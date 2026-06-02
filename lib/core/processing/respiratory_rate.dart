import 'dart:typed_data';
import 'package:hlth_app/core/processing/signal_processor.dart';

/// Respiratory rate extraction from PPG signal.
/// Uses bandpass filtering at 0.1-0.5 Hz (6-30 breaths/min).
class RespiratoryRateCalculator {
  final SignalProcessor _processor;

  RespiratoryRateCalculator({int samplingRate = 75})
      : _processor = SignalProcessor(samplingRate: samplingRate);

  /// Calculate respiratory rate in breaths per minute.
  /// Requires at least 30 seconds of PPG data.
  double? calculate(Float64List rawPpg) {
    if (rawPpg.length < _processor.samplingRate * 30) return null;

    // Bandpass filter for respiratory band: 0.1-0.5 Hz
    final respiratory = _processor.bandpassFilter(rawPpg, 0.1, 0.5);

    // Find respiratory peaks
    final peaks = _processor.detectPeaks(respiratory);

    if (peaks.length < 2) return null;

    // Calculate breaths per minute from peak intervals
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add(
          (peaks[i] - peaks[i - 1]) / _processor.samplingRate);
    }

    final meanInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final breathsPerMin = 60.0 / meanInterval;

    // Sanity check: 4-40 breaths/min
    if (breathsPerMin < 4 || breathsPerMin > 40) return null;
    return double.parse(breathsPerMin.toStringAsFixed(1));
  }
}
