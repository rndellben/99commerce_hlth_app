import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/features/heart_rate/heart_rate_providers.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';

/// Heart Rate detail screen.
///
/// Top of page: live RT HR headline + "Measure Now" — same band-pushed
/// stream the Home dashboard HR card consumes, with a fallback to the
/// latest stored DB sample when the band isn't pushing yet.
///
/// Below the headline: Day / Week / Month tabs, a date selector, a
/// trend chart and metric tile grid — mirrors the QWatch Pro Heart Rate
/// tab pattern and the sibling Sleep detail screen.
class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen> {
  bool _measuring = false;
  bool _syncing = false;
  Period _period = Period.day;
  DateTime _anchor = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBand());
  }

  Future<void> _measureNow() async {
    final ble = ref.read(bleServiceProvider);
    setState(() => _measuring = true);
    try {
      // Wake the band into a brief continuous-read window so RT HR
      // updates within seconds. 30s window is plenty for a UX-grade
      // "tap-to-measure" interaction.
      await ble.startMeasureHrRaw(durationSec: 30);
    } catch (_) {
      // Non-fatal — RT HR stream will still emit when band pushes its
      // next routine update.
    }
    // Leave _measuring=true for a short visual cooldown; band may
    // continue streaming for ~30s but we don't need to block the UI.
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _measuring = false);
  }

  /// Pulls the HR day(s) the current view needs from the band. SDK
  /// §2.3.x supports dayOffset 0..7 — older days still surface from
  /// local SQLite via the repo.
  Future<void> _refreshFromBand() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device == null) return; // not paired — silently skip
      final sync = ref.read(syncServiceProvider);
      final offsets = _offsetsForView();
      var total = 0;
      for (final offset in offsets) {
        final r = await sync.syncHr(
          userId: ActiveSession.defaultUserId,
          deviceId: device.id,
          dayOffset: offset,
        );
        total += r.count;
      }
      if (!mounted) return;
      // Invalidate the per-range providers so the new samples show up.
      ref.invalidate(hrSamplesInRangeProvider);
      ref.invalidate(hrSamplesInRangeOnceProvider);
      ref.invalidate(restingHrInRangeProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total == 0
              ? 'No new HR data on band'
              : 'Synced ${offsets.length} day(s) of heart rate'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HR sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

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
        // Band only retains ~7 days; older days fall back to SQLite.
        return List.generate(8, (i) => i);
      case Period.threeMonths:
        return List.generate(8, (i) => i); // band only retains ~7 days
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetricTrendScaffold(
      metricName: 'Heart Rate',
      allowAddEdit: false,
      aboutTitle: 'Heart Rate',
      aboutText: 'Heart rate is the number of times your heart beats per minute. Your resting heart rate is a key indicator of cardiovascular fitness and recovery.',
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
                _LiveHrHeader(
                  measuring: _measuring,
                  onMeasureNow: _measureNow,
                ),
                const SizedBox(height: 20),
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
                if (_period == Period.week)
                  _RangeView(period: _period, anchor: _anchor),
                if (_period == Period.month)
                  _RangeView(period: _period, anchor: _anchor),
                if (_period == Period.threeMonths)
                  _RangeView(period: _period, anchor: _anchor),
              ],
            ),
          ),
        ),
      ),
    );
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
}

// ─── Live HR headline (preserved from original) ────────────────────────────

