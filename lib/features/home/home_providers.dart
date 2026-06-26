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

/// Today's `daily_metrics` row (null until the aggregator has run).
final todayDailyMetricsProvider = StreamProvider<DailyMetrics?>((ref) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  final today = DateTime.now();
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(today.year, today.month, today.day),
  );
});

/// Latest stored HR sample (any time, any source).
final latestHrSampleProvider = StreamProvider<HrSample?>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest stored SpO2 sample.
final latestSpo2SampleProvider = StreamProvider<Spo2Sample?>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest stored HRV sample.
final latestHrvSampleProvider = StreamProvider<HrvSample?>((ref) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest stored BP reading.
final latestBpReadingProvider = StreamProvider<BpReading?>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest stored stress sample.
final latestStressSampleProvider = StreamProvider<StressSample?>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest computed Recovery / Stability score (null until ≥4 valid nights).
final latestRecoveryScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.recovery,
  );
});

/// Latest computed Cardio Load score (null until the baseline has matured).
final latestCardioLoadScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.cardioLoad,
  );
});

// ─── Sparkline (last-24h sample series) providers for the home cards.
//
// Each one returns a plain `List<double>` for HealthMetricCard's
// `sparkline` param. Returning a value list rather than the full sample
// rows keeps the cards decoupled from sample schema changes.

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
