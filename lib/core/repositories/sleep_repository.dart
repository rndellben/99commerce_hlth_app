import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/sleep.dart';

/// hlth-repository-api.md §4.7 — v1 subset (create + range + epoch insert).
abstract class SleepRepository {
  Future<String> createSession(SleepSession session);
  Future<SleepSession?> getSessionById(String sessionId);
  Future<SleepSession?> getMostRecentNightFor(String userId);

  Future<List<SleepSession>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    SleepSessionType? type,
  });

  Stream<SleepSession?> watchMostRecentNight(String userId);

  Future<void> insertEpochs(String sessionId, List<SleepEpoch> epochs);
  Future<List<SleepEpoch>> getEpochsForSession(String sessionId);

  /// HLT-12: soft-delete (sets `deleted_at_utc`) any session whose
  /// `started_at_utc` is older than `cutoff`. Returns affected row count.
  ///
  /// TODO(HLT-13): sleep_epochs has no `deleted_at_utc` column. Orphan
  /// epochs whose parent session got soft-deleted become unreachable via
  /// `getEpochsForSession` (no one queries them once parent is hidden) but
  /// still occupy disk. When backend sync needs grace-period hard delete,
  /// add a schema migration that adds `deleted_at_utc` to sleep_epochs and
  /// cascade-delete on session soft-delete.
  Future<int> softDeleteSessionsBefore(DateTime cutoff);
}

class SleepRepositoryImpl implements SleepRepository {
  SleepRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  SleepSession _rowToSession(db.SleepSession r) => SleepSession(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        startedAt: _toDt(r.startedAtUtc),
        endedAt: _toDt(r.endedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        type: r.type,
        protocolVersion: r.protocolVersion,
        totalMin: r.totalMin,
        deepMin: r.deepMin,
        lightMin: r.lightMin,
        remMin: r.remMin,
        awakeMin: r.awakeMin,
        coverageGapMin: r.coverageGapMin,
        efficiencyPct: r.efficiencyPct,
        hasUnweared: r.hasUnweared,
        source: r.source,
      );

  SleepEpoch _rowToEpoch(db.SleepEpoch r) => SleepEpoch(
        id: r.id,
        sessionId: r.sessionId,
        userId: r.userId,
        startedAt: _toDt(r.startedAtUtc),
        durationMin: r.durationMin,
        stage: r.stage,
        source: r.source,
      );

  @override
  Future<String> createSession(SleepSession s) async {
    await _db.into(_db.sleepSessions).insertOnConflictUpdate(
          db.SleepSessionsCompanion.insert(
            id: s.id,
            userId: s.userId,
            deviceId: s.deviceId,
            startedAtUtc: _toSec(s.startedAt),
            capturedTzOffsetMin: s.tzOffsetMin,
            source: s.source,
            createdAtUtc: _toSec(DateTime.now()),
            endedAtUtc: _toSec(s.endedAt),
            type: s.type,
            protocolVersion: s.protocolVersion,
            totalMin: s.totalMin,
            deepMin: Value(s.deepMin),
            lightMin: Value(s.lightMin),
            remMin: Value(s.remMin),
            awakeMin: Value(s.awakeMin),
            coverageGapMin: Value(s.coverageGapMin),
            efficiencyPct: Value(s.efficiencyPct),
            hasUnweared: Value(s.hasUnweared),
          ),
        );
    return s.id;
  }

  @override
  Future<SleepSession?> getSessionById(String sessionId) async {
    final row = await (_db.select(_db.sleepSessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _rowToSession(row);
  }

  @override
  Future<SleepSession?> getMostRecentNightFor(String userId) async {
    final row = await (_db.select(_db.sleepSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equalsValue(SleepSessionType.night) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToSession(row);
  }

  @override
  Future<List<SleepSession>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    SleepSessionType? type,
  }) async {
    final q = _db.select(_db.sleepSessions)
      ..where((t) =>
          t.userId.equals(userId) &
          t.startedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
          t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.startedAtUtc)]);
    if (type != null) q.where((t) => t.type.equalsValue(type));
    final rows = await q.get();
    return rows.map(_rowToSession).toList();
  }

  @override
  Stream<SleepSession?> watchMostRecentNight(String userId) {
    return (_db.select(_db.sleepSessions)
          ..where((t) =>
              t.userId.equals(userId) &
              t.type.equalsValue(SleepSessionType.night) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAtUtc)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToSession(row));
  }

  @override
  Future<void> insertEpochs(String sessionId, List<SleepEpoch> epochs) async {
    await _db.batch((b) {
      for (final e in epochs) {
        b.insert(
          _db.sleepEpochs,
          db.SleepEpochsCompanion.insert(
            id: e.id,
            sessionId: sessionId,
            userId: e.userId,
            startedAtUtc: _toSec(e.startedAt),
            durationMin: e.durationMin,
            stage: e.stage,
            source: e.source,
            createdAtUtc: _toSec(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<SleepEpoch>> getEpochsForSession(String sessionId) async {
    final rows = await (_db.select(_db.sleepEpochs)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAtUtc)]))
        .get();
    return rows.map(_rowToEpoch).toList();
  }

  @override
  Future<int> softDeleteSessionsBefore(DateTime cutoff) async {
    return (_db.update(_db.sleepSessions)
          ..where((t) =>
              t.startedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.SleepSessionsCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }
}

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  return SleepRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
