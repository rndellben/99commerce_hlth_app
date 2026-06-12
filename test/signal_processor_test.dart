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
