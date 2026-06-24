import 'dart:math';
import 'package:hlth_app/core/models/hrv_metrics.dart';
import 'package:hlth_app/core/processing/ectopic_adaptive.dart';

/// Ectopic-beat cleaning strategy for [HrvCalculator].
enum EctopicCleaningPolicy {
  /// No cleaning beyond the upstream 300-2000ms range filter applied by
  /// [SignalProcessor.extractRRIntervals]. Use when intervals come from a
  /// source that has already removed ectopics (e.g. the band's own HRV
  /// engine), or for debugging.
  none,

  /// Malik's method: drop each interval whose ratio to its immediate
  /// predecessor (in the original input) lies outside [0.8, 1.2] — i.e.
  /// it deviates more than 20% from the previous beat. Matches the
  /// `hrv-analysis` Python library's Malik implementation and the
  /// reference algorithm in `health-features-build-guide.md`.
  malik,

  /// HeartPy-style moving-median outlier removal: drop each interval
  /// outside ±30% of the local rolling median (window of 9 beats, the
  /// HeartPy default). Robust against isolated ectopics AND short runs of
  /// noise — Malik's per-beat comparison can be fooled by clusters
  /// (each "bad" beat looks fine relative to the previous "bad" beat),
  /// the rolling median holds steady through them.
  ///
  /// Reference: HeartPy by van Gent et al. — github.com/paulvangentcom/
  /// heartrate_analysis_python. Cited by `awesome-ppg` as the standard
  /// HRV pipeline for noisy wrist PPG.
  movingMedian,

  /// Lipponen–Tarvainen / Kubios-style adaptive cleaning (see
  /// [cleanAdaptive]). Scales the accept band with local variability,
  /// CORRECTS flagged beats by interpolation instead of dropping them, and
  /// separates packet-loss gaps from real ectopy. This is the policy PPG
  /// captures use; routing it through [cleanEctopics] returns the corrected,
  /// full-length series (use [cleanAdaptive] directly when you need the
  /// per-beat labels and the separated ectopic/gap fractions).
  adaptive,
}

/// HRV metric extraction from R-R intervals (ms).
///
/// Inputs are expected to already pass an upstream physiological range
/// filter (300-2000ms). This class adds the second preprocessing pass —
/// ectopic removal — before computing RMSSD / SDNN / pNN50.
class HrvCalculator {
  /// Compute time-domain HRV metrics. Applies [policy] to clean ectopic
  /// beats first, then requires at least 10 surviving beats. Returns
  /// `null` if too few clean beats remain or the metrics fail their
  /// internal validity check.
  HrvMetrics? calculate(
    List<double> rrIntervalsMs, {
    EctopicCleaningPolicy policy = EctopicCleaningPolicy.malik,
  }) {
    final nn = cleanEctopics(rrIntervalsMs, policy: policy);
    if (nn.length < 10) return null;

    final successiveDiffs = <double>[];
    for (int i = 1; i < nn.length; i++) {
      successiveDiffs.add(nn[i] - nn[i - 1]);
    }

    final meanRr = _mean(nn);
    final sdnn = _stdDev(nn, ddof: 1);

    double sumSquaredDiffs = 0;
    for (final d in successiveDiffs) {
      sumSquaredDiffs += d * d;
    }
    final rmssd = sqrt(sumSquaredDiffs / successiveDiffs.length);

    int countOver50 = 0;
    for (final d in successiveDiffs) {
      if (d.abs() > 50) countOver50++;
    }
    final pnn50 = (countOver50 / successiveDiffs.length) * 100;

    final meanHr = 60000 / meanRr;

    final metrics = HrvMetrics(
      meanRr: meanRr,
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
      meanHr: meanHr,
    );

    return metrics.isValid ? metrics : null;
  }

  /// Apply the chosen [policy] without computing metrics. Public so
  /// callers can inspect how many beats the cleaning removed (e.g. the
  /// Analyze debug screen) before deciding whether the resulting series
  /// is long enough to trust.
  List<double> cleanEctopics(
    List<double> rrIntervals, {
    EctopicCleaningPolicy policy = EctopicCleaningPolicy.malik,
  }) {
    switch (policy) {
      case EctopicCleaningPolicy.none:
        return rrIntervals;
      case EctopicCleaningPolicy.malik:
        return _malik2Beat(rrIntervals);
      case EctopicCleaningPolicy.movingMedian:
        return _movingMedian(rrIntervals);
      case EctopicCleaningPolicy.adaptive:
        return cleanAdaptive(rrIntervals).rrCorrected;
    }
  }

