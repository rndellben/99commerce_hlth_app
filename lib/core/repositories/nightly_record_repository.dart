import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/nightly_record_row.dart';

abstract class NightlyRecordRepository {
  /// Upsert keyed on (userId, localDate) — re-reducing a night overwrites.
  Future<void> upsert(NightlyRecordRow row);

  /// Records with localDate strictly BEFORE [beforeDate], oldest first
  /// (most recent LAST — the order computeVascularLoad expects for history).
  Future<List<NightlyRecordRow>> getHistoryBefore({
    required String userId,
    required DateTime beforeDate,
    int limit = 30,
  });

  Future<NightlyRecordRow?> getForDate({
    required String userId,
    required DateTime localDate,
  });
}

class NightlyRecordRepositoryImpl implements NightlyRecordRepository {
  NightlyRecordRepositoryImpl(this._db);
  final db.AppDatabase _db;

  String _dateOnly(DateTime d) => d.toIso8601String().substring(0, 10);
  int _toSec(DateTime d) => d.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  String _idFor(String userId, DateTime localDate) =>
      '$userId:${_dateOnly(localDate)}';

  NightlyRecordRow _toDomain(db.NightlyRecord r) => NightlyRecordRow(
        id: r.id,
        userId: r.userId,
        localDate: DateTime.parse(r.localDate),
        hrP5: r.hrP5,
        rmssdMedian: r.rmssdMedian,
        stressMean: r.stressMean,
        coverage: r.coverage,
        valid: r.valid,
        computedAt: _toDt(r.computedAtUtc),
        algorithmVersion: r.algorithmVersion,
      );

  @override
  Future<void> upsert(NightlyRecordRow row) async {
    await _db.into(_db.nightlyRecords).insertOnConflictUpdate(
          db.NightlyRecordsCompanion.insert(
            id: _idFor(row.userId, row.localDate),
            userId: row.userId,
            localDate: _dateOnly(row.localDate),
            hrP5: Value(row.hrP5),
            rmssdMedian: Value(row.rmssdMedian),
            stressMean: Value(row.stressMean),
            coverage: Value(row.coverage),
            valid: Value(row.valid),
            computedAtUtc: _toSec(row.computedAt),
            algorithmVersion: row.algorithmVersion,
          ),
        );
  }

  @override
  Future<List<NightlyRecordRow>> getHistoryBefore({
    required String userId,
    required DateTime beforeDate,
    int limit = 30,
  }) async {
    final rows = await (_db.select(_db.nightlyRecords)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.isSmallerThanValue(_dateOnly(beforeDate)))
          ..orderBy([(t) => OrderingTerm.asc(t.localDate)])) // oldest first
        .get();
    final mapped = rows.map(_toDomain).toList();
    // Keep the most recent `limit` (history window), preserving asc order.
    return mapped.length > limit
        ? mapped.sublist(mapped.length - limit)
        : mapped;
  }

  @override
  Future<NightlyRecordRow?> getForDate({
    required String userId,
    required DateTime localDate,
  }) async {
    final r = await (_db.select(_db.nightlyRecords)
          ..where((t) =>
              t.userId.equals(userId) &
              t.localDate.equals(_dateOnly(localDate))))
        .getSingleOrNull();
    return r == null ? null : _toDomain(r);
  }
}

final nightlyRecordRepositoryProvider =
    Provider<NightlyRecordRepository>((ref) {
  return NightlyRecordRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
