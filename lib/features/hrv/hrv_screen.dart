import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/features/hrv/hrv_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';

/// HRV detail screen.
///
/// Mirrors the Stress / Sleep / Heart-Rate detail-screen template:
/// headline → period toggle → date selector → trend chart → metric grid.
///
/// **dayOffset quirk:** the H59 stores HRV in a rolling 60-65 slot buffer
/// (~30 min per slot). Firmware quirk: `dayOffset=0` returns empty;
/// `dayOffset=1` returns the actual rolling buffer covering yesterday +
/// today. We hide that from the user by pulling BOTH offsets on every
/// refresh — same workaround Stress uses. Adapter logic in
/// `sync_adapters.dart::hrvFromNative` already places each slot at the
/// correct absolute timestamp using the band's `today.zeroTime` anchor,
/// so consumers just see clean per-slot RMSSD points.
class HrvScreen extends ConsumerStatefulWidget {
  const HrvScreen({super.key});

  @override
  ConsumerState<HrvScreen> createState() => _HrvScreenState();
}

class _HrvScreenState extends ConsumerState<HrvScreen> {
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

  /// Pulls the HRV day(s) the current view needs from the band. SDK
  /// supports dayOffset 0..7. Per the firmware quirk, dayOffset 0 is a
  /// no-op on its own — but we still issue it because adapter logic
  /// keys timestamps off `today.zeroTime` from the same response, and
  /// running both offsets is the documented Stress/HRV workaround.
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
        final r = await sync.syncHrv(
          userId: ActiveSession.defaultUserId,
          deviceId: device.id,
          dayOffset: offset,
        );
        total += r.count;
      }
      if (!mounted) return;
      // Invalidate the per-range providers so the new slots show up.
      ref.invalidate(hrvSamplesInRangeProvider);
      ref.invalidate(hrvSamplesInRangeOnceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(total == 0
              ? 'No new HRV data on band'
              : 'Synced ${offsets.length} day(s) of HRV'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HRV sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// SDK supports dayOffset 0..7. We always include both 0 and 1 for
  /// Day view because the band's rolling HRV buffer spans yesterday +
  /// today — pulling offset=1 fills out earlier-in-the-day slots that
  /// offset=0 alone misses.
  Iterable<int> _offsetsForView() {
    final today = _today();
    switch (_period) {
      case Period.day:
        final delta = today.difference(_anchor).inDays.clamp(0, 7);
        // Pair the anchor day with its neighbour so the rolling buffer
        // is exercised on both sides of the dayOffset quirk.
        return {delta, (delta + 1).clamp(0, 7)};
      case Period.week:
        final monday = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          return today.difference(d).inDays.clamp(0, 7);
        }).toSet();
      case Period.month:
        // Band only retains ~7 days; older days fall back to SQLite.
        return List.generate(8, (i) => i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('HRV'),
        centerTitle: true,
        leading: const BackButton(),
        actions: [
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
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFromBand,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HrvHeader(),
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
        }
      });
      _refreshFromBand();
    };
  }
}

// ─── Headline ─────────────────────────────────────────────────────────────

