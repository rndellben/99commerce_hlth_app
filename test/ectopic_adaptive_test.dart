import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/ectopic_adaptive.dart';
import 'package:hlth_app/core/processing/hrv_calculator.dart';

void main() {
  // A steady ~72 bpm rhythm (~833 ms) with small physiologic jitter.
  List<double> steadyRhythm({int n = 40, double base = 833}) {
    final rr = <double>[];
    for (int i = 0; i < n; i++) {
      // Deterministic ±12 ms wobble — well inside the adaptive accept band.
      rr.add(base + (i.isEven ? 12.0 : -12.0));
    }
    return rr;
  }

  group('cleanAdaptive', () {
    test('clean rhythm: nothing flagged, length preserved', () {
      final rr = steadyRhythm();
      final res = cleanAdaptive(rr);

      expect(res.rrCorrected.length, rr.length,
          reason: 'correction must preserve the time axis');
      expect(res.ectopicFraction, 0.0);
      expect(res.gapFraction, 0.0);
      expect(res.nNormal, rr.length);
    });

    test('a missed beat (~2×) is labelled gap, not ectopy', () {
      final rr = steadyRhythm();
      rr[20] = 1666; // two beats stitched into one long interval (BLE drop)

      final res = cleanAdaptive(rr);

      expect(res.labels[20], BeatLabel.gap);
      expect(res.gapFraction, greaterThan(0));
      // Crucially, a BLE gap must NOT inflate the arrhythmia signal.
      expect(res.ectopicFraction, 0.0);
      // The gap interval is interpolated back toward the local rhythm.
      expect(res.rrCorrected[20], lessThan(1000));
    });

    test('a genuine premature beat is flagged as ectopic', () {
      final rr = steadyRhythm();
      rr[20] = 520; // premature beat, ~0.6× — real ectopy, not a gap

      final res = cleanAdaptive(rr);

      expect(res.ectopicFraction, greaterThan(0));
      expect(res.labels[20], isNot(BeatLabel.normal));
      expect(res.labels[20], isNot(BeatLabel.gap));
    });
  });

  group('HrvCalculator.calculateFromLabeled', () {
    test('clean series yields valid HRV', () {
      final rr = steadyRhythm();
      final res = cleanAdaptive(rr);
      final hrv = HrvCalculator().calculateFromLabeled(res.rrCorrected, res.labels);

      expect(hrv, isNotNull);
      expect(hrv!.meanHr, closeTo(72, 2));
    });

    test('returns null when fewer than 10 normal beats remain', () {
      final rr = steadyRhythm(n: 8);
      final res = cleanAdaptive(rr);
      final hrv = HrvCalculator().calculateFromLabeled(res.rrCorrected, res.labels);

      expect(hrv, isNull);
    });
  });
}
