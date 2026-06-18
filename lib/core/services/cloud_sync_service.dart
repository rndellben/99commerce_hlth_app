import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/baseline_repository.dart';
import 'package:hlth_app/core/repositories/cloud_sync_outbox_repository.dart';
import 'package:hlth_app/core/services/baseline_service.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/supabase_sync_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/services/connectivity_service.dart';

/// Result of an outbox processing run.
class CloudSyncResult {
  const CloudSyncResult({
    required this.pushed,
    required this.failed,
    this.errors = const [],
  });

  final int pushed;
  final int failed;
  final List<String> errors;

  bool get allOk => failed == 0;
}

/// Orchestrates the local-to-Supabase cloud sync via the outbox pattern.
///
/// Flow:
///   1. After daily_aggregator runs, `enqueueRecentMetrics` queues dirty rows.
///   2. On each periodic tick (or on-demand), `processOutbox` drains the queue.
///   3. Each entry is loaded from the local repo, converted, pushed to Supabase.
///   4. On success the entry is dequeued; on failure the attempt is recorded.
class CloudSyncService {
  CloudSyncService({
    required this.outboxRepo,
    required this.supabaseRepo,
    required this.dailyRepo,
    required this.baselineRepo,
    required this.deviceRepo,
    required this.userRepo,
    required this.connectivityService,
  });

  final CloudSyncOutboxRepository outboxRepo;
  final SupabaseSyncRepository supabaseRepo;
  final DailyMetricsRepository dailyRepo;
  final BaselineRepository baselineRepo;
  final DeviceRepository deviceRepo;
  final UserRepository userRepo;
  final ConnectivityService connectivityService;

  /// Enqueue the last [days] of daily_metrics + current baselines for cloud sync.
  Future<void> enqueueRecentMetrics({
    required String userId,
    int days = 14,
  }) async {
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    final metrics = await dailyRepo.getInRange(
      userId: userId,
      fromDate: from,
      toDate: now,
    );
    for (final m in metrics) {
      await outboxRepo.enqueue(tableName: 'daily_metrics', recordId: m.id);
    }

    // Also enqueue recent baselines.
    for (final metricKey in BaselineMetric.all) {
      for (final window in const [14, 30, 90]) {
        final b = await baselineRepo.getCurrent(
          userId: userId,
          metricKey: metricKey,
          windowDays: window,
          forDate: now,
        );
        if (b != null) {
          await outboxRepo.enqueue(tableName: 'baselines', recordId: b.id);
        }
      }
    }
  }

  /// Enqueue the active device and user profile for cloud sync.
  Future<void> enqueueIdentity({
    required String userId,
  }) async {
    final device = await deviceRepo.getActiveForUser(userId);
    if (device != null) {
      await outboxRepo.enqueue(tableName: 'devices', recordId: device.id);
    }
    final profile = await userRepo.getProfile(userId);
    if (profile != null) {
      await outboxRepo.enqueue(
        tableName: 'user_profiles',
        recordId: profile.userId,
      );
    }
  }

  /// Process pending outbox entries. Returns early if offline.
  Future<CloudSyncResult> processOutbox({
    required String authUserId,
  }) async {
    if (connectivityService.current == ConnectivityStatus.offline) {
      return const CloudSyncResult(pushed: 0, failed: 0);
    }

    final pending = await outboxRepo.getPending(limit: 50);
    var pushed = 0;
    var failed = 0;
    final errors = <String>[];

    for (final entry in pending) {
      try {
        await _pushEntry(entry, authUserId);
        await outboxRepo.dequeue(entry.id);
        pushed++;
      } catch (e) {
        await outboxRepo.recordAttempt(entry.id, error: e.toString());
        failed++;
        errors.add('${entry.tableName}/${entry.recordId}: $e');
      }
    }

    // Purge entries that have failed too many times.
    await outboxRepo.purgeStaleFailed();

    return CloudSyncResult(pushed: pushed, failed: failed, errors: errors);
  }

  Future<void> _pushEntry(OutboxEntry entry, String authUserId) async {
    switch (entry.tableName) {
      case 'daily_metrics':
        final m = await dailyRepo.getById(entry.recordId);
        if (m == null) return; // Record deleted locally — skip.
        await supabaseRepo.pushDailyMetrics(m, authUserId);
      case 'baselines':
        final b = await baselineRepo.getById(entry.recordId);
        if (b == null) return;
        await supabaseRepo.pushBaseline(b, authUserId);
      case 'devices':
        final d = await deviceRepo.getById(entry.recordId);
        if (d == null) return;
        await supabaseRepo.pushDevice(d, authUserId);
      case 'user_profiles':
        final p = await userRepo.getProfile(entry.recordId);
        if (p == null) return;
        await supabaseRepo.pushUserProfile(p, authUserId);
    }
  }
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService(
    outboxRepo: ref.watch(cloudSyncOutboxRepositoryProvider),
    supabaseRepo: ref.watch(supabaseSyncRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    baselineRepo: ref.watch(baselineRepositoryProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
    connectivityService: ref.watch(connectivityServiceProvider),
  );
});
