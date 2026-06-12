import 'dart:math';

/// Outcome of a fall-detection sweep.
enum FallSeverity {
  /// Freefall + impact, but the wearer kept moving after — likely caught
  /// themselves, brushed it off, or this was a hard sit. Worth a check-in
  /// prompt, not an emergency escalation.
  moderate,

  /// Freefall + impact + stillness for the full post-impact window. The
  /// wearer hasn't moved for 10 s. Treat as a possible emergency.
  severe,
}

/// Outcome of a single background fall-sweep window. Emitted by
/// `PeriodicSyncCoordinator` after each scheduled accel-capture so
/// listeners (debug screen, alert pipeline) can react.
class FallSweepResult {
  const FallSweepResult({
    required this.sweptAt,
    required this.captureDurationS,
    required this.sampleCount,
    required this.events,
    this.calibratedOneGRaw,
    this.skipReason,
  });

  final DateTime sweptAt;
  final int captureDurationS;
  final int sampleCount;
  final List<FallEvent> events;
  final double? calibratedOneGRaw;

  /// Non-null when the sweep didn't actually run (e.g. no accel
  /// arrived, capture failed). Both `events` and `sampleCount` will be
  /// empty in that case.
  final String? skipReason;

  bool get ok => skipReason == null;
}

/// One detected fall event, indexed against the input sample stream.
class FallEvent {
  const FallEvent({
    required this.severity,
    required this.impactSampleIndex,
    required this.peakImpactG,
    required this.postImpactVariabilityG,
  });

  final FallSeverity severity;

  /// Index into the input samples list where the impact peaked.
  final int impactSampleIndex;

  /// Peak acceleration magnitude during the impact window, in g.
  final double peakImpactG;

  /// Std-dev of acceleration magnitude across the post-impact window, in
  /// g. Below 0.1g = severe; 0.1-0.3g = moderate; above 0.3g = ignored
  /// (wearer kept moving normally).
  final double postImpactVariabilityG;
}

/// Three-window fall detection on an accelerometer stream.
///
/// Algorithm (per `advanced-health-features-build-guide.md` §1):
///   1. **Freefall** — `accel_mag < 0.5g` sustained for ≥200 ms.
///   2. **Impact** — within 1 s after freefall ends, `accel_mag > 2.5g`.
///   3. **Immobility** — over the next 10 s, std-dev of `accel_mag`
///      classifies severity: `<0.1g` severe, `<0.3g` moderate, else
///      discarded as a false positive.
///
/// Inputs are 3-axis accelerometer samples in **milli-g** (matches the
/// H59 platform-channel payload: `accel_x_mg`/`accel_y_mg`/`accel_z_mg`).
/// Pass `samplingRateHz` matching the source — typically ~24 Hz during
/// H59 `startMeasureHrRaw` capture.
///
/// **V1 scope:** runs on whatever accel stream is available. The H59
/// only emits accel during active PPG capture, so 24/7 fall coverage
/// requires scheduling periodic capture windows (handled at the
/// integration layer, not in this class).
class FallDetector {
  const FallDetector({
    this.freefallThresholdG = 0.5,
    this.freefallDurationMs = 200,
    this.impactThresholdG = 2.5,
    this.impactWindowMs = 1000,
    this.immobilityWindowMs = 10000,
    this.severeImmobilityStdG = 0.1,
    this.moderateImmobilityStdG = 0.3,
  });

  final double freefallThresholdG;
  final int freefallDurationMs;
  final double impactThresholdG;
  final int impactWindowMs;
  final int immobilityWindowMs;
  final double severeImmobilityStdG;
  final double moderateImmobilityStdG;

  /// Scan an accelerometer trace for fall events.
  ///
  /// Input is parallel lists of milli-g samples for each axis. The
  /// caller is responsible for collecting the samples in capture order
  /// at a known rate.
  List<FallEvent> detect({
    required List<int> accelXMilliG,
    required List<int> accelYMilliG,
    required List<int> accelZMilliG,
    required double samplingRateHz,
  }) {
    final n = accelXMilliG.length;
    if (n != accelYMilliG.length || n != accelZMilliG.length) {
      throw ArgumentError('accel axis lengths must match');
    }
    final freefallSamples = (freefallDurationMs / 1000 * samplingRateHz).round();
    final impactWindowSamples = (impactWindowMs / 1000 * samplingRateHz).round();
    final immobilitySamples =
        (immobilityWindowMs / 1000 * samplingRateHz).round();
    if (n < freefallSamples + impactWindowSamples + immobilitySamples) {
      return const [];
    }

    final mag = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final x = accelXMilliG[i] / 1000.0;
      final y = accelYMilliG[i] / 1000.0;
      final z = accelZMilliG[i] / 1000.0;
      mag[i] = sqrt(x * x + y * y + z * z);
    }

    final events = <FallEvent>[];
    int i = 0;
    while (i < n) {
      // Phase 1: scan forward for a sustained freefall.
      if (mag[i] >= freefallThresholdG) {
        i++;
        continue;
      }
      int freefallEnd = i;
      while (freefallEnd < n && mag[freefallEnd] < freefallThresholdG) {
        freefallEnd++;
      }
      if (freefallEnd - i < freefallSamples) {
        i = freefallEnd;
        continue;
      }

      // Phase 2: look for an impact spike within the next impact window.
      final impactSearchEnd = min(freefallEnd + impactWindowSamples, n);
      double peakImpact = 0;
      int peakImpactIdx = -1;
      for (int j = freefallEnd; j < impactSearchEnd; j++) {
        if (mag[j] > peakImpact) {
          peakImpact = mag[j];
          peakImpactIdx = j;
        }
      }
      if (peakImpact <= impactThresholdG || peakImpactIdx < 0) {
        // No impact — wearer floated weightless then settled (e.g. arm
        // drop). Resume scanning after the freefall.
        i = freefallEnd;
        continue;
      }

      // Phase 3: measure post-impact variability over the immobility
      // window. Start one sample *after* the impact peak — the peak
      // itself isn't "post-impact behaviour" and including it inflates
      // std-dev artificially (a single 3g spike in an otherwise still
      // 10 s window pushes std above the 0.1g severe threshold even when
      // the wearer is motionless).
      final immobilityStart = peakImpactIdx + 1;
      final immobilityEnd = min(immobilityStart + immobilitySamples, n);
      if (immobilityEnd - immobilityStart < immobilitySamples) {
        // Trace ended before we could measure stillness; can't classify.
        break;
      }
      final variability = _stdDev(mag, immobilityStart, immobilityEnd);
      FallSeverity? severity;
      if (variability < severeImmobilityStdG) {
        severity = FallSeverity.severe;
      } else if (variability < moderateImmobilityStdG) {
        severity = FallSeverity.moderate;
      }
      if (severity != null) {
        events.add(FallEvent(
          severity: severity,
          impactSampleIndex: peakImpactIdx,
          peakImpactG: peakImpact,
          postImpactVariabilityG: variability,
        ));
        // Skip past the immobility window so a single event doesn't
        // count twice.
        i = immobilityEnd;
      } else {
        // Caught themselves / kept moving — false positive, scan past
        // the impact.
        i = peakImpactIdx + 1;
      }
    }
    return events;
  }

  double _stdDev(List<double> data, int start, int end) {
    final n = end - start;
    if (n <= 1) return 0;
    double sum = 0;
    for (int i = start; i < end; i++) {
      sum += data[i];
    }
    final mean = sum / n;
    double sumSq = 0;
    for (int i = start; i < end; i++) {
      final d = data[i] - mean;
      sumSq += d * d;
    }
    return sqrt(sumSq / n);
  }
}
