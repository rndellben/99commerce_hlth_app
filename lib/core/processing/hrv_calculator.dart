import 'dart:math';
import 'package:hlth_app/core/models/hrv_metrics.dart';

/// HRV metric extraction from R-R intervals.
/// Ported from hlth-engineering-primer.md Section 2, Stage 7.
class HrvCalculator {
  /// Calculate all core HRV metrics from R-R intervals (in ms).
  /// Requires at least 10 beats for meaningful results.
  HrvMetrics? calculate(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 10) return null;

    final nn = rrIntervalsMs;

    // Successive differences
    final successiveDiffs = <double>[];
    for (int i = 1; i < nn.length; i++) {
      successiveDiffs.add(nn[i] - nn[i - 1]);
    }

    // Time domain metrics
    final meanRr = _mean(nn);
    final sdnn = _stdDev(nn, ddof: 1);

    // RMSSD: root mean square of successive differences
    double sumSquaredDiffs = 0;
    for (final d in successiveDiffs) {
      sumSquaredDiffs += d * d;
    }
    final rmssd = sqrt(sumSquaredDiffs / successiveDiffs.length);

    // pNN50: percentage of successive diffs > 50ms
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

  /// Remove ectopic beats using Malik method.
  /// Ectopic = interval differs from previous by > 20%.
  List<double> removeEctopicBeats(List<double> rrIntervals) {
    if (rrIntervals.length < 3) return rrIntervals;

    final cleaned = <double>[rrIntervals[0]];

    for (int i = 1; i < rrIntervals.length; i++) {
      final ratio = rrIntervals[i] / rrIntervals[i - 1];
      // Keep if within 20% of previous interval
      if (ratio > 0.8 && ratio < 1.2) {
        cleaned.add(rrIntervals[i]);
      }
    }

    return cleaned;
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
