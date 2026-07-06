import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/config/app_env.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/sync_service.dart';

/// Headless entrypoint for background sync — executed by the native
/// `HeadlessSyncEngine` when the user swipes the app away (or the watchdog
/// revives a killed process). Boots the SAME provider graph the UI uses —
/// database, repos, SyncService, PeriodicSyncCoordinator, AlertEvaluator —
/// just without any widgets, so overnight collection, scoring and the
/// morning notification keep working with no UI alive.
///
/// The native side guarantees at most ONE Dart sync brain: this engine is
/// destroyed before the UI engine registers (MainActivity), and is never
/// started while the UI is attached.
@pragma('vm:entry-point')
Future<void> backgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Registers plugin Dart-side registrants on this background isolate
  // (path_provider, shared_preferences, flutter_local_notifications, …).
  DartPluginRegistrant.ensureInitialized();

  debugPrint('[bg] headless sync engine booting');

  // Same offline-tolerant Supabase boot as main.dart — cloud push is a
  // best-effort mirror; sync must run without it.
  try {
    AppEnv.assertConfigured();
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(),
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(eventsPerSecond: 2),
    );
  } catch (e) {
    debugPrint('[bg] Supabase init skipped: $e');
  }

  // Notification channels must exist in THIS process for the alert rules
  // (morning report, breathing disruption, …) to actually post. No
  // permission request here — headless can't show the OS prompt; the UI
  // asked at first launch.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[bg] notification init failed: $e');
  }

  final container = ProviderContainer();

  // Reading the coordinator wires the whole pipeline: the hlth/ble tick
  // listener, sync orchestration, scoring, cloud outbox and alert
  // evaluation — identical to the UI's `ref.watch` in app.dart.
  container.read(periodicSyncCoordinatorProvider);

  // The UI flow never needs an auto-connect (the SDK reconnects while the
  // process lives), but after a process death nobody re-initiates the BLE
  // link — so the headless brain owns reconnection: try now, then retry
  // every 5 minutes while disconnected. connect() is a no-op-ish direct
  // connect by MAC; no scanning (which would need an Activity).
  final ble = container.read(bleServiceProvider);
  final deviceRepo = container.read(deviceRepositoryProvider);

  Future<void> tryReconnect() async {
    try {
      if (ble.currentConnectionState == BleConnectionState.connected) return;
      final device = await deviceRepo.getActiveForUser(
        ActiveSession.defaultUserId,
      );
      final mac = device?.macAddress;
      if (mac == null || mac.isEmpty) return;
      debugPrint('[bg] reconnecting to $mac');
      await ble.connect(mac);
    } catch (e) {
      debugPrint('[bg] reconnect attempt failed: $e');
    }
  }

  await tryReconnect();
  Timer.periodic(const Duration(minutes: 5), (_) => tryReconnect());

  debugPrint('[bg] headless sync engine ready');
  // No runApp: the isolate stays alive through the active listeners
  // (tick stream, connection stream, reconnect timer).
}
