import 'package:freezed_annotation/freezed_annotation.dart';

part 'entitlement.freezed.dart';

enum SubscriptionTier { free, premium }

/// User's subscription entitlement. Determines which features are
/// available (free on-device vs premium server-side).
@freezed
class Entitlement with _$Entitlement {
  const factory Entitlement({
    required SubscriptionTier tier,
    DateTime? expiresAt,
    @Default({}) Set<String> enabledFeatures,
  }) = _Entitlement;

  const Entitlement._();

  bool get isPremium => tier == SubscriptionTier.premium;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());

  /// Effective tier accounting for expiration.
  SubscriptionTier get effectiveTier =>
      isExpired ? SubscriptionTier.free : tier;
}
