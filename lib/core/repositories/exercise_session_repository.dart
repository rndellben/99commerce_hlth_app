import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/exercise_session.dart';
import 'package:uuid/uuid.dart';

abstract class ExerciseSessionRepository {
  /// Persist a band workout summary (idempotent on the dedup key). Returns the
  /// row's id — whether newly inserted or already present — so callers can
  /// trigger per-session scoring (VO2 max).
  Future<String?> upsertFromBand({
    required String userId,
    required String deviceId,
    required SportSessionSummary summary,
  });

  Future<ExerciseSession?> getById(String id);
  Stream<List<ExerciseSession>> watchForUser({required String userId, int limit = 50});
  Stream<ExerciseSession?> watchLatest({required String userId});

  /// Sessions started within [from, to] (UTC), ascending by start time.
  /// Used by Vo2MaxService to build the rolling-average trend.
  Future<List<ExerciseSession>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  /// Persist a computed VO2 max estimate back onto a session row.
  Future<void> updateVo2({
    required String sessionId,
    required double? vo2maxMl,
    required double? vo2Confidence,
  });
}

class ExerciseSessionRepositoryImpl implements ExerciseSessionRepository {
  ExerciseSessionRepositoryImpl(this._db);
  final db.AppDatabase _db;
  final _uuid = const Uuid();

  @override
  Future<String?> upsertFromBand({
    required String userId,
    required String deviceId,
    required SportSessionSummary summary,
  }) async {
    final startedAtUtc = summary.startTimeUnixSec;
    final endedAtUtc = startedAtUtc + summary.durationSec;
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    const source = DataSource.bandScheduled;
    await _db.into(_db.exerciseSessions).insert(
          db.ExerciseSessionsCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            deviceId: deviceId,
            sportType: summary.sportType,
            startedAtUtc: startedAtUtc,
            endedAtUtc: Value(endedAtUtc),
            durationSec: summary.durationSec,
            distanceM: Value(summary.distanceM),
            calories: Value(summary.calories),
            avgSpeedCmS: Value(summary.avgSpeedCmS),
            maxSpeedCmS: Value(summary.maxSpeedCmS),
            avgHrBpm: Value(summary.avgHr > 0 ? summary.avgHr : null),
            minHrBpm: Value(summary.minHr > 0 ? summary.minHr : null),
            maxHrBpm: Value(summary.maxHr > 0 ? summary.maxHr : null),
            steps: Value(summary.steps > 0 ? summary.steps : null),
            stepRate: Value(summary.stepRate > 0 ? summary.stepRate : null),
            elevationCm: Value(summary.elevationCm),
            uphillCm: Value(summary.uphillCm),
            downhillCm: Value(summary.downhillCm),
            source: source,
            createdAtUtc: nowSec,
          ),
          // The composite unique index (user_id, device_id, started_at_utc,
          // source) keeps us idempotent if the band re-syncs the same
          // workout twice.
          mode: InsertMode.insertOrIgnore,
        );
    // Resolve the row id on the dedup key (new insert or pre-existing).
    final row = await (_db.select(_db.exerciseSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.deviceId.equals(deviceId) &
              t.startedAtUtc.equals(startedAtUtc) &
              t.source.equals(source.index))
          ..limit(1))
        .getSingleOrNull();
    return row?.id;
  }

  @override
  Future<ExerciseSession?> getById(String id) async {
    final row = await (_db.select(_db.exerciseSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  @override
  Stream<List<ExerciseSession>> watchForUser({
    required String userId,
    int limit = 50,
  }) {
    return (_db.select(_db.exerciseSessions)
          ..where((t) =>
              t.userId.equals(userId) & t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm(
              expression: t.startedAtUtc, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  @override
  Stream<ExerciseSession?> watchLatest({required String userId}) {
    return watchForUser(userId: userId, limit: 1)
        .map((list) => list.isEmpty ? null : list.first);
  }

  @override
  Future<List<ExerciseSession>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromSec = from.toUtc().millisecondsSinceEpoch ~/ 1000;
    final toSec = to.toUtc().millisecondsSinceEpoch ~/ 1000;
    final rows = await (_db.select(_db.exerciseSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.deletedAtUtc.isNull() &
              t.startedAtUtc.isBiggerOrEqualValue(fromSec) &
              t.startedAtUtc.isSmallerOrEqualValue(toSec))
          ..orderBy([(t) => OrderingTerm(
              expression: t.startedAtUtc, mode: OrderingMode.asc)]))
        .get();
    return rows.map(_toModel).toList();
  }

  @override
  Future<void> updateVo2({
    required String sessionId,
    required double? vo2maxMl,
    required double? vo2Confidence,
  }) async {
    await (_db.update(_db.exerciseSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(db.ExerciseSessionsCompanion(
      vo2maxMl: Value(vo2maxMl),
      vo2Confidence: Value(vo2Confidence),
    ));
  }

  ExerciseSession _toModel(db.ExerciseSession d) => ExerciseSession(
        id: d.id,
        userId: d.userId,
        deviceId: d.deviceId,
        sportType: d.sportType,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          d.startedAtUtc * 1000,
          isUtc: true,
        ),
        endedAt: d.endedAtUtc == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                d.endedAtUtc! * 1000,
                isUtc: true,
              ),
        durationSec: d.durationSec,
        distanceM: d.distanceM,
        calories: d.calories,
        avgSpeedCmS: d.avgSpeedCmS,
        maxSpeedCmS: d.maxSpeedCmS,
        avgHrBpm: d.avgHrBpm,
        minHrBpm: d.minHrBpm,
        maxHrBpm: d.maxHrBpm,
        steps: d.steps,
        stepRate: d.stepRate,
        elevationCm: d.elevationCm,
        uphillCm: d.uphillCm,
        downhillCm: d.downhillCm,
        vo2maxMl: d.vo2maxMl,
        vo2Confidence: d.vo2Confidence,
        source: d.source,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          d.createdAtUtc * 1000,
          isUtc: true,
        ),
      );
}

final exerciseSessionRepositoryProvider =
    Provider<ExerciseSessionRepository>((ref) {
  return ExerciseSessionRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
