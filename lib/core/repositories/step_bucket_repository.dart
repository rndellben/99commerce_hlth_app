import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/step_bucket.dart';

/// hlth-repository-api.md §4.5
abstract class StepBucketRepository {
  Future<void> insert(StepBucket bucket);
  Future<void> insertMany(List<StepBucket> buckets);

  Future<List<StepBucket>> getForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  });

  Stream<List<StepBucket>> watchForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  });

  Future<int> getTotalStepsForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  });

  /// HLT-12: soft-delete (sets `deleted_at_utc`) any bucket whose
  /// `bucket_start_at_utc` is older than `cutoff`. Returns affected row
  /// count. Hard delete deferred until a backend-sync grace period needs it.
  Future<int> softDeleteBefore(DateTime cutoff);
}

class StepBucketRepositoryImpl implements StepBucketRepository {
  StepBucketRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  StepBucket _rowToDomain(db.StepBucket r) => StepBucket(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        bucketStartAt: _toDt(r.bucketStartAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        steps: r.steps,
        distanceM: r.distanceM,
        caloriesKcal: r.caloriesKcal,
        runSteps: r.runSteps,
        source: r.source,
      );

  db.StepBucketsCompanion _toCompanion(StepBucket s) =>
      db.StepBucketsCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        bucketStartAtUtc: _toSec(s.bucketStartAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        createdAtUtc: _toSec(DateTime.now()),
        steps: s.steps,
        distanceM: s.distanceM,
        caloriesKcal: s.caloriesKcal,
        runSteps: Value(s.runSteps),
      );

  @override
  Future<void> insert(StepBucket bucket) async {
    await _db.into(_db.stepBuckets).insertOnConflictUpdate(_toCompanion(bucket));
  }

  @override
  Future<void> insertMany(List<StepBucket> buckets) async {
    await _db.batch((b) {
      for (final s in buckets) {
        b.insert(_db.stepBuckets, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// `localDate` + `tzOffsetMin` → UTC window for that local day.
  /// Uses DateTime.utc + manual offset so the math is independent of the
  /// system clock's TZ (avoids the double-conversion bug that would
  /// happen if you called `.toUtc()` on a local-zoned DateTime AND
  /// subtracted tzOffsetMin).
  ({int from, int to}) _dayWindow(DateTime localDate, int tzOffsetMin) {
    final localMidnightAsUtc =
        DateTime.utc(localDate.year, localDate.month, localDate.day);
    final dayStartUtc =
        localMidnightAsUtc.subtract(Duration(minutes: tzOffsetMin));
    final dayEndUtc = dayStartUtc.add(const Duration(days: 1));
    return (from: _toSec(dayStartUtc), to: _toSec(dayEndUtc));
  }

  @override
  Future<List<StepBucket>> getForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  }) async {
    final w = _dayWindow(localDate, tzOffsetMin);
    final rows = await (_db.select(_db.stepBuckets)
          ..where((t) =>
              t.userId.equals(userId) &
              t.bucketStartAtUtc.isBetweenValues(w.from, w.to) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.bucketStartAtUtc)]))
        .get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Stream<List<StepBucket>> watchForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  }) {
    final w = _dayWindow(localDate, tzOffsetMin);
    return (_db.select(_db.stepBuckets)
          ..where((t) =>
              t.userId.equals(userId) &
              t.bucketStartAtUtc.isBetweenValues(w.from, w.to) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.bucketStartAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Future<int> getTotalStepsForDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
  }) async {
    final w = _dayWindow(localDate, tzOffsetMin);
    final sum = _db.stepBuckets.steps.sum();
    final row = await (_db.selectOnly(_db.stepBuckets)
          ..addColumns([sum])
          ..where(_db.stepBuckets.userId.equals(userId) &
              _db.stepBuckets.bucketStartAtUtc.isBetweenValues(w.from, w.to) &
              _db.stepBuckets.deletedAtUtc.isNull()))
        .getSingle();
    return (row.read(sum) ?? 0).toInt();
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.stepBuckets)
          ..where((t) =>
              t.bucketStartAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.StepBucketsCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }
}

final stepBucketRepositoryProvider = Provider<StepBucketRepository>((ref) {
  return StepBucketRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
