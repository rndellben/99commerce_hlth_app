import 'dart:math';
import 'dart:typed_data';

/// Shared signal processing pipeline — foundation for all health features.
/// Ported from hlth-engineering-primer.md Section 2.
class SignalProcessor {
  final int samplingRate;

  SignalProcessor({this.samplingRate = 75});

  /// Zero-phase bandpass via biquad bandpass + filtfilt.
  ///
  /// Coefficients are the standard audio-EQ cookbook (RBJ) bandpass biquad
  /// — a 2nd-order BPF with geometric-center f0 = sqrt(low*high) and
  /// Q = f0/(high-low). Applied forward then backward to get zero phase
  /// (matches scipy's `sosfiltfilt` for our purposes, though scipy uses
  /// a true 4th-order Butterworth — adequate for HR/respiratory bands).
  ///
  ///   cardiac:     lowcut=0.5, highcut=5.0  (heartbeat fundamental)
  ///   respiratory: lowcut=0.1, highcut=0.5  (breathing modulation)
  Float64List bandpassFilter(
    Float64List signal,
    double lowcut,
    double highcut,
  ) {
    // Geometric center + bandwidth → Q.
    final f0 = sqrt(lowcut * highcut);
    final bw = highcut - lowcut;
    final q = f0 / bw;

    final omega = 2.0 * pi * f0 / samplingRate;
    final alpha = sin(omega) / (2.0 * q);
    final cosOmega = cos(omega);

    // RBJ BPF (constant 0 dB peak gain).
    final b0 = alpha;
    const b1 = 0.0;
    final b2 = -alpha;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    final coeffs = _BiquadCoeffs(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);

    final forward = _applyBiquad(signal, coeffs);
    final reversed = _reverse(forward);
    final backward = _applyBiquad(reversed, coeffs);
    return _reverse(backward);
  }

  Float64List _applyBiquad(Float64List signal, _BiquadCoeffs c) {
    final out = Float64List(signal.length);
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < signal.length; i++) {
      final x = signal[i];
      final y = c.b0 * x + c.b1 * x1 + c.b2 * x2 - c.a1 * y1 - c.a2 * y2;
      out[i] = y;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
    }
    return out;
  }

  Float64List _reverse(Float64List s) {
    final out = Float64List(s.length);
    for (int i = 0; i < s.length; i++) {
      out[i] = s[s.length - 1 - i];
    }
    return out;
  }

  /// Signal quality assessment (0-100).
  /// Reject segments below 50.
  double assessQuality(Float64List ppgSegment) {
    if (ppgSegment.length < samplingRate * 2) return 0;

    // 1. Spectral SNR: cardiac band power vs total power
    final cardiacFiltered =
        bandpassFilter(ppgSegment, 0.7, 3.5);
    final cardiacPower = _signalPower(cardiacFiltered);
    final totalPower = _signalPower(ppgSegment);
    final snrScore =
        totalPower > 0 ? (cardiacPower / totalPower) * 100 : 0.0;

    // 2. Peak regularity
    final peaks = detectPeaks(cardiacFiltered);
    if (peaks.length < 3) return 0;

    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / samplingRate);
    }
    final meanInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final stdInterval = _std(intervals);
    final cv = stdInterval / meanInterval;
    final regularityScore = max(0.0, (1.0 - cv / 0.3)) * 100;

    return min(100.0, max(0.0, snrScore * 0.5 + regularityScore * 0.5));
  }

  /// Detect heartbeat peaks in filtered PPG signal.
  ///
  /// Follows hlth-engineering-primer.md Section 2 Stage 4 exactly.
  /// For noisy real-world PPG (motion, loose fit), the primer recommends
  /// the `heartpy` library — not parameter tweaks. We port the canonical
  /// formula here and treat accuracy on noisy data as a Phase 4+ concern.
  List<int> detectPeaks(Float64List ppgFiltered) {
    final minDistance = (0.33 * samplingRate).toInt(); // max 180 bpm
    final median = _median(ppgFiltered);
    final std = _std(ppgFiltered.toList());
    final threshold = median + 0.3 * std;
    final prominence = 0.1 * std;

    final peaks = <int>[];

    for (int i = 1; i < ppgFiltered.length - 1; i++) {
      if (ppgFiltered[i] > ppgFiltered[i - 1] &&
          ppgFiltered[i] > ppgFiltered[i + 1] &&
          ppgFiltered[i] > threshold) {
        // Check prominence
        final leftMin = _localMin(ppgFiltered, max(0, i - minDistance), i);
        final rightMin = _localMin(
            ppgFiltered, i, min(ppgFiltered.length - 1, i + minDistance));
        final peakProminence =
            ppgFiltered[i] - max(leftMin, rightMin);

        if (peakProminence > prominence) {
          // Check distance from last peak
          if (peaks.isEmpty || (i - peaks.last) >= minDistance) {
            peaks.add(i);
          } else if (ppgFiltered[i] > ppgFiltered[peaks.last]) {
            peaks[peaks.length - 1] = i; // Replace with higher peak
          }
        }
      }
    }

    return peaks;
  }

  /// Extract R-R intervals in milliseconds from peak indices.
  List<double> extractRRIntervals(List<int> peaks) {
    final rrIntervals = <double>[];

    for (int i = 1; i < peaks.length; i++) {
      final rrMs = (peaks[i] - peaks[i - 1]) / samplingRate * 1000;
      // Physiological validation: 300ms (200bpm) to 2000ms (30bpm)
      if (rrMs >= 300 && rrMs <= 2000) {
        rrIntervals.add(rrMs);
      }
    }

    return rrIntervals;
  }

  /// Heart rate in BPM from R-R intervals.
  double? calculateHeartRate(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) return null;
    final meanRr =
        rrIntervalsMs.reduce((a, b) => a + b) / rrIntervalsMs.length;
    final hr = 60000 / meanRr;

    // Sanity check: 30-220 bpm
    if (hr < 30 || hr > 220) return null;
    return double.parse(hr.toStringAsFixed(1));
  }

  /// Calculate SpO2 from red and infrared AC/DC components.
  double? calculateSpO2({
    required double redAc,
    required double redDc,
    required double irAc,
    required double irDc,
  }) {
    if (redDc == 0 || irDc == 0) return null;
    final r = (redAc / redDc) / (irAc / irDc);
    final spo2 = 110 - 25 * r;

    // Sanity check: 70-100%
    if (spo2 < 70 || spo2 > 100) return null;
    return double.parse(spo2.toStringAsFixed(1));
  }

  // --- Helper functions ---

  double _signalPower(Float64List signal) {
    double sum = 0;
    for (final s in signal) {
      sum += s * s;
    }
    return sum / signal.length;
  }

  double _median(Float64List data) {
    final sorted = Float64List.fromList(data)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _std(List<double> data) {
    final mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiffs = 0;
    for (final d in data) {
      sumSquaredDiffs += (d - mean) * (d - mean);
    }
    return sqrt(sumSquaredDiffs / data.length);
  }

  double _localMin(Float64List data, int start, int end) {
    double minVal = double.infinity;
    for (int i = start; i <= end && i < data.length; i++) {
      if (data[i] < minVal) minVal = data[i];
    }
    return minVal;
  }
}

class _BiquadCoeffs {
  final double b0, b1, b2, a1, a2;
  const _BiquadCoeffs(this.b0, this.b1, this.b2, this.a1, this.a2);
}
