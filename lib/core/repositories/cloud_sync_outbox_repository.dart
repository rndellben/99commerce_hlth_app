import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

/// Outbox entry waiting to be pushed to Supabase.
class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.createdAtUtc,
    required this.attempts,
    this.lastAttemptAtUtc,
    this.lastError,
  });

  final String id;
  final String tableName;
  final String recordId;
  final int createdAtUtc;
  final int attempts;
  final int? lastAttemptAtUtc;
  final String? lastError;
}

/// CRUD for the local cloud-sync outbox queue.
class CloudSyncOutboxRepository {
  CloudSyncOutboxRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Queue a record for cloud sync. Skips if an entry for the same
  /// table+record already exists (idempotent).
  Future<void> enqueue({
    required String tableName,
    required String recordId,
  }) async {
    // Skip if already queued.
    final existing = await (_db.select(_db.cloudSyncOutbox)
          ..where((t) =>
              t.targetTable.equals(tableName) & t.recordId.equals(recordId)))
        .getSingleOrNull();
    if (existing != null) return;

    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    await _db.into(_db.cloudSyncOutbox).insert(
          CloudSyncOutboxCompanion.insert(
            id: _uuid.v4(),
            targetTable: tableName,
            recordId: recordId,
            createdAtUtc: nowSec,
          ),
        );
  }

  /// Fetch the oldest [limit] pending entries.
  Future<List<OutboxEntry>> getPending({int limit = 50}) async {
    final query = _db.select(_db.cloudSyncOutbox)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAtUtc)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_rowToEntry).toList();
  }

  /// Remove an entry after successful push.
  Future<void> dequeue(String id) async {
    await (_db.delete(_db.cloudSyncOutbox)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  /// Record a failed push attempt.
  Future<void> recordAttempt(String id, {String? error}) async {
    final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    // Read-modify-write since Drift companions don't support column arithmetic.
    final row = await (_db.select(_db.cloudSyncOutbox)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.update(_db.cloudSyncOutbox)
          ..where((t) => t.id.equals(id)))
        .write(CloudSyncOutboxCompanion(
          attempts: Value(row.attempts + 1),
          lastAttemptAtUtc: Value(nowSec),
          lastError: Value(error),
        ));
  }

  /// Purge entries that have exceeded [maxAttempts] retries.
  Future<int> purgeStaleFailed({int maxAttempts = 10}) async {
    return (_db.delete(_db.cloudSyncOutbox)
          ..where((t) => t.attempts.isBiggerOrEqualValue(maxAttempts)))
        .go();
  }

  OutboxEntry _rowToEntry(CloudSyncOutboxData row) => OutboxEntry(
        id: row.id,
        tableName: row.targetTable,
        recordId: row.recordId,
        createdAtUtc: row.createdAtUtc,
        attempts: row.attempts,
        lastAttemptAtUtc: row.lastAttemptAtUtc,
        lastError: row.lastError,
      );
}

final cloudSyncOutboxRepositoryProvider =
    Provider<CloudSyncOutboxRepository>((ref) {
  return CloudSyncOutboxRepository(ref.watch(appDatabaseProvider));
});
