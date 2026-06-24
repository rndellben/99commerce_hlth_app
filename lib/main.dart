import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/app.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/config/app_env.dart';
import 'package:hlth_app/core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnv.assertConfigured();
  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      // `publishableKey` replaces the deprecated `anonKey` in supabase_flutter
      // 2.8+. Same role: long-lived public JWT, safe to ship in clients.
      publishableKey: AppEnv.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureAuthStorage(),
        // Auto-refresh access tokens before they expire.
        autoRefreshToken: true,
      ),
      // Realtime is unused in V1.0 — keep the events-per-second low so the
      // websocket warm-up cost stays small if anything subscribes later.
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 2,
      ),
    );
  } catch (e, st) {
    // Offline-first-boot graceful failure: the app still launches into a
    // "retry" surface (handled by the router's auth-state-aware redirect)
    // instead of crashing. Real diagnostic goes to console.
    debugPrint('Supabase.initialize failed: $e\n$st');
  }
  // Set up local notifications (channels) and request permission once at
  // boot. The OS only prompts on the first call; later calls just return
  // the stored decision. Non-fatal — the app launches regardless.
  try {
    final notifications = NotificationService();
    await notifications.init();
    await notifications.requestPermission();
  } catch (e, st) {
    debugPrint('Notification init failed: $e\n$st');
  }

  runApp(const ProviderScope(child: HlthApp()));
}
