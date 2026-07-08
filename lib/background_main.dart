import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/config/app_env.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
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
  await Breadcrumbs.init('headless');

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
    Breadcrumbs.log('bg: supabase init skipped ($e)');
  }

  // Notification channels must exist in THIS process for the alert rules
  // (morning report, breathing disruption, …) to actually post. No
  // permission request here — headless can't show the OS prompt; the UI
  // asked at first launch.
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('[bg] notification init failed: $e');
    Breadcrumbs.log('bg: notification init failed ($e)');
  }

  final container = ProviderContainer();

  // Reading the coordinator wires the whole pipeline: the hlth/ble tick
  // listener, sync orchestration, scoring, cloud outbox, alert evaluation
  // AND band reconnection (immediate + every 5 min while disconnected) —
  // identical to the UI's `ref.watch` in app.dart. Reconnect ownership
  // moved INTO the coordinator (2026-07-07): keeping it only here left the
  // "UI engine alive but backgrounded" case with nobody re-initiating the
  // BLE link after a drop — the app sat alive-but-deaf all night.
  container.read(periodicSyncCoordinatorProvider);

  Breadcrumbs.log('bg: headless sync engine ready');
  debugPrint('[bg] headless sync engine ready');
  // No runApp: the isolate stays alive through the coordinator's active
  // listeners (tick stream, connection stream, reconnect timer).
}