class _LiveHrHeader extends ConsumerWidget {
  const _LiveHrHeader({required this.measuring, required this.onMeasureNow});
  final bool measuring;
  final VoidCallback onMeasureNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleServiceProvider);
    final latestHr = ref.watch(latestHrSampleProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.favorite, color: AppColors.heartRate, size: 40),
          const SizedBox(height: 8),
          // Seeded: replays the last fresh live push so this headline agrees
          // with the home card even when opened between band pushes.
          StreamBuilder<int>(
            stream: ble.realtimeHeartRateSeeded,
            builder: (context, snap) {
              final realtime = snap.data;
              final value = realtime?.toString() ??
                  latestHr?.bpm.toString() ??
                  '--';
              final source = realtime != null
                  ? 'Live'
                  : (latestHr != null
                      ? 'Last reading ${_timeAgo(latestHr.capturedAt)}'
                      : (connected
                          ? 'Waiting for band update...'
                          : 'Connect your band to see live HR'));
              return Column(
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(color: AppColors.heartRate),
                  ),
                  Text(
                    'bpm',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (realtime != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        source,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !connected || measuring ? null : onMeasureNow,
              icon: measuring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.favorite),
              label: Text(measuring ? 'Measuring...' : 'Measure Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.heartRate,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ],
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

// ─── Day view ──────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _dayRange(anchor);
    final samplesAsync = ref.watch(hrSamplesInRangeProvider(range));
    final restingAsync = ref.watch(restingHrInRangeProvider(range));
    final isToday = _isSameDay(anchor, _todayLocal());
    // Today's restingHrBpm lives in the daily_metrics row — use it when
    // viewing today so the user sees the aggregator-derived RHR.
    final today = isToday
        ? ref.watch(todayDailyMetricsProvider).valueOrNull
        : null;

    return samplesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load HR: $e'),
      data: (samples) {
        if (samples.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EmptyState(
                  message:
                      'No heart rate data for this day. Wear the band and sync to populate.'),
              const SizedBox(height: 16),
              DataDetailsCard(metric: 'heart-rate'),
              const SizedBox(height: 16),
              Last7DaysTile(
                metric: 'heart-rate',
                averageValue: null,
                unit: 'bpm',
                color: AppColors.heartRate,
              ),
              const SizedBox(height: 16),
              AboutMetricSection(
                title: 'About Heart Rate',
                body: 'Heart rate is the number of times your heart beats per minute. Your resting heart rate is a key indicator of cardiovascular fitness and recovery.',
              ),
              const SizedBox(height: 16),
              const _DisclaimerCard(),
            ],
          );
        }
        final points = samples
            .map((s) => TrendPoint(
                  at: s.capturedAt.toLocal(),
                  value: s.bpm.toDouble(),
                ))
            .toList();
        final bpms = samples.map((s) => s.bpm).toList();
        final minHr = bpms.reduce((a, b) => a < b ? a : b);
        final maxHr = bpms.reduce((a, b) => a > b ? a : b);
        final avgHr = bpms.reduce((a, b) => a + b) / bpms.length;

        // RHR: prefer today's daily_metrics value for parity with home.
        // For historical days, average the resting-flagged samples.
        int? rhr;
        if (today?.restingHrBpm != null) {
          rhr = today!.restingHrBpm;
        } else {
          final resting = restingAsync.valueOrNull ?? const <HrSample>[];
          if (resting.isNotEmpty) {
            final r = resting.map((s) => s.bpm).reduce((a, b) => a + b) /
                resting.length;
            rhr = r.round();
          }
        }

        final dayStart = DateTime(anchor.year, anchor.month, anchor.day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Heart Rate',
              subtitle: '24-hour trend',
              points: points,
              color: AppColors.heartRate,
              axis: const TrendAxis.bounded(
                min: 40,
                max: 180,
                referenceMin: 60,
                referenceMax: 100,
              ),
              bottomLabels: [
                hm(dayStart),
                hm(dayStart.add(const Duration(hours: 6))),
                hm(dayStart.add(const Duration(hours: 12))),
                hm(dayStart.add(const Duration(hours: 18))),
                hm(dayStart.add(const Duration(hours: 23, minutes: 59))),
              ],
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Resting heart rate',
                  reference: 'Reference: 50~80 bpm',
                  value: rhr == null ? '--' : rhr.toString(),
                  valueUnit: 'bpm',
                  status: rhr == null
                      ? MetricStatus.none
                      : statusFor(
                          value: rhr.toDouble(),
                          ok: const MetricRange(50, 80),
                        ),
                ),
                MetricTile(
                  label: 'Average heart rate',
                  reference: 'Reference: 60~100 bpm',
                  value: avgHr.toStringAsFixed(0),
                  valueUnit: 'bpm',
                  status: statusFor(
                    value: avgHr,
                    ok: const MetricRange(60, 100),
                  ),
                ),
                MetricTile(
                  label: 'Minimum heart rate',
                  reference: '',
                  value: minHr.toString(),
                  valueUnit: 'bpm',
                ),
                MetricTile(
                  label: 'Maximum heart rate',
                  reference: '',
                  value: maxHr.toString(),
                  valueUnit: 'bpm',
                ),
              ],
            ),
            const SizedBox(height: 16),
            DataDetailsCard(metric: 'heart-rate'),
            const SizedBox(height: 16),
            Last7DaysTile(
              metric: 'heart-rate',
              averageValue: null,
              unit: 'bpm',
              color: AppColors.heartRate,
            ),
            const SizedBox(height: 16),
            AboutMetricSection(
              title: 'About Heart Rate',
              body: 'Heart rate is the number of times your heart beats per minute. Your resting heart rate is a key indicator of cardiovascular fitness and recovery.',
            ),
            const SizedBox(height: 16),
            const _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

// ─── Week / Month range view ───────────────────────────────────────────────

class _RangeView extends ConsumerWidget {
  const _RangeView({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final samplesAsync = ref.watch(hrSamplesInRangeOnceProvider(range));
    final restingAsync = ref.watch(restingHrInRangeProvider(range));

    return samplesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load HR: $e'),
      data: (samples) {
        if (samples.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EmptyState(
                  message: 'No heart rate recorded in this period.'),
              const SizedBox(height: 16),
              DataDetailsCard(metric: 'heart-rate'),
              const SizedBox(height: 16),
              Last7DaysTile(
                metric: 'heart-rate',
                averageValue: null,
                unit: 'bpm',
                color: AppColors.heartRate,
              ),
              const SizedBox(height: 16),
              AboutMetricSection(
                title: 'About Heart Rate',
                body: 'Heart rate is the number of times your heart beats per minute. Your resting heart rate is a key indicator of cardiovascular fitness and recovery.',
              ),
              const SizedBox(height: 16),
              const _DisclaimerCard(),
            ],
          );
        }
        final daily = _dailyAverages(samples, period, anchor);
        final points = daily.entries
            .where((e) => e.value.count > 0)
            .map((e) => TrendPoint(
                  at: e.key,
                  value: e.value.avg,
                ))
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));

        final bpms = samples.map((s) => s.bpm).toList();
        final avgHr = bpms.reduce((a, b) => a + b) / bpms.length;
        final minHr = bpms.reduce((a, b) => a < b ? a : b);
        final maxHr = bpms.reduce((a, b) => a > b ? a : b);

        final restingSamples = restingAsync.valueOrNull ?? const <HrSample>[];
        double? avgResting;
        if (restingSamples.isNotEmpty) {
          avgResting =
              restingSamples.map((s) => s.bpm).reduce((a, b) => a + b) /
                  restingSamples.length;
        }

        final subtitle = period == Period.threeMonths
            ? 'Daily average across 3 months'
            : period == Period.week
                ? 'Daily average across the week'
                : 'Daily average across the month';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Heart Rate',
              subtitle: subtitle,
              points: points,
              color: AppColors.heartRate,
              axis: const TrendAxis.bounded(
                min: 40,
                max: 140,
                referenceMin: 60,
                referenceMax: 100,
              ),
              showDots: true,
              bottomLabels: _axisLabels(period, anchor),
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Average resting HR',
                  reference: 'Reference: 50~80 bpm',
                  value: avgResting == null
                      ? '--'
                      : avgResting.toStringAsFixed(0),
                  valueUnit: 'bpm',
                  status: avgResting == null
                      ? MetricStatus.none
                      : statusFor(
                          value: avgResting,
                          ok: const MetricRange(50, 80),
                        ),
                ),
                MetricTile(
                  label: 'Average heart rate',
                  reference: 'Reference: 60~100 bpm',
                  value: avgHr.toStringAsFixed(0),
                  valueUnit: 'bpm',
                  status: statusFor(
                    value: avgHr,
                    ok: const MetricRange(60, 100),
                  ),
                ),
                MetricTile(
                  label: 'Minimum heart rate',
                  reference: '',
                  value: minHr.toString(),
                  valueUnit: 'bpm',
                ),
                MetricTile(
                  label: 'Maximum heart rate',
                  reference: '',
                  value: maxHr.toString(),
                  valueUnit: 'bpm',
                ),
              ],
            ),
            const SizedBox(height: 16),
            DataDetailsCard(metric: 'heart-rate'),
            const SizedBox(height: 16),
            Last7DaysTile(
              metric: 'heart-rate',
              averageValue: null,
              unit: 'bpm',
              color: AppColors.heartRate,
            ),
            const SizedBox(height: 16),
            AboutMetricSection(
              title: 'About Heart Rate',
              body: 'Heart rate is the number of times your heart beats per minute. Your resting heart rate is a key indicator of cardiovascular fitness and recovery.',
            ),
            const SizedBox(height: 16),
            const _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

