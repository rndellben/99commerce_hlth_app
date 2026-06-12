import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/time_series_repository.dart';

/// hlth-repository-api.md §4.3.4
abstract class Spo2Repository extends TimeSeriesRepository<Spo2Sample> {
  Future<({double avg, int min})?> overnightStats({
    required String userId,
    required DateTime sleepStart,
    required DateTime sleepEnd,
  });
}

class Spo2RepositoryImpl implements Spo2Repository {
  Spo2RepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  Spo2Sample _rowToDomain(db.Spo2Sample r) => Spo2Sample(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        capturedAt: _toDt(r.capturedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        pctMin: r.pctMin,
        pctMax: r.pctMax,
        bucketMin: r.bucketMin,
        source: r.source,
        quality: r.quality,
        algorithmVersion: r.algorithmVersion,
      );

  db.Spo2SamplesCompanion _toCompanion(Spo2Sample s) =>
      db.Spo2SamplesCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        capturedAtUtc: _toSec(s.capturedAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        quality: Value(s.quality),
        algorithmVersion: Value(s.algorithmVersion),
        createdAtUtc: _toSec(DateTime.now()),
        pctMin: s.pctMin,
        pctMax: s.pctMax,
        bucketMin: s.bucketMin,
      );

  @override
  Future<void> insert(Spo2Sample sample) async {
    await _db.into(_db.spo2Samples).insertOnConflictUpdate(_toCompanion(sample));
  }

  @override
  Future<void> insertMany(List<Spo2Sample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(_db.spo2Samples, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<Spo2Sample?> getLatest({required String userId, String? deviceId}) async {
    final q = _db.select(_db.spo2Samples)
      ..where((t) => t.userId.equals(userId) & t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
      ..limit(1);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    final row = await q.getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<Spo2Sample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    final q = _db.select(_db.spo2Samples)
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
  Stream<List<Spo2Sample>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (_db.select(_db.spo2Samples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Stream<Spo2Sample?> watchLatest({required String userId}) {
    return (_db.select(_db.spo2Samples)
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
    final q = _db.selectOnly(_db.spo2Samples)
      ..addColumns([count])
      ..where(_db.spo2Samples.userId.equals(userId) &
          _db.spo2Samples.capturedAtUtc
              .isBetweenValues(_toSec(from), _toSec(to)) &
          _db.spo2Samples.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.spo2Samples)
          ..where((t) =>
              t.capturedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.Spo2SamplesCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }

  @override
  Future<({double avg, int min})?> overnightStats({
    required String userId,
    required DateTime sleepStart,
    required DateTime sleepEnd,
  }) async {
    final avg = _db.spo2Samples.pctMin.avg();
    final mn = _db.spo2Samples.pctMin.min();
    final row = await (_db.selectOnly(_db.spo2Samples)
          ..addColumns([avg, mn])
          ..where(_db.spo2Samples.userId.equals(userId) &
              _db.spo2Samples.capturedAtUtc.isBetweenValues(
                  _toSec(sleepStart), _toSec(sleepEnd)) &
              _db.spo2Samples.deletedAtUtc.isNull()))
        .getSingle();
    final avgV = row.read(avg);
    final minV = row.read(mn);
    if (avgV == null || minV == null) return null;
    return (avg: avgV, min: minV);
  }
}

final spo2RepositoryProvider = Provider<Spo2Repository>((ref) {
  return Spo2RepositoryImpl(ref.watch(db.appDatabaseProvider));
});
