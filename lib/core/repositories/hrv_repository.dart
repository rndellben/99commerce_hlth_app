import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/time_series_repository.dart';

/// hlth-repository-api.md §4.3.2
abstract class HrvRepository extends TimeSeriesRepository<HrvSample> {
  Future<HrvSample?> getMorningResting({
    required String userId,
    required DateTime forDate,
  });
}

class HrvRepositoryImpl implements HrvRepository {
  HrvRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  HrvSample _rowToDomain(db.HrvSample r) => HrvSample(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        capturedAt: _toDt(r.capturedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        rmssdMs: r.rmssdMs,
        sdnnMs: r.sdnnMs,
        pnn50Pct: r.pnn50Pct,
        meanHrBpm: r.meanHrBpm,
        beatCount: r.beatCount,
        source: r.source,
        quality: r.quality,
        algorithmVersion: r.algorithmVersion,
      );

  db.HrvSamplesCompanion _toCompanion(HrvSample s) =>
      db.HrvSamplesCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        capturedAtUtc: _toSec(s.capturedAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        quality: Value(s.quality),
        algorithmVersion: Value(s.algorithmVersion),
        createdAtUtc: _toSec(DateTime.now()),
        rmssdMs: s.rmssdMs,
        sdnnMs: Value(s.sdnnMs),
        pnn50Pct: Value(s.pnn50Pct),
        meanHrBpm: Value(s.meanHrBpm),
        beatCount: Value(s.beatCount),
      );

  @override
  Future<void> insert(HrvSample sample) async {
    await _db.into(_db.hrvSamples).insertOnConflictUpdate(_toCompanion(sample));
  }

  @override
  Future<void> insertMany(List<HrvSample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(_db.hrvSamples, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<HrvSample?> getLatest({required String userId, String? deviceId}) async {
    final q = _db.select(_db.hrvSamples)
      ..where((t) => t.userId.equals(userId) & t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
      ..limit(1);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    final row = await q.getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<HrvSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    final q = _db.select(_db.hrvSamples)
      ..where((t) =>
          t.userId.equals(userId) &
          t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
          t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    if (limit != null) q.limit(limit);
    final rows = await q.get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Stream<List<HrvSample>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (_db.select(_db.hrvSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Stream<HrvSample?> watchLatest({required String userId}) {
    return (_db.select(_db.hrvSamples)
          ..where((t) => t.userId.equals(userId) & t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToDomain(row));
  }

  @override
  Future<int> countInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final count = countAll();
    final q = _db.selectOnly(_db.hrvSamples)
      ..addColumns([count])
      ..where(_db.hrvSamples.userId.equals(userId) &
          _db.hrvSamples.capturedAtUtc
              .isBetweenValues(_toSec(from), _toSec(to)) &
          _db.hrvSamples.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.hrvSamples)
          ..where((t) =>
              t.capturedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.HrvSamplesCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }

  /// Morning resting HRV — the earliest non-null HRV between local
  /// 04:00 and 09:00 on `forDate`. Required by recovery score.
  @override
  Future<HrvSample?> getMorningResting({
    required String userId,
    required DateTime forDate,
  }) async {
    final start = DateTime(forDate.year, forDate.month, forDate.day, 4);
    final end = DateTime(forDate.year, forDate.month, forDate.day, 9);
    final row = await (_db.select(_db.hrvSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(start), _toSec(end)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }
}

final hrvRepositoryProvider = Provider<HrvRepository>((ref) {
  return HrvRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
