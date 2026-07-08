import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';

/// The pure verdict behind sleep-triggered captures (nightly BP + sleep
/// PPG). Asleep = night span AND settled HR AND zero steps; every ambiguous
/// input must resolve to awake (a false "asleep" spends a once-per-night
/// BP attempt on an awake reading).
void main() {
  group('SleepOnsetDetector.judge', () {
    test('settled HR + zero steps at night → asleep', () {
      expect(
        SleepOnsetDetector.judge(
          localHour: 4, // 04:00 — mid-sleep for a 03:37 sleeper
          recentAvgHr: 58,
          restingHr: 57,
          recentSteps: 0,
        ),
        isTrue,
      );
    });

    test('daytime hour → awake even with settled HR', () {
      expect(
        SleepOnsetDetector.judge(
          localHour: 14,
          recentAvgHr: 55,
          restingHr: 57,
          recentSteps: 0,
        ),
        isFalse,
      );
    });

    test('elevated HR at night → awake', () {
      // resting 57 + margin 20 = 77 ceiling; 82 is a genuinely active HR.
      expect(
        SleepOnsetDetector.judge(
          localHour: 23,
          recentAvgHr: 82,
          restingHr: 57,
          recentSteps: 0,
        ),
        isFalse,
      );
    });

    test('HR exactly at resting + margin → asleep (inclusive bound)', () {
      expect(
        SleepOnsetDetector.judge(
          localHour: 2,
          recentAvgHr: 77,
          restingHr: 57,
          recentSteps: 0,
        ),
        isTrue,
      );
    });

    test('regression 2026-07-08: real sleeping HR rides well above the '
        'resting floor (70–78 vs rest 60) and must still read asleep', () {
      // First full night's crumbs: every overnight tick (hr 70/74/78,
      // rest=60) was judged awake under the old +8 margin, so nightly BP
      // never fired. The resting baseline is the overnight MINIMUM — real
      // sleep hovers 10–18 bpm above it across light/REM cycles.
      for (final hr in [70.0, 74.0, 78.0]) {
        expect(
          SleepOnsetDetector.judge(
            localHour: 4,
            recentAvgHr: hr,
            restingHr: 60,
            recentSteps: 0,
          ),
          isTrue,
          reason: 'hr=$hr must be asleep vs rest=60',
        );
      }
    });

    test('any steps in the window → awake (walking is proof)', () {
      expect(
        SleepOnsetDetector.judge(
          localHour: 1,
          recentAvgHr: 58,
          restingHr: 57,
          recentSteps: 12,
        ),
        isFalse,
      );
    });

    test('no fresh HR → awake (cannot confirm — conservative)', () {
      expect(
        SleepOnsetDetector.judge(
          localHour: 3,
          recentAvgHr: null,
          restingHr: 57,
          recentSteps: 0,
        ),
        isFalse,
      );
    });

    test('morning side of the span covers late sleepers (10:xx asleep)', () {
      // Verified 2026-07-07: user sleeps 03:37–12:52 — 10:00 is mid-sleep.
      expect(
        SleepOnsetDetector.judge(
          localHour: 10,
          recentAvgHr: 56,
          restingHr: 57,
          recentSteps: 0,
        ),
        isTrue,
      );
    });

    test('night span boundaries: 11:00 is out, 21:00 is in', () {
      expect(SleepOnsetDetector.inNightSpan(11), isFalse);
      expect(SleepOnsetDetector.inNightSpan(20), isFalse);
      expect(SleepOnsetDetector.inNightSpan(21), isTrue);
      expect(SleepOnsetDetector.inNightSpan(0), isTrue);
      expect(SleepOnsetDetector.inNightSpan(10), isTrue);
    });
  });
}
