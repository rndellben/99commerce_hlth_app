import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/baseline.dart';

/// hlth-repository-api.md §4.9
abstract class BaselineRepository {
  Future<Baseline?> getCurrent({
    required String userId,
    required String metricKey,
    required int windowDays,
    required DateTime forDate,
  });

  Stream<Baseline?> watchCurrent({
    required String userId,
    required String metricKey,
    required int windowDays,
  });

  Future<List<Baseline>> getHistory({
    required String userId,
    required String metricKey,
    required int windowDays,
    int? limitDays,
  });

  Future<void> upsert(Baseline baseline);
  Future<void> upsertMany(List<Baseline> baselines);

  Future<bool> isEstablished({
    required String userId,
    required String metricKey,
    required int windowDays,
  });
}

class BaselineRepositoryImpl implements BaselineRepository {
  BaselineRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
  String _dateOnly(DateTime dt) => dt.toIso8601String().substring(0, 10);

  Baseline _rowToDomain(db.Baseline r) => Baseline(
        id: r.id,
        userId: r.userId,
        metricKey: r.metricKey,
        windowDays: r.windowDays,
        computedForDate: DateTime.parse(r.computedForDate),
        meanValue: r.meanValue,
        stddevValue: r.stddevValue,
        sampleCount: r.sampleCount,
        computedAt: _toDt(r.computedAtUtc),
        algorithmVersion: r.algorithmVersion,
      );

  db.BaselinesCompanion _toCompanion(Baseline b) => db.BaselinesCompanion.insert(
        id: b.id,
        userId: b.userId,
        metricKey: b.metricKey,
        windowDays: b.windowDays,
        computedForDate: _dateOnly(b.computedForDate),
        meanValue: b.meanValue,
        stddevValue: b.stddevValue,
        sampleCount: b.sampleCount,
        computedAtUtc: _toSec(b.computedAt),
        algorithmVersion: b.algorithmVersion,
      );

  @override
  Future<Baseline?> getCurrent({
    required String userId,
    required String metricKey,
    required int windowDays,
    required DateTime forDate,
  }) async {
    final row = await (_db.select(_db.baselines)
          ..where((t) =>
              t.userId.equals(userId) &
              t.metricKey.equals(metricKey) &
              t.windowDays.equals(windowDays) &
              t.computedForDate.isSmallerOrEqualValue(_dateOnly(forDate)))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Stream<Baseline?> watchCurrent({
    required String userId,
    required String metricKey,
    required int windowDays,
  }) {
    return (_db.select(_db.baselines)
          ..where((t) =>
              t.userId.equals(userId) &
              t.metricKey.equals(metricKey) &
              t.windowDays.equals(windowDays))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _rowToDomain(row));
  }

  @override
  Future<List<Baseline>> getHistory({
    required String userId,
    required String metricKey,
    required int windowDays,
    int? limitDays,
  }) async {
    final q = _db.select(_db.baselines)
      ..where((t) =>
          t.userId.equals(userId) &
          t.metricKey.equals(metricKey) &
          t.windowDays.equals(windowDays))
      ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)]);
    if (limitDays != null) q.limit(limitDays);
    final rows = await q.get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<void> upsert(Baseline baseline) async {
    await _db.into(_db.baselines).insertOnConflictUpdate(_toCompanion(baseline));
  }

  @override
  Future<void> upsertMany(List<Baseline> baselines) async {
    await _db.batch((b) {
      for (final x in baselines) {
        b.insert(_db.baselines, _toCompanion(x),
            mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// "Established" = at least window/2 daily samples contributed.
  @override
  Future<bool> isEstablished({
    required String userId,
    required String metricKey,
    required int windowDays,
  }) async {
    final row = await (_db.select(_db.baselines)
          ..where((t) =>
              t.userId.equals(userId) &
              t.metricKey.equals(metricKey) &
              t.windowDays.equals(windowDays))
          ..orderBy([(t) => OrderingTerm.desc(t.computedForDate)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return false;
    return row.sampleCount >= (windowDays / 2).floor();
  }
}

final baselineRepositoryProvider = Provider<BaselineRepository>((ref) {
  return BaselineRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
