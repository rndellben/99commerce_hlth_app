import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// How disrupted a night's breathing looked, from the SpO2 desaturation
/// depth + count. Bands are wellness observations for copy/colour only —
/// deliberately NOT the clinical AHI mild/moderate/severe cut-offs (we can't
/// measure events/hr from hourly buckets, and naming them would imply a
/// diagnosis we don't make).
enum BreathingSeverity { none, mild, moderate, marked }

/// Result of scanning one night for low-oxygen ("breathing disruption")
/// evidence. Pure + reusable: the sleep-dashboard card, the multi-night
/// trend, and the notification all run the same detection so they can never
/// disagree.
class BreathingDisruptionResult {
  const BreathingDisruptionResult({
    required this.totalBuckets,
    required this.lowBuckets,
    required this.minPct,
    required this.severity,
    required this.hrCyclingSwings,
  });

  /// Hourly SpO2 buckets with a real reading (`pctMin > 0`).
  final int totalBuckets;

  /// Buckets whose minimum SpO2 sat at/below the low threshold.
  final int lowBuckets;

  /// Lowest SpO2 seen across the night (100 if none).
  final int minPct;

  /// Wellness severity band from desaturation count + depth.
  final BreathingSeverity severity;

  /// Count of large HR swings overnight (drop-then-rebound), the coarse
  /// footprint of the bradycardia-tachycardia cycling that accompanies
  /// breathing pauses. Corroborating signal only — never fires on its own
  /// (HR sampling is too sparse to resolve individual events).
  final int hrCyclingSwings;

  /// The night crossed the flag threshold on its own SpO2 evidence.
  bool get flags => lowBuckets >= 2 && totalBuckets >= 4;

  /// SpO2 desaturation AND the HR cycling footprint agree — higher
  /// confidence this was real breathing disruption, not a sensor artifact.
  bool get corroborated => flags && hrCyclingSwings >= 3;
}

/// Overnight low-oxygen ("breathing disruption") detection — Ryan's June 17
/// ask: "an in-app alert on the sleep dashboard if your oxygen drops below a
/// certain amount for a certain amount of time while you sleep." Extended per
/// the sleep-apnea build guide with what the H59 actually exposes: a severity
/// band, HR bradycardia-tachycardia corroboration, and multi-night
/// confirmation before the push fires.
///
/// The H59 records scheduled SpO2 as HOURLY min/max buckets, so "below X for
/// a duration" is expressed in buckets: a night flags only when at least
/// [minLowBuckets] hourly buckets have `pctMin <= lowThresholdPct` — a single
/// low hour (one artifact read) never counts. The guide's accelerometer
/// breathing-pause and gyroscope body-position layers are intentionally out
/// of scope: the H59 exposes neither raw stream.
///
/// The NOTIFICATION additionally requires the pattern to repeat: at least
/// [minDisruptedNights] of the last [nightsWindow] nights must flag (guide
/// Layer 6, "single night ≠ alert"). The sleep-screen card still reflects the
/// single most-recent night so the user always sees last night's reading.
///
/// Regulatory framing: "breathing disruption / oxygen dipped" wellness
/// observation — never "sleep apnea", "AHI", or a diagnosis (AlertType §6.4).
class BreathingDisruptionRule implements AlertRule {
  BreathingDisruptionRule({
    required this.sleepRepo,
    required this.spo2Repo,
    required this.hrRepo,
    this.lowThresholdPct = 90,
    this.minLowBuckets = 2,
    this.minCoverageBuckets = 4,
    this.maxNightAge = const Duration(hours: 24),
    this.nightsWindow = 14,
    this.minDisruptedNights = 2,
  });

  final SleepRepository sleepRepo;
  final Spo2Repository spo2Repo;
  final HrRepository hrRepo;

  /// A bucket is "low" when its minimum SpO2 is at or below this.
  final int lowThresholdPct;

  /// Low buckets needed before a night flags (≈ sustained across ≥2 hours).
  final int minLowBuckets;

  /// Minimum buckets a night must carry before we'll judge it at all.
  final int minCoverageBuckets;

  /// Only fire off the most recent night, and only while it's fresh.
  final Duration maxNightAge;

  /// How far back multi-night confirmation looks.
  final int nightsWindow;

  /// Disrupted nights required inside [nightsWindow] before the push fires.
  final int minDisruptedNights;

  @override
  String get type => 'breathing_disruption';

  @override
  Duration get minInterval => const Duration(days: 7);

  /// Consecutive-sample HR delta (bpm) that counts as a "swing" edge when
  /// detecting the bradycardia-tachycardia cycling footprint.
  static const _hrSwingBpm = 8;

