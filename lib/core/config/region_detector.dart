import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/config/geo_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects the user's geo region from device locale, with manual override.
///
/// Priority:
///   1. Explicit user override (stored in SharedPreferences)
///   2. Device locale country code → [GeoRegion] mapping
///   3. Fallback: [GeoRegion.other] (EU-strict defaults)
class RegionDetector {
  static const _kOverrideKey = 'hlth_geo_region_override';

  /// Country codes → GeoRegion mapping. ISO 3166-1 alpha-2.
  static const _countryMap = <String, GeoRegion>{
    // EU member states
    'AT': GeoRegion.eu, 'BE': GeoRegion.eu, 'BG': GeoRegion.eu,
    'HR': GeoRegion.eu, 'CY': GeoRegion.eu, 'CZ': GeoRegion.eu,
    'DK': GeoRegion.eu, 'EE': GeoRegion.eu, 'FI': GeoRegion.eu,
    'FR': GeoRegion.eu, 'DE': GeoRegion.eu, 'GR': GeoRegion.eu,
    'HU': GeoRegion.eu, 'IE': GeoRegion.eu, 'IT': GeoRegion.eu,
    'LV': GeoRegion.eu, 'LT': GeoRegion.eu, 'LU': GeoRegion.eu,
    'MT': GeoRegion.eu, 'NL': GeoRegion.eu, 'PL': GeoRegion.eu,
    'PT': GeoRegion.eu, 'RO': GeoRegion.eu, 'SK': GeoRegion.eu,
    'SI': GeoRegion.eu, 'ES': GeoRegion.eu, 'SE': GeoRegion.eu,
    // EEA (GDPR applies)
    'IS': GeoRegion.eu, 'LI': GeoRegion.eu, 'NO': GeoRegion.eu,
    // UK (UK GDPR — same rules)
    'GB': GeoRegion.eu,
    // US & territories
    'US': GeoRegion.us, 'PR': GeoRegion.us, 'GU': GeoRegion.us,
    'VI': GeoRegion.us, 'AS': GeoRegion.us,
    // Thailand
    'TH': GeoRegion.th,
    // China
    'CN': GeoRegion.cn,
  };

  /// Detect region from device locale.
  static GeoRegion detectFromLocale() {
    try {
      final locale = Platform.localeName; // e.g. "en_US", "th_TH"
      final parts = locale.split(RegExp(r'[_\-]'));
      if (parts.length >= 2) {
        final country = parts[1].toUpperCase();
        return _countryMap[country] ?? GeoRegion.other;
      }
    } catch (_) {
      // Platform.localeName can throw on some platforms.
    }
    return GeoRegion.other;
  }

  /// Read the user's explicit override (if any).
  static Future<GeoRegion?> getOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kOverrideKey);
    if (value == null) return null;
    return GeoRegion.values.where((r) => r.name == value).firstOrNull;
  }

  /// Save an explicit region override.
  static Future<void> setOverride(GeoRegion region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOverrideKey, region.name);
  }

  /// Clear the override so locale detection takes over again.
  static Future<void> clearOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOverrideKey);
  }

  /// Resolve the effective region (override > locale > fallback).
  static Future<GeoRegion> resolve() async {
    final override = await getOverride();
    if (override != null) return override;
    return detectFromLocale();
  }
}

/// The user's detected (or overridden) geo region.
final detectedRegionProvider = FutureProvider<GeoRegion>((ref) async {
  return RegionDetector.resolve();
});

/// The fully-resolved geo config for the current user's region.
final geoConfigProvider = Provider<GeoConfig>((ref) {
  final region =
      ref.watch(detectedRegionProvider).valueOrNull ?? GeoRegion.other;
  return GeoConfig.forRegion(region);
});
