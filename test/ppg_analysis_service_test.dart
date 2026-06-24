import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/services/ppg_analysis_service.dart';

void main() {
  final svc = PpgAnalysisService();

  group('PpgAnalysisService.analyze', () {
    test('clean ~72 bpm signal yields plausible HR and passes the gate', () {
      // 90 s of a clean 1.2 Hz (72 bpm) sinusoid sampled at 25 Hz, with a
      // contiguous ppg_count (no loss) and a realistic ~30k DC offset.
      const fs = 25;
      const seconds = 90;
      final counts = <int>[];
      final greens = <double>[];
      for (int i = 0; i < fs * seconds; i++) {
        counts.add(i % 256);
        greens.add(30000 + 800 * sin(2 * pi * 1.2 * i / fs));
      }

      final r = svc.analyze(
        counts: counts,
        greens: greens,
        greenZeroCount: 0,
        durationSec: seconds.toDouble(),
        bandHr: 72,
      );

      expect(r.error, isNull, reason: r.log.join('\n'));
      expect(r.usedCounterTiming, isTrue);
      expect(r.fsNativeHz, inInclusiveRange(24, 26));
      expect(r.hrBpm, isNotNull);
      expect(r.hrBpm!, inInclusiveRange(66.0, 78.0),
          reason: 'HR=${r.hrBpm} log=${r.log.join('\n')}');
      expect(r.passedQualityGate, isTrue, reason: r.rejectReasons.join('; '));
      // A perfectly periodic signal is a maximally REGULAR rhythm — the
      // irregularity index (R-R coefficient of variation) must read low.
      expect(r.rrIrregularityPct, isNotNull);
      expect(r.rrIrregularityPct!, lessThan(10.0),
          reason: 'CoV=${r.rrIrregularityPct} log=${r.log.join('\n')}');
      expect(r.ectopicBeatPct, isNotNull);
    });

    test('derived HR far from band HR fails the quality gate', () {
      const fs = 25;
      const seconds = 90;
      final counts = <int>[];
      final greens = <double>[];
      for (int i = 0; i < fs * seconds; i++) {
        counts.add(i % 256);
        greens.add(30000 + 800 * sin(2 * pi * 1.2 * i / fs));
      }

      // Tell the gate the band measured 130 bpm — derived ~72 is >15% off.
      final r = svc.analyze(
        counts: counts,
        greens: greens,
        greenZeroCount: 0,
        durationSec: seconds.toDouble(),
        bandHr: 130,
      );

      expect(r.passedQualityGate, isFalse);
      expect(r.rejectReasons, isNotEmpty);
    });

    test('capture whose derived HR is far from band HR rejects, no rhythm', () {
      // A clean 0.6 Hz (~36 bpm) signal, but tell the gate the band measured
      // 90 bpm. Beat coverage is fine (the signal is fully detected), so the
      // band-HR cross-check (36 vs 90 = 60% > 30%) is what rejects it. A
      // rejected capture must never emit a rhythm number.
      const fs = 25;
      const seconds = 90;
      final counts = <int>[];
      final greens = <double>[];
      for (int i = 0; i < fs * seconds; i++) {
        counts.add(i % 256);
        greens.add(30000 + 800 * sin(2 * pi * 0.6 * i / fs));
      }

      final r = svc.analyze(
        counts: counts,
        greens: greens,
        greenZeroCount: 0,
        durationSec: seconds.toDouble(),
        bandHr: 90,
      );

      expect(r.passedQualityGate, isFalse);
      expect(r.rejectReasons, isNotEmpty);
      expect(r.rrIrregularityPct, isNull);
      expect(r.ectopicBeatPct, isNull);
    });

    test('flat signal produces no peaks and does not pass the gate', () {
      const fs = 25;
      const seconds = 90;
      final counts = [for (int i = 0; i < fs * seconds; i++) i % 256];
      final greens = List<double>.filled(fs * seconds, 30000);

      final r = svc.analyze(
        counts: counts,
        greens: greens,
        greenZeroCount: 0,
        durationSec: seconds.toDouble(),
        bandHr: 72,
      );

      expect(r.error, isNotNull);
      expect(r.passedQualityGate, isFalse);
      expect(r.respRateBpm, isNull);
    });
  });
}
