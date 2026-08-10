import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/scoring/mental_wellness.dart';

/// Computes and persists the daily Mental Wellness ("Wellness Balance") score.
///
/// The engine (`mental_wellness.dart`) is the source of truth; this service
/// only ADAPTS our data into it: it pulls the trailing `daily_metrics` rows,
/// maps each to a [WellnessDay] (converting the stored bedtime to a wrap-safe
/// minute-of-evening for circadian variability), runs [computeMentalWellness]
/// over the window, and stores a `Score` of [ScoreType.wellness].
///
/// Triggered on the post-sleep sync tick after `daily_metrics` is aggregated,
/// alongside Recovery / Cardio Load / VO2 in [ScoreRefreshService].
class MentalWellnessService {
  MentalWellnessService({
    required this.dailyRepo,
    required this.scoreRepo,
  });

  final DailyMetricsRepository dailyRepo;
  final ScoreRepository scoreRepo;

  static const _algorithmVersion = 'mental-wellness-v1';

  /// Trailing days to pull — the engine's baseline is up to 30 days.
  static const _historyDays = 30;

  /// Compute the Wellness score for [localDate] and persist it. Returns the
  /// persisted [Score], or null when there's nothing to show yet (no rows, or
  /// still calibrating / no signal this week).
  Future<Score?> computeForDay({
    required String userId,
    required DateTime localDate,
  }) async {
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final from = day.subtract(const Duration(days: _historyDays));

    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: from,
      toDate: day,
    );
    if (rows.isEmpty) return null;

    // getInRange returns ascending by date; the engine expects today last.
    final history = rows.map(_toWellnessDay).toList();

    final prev = await scoreRepo.getPrevious(
      userId: userId,
      scoreType: ScoreType.wellness,
      beforeDate: day,
    );

    final result = computeMentalWellness(
      history: history,
      previousScore: prev?.score,
    );

    if (!result.produced || result.score == null) return null;

    final score = Score(
      id: ScoreRepository.idFor(userId, ScoreType.wellness, day),
      userId: userId,
      scoreType: ScoreType.wellness,
      computedForDate: day,
      score: result.score!,
      label: result.label,
      provisional: result.provisional,
      components: result.components,
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    );
    await scoreRepo.upsert(score);
    return score;
  }

  WellnessDay _toWellnessDay(DailyMetrics m) => WellnessDay(
        rmssd: m.hrvRmssdMs,
        rhr: m.restingHrBpm?.toDouble(),
        deepFraction: m.sleepDeepPct,
        efficiencyFraction: m.sleepEfficiencyPct,
        bedtimeMinutes: _bedtimeAnchoredMinutes(m.bedtime),
        steps: m.steps?.toDouble(),
      );

  /// Bedtime as minutes elapsed since 18:00 *local* time, so typical bedtimes
  /// (21:00–02:00) don't straddle the midnight wrap when we take their spread.
  /// Returns null when bedtime is unknown.
  double? _bedtimeAnchoredMinutes(DateTime? bedtimeUtc) {
    if (bedtimeUtc == null) return null;
    final local = bedtimeUtc.toLocal();
    final minutesOfDay = local.hour * 60 + local.minute;
    return ((minutesOfDay - 18 * 60) % (24 * 60)).toDouble();
  }
}

final mentalWellnessServiceProvider = Provider<MentalWellnessService>((ref) {
  return MentalWellnessService(
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    scoreRepo: ref.watch(scoreRepositoryProvider),
  );
});
