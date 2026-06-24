import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:uuid/uuid.dart';

/// Persists fired notifications and answers the rate-limit question
/// ("when did we last fire alert X for this user?"). Survives restarts so
/// the "once every N days" guard holds across sessions.
class NotificationLogRepository {
  NotificationLogRepository(this._db);
  final db.AppDatabase _db;
  final _uuid = const Uuid();

  int _toSec(DateTime dt) => dt.toUtc().millisecondsSinceEpoch ~/ 1000;

  Future<void> insert({
    required String userId,
    required String type,
    required String dedupeKey,
    required String title,
    required String body,
    String? payload,
    required String channel,
    required DateTime firedAtUtc,
  }) async {
    await _db.into(_db.notificationLog).insert(
          db.NotificationLogCompanion.insert(
            id: _uuid.v4(),
            userId: userId,
            type: type,
            dedupeKey: dedupeKey,
            title: title,
            body: body,
            payload: Value(payload),
            channel: channel,
            firedAtUtcSec: _toSec(firedAtUtc),
          ),
        );
  }

  /// Most recent fire time for (userId, type), or null if never fired.
  /// Drives the per-rule minInterval rate-limit.
  Future<DateTime?> lastFiredFor({
    required String userId,
    required String type,
  }) async {
    final row = await (_db.select(_db.notificationLog)
          ..where((t) => t.userId.equals(userId) & t.type.equals(type))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.firedAtUtcSec, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      row.firedAtUtcSec * 1000,
      isUtc: true,
    );
  }

  /// Recent fired notifications, newest first — for an in-app history list.
  Future<List<db.NotificationLogData>> recent({
    required String userId,
    int limit = 50,
  }) {
    return (_db.select(_db.notificationLog)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.firedAtUtcSec, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }
}

final notificationLogRepositoryProvider =
    Provider<NotificationLogRepository>((ref) =>
        NotificationLogRepository(ref.watch(db.appDatabaseProvider)));
