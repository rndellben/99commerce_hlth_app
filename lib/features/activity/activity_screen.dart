import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:hlth_app/features/activity/activity_providers.dart';
import 'package:hlth_app/features/activity/widgets/vo2max_card.dart';
import 'package:hlth_app/features/activity/widgets/workout_prompt_banner.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/date_selector.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';
import 'package:hlth_app/ui/widgets/period_toggle.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';

/// Activity detail screen mirroring the Sleep screen's Day / Week / Month
/// layout: a steps headline with progress ring, a trend chart of the
/// selected period, a 3-across stats grid, and an exercise-history slot
/// (empty until HLT-19 lands ExerciseSession ingestion).
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const int _stepGoal = 10000;
  static const double _calorieGoal = 2000;
  static const double _distanceGoalKm = 5;
  static const int _activeMinGoal = 30;

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

  /// SyncService's step paths (`syncSteps`, `syncStepBuckets`) only fetch
  /// "today" — H59 doesn't expose a per-day step API. Historical days
  /// just read out of local SQLite. So this is unconditional "pull today"
  /// regardless of which date the user is browsing.
  Future<void> _refreshFromBand() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device == null) return; // not paired — silently skip
      final sync = ref.read(syncServiceProvider);
      final stepsResult =
          await sync.syncSteps(userId: ActiveSession.defaultUserId);
      final bucketsResult = await sync.syncStepBuckets(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
      );
      if (!mounted) return;
      // The provider streams off Drift, so upserts surface automatically;
      // we still invalidate today's date families to nudge any cached
      // FutureProvider consumers (defensive — Drift watch should suffice).
      ref.invalidate(dailyMetricsForDateProvider);
      ref.invalidate(stepBucketsForDateProvider);
      ref.invalidate(dailyMetricsInRangeProvider);
      final hadError = stepsResult.error != null || bucketsResult.error != null;
      final msg = hadError
          ? 'Activity sync had errors: ${stepsResult.error ?? bucketsResult.error}'
          : 'Synced ${stepsResult.count} steps · ${bucketsResult.count} buckets';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activity sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Activity'),
        centerTitle: true,
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
                const WorkoutPromptBanner(),
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
                if (_period == Period.day)
                  _DayView(anchor: _anchor, stepGoal: _stepGoal)
                else
                  _RangeView(
                    period: _period,
                    anchor: _anchor,
                    stepGoal: _stepGoal,
                    calorieGoal: _calorieGoal,
                    distanceGoalKm: _distanceGoalKm,
                    activeMinGoal: _activeMinGoal,
                  ),
                const SizedBox(height: 24),
                const _RecentExercisesSection(),
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
      // Refresh today's totals from the band — useful even when browsing
      // history because the user often arrives expecting fresh "today"
      // values. Historical days resolve from local SQLite regardless.
      _refreshFromBand();
    };
  }
}

const double _calorieGoalConst = 2000;
const double _distanceGoalKmConst = 5;
const int _activeMinGoalConst = 30;

// ─── Day view ──────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  const _DayView({required this.anchor, required this.stepGoal});
  final DateTime anchor;
  final int stepGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dailyMetricsForDateProvider(anchor));
    final bucketsAsync = ref.watch(stepBucketsForDateProvider(anchor));

    return metricsAsync.when(
      loading: () => const _LoadingBlock(),
      error: (e, _) => _EmptyState(message: 'Failed to load activity: $e'),
      data: (metrics) {
        final steps = metrics?.steps ?? 0;
        final calories = metrics?.caloriesKcal ?? 0;
        final distanceKm = (metrics?.distanceM ?? 0) / 1000.0;
        final activeMin = metrics?.activeMinutes ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepsHeadline(steps: steps, goal: stepGoal),
            const SizedBox(height: 16),
            _DayTrendCard(bucketsAsync: bucketsAsync, anchor: anchor),
            const SizedBox(height: 16),
            _StatsGrid(
              caloriesKcal: calories,
              distanceKm: distanceKm,
              activeMinutes: activeMin,
            ),
            const SizedBox(height: 16),
            const Vo2MaxCard(),
          ],
        );
      },
    );
  }
}