class _HrvHeader extends ConsumerWidget {
  const _HrvHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestHrvSampleProvider).valueOrNull;
    // Fall back to today's daily_metrics aggregate when no per-slot
    // sample has arrived yet (e.g. first launch before the periodic
    // sync runs).
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final rmssd = latest?.rmssdMs ?? today?.hrvRmssdMs;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.show_chart,
              color: AppColors.respiratory, size: 40),
          const SizedBox(height: 8),
          Text(
            rmssd?.toStringAsFixed(0) ?? '--',
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: AppColors.respiratory),
          ),
          Text(
            'ms RMSSD',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            latest == null
                ? 'Wear the band so the next 30-min slot can sync'
                : 'Last reading ${_timeAgo(latest.capturedAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ─── Day view ─────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({required this.anchor});
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _dayRange(anchor);
    final samplesAsync = ref.watch(hrvSamplesInRangeProvider(range));

    return samplesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load HRV: $e'),
      data: (samples) {
        if (samples.isEmpty) {
          return const _EmptyState(
              message:
                  'No HRV data for this day. The band records one slot every ~30 minutes while worn.');
        }
        final points = samples
            .map((s) => TrendPoint(
                  at: s.capturedAt.toLocal(),
                  value: s.rmssdMs,
                ))
            .toList();
        final rmssds = samples.map((s) => s.rmssdMs).toList();
        final avgRmssd =
            rmssds.reduce((a, b) => a + b) / rmssds.length;
        final latestRmssd = samples.last.rmssdMs;
        final sdnnValues = samples
            .map((s) => s.sdnnMs)
            .whereType<double>()
            .toList();
        final avgSdnn = sdnnValues.isEmpty
            ? null
            : sdnnValues.reduce((a, b) => a + b) / sdnnValues.length;

        final dayStart = DateTime(anchor.year, anchor.month, anchor.day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Heart Rate Variability',
              subtitle: '24-hour trend (RMSSD)',
              points: points,
              color: AppColors.respiratory,
              axis: const TrendAxis.bounded(
                min: 10,
                max: 100,
                referenceMin: 30,
                referenceMax: 60,
              ),
              showDots: true,
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
                  label: 'Latest RMSSD',
                  reference: 'Reference: 30~60 ms',
                  value: latestRmssd.toStringAsFixed(0),
                  valueUnit: 'ms',
                  status: statusFor(
                    value: latestRmssd,
                    ok: const MetricRange(30, 60),
                  ),
                ),
                MetricTile(
                  label: 'Average RMSSD',
                  reference: 'Reference: 30~60 ms',
                  value: avgRmssd.toStringAsFixed(0),
                  valueUnit: 'ms',
                  status: statusFor(
                    value: avgRmssd,
                    ok: const MetricRange(30, 60),
                  ),
                ),
                MetricTile(
                  label: 'Average SDNN',
                  reference: avgSdnn == null ? '' : 'Beat-to-beat variation',
                  value: avgSdnn == null ? '--' : avgSdnn.toStringAsFixed(0),
                  valueUnit: avgSdnn == null ? null : 'ms',
                ),
                MetricTile(
                  label: 'Samples',
                  reference: '30-min slots',
                  value: samples.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _RangeLegend(),
            const SizedBox(height: 16),
            const _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

// ─── Week / Month view ────────────────────────────────────────────────────

class _RangeView extends ConsumerWidget {
  const _RangeView({required this.period, required this.anchor});
  final Period period;
  final DateTime anchor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final samplesAsync = ref.watch(hrvSamplesInRangeOnceProvider(range));

    return samplesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _EmptyState(message: 'Failed to load HRV: $e'),
      data: (samples) {
        if (samples.isEmpty) {
          return const _EmptyState(
              message: 'No HRV recorded in this period.');
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

        final rmssds = samples.map((s) => s.rmssdMs).toList();
        final avgRmssd = rmssds.reduce((a, b) => a + b) / rmssds.length;
        final sdnnValues = samples
            .map((s) => s.sdnnMs)
            .whereType<double>()
            .toList();
        final avgSdnn = sdnnValues.isEmpty
            ? null
            : sdnnValues.reduce((a, b) => a + b) / sdnnValues.length;
        final daysRecorded =
            daily.values.where((b) => b.count > 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrendChartCard(
              title: 'Heart Rate Variability',
              subtitle: period == Period.week
                  ? 'Daily average across the week (RMSSD)'
                  : 'Daily average across the month (RMSSD)',
              points: points,
              color: AppColors.respiratory,
              axis: const TrendAxis.bounded(
                min: 10,
                max: 100,
                referenceMin: 30,
                referenceMax: 60,
              ),
              showDots: true,
              bottomLabels: _axisLabels(period, anchor),
            ),
            const SizedBox(height: 16),
            MetricGrid(
              tiles: [
                MetricTile(
                  label: 'Average RMSSD',
                  reference: 'Reference: 30~60 ms',
                  value: avgRmssd.toStringAsFixed(0),
                  valueUnit: 'ms',
                  status: statusFor(
                    value: avgRmssd,
                    ok: const MetricRange(30, 60),
                  ),
                ),
                MetricTile(
                  label: 'Average SDNN',
                  reference: avgSdnn == null ? '' : 'Beat-to-beat variation',
                  value: avgSdnn == null ? '--' : avgSdnn.toStringAsFixed(0),
                  valueUnit: avgSdnn == null ? null : 'ms',
                ),
                MetricTile(
                  label: 'Days recorded',
                  reference: '',
                  value: daysRecorded.toString(),
                ),
                MetricTile(
                  label: 'Samples',
                  reference: '30-min slots',
                  value: samples.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _RangeLegend(),
            const SizedBox(height: 16),
            const _DisclaimerCard(),
          ],
        );
      },
    );
  }
}

// ─── Range legend (RMSSD reference chips) ─────────────────────────────────

class _RangeLegend extends StatelessWidget {
  const _RangeLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RMSSD reference',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          _legendRow(
            color: AppColors.warning,
            label: 'Low',
            range: '<30 ms',
            note: 'Often seen after stress, poor sleep, or illness',
          ),
          const SizedBox(height: 8),
          _legendRow(
            color: AppColors.success,
            label: 'Normal',
            range: '30~60 ms',
            note: 'Typical healthy adult range',
          ),
          const SizedBox(height: 8),
          _legendRow(
            color: AppColors.respiratory,
            label: 'High',
            range: '>60 ms',
            note: 'Common in well-recovered or athletic users',
          ),
          const SizedBox(height: 10),
          const Text(
            'HRV varies widely between individuals — your personal trend over time matters more than the absolute number.',
            style: TextStyle(
                color: AppColors.textTertiary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required String range,
    required String note,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              children: [
                TextSpan(
                    text: '$label  ',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w600)),
                TextSpan(
                    text: '$range  ',
                    style: const TextStyle(color: AppColors.textPrimary)),
                TextSpan(text: '— $note'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Range helpers ────────────────────────────────────────────────────────

HrvRange _dayRange(DateTime anchor) {
  final start = DateTime(anchor.year, anchor.month, anchor.day);
  final end = start.add(const Duration(days: 1));
  return HrvRange(from: start.toUtc(), to: end.toUtc());
}

HrvRange _resolveRange(Period p, DateTime a) {
  switch (p) {
    case Period.day:
      return _dayRange(a);
    case Period.week:
      final monday = a.subtract(Duration(days: a.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = start.add(const Duration(days: 7));
      return HrvRange(from: start.toUtc(), to: end.toUtc());
    case Period.month:
      final first = DateTime(a.year, a.month, 1);
      final next = DateTime(a.year, a.month + 1, 1);
      return HrvRange(from: first.toUtc(), to: next.toUtc());
  }
}

class _DailyAvg {
  _DailyAvg();
  double sum = 0;
  int count = 0;
  double get avg => count == 0 ? 0 : sum / count;
}

/// Bucket samples by local day, returning a map keyed by day-start
/// (local midnight) → running average. Empty days are pre-seeded with a
/// zero-count entry so the chart shows a continuous X-axis.
Map<DateTime, _DailyAvg> _dailyAverages(
    List<HrvSample> samples, Period period, DateTime anchor) {
  final out = <DateTime, _DailyAvg>{};

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
  }
  for (final d in days) {
    out[d] = _DailyAvg();
  }

  for (final s in samples) {
    final local = s.capturedAt.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    final bucket = out[key];
    if (bucket == null) continue;
    bucket.sum += s.rmssdMs;
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
  }
}

// ─── Empty state + disclaimer ─────────────────────────────────────────────

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
          const Icon(Icons.show_chart,
              color: AppColors.respiratory, size: 28),
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
        'HRV is derived from beat-to-beat intervals captured by the band\'s '
        'optical PPG sensor. Measurements are affected by motion, fit, and '
        'wake state. Not for medical use — consult a healthcare professional '
        'for any concerns.',
        style: TextStyle(
            color: AppColors.textSecondary, fontSize: 12, height: 1.4),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────

String _timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
