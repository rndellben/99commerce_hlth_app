import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/hrv_calculator.dart';

void main() {
  group('HrvCalculator', () {
    final calc = HrvCalculator();

    test('returns null when fewer than 10 beats survive cleaning', () {
      final tooShort = List<double>.filled(9, 1000.0);
      expect(calc.calculate(tooShort), isNull);
    });

    test('clean alternating ±20ms signal yields RMSSD = 40ms exactly', () {
      // 50 beats: 1020, 980, 1020, 980, ... Successive diffs are all ±40,
      // so RMSSD = sqrt(mean(diff^2)) = sqrt(1600) = 40.
      final rr = _alternating(50);
      final metrics = calc.calculate(
        rr,
        policy: EctopicCleaningPolicy.none,
      )!;
      expect(metrics.rmssd, closeTo(40.0, 0.001));
    });

    test('Malik cleaning recovers reference RMSSD when ectopics injected', () {
      final clean = _alternating(50);
      final reference = calc
          .calculate(clean, policy: EctopicCleaningPolicy.none)!
          .rmssd;

      // Inject two ectopic beats well outside ±20% of their neighbours.
      // Malik will cascade-drop each ectopic plus the following beat
      // (which compares to the ectopic as its predecessor). Dropping
      // adjacent pairs from an alternating sequence preserves the
      // alternation, so the cleaned RMSSD lands within 5% of reference.
      final dirty = List<double>.from(clean)
        ..[15] = 1500.0
        ..[35] = 600.0;

      final cleanedRmssd = calc
          .calculate(dirty, policy: EctopicCleaningPolicy.malik)!
          .rmssd;
      final dirtyRmssd = calc
          .calculate(dirty, policy: EctopicCleaningPolicy.none)!
          .rmssd;

      final cleanedError = (cleanedRmssd - reference).abs() / reference;
      expect(
        cleanedError,
        lessThan(0.05),
        reason: 'cleaned=$cleanedRmssd ref=$reference err=$cleanedError',
      );

      // Sanity check the other direction: without cleaning the ectopics
      // inflate RMSSD by an order of magnitude. If this fails the test
      // fixture itself has stopped being "noisy enough" and the cleaned
      // assertion above no longer proves anything.
      expect(
        dirtyRmssd,
        greaterThan(reference * 3),
        reason: 'uncleaned RMSSD ($dirtyRmssd) should swamp ref ($reference)',
      );
    });

    test('cleanEctopics(none) passes the series through unchanged', () {
      final rr = [1000.0, 1020.0, 980.0, 1010.0];
      expect(
        calc.cleanEctopics(rr, policy: EctopicCleaningPolicy.none),
        equals(rr),
      );
    });

    test('cleanEctopics(malik) drops the ectopic plus the cascaded neighbour',
        () {
      // First beat is kept by definition. Beat at i=10 is the ectopic
      // (1500ms after a ~1000ms run). Malik drops it, then drops i=11
      // too because 1020/1500 = 0.68 (outside [0.8, 1.2]).
      final rr = _alternating(20)..[10] = 1500.0;
      final cleaned = calc.cleanEctopics(rr);
      expect(cleaned.contains(1500.0), isFalse);
      expect(cleaned.length, equals(rr.length - 2));
    });

    test('first beat is always retained (cannot compare to nothing)', () {
      final rr = _alternating(20);
      final cleaned = calc.cleanEctopics(rr);
      expect(cleaned.first, equals(rr.first));
    });
  });
}

/// `n` beats alternating 1020 / 980 starting with 1020.
List<double> _alternating(int n) =>
    List<double>.generate(n, (i) => i.isEven ? 1020.0 : 980.0);
