import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/time_series_repository.dart';

/// hlth-repository-api.md §4.3.5 — v1 scope drops calibration helpers
/// (deferred until step 11+); core CRUD only.
abstract class BpRepository extends TimeSeriesRepository<BpReading> {
  Future<List<BpReading>> getByDerivation({
    required String userId,
    required BpDerivation derivation,
    DateTime? from,
    DateTime? to,
  });

  /// Downsamples raw `bp_readings` to **at most one reading per clock
  /// hour** — picks the first sample inside each hour-bucket. Algorithms
  /// that depend on BP at a fixed cadence (e.g. hourly trend analysis,
  /// daily-metric aggregation) MUST consume readings via this method, not
  /// `getInRange`, so that user-selectable scheduled-monitoring cadence
  /// (15 / 30 / 60 min) doesn't change the algorithm's input density.
  ///
  /// Empty hours return no reading — the result list is not padded.
  Future<List<BpReading>> getHourlySnapshots({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
  });
}

class BpRepositoryImpl implements BpRepository {
  BpRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  BpReading _rowToDomain(db.BpReading r) => BpReading(
        id: r.id,
        userId: r.userId,
        deviceId: r.deviceId,
        capturedAt: _toDt(r.capturedAtUtc),
        tzOffsetMin: r.capturedTzOffsetMin,
        systolicMmhg: r.systolicMmhg,
        diastolicMmhg: r.diastolicMmhg,
        pulseBpm: r.pulseBpm,
        derivation: r.derivation,
        position: r.position,
        source: r.source,
        quality: r.quality,
        algorithmVersion: r.algorithmVersion,
      );

  db.BpReadingsCompanion _toCompanion(BpReading s) =>
      db.BpReadingsCompanion.insert(
        id: s.id,
        userId: s.userId,
        deviceId: s.deviceId,
        capturedAtUtc: _toSec(s.capturedAt),
        capturedTzOffsetMin: s.tzOffsetMin,
        source: s.source,
        quality: Value(s.quality),
        algorithmVersion: Value(s.algorithmVersion),
        createdAtUtc: _toSec(DateTime.now()),
        systolicMmhg: s.systolicMmhg,
        diastolicMmhg: s.diastolicMmhg,
        pulseBpm: Value(s.pulseBpm),
        derivation: s.derivation,
        position: Value(s.position),
      );

  @override
  Future<void> insert(BpReading sample) async {
    await _db.into(_db.bpReadings).insertOnConflictUpdate(_toCompanion(sample));
  }

  @override
  Future<void> insertMany(List<BpReading> samples) async {
    await _db.batch((b) {
      for (final s in samples) {
        b.insert(_db.bpReadings, _toCompanion(s),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  @override
  Future<BpReading?> getLatest({required String userId, String? deviceId}) async {
    final q = _db.select(_db.bpReadings)
      ..where((t) => t.userId.equals(userId) & t.deletedAtUtc.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
      ..limit(1);
    if (deviceId != null) q.where((t) => t.deviceId.equals(deviceId));
    final row = await q.getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<List<BpReading>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    final q = _db.select(_db.bpReadings)
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
  Stream<List<BpReading>> watchInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (_db.select(_db.bpReadings)
          ..where((t) =>
              t.userId.equals(userId) &
              t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)) &
              t.deletedAtUtc.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Stream<BpReading?> watchLatest({required String userId}) {
    return (_db.select(_db.bpReadings)
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
    final q = _db.selectOnly(_db.bpReadings)
      ..addColumns([count])
      ..where(_db.bpReadings.userId.equals(userId) &
          _db.bpReadings.capturedAtUtc
              .isBetweenValues(_toSec(from), _toSec(to)) &
          _db.bpReadings.deletedAtUtc.isNull());
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> softDeleteBefore(DateTime cutoff) async {
    return (_db.update(_db.bpReadings)
          ..where((t) =>
              t.capturedAtUtc.isSmallerThanValue(_toSec(cutoff)) &
              t.deletedAtUtc.isNull()))
        .write(db.BpReadingsCompanion(
            deletedAtUtc: Value(_toSec(DateTime.now()))));
  }

  @override
  Future<List<BpReading>> getHourlySnapshots({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
  }) async {
    // Pull every raw sample in range (small set — at most ~24 readings/day
    // at 60-min cadence, 96/day at 15-min). Bucket by floor(epochSec / 3600)
    // and keep the first (lowest capturedAt) sample per bucket.
    final rows = await getInRange(
      userId: userId,
      from: from,
      to: to,
      deviceId: deviceId,
    );
    final byHour = <int, BpReading>{};
    for (final r in rows) {
      final hourBucket = _toSec(r.capturedAt) ~/ 3600;
      // getInRange returns ASC by capturedAtUtc, so the first put wins.
      byHour.putIfAbsent(hourBucket, () => r);
    }
    final hours = byHour.keys.toList()..sort();
    return [for (final h in hours) byHour[h]!];
  }

  @override
  Future<List<BpReading>> getByDerivation({
    required String userId,
    required BpDerivation derivation,
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _db.select(_db.bpReadings)
      ..where((t) =>
          t.userId.equals(userId) &
          t.derivation.equalsValue(derivation) &
          t.deletedAtUtc.isNull());
    if (from != null && to != null) {
      q.where((t) =>
          t.capturedAtUtc.isBetweenValues(_toSec(from), _toSec(to)));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)]);
    final rows = await q.get();
    return rows.map(_rowToDomain).toList();
  }
}

final bpRepositoryProvider = Provider<BpRepository>((ref) {
  return BpRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
