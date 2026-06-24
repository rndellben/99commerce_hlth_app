import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/processing/signal_processor.dart';

void main() {
  final sp = SignalProcessor(samplingRate: 75);

  group('SignalProcessor.detectPeaks', () {
    test('returns empty on signals shorter than 3 samples', () {
      expect(sp.detectPeaks(Float64List(0)), isEmpty);
      expect(sp.detectPeaks(Float64List.fromList([1.0, 2.0])), isEmpty);
    });

    test('returns empty on a flat signal', () {
      final flat = Float64List(1000)..fillRange(0, 1000, 5.0);
      expect(sp.detectPeaks(flat), isEmpty);
    });

    test('clean 72 bpm sinusoid yields ~36 peaks in 30 seconds', () {
      // 1.2 Hz sine over 30s → exactly 36 cardiac cycles. detectPeaks
      // should land within ±2 of that (edges may or may not crest a
      // local max depending on phase).
      final s = _sine(freqHz: 1.2, fs: 75, durationS: 30, amplitude: 1.0);
      final peaks = sp.detectPeaks(s);
      expect(
        peaks.length,
        inInclusiveRange(34, 38),
        reason: 'got ${peaks.length} peaks — expected ~36 for 72 bpm × 30s',
      );
    });

    test('72 bpm + 10% Gaussian noise still recovers all real beats', () {
      final s = _sineWithNoise(
        freqHz: 1.2,
        fs: 75,
        durationS: 30,
        amplitude: 1.0,
        noiseStd: 0.1,
        seed: 42,
      );
      final peaks = sp.detectPeaks(s);
      // 10% noise rarely creates spurious local maxima that pass both
      // the height (median + 0.3σ) and prominence (0.1σ) gates — so we
      // expect the count to land near 36, not balloon upward.
      expect(
        peaks.length,
        inInclusiveRange(32, 40),
        reason: 'got ${peaks.length} peaks with 10% noise — expected near 36',
      );
    });

    test('large motion spike survives but does not erase nearby beats', () {
      final s = _sine(freqHz: 1.2, fs: 75, durationS: 30, amplitude: 1.0);
      // Inject a spike at sample 750 (t=10s). At 1.2 Hz the nearest real
      // peaks sit at samples ~719 and ~781 — both ≥31 samples away, so
      // the 25-sample distance filter cannot eliminate them.
      s[750] = 10.0;
      final peaks = sp.detectPeaks(s);
      expect(peaks, contains(750), reason: 'spike is a strict local max');
      expect(
        peaks.length,
        greaterThanOrEqualTo(34),
        reason: 'spike must not suppress legitimate peaks outside its window',
      );
    });

    test('end-to-end: raw PPG → bandpass → peaks → HR yields 72 ± 2 bpm', () {
      // Simulated raw H59-like PPG: 27000 DC offset + 1.2 Hz cardiac
      // modulation + 0.05 Hz baseline drift. The bandpass must reject
      // both the DC and the drift; detectPeaks must then find the beats.
      const fs = 75;
      const seconds = 30;
      final raw = Float64List(fs * seconds);
      for (int i = 0; i < raw.length; i++) {
        final t = i / fs;
        raw[i] = 27000 +
            200 * sin(2 * pi * 1.2 * t) +
            500 * sin(2 * pi * 0.05 * t);
      }

      final filtered = sp.bandpassFilter(raw, 0.5, 5.0);
      // Trim ~2s on each side to skip the IIR bandpass transient.
      const trim = 150;
      final clean = Float64List.fromList(
        filtered.sublist(trim, filtered.length - trim),
      );

      final peaks = sp.detectPeaks(clean);
      expect(
        peaks.length,
        inInclusiveRange(28, 34),
        reason: 'got ${peaks.length} from end-to-end pipeline — expected ~31',
      );

      final rr = sp.extractRRIntervals(peaks);
      expect(rr, isNotEmpty);
      final hr = sp.calculateHeartRate(rr);
      expect(hr, isNotNull);
      expect(
        hr!,
        inInclusiveRange(70.0, 74.0),
        reason: 'recovered HR=$hr — expected ~72 bpm',
      );
    });
  });

  group('SignalProcessor.refinePeaksParabolic', () {
    test('asymmetric triple shifts the peak toward the taller neighbour', () {
      // Vertex of the parabola through (9,8,6): delta = 0.5*(9-6)/(9-16+6)
      // = 0.5*3/-1 = -1.5, clamped to -0.5 → refined index 4.5.
      final s = Float64List.fromList([0, 0, 0, 9, 8, 6, 0, 0]);
      final refined = sp.refinePeaksParabolic(s, [4]);
      expect(refined.single, closeTo(3.5, 1e-9));
    });

    test('symmetric peak stays on the integer grid', () {
      final s = Float64List.fromList([0, 1, 5, 1, 0]);
      final refined = sp.refinePeaksParabolic(s, [2]);
      expect(refined.single, closeTo(2.0, 1e-9));
    });

    test('boundary peaks are returned unrefined', () {
      final s = Float64List.fromList([5, 4, 3, 4, 5]);
      expect(sp.refinePeaksParabolic(s, [0]).single, 0.0);
      expect(sp.refinePeaksParabolic(s, [4]).single, 4.0);
    });

    test('refined R-R intervals reduce quantisation jitter vs integer grid',
        () {
      // A clean 72 bpm sinusoid has perfectly even beats; on the integer
      // grid the R-R series carries ±1-sample jitter, which sub-sample
      // refinement should shrink. Compare the spread (SD) of each series.
      final s = _sine(freqHz: 1.2, fs: 75, durationS: 60, amplitude: 1.0);
      final peaks = sp.detectPeaks(s);
      final coarse = sp.extractRRIntervals(peaks);
      final fine = sp.extractRRIntervalsRefined(s, peaks);
      expect(fine.length, coarse.length);
      expect(_sd(fine), lessThan(_sd(coarse)),
          reason: 'refined SD=${_sd(fine)} coarse SD=${_sd(coarse)}');
    });
  });

  group('SignalProcessor.reconstructUniformFromCounter', () {
    test('contiguous counter passes through unchanged', () {
      final counts = List<int>.generate(50, (i) => i % 256);
      final greens = List<double>.generate(50, (i) => 100.0 + i);
      final r = sp.reconstructUniformFromCounter(counts, greens)!;
      expect(r.bandSampleCount, 50);
      expect(r.keptSamples, 50);
      expect(r.gapsInterpolated, 0);
      expect(r.samples.first, 100.0);
      expect(r.samples.last, 149.0);
    });

    test('a dropped sample is linearly interpolated at its true position', () {
      // Band-index 5 is missing (…4,6…); it should be filled with the
      // mean of its neighbours, not by closing the gap.
      final counts = <int>[];
      final greens = <double>[];
      for (int i = 0; i < 40; i++) {
        if (i == 5) continue;
        counts.add(i);
        greens.add(100.0 + i * 10); // nonzero so none read as blanks
      }
      final r = sp.reconstructUniformFromCounter(counts, greens)!;
      expect(r.bandSampleCount, 40); // span 0..39 preserved
      expect(r.keptSamples, 39);
      expect(r.gapsInterpolated, 1);
      expect(r.samples[4], closeTo(140.0, 1e-9));
      expect(r.samples[5], closeTo(150.0, 1e-9)); // interpolated
      expect(r.samples[6], closeTo(160.0, 1e-9));
    });

    test('green=0 sample is treated as a gap and interpolated', () {
      final counts = List<int>.generate(40, (i) => i);
      final greens = List<double>.generate(40, (i) => 100.0);
      greens[10] = 0.0; // blank
      final r = sp.reconstructUniformFromCounter(counts, greens)!;
      expect(r.keptSamples, 39);
      expect(r.gapsInterpolated, 1);
      expect(r.samples[10], closeTo(100.0, 1e-9));
    });

    test('counter wrap (255→0) is unwrapped, not a phantom gap', () {
      final counts = [253, 254, 255, 0, 1, 2, 3, 4, 5, 6, 7, 8];
      final greens = List<double>.generate(counts.length, (i) => 200.0 + i);
      final r = sp.reconstructUniformFromCounter(counts, greens)!;
      expect(r.bandSampleCount, counts.length);
      expect(r.gapsInterpolated, 0);
    });

    test('returns null when too few usable samples or misaligned', () {
      expect(sp.reconstructUniformFromCounter([1, 2, 3], [10, 20, 30]), isNull);
      expect(sp.reconstructUniformFromCounter([1, 2], [10, 20]), isNull);
      expect(sp.reconstructUniformFromCounter([1, 2, 3], [10, 20]), isNull);
    });
  });
}

double _sd(List<double> xs) {
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  double s = 0;
  for (final x in xs) {
    s += (x - mean) * (x - mean);
  }
  return sqrt(s / xs.length);
}

Float64List _sine({
  required double freqHz,
  required int fs,
  required int durationS,
  required double amplitude,
}) {
  final n = fs * durationS;
  final out = Float64List(n);
  for (int i = 0; i < n; i++) {
    out[i] = amplitude * sin(2 * pi * freqHz * i / fs);
  }
  return out;
}

Float64List _sineWithNoise({
  required double freqHz,
  required int fs,
  required int durationS,
  required double amplitude,
  required double noiseStd,
  required int seed,
}) {
  final n = fs * durationS;
  final out = Float64List(n);
  final rng = Random(seed);
  for (int i = 0; i < n; i++) {
    // Box-Muller transform to get N(0, 1) → scale by noiseStd.
    final u1 = rng.nextDouble().clamp(1e-12, 1.0);
    final u2 = rng.nextDouble();
    final z = sqrt(-2.0 * log(u1)) * cos(2 * pi * u2);
    out[i] = amplitude * sin(2 * pi * freqHz * i / fs) + noiseStd * z;
  }
  return out;
}
