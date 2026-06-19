import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Monitors auth state for token refresh failures and attempts recovery.
///
/// On persistent failure, sets [needsReAuth] to true so the router can
/// show a soft re-authentication overlay without losing local data.
class AuthRecovery {
  AuthRecovery(this._client) {
    _sub = _client.auth.onAuthStateChange.listen(_onAuthEvent);
  }

  final SupabaseClient _client;
  StreamSubscription<AuthState>? _sub;

  final _needsReAuth = StreamController<bool>.broadcast();
  Stream<bool> get needsReAuth => _needsReAuth.stream;

  bool _reAuthRequired = false;
  bool get isReAuthRequired => _reAuthRequired;

  int _refreshFailures = 0;
  static const _maxFailures = 3;

  void _onAuthEvent(AuthState state) {
    if (state.event == AuthChangeEvent.tokenRefreshed) {
      // Successful refresh — reset failure counter.
      _refreshFailures = 0;
      if (_reAuthRequired) {
        _reAuthRequired = false;
        _needsReAuth.add(false);
      }
    } else if (state.event == AuthChangeEvent.signedOut) {
      // Explicit sign-out — not a failure.
      _refreshFailures = 0;
      _reAuthRequired = false;
    }
  }

  /// Called externally when a Supabase API call gets a 401. Attempts
  /// a manual session refresh. After [_maxFailures] consecutive failures,
  /// flags the user as needing re-authentication.
  Future<void> onAuthError() async {
    _refreshFailures++;

    if (_refreshFailures <= _maxFailures) {
      try {
        await _client.auth.refreshSession();
        _refreshFailures = 0;
        return; // Recovery successful.
      } catch (_) {
        // Fall through to check threshold.
      }
    }

    if (_refreshFailures >= _maxFailures && !_reAuthRequired) {
      _reAuthRequired = true;
      _needsReAuth.add(true);
    }
  }

  void dispose() {
    _sub?.cancel();
    _needsReAuth.close();
  }
}

final authRecoveryProvider = Provider<AuthRecovery>((ref) {
  final recovery = AuthRecovery(ref.watch(supabaseClientProvider));
  ref.onDispose(recovery.dispose);
  return recovery;
});

/// Stream that emits true when the user needs to re-authenticate.
final needsReAuthProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRecoveryProvider).needsReAuth;
});
