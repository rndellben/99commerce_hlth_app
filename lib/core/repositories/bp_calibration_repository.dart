import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/bp_calibration.dart';

/// Repository for `bp_calibrations`. Calibrations are user-entered cuff
/// readings that anchor every subsequent band BP estimate to the user's
/// own pressure range.
///
/// Active-record invariant: at most one row per `userId` has
/// `isActive = true` at any time. `upsertNewActive` enforces that by
/// deactivating any older active rows in the same transaction.
abstract class BpCalibrationRepository {
  Future<void> insert(BpCalibration calibration);

  /// Save [calibration] as the new active row and flip all other active
  /// rows for the same `userId` to inactive. Idempotent — re-saving the
  /// same id replaces the existing row.
  Future<void> upsertNewActive(BpCalibration calibration);

  Future<BpCalibration?> getActiveForUser(String userId);
  Stream<BpCalibration?> watchActiveForUser(String userId);

  Future<List<BpCalibration>> getHistoryForUser(String userId);
  Stream<List<BpCalibration>> watchHistoryForUser(String userId);

  /// Mark every active row for [userId] as inactive. Used when the user
  /// wants to revert to uncalibrated readings without entering a new cuff.
  Future<void> deactivateAllForUser(String userId);

  /// Convenience setter for the boolean that records whether the band
  /// accepted the `TimeFormatReq` write. The native call is fire-and-forget
  /// so we mark this true only after the method-channel future resolves
  /// without an error.
  Future<void> markBandWriteSucceeded(String id);
}

class BpCalibrationRepositoryImpl implements BpCalibrationRepository {
  BpCalibrationRepositoryImpl(this._db);
  final db.AppDatabase _db;

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  BpCalibration _rowToDomain(db.BpCalibration r) => BpCalibration(
        id: r.id,
        userId: r.userId,
        capturedAt: _toDt(r.capturedAtUtc),
        cuffSystolic: r.cuffSystolic,
        cuffDiastolic: r.cuffDiastolic,
        bandSystolic: r.bandSystolic,
        bandDiastolic: r.bandDiastolic,
        hrAtCalibration: r.hrAtCalibration,
        ageAtCalibration: r.ageAtCalibration,
        bandWriteSucceeded: r.bandWriteSucceeded,
        notes: r.notes,
        isActive: r.isActive,
        createdAt: _toDt(r.createdAtUtc),
      );

  db.BpCalibrationsCompanion _toCompanion(BpCalibration c) =>
      db.BpCalibrationsCompanion.insert(
        id: c.id,
        userId: c.userId,
        capturedAtUtc: _toSec(c.capturedAt),
        cuffSystolic: c.cuffSystolic,
        cuffDiastolic: c.cuffDiastolic,
        bandSystolic: Value(c.bandSystolic),
        bandDiastolic: Value(c.bandDiastolic),
        hrAtCalibration: Value(c.hrAtCalibration),
        ageAtCalibration: Value(c.ageAtCalibration),
        bandWriteSucceeded: Value(c.bandWriteSucceeded),
        notes: Value(c.notes),
        isActive: Value(c.isActive),
        createdAtUtc: _toSec(c.createdAt),
      );

  @override
  Future<void> insert(BpCalibration calibration) async {
    await _db
        .into(_db.bpCalibrations)
        .insertOnConflictUpdate(_toCompanion(calibration));
  }

  @override
  Future<void> upsertNewActive(BpCalibration calibration) async {
    await _db.transaction(() async {
      // Deactivate any other active rows for this user FIRST so the
      // single-active invariant holds even if the new row's id collides
      // with an existing one (insertOnConflictUpdate replaces in-place).
      await (_db.update(_db.bpCalibrations)
            ..where((t) =>
                t.userId.equals(calibration.userId) &
                t.isActive.equals(true) &
                t.id.equals(calibration.id).not()))
          .write(const db.BpCalibrationsCompanion(isActive: Value(false)));
      await _db
          .into(_db.bpCalibrations)
          .insertOnConflictUpdate(_toCompanion(calibration.copyWith(
            isActive: true,
          )));
    });
  }

  @override
  Future<BpCalibration?> getActiveForUser(String userId) async {
    final row = await (_db.select(_db.bpCalibrations)
          ..where((t) =>
              t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Stream<BpCalibration?> watchActiveForUser(String userId) {
    return (_db.select(_db.bpCalibrations)
          ..where((t) =>
              t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)])
          ..limit(1))
        .watchSingleOrNull()
        .map((r) => r == null ? null : _rowToDomain(r));
  }

  @override
  Future<List<BpCalibration>> getHistoryForUser(String userId) async {
    final rows = await (_db.select(_db.bpCalibrations)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)]))
        .get();
    return rows.map(_rowToDomain).toList();
  }

  @override
  Stream<List<BpCalibration>> watchHistoryForUser(String userId) {
    return (_db.select(_db.bpCalibrations)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.capturedAtUtc)]))
        .watch()
        .map((rows) => rows.map(_rowToDomain).toList());
  }

  @override
  Future<void> deactivateAllForUser(String userId) async {
    await (_db.update(_db.bpCalibrations)
          ..where((t) =>
              t.userId.equals(userId) & t.isActive.equals(true)))
        .write(const db.BpCalibrationsCompanion(isActive: Value(false)));
  }

  @override
  Future<void> markBandWriteSucceeded(String id) async {
    await (_db.update(_db.bpCalibrations)..where((t) => t.id.equals(id)))
        .write(const db.BpCalibrationsCompanion(
      bandWriteSucceeded: Value(true),
    ));
  }
}

final bpCalibrationRepositoryProvider =
    Provider<BpCalibrationRepository>((ref) {
  return BpCalibrationRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
