import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/scoring/recovery_stability.dart';

/// Behavioural checks on the shipped Recovery engine (the validated drop-in).
/// The Python validation builds its baseline with seeded `random.gauss`, which
/// can't be reproduced in Dart — so rather than pin its exact figures, these
/// assert the engine's documented invariants on deterministic inputs:
///   * a night identical to the baseline scores exactly 50 ("50 = baseline"),
///   * cold-start locks until 4 valid nights,
///   * an invalid (too-short) night refuses,
///   * activity context forgives a dip / caps a euphoric spike (both directions),
///   * sleeping tachypnea (>20 br/min) trips the override.
void main() {
  // A calm, moderate baseline night (matches holistic_proof's centre values).
  RecoveryInput baselineNight({
    double rmssd = 50,
    double hr = 58,
    double resp = 14.5,
    double active = 30,
    double steps = 8000,
  }) =>
      RecoveryInput(
        sleep: SleepSessionLike(
          totalMin: 540,
          deepMin: 95,
          lightMin: 365,
          remMin: 80,
          awakeMin: 8,
          coverageGapMin: 4,
          efficiencyPct: 0.93,
          protocolVersion: 2,
        ),
        metrics: {
          MetricKeys.hrvRmssdMs: rmssd,
          MetricKeys.restingHrBpm: hr,
          MetricKeys.respRateBpm: resp,
          MetricKeys.activeMinutes: active,
          MetricKeys.steps: steps,
          MetricKeys.ppgQualityGate: 1.0,
          MetricKeys.ectopicPct: 2.0,
          MetricKeys.rrIrregularityPct: 5.0,
          MetricKeys.bleLossPct: 3.0,
          MetricKeys.hrvSdnnMs: 46.0,
        },
        ageYears: 40,
      );

  List<RecoveryNightlyRecord> matureBaseline() => [
        for (var i = 0; i < 13; i++)
          reduceNight('base-$i', baselineNight()),
      ];

  test('a night identical to the baseline scores exactly 50', () {
    final history = matureBaseline();
    final tonight = reduceNight('today', baselineNight());
    final r = computeRecovery(
      history: history,
      tonight: tonight,
      bankedValidCount: 13,
      ageYears: 40,
    );
    expect(r.produced, isTrue, reason: r.message);
    expect(r.provisional, isFalse);
    expect(r.score, 50.0); // 50 = exactly your personal baseline
    expect(r.label, 'Moderate');
  });

  test('cold start: <4 valid nights is provisional/calibrating', () {
    final history = [
      reduceNight('b0', baselineNight()),
      reduceNight('b1', baselineNight()),
    ];
    final r = computeRecovery(
      history: history,
      tonight: reduceNight('today', baselineNight()),
      bankedValidCount: 2,
      ageYears: 40,
    );
    expect(r.status, RecoveryStatus.calibrating);
    expect(r.provisional, isTrue);
    expect(r.score, isNotNull); // a provisional number is still shown
  });

  test('an invalid (too-short) night refuses, no score', () {
    final shortNight = RecoveryInput(
      sleep: SleepSessionLike(totalMin: 60, deepMin: 10, lightMin: 40, remMin: 5),
      metrics: const {MetricKeys.hrvRmssdMs: 45.0, MetricKeys.restingHrBpm: 60.0},
      ageYears: 40,
    );
    final r = computeRecovery(
      history: matureBaseline(),
      tonight: reduceNight('today', shortNight),
      bankedValidCount: 13,
      ageYears: 40,
    );
    expect(r.status, RecoveryStatus.invalidNight);
    expect(r.score, isNull);
  });

  test('activity context forgives a dip: hard-training > sedentary', () {
    final history = matureBaseline();
    // Identical suppressed physiology, only the prior day's activity differs.
    RecoveryInput suppressed(double active, double steps) => RecoveryInput(
          sleep: SleepSessionLike(
            totalMin: 520,
            deepMin: 66,
            lightMin: 380,
            remMin: 74,
            awakeMin: 12,
            coverageGapMin: 4,
            efficiencyPct: 0.91,
            protocolVersion: 2,
          ),
          metrics: {
            MetricKeys.hrvRmssdMs: 35.0,
            MetricKeys.restingHrBpm: 62.0,
            MetricKeys.respRateBpm: 14.8,
            MetricKeys.activeMinutes: active,
            MetricKeys.steps: steps,
            MetricKeys.ppgQualityGate: 1.0,
            MetricKeys.hrvSdnnMs: 40.0,
          },
          ageYears: 40,
        );
    final sedentary = computeRecovery(
      history: history,
      tonight: reduceNight('sed', suppressed(5, 1200)),
      bankedValidCount: 13,
      ageYears: 40,
    );
    final hard = computeRecovery(
      history: history,
      tonight: reduceNight('hard', suppressed(120, 18000)),
      bankedValidCount: 13,
      ageYears: 40,
    );
    expect(hard.score! > sedentary.score!, isTrue,
        reason: 'hard ${hard.score} should forgive the dip vs '
            'sedentary ${sedentary.score}');
  });

  test('euphoria cap: high-HRV bounce after a hard day scores lower', () {
    final history = matureBaseline();
    RecoveryInput euphoric(double active, double steps) => RecoveryInput(
          sleep: SleepSessionLike(
            totalMin: 545,
            deepMin: 100,
            lightMin: 365,
            remMin: 80,
            awakeMin: 8,
            coverageGapMin: 4,
            efficiencyPct: 0.94,
            protocolVersion: 2,
          ),
          metrics: {
            MetricKeys.hrvRmssdMs: 72.0,
            MetricKeys.restingHrBpm: 54.0,
            MetricKeys.respRateBpm: 14.2,
            MetricKeys.activeMinutes: active,
            MetricKeys.steps: steps,
            MetricKeys.ppgQualityGate: 1.0,
            MetricKeys.hrvSdnnMs: 60.0,
          },
          ageYears: 40,
        );
    final rested = computeRecovery(
      history: history,
      tonight: reduceNight('eu-rest', euphoric(20, 6000)),
      bankedValidCount: 13,
      ageYears: 40,
    );
    final afterHard = computeRecovery(
      history: history,
      tonight: reduceNight('eu-hard', euphoric(120, 18000)),
      bankedValidCount: 13,
      ageYears: 40,
    );
    expect(afterHard.score! < rested.score!, isTrue,
        reason: 'post-hard euphoric spike should be capped: '
            'afterHard ${afterHard.score} vs rested ${rested.score}');
  });

  test('sleeping tachypnea (>20 br/min) trips the override', () {
    final r = computeRecovery(
      history: matureBaseline(),
      tonight: reduceNight('today', baselineNight(resp: 22.0)),
      bankedValidCount: 13,
      ageYears: 40,
    );
    expect(r.overrideTriggered, isTrue);
  });
}
