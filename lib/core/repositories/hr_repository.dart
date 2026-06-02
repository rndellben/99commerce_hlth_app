import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/time_series_repository.dart';

/// hlth-repository-api.md §4.3.1
abstract class HrRepository extends TimeSeriesRepository<HrSample> {
  Future<List<HrSample>> getRestingInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  Future<double?> averageInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });
}

class HrRepositoryImpl implements HrRepository {
  HrRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  HrSample _rowToDomain(db.HrSample r) => HrSample(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        capturedAt: _toDt(r.capturedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        bpm: r.bpm,
        intervalMin: r.intervalMin,
        isResting: r.isResting,
        source: r.source,
        quality: r.quality,
        algorithmVersion: r.algorithmVersion,
      );

  db.HrSamplesCompanion _toCompanion(HrSample s) =>
      db.HrSamplesCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        capturedAtUtc: _toSec(s.capturedAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        quality: Value(s.quality),
        algorithmVersion: Value(s.algorithmVersion),
        createdAtUtc: _toSec(DateTime.now()),
        bpm: s.bpm,
        intervalMin: s.intervalMin,
        isResting: Value(s.isResting),
      );

  @override
  Future<void> insert(HrSample sample) async {
    await _db.into(_db.hrSamples).insertOnConflictUpdate(_toCompanion(sample));
  }

  @override
  Future<void> insertMany(List<HrSample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(_db.hrSamples, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<HrSample?> getLatest({
    required String userId,
    String? deviceId,
  }) async {
    final q = _db.select(_db.hrSamples)
      ..where((t) => t.userId.equals(userId))
      ..where((t) => t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
      ..limit(1);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    final row = await q.getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<HrSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    final q = _db.select(_db.hrSamples)
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
  Stream<List<HrSample>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (_db.select(_db.hrSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Stream<HrSample?> watchLatest({required String userId}) {
    return (_db.select(_db.hrSamples)
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
    final q = _db.selectOnly(_db.hrSamples)
      ..addColumns([count])
      ..where(_db.hrSamples.userId.equals(userId) &
          _db.hrSamples.capturedAtUtc
              .isBetweenValues(_toSec(from), _toSec(to)) &
          _db.hrSamples.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<void> softDeleteBefore(DateTime cutoff) async {
    await (_db.update(_db.hrSamples)
          ..where((t) =>
              t.capturedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.HrSamplesCompanion(
      deletedAtUtc: Value(_toSec(DateTime.now())),
    ));
  }

  @override
  Future<List<HrSample>> getRestingInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await (_db.select(_db.hrSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.isResting.equals(true) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<double?> averageInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final avg = _db.hrSamples.bpm.avg();
    final row = await (_db.selectOnly(_db.hrSamples)
          ..addColumns([avg])
          ..where(_db.hrSamples.userId.equals(userId) &
              _db.hrSamples.capturedAtUtc
                  .isBetweenValues(_toSec(from), _toSec(to)) &
              _db.hrSamples.deletedAtUtc.isNull()))
        .getSingle();
    return row.read(avg);
  }
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
