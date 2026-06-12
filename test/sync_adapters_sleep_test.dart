import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/sync_adapters.dart';
import 'package:hlth_app/core/database/enums.dart';

void main() {
  // Sleep starts 22:00 UTC 2026-06-04, wakes 06:00 UTC 2026-06-05 (8h).
  const sleepTime = 1780000800; // 2026-06-04 22:00 UTC (Unix sec)
  const wakeTime = 1780029600;  // 2026-06-05 06:00 UTC

  Map<String, dynamic> baseNative({
    int totalSec = 28800,
    int deepSec = 5400,
    int shallowSec = 18840,
    int rapidSec = 0,
    int awakeSec = 4560,
    List<Map<String, dynamic>>? stages,
  }) {
    return {
      'totalSleepDuration': totalSec,
      'deepDuration': deepSec,
      'shallowDuration': shallowSec,
      'awakeDuration': awakeSec,
      'rapidDuration': rapidSec,
      'sleepTime': sleepTime,
      'wakeTime': wakeTime,
      'wakingCount': 2,
      'stages': stages ?? const [],
    };
  }

  /// Construct a stage epoch with `sleepStart` / `sleepEnd` in unix sec.
  Map<String, dynamic> stage({
    required int startSec,
    required int durationSec,
    required int type,
  }) =>
      {
        'sleepStart': startSec,
        'sleepEnd': startSec + durationSec,
        'type': type,
      };

  group('sleepFromNative — basic parsing', () {
    test('returns null when sleepTime or wakeTime is zero', () {
      expect(
        sleepFromNative(baseNative()..['sleepTime'] = 0,
            userId: 'u', deviceId: 'd'),
        isNull,
      );
      expect(
        sleepFromNative(baseNative()..['wakeTime'] = 0,
            userId: 'u', deviceId: 'd'),
        isNull,
      );
    });

    test('converts band-side seconds to minutes', () {
      final r = sleepFromNative(baseNative(), userId: 'u', deviceId: 'd');
      expect(r!.session.totalMin, 480); // 28800s / 60
      expect(r.session.deepMin, 90);
      expect(r.session.lightMin, 314); // 18840 / 60 = 314.0
      expect(r.session.awakeMin, 76);  // 4560 / 60 = 76
    });

    test('startedAt and endedAt are UTC', () {
      final r = sleepFromNative(baseNative(), userId: 'u', deviceId: 'd');
      expect(r!.session.startedAt.isUtc, isTrue);
      expect(r.session.endedAt.isUtc, isTrue);
      expect(r.session.endedAt.difference(r.session.startedAt).inHours, 8);
    });
  });

  group('sleepFromNative — protocol detection (gap #1)', () {
    test('no REM minutes and no REM epochs → protocol v1', () {
      final r = sleepFromNative(
        baseNative(rapidSec: 0, stages: [
          stage(startSec: sleepTime, durationSec: 5400, type: 2), // light
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.protocolVersion, 1);
    });

    test('REM minutes > 0 → protocol v2', () {
      final r = sleepFromNative(
        baseNative(rapidSec: 6000), // 100 min of REM
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.protocolVersion, 2);
    });

    test('any REM epoch → protocol v2 even when remDuration is 0', () {
      // Defensive: some firmware reports per-epoch REM without the
      // session-level rapidDuration field populated.
      final r = sleepFromNative(
        baseNative(rapidSec: 0, stages: [
          stage(startSec: sleepTime, durationSec: 5400, type: 4), // REM
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.protocolVersion, 2);
    });
  });

  group('sleepFromNative — coverage gap (gap #2)', () {
    test('no unweared epochs → coverageGapMin=0 and hasUnweared=false', () {
      final r = sleepFromNative(
        baseNative(stages: [
          stage(startSec: sleepTime, durationSec: 5400, type: 1), // deep
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.coverageGapMin, 0);
      expect(r.session.hasUnweared, isFalse);
    });

    test('unweared epoch (type=5) → coverageGapMin counts it', () {
      final r = sleepFromNative(
        baseNative(stages: [
          stage(startSec: sleepTime, durationSec: 3600, type: 1), // deep 60m
          stage(startSec: sleepTime + 3600, durationSec: 1800, type: 5), // unweared 30m
          stage(startSec: sleepTime + 5400, durationSec: 3600, type: 2), // light
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.coverageGapMin, 30);
      expect(r.session.hasUnweared, isTrue);
    });

    test('multiple unweared windows sum into coverageGapMin', () {
      final r = sleepFromNative(
        baseNative(stages: [
          stage(startSec: sleepTime, durationSec: 600, type: 5),   // 10m
          stage(startSec: sleepTime + 600, durationSec: 3600, type: 2),
          stage(startSec: sleepTime + 4200, durationSec: 1200, type: 5), // 20m
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.session.coverageGapMin, 30);
      expect(r.session.hasUnweared, isTrue);
    });
  });

  group('sleepFromNative — stage timestamps', () {
    test('seconds-based stage times are converted correctly', () {
      final r = sleepFromNative(
        baseNative(stages: [
          stage(startSec: sleepTime, durationSec: 1800, type: 1),
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.epochs, hasLength(1));
      expect(r.epochs.first.durationMin, 30);
      expect(r.epochs.first.stage, SleepStage.deep);
    });

    test('millisecond-based stage times are auto-detected', () {
      // Some firmware variants ship `sleepStart` in milliseconds.
      final r = sleepFromNative(
        baseNative(stages: [
          {
            'sleepStart': sleepTime * 1000,
            'sleepEnd': (sleepTime + 1800) * 1000,
            'type': 2,
          },
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.epochs, hasLength(1));
      expect(r.epochs.first.durationMin, 30);
      expect(r.epochs.first.stage, SleepStage.light);
    });

    test('zero-or-negative durations are dropped', () {
      final r = sleepFromNative(
        baseNative(stages: [
          {'sleepStart': sleepTime, 'sleepEnd': sleepTime, 'type': 1},
          {'sleepStart': sleepTime, 'sleepEnd': sleepTime - 60, 'type': 2},
          stage(startSec: sleepTime, durationSec: 600, type: 3),
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.epochs, hasLength(1));
    });
  });

  group('sleepFromNative — stage code mapping', () {
    test('all known stage codes map correctly', () {
      final r = sleepFromNative(
        baseNative(stages: [
          stage(startSec: sleepTime, durationSec: 60, type: 1), // deep
          stage(startSec: sleepTime + 60, durationSec: 60, type: 2),
          stage(startSec: sleepTime + 120, durationSec: 60, type: 3),
          stage(startSec: sleepTime + 180, durationSec: 60, type: 4),
          stage(startSec: sleepTime + 240, durationSec: 60, type: 5),
        ]),
        userId: 'u',
        deviceId: 'd',
      );
      expect(r!.epochs.map((e) => e.stage).toList(), [
        SleepStage.deep,
        SleepStage.light,
        SleepStage.awake,
        SleepStage.rem,
        SleepStage.noSleep, // type=5 documented as "no_sleep / no_wear"
      ]);
    });
  });
}
