/// Supported geographic regions for privacy configuration.
enum GeoRegion { eu, us, th, cn, other }

/// Geo-specific privacy and data handling configuration.
///
/// Each [GeoRegion] maps to a [GeoConfig] that controls consent flows,
/// data retention, minimum age requirements, and regulatory notices.
/// Default fallback is EU-strict (safest for unknown regions).

class GeoConfig {
  const GeoConfig({
    required this.region,
    required this.requiresExplicitConsent,
    required this.dataRetentionMaxDays,
    required this.supportsRightToDelete,
    required this.requiresMinorConsentGate,
    required this.minimumAge,
    required this.privacyPolicyUrl,
    required this.dataResidencyRegion,
    required this.regulatoryLabel,
  });

  final GeoRegion region;

  /// GDPR Art. 6 / PIPL: user must explicitly opt-in to data processing.
  final bool requiresExplicitConsent;

  /// Max days health data may be retained in cloud storage.
  final int dataRetentionMaxDays;

  /// GDPR Art. 17 / CCPA: user can request full account deletion.
  final bool supportsRightToDelete;

  /// Whether the onboarding flow must include a minor-consent check.
  final bool requiresMinorConsentGate;

  /// Minimum age for account creation.
  final int minimumAge;

  /// Region-specific privacy policy URL.
  final String privacyPolicyUrl;

  /// Supabase region where data is stored.
  final String dataResidencyRegion;

  /// Short label shown in settings (e.g. "GDPR", "CCPA").
  final String regulatoryLabel;

  /// Required consent types for this region. Must all be granted before
  /// the user can proceed past onboarding.
  List<String> get requiredConsentTypes {
    if (requiresExplicitConsent) {
      return const ['data_processing', 'health_data'];
    }
    return const ['health_data'];
  }

  // ── Static factories ───────────────────────────────────────────────────

  /// EU — GDPR. Strictest: explicit consent, right to delete, age 16.
  static const eu = GeoConfig(
    region: GeoRegion.eu,
    requiresExplicitConsent: true,
    dataRetentionMaxDays: 365 * 3, // 3 years
    supportsRightToDelete: true,
    requiresMinorConsentGate: true,
    minimumAge: 16,
    privacyPolicyUrl: 'https://hlth.app/privacy/eu',
    dataResidencyRegion: 'eu-central-1',
    regulatoryLabel: 'GDPR',
  );

  /// US — CCPA/HIPAA-adjacent. No explicit consent required, right to delete.
  static const us = GeoConfig(
    region: GeoRegion.us,
    requiresExplicitConsent: false,
    dataRetentionMaxDays: 365 * 5, // 5 years
    supportsRightToDelete: true,
    requiresMinorConsentGate: true,
    minimumAge: 13,
    privacyPolicyUrl: 'https://hlth.app/privacy/us',
    dataResidencyRegion: 'eu-central-1', // V1: all data in Frankfurt
    regulatoryLabel: 'CCPA',
  );

  /// Thailand — PDPA. Similar to GDPR, explicit consent required.
  static const th = GeoConfig(
    region: GeoRegion.th,
    requiresExplicitConsent: true,
    dataRetentionMaxDays: 365 * 3,
    supportsRightToDelete: true,
    requiresMinorConsentGate: false,
    minimumAge: 13,
    privacyPolicyUrl: 'https://hlth.app/privacy/th',
    dataResidencyRegion: 'eu-central-1',
    regulatoryLabel: 'PDPA',
  );

  /// China — PIPL. Strictest consent + data residency notices.
  static const cn = GeoConfig(
    region: GeoRegion.cn,
    requiresExplicitConsent: true,
    dataRetentionMaxDays: 365 * 2, // 2 years
    supportsRightToDelete: true,
    requiresMinorConsentGate: true,
    minimumAge: 14,
    privacyPolicyUrl: 'https://hlth.app/privacy/cn',
    dataResidencyRegion: 'eu-central-1', // V1: note cross-border transfer
    regulatoryLabel: 'PIPL',
  );

  /// Fallback — defaults to EU-strict (safest for unknown regions).
  static const other = GeoConfig(
    region: GeoRegion.other,
    requiresExplicitConsent: true,
    dataRetentionMaxDays: 365 * 3,
    supportsRightToDelete: true,
    requiresMinorConsentGate: false,
    minimumAge: 13,
    privacyPolicyUrl: 'https://hlth.app/privacy',
    dataResidencyRegion: 'eu-central-1',
    regulatoryLabel: 'Privacy',
  );

  /// Lookup by region enum.
  static GeoConfig forRegion(GeoRegion region) => switch (region) {
        GeoRegion.eu => eu,
        GeoRegion.us => us,
        GeoRegion.th => th,
        GeoRegion.cn => cn,
        GeoRegion.other => other,
      };
}
