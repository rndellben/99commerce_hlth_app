import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/services/nightly_bp_capture_service.dart';

/// Unit tests for the night-window gating: which local times count as
/// "night", and that the night key is stable across midnight so a single
/// reading isn't taken twice for one night.
void main() {
  String? key(DateTime t, {int start = 23, int end = 7}) =>
      NightlyBpCaptureService.nightKey(t, startHour: start, endHour: end);

  test('daytime is outside the window → null', () {
    expect(key(DateTime(2026, 6, 24, 12)), isNull); // noon
    expect(key(DateTime(2026, 6, 24, 8)), isNull); // 08:00
    expect(key(DateTime(2026, 6, 24, 22, 59)), isNull); // 22:59
  });

  test('evening side keys to the same calendar day', () {
    expect(key(DateTime(2026, 6, 24, 23)), '2026-06-24');
    expect(key(DateTime(2026, 6, 24, 23, 30)), '2026-06-24');
  });

  test('morning side keys to the PREVIOUS day (night spans midnight)', () {
    // 02:00 on the 25th belongs to the night that opened on the 24th.
    expect(key(DateTime(2026, 6, 25, 2)), '2026-06-24');
    expect(key(DateTime(2026, 6, 25, 6, 59)), '2026-06-24');
  });

  test('23:30 and 02:00 next day share one night key', () {
    expect(key(DateTime(2026, 6, 24, 23, 30)), key(DateTime(2026, 6, 25, 2)));
  });

  test('07:00 exactly is outside (window end is exclusive)', () {
    expect(key(DateTime(2026, 6, 25, 7)), isNull);
  });

  test('custom window respects its bounds', () {
    expect(key(DateTime(2026, 6, 24, 0, 30), start: 1, end: 5), isNull);
    expect(key(DateTime(2026, 6, 24, 1), start: 1, end: 5), '2026-06-24');
    expect(key(DateTime(2026, 6, 24, 4, 59), start: 1, end: 5), '2026-06-24');
    expect(key(DateTime(2026, 6, 24, 5), start: 1, end: 5), isNull);
  });

  group('hourly spacing (one reading per hour of sleep)', () {
    bool due(DateTime now, DateTime? last) =>
        NightlyBpCaptureService.dueForNextReading(
          now: now,
          lastSuccessAt: last,
        );

    test('no prior reading → due immediately', () {
      expect(due(DateTime.utc(2026, 6, 24, 23, 30), null), isTrue);
    });

    test('30 min after a reading (next tick) → not due', () {
      final last = DateTime.utc(2026, 6, 25, 1, 0);
      expect(due(DateTime.utc(2026, 6, 25, 1, 30), last), isFalse);
    });

    test('55 min after a reading → due (tick jitter must not skip an hour)',
        () {
      final last = DateTime.utc(2026, 6, 25, 1, 0);
      expect(due(DateTime.utc(2026, 6, 25, 1, 55), last), isTrue);
    });

    test('a full hour after a reading → due', () {
      final last = DateTime.utc(2026, 6, 25, 1, 0);
      expect(due(DateTime.utc(2026, 6, 25, 2, 0), last), isTrue);
    });

    test('54 min after a reading → still inside the spacing guard', () {
      final last = DateTime.utc(2026, 6, 25, 1, 0);
      expect(due(DateTime.utc(2026, 6, 25, 1, 54), last), isFalse);
    });
  });
}
