import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/services/cardio_load_service.dart';
import 'package:hlth_app/core/services/mental_wellness_service.dart';
import 'package:hlth_app/core/services/recovery_score_service.dart';
import 'package:hlth_app/core/services/vo2max_service.dart';

/// Recomputes the derived daily scores (Recovery, Cardio Load, VO2 Max)
/// after a band sync has re-aggregated `daily_metrics`. Split out of the
/// band-sync orchestrator so "pull samples off the band" and "refresh
/// derived scores" stay independently testable concerns.
///
/// Every recompute is non-fatal: a score engine failure must never break
/// the sync sweep that follows it on the next tick.
class ScoreRefreshService {
  ScoreRefreshService({
    required this.recoveryScore,
    required this.cardioLoad,
    required this.vo2Max,
    required this.mentalWellness,
  });

  final RecoveryScoreService recoveryScore;
  final CardioLoadService cardioLoad;
  final Vo2MaxService vo2Max;
  final MentalWellnessService mentalWellness;

  /// How many days back to recompute Recovery / Cardio Load each sync so scores
  /// "settle" once the H59 releases a night's HRV (which it only does the next
  /// day). 2 covers the same-day + next-day backfill with margin.
  static const _scoreBackfillDays = 2;

  /// Cardio Load recomputes a wider trailing window than Recovery. Its engine
  /// needs 4 banked *valid* nights before it produces, and a night only becomes
  /// valid once its sleep-window HRV is found. HRV was persisted all along but
  /// the sleep-window search missed it (a tz-frame mismatch, fixed in
  /// daily_aggregator/cardio_load_service), so historically NO night was valid.
  /// Re-reducing a week of already-persisted nights on each sync lets the count
  /// of valid nights bank quickly instead of one-per-day. Idempotent (nightly
  /// records + scores are date-keyed) and cheap (local DB + pure engine).
  static const _cardioLoadBackfillNights = 7;

  /// Recompute all derived scores off the freshly-aggregated rollups.
  ///
  /// Recovery recomputes the trailing 3 days (oldest → newest), not just
  /// today, because the H59 only serves a night's HRV starting the NEXT
  /// day — so a score computed the morning after a sleep is missing that
  /// night's HRV and must be re-run once it backfills. Oldest-first keeps
  /// Recovery's forward-only smoothing chain consistent.
  ///
  /// Cardio Load recomputes the trailing nights (same next-day-HRV reason;
  /// it REQUIRES sleep RMSSD, so last night is always noData until its HRV
  /// lands the next day).
  ///
  /// VO2 Max refreshes the rolling aerobic-fitness score. Idempotent over
  /// whatever per-session estimates exist; covers band-native workouts
  /// synced without going through the workout screen.
  /// Every catch below was bare. A consistently-throwing engine is
  /// indistinguishable from "not enough data yet" — which is the *expected*
  /// state for a new user, so nobody investigates. Each engine now names
  /// itself in a breadcrumb on failure.
  ///
  /// The two day-loops fold their failures into ONE crumb per engine per run
  /// rather than one per day: a broken engine at a 30-min tick cadence would
  /// otherwise write ~144 lines/day per engine and evict the narrative
  /// context that the 800-line ring buffer exists to preserve.
  Future<void> refreshAfterAggregation({required String userId}) async {
    final today = DateTime.now();
    var recoveryFailed = 0;
    Object? recoveryFirstError;
    for (var d = _scoreBackfillDays; d >= 0; d--) {
      try {
        await recoveryScore.computeForDay(
          userId: userId,
          localDate: today.subtract(Duration(days: d)),
        );
      } catch (e) {
        recoveryFailed++;
        recoveryFirstError ??= e;
      }
    }
    if (recoveryFailed > 0) {
      Breadcrumbs.log('scoreRefresh: recovery FAILED on $recoveryFailed/'
          '${_scoreBackfillDays + 1} days — $recoveryFirstError');
    }

    try {
      await cardioLoad.computeRecentNights(
        userId: userId,
        nights: _cardioLoadBackfillNights,
      );
    } catch (e) {
      Breadcrumbs.log('scoreRefresh: cardioLoad FAILED — $e');
    }

    try {
      await vo2Max.computeForDay(userId: userId, localDate: DateTime.now());
    } catch (e) {
      Breadcrumbs.log('scoreRefresh: vo2Max FAILED — $e');
    }

    // Mental Wellness reads the same trailing rollups; recompute the trailing
    // days (oldest → newest) so a day's score settles once its HRV backfills.
    var wellnessFailed = 0;
    Object? wellnessFirstError;
    for (var d = _scoreBackfillDays; d >= 0; d--) {
      try {
        await mentalWellness.computeForDay(
          userId: userId,
          localDate: today.subtract(Duration(days: d)),
        );
      } catch (e) {
        wellnessFailed++;
        wellnessFirstError ??= e;
      }
    }
    if (wellnessFailed > 0) {
      Breadcrumbs.log('scoreRefresh: mentalWellness FAILED on $wellnessFailed/'
          '${_scoreBackfillDays + 1} days — $wellnessFirstError');
    }
  }
}

final scoreRefreshServiceProvider = Provider<ScoreRefreshService>((ref) {
  return ScoreRefreshService(
    recoveryScore: ref.watch(recoveryScoreServiceProvider),
    cardioLoad: ref.watch(cardioLoadServiceProvider),
    vo2Max: ref.watch(vo2MaxServiceProvider),
    mentalWellness: ref.watch(mentalWellnessServiceProvider),
  );
});
