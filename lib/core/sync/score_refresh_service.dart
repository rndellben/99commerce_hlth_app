import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/services/cardio_load_service.dart';
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
  });

  final RecoveryScoreService recoveryScore;
  final CardioLoadService cardioLoad;
  final Vo2MaxService vo2Max;

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
  Future<void> refreshAfterAggregation({required String userId}) async {
    final today = DateTime.now();
    for (var d = _scoreBackfillDays; d >= 0; d--) {
      try {
        await recoveryScore.computeForDay(
          userId: userId,
          localDate: today.subtract(Duration(days: d)),
        );
      } catch (_) {}
    }

    try {
      await cardioLoad.computeRecentNights(
        userId: userId,
        nights: _cardioLoadBackfillNights,
      );
    } catch (_) {}

    try {
      await vo2Max.computeForDay(userId: userId, localDate: DateTime.now());
    } catch (_) {}
  }
}

final scoreRefreshServiceProvider = Provider<ScoreRefreshService>((ref) {
  return ScoreRefreshService(
    recoveryScore: ref.watch(recoveryScoreServiceProvider),
    cardioLoad: ref.watch(cardioLoadServiceProvider),
    vo2Max: ref.watch(vo2MaxServiceProvider),
  );
});
