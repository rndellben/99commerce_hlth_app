import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/fall_detector.dart';

const _fs = 24.0; // matches H59 PPG capture sample rate

void main() {
  final detector = const FallDetector();

  group('FallDetector', () {
    test('normal resting activity produces no events', () {
      final trace = _restingActivity(seconds: 15);
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events, isEmpty);
    });

    test('freefall + impact + stillness is detected as severe', () {
      final trace = _fallTrace(
        preFallSeconds: 3,
        freefallMs: 300,
        impactPeakG: 3.5,
        postImpactSeconds: 12,
        postImpactMovementMagnitudeG: 0.0,
      );
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events.length, equals(1));
      expect(events.first.severity, FallSeverity.severe);
      expect(events.first.peakImpactG, greaterThanOrEqualTo(3.0));
    });

    test('freefall + impact + minor movement is detected as moderate', () {
      final trace = _fallTrace(
        preFallSeconds: 3,
        freefallMs: 300,
        impactPeakG: 3.5,
        postImpactSeconds: 12,
        // sin wave on the dominant axis (z) with amp 0.2g → mag std ≈
        // 0.14g, which lands between 0.1g (severe) and 0.3g (moderate).
        postImpactMovementMagnitudeG: 0.2,
      );
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events.length, equals(1));
      expect(events.first.severity, FallSeverity.moderate);
    });

    test('freefall + impact + active movement is filtered as false positive',
        () {
      // Wearer caught themselves / kept walking. Post-impact mag std ≈
      // 0.5 / √2 = 0.35g — above the 0.3g moderate threshold so no
      // detection. Keep the amplitude bounded so the oscillation
      // doesn't itself dip below 0.5g (which would look like a new
      // freefall) or spike above 2.5g (which would look like a new
      // impact).
      final trace = _fallTrace(
        preFallSeconds: 3,
        freefallMs: 300,
        impactPeakG: 3.5,
        postImpactSeconds: 12,
        postImpactMovementMagnitudeG: 0.5,
      );
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events, isEmpty);
    });

    test('freefall without impact (arm drop) is ignored', () {
      // Freefall happens, but no >2.5g spike follows — wearer just
      // lowered their arm.
      final trace = _fallTrace(
        preFallSeconds: 3,
        freefallMs: 300,
        impactPeakG: 1.5, // below 2.5g threshold
        postImpactSeconds: 12,
        postImpactMovementMagnitudeG: 0.0,
      );
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events, isEmpty);
    });

    test('impact spike without prior freefall (sat down hard) is ignored',
        () {
      // 15s of resting + one 3g spike in the middle, with no freefall
      // before it.
      final trace = _restingActivity(seconds: 15);
      final spikeIdx = (5 * _fs).toInt();
      trace.x[spikeIdx] = 3000;
      trace.y[spikeIdx] = 0;
      trace.z[spikeIdx] = 0;
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events, isEmpty);
    });

    test('trace shorter than required windows produces no events', () {
      // 2 seconds isn't enough room for freefall + impact + 10s
      // immobility window.
      final trace = _restingActivity(seconds: 2);
      final events = detector.detect(
        accelXMilliG: trace.x,
        accelYMilliG: trace.y,
        accelZMilliG: trace.z,
        samplingRateHz: _fs,
      );
      expect(events, isEmpty);
    });

    test('two separate falls in one trace are both detected', () {
      // First fall, then 5s of stillness gap, then second fall.
      final first = _fallTrace(
        preFallSeconds: 2,
        freefallMs: 300,
        impactPeakG: 3.5,
        postImpactSeconds: 12,
        postImpactMovementMagnitudeG: 0.0,
      );
      final second = _fallTrace(
        preFallSeconds: 2,
        freefallMs: 300,
        impactPeakG: 3.5,
        postImpactSeconds: 12,
        postImpactMovementMagnitudeG: 0.0,
      );
      final combined = _AccelTrace(
        x: [...first.x, ...second.x],
        y: [...first.y, ...second.y],
        z: [...first.z, ...second.z],
      );
      final events = detector.detect(
        accelXMilliG: combined.x,
        accelYMilliG: combined.y,
        accelZMilliG: combined.z,
        samplingRateHz: _fs,
      );
      expect(events.length, equals(2));
      expect(events.every((e) => e.severity == FallSeverity.severe), isTrue);
    });

    test('throws when axis lengths disagree', () {
      expect(
        () => detector.detect(
          accelXMilliG: const [1, 2, 3],
          accelYMilliG: const [1, 2],
          accelZMilliG: const [1, 2, 3],
          samplingRateHz: _fs,
        ),
        throwsArgumentError,
      );
    });
  });
}