  /// Time-domain HRV from an adaptively-cleaned series + its per-beat labels.
  ///
  /// The cleaning step interpolates flagged beats to keep the time axis intact
  /// for SDNN, but interpolated/flagged beats must NOT count as real successive
  /// differences (that is exactly what inflates RMSSD). So a successive-
  /// difference pair (RMSSD/pNN50) is counted only when BOTH beats are
  /// `normal`; SDNN and the mean use the normal beats' spread. Needs ≥10
  /// normal beats and at least one normal-normal pair, else returns `null`.
  HrvMetrics? calculateFromLabeled(List<double> rr, List<BeatLabel> labels) {
    if (rr.length != labels.length) return null;
    final normals = <double>[];
    for (int i = 0; i < rr.length; i++) {
      if (labels[i] == BeatLabel.normal) normals.add(rr[i]);
    }
    if (normals.length < 10) return null;

    final diffs = <double>[];
    for (int i = 1; i < rr.length; i++) {
      if (labels[i] == BeatLabel.normal && labels[i - 1] == BeatLabel.normal) {
        diffs.add(rr[i] - rr[i - 1]);
      }
    }
    if (diffs.isEmpty) return null;

    final meanRr = _mean(normals);
    final sdnn = _stdDev(normals, ddof: 1);

    double sumSquaredDiffs = 0;
    for (final d in diffs) {
      sumSquaredDiffs += d * d;
    }
    final rmssd = sqrt(sumSquaredDiffs / diffs.length);

    int countOver50 = 0;
    for (final d in diffs) {
      if (d.abs() > 50) countOver50++;
    }
    final pnn50 = (countOver50 / diffs.length) * 100;

    final metrics = HrvMetrics(
      meanRr: meanRr,
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
      meanHr: 60000 / meanRr,
    );
    return metrics.isValid ? metrics : null;
  }

  /// Malik's two-beat rule: keep the first beat; drop any subsequent
  /// beat whose ratio to its predecessor in the original input is
  /// outside [0.8, 1.2]. Compares to the input predecessor (not the
  /// last-kept beat), matching `hrv-analysis` semantics — this can
  /// cascade-drop the neighbour after an ectopic, which is the
  /// conservative behaviour that protects RMSSD.
  List<double> _malik2Beat(List<double> rr) {
    if (rr.length < 3) return rr;
    final kept = <double>[rr[0]];
    for (int i = 1; i < rr.length; i++) {
      if (rr[i - 1] <= 0) continue;
      final ratio = rr[i] / rr[i - 1];
      if (ratio > 0.8 && ratio < 1.2) {
        kept.add(rr[i]);
      }
    }
    return kept;
  }

  /// HeartPy-style moving-median outlier removal. For each interval,
  /// compute the median of the surrounding `_movingMedianWindow` beats
  /// (centered, edges clamped) and drop the interval if it deviates more
  /// than `_movingMedianTolerance` from that local median.
  ///
  /// Outperforms Malik on noisy wrist PPG because it compares each beat
  /// against a local context window rather than just its immediate
  /// predecessor — a single ectopic doesn't poison the comparison for
  /// the next 1-2 beats.
  static const int _movingMedianWindow = 9; // HeartPy default
  static const double _movingMedianTolerance = 0.30; // ±30%

  List<double> _movingMedian(List<double> rr) {
    if (rr.length < _movingMedianWindow) return rr;
    final half = _movingMedianWindow ~/ 2;
    final kept = <double>[];
    for (int i = 0; i < rr.length; i++) {
      final lo = (i - half).clamp(0, rr.length - 1);
      final hi = (i + half + 1).clamp(0, rr.length);
      final window = rr.sublist(lo, hi).toList()..sort();
      final median = window.length.isOdd
          ? window[window.length ~/ 2]
          : (window[window.length ~/ 2 - 1] + window[window.length ~/ 2]) / 2;
      if (median <= 0) continue;
      final deviation = (rr[i] - median).abs() / median;
      if (deviation <= _movingMedianTolerance) {
        kept.add(rr[i]);
      }
    }
    return kept;
  }

  double _mean(List<double> data) {
    return data.reduce((a, b) => a + b) / data.length;
  }

  double _stdDev(List<double> data, {int ddof = 0}) {
    final mean = _mean(data);
    double sumSquaredDiffs = 0;
    for (final d in data) {
      sumSquaredDiffs += (d - mean) * (d - mean);
    }
    return sqrt(sumSquaredDiffs / (data.length - ddof));
  }
}
