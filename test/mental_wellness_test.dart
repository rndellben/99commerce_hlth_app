import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/scoring/mental_wellness.dart';

/// Behavioural checks on the Mental Wellness engine (guide §2). Rather than pin
/// exact composite figures (weights are starting values), these assert the
/// engine's documented invariants on deterministic inputs:
///   * cold-start lock until enough core days bank,
///   * provisional while the baseline matures, then firm,
///   * missing signals are REDISTRIBUTED, never fabricated,
///   * each input moves the score in its documented direction,
///   * a baseline-identical week reads as its neutral sub-scores.
void main() {
  WellnessDay day({
    double? rmssd,
    double? rhr,
    double? deep,
    double? eff,
    double? bedtime,
    double? steps,
  }) =>
      WellnessDay(
        rmssd: rmssd,
        rhr: rhr,
        deepFraction: deep,
        efficiencyFraction: eff,
        bedtimeMinutes: bedtime,
        steps: steps,
      );

  /// [n] identical days carrying HRV + resting HR, oldest-first.
  List<WellnessDay> flat(int n, {double rmssd = 50, double rhr = 60}) =>
      [for (var i = 0; i < n; i++) day(rmssd: rmssd, rhr: rhr)];

  test('empty history → noData', () {
    final r = computeMentalWellness(history: const []);
    expect(r.status, WellnessStatus.noData);
  });

  test('cold start: <7 core days is calibrating', () {
    final r = computeMentalWellness(history: flat(6));
    expect(r.status, WellnessStatus.calibrating);
    expect(r.message, contains('1 more day'));
  });

  test('7–13 core days produces a provisional score', () {
    final r = computeMentalWellness(history: flat(10));
    expect(r.produced, isTrue, reason: r.message);
    expect(r.provisional, isTrue);
  });

  test('≥14 core days produces a firm (non-provisional) score', () {
    final r = computeMentalWellness(history: flat(20));
    expect(r.produced, isTrue, reason: r.message);
    expect(r.provisional, isFalse);
  });

  test('missing signals are redistributed, not fabricated', () {
    // Only HRV present, flat at baseline → ratio 1 → hrv sub-score ~50, and the
    // composite equals it (no other component invented).
    final r = computeMentalWellness(
      history: [for (var i = 0; i < 20; i++) day(rmssd: 50)],
    );
    expect(r.produced, isTrue, reason: r.message);
    expect(r.components.keys, containsAll(['hrv', 'coverageDays']));
    expect(r.components.containsKey('rhr'), isFalse);
    expect(r.components.containsKey('sleep'), isFalse);
    expect(r.components.containsKey('activity'), isFalse);
    // composite == the single available sub-score
    expect(r.score, closeTo(r.components['hrv']!, 0.2));
  });

  test('chronically suppressed weekly HRV lowers the score', () {
    // 23 baseline days high (55), last 7 suppressed (30): weekly avg well below
    // the 30-day baseline → lower HRV sub-score than a flat week.
    final suppressed = <WellnessDay>[
      for (var i = 0; i < 23; i++) day(rmssd: 55),
      for (var i = 0; i < 7; i++) day(rmssd: 30),
    ];
    final flatWeek = [for (var i = 0; i < 30; i++) day(rmssd: 55)];
    final rSup = computeMentalWellness(history: suppressed);
    final rFlat = computeMentalWellness(history: flatWeek);
    expect(rSup.produced && rFlat.produced, isTrue);
    expect(rSup.score! < rFlat.score!, isTrue,
        reason: 'suppressed ${rSup.score} should be below flat ${rFlat.score}');
  });

  test('elevated weekly resting HR lowers the score', () {
    final elevated = <WellnessDay>[
      for (var i = 0; i < 23; i++) day(rhr: 55),
      for (var i = 0; i < 7; i++) day(rhr: 70),
    ];
    final flatWeek = [for (var i = 0; i < 30; i++) day(rhr: 55)];
    final rEl = computeMentalWellness(history: elevated);
    final rFlat = computeMentalWellness(history: flatWeek);
    expect(rEl.produced && rFlat.produced, isTrue);
    expect(rEl.score! < rFlat.score!, isTrue,
        reason: 'elevated RHR ${rEl.score} should be below flat ${rFlat.score}');
  });

  test('irregular bedtime lowers the circadian/sleep contribution', () {
    // Consistent bedtime (all 1320 = 04:00-anchored) vs highly variable.
    final consistent = [
      for (var i = 0; i < 20; i++) day(rmssd: 50, rhr: 60, bedtime: 300)
    ];
    final variable = [
      for (var i = 0; i < 20; i++)
        day(rmssd: 50, rhr: 60, bedtime: i.isEven ? 120 : 480)
    ];
    final rC = computeMentalWellness(history: consistent);
    final rV = computeMentalWellness(history: variable);
    expect(rC.produced && rV.produced, isTrue);
    expect(rC.components['circadian']! > rV.components['circadian']!, isTrue);
    expect(rC.score! > rV.score!, isTrue);
  });

  test('label bands and trend vs previous score', () {
    final r = computeMentalWellness(history: flat(20));
    expect(['Balanced', 'Shifted', 'Elevated stress'], contains(r.label));

    // Trend is relative to the previous displayed score.
    final base = computeMentalWellness(history: flat(20));
    final improving =
        computeMentalWellness(history: flat(20), previousScore: base.score! - 20);
    final declining =
        computeMentalWellness(history: flat(20), previousScore: base.score! + 20);
    expect(improving.trend, 'improving');
    expect(declining.trend, 'declining');
  });
}
