import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/sync_state_repository.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// Nudges the user to reopen the app when the band hasn't synced in a
/// while. The first concrete rule on the alert engine and one of Ryan's
/// four requested notifications.
///
/// Conservative by design: fires nothing for a user with no paired device
/// or one that has never synced (a fresh install shouldn't be nagged).
class RetentionRule implements AlertRule {
  RetentionRule({
    required this.deviceRepo,
    required this.syncStateRepo,
    this.staleAfter = const Duration(days: 3),
  });

  final DeviceRepository deviceRepo;
  final SyncStateRepository syncStateRepo;

  /// How long without a successful sync before we consider the band quiet.
  final Duration staleAfter;

  @override
  String get type => 'retention';

  /// Don't re-nag more than this often even if still stale.
  @override
  Duration get minInterval => const Duration(days: 3);

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final device = await deviceRepo.getActiveForUser(ctx.userId);
    if (device == null) return null;

    final lastSync =
        await syncStateRepo.latestSuccessfulSync(deviceId: device.id);
    if (lastSync == null) return null; // never synced — don't nag a new user
    if (ctx.now.difference(lastSync) < staleAfter) return null;

    return const AlertCandidate(
      dedupeKey: 'retention',
      title: 'Sync your HLTH band',
      body: 'It’s been a few days — open the app to back up your health data.',
      channel: AlertChannel.retention,
    );
  }
}

final retentionRuleProvider = Provider<RetentionRule>((ref) {
  return RetentionRule(
    deviceRepo: ref.watch(deviceRepositoryProvider),
    syncStateRepo: ref.watch(syncStateRepositoryProvider),
  );
});
