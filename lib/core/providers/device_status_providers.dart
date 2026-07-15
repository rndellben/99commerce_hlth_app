import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';

/// App-wide device/band status read-models. Extracted from
/// `features/home/home_providers.dart` — any screen (home header,
/// settings, debug) can watch these without importing a feature.

/// Latest battery reading from the ring. Null until the band sends its first
/// battery update after connecting.
final bleBatteryProvider =
    StreamProvider<({int level, bool charging})>((ref) {
  return ref.watch(bleServiceProvider).batteryUpdate;
});

/// True for ~5 seconds after each periodic-sync tick, false otherwise.
/// Drives the "syncing" icon state in the home header.
final isSyncingProvider = StreamProvider<bool>((ref) async* {
  yield false;
  await for (final _ in ref.watch(bleServiceProvider).periodicSyncTick) {
    yield true;
    await Future<void>.delayed(const Duration(seconds: 5));
    yield false;
  }
});

/// Firmware update available — stubbed false until the OTA check service is
/// implemented. The header shows an "Update" button when this is true.
final firmwareUpdateAvailableProvider = Provider<bool>((_) => false);
