import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'user.freezed.dart';

/// hlth-repository-api.md §3 — domain model paired with the `users` table.
/// Timestamps are exposed as DateTime UTC; drift row uses Unix sec.
@freezed
class User with _$User {
  const factory User({
    required String id,
    String? email,
    String? phone,
    String? displayName,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _User;
}

/// Paired with `user_profiles`. Profile data the band needs plus app-only fields.
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String userId,
    DateTime? dateOfBirth,
    @Default(SexAtBirth.unknown) SexAtBirth sexAtBirth,
    double? heightCm,
    double? weightKg,
    @Default(true) bool usesMetric,
    @Default(true) bool uses24hClock,
    int? restingHrBaseline,
    @Default(false) bool cycleTrackingEnabled,
    DateTime? lastPeriodStartDate,
    int? typicalCycleLength,
    required DateTime updatedAt,
  }) = _UserProfile;
}
