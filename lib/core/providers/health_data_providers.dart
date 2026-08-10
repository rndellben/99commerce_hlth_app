import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';

/// App-wide reactive read-models over the local database.
///
/// These providers are the shared UI-facing surface for health data —
/// every screen that shows "latest HR" or "today's metrics" watches the
/// SAME provider, so a repository upsert anywhere (e.g. after a band
/// sync) propagates to every watching card with no manual invalidation.
///
/// Extracted from `features/home/home_providers.dart`, which had become a
/// de-facto shared kernel imported by 7+ other features.
///
/// NOTE: the date-anchored providers capture the wall clock when first
/// built; `app.dart` invalidates them on app-resume so "today" stays
/// current across day boundaries.

// ─── Daily metrics ────────────────────────────────────────────────────────────

/// Today's `daily_metrics` row (null until the aggregator has run).
final todayDailyMetricsProvider = StreamProvider<DailyMetrics?>((ref) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  final today = DateTime.now();
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(today.year, today.month, today.day),
  );
});

/// `daily_metrics` row for a specific local date. Streams so detail
/// screens update as soon as `syncSteps` lands a fresh aggregate.
final dailyMetricsForDateProvider =
    StreamProvider.family<DailyMetrics?, DateTime>((ref, localDate) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(localDate.year, localDate.month, localDate.day),
  );
});

// ─── Latest sample providers ─────────────────────────────────────────────────

final latestHrSampleProvider = StreamProvider<HrSample?>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestSpo2SampleProvider = StreamProvider<Spo2Sample?>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestHrvSampleProvider = StreamProvider<HrvSample?>((ref) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestBpReadingProvider = StreamProvider<BpReading?>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestStressSampleProvider = StreamProvider<StressSample?>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

// ─── Score providers ─────────────────────────────────────────────────────────

final latestRecoveryScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.recovery,
  );
});

final latestCardioLoadScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.cardioLoad,
  );
});

final latestWellnessScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.wellness,
  );
});

// ─── Sparkline providers (last 24h sample series) ────────────────────────────

DateTime _last24hCutoff() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 24));

final hrSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.bpm.toDouble()).toList());
});

final spo2SparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.pctMin.toDouble()).toList());
});

final hrvSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.rmssdMs).toList());
});

final bpSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.systolicMmhg.toDouble()).toList());
});

final stressSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.stressScore.toDouble()).toList());
});

/// Today's stress samples (full day) — for the Day tab on the detail screen.
final todayStressSamplesProvider = StreamProvider<List<StressSample>>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc();
  final end = start.add(const Duration(days: 1));
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: start,
    to: end,
  );
});