// ─── Range helpers ─────────────────────────────────────────────────────────

DateTime _todayLocal() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

HrRange _dayRange(DateTime anchor) {
  final start = DateTime(anchor.year, anchor.month, anchor.day);
  final end = start.add(const Duration(days: 1));
  return HrRange(from: start.toUtc(), to: end.toUtc());
}

HrRange _resolveRange(Period p, DateTime a) {
  switch (p) {
    case Period.day:
      return _dayRange(a);
    case Period.week:
      final monday = a.subtract(Duration(days: a.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = start.add(const Duration(days: 7));
      return HrRange(from: start.toUtc(), to: end.toUtc());
    case Period.month:
      final first = DateTime(a.year, a.month, 1);
      final next = DateTime(a.year, a.month + 1, 1);
      return HrRange(from: first.toUtc(), to: next.toUtc());
    case Period.threeMonths:
      final start = DateTime(a.year, a.month - 2, 1);
      final end = DateTime(a.year, a.month + 1, 1);
      return HrRange(from: start.toUtc(), to: end.toUtc());
  }
}

class _DailyAvg {
  _DailyAvg();
  int sum = 0;
  int count = 0;
  double get avg => count == 0 ? 0 : sum / count;
}

/// Bucket samples by local day, returning a map keyed by day-start
/// (local midnight) → running average. Empty days are represented as a
/// zero-count entry so callers can decide whether to render gaps.
Map<DateTime, _DailyAvg> _dailyAverages(
    List<HrSample> samples, Period period, DateTime anchor) {
  final out = <DateTime, _DailyAvg>{};

  // Pre-seed the map with every day in the selected window so the chart
  // gets uniform X-axis spacing even when a day has no data.
  Iterable<DateTime> days;
  switch (period) {
    case Period.day:
      days = [DateTime(anchor.year, anchor.month, anchor.day)];
      break;
    case Period.week:
      final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
      days = List.generate(
          7,
          (i) => DateTime(monday.year, monday.month, monday.day)
              .add(Duration(days: i)));
      break;
    case Period.month:
      final first = DateTime(anchor.year, anchor.month, 1);
      final next = DateTime(anchor.year, anchor.month + 1, 1);
      final dayCount = next.difference(first).inDays;
      days = List.generate(dayCount, (i) => first.add(Duration(days: i)));
      break;
    case Period.threeMonths:
      final first = DateTime(anchor.year, anchor.month - 2, 1);
      final next = DateTime(anchor.year, anchor.month + 1, 1);
      final dayCount = next.difference(first).inDays;
      days = List.generate(dayCount, (i) => first.add(Duration(days: i)));
  }
  for (final d in days) {
    out[d] = _DailyAvg();
  }

  for (final s in samples) {
    final local = s.capturedAt.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    final bucket = out[key];
    if (bucket == null) continue; // outside the slot window
    bucket.sum += s.bpm;
    bucket.count += 1;
  }
  return out;
}

List<String> _axisLabels(Period period, DateTime anchor) {
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

// ─── Empty state + disclaimer ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: AppColors.heartRate, size: 28),
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
        'Heart rate readings are captured by the band\'s optical PPG sensor and '
        'can be affected by motion, fit, and skin tone. '
        'This feature is not designed for medical use — consult a healthcare professional for any concerns.',
        style:
            TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }
}
