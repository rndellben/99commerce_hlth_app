import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/daily_metrics.dart';

/// hlth-repository-api.md §4.6
abstract class DailyMetricsRepository {
  Future<DailyMetrics?> getForDay({
    required String userId,
    required DateTime localDate,
  });

  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  });

  Stream<DailyMetrics?> watchForDay({
    required String userId,
    required DateTime localDate,
  });

  Stream<List<DailyMetrics>> watchInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  });

  Future<void> upsert(DailyMetrics row);
  Future<void> upsertMany(List<DailyMetrics> rows);

  Future<bool> hasDataForDay({
    required String userId,
    required DateTime localDate,
  });

  /// HLT-12: soft-delete (sets `deleted_at_utc`) any daily_metrics row
  /// whose `local_date` is before `cutoff`. `localDate` is stored as TEXT
  /// in ISO-8601 YYYY-MM-DD form, which sorts lexicographically the same
  /// as chronologically — so a string compare is correct. Returns
  /// affected row count.
  Future<int> softDeleteBefore(DateTime cutoff);
}

class DailyMetricsRepositoryImpl implements DailyMetricsRepository {
  DailyMetricsRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
  String _dateOnly(DateTime dt) => dt.toIso8601String().substring(0, 10);

  DailyMetrics _rowToDomain(db.DailyMetric r) => DailyMetrics(
        id: r.id,
        userId: r.userId,
        localDate: DateTime.parse(r.localDate),
        tzOffsetMin: r.tzOffsetMin,
        restingHrBpm: r.restingHrBpm,
        hrvRmssdMs: r.hrvRmssdMs,
        hrvSdnnMs: r.hrvSdnnMs,
        restingRespRateBpm: r.restingRespRateBpm,
        spo2OvernightAvg: r.spo2OvernightAvg,
        spo2OvernightMin: r.spo2OvernightMin,
        systolicMmhg: r.systolicMmhg,
        diastolicMmhg: r.diastolicMmhg,
        sleepTotalMin: r.sleepTotalMin,
        sleepDeepPct: r.sleepDeepPct,
        sleepRemPct: r.sleepRemPct,
        sleepLightPct: r.sleepLightPct,
        sleepEfficiencyPct: r.sleepEfficiencyPct,
        bedtime: r.bedtimeUtc == null ? null : _toDt(r.bedtimeUtc!),
        wake: r.wakeUtc == null ? null : _toDt(r.wakeUtc!),
        steps: r.steps,
        distanceM: r.distanceM,
        caloriesKcal: r.caloriesKcal,
        activeMinutes: r.activeMinutes,
        stiffnessIndex: r.stiffnessIndex,
        augmentationIndex: r.augmentationIndex,
        strokeVolumeIndex: r.strokeVolumeIndex,
        breathingDisruptionsHr: r.breathingDisruptionsHr,
        recoveryScore: r.recoveryScore,
        wellnessScore: r.wellnessScore,
        cyclePhase: r.cyclePhase,
        computedAt: _toDt(r.computedAtUtc),
        algorithmVersion: r.algorithmVersion,
        source: r.source,
      );

  db.DailyMetricsCompanion _toCompanion(DailyMetrics m) =>
      db.DailyMetricsCompanion.insert(
        id: m.id,
        userId: m.userId,
        localDate: _dateOnly(m.localDate),
        tzOffsetMin: m.tzOffsetMin,
        restingHrBpm: Value(m.restingHrBpm),
        hrvRmssdMs: Value(m.hrvRmssdMs),
        hrvSdnnMs: Value(m.hrvSdnnMs),
        restingRespRateBpm: Value(m.restingRespRateBpm),
        spo2OvernightAvg: Value(m.spo2OvernightAvg),
        spo2OvernightMin: Value(m.spo2OvernightMin),
        systolicMmhg: Value(m.systolicMmhg),
        diastolicMmhg: Value(m.diastolicMmhg),
        sleepTotalMin: Value(m.sleepTotalMin),
        sleepDeepPct: Value(m.sleepDeepPct),
        sleepRemPct: Value(m.sleepRemPct),
        sleepLightPct: Value(m.sleepLightPct),
        sleepEfficiencyPct: Value(m.sleepEfficiencyPct),
        bedtimeUtc: Value(m.bedtime == null ? null : _toSec(m.bedtime!)),
        wakeUtc: Value(m.wake == null ? null : _toSec(m.wake!)),
        steps: Value(m.steps),
        distanceM: Value(m.distanceM),
        caloriesKcal: Value(m.caloriesKcal),
        activeMinutes: Value(m.activeMinutes),
        stiffnessIndex: Value(m.stiffnessIndex),
        augmentationIndex: Value(m.augmentationIndex),
        strokeVolumeIndex: Value(m.strokeVolumeIndex),
        breathingDisruptionsHr: Value(m.breathingDisruptionsHr),
        recoveryScore: Value(m.recoveryScore),
        wellnessScore: Value(m.wellnessScore),
        cyclePhase: Value(m.cyclePhase),
        computedAtUtc: _toSec(m.computedAt),
        algorithmVersion: m.algorithmVersion,
        source: m.source,
      );

  @override
  Future<DailyMetrics?> getForDay({
    required String userId,
    required DateTime localDate,
  }) async {
    final row = await (_db.select(_db.dailyMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.equals(_dateOnly(localDate)) &
              t.deletedAtUtc.isNull()))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<DailyMetrics>> getInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final rows = await (_db.select(_db.dailyMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.isBiggerOrEqualValue(_dateOnly(fromDate)) &
              t.localDate.isSmallerOrEqualValue(_dateOnly(toDate)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.localDate)]))
        .get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Stream<DailyMetrics?> watchForDay({
    required String userId,
    required DateTime localDate,
  }) {
    return (_db.select(_db.dailyMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.equals(_dateOnly(localDate)) &
              t.deletedAtUtc.isNull()))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToDomain(row));
  }

  @override
  Stream<List<DailyMetrics>> watchInRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return (_db.select(_db.dailyMetrics)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.isBiggerOrEqualValue(_dateOnly(fromDate)) &
              t.localDate.isSmallerOrEqualValue(_dateOnly(toDate)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.localDate)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Future<void> upsert(DailyMetrics row) async {
    await _db.into(_db.dailyMetrics).insertOnConflictUpdate(_toCompanion(row));
  }

  @override
  Future<void> upsertMany(List<DailyMetrics> rows) async {
    await _db.batch((b) {
      for (final r in rows) {
        b.insert(_db.dailyMetrics, _toCompanion(r),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<bool> hasDataForDay({
    required String userId,
    required DateTime localDate,
  }) async {
    final r = await getForDay(userId: userId, localDate: localDate);
    if (r == null) return false;
    // Any non-null metric counts as "data exists"
    return r.restingHrBpm != null ||
        r.hrvRmssdMs != null ||
        r.spo2OvernightAvg != null ||
        r.steps != null ||
        r.sleepTotalMin != null;
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.dailyMetrics)
          ..where((t) =>
              t.localDate.isSmallerThanValue(_dateOnly(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.DailyMetricsCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }
}

final dailyMetricsRepositoryProvider =
    Provider<DailyMetricsRepository>((ref) {
  return DailyMetricsRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
