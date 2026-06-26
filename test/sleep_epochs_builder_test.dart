import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart' as dbenums;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/scoring/sleep_epochs_builder.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart' as vl;

void main() {
  // Fixed session window: 2026-06-24 00:00 -> 02:00 local (120 minutes).
  final start = DateTime(2026, 6, 24, 0, 0);
  final end = DateTime(2026, 6, 24, 2, 0);

  // --- Terse constructor helpers (real required params) -------------------
  HrSample hrAt(DateTime t, int bpm) => HrSample(
        id: 'hr-${t.millisecondsSinceEpoch}-$bpm',
        userId: 'u1',
        deviceId: 'd1',
        capturedAt: t,
        tzOffsetMin: 0,
        bpm: bpm,
        intervalMin: 1,
        isResting: true,
        source: dbenums.DataSource.bandScheduled,
      );

  HrvSample hrvAt(DateTime t, double rmssd) => HrvSample(
        id: 'hrv-${t.millisecondsSinceEpoch}-$rmssd',
        userId: 'u1',
        deviceId: 'd1',
        capturedAt: t,
        tzOffsetMin: 0,
        rmssdMs: rmssd,
        source: dbenums.DataSource.bandScheduled,
      );

  StressSample stressAt(DateTime t, int score) => StressSample(
        id: 'st-${t.millisecondsSinceEpoch}-$score',
        userId: 'u1',
        deviceId: 'd1',
        capturedAt: t,
        tzOffsetMin: 0,
        stressScore: score,
        rangeMin: 30,
        source: dbenums.DataSource.bandScheduled,
      );

  SleepEpoch epochSpan(
    DateTime spanStart,
    int durationMin,
    dbenums.SleepStage stage,
  ) =>
      SleepEpoch(
        id: 'ep-${spanStart.millisecondsSinceEpoch}-${stage.name}',
        sessionId: 's1',
        userId: 'u1',
        startedAt: spanStart,
        durationMin: durationMin,
        stage: stage,
        source: dbenums.DataSource.bandScheduled,
      );

  group('bucketing', () {
    test('a HR sample at start+5min lands in epoch index 5; others NaN', () {
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: const [],
        hr: [hrAt(start.add(const Duration(minutes: 5)), 60)],
        hrv: const [],
        stress: const [],
      );

      expect(built.hr.length, 120);
      expect(built.hr[5], 60.0);
      // Every other epoch is NaN (never fabricated fill).
      for (var i = 0; i < built.hr.length; i++) {
        if (i == 5) continue;
        expect(built.hr[i].isNaN, isTrue, reason: 'epoch $i should be NaN');
      }
    });

    test('multiple samples in one minute are averaged', () {
      final t = start.add(const Duration(minutes: 10));
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: const [],
        hr: [hrAt(t, 50), hrAt(t.add(const Duration(seconds: 30)), 70)],
        hrv: const [],
        stress: const [],
      );
      expect(built.hr[10], 60.0); // mean of 50 and 70
    });

    test('samples outside [start, end) are dropped', () {
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: const [],
        hr: [
          hrAt(start.subtract(const Duration(minutes: 1)), 99), // before
          hrAt(end, 99), // exactly at end -> index 120, out of range
        ],
        hrv: const [],
        stress: const [],
      );
      for (final v in built.hr) {
        expect(v.isNaN, isTrue);
      }
    });
  });

  group('stage painting', () {
    test('a deep span [start, start+30min) makes epochs 0..29 deep', () {
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: [epochSpan(start, 30, dbenums.SleepStage.deep)],
        hr: const [],
        hrv: const [],
        stress: const [],
      );
      for (var i = 0; i < 30; i++) {
        expect(built.stage[i], vl.SleepStage.deep, reason: 'epoch $i');
      }
      // Epoch 30 onward defaults to wake (no span painted).
      expect(built.stage[30], vl.SleepStage.wake);
    });

    test('light and rem spans paint their own epochs', () {
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: [
          epochSpan(start, 10, dbenums.SleepStage.light),
          epochSpan(start.add(const Duration(minutes: 10)), 10,
              dbenums.SleepStage.rem),
        ],
        hr: const [],
        hrv: const [],
        stress: const [],
      );
      expect(built.stage[0], vl.SleepStage.light);
      expect(built.stage[9], vl.SleepStage.light);
      expect(built.stage[10], vl.SleepStage.rem);
      expect(built.stage[19], vl.SleepStage.rem);
    });

    test('awake, noSleep, unweared all map to vl.SleepStage.wake', () {
      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: [
          epochSpan(start, 10, dbenums.SleepStage.awake),
          epochSpan(start.add(const Duration(minutes: 10)), 10,
              dbenums.SleepStage.noSleep),
          epochSpan(start.add(const Duration(minutes: 20)), 10,
              dbenums.SleepStage.unweared),
        ],
        hr: const [],
        hrv: const [],
        stress: const [],
      );
      for (var i = 0; i < 30; i++) {
        expect(built.stage[i], vl.SleepStage.wake, reason: 'epoch $i');
      }
    });
  });

  group('end-to-end reduceSession', () {
    test('dense night -> finite hrP5/rmssdMedian and valid == true', () {
      // 4-hour session, entirely deep so it passes the asleep + deep masks
      // and clears the >= 3h min-sleep gate (reduceSession's validity rule).
      final longEnd = start.add(const Duration(hours: 4));
      final stages = [epochSpan(start, 240, dbenums.SleepStage.deep)];

      // >= 10 HR samples in asleep epochs.
      final hr = <HrSample>[];
      for (var i = 0; i < 60; i++) {
        hr.add(hrAt(start.add(Duration(minutes: i)), 55 + (i % 5)));
      }
      // >= 5 RMSSD samples in deep epochs.
      final hrv = <HrvSample>[];
      for (var i = 0; i < 30; i++) {
        hrv.add(hrvAt(start.add(Duration(minutes: i * 2)), 40.0 + i));
      }
      // Stress samples in asleep epochs.
      final stress = <StressSample>[];
      for (var i = 0; i < 10; i++) {
        stress.add(stressAt(start.add(Duration(minutes: i * 5)), 20 + i));
      }

      final built = SleepEpochsBuilder.build(
        start: start,
        end: longEnd,
        stages: stages,
        hr: hr,
        hrv: hrv,
        stress: stress,
      );

      final record = vl.reduceSession('2026-06-24', built);

      expect(record.hrP5.isFinite, isTrue);
      expect(record.rmssdMedian.isFinite, isTrue);
      expect(record.valid, isTrue);
      expect(record.coverage, 1.0); // every epoch is asleep (deep)
    });

    test('sparse HR (< 10 samples) -> hrP5 NaN and valid == false', () {
      final stages = [epochSpan(start, 120, dbenums.SleepStage.deep)];

      // Only 3 HR samples -> below the >= 10 trough threshold.
      final hr = <HrSample>[
        hrAt(start.add(const Duration(minutes: 1)), 55),
        hrAt(start.add(const Duration(minutes: 2)), 56),
        hrAt(start.add(const Duration(minutes: 3)), 57),
      ];
      // Plenty of RMSSD so it's clearly HR that fails validity.
      final hrv = <HrvSample>[];
      for (var i = 0; i < 30; i++) {
        hrv.add(hrvAt(start.add(Duration(minutes: i * 2)), 40.0 + i));
      }

      final built = SleepEpochsBuilder.build(
        start: start,
        end: end,
        stages: stages,
        hr: hr,
        hrv: hrv,
        stress: const [],
      );

      final record = vl.reduceSession('2026-06-24', built);

      expect(record.hrP5.isNaN, isTrue);
      expect(record.valid, isFalse);
    });
  });
}
