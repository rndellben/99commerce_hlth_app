import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hlth_app/core/auth/auth_failure.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';

/// Thin facade over `supabase.auth` that returns typed [AuthFailure]
/// errors instead of leaking `AuthException` to feature code.
///
/// All three methods follow the same shape: success returns `null`,
/// failure returns an `AuthFailure` so UIs can branch without try/catch.
class AuthController {
  AuthController(this._client);

  final SupabaseClient _client;

  /// Returns `null` on success, an [AuthFailure] otherwise. On success
  /// the underlying auth state stream emits `signedIn`, which downstream
  /// providers + the router redirect react to.
  Future<AuthFailure?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return _mapAuthException(e);
    } on SocketException {
      return const AuthNetworkError();
    } catch (e, st) {
      debugPrint('AuthController.signUp unexpected: $e\n$st');
      return UnknownAuthFailure(e.toString());
    }
  }

  /// Returns `null` on success, an [AuthFailure] otherwise.
  Future<AuthFailure?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return _mapAuthException(e);
    } on SocketException {
      return const AuthNetworkError();
    } catch (e, st) {
      debugPrint('AuthController.signIn unexpected: $e\n$st');
      return UnknownAuthFailure(e.toString());
    }
  }

  /// Best-effort sign-out. Failures are swallowed because the only thing
  /// the user can do about a failed sign-out is restart the app, and
  /// local session state gets cleared regardless.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e, st) {
      debugPrint('AuthController.signOut: $e\n$st');
    }
  }

  /// Maps a Supabase `AuthException` to an [AuthFailure]. We branch on
  /// status code AND message because gotrue's error shape varies between
  /// dashboard versions — both signals together are more robust than
  /// either alone.
  AuthFailure _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.statusCode;

    if (code == '400' || code == 400.toString()) {
      if (msg.contains('invalid login') || msg.contains('credentials')) {
        return const InvalidCredentials();
      }
      if (msg.contains('password') &&
          (msg.contains('short') || msg.contains('weak'))) {
        return const WeakPassword();
      }
    }
    if (code == '422' || code == 422.toString()) {
      if (msg.contains('already registered') || msg.contains('user already')) {
        return const EmailTaken();
      }
      if (msg.contains('password')) {
        return const WeakPassword();
      }
    }
    if (msg.contains('email not confirmed')) {
      return const EmailNotConfirmed();
    }
    return UnknownAuthFailure(e.message);
  }
}

/// Single-instance `AuthController` keyed on the Supabase client.
final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(supabaseClientProvider));
});
