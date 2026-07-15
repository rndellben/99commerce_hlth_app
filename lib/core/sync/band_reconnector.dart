import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';

/// Owns re-establishing the band link when it drops.
///
/// Reconnect ownership (2026-07-07 overnight failure): native sync ticks
/// are scheduled ONLY while connected, so once the band drops, no tick
/// ever fires again and nothing Dart-side notices — the app sat "alive
/// but deaf" for hours. This timer runs in WHICHEVER engine hosts the
/// coordinator (UI or headless) and re-establishes the link by bonded
/// MAC. Cheap no-op while connected.
class BandReconnector {
  BandReconnector({
    required this.ble,
    required this.deviceRepo,
  });

  final BleService ble;
  final DeviceRepository deviceRepo;

  Timer? _timer;
  bool _reconnecting = false;

  /// Starts the periodic reconnect loop: one attempt shortly after boot
  /// (a revived process shouldn't wait 5 min for its first attempt), then
  /// every 5 minutes.
  void start() {
    _timer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => tryNow(),
    );
    Future<void>.delayed(const Duration(seconds: 10), tryNow);
  }

  /// One reconnect attempt. Direct connect by bonded MAC (no scan — works
  /// headless). Skips while connected/connecting, when no band is bonded,
  /// or while a previous attempt is still in flight.
  Future<void> tryNow() async {
    if (_reconnecting) return;
    final state = ble.currentConnectionState;
    if (state == BleConnectionState.connected ||
        state == BleConnectionState.connecting) {
      return;
    }
    _reconnecting = true;
    try {
      final device =
          await deviceRepo.getActiveForUser(ActiveSession.defaultUserId);
      final mac = device?.macAddress;
      if (mac == null || mac.isEmpty) return;
      Breadcrumbs.log('reconnect: band disconnected — trying $mac');
      await ble.connect(mac);
    } catch (e) {
      Breadcrumbs.log('reconnect: attempt failed ($e)');
    } finally {
      _reconnecting = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

final bandReconnectorProvider = Provider<BandReconnector>((ref) {
  final reconnector = BandReconnector(
    ble: ref.watch(bleServiceProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
  );
  ref.onDispose(reconnector.dispose);
  return reconnector;
});
