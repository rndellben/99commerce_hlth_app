import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/frequency_domain_hrv.dart';

void main() {
  final fd = FrequencyDomainHrv();

  group('FrequencyDomainHrv.calculate', () {
    test('returns null when input is too short', () {
      expect(fd.calculate(const []), isNull);
      expect(fd.calculate(const [800, 810, 790]), isNull);
    });

    test('returns null when tachogram is shorter than 25 seconds', () {
      // 25 beats × 800 ms = 20 s — under the LF resolution floor.
      final shortRr = List<double>.filled(25, 800);
      expect(fd.calculate(shortRr), isNull);
    });

    test('LF-modulated R-R (0.1 Hz) puts most power in the LF band', () {
      final rr = _modulatedRr(
        baseRrMs: 800,
        amplitudeMs: 50,
        modulationHz: 0.10,
        durationS: 90,
      );
      final m = fd.calculate(rr)!;
      expect(m.lfPowerMs2, greaterThan(m.hfPowerMs2 * 5),
          reason: 'LF=${m.lfPowerMs2} HF=${m.hfPowerMs2} ratio=${m.lfHfRatio}');
      expect(m.lfHfRatio, greaterThan(5.0));
    });

    test('HF-modulated R-R (0.25 Hz) puts most power in the HF band', () {
      // 0.25 Hz ≈ 15 breaths/min — squarely in the respiratory band.
      final rr = _modulatedRr(
        baseRrMs: 800,
        amplitudeMs: 50,
        modulationHz: 0.25,
        durationS: 90,
      );
      final m = fd.calculate(rr)!;
      expect(m.hfPowerMs2, greaterThan(m.lfPowerMs2 * 5),
          reason: 'LF=${m.lfPowerMs2} HF=${m.hfPowerMs2} ratio=${m.lfHfRatio}');
      expect(m.lfHfRatio, lessThan(0.2));
    });

    test('combined LF + HF modulation produces a ratio in physiological range',
        () {
      final base = _modulatedRr(
        baseRrMs: 800,
        amplitudeMs: 30,
        modulationHz: 0.10,
        durationS: 120,
      );
      // Re-modulate by adding HF on top.
      double t = 0;
      final dual = <double>[];
      for (final rr in base) {
        final phase = 2 * pi * 0.25 * (t / 1000);
        dual.add(rr + 20 * sin(phase));
        t += rr;
      }
      final m = fd.calculate(dual)!;
      // Healthy resting LF/HF typically lands between 0.5 and 3.
      expect(m.lfHfRatio, inInclusiveRange(0.3, 5.0),
          reason: 'LF=${m.lfPowerMs2} HF=${m.hfPowerMs2} ratio=${m.lfHfRatio}');
    });

    test('tachogram duration is reported correctly', () {
      final rr = _modulatedRr(
        baseRrMs: 800,
        amplitudeMs: 30,
        modulationHz: 0.10,
        durationS: 90,
      );
      final m = fd.calculate(rr)!;
      expect(m.tachogramDurationS, inInclusiveRange(85, 95));
      // 4 Hz resampling: ~360 samples in a 90 s window.
      expect(m.resampledSamples, inInclusiveRange(340, 380));
    });
  });
}

/// Generate an R-R series of [durationS] seconds, modulated as
/// `RR[n] = baseRrMs + amplitudeMs * sin(2π · modulationHz · t[n])`
/// where `t[n]` is the cumulative beat time. Stays positive as long as
/// `amplitudeMs < baseRrMs`.
List<double> _modulatedRr({
  required double baseRrMs,
  required double amplitudeMs,
  required double modulationHz,
  required double durationS,
}) {
  final rr = <double>[];
  double t = 0;
  while (t < durationS * 1000) {
    final phase = 2 * pi * modulationHz * (t / 1000);
    final value = baseRrMs + amplitudeMs * sin(phase);
    rr.add(value);
    t += value;
  }
  return rr;
}
