// Adaptive (Lipponen–Tarvainen / Kubios-style) R-R artifact correction.
//
// Replaces the fixed ±30% moving-median drop-and-discard cleaner for PPG
// captures. Three differences that matter on the H59's lossy stream:
//
//   • Scales the accept band with LOCAL variability (quartile deviation of the
//     successive differences) instead of a fixed ±30% — so it adapts to the
//     subject's own HR and HRV rather than a one-size threshold.
//   • CORRECTS flagged beats by interpolation instead of deleting them, which
//     preserves the time axis. Deleting beats creates false adjacencies that
//     corrupt RMSSD; interpolation keeps the series honest.
//   • LABELS each beat and separates packet-loss GAPS from real ectopy, so the
//     irregular-rhythm alert reads [ectopicFraction] (gap-free) while the
//     quality gate can read [gapFraction] (BLE loss) independently.
//
// Pure Dart, no dependencies. When [validMask] is omitted, gap intervals are
// inferred from interval length (≥1.8× the local median) — the same trick the
// old CoV filter used, now applied consistently.

import 'dart:math' as math;

/// Per-beat classification produced by [cleanAdaptive].
enum BeatLabel {
  normal, // clean sinus beat
  ectopic, // premature/abnormal beat (short-then-compensatory-long)
  missed, // a beat the detector skipped (interval ≈ 2× normal)
  extra, // a false/split peak (interval ≈ 0.5× normal)
  gap, // interval spans dropped BLE packets — missing data, NOT ectopy
}

/// Result of adaptive cleaning. [rrCorrected] is the same length as the input
/// with flagged beats interpolated; [labels] carries the per-beat verdict.
class EctopicResult {
  final List<double> rrCorrected;
  final List<BeatLabel> labels;

  /// (ectopic + missed + extra) / n — feeds the irregular-rhythm alert.
  /// Excludes gaps, so BLE loss can't masquerade as arrhythmia.
  final double ectopicFraction;

  /// gap / n — feeds the quality gate only. This is BLE-loss-driven.
  final double gapFraction;

  final int nNormal;

  const EctopicResult({
    required this.rrCorrected,
    required this.labels,
    required this.ectopicFraction,
    required this.gapFraction,
    required this.nNormal,
  });
}

// Adaptive-threshold config, tuned to the real ~94 bpm capture (flags the
// ectopic couplet, the missed beat and the split beat). Re-check on a resting
// <60 bpm capture; raise [alpha] toward 6 if it over-flags RSA swings.
const double _adaptiveAlpha = 5.2; // threshold multiplier on local QD(dRR)
const int _adaptiveWindow = 45; // beats in the local quartile-deviation window
const double _physMinMs = 300; // hard physiologic floor (200 bpm)
const double _physMaxMs = 2000; // hard physiologic ceiling (30 bpm)
const double _gapRatio = 1.8; // interval ≥ this × local median ⇒ inferred gap

/// Adaptive ectopic correction.
///
///   [rr]        R-R intervals (ms), time-ordered.
///   [validMask] optional; same length as [rr]. false ⇒ this interval spans a
///               dropped-packet region. When omitted, gaps are inferred from
///               interval length (≥[_gapRatio]× the local median). Gap-labelled
///               intervals are interpolated and EXCLUDED from [ectopicFraction]
///               so BLE loss can't fire the irregular-rhythm alert.
EctopicResult cleanAdaptive(
  List<double> rr, {
  List<bool>? validMask,
  double alpha = _adaptiveAlpha,
  int window = _adaptiveWindow,
}) {
  final n = rr.length;
  if (n == 0) {
    return const EctopicResult(
      rrCorrected: [],
      labels: [],
      ectopicFraction: 0,
      gapFraction: 0,
      nNormal: 0,
    );
  }
  final labels = List<BeatLabel>.filled(n, BeatLabel.normal);

  // 1) Successive differences (the quantity ectopics spike).
  final dRR = List<double>.generate(n, (i) => i == 0 ? 0.0 : rr[i] - rr[i - 1]);

  // 2) Local adaptive threshold = alpha × quartile-deviation(dRR) in a window.
  //    Quartile deviation (IQR/2) is robust to the very outliers we're hunting
  //    and auto-scales with the subject's HR and variability.
  final half = window ~/ 2;
  final th = List<double>.generate(n, (i) {
    final lo = (i - half).clamp(0, n);
    final hi = (i + half).clamp(0, n);
    return alpha * _quartileDeviation(dRR.sublist(lo, hi));
  });

  // 3) Classify.
  for (int i = 0; i < n; i++) {
    // Packet-gap intervals first — missing data, not ectopy.
    final isGap = (validMask != null && i < validMask.length && !validMask[i]) ||
        (validMask == null && _looksLikeGap(rr, i));
    if (isGap) {
      labels[i] = BeatLabel.gap;
      continue;
    }
    // Hard physiologic bounds always flag.
    if (rr[i] < _physMinMs || rr[i] > _physMaxMs) {
      labels[i] = _classifyByRatio(rr, i);
      continue;
    }
    // Adaptive successive-difference test. Skip it when the previous beat is a
    // gap: the difference across a stitched-over dropout is meaningless and
    // would otherwise mislabel the (perfectly normal) post-gap beat as ectopic
    // — i.e. let BLE loss masquerade as arrhythmia, the exact thing the gap
    // separation exists to prevent.
    if (i > 0 && labels[i - 1] != BeatLabel.gap && dRR[i].abs() > th[i]) {
      labels[i] = _classifyByRatio(rr, i);
    }
  }

  // 4) CORRECT by interpolation (never delete). Preserves length + time axis.
  final corrected = _interpolateFlagged(rr, labels);

  // 5) Honest, separated fractions.
  int nEctopic = 0, nGap = 0, nNormal = 0;
  for (final l in labels) {
    switch (l) {
      case BeatLabel.ectopic:
      case BeatLabel.missed:
      case BeatLabel.extra:
        nEctopic++;
        break;
      case BeatLabel.gap:
        nGap++;
        break;
      case BeatLabel.normal:
        nNormal++;
        break;
    }
  }

  return EctopicResult(
    rrCorrected: corrected,
    labels: labels,
    ectopicFraction: nEctopic / n,
    gapFraction: nGap / n,
    nNormal: nNormal,
  );
}

