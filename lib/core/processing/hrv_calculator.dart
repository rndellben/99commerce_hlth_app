import 'dart:math';
import 'package:hlth_app/core/models/hrv_metrics.dart';

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
    }
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
