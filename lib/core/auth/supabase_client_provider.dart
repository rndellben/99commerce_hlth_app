import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the singleton [SupabaseClient] via Riverpod.
///
/// `Supabase.initialize` is called once from `main.dart` BEFORE the
/// `runApp` — this provider only surfaces the already-initialized client
/// to the rest of the app. We deliberately don't initialize inside the
/// provider so that init failures (no network on first boot, malformed
/// URL) surface at app startup with a clear stack trace, not lazily
/// when the first screen tries to use it.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// `LocalStorage` adapter for Supabase Auth backed by
/// [FlutterSecureStorage] so refresh tokens land in iOS Keychain /
/// Android EncryptedSharedPreferences, not in plain SharedPreferences.
///
/// Pass an instance of this to `Supabase.initialize(authOptions:
/// AuthClientOptions(localStorage: SecureAuthStorage()))`.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {
    // Nothing to do; FlutterSecureStorage is always-ready.
  }

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: _kSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return (await _storage.read(key: _kSessionKey)) != null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _kSessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _kSessionKey);
  }

  static const _kSessionKey = 'supabase.auth.token';
}
