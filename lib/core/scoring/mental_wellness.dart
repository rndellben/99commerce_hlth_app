// ============================================================================
// mental_wellness.dart
//
// On-device Mental Wellness Trend metric for the hlth band.
// Derived from advanced-health-features-build-guide.md §2 ("Mental Wellness
// Trends"). This is a WELLNESS / "body stress and balance" trend — NOT a
// depression, anxiety, or mental-health diagnosis. User-facing copy must never
// use clinical terms (see the guide's "Safe Framing").
//
// Runs ONCE DAILY on the post-sleep sync tick. Reads only rolled-up
// `daily_metrics` (HRV RMSSD, resting HR, sleep deep %/efficiency/bedtime,
// steps) — no raw PPG. A 7-day window is scored against the user's own
// up-to-30-day rolling baseline. Single 0-100 score; higher = better balance.
//
// HOUSE CONVENTIONS honoured (differ from the guide's fixed-weight Python):
//   * Cold-start lock (calibrating) until enough days bank, then a provisional
//     phase while the baseline matures — mirrors Recovery / Cardio Load.
//   * NEVER fabricate a missing signal. If a sub-signal has no data in the
//     window/baseline its weight is REDISTRIBUTED across the signals that do,
//     rather than assumed. A day with no core signals produces no score.
//
// The sub-score formulas (HRV ratio, RHR deviation, sleep composite, activity
// ratio + variability, circadian consistency) and the 30/15/25/20/10 weighting
// are taken from the guide so the logic stays traceable to it. Weights, gates,
// and thresholds are starting values — TUNE ON REAL MULTI-DAY DATA.
// ============================================================================

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// PER-DAY INPUT. One per calendar day, built from a `daily_metrics` row.
// Every field is nullable — a missing signal is honestly absent, never zero.
// Fractions are stored 0..1 in the DB (the engine converts to the guide's
// percentage scale internally).
// ---------------------------------------------------------------------------
class WellnessDay {
  final double? rmssd; // overnight HRV RMSSD (ms)
  final double? rhr; // resting HR (bpm)
  final double? deepFraction; // deep sleep fraction of total (0..1)
  final double? efficiencyFraction; // sleep efficiency (0..1)
  final double? bedtimeMinutes; // wrap-anchored minutes from 18:00 local
  final double? steps; // daily step count

  const WellnessDay({
    this.rmssd,
    this.rhr,
    this.deepFraction,
    this.efficiencyFraction,
    this.bedtimeMinutes,
    this.steps,
  });

  /// A day carries a "core" autonomic signal if it has HRV or resting HR — the
  /// two signals the cold-start / coverage gate counts.
  bool get hasCore => rmssd != null || rhr != null;
}

// ---------------------------------------------------------------------------
// WEIGHTS (guide §2). Nominal — renormalised over whichever sub-scores are
// actually available on a given run.
// ---------------------------------------------------------------------------
const double _wHrv = 0.30;
const double _wRhr = 0.15;
const double _wSleep = 0.25;
const double _wActivity = 0.20;
const double _wCircadian = 0.10;

// Cold-start / maturity gates (days with a core signal in the baseline).
const int _minDaysForScore = 7; // below this → calibrating (locked)
const int _minDaysForStable = 14; // below this → provisional (guide: "2 weeks")

// Window / baseline sizes.
const int _windowDays = 7; // the "this week" window
const int _baselineDays = 30; // the personal yardstick

enum WellnessStatus { calibrating, noData, produced }

class MentalWellnessResult {
  final WellnessStatus status;
  final String message; // user-facing reason / context
  final double? score; // 0..100, higher = better balance
  final String? label; // Balanced / Shifted / Elevated stress
  final String? trend; // improving / stable / declining (vs previous score)
  final bool provisional; // baseline still maturing
  final Map<String, double> components; // sub-scores + coverage (debug/UI)

  const MentalWellnessResult({
    required this.status,
    this.message = '',
    this.score,
    this.label,
    this.trend,
    this.provisional = false,
    this.components = const {},
  });

  bool get produced => status == WellnessStatus.produced;
}

