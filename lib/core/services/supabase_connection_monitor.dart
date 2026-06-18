import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/services/connectivity_service.dart';

/// High-level connection health combining network + auth token state.
enum ConnectionHealth { connected, offline, authExpired }

/// Combines connectivity + Supabase auth validity into a single health signal.
/// Also provides a retry-with-backoff utility for all Supabase calls.
class SupabaseConnectionMonitor {
  const SupabaseConnectionMonitor();

  /// Retries [op] with exponential backoff. Base delay doubles each attempt
  /// (200ms, 400ms, 800ms, ...) with jitter. Rethrows the last error on
  /// exhaustion.
  static Future<T> withRetry<T>(
    Future<T> Function() op, {
    int maxAttempts = 3,
  }) async {
    final rng = Random();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await op();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final baseMs = 200 * (1 << (attempt - 1)); // 200, 400, 800...
        final jitter = rng.nextInt(baseMs ~/ 2);
        await Future<void>.delayed(Duration(milliseconds: baseMs + jitter));
      }
    }
    throw StateError('unreachable');
  }
}

/// True when online AND the user has a valid auth session.
final supabaseReadyProvider = Provider<bool>((ref) {
  final connectivity =
      ref.watch(connectivityStateProvider).valueOrNull ?? ConnectivityStatus.offline;
  final hasUser = ref.watch(currentUserIdProvider) != null;
  return connectivity == ConnectivityStatus.online && hasUser;
});

/// UI-facing connection health: connected / offline / authExpired.
final connectionHealthProvider = Provider<ConnectionHealth>((ref) {
  final connectivity =
      ref.watch(connectivityStateProvider).valueOrNull ?? ConnectivityStatus.offline;
  if (connectivity == ConnectivityStatus.offline) return ConnectionHealth.offline;
  final hasUser = ref.watch(currentUserIdProvider) != null;
  if (!hasUser) return ConnectionHealth.authExpired;
  return ConnectionHealth.connected;
});
