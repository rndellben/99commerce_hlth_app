import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/models/entitlement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches the user's subscription from Supabase and caches locally
/// for offline access.
class EntitlementService {
  EntitlementService(this._client);

  final SupabaseClient _client;

  static const _kTierKey = 'hlth_subscription_tier';
  static const _kExpiresKey = 'hlth_subscription_expires';

  /// Fetch the current entitlement. Tries Supabase first, falls back
  /// to local cache.
  Future<Entitlement> fetchEntitlement() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return _fallbackFromCache();

      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        await _cache(SubscriptionTier.free, null);
        return const Entitlement(tier: SubscriptionTier.free);
      }

      final tier = response['tier'] == 'premium'
          ? SubscriptionTier.premium
          : SubscriptionTier.free;
      final expiresAt = response['expires_at'] != null
          ? DateTime.tryParse(response['expires_at'] as String)
          : null;

      await _cache(tier, expiresAt);
      return Entitlement(tier: tier, expiresAt: expiresAt);
    } catch (_) {
      return _fallbackFromCache();
    }
  }

  Future<void> _cache(SubscriptionTier tier, DateTime? expiresAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTierKey, tier.name);
    if (expiresAt != null) {
      await prefs.setString(_kExpiresKey, expiresAt.toIso8601String());
    } else {
      await prefs.remove(_kExpiresKey);
    }
  }

  Future<Entitlement> _fallbackFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final tierName = prefs.getString(_kTierKey);
    final tier = tierName == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
    final expiresStr = prefs.getString(_kExpiresKey);
    final expiresAt =
        expiresStr != null ? DateTime.tryParse(expiresStr) : null;
    return Entitlement(tier: tier, expiresAt: expiresAt);
  }
}

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService(ref.watch(supabaseClientProvider));
});

/// The user's current entitlement, refreshed on app start and when
/// auth state changes.
final entitlementProvider = FutureProvider<Entitlement>((ref) async {
  // Re-fetch when auth state changes (sign-in, token refresh).
  ref.watch(authStateProvider);
  final svc = ref.watch(entitlementServiceProvider);
  return svc.fetchEntitlement();
});