/// Resting wrist: x=y=0, z=1000 mg → magnitude = 1.0g, plus tiny noise
/// from a fixed-seed PRNG so std-dev isn't pathologically zero.
_AccelTrace _restingActivity({required int seconds}) {
  final n = (seconds * _fs).toInt();
  final rng = Random(7);
  final x = <int>[];
  final y = <int>[];
  final z = <int>[];
  for (int i = 0; i < n; i++) {
    x.add(rng.nextInt(11) - 5); // ±5 mg jitter
    y.add(rng.nextInt(11) - 5);
    z.add(1000 + rng.nextInt(11) - 5);
  }
  return _AccelTrace(x: x, y: y, z: z);
}

/// Synthetic fall: resting → freefall → impact → post-impact behaviour.
///
/// - `preFallSeconds` of normal resting (1g down)
/// - `freefallMs` of near-weightlessness (0g)
/// - 1 sample at `impactPeakG` (placed on the +x axis for clarity)
/// - `postImpactSeconds` of either stillness (movement=0) or oscillation
///   around 1g, where the magnitude swing equals
///   `postImpactMovementMagnitudeG`.
_AccelTrace _fallTrace({
  required int preFallSeconds,
  required int freefallMs,
  required double impactPeakG,
  required int postImpactSeconds,
  required double postImpactMovementMagnitudeG,
}) {
  final rng = Random(13);
  final pre = _restingActivity(seconds: preFallSeconds);

  final freefallSamples = (freefallMs / 1000 * _fs).round();
  final ffX = List<int>.filled(freefallSamples, 0);
  final ffY = List<int>.filled(freefallSamples, 0);
  final ffZ = List<int>.filled(freefallSamples, 0);

  final impactX = [(impactPeakG * 1000).round()];
  final impactY = [0];
  final impactZ = [0];

  final postSamples = (postImpactSeconds * _fs).toInt();
  final postX = <int>[];
  final postY = <int>[];
  final postZ = <int>[];
  for (int i = 0; i < postSamples; i++) {
    if (postImpactMovementMagnitudeG <= 0.001) {
      // Severe: lying still on the ground at 1g.
      postX.add(rng.nextInt(11) - 5);
      postY.add(rng.nextInt(11) - 5);
      postZ.add(1000 + rng.nextInt(11) - 5);
    } else {
      // Moderate / false-positive: oscillating on the dominant axis
      // (z). Oscillating x or y barely changes magnitude because z=1g
      // already dominates the Pythagorean sum.
      final swingMg = (postImpactMovementMagnitudeG * 1000).round();
      final swing = (sin(2 * pi * i / _fs) * swingMg).round();
      postX.add(rng.nextInt(21) - 10);
      postY.add(rng.nextInt(21) - 10);
      postZ.add(1000 + swing + rng.nextInt(21) - 10);
    }
  }

  return _AccelTrace(
    x: [...pre.x, ...ffX, ...impactX, ...postX],
    y: [...pre.y, ...ffY, ...impactY, ...postY],
    z: [...pre.z, ...ffZ, ...impactZ, ...postZ],
  );
}

class _AccelTrace {
  _AccelTrace({required this.x, required this.y, required this.z});
  final List<int> x;
  final List<int> y;
  final List<int> z;
}
