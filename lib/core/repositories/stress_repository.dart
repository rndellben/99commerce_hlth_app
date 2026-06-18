import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/time_series_repository.dart';

/// Repository for the band-side "pressure" (stress) feature.
/// One sample per band-side scheduling slot (typically 30 min). Score 0-100
/// with QWatch zone breakdown: 0-29 relax, 30-59 normal, 60-79 medium,
/// 80-100 high.
abstract class StressRepository extends TimeSeriesRepository<StressSample> {}

class StressRepositoryImpl implements StressRepository {
  StressRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  StressSample _rowToDomain(db.StressSample r) => StressSample(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        capturedAt: _toDt(r.capturedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        stressScore: r.stressScore,
        rangeMin: r.rangeMin,
        source: r.source,
        quality: r.quality,
        algorithmVersion: r.algorithmVersion,
      );

  db.StressSamplesCompanion _toCompanion(StressSample s) =>
      db.StressSamplesCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        capturedAtUtc: _toSec(s.capturedAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        quality: Value(s.quality),
        algorithmVersion: Value(s.algorithmVersion),
        createdAtUtc: _toSec(DateTime.now()),
        stressScore: s.stressScore,
        rangeMin: s.rangeMin,
      );

  @override
  Future<void> insert(StressSample sample) async {
    await _db
        .into(_db.stressSamples)
        .insertOnConflictUpdate(_toCompanion(sample));
  }

  @override
  Future<void> insertMany(List<StressSample> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(_db.stressSamples, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<StressSample?> getLatest(
      {required String userId, String? deviceId}) async {
    final q = _db.select(_db.stressSamples)
      ..where((t) => t.userId.equals(userId) & t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
      ..limit(1);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    final row = await q.getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<StressSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    final q = _db.select(_db.stressSamples)
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
  Stream<List<StressSample>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (_db.select(_db.stressSamples)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Stream<StressSample?> watchLatest({required String userId}) {
    return (_db.select(_db.stressSamples)
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
    final q = _db.selectOnly(_db.stressSamples)
      ..addColumns([count])
      ..where(_db.stressSamples.userId.equals(userId) &
          _db.stressSamples.capturedAtUtc
              .isBetweenValues(_toSec(from), _toSec(to)) &
          _db.stressSamples.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.stressSamples)
          ..where((t) =>
              t.capturedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.StressSamplesCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }
}

final stressRepositoryProvider = Provider<StressRepository>((ref) {
  return StressRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
