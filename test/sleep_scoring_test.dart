import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/processing/sleep_scoring.dart';

void main() {
  group('sleepScoreFromStages — reference fixtures', () {
    // Reference outputs from `hlth_pipeline/notebooks/03_recovery_score.ipynb`,
    // Test 5. Allow ±1.5 because the pipeline composite is a weighted sum
    // of clamped sub-scores; rounding at the float boundary can differ by
    // ~1 point between Python and Dart without anything being wrong.

    test('ideal night → 100.0', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 480,
        deepPct: 20,
        remPct: 22,
        efficiencyPct: 92,
        latencyMin: 15,
      );
      expect(s, closeTo(100.0, 1.5));
    });

    test('short sleep → 72.0', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 300,
        deepPct: 18,
        remPct: 20,
        efficiencyPct: 88,
        latencyMin: 12,
      );
      expect(s, closeTo(72.0, 1.5));
    });

    test('long sleep → 88.0', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 660,
        deepPct: 18,
        remPct: 22,
        efficiencyPct: 90,
        latencyMin: 10,
      );
      expect(s, closeTo(88.0, 1.5));
    });

    test('poor efficiency → 89.9', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 480,
        deepPct: 18,
        remPct: 22,
        efficiencyPct: 65,
        latencyMin: 12,
      );
      expect(s, closeTo(89.9, 1.5));
    });

    test('insomnia → 69.9', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 420,
        deepPct: 10,
        remPct: 12,
        efficiencyPct: 70,
        latencyMin: 55,
      );
      expect(s, closeTo(69.9, 1.5));
    });

    test('no deep sleep → 85.0', () {
      final s = sleepScoreFromStages(
        totalSleepMin: 480,
        deepPct: 5,
        remPct: 22,
        efficiencyPct: 88,
        latencyMin: 15,
      );
      expect(s, closeTo(85.0, 1.5));
    });
  });

  group('sleepScoreFromStages — bounds and edge cases', () {
    test('clamps to 0-100', () {
      final low = sleepScoreFromStages(
        totalSleepMin: 0,
        deepPct: 0,
        remPct: 0,
        efficiencyPct: 0,
        latencyMin: 999,
      );
      expect(low, inInclusiveRange(0.0, 100.0));

      final high = sleepScoreFromStages(
        totalSleepMin: 480,
        deepPct: 20,
        remPct: 22.5,
        efficiencyPct: 100,
        latencyMin: 10,
      );
      expect(high, inInclusiveRange(0.0, 100.0));
    });
  });

  group('sleepLatencyMin', () {
    final session = SleepSession(
      id: 's',
      userId: 'u',
      deviceId: 'd',
      startedAt: DateTime.utc(2026, 6, 5, 22, 0),
      endedAt: DateTime.utc(2026, 6, 6, 6, 0),
      tzOffsetMin: 0,
      type: SleepSessionType.night,
      protocolVersion: 2,
      totalMin: 480,
      source: DataSource.bandScheduled,
    );

    SleepEpoch epoch(
        DateTime startedAt, int durationMin, SleepStage stage) =>
        SleepEpoch(
          id: 'e-${startedAt.toIso8601String()}',
          sessionId: 's',
          userId: 'u',
          startedAt: startedAt,
          durationMin: durationMin,
          stage: stage,
          source: DataSource.bandScheduled,
        );

    test('15 minutes of awake then sleep → latency 15', () {
      final epochs = [
        epoch(DateTime.utc(2026, 6, 5, 22, 0), 15, SleepStage.awake),
        epoch(DateTime.utc(2026, 6, 5, 22, 15), 30, SleepStage.light),
      ];
      expect(sleepLatencyMin(session, epochs), 15);
    });

    test('falls asleep immediately → latency 0', () {
      final epochs = [
        epoch(DateTime.utc(2026, 6, 5, 22, 0), 30, SleepStage.light),
      ];
      expect(sleepLatencyMin(session, epochs), 0);
    });

    test('unweared epochs are not counted as sleep onset', () {
      final epochs = [
        epoch(DateTime.utc(2026, 6, 5, 22, 0), 10, SleepStage.unweared),
        epoch(DateTime.utc(2026, 6, 5, 22, 10), 20, SleepStage.awake),
        epoch(DateTime.utc(2026, 6, 5, 22, 30), 30, SleepStage.deep),
      ];
      expect(sleepLatencyMin(session, epochs), 30);
    });

    test('never enters a sleep stage → null', () {
      final epochs = [
        epoch(DateTime.utc(2026, 6, 5, 22, 0), 30, SleepStage.awake),
        epoch(DateTime.utc(2026, 6, 5, 22, 30), 60, SleepStage.unweared),
      ];
      expect(sleepLatencyMin(session, epochs), isNull);
    });
  });
}
