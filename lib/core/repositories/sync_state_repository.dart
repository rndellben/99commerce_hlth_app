import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/models/sync_state.dart';
import 'package:uuid/uuid.dart';

/// hlth-repository-api.md §4.12
abstract class SyncStateRepository {
  Future<SyncState?> get({
    required String deviceId,
    required String metricKey,
  });

  Future<void> recordSuccess({
    required String deviceId,
    required String metricKey,
    required DateTime at,
    required int lastDayIndexSynced,
    int? bytesSynced,
  });

  Future<void> recordFailure({
    required String deviceId,
    required String metricKey,
    required DateTime at,
    required String error,
  });

  Future<List<SyncState>> getStaleMetrics({
    required String deviceId,
    required Duration staleness,
  });
}

class SyncStateRepositoryImpl implements SyncStateRepository {
  SyncStateRepositoryImpl(this._db);
  final db.AppDatabase _db;
  static const _uuid = Uuid();

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;
  DateTime _toDt(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  SyncState _rowToDomain(db.SyncStateData r) => SyncState(
        id: r.id,
        deviceId: r.deviceId,
        metricKey: r.metricKey,
        lastSuccessfulSync: r.lastSuccessfulSyncUtc == null
            ? null
            : _toDt(r.lastSuccessfulSyncUtc!),
        lastAttemptedSync: r.lastAttemptedSyncUtc == null
            ? null
            : _toDt(r.lastAttemptedSyncUtc!),
        lastSyncError: r.lastSyncError,
        lastSyncedDayIndex: r.lastSyncedDayIndex,
        bytesSyncedLifetime: r.bytesSyncedLifetime,
      );

  @override
  Future<SyncState?> get({
    required String deviceId,
    required String metricKey,
  }) async {
    final row = await (_db.select(_db.syncState)
          ..where((t) =>
              t.deviceId.equals(deviceId) & t.metricKey.equals(metricKey)))
        .getSingleOrNull();
    return row == null ? null : _rowToDomain(row);
  }

  @override
  Future<void> recordSuccess({
    required String deviceId,
    required String metricKey,
    required DateTime at,
    required int lastDayIndexSynced,
    int? bytesSynced,
  }) async {
    final existing = await get(deviceId: deviceId, metricKey: metricKey);
    final id = existing?.id ?? _uuid.v4();
    final lifetime = (existing?.bytesSyncedLifetime ?? 0) + (bytesSynced ?? 0);
    await _db.into(_db.syncState).insertOnConflictUpdate(
          db.SyncStateCompanion.insert(
            id: id,
            deviceId: deviceId,
            metricKey: metricKey,
            lastSuccessfulSyncUtc: Value(_toSec(at)),
            lastAttemptedSyncUtc: Value(_toSec(at)),
            lastSyncError: const Value(null),
            lastSyncedDayIndex: Value(lastDayIndexSynced),
            bytesSyncedLifetime: Value(lifetime),
          ),
        );
  }

  @override
  Future<void> recordFailure({
    required String deviceId,
    required String metricKey,
    required DateTime at,
    required String error,
  }) async {
    final existing = await get(deviceId: deviceId, metricKey: metricKey);
    final id = existing?.id ?? _uuid.v4();
    await _db.into(_db.syncState).insertOnConflictUpdate(
          db.SyncStateCompanion.insert(
            id: id,
            deviceId: deviceId,
            metricKey: metricKey,
            lastSuccessfulSyncUtc: Value(existing?.lastSuccessfulSync == null
                ? null
                : _toSec(existing!.lastSuccessfulSync!)),
            lastAttemptedSyncUtc: Value(_toSec(at)),
            lastSyncError: Value(error),
            lastSyncedDayIndex: Value(existing?.lastSyncedDayIndex),
            bytesSyncedLifetime:
                Value(existing?.bytesSyncedLifetime ?? 0),
          ),
        );
  }

  @override
  Future<List<SyncState>> getStaleMetrics({
    required String deviceId,
    required Duration staleness,
  }) async {
    final cutoff = _toSec(DateTime.now().subtract(staleness));
    final rows = await (_db.select(_db.syncState)
          ..where((t) =>
              t.deviceId.equals(deviceId) &
              (t.lastSuccessfulSyncUtc.isNull() |
                  t.lastSuccessfulSyncUtc.isSmallerThanValue(cutoff))))
        .get();
    return rows.map(_rowToDomain).toList();
  }
}

final syncStateRepositoryProvider = Provider<SyncStateRepository>((ref) {
  return SyncStateRepositoryImpl(ref.watch(db.appDatabaseProvider));
});
