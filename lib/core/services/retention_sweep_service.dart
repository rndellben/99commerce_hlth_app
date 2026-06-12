import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';

/// Per-table sweep result. `error` non-null on failure; count is the
/// number of rows soft-deleted on this pass.
class RetentionSweepStepResult {
  const RetentionSweepStepResult({
    required this.table,
    required this.softDeletedCount,
    this.error,
  });

  final String table;
  final int softDeletedCount;
  final String? error;

  bool get ok => error == null;
}

/// Aggregate of a single sweep pass across every retention-managed table.
class RetentionSweepResult {
  const RetentionSweepResult({required this.steps, required this.sweptAt});

  final List<RetentionSweepStepResult> steps;
  final DateTime sweptAt;

  int get totalSoftDeleted =>
      steps.fold(0, (a, s) => a + s.softDeletedCount);
  Iterable<RetentionSweepStepResult> get failed =>
      steps.where((s) => !s.ok);
  bool get allOk => failed.isEmpty;
}

/// HLT-12: nightly retention sweep. Soft-deletes raw samples older than
/// 90 days and daily_metrics rows older than 1 year, per
/// `hlth-db-schema.md` §11.
///
/// **V1 scope:** soft-delete only. Hard delete (after a 14-day grace per
/// schema §11:1147) is deferred to HLT-13 — required once backend sync
/// needs the grace window for conflict resolution.
///
/// **Tables NOT swept here:**
///   * `baselines` — no `deleted_at_utc` column; would need a Drift
///     migration. Deferred.
///   * `sleep_epochs` — no `deleted_at_utc` column. Orphan epochs whose
///     parent session is soft-deleted become unreachable via the only
///     query path (`getEpochsForSession`), so they don't cause bugs;
///     they just sit on disk. ~9K rows/year/user, acceptable for V1.
///   * `exercise_sessions`, `bp_calibrations`, `scores` — documented as
///     indefinite-retention in schema §11.
class RetentionSweepService {
  RetentionSweepService({
    required this.hrRepo,
    required this.hrvRepo,
    required this.spo2Repo,
    required this.bpRepo,
    required this.stepBucketRepo,
    required this.sleepRepo,
    required this.dailyRepo,
  });

  final HrRepository hrRepo;
  final HrvRepository hrvRepo;
  final Spo2Repository spo2Repo;
  final BpRepository bpRepo;
  final StepBucketRepository stepBucketRepo;
  final SleepRepository sleepRepo;
  final DailyMetricsRepository dailyRepo;

  /// Retention windows per `hlth-db-schema.md` §11.
  static const rawRetentionDays = 90;
  static const dailyMetricsRetentionDays = 365;

  /// Sweeps every retention-managed table. `now` is injectable for tests;
  /// in production callers pass nothing and `DateTime.now().toUtc()` is
  /// used. Continues past per-table failures (each is recorded in steps).
  Future<RetentionSweepResult> sweepAll({DateTime? now}) async {
    final ts = now ?? DateTime.now().toUtc();
    final rawCutoff = ts.subtract(const Duration(days: rawRetentionDays));
    final dailyCutoff =
        ts.subtract(const Duration(days: dailyMetricsRetentionDays));

    final steps = <RetentionSweepStepResult>[
      await _sweep('hr_samples', () => hrRepo.softDeleteBefore(rawCutoff)),
      await _sweep('hrv_samples', () => hrvRepo.softDeleteBefore(rawCutoff)),
      await _sweep('spo2_samples', () => spo2Repo.softDeleteBefore(rawCutoff)),
      await _sweep('bp_readings', () => bpRepo.softDeleteBefore(rawCutoff)),
      await _sweep(
        'step_buckets',
        () => stepBucketRepo.softDeleteBefore(rawCutoff),
      ),
      await _sweep(
        'sleep_sessions',
        () => sleepRepo.softDeleteSessionsBefore(rawCutoff),
      ),
      await _sweep(
        'daily_metrics',
        () => dailyRepo.softDeleteBefore(dailyCutoff),
      ),
    ];

    return RetentionSweepResult(steps: steps, sweptAt: ts);
  }

  Future<RetentionSweepStepResult> _sweep(
    String table,
    Future<int> Function() op,
  ) async {
    try {
      final count = await op();
      return RetentionSweepStepResult(
        table: table,
        softDeletedCount: count,
      );
    } catch (e) {
      return RetentionSweepStepResult(
        table: table,
        softDeletedCount: 0,
        error: e.toString(),
      );
    }
  }
}

final retentionSweepServiceProvider = Provider<RetentionSweepService>((ref) {
  return RetentionSweepService(
    hrRepo: ref.watch(hrRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    spo2Repo: ref.watch(spo2RepositoryProvider),
    bpRepo: ref.watch(bpRepositoryProvider),
    stepBucketRepo: ref.watch(stepBucketRepositoryProvider),
    sleepRepo: ref.watch(sleepRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});
