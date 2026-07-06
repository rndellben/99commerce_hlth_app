import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// Result of scanning one night's SpO2 buckets for sustained low oxygen.
/// Pure + reusable: the sleep-dashboard risk card runs the same detection so
/// the card and the notification can never disagree.
class BreathingDisruptionResult {
  const BreathingDisruptionResult({
    required this.totalBuckets,
    required this.lowBuckets,
    required this.minPct,
  });

  final int totalBuckets;
  final int lowBuckets;
  final int minPct;
}

/// Overnight low-oxygen ("breathing disruption") alert — Ryan's June 17 ask:
/// "an in-app alert on the sleep dashboard if your oxygen drops below a
/// certain amount for a certain amount of time while you sleep."
///
/// The H59 records scheduled SpO2 as HOURLY min/max buckets, so "below X for
/// a duration" is expressed in buckets: the night flags only when at least
/// [minLowBuckets] hourly buckets have `pctMin <= lowThresholdPct` — a single
/// low hour (one artifact read) never fires. Conservative gates:
///  * the night must have ended within [maxNightAge] of now (no stale fires),
///  * at least [minCoverageBuckets] buckets must exist (thin coverage → null).
///
/// Regulatory framing: "breathing disruption / oxygen dipped" wellness
/// observation — never "sleep apnea" as a diagnosis (AlertType enum §6.4).
class BreathingDisruptionRule implements AlertRule {
  BreathingDisruptionRule({
    required this.sleepRepo,
    required this.spo2Repo,
    this.lowThresholdPct = 90,
    this.minLowBuckets = 2,
    this.minCoverageBuckets = 4,
    this.maxNightAge = const Duration(hours: 24),
  });

  final SleepRepository sleepRepo;
  final Spo2Repository spo2Repo;

  /// A bucket is "low" when its minimum SpO2 is at or below this.
  final int lowThresholdPct;

  /// Low buckets needed before the night flags (≈ sustained across ≥2 hours).
  final int minLowBuckets;

  /// Minimum buckets the night must carry before we'll judge it at all.
  final int minCoverageBuckets;

  /// Only the most recent night, and only while it's fresh.
  final Duration maxNightAge;

  @override
  String get type => 'breathing_disruption';

  @override
  Duration get minInterval => const Duration(days: 7);

  /// Pure detection over one night's SpO2 samples — shared with the sleep
  /// screen's risk card.
  static BreathingDisruptionResult detect(
    List<Spo2Sample> samples, {
    int lowThresholdPct = 90,
  }) {
    var low = 0;
    var minPct = 100;
    for (final s in samples) {
      if (s.pctMin <= 0) continue; // 0 = no reading that hour
      if (s.pctMin <= lowThresholdPct) low++;
      if (s.pctMin < minPct) minPct = s.pctMin;
    }
    return BreathingDisruptionResult(
      totalBuckets: samples.where((s) => s.pctMin > 0).length,
      lowBuckets: low,
      minPct: minPct,
    );
  }

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final night = await sleepRepo.getMostRecentNightFor(ctx.userId);
    if (night == null) return null;
    if (ctx.now.difference(night.endedAt) > maxNightAge) return null;

    final samples = await spo2Repo.getInRange(
      userId: ctx.userId,
      from: night.startedAt,
      to: night.endedAt,
    );
    final result = detect(samples, lowThresholdPct: lowThresholdPct);
    if (result.totalBuckets < minCoverageBuckets) return null;
    if (result.lowBuckets < minLowBuckets) return null;

    return AlertCandidate(
      dedupeKey: 'breathing_disruption-${_dateKey(night.endedAt.toLocal())}',
      title: 'Overnight oxygen dipped',
      body: 'Your blood oxygen dropped below $lowThresholdPct% during '
          '${result.lowBuckets} hours of last night’s sleep. This isn’t a '
          'diagnosis — if it happens often or you wake unrefreshed, consider '
          'mentioning it to a healthcare professional.',
      payload: {
        'lowBuckets': result.lowBuckets,
        'totalBuckets': result.totalBuckets,
        'minPct': result.minPct,
        'thresholdPct': lowThresholdPct,
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final breathingDisruptionRuleProvider = Provider<BreathingDisruptionRule>((ref) {
  return BreathingDisruptionRule(
    sleepRepo: ref.watch(sleepRepositoryProvider),
    spo2Repo: ref.watch(spo2RepositoryProvider),
  );
});
