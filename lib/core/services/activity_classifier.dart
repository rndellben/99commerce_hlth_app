import 'package:hlth_app/core/models/step_bucket.dart';

/// Activity intensity zone per 15-minute step bucket.
///
/// Thresholds derived from Tudor-Locke cadence research applied to the
/// band's 15-min step granularity:
///   * <60 spm  → sedentary  (<900 steps / 15 min)
///   * 60–99    → light       (900–1499)
///   * 100–129  → moderate    (1500–1949)
///   * ≥130     → vigorous    (≥1950)
///
/// We round those onto product-friendly bucket boundaries below. The
/// `active_minutes` daily total uses Apple Health's "Exercise Ring"
/// convention — only moderate + vigorous count.
enum ActivityZone {
  sedentary,
  light,
  moderate,
  vigorous,
}

extension ActivityZoneLabel on ActivityZone {
  String get label {
    switch (this) {
      case ActivityZone.sedentary:
        return 'sedentary';
      case ActivityZone.light:
        return 'light';
      case ActivityZone.moderate:
        return 'moderate';
      case ActivityZone.vigorous:
        return 'vigorous';
    }
  }
}

class ActivityClassifier {
  // Step-count thresholds per 15-min bucket. Tweak as we gather more
  // real-world data. Treat as a permanent contract once the daily-rollup
  // pipeline depends on them — history will be re-classifiable but
  // baselines won't shift retroactively.
  static const int sedentaryMax = 99;      // 0–99       → sedentary
  static const int lightMax = 1499;        // 100–1499   → light
  static const int moderateMax = 2249;     // 1500–2249  → moderate
  // anything above → vigorous

  static const int bucketMinutes = 15;

  ActivityZone classifyBucket(StepBucket bucket) =>
      classifySteps(bucket.steps);

  ActivityZone classifySteps(int steps) {
    if (steps <= sedentaryMax) return ActivityZone.sedentary;
    if (steps <= lightMax) return ActivityZone.light;
    if (steps <= moderateMax) return ActivityZone.moderate;
    return ActivityZone.vigorous;
  }

  /// Apple-style "active minutes" — sum of bucket minutes labeled
  /// moderate or vigorous. Excludes light because most people get hours
  /// of incidental light activity that doesn't reflect intentional
  /// exercise.
  int activeMinutes(List<StepBucket> buckets) {
    var minutes = 0;
    for (final b in buckets) {
      final z = classifyBucket(b);
      if (z == ActivityZone.moderate || z == ActivityZone.vigorous) {
        minutes += bucketMinutes;
      }
    }
    return minutes;
  }

  /// Returns minute-counts per zone for a day. Useful for UI breakdowns
  /// and for the debug `Aggregate Day` log.
  Map<ActivityZone, int> minutesByZone(List<StepBucket> buckets) {
    final out = <ActivityZone, int>{
      ActivityZone.sedentary: 0,
      ActivityZone.light: 0,
      ActivityZone.moderate: 0,
      ActivityZone.vigorous: 0,
    };
    for (final b in buckets) {
      final z = classifyBucket(b);
      out[z] = (out[z] ?? 0) + bucketMinutes;
    }
    return out;
  }
}