class _StepsHeadline extends StatelessWidget {
  const _StepsHeadline({required this.steps, required this.goal});
  final int steps;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.activity),
                  ),
                ),
                const Icon(Icons.directions_walk,
                    color: AppColors.activity, size: 36),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSteps(steps),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'steps',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Goal: ${_formatSteps(goal)}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: AppColors.activity,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSteps(int n) {
  // Thin-space thousands grouping (e.g. 10 000) — keeps it locale-light
  // without pulling in `intl` just for this screen.
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class _DayTrendCard extends StatelessWidget {
  const _DayTrendCard({required this.bucketsAsync, required this.anchor});
  final AsyncValue<List<StepBucket>> bucketsAsync;
  final DateTime anchor;

  @override
  Widget build(BuildContext context) {
    return bucketsAsync.when(
      loading: () => const _ChartShimmer(),
      error: (e, _) => TrendChartCard(
        points: const [],
        color: AppColors.activity,
        title: 'Steps throughout the day',
        subtitle: 'Failed to load buckets',
      ),
      data: (buckets) {
        final points = buckets
            .map((b) => TrendPoint(
                  at: b.bucketStartAt.toLocal(),
                  value: b.steps.toDouble(),
                ))
            .toList(growable: false);
        return TrendChartCard(
          points: points,
          color: AppColors.activity,
          title: 'Steps throughout the day',
          subtitle: '15-minute buckets',
          bottomLabels: const ['00:00', '12:00', '23:59'],
        );
      },
    );
  }
}

// ─── Week / Month view ────────────────────────────────────────────────────

class _RangeView extends ConsumerWidget {
  const _RangeView({
    required this.period,
    required this.anchor,
    required this.stepGoal,
    required this.calorieGoal,
    required this.distanceGoalKm,
    required this.activeMinGoal,
  });
  final Period period;
  final DateTime anchor;
  final int stepGoal;
  final double calorieGoal;
  final double distanceGoalKm;
  final int activeMinGoal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = _resolveRange(period, anchor);
    final async = ref.watch(dailyMetricsInRangeProvider(range));
    return async.when(
      loading: () => const _LoadingBlock(),
      error: (e, _) => _EmptyState(message: 'Failed to load activity: $e'),
      data: (rows) {
        // Average is calculated over days with non-null steps so a
        // partial week (e.g. mid-week view) doesn't dilute the headline.
        final stepDays = rows.where((r) => (r.steps ?? 0) > 0).toList();
        final avgSteps = stepDays.isEmpty
            ? 0
            : (stepDays.fold<int>(0, (a, r) => a + (r.steps ?? 0)) /
                    stepDays.length)
                .round();
        final calDays =
            rows.where((r) => (r.caloriesKcal ?? 0) > 0).toList();
        final avgCalories = calDays.isEmpty
            ? 0.0
            : calDays.fold<double>(0, (a, r) => a + (r.caloriesKcal ?? 0)) /
                calDays.length;
        final distDays = rows.where((r) => (r.distanceM ?? 0) > 0).toList();
        final avgDistanceKm = distDays.isEmpty
            ? 0.0
            : distDays.fold<int>(0, (a, r) => a + (r.distanceM ?? 0)) /
                distDays.length /
                1000;
        final activeDays =
            rows.where((r) => (r.activeMinutes ?? 0) > 0).toList();
        final avgActive = activeDays.isEmpty
            ? 0
            : (activeDays.fold<int>(0, (a, r) => a + (r.activeMinutes ?? 0)) /
                    activeDays.length)
                .round();

        final points = _pointsForRange(period, anchor, rows);
        final bottomLabels = _bottomLabelsForRange(period, anchor);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepsHeadline(steps: avgSteps, goal: stepGoal),
            const SizedBox(height: 16),
            TrendChartCard(
              points: points,
              color: AppColors.activity,
              title: period == Period.week
                  ? 'Daily steps this week'
                  : 'Daily steps this month',
              subtitle: 'Daily average: ${_formatSteps(avgSteps)}',
              bottomLabels: bottomLabels,
            ),
            const SizedBox(height: 16),
            _StatsGrid(
              caloriesKcal: avgCalories,
              distanceKm: avgDistanceKm,
              activeMinutes: avgActive,
            ),
          ],
        );
      },
    );
  }

  ActivityRange _resolveRange(Period p, DateTime a) {
    switch (p) {
      case Period.day:
        final d = DateTime(a.year, a.month, a.day);
        return ActivityRange(from: d, to: d);
      case Period.week:
        final monday = a.subtract(Duration(days: a.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        return ActivityRange(
            from: start, to: start.add(const Duration(days: 6)));
      case Period.month:
        final first = DateTime(a.year, a.month, 1);
        final last = DateTime(a.year, a.month + 1, 0);
        return ActivityRange(from: first, to: last);
    }
  }

  List<TrendPoint> _pointsForRange(
      Period p, DateTime anchor, List<DailyMetrics> rows) {
    // Index by yyyy-mm-dd so missing days plot as zero rather than
    // collapsing the X axis.
    final byDay = <String, DailyMetrics>{
      for (final r in rows) ymd(r.localDate): r,
    };
    final days = _daysInPeriod(p, anchor);
    return days
        .map((d) => TrendPoint(
              at: d,
              value: (byDay[ymd(d)]?.steps ?? 0).toDouble(),
            ))
        .toList(growable: false);
  }

  List<DateTime> _daysInPeriod(Period p, DateTime anchor) {
    switch (p) {
      case Period.day:
        return [DateTime(anchor.year, anchor.month, anchor.day)];
      case Period.week:
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return List.generate(
            7, (i) => DateTime(monday.year, monday.month, monday.day + i));
      case Period.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        final days = next.difference(first).inDays;
        return List.generate(
            days, (i) => DateTime(first.year, first.month, 1 + i));
    }
  }

  List<String> _bottomLabelsForRange(Period p, DateTime anchor) {
    switch (p) {
      case Period.day:
        return const ['00:00', '12:00', '23:59'];
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
}

// ─── Stats grid (Calories / Distance / Active min) ────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.caloriesKcal,
    required this.distanceKm,
    required this.activeMinutes,
  });
  final double caloriesKcal;
  final double distanceKm;
  final int activeMinutes;

  @override
  Widget build(BuildContext context) {
    return MetricGrid(
      tiles: [
        MetricTile(
          label: 'Calories',
          reference: 'Reference: ${_calorieGoalConst.round()} kcal',
          value: caloriesKcal <= 0
              ? '--'
              : caloriesKcal.toStringAsFixed(0),
          valueUnit: 'kcal',
          status: caloriesKcal <= 0
              ? MetricStatus.none
              : statusFor(
                  value: caloriesKcal,
                  ok: MetricRange(_calorieGoalConst, _calorieGoalConst * 2),
                ),
        ),
        MetricTile(
          label: 'Distance',
          reference: 'Reference: ${_distanceGoalKmConst.toStringAsFixed(0)} km',
          value: distanceKm <= 0 ? '--' : distanceKm.toStringAsFixed(2),
          valueUnit: 'km',
          status: distanceKm <= 0
              ? MetricStatus.none
              : statusFor(
                  value: distanceKm,
                  ok: MetricRange(
                      _distanceGoalKmConst, _distanceGoalKmConst * 4),
                ),
        ),
        MetricTile(
          label: 'Active minutes',
          reference: 'Reference: $_activeMinGoalConst min',
          value: activeMinutes <= 0 ? '--' : activeMinutes.toString(),
          valueUnit: 'min',
          status: activeMinutes <= 0
              ? MetricStatus.none
              : statusFor(
                  value: activeMinutes.toDouble(),
                  ok: MetricRange(
                      _activeMinGoalConst.toDouble(),
                      (_activeMinGoalConst * 4).toDouble()),
                ),
        ),
      ],
    );
  }
}

// ─── Recent exercises ──────────────────────────────────────────────────────

class _RecentExercisesSection extends StatelessWidget {
  const _RecentExercisesSection();

  @override
  Widget build(BuildContext context) {
    // ExerciseSession model/repo doesn't exist yet (HLT-19 lands it).
    // Until then always show the empty state.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Recent Exercises',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: const [
              Icon(Icons.fitness_center,
                  color: AppColors.activity, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No exercises recorded yet — start a 10+ minute walk or run to estimate your fitness level.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Misc ──────────────────────────────────────────────────────────────────

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ChartShimmer extends StatelessWidget {
  const _ChartShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

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
          const Icon(Icons.directions_walk,
              color: AppColors.activity, size: 28),
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
