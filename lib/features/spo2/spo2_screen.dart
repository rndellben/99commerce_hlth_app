import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/sync/band_sync_service.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/features/spo2/spo2_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';

/// Blood Oxygen detail screen. The H59 doesn't push SpO2 continuously
/// (the band only measures when scheduled or actively triggered), so
/// "Measure Now" runs an on-demand `manualModeSpO2` measurement — same
/// path the BLE Debug "Stream SpO2" button uses. ~30-60s round trip;
/// one final % value when the band converges.
///
/// Below the live headline, the screen mirrors QWatch Pro's Day / Week
/// / Month layout (PeriodToggle + DateSelector + TrendChartCard +
/// MetricGrid) so users can scrub through history and see overnight
/// trends.
class SpO2Screen extends ConsumerStatefulWidget {
  const SpO2Screen({super.key});

  @override
  ConsumerState<SpO2Screen> createState() => _SpO2ScreenState();
}

class _SpO2ScreenState extends ConsumerState<SpO2Screen> {
  // ── Live measurement state (Measure Now flow) ─────────────────────────
  bool _measuring = false;
  int? _liveSpo2;
  int? _liveHr;
  StreamSubscription<({int spo2, int hr})>? _sub;
  Timer? _timeoutTimer;

  // ── History view state (Day/Week/Month) ───────────────────────────────
  Period _period = Period.day;
  DateTime _anchor = _today();
  bool _syncing = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBand());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    if (_measuring) {
      // Best-effort: tell the band to stop if we leave mid-measurement.
      ref.read(bleServiceProvider).stopSpo2Stream();
    }
    super.dispose();
  }

  // ── Live measurement ──────────────────────────────────────────────────

  Future<void> _measureNow() async {
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _measuring = true;
      _liveSpo2 = null;
      _liveHr = null;
    });
    _sub?.cancel();
    _sub = ble.spo2Stream.listen((t) {
      if (!mounted) return;
      setState(() {
        _liveSpo2 = t.spo2;
        _liveHr = t.hr;
      });
      // First good reading is the band's converged value — auto-stop.
      _finish();
    });
    // Safety timeout — band sometimes never converges (poor contact).
    _timeoutTimer = Timer(const Duration(seconds: 75), () {
      if (mounted && _measuring) _finish(timedOut: true);
    });

    try {
      await ble.startSpo2Stream();
    } catch (e) {
      _finish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start measurement: $e')),
        );
      }
    }
  }

  Future<void> _finish({bool timedOut = false}) async {
    _sub?.cancel();
    _sub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    try {
      await ref.read(bleServiceProvider).stopSpo2Stream();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _measuring = false);
    if (timedOut && _liveSpo2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Measurement timed out — make sure the band is snug and try again.'),
        ),
      );
    }
  }

  // ── History sync ──────────────────────────────────────────────────────

  /// Pulls the SpO2 day(s) that the current view needs from the band.
  ///
  /// H59's per-day API (`getSpO2Day`) supports dayOffset 0..7. Older
  /// days fall back to local SQLite (no BLE call needed).
  Future<void> _refreshFromBand() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device == null) return; // not paired — silently skip
      final sync = ref.read(bandSyncServiceProvider);
      final offsets = _offsetsForView();
      var total = 0;
      for (final offset in offsets) {
        final result = await sync.syncSpo2Day(
          userId: ActiveSession.defaultUserId,
          deviceId: device.id,
          dayOffset: offset,
        );
        total += result.count;
      }
      if (!mounted) return;
      ref.invalidate(spo2SamplesForDateProvider);
      ref.invalidate(spo2DailyMetricsForDateProvider);
      ref.invalidate(spo2DailyMetricsInRangeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total == 0
              ? 'No new SpO2 data on band'
              : 'Synced ${offsets.length} day(s) of SpO2'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SpO2 sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// SDK supports dayOffset 0..7. Clamp to that window — older days
  /// only appear if they were synced previously and still live in
  /// local SQLite.
  Iterable<int> _offsetsForView() {
    final today = _today();
    switch (_period) {
      case Period.day:
        final delta = today.difference(_anchor).inDays;
        return [delta.clamp(0, 7)];
      case Period.week:
        final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          return today.difference(d).inDays.clamp(0, 7);
        }).toSet();
      case Period.month:
        // Band only retains ~7 days; older days come from local SQLite.
        return List.generate(8, (i) => i);
      case Period.threeMonths:
        return List.generate(8, (i) => i); // band only retains ~7 days
    }
  }

  VoidCallback _shiftAnchor(int direction) {
    return () {
      setState(() {
        switch (_period) {
          case Period.day:
            _anchor = _anchor.add(Duration(days: direction));
            break;
          case Period.week:
            _anchor = _anchor.add(Duration(days: 7 * direction));
            break;
          case Period.month:
            _anchor = DateTime(
              _anchor.year,
              _anchor.month + direction,
              _anchor.day,
            );
            break;
          case Period.threeMonths:
            _anchor = DateTime(_anchor.year, _anchor.month + (3 * direction), _anchor.day);
        }
      });
      _refreshFromBand();
    };
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(latestSpo2SampleProvider).valueOrNull;
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    // Headline value priority: live in-flight reading → latest stored
    // sample → placeholder.
    final headlineValue =
        _liveSpo2?.toString() ?? latest?.pctMin.toString() ?? '--';
    final headlineSubtitle = _measuring
        ? (_liveSpo2 == null
            ? 'Measuring... wear the band snugly'
            : 'Live reading')
        : (latest != null
            ? 'Last reading ${_timeAgo(latest.capturedAt)}'
            : (connected
                ? 'Tap Measure Now to get a reading'
                : 'Connect your band to measure SpO2'));

    return MetricTrendScaffold(
      metricName: 'SpO2',
      allowAddEdit: false,
      aboutTitle: 'SpO2',
      aboutText: 'Blood oxygen saturation (SpO2) measures the percentage of haemoglobin carrying oxygen. Healthy adults typically maintain levels of 95% or above.',
      extraActions: [
        IconButton(
          icon: _syncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh),
          onPressed: _syncing ? null : _refreshFromBand,
          tooltip: 'Sync from band',
        ),
      ],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFromBand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Live headline (existing UX) ─────────────────────────
                _LiveHeadline(
                  headlineValue: headlineValue,
                  headlineSubtitle: headlineSubtitle,
                  measuring: _measuring,
                  liveHr: _liveHr,
                  todayOvernightAvg: today?.spo2OvernightAvg,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        !connected || _measuring ? null : _measureNow,
                    icon: _measuring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.air),
                    label:
                        Text(_measuring ? 'Measuring...' : 'Measure Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.spo2,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (!connected) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Connect your band from the Settings tab to enable Measure.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ] else if (!_measuring) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Takes ~30-60s. Keep the band snug and your hand still.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                // ── History (Day/Week/Month) ────────────────────────────
                PeriodToggle(
                  value: _period,
                  onChanged: (p) => setState(() {
                    _period = p;
                    _anchor = _today();
                  }),
                ),
                const SizedBox(height: 16),
                DateSelector(
                  period: _period,
                  anchor: _anchor,
                  onPrev: _shiftAnchor(-1),
                  onNext: _shiftAnchor(1),
                ),
                const SizedBox(height: 16),
                if (_period == Period.day) _DayView(anchor: _anchor),
                if (_period != Period.day)
                  _RangeView(period: _period, anchor: _anchor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─── Live headline card ────────────────────────────────────────────────

class _LiveHeadline extends StatelessWidget {
  const _LiveHeadline({
    required this.headlineValue,
    required this.headlineSubtitle,
    required this.measuring,
    required this.liveHr,
    required this.todayOvernightAvg,
  });

  final String headlineValue;
  final String headlineSubtitle;
  final bool measuring;
  final int? liveHr;
  final double? todayOvernightAvg;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(child: Icon(Icons.air, color: AppColors.spo2, size: 40)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            headlineValue,
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: AppColors.spo2),
          ),
        ),
        Center(
          child: Text(
            '% SpO2',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (measuring)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.spo2),
              ),
            if (measuring) const SizedBox(width: 8),
            Text(headlineSubtitle,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        if (liveHr != null && measuring) ...[
          const SizedBox(height: 4),
          Center(
            child: Text('HR during read: $liveHr bpm',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary)),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Overnight Average",
                  style: Theme.of(context).textTheme.titleSmall),
              Text(
                todayOvernightAvg == null
                    ? '-- %'
                    : '${todayOvernightAvg!.toStringAsFixed(0)} %',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.spo2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Day view ───────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samplesAsync = ref.watch(spo2SamplesForDateProvider(anchor));
    final dailyAsync = ref.watch(spo2DailyMetricsForDateProvider(anchor));

    return samplesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load SpO2: $e'),
      data: (samples) {
        final points = samples
            .map((s) => TrendPoint(
                  at: s.capturedAt.toLocal(),
                  value: s.pctMin.toDouble(),
                ))
            .toList();

        final daily = dailyAsync.valueOrNull;

        // Day stats — overnight from daily_metrics (authoritative),
        // daytime computed from samples whose local hour is >= 9.
        final daytimeSamples = samples.where((s) {
          final h = s.capturedAt.toLocal().hour;
          return h >= 9 && h < 22;
        }).toList();
        final daytimeAvg = _avg(
            daytimeSamples.map((s) => s.pctMin.toDouble()));
        final belowCount =
            samples.where((s) => s.pctMin < 95).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'SpO2 across the day',
              subtitle: ymd(anchor),
              points: points,
              color: AppColors.spo2,
              axis: const TrendAxis.bounded(
                min: 88,
                max: 100,
                referenceMin: 95,
                referenceMax: 100,
              ),
              bottomLabels: points.length >= 2
                  ? [hm(points.first.at), hm(points.last.at)]
                  : const [],
              showDots: true,
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Overnight Avg',
                  reference: 'Reference: 95~100%',
                  value: daily?.spo2OvernightAvg == null
                      ? '--'
                      : daily!.spo2OvernightAvg!.toStringAsFixed(0),
                  valueUnit: '%',
                  status: daily?.spo2OvernightAvg == null
                      ? MetricStatus.none
                      : statusFor(
                          value: daily!.spo2OvernightAvg!,
                          ok: const MetricRange(95, 100),
                        ),
                ),
                MetricTile(
                  label: 'Overnight Min',
                  reference: 'Reference: ≥95%',
                  value: daily?.spo2OvernightMin == null
                      ? '--'
                      : daily!.spo2OvernightMin!.toString(),
                  valueUnit: '%',
                  status: daily?.spo2OvernightMin == null
                      ? MetricStatus.none
                      : statusFor(
                          value: daily!.spo2OvernightMin!.toDouble(),
                          ok: const MetricRange(95, 100),
                        ),
                ),
                MetricTile(
                  label: 'Daytime Avg',
                  reference: 'Reference: 95~100%',
                  value: daytimeAvg == null
                      ? '--'
                      : daytimeAvg.toStringAsFixed(0),
                  valueUnit: '%',
                  status: daytimeAvg == null
                      ? MetricStatus.none
                      : statusFor(
                          value: daytimeAvg,
                          ok: const MetricRange(95, 100),
                        ),
                ),
                MetricTile(
                  label: 'Readings below 95%',
                  reference: samples.isEmpty
                      ? ''
                      : 'of ${samples.length} sample(s)',
                  value: belowCount.toString(),
                  status: samples.isEmpty
                      ? MetricStatus.none
                      : (belowCount == 0
                          ? MetricStatus.normal
                          : MetricStatus.low),
                ),
              ],
            ),
            if (samples.isEmpty) ...[
              const SizedBox(height: 16),
              const _EmptyState(
                message:
                    'No SpO2 samples for this day. Overnight measurements need the band to be worn through the night.',
              ),
            ],
            const SizedBox(height: 16),
            DataDetailsCard(metric: 'spo2'),
            const SizedBox(height: 16),
            Last7DaysTile(
              metric: 'spo2',
              averageValue: null,
              unit: '%',
              color: AppColors.spo2,
            ),
            const SizedBox(height: 16),
            AboutMetricSection(
              title: 'About SpO2',
              body: 'Blood oxygen saturation (SpO2) measures the percentage of haemoglobin carrying oxygen. Healthy adults typically maintain levels of 95% or above.',
            ),
            const SizedBox(height: 16),
            _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

// ─── Week / Month view ──────────────────────────────────────────────────

class _RangeView extends ConsumerWidget {
  const _RangeView({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final async = ref.watch(spo2DailyMetricsInRangeProvider(range));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load: $e'),
      data: (rows) {
        // Keep only rows that actually carry an SpO2 overnight rollup.
        final spo2Rows = rows
            .where((r) => r.spo2OvernightAvg != null)
            .toList();

        final points = spo2Rows
            .map((r) => TrendPoint(
                  at: DateTime(r.localDate.year, r.localDate.month,
                      r.localDate.day, 12),
                  value: r.spo2OvernightAvg!,
                ))
            .toList();

        final avgOvernight =
            _avg(spo2Rows.map((r) => r.spo2OvernightAvg!));
        final minOvernightVals = spo2Rows
            .where((r) => r.spo2OvernightMin != null)
            .map((r) => r.spo2OvernightMin!)
            .toList();
        final minOvernight = minOvernightVals.isEmpty
            ? null
            : minOvernightVals.reduce((a, b) => a < b ? a : b);
        final daysBelow = spo2Rows
            .where((r) => r.spo2OvernightAvg! < 95)
            .length;

        final title = period == Period.threeMonths
            ? 'Overnight SpO2 — 3 months'
            : period == Period.week
                ? 'Overnight SpO2 — this week'
                : 'Overnight SpO2 — this month';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: title,
              points: points,
              color: AppColors.spo2,
              axis: const TrendAxis.bounded(
                min: 88,
                max: 100,
                referenceMin: 95,
                referenceMax: 100,
              ),
              bottomLabels: _bottomLabels(period, anchor),
              showDots: true,
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Average overnight',
                  reference: 'Reference: 95~100%',
                  value: avgOvernight == null
                      ? '--'
                      : avgOvernight.toStringAsFixed(0),
                  valueUnit: '%',
                  status: avgOvernight == null
                      ? MetricStatus.none
                      : statusFor(
                          value: avgOvernight,
                          ok: const MetricRange(95, 100),
                        ),
                ),
                MetricTile(
                  label: 'Lowest overnight min',
                  reference: 'Reference: ≥95%',
                  value: minOvernight == null
                      ? '--'
                      : minOvernight.toString(),
                  valueUnit: '%',
                  status: minOvernight == null
                      ? MetricStatus.none
                      : statusFor(
                          value: minOvernight.toDouble(),
                          ok: const MetricRange(95, 100),
                        ),
                ),
                MetricTile(
                  label: 'Days below 95%',
                  reference: spo2Rows.isEmpty
                      ? ''
                      : 'of ${spo2Rows.length} day(s) with data',
                  value: daysBelow.toString(),
                  status: spo2Rows.isEmpty
                      ? MetricStatus.none
                      : (daysBelow == 0
                          ? MetricStatus.normal
                          : MetricStatus.low),
                ),
              ],
            ),
            if (spo2Rows.isEmpty) ...[
              const SizedBox(height: 16),
              const _EmptyState(
                message:
                    'No overnight SpO2 in this range. Wear the band through the night to see trends.',
              ),
            ],
            const SizedBox(height: 16),
            DataDetailsCard(metric: 'spo2'),
            const SizedBox(height: 16),
            Last7DaysTile(
              metric: 'spo2',
              averageValue: null,
              unit: '%',
              color: AppColors.spo2,
            ),
            const SizedBox(height: 16),
            AboutMetricSection(
              title: 'About SpO2',
              body: 'Blood oxygen saturation (SpO2) measures the percentage of haemoglobin carrying oxygen. Healthy adults typically maintain levels of 95% or above.',
            ),
            const SizedBox(height: 16),
            _DisclaimerCard(),
          ],
        );
      },
    );
  }

  Spo2DateRange _resolveRange(Period p, DateTime a) {
    switch (p) {
      case Period.day:
        final start = DateTime(a.year, a.month, a.day);
        return Spo2DateRange(fromDate: start, toDate: start);
      case Period.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return Spo2DateRange(
          fromDate: DateTime(monday.year, monday.month, monday.day),
          toDate: DateTime(sunday.year, sunday.month, sunday.day),
        );
      case Period.month:
        final first = DateTime(a.year, a.month, 1);
        final lastDay = DateTime(a.year, a.month + 1, 0);
        return Spo2DateRange(fromDate: first, toDate: lastDay);
      case Period.threeMonths:
        final first = DateTime(a.year, a.month - 2, 1);
        final lastDay = DateTime(a.year, a.month + 1, 0);
        return Spo2DateRange(fromDate: first, toDate: lastDay);
    }
  }

  List<String> _bottomLabels(Period period, DateTime anchor) {
    switch (period) {
      case Period.day:
        return const [];
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return List.generate(
            7, (i) => md(monday.add(Duration(days: i))));
      case Period.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        final days = next.difference(first).inDays;
        return [
          for (final day in [1, 7, 13, 19, 25, days])
            md(DateTime(first.year, first.month, day)),
        ];
      case Period.threeMonths:
        final first = DateTime(anchor.year, anchor.month - 2, 1);
        return [
          md(first),
          md(DateTime(first.year, first.month + 1, 1)),
          md(DateTime(first.year, first.month + 2, 1)),
        ];
    }
  }
}

// ─── Helpers + small widgets ────────────────────────────────────────────

double? _avg(Iterable<double> values) {
  final list = values.where((v) => v.isFinite).toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.air, color: AppColors.spo2, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'SpO2 readings from a wrist wearable are estimates — accuracy depends on band fit and skin contact. '
        'Persistent readings below 95% with symptoms should be evaluated by a healthcare professional. '
        'This feature is not designed for medical diagnosis.',
        style: TextStyle(
            color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }
}