  /// Pure detection over one night's samples — shared by the card, the
  /// trend, and the notification. [hrSamples] is optional; without it the
  /// HR-cycling corroboration is simply absent.
  static BreathingDisruptionResult detect(
    List<Spo2Sample> spo2Samples, {
    List<HrSample> hrSamples = const [],
    int lowThresholdPct = 90,
  }) {
    var low = 0;
    var minPct = 100;
    var total = 0;
    for (final s in spo2Samples) {
      if (s.pctMin <= 0) continue; // 0 = no reading that hour
      total++;
      if (s.pctMin <= lowThresholdPct) low++;
      if (s.pctMin < minPct) minPct = s.pctMin;
    }

    return BreathingDisruptionResult(
      totalBuckets: total,
      lowBuckets: low,
      minPct: total == 0 ? 100 : minPct,
      severity: _severity(lowBuckets: low, minPct: total == 0 ? 100 : minPct),
      hrCyclingSwings: _countHrSwings(hrSamples),
    );
  }

  /// Wellness severity from desaturation count + depth. Takes the worse of
  /// the two axes so a single very deep dip isn't hidden by a low hour-count.
  static BreathingSeverity _severity({
    required int lowBuckets,
    required int minPct,
  }) {
    if (lowBuckets < 2) return BreathingSeverity.none;
    final byCount = lowBuckets >= 6
        ? BreathingSeverity.marked
        : lowBuckets >= 4
            ? BreathingSeverity.moderate
            : BreathingSeverity.mild;
    final byDepth = minPct < 80
        ? BreathingSeverity.marked
        : minPct < 85
            ? BreathingSeverity.moderate
            : BreathingSeverity.mild;
    return byCount.index >= byDepth.index ? byCount : byDepth;
  }

  /// Count of drop-then-rebound swings in overnight HR — the coarse
  /// footprint of apnea's bradycardia-tachycardia cycling. Sparse sampling
  /// (5–15 min) can't resolve individual events, so this only corroborates
  /// SpO2 evidence; it never triggers anything alone. Walks consecutive
  /// samples and counts local direction reversals whose magnitude clears
  /// [_hrSwingBpm].
  static int _countHrSwings(List<HrSample> hr) {
    if (hr.length < 3) return 0;
    final sorted = [...hr]..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    var swings = 0;
    for (var i = 1; i < sorted.length - 1; i++) {
      final prev = sorted[i - 1].bpm;
      final cur = sorted[i].bpm;
      final next = sorted[i + 1].bpm;
      final isTrough = cur < prev && cur < next;
      final isPeak = cur > prev && cur > next;
      final amplitude =
          (cur - prev).abs() < (next - cur).abs() ? (next - cur).abs() : (cur - prev).abs();
      if ((isTrough || isPeak) && amplitude >= _hrSwingBpm) swings++;
    }
    return swings;
  }

  Future<BreathingDisruptionResult> _forNight(
    String userId,
    SleepSession night,
  ) async {
    final spo2 = await spo2Repo.getInRange(
      userId: userId,
      from: night.startedAt,
      to: night.endedAt,
    );
    final hr = await hrRepo.getInRange(
      userId: userId,
      from: night.startedAt,
      to: night.endedAt,
    );
    return detect(spo2, hrSamples: hr, lowThresholdPct: lowThresholdPct);
  }

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final night = await sleepRepo.getMostRecentNightFor(ctx.userId);
    if (night == null) return null;
    if (ctx.now.difference(night.endedAt) > maxNightAge) return null;

    final latest = await _forNight(ctx.userId, night);
    if (latest.totalBuckets < minCoverageBuckets) return null;
    if (!latest.flags) return null;

    // Multi-night confirmation (guide Layer 6): a single flagged night is
    // never enough — look back over the window and require a repeating
    // pattern before nudging the user toward a professional.
    final recent = await sleepRepo.getInRange(
      userId: ctx.userId,
      from: ctx.now.subtract(Duration(days: nightsWindow)),
      to: ctx.now,
      type: SleepSessionType.night,
    );
    var disrupted = 0;
    for (final s in recent) {
      final r = await _forNight(ctx.userId, s);
      if (r.totalBuckets >= minCoverageBuckets && r.flags) disrupted++;
    }
    if (disrupted < minDisruptedNights) return null;

    return AlertCandidate(
      dedupeKey: 'breathing_disruption-${_dateKey(night.endedAt.toLocal())}',
      title: 'Recurring overnight breathing disruption',
      body: 'Your blood oxygen dropped below $lowThresholdPct% on '
          '$disrupted of the last $nightsWindow nights (last night: '
          '${latest.lowBuckets} hours, low of ${latest.minPct}%). This isn’t '
          'a diagnosis — a recurring pattern is worth mentioning to a '
          'healthcare professional.',
      payload: {
        'lowBuckets': latest.lowBuckets,
        'totalBuckets': latest.totalBuckets,
        'minPct': latest.minPct,
        'thresholdPct': lowThresholdPct,
        'severity': latest.severity.name,
        'hrCyclingSwings': latest.hrCyclingSwings,
        'corroborated': latest.corroborated,
        'disruptedNights': disrupted,
        'nightsWindow': nightsWindow,
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
    hrRepo: ref.watch(hrRepositoryProvider),
  );
});