/// Compute the daily Mental Wellness trend score.
///
/// [history] is the trailing daily rows in ASCENDING date order, today last
/// (the service supplies the last ~30 days). [previousScore] is yesterday's
/// displayed wellness score, if any, used only to describe the trend.
MentalWellnessResult computeMentalWellness({
  required List<WellnessDay> history,
  double? previousScore,
}) {
  if (history.isEmpty) {
    return const MentalWellnessResult(
      status: WellnessStatus.noData,
      message: 'No data yet.',
    );
  }

  // Coverage gate: how many baseline days carry a core autonomic signal.
  final baseline = history.length > _baselineDays
      ? history.sublist(history.length - _baselineDays)
      : history;
  final coreDays = baseline.where((d) => d.hasCore).length;

  if (coreDays < _minDaysForScore) {
    final need = _minDaysForScore - coreDays;
    return MentalWellnessResult(
      status: WellnessStatus.calibrating,
      message:
          'Calibrating — $need more day${need == 1 ? '' : 's'} of wear needed '
          'before your wellness balance unlocks.',
    );
  }

  // 7-day window (most recent) vs the up-to-30-day baseline.
  final window = history.length > _windowDays
      ? history.sublist(history.length - _windowDays)
      : history;

  // ── Sub-scores. Each is null when its inputs are absent (→ redistributed). ──

  // 1. HRV trend — chronic suppression vs baseline. (guide: (ratio-0.7)/0.6)
  final avgRmssd = _avg(window.map((d) => d.rmssd));
  final baseRmssd = _avg(baseline.map((d) => d.rmssd));
  double? hrvScore;
  if (avgRmssd != null && baseRmssd != null && baseRmssd > 0) {
    final ratio = avgRmssd / baseRmssd;
    hrvScore = _clip((ratio - 0.7) / 0.6 * 100);
  }

  // 2. Resting HR trend — elevation over baseline = physiological stress.
  final avgRhr = _avg(window.map((d) => d.rhr));
  final baseRhr = _avg(baseline.map((d) => d.rhr));
  double? rhrScore;
  if (avgRhr != null && baseRhr != null) {
    final deviation = baseRhr - avgRhr; // positive = lower than baseline = good
    rhrScore = _clip(50 + deviation * 10);
  }

  // 3. Sleep quality — deep %, efficiency, bedtime consistency (guide weights
  //    0.3/0.4/0.3, renormalised over whichever are present).
  final avgDeepPct = _avg(window.map((d) => d.deepFraction)); // 0..1
  final avgEffPct = _avg(window.map((d) => d.efficiencyFraction)); // 0..1
  final bedtimeVar = _std(window.map((d) => d.bedtimeMinutes)); // minutes
  final sleepParts = <double, double>{}; // weight → sub-score
  if (avgDeepPct != null) {
    sleepParts[0.3] = _clip(avgDeepPct * 100 / 25 * 100); // 25% deep = 100
  }
  if (avgEffPct != null) {
    sleepParts[0.4] = _clip((avgEffPct * 100 - 70) / 25 * 100); // 95% = 100
  }
  double? consistencyScore;
  if (bedtimeVar != null) {
    consistencyScore = _clip((60 - bedtimeVar) / 60 * 100); // <60 min var = good
    sleepParts[0.3] = consistencyScore;
  }
  double? sleepScore;
  if (sleepParts.isNotEmpty) {
    final wSum = sleepParts.keys.fold<double>(0, (a, b) => a + b);
    sleepScore =
        sleepParts.entries.fold<double>(0, (a, e) => a + e.key * e.value) /
            wSum;
  }

  // 4. Activity — steps vs baseline + variability bonus (engagement).
  final avgSteps = _avg(window.map((d) => d.steps));
  final baseSteps = _avg(baseline.map((d) => d.steps));
  double? activityScore;
  if (avgSteps != null && baseSteps != null && baseSteps > 0) {
    final ratio = avgSteps / baseSteps;
    var a = _clip(ratio * 80); // at baseline = 80, above = bonus headroom
    final mean = avgSteps;
    final sd = _std(window.map((d) => d.steps)) ?? 0;
    final variability = sd / (mean + 1);
    a = _clip(a + _clip(variability * 50, 0, 20));
    activityScore = a;
  }

  // 5. Circadian regularity — reuse bedtime consistency.
  final circadianScore = consistencyScore;

  // ── Weighted composite with weight redistribution over available parts. ──
  final parts = <double, double>{}; // nominal weight → sub-score
  if (hrvScore != null) parts[_wHrv] = hrvScore;
  if (rhrScore != null) parts[_wRhr] = rhrScore;
  if (sleepScore != null) parts[_wSleep] = sleepScore;
  if (activityScore != null) parts[_wActivity] = activityScore;
  if (circadianScore != null) parts[_wCircadian] = circadianScore;

  if (parts.isEmpty) {
    return const MentalWellnessResult(
      status: WellnessStatus.noData,
      message: 'Not enough signal this week to read your balance.',
    );
  }

  final weightSum = parts.keys.fold<double>(0, (a, b) => a + b);
  final composite =
      parts.entries.fold<double>(0, (a, e) => a + e.key * e.value) / weightSum;
  final score = _clip(composite);

  // Label from the absolute score (guide's wellness_insight bands).
  String label;
  if (score >= 70) {
    label = 'Balanced';
  } else if (score >= 45) {
    label = 'Shifted';
  } else {
    label = 'Elevated stress';
  }

  // Trend from the previous displayed score, if any.
  String trend = 'stable';
  if (previousScore != null) {
    final delta = score - previousScore;
    if (delta >= 5) {
      trend = 'improving';
    } else if (delta <= -5) {
      trend = 'declining';
    }
  }

  final provisional = coreDays < _minDaysForStable;

  return MentalWellnessResult(
    status: WellnessStatus.produced,
    message: 'ok',
    score: double.parse(score.toStringAsFixed(1)),
    label: label,
    trend: trend,
    provisional: provisional,
    components: {
      if (hrvScore != null) 'hrv': _round1(hrvScore),
      if (rhrScore != null) 'rhr': _round1(rhrScore),
      if (sleepScore != null) 'sleep': _round1(sleepScore),
      if (activityScore != null) 'activity': _round1(activityScore),
      if (circadianScore != null) 'circadian': _round1(circadianScore),
      'coverageDays': coreDays.toDouble(),
    },
  );
}

// ===========================================================================
// MATH HELPERS (no external deps). All ignore nulls / non-finite values.
// ===========================================================================
double? _avg(Iterable<double?> xs) {
  final v = xs.where((e) => e != null && e.isFinite).cast<double>().toList();
  if (v.isEmpty) return null;
  return v.reduce((a, b) => a + b) / v.length;
}

double? _std(Iterable<double?> xs) {
  final v = xs.where((e) => e != null && e.isFinite).cast<double>().toList();
  if (v.length < 2) return null;
  final m = v.reduce((a, b) => a + b) / v.length;
  final variance =
      v.map((e) => (e - m) * (e - m)).reduce((a, b) => a + b) / v.length;
  return math.sqrt(variance);
}

double _clip(double x, [double lo = 0, double hi = 100]) =>
    x.isNaN ? lo : x.clamp(lo, hi).toDouble();

double _round1(double x) => double.parse(x.toStringAsFixed(1));
