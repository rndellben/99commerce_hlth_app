import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:uuid/uuid.dart';

/// Pre-onboarding bootstrap so health rows have valid FK targets.
///
/// V1 ships with a single local user (`local-user-v1`) until step 6's
/// onboarding flow assigns a real identity. The device row is created on
/// first connect — keyed by MAC, with a fresh UUID as the row id.
class ActiveSession {
  ActiveSession(this._userRepo, this._deviceRepo);
  final UserRepository _userRepo;
  final DeviceRepository _deviceRepo;

  static const _uuid = Uuid();
  static const defaultUserId = 'local-user-v1';

  Future<String> ensureUser() async {
    final existing = await _userRepo.getById(defaultUserId);
    if (existing != null) return existing.id;
    final created = await _userRepo.create(
      id: defaultUserId,
      displayName: 'You',
    );
    return created.id;
  }

  /// Looks up a device by its band-side identifier (MAC on Android, peripheral
  /// UUID on iOS) and creates it if missing. Returns the row id (a UUID).
  Future<String> ensureDevice({
    required String bandId,
    String? displayName,
    String? model,
    bool isMac = true,
  }) async {
    final userId = await ensureUser();

    final existing = isMac
        ? await _deviceRepo.getByMacAddress(bandId)
        : null; // iOS peripheral lookup wired in onboarding step
    if (existing != null) {
      // Re-pair after Forget: existing row is marked isActive=false. Flip
      // it back on so getActiveForUser / the ★ Paired badge / My Device
      // screen see the binding again.
      if (!existing.isActive) {
        await _deviceRepo.reactivate(existing.id);
      }
      await _deviceRepo.updateConnectionState(
        deviceId: existing.id,
        lastConnectedAt: DateTime.now().toUtc(),
      );
      return existing.id;
    }

    final id = _uuid.v4();
    await _deviceRepo.create(
      id: id,
      userId: userId,
      macAddress: isMac ? bandId : null,
      iosPeripheralUuid: isMac ? null : bandId,
      displayName: displayName ?? bandId,
      model: model,
    );
    await _deviceRepo.updateConnectionState(
      deviceId: id,
      lastConnectedAt: DateTime.now().toUtc(),
    );
    return id;
  }
}

final activeSessionProvider = Provider<ActiveSession>((ref) {
  return ActiveSession(
    ref.watch(userRepositoryProvider),
    ref.watch(deviceRepositoryProvider),
  );
});