/// Length-based gap inference used when no [validMask] is supplied: an interval
/// far longer than the local median is most likely a stitched-over dropout.
bool _looksLikeGap(List<double> rr, int i) {
  final med = _localMedian(rr, i, 9);
  if (med <= 0) return false;
  return rr[i] >= _gapRatio * med;
}

/// Classify a flagged beat by its ratio to the local clean median.
/// missed ≈ 2× (detector skipped a beat); extra ≈ 0.5× (false/split peak);
/// ectopic otherwise (premature/compensatory).
BeatLabel _classifyByRatio(List<double> rr, int i) {
  final med = _localMedian(rr, i, 9);
  if (med <= 0) return BeatLabel.ectopic;
  final ratio = rr[i] / med;
  if (ratio > 1.6) return BeatLabel.missed;
  if (ratio < 0.6) return BeatLabel.extra;
  return BeatLabel.ectopic;
}

/// Replace every non-normal beat with a linear interpolation between the
/// nearest clean beats on each side. Linear is within noise of cubic for the
/// short 1-2 beat gaps typical on this device.
List<double> _interpolateFlagged(List<double> rr, List<BeatLabel> labels) {
  final n = rr.length;
  final out = List<double>.from(rr);
  final cleanIdx = <int>[];
  for (int i = 0; i < n; i++) {
    if (labels[i] == BeatLabel.normal) cleanIdx.add(i);
  }
  if (cleanIdx.isEmpty) return out; // nothing clean to interpolate from

  for (int i = 0; i < n; i++) {
    if (labels[i] == BeatLabel.normal) continue;
    int? lo, hi;
    for (final c in cleanIdx) {
      if (c < i) {
        lo = c;
      } else if (c > i) {
        hi = c;
        break;
      }
    }
    if (lo != null && hi != null) {
      final t = (i - lo) / (hi - lo);
      out[i] = rr[lo] + (rr[hi] - rr[lo]) * t;
    } else if (lo != null) {
      out[i] = rr[lo];
    } else if (hi != null) {
      out[i] = rr[hi];
    }
  }
  return out;
}

// ── Small numeric helpers ───────────────────────────────────────────────────

double _quartileDeviation(List<double> a) {
  if (a.length < 4) {
    if (a.length < 2) return 0.0;
    return _std(a); // tiny-window fallback
  }
  final s = List<double>.from(a)..sort();
  final q1 = _percentile(s, 25);
  final q3 = _percentile(s, 75);
  return (q3 - q1) / 2.0;
}

double _percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0.0;
  final rank = (p / 100.0) * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return sorted[lo];
  final frac = rank - lo;
  return sorted[lo] + (sorted[hi] - sorted[lo]) * frac;
}

double _localMedian(List<double> rr, int i, int win) {
  final half = win ~/ 2;
  final lo = (i - half).clamp(0, rr.length);
  final hi = (i + half + 1).clamp(0, rr.length);
  final w = rr.sublist(lo, hi)..sort();
  if (w.isEmpty) return 0.0;
  return w.length.isOdd
      ? w[w.length ~/ 2]
      : (w[w.length ~/ 2 - 1] + w[w.length ~/ 2]) / 2.0;
}

double _std(List<double> a) {
  if (a.length < 2) return 0.0;
  final m = a.reduce((x, y) => x + y) / a.length;
  final v =
      a.map((x) => (x - m) * (x - m)).reduce((x, y) => x + y) / (a.length - 1);
  return math.sqrt(v);
}
