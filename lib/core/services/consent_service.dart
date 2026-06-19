import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/config/geo_config.dart';
import 'package:hlth_app/core/config/region_detector.dart';
import 'package:hlth_app/core/services/supabase_connection_monitor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Current policy version. Bump when the privacy policy text changes —
/// users who consented to an older version will be re-prompted.
const kCurrentPolicyVersion = '1.0.0';

/// Per-consent-type status.
class ConsentStatus {
  const ConsentStatus({
    required this.type,
    required this.granted,
    this.grantedAt,
    this.policyVersion,
  });

  final String type;
  final bool granted;
  final DateTime? grantedAt;
  final String? policyVersion;
}

/// Manages user consent records — both locally (for offline access)
/// and in Supabase (for audit trail / legal compliance).
class ConsentService {
  ConsentService(this._client);

  final SupabaseClient _client;

  /// Check whether all required consents for [config] have been granted.
  Future<bool> hasRequiredConsent(GeoConfig config) async {
    for (final type in config.requiredConsentTypes) {
      final status = await getStatus(type);
      if (!status.granted) return false;
      // Re-prompt if policy version changed.
      if (status.policyVersion != kCurrentPolicyVersion) return false;
    }
    return true;
  }

  /// Get the current consent status for a given [type].
  /// Checks local cache first, falls back to Supabase.
  Future<ConsentStatus> getStatus(String type) async {
    // Try local cache first (offline support).
    final prefs = await SharedPreferences.getInstance();
    final localKey = 'consent_${type}_granted';
    final localVersion = prefs.getString('consent_${type}_version');
    final localGranted = prefs.getBool(localKey);

    if (localGranted != null) {
      return ConsentStatus(
        type: type,
        granted: localGranted,
        policyVersion: localVersion,
      );
    }

    // Not cached locally — try Supabase.
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return ConsentStatus(type: type, granted: false);
      }

      final response = await _client
          .from('consent_records')
          .select()
          .eq('user_id', userId)
          .eq('consent_type', type)
          .isFilter('revoked_at', null)
          .order('granted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['granted'] == true) {
        // Cache locally.
        await prefs.setBool(localKey, true);
        await prefs.setString(
          'consent_${type}_version',
          response['policy_version'] as String,
        );
        return ConsentStatus(
          type: type,
          granted: true,
          grantedAt: DateTime.tryParse(response['granted_at'] as String),
          policyVersion: response['policy_version'] as String,
        );
      }
    } catch (_) {
      // Offline or error — fall through to not granted.
    }

    return ConsentStatus(type: type, granted: false);
  }

  /// Record a consent grant. Writes to both Supabase and local cache.
  Future<void> recordConsent({
    required String type,
    required bool granted,
    required GeoRegion region,
    String policyVersion = kCurrentPolicyVersion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_${type}_granted', granted);
    await prefs.setString('consent_${type}_version', policyVersion);

    // Push to Supabase (best-effort).
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseConnectionMonitor.withRetry(() async {
        await _client.from('consent_records').insert({
          'user_id': userId,
          'consent_type': type,
          'granted': granted,
          'policy_version': policyVersion,
          'geo_region': region.name,
        });
      });
    } catch (_) {
      // Will sync on next app start when online.
    }
  }

  /// Revoke a previously granted consent.
  Future<void> revokeConsent(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_${type}_granted', false);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseConnectionMonitor.withRetry(() async {
        await _client
            .from('consent_records')
            .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', userId)
            .eq('consent_type', type)
            .isFilter('revoked_at', null);
      });
    } catch (_) {}
  }
}

final consentServiceProvider = Provider<ConsentService>((ref) {
  return ConsentService(ref.watch(supabaseClientProvider));
});

/// Whether all required consents for the current geo region have been granted.
final hasRequiredConsentProvider = FutureProvider<bool>((ref) async {
  final config = ref.watch(geoConfigProvider);
  final consentService = ref.watch(consentServiceProvider);
  return consentService.hasRequiredConsent(config);
});
