import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/repositories/baseline_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/baseline_service.dart';

/// Progressive feature unlock per hlth-onboarding-timeline.md.
///
/// A feature is **available** when both gates pass:
///   1. `daysSinceFirstWear >= required_days` — enough calendar time has
///      elapsed since the user first paired their band.
///   2. `baselineEstablished[metric]` — the metric has accumulated enough
///      samples (window/2 daily values, per BaselineRepository.isEstablished)
///      for its reading to be trusted.
///
/// Day-0 features (HR, SpO2, steps, respiratory, fall detection) don't gate
/// on baselines — they're raw readings that work from the first measurement.
class FeatureGate {
  FeatureGate({
    required this.daysSinceFirstWear,
    this.baselineEstablished = const {},
  });

  final int daysSinceFirstWear;
  final Map<String, bool> baselineEstablished;

  bool _baseline(String metric) => baselineEstablished[metric] ?? false;

  // ── Day 0 — raw measurements ────────────────────────────────────────────
  bool get heartRate => true;
  bool get spo2 => true;
  bool get steps => true;
  bool get respiratoryRate => true;
  bool get fallDetection => true;

  // ── Day 1+ — needs at least one night ───────────────────────────────────
  bool get basicSleep => daysSinceFirstWear >= 1;

  // ── Day 3+ — needs a few nights ─────────────────────────────────────────
  bool get sleepStaging => daysSinceFirstWear >= 3;
  bool get sleepBreathingBasic => daysSinceFirstWear >= 3;
  bool get weeklyInsights => daysSinceFirstWear >= 7;

  // ── Day 14+ — needs 14-day baseline ─────────────────────────────────────
  bool get recoveryScore =>
      daysSinceFirstWear >= 14 &&
      _baseline(BaselineMetric.restingHrBpm) &&
      _baseline(BaselineMetric.hrvRmssdMs);

  bool get stressScore =>
      daysSinceFirstWear >= 14 && _baseline(BaselineMetric.hrvRmssdMs);

  bool get vascularAge => daysSinceFirstWear >= 14;
  bool get cardiacOutput => daysSinceFirstWear >= 14;

  bool get mentalWellnessBasic =>
      daysSinceFirstWear >= 14 && _baseline(BaselineMetric.hrvRmssdMs);

  bool get bodyAgePreliminary =>
      daysSinceFirstWear >= 14 &&
      _baseline(BaselineMetric.restingHrBpm);

  // ── Day 30+ — needs 30-day baselines ────────────────────────────────────
  bool get illnessWarning =>
      daysSinceFirstWear >= 30 &&
      _baseline(BaselineMetric.restingHrBpm) &&
      _baseline(BaselineMetric.hrvRmssdMs) &&
      _baseline(BaselineMetric.spo2OvernightAvg) &&
      _baseline(BaselineMetric.respRateBpm);

  bool get menstrualCycle =>
      daysSinceFirstWear >= 30 &&
      _baseline(BaselineMetric.restingHrBpm) &&
      _baseline(BaselineMetric.hrvRmssdMs);

  bool get breathingAlerts =>
      daysSinceFirstWear >= 30 && _baseline(BaselineMetric.spo2OvernightAvg);

  bool get mentalWellnessFull =>
      daysSinceFirstWear >= 30 && _baseline(BaselineMetric.hrvRmssdMs);

  bool get bodyAgeFull =>
      daysSinceFirstWear >= 30 &&
      _baseline(BaselineMetric.restingHrBpm) &&
      _baseline(BaselineMetric.hrvRmssdMs);

  // ── Day 60+ ─────────────────────────────────────────────────────────────
  bool get cyclePhasePrediction => daysSinceFirstWear >= 60;

  // ── Day 90+ — longevity / trends ────────────────────────────────────────
  bool get longTermTrends => daysSinceFirstWear >= 90;

  // ── UX helpers ──────────────────────────────────────────────────────────
  int get daysUntilRecovery => _daysUntil(14);
  int get daysUntilIllnessWarning => _daysUntil(30);
  int get daysUntilBodyAge => _daysUntil(14);

  /// Onboarding progress bar (0.0 → 1.0 over the first 14 days).
  double get onboardingProgress =>
      (daysSinceFirstWear / 14.0).clamp(0.0, 1.0);

  int _daysUntil(int target) =>
      (target - daysSinceFirstWear).clamp(0, target);
}

/// Earliest active-device pairing timestamp — the user's "Day 0".
/// Stream-backed so the home screen's "Day N of 14" counter reactively
/// updates when the user pairs, forgets, or re-pairs a band (the binding
/// flow toggles `devices.isActive`, which would otherwise leave a cached
/// null from a one-shot FutureProvider read at app start).
final firstWearDateProvider = StreamProvider<DateTime?>((ref) {
  final repo = ref.watch(deviceRepositoryProvider);
  return repo
      .watchActive(ActiveSession.defaultUserId)
      .map((device) => device?.pairedAt);
});

/// Map of metric → whether its 14-day baseline is established (≥7 samples).
/// Recovery / illness / body-age gates consult this in addition to calendar days.
final baselineEstablishedProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final repo = ref.watch(baselineRepositoryProvider);
  final out = <String, bool>{};
  for (final metric in BaselineMetric.all) {
    out[metric] = await repo.isEstablished(
      userId: ActiveSession.defaultUserId,
      metricKey: metric,
      windowDays: 14,
    );
  }
  return out;
});

final featureGateProvider = Provider<FeatureGate>((ref) {
  final firstWear = ref.watch(firstWearDateProvider).valueOrNull;
  final baselines =
      ref.watch(baselineEstablishedProvider).valueOrNull ?? const {};
  final days = firstWear == null
      ? 0
      : DateTime.now().toUtc().difference(firstWear.toUtc()).inDays;
  return FeatureGate(
    daysSinceFirstWear: days,
    baselineEstablished: baselines,
  );
});
