import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/scoring/vo2max_estimation.dart';

/// Behavioural checks on the Algorithm-A VO2 max engine. Values are
/// hand-computed from the Åstrand-Ryhming adaptation in the build guide
/// (VO2max = METs/%HRR · 3.5 · ageCorrection), with METs derived from the
/// band summary via the ACSM speed equations / caloric fallback.
void main() {
  Vo2SessionInput input({
    int sportType = 7, // running
    int durationSec = 1800,
    int distanceM = 0,
    double calories = 0,
    int? avgSpeedCmS,
    int? avgHrBpm = 150,
    int? ageYears = 30,
    SexAtBirth sex = SexAtBirth.male,
    double? weightKg,
    int? restingHrBpm = 60,
  }) =>
      Vo2SessionInput(
        sportType: sportType,
        durationSec: durationSec,
        distanceM: distanceM,
        calories: calories,
        avgSpeedCmS: avgSpeedCmS,
        avgHrBpm: avgHrBpm,
        ageYears: ageYears,
        sex: sex,
        weightKg: weightKg,
        restingHrBpm: restingHrBpm,
      );

  group('Algorithm A core', () {
    test('known running session lands near hand-computed VO2', () {
      // speed 250 cm/s = 150 m/min → run VO2=0.2·150+3.5=33.5 → 9.57 METs.
      // %HRR=(150-60)/(190-60)=0.6923. age 30 corr 0.87.
      // (9.57/0.6923)·3.5·0.87 ≈ 42.1 mL/kg/min.
      final r = computeVo2Max(input(avgSpeedCmS: 250));
      expect(r.status, Vo2Status.produced);
      expect(r.activityClass, 'running');
      expect(r.vo2maxMl, closeTo(42.1, 0.4));
      expect(r.confidence, 0.9);
    });
  });

  group('ageCorrection table boundaries (guide verbatim)', () {
    test('band edges', () {
      expect(ageCorrection(24), 1.0);
      expect(ageCorrection(25), 0.87);
      expect(ageCorrection(34), 0.87);
      expect(ageCorrection(35), 0.83);
      expect(ageCorrection(39), 0.83);
      expect(ageCorrection(40), 0.78);
      expect(ageCorrection(49), 0.75);
      expect(ageCorrection(50), 0.71);
      expect(ageCorrection(59), 0.68);
      expect(ageCorrection(60), 0.65);
      expect(ageCorrection(80), 0.65);
    });
  });

  group('METs derivation tiers', () {
    test('walking ACSM ~3 METs at 4 km/h', () {
      // 4 km/h = 66.7 m/min → walk VO2=0.1·66.7+3.5=10.2 → 2.9 METs.
      final r = computeVo2Max(
          input(sportType: 4, avgSpeedCmS: 111, avgHrBpm: 120));
      expect(r.status, Vo2Status.produced);
      expect(r.activityClass, 'walking');
      expect(r.metsEstimate, closeTo(2.9, 0.2));
      expect(r.metsSource, MetsSource.speedWalking);
      expect(r.confidence, 0.75);
    });

    test('running ACSM ~10.5 METs at 10 km/h', () {
      // 10 km/h = 166.7 m/min → run VO2=0.2·166.7+3.5=36.8 → 10.5 METs.
      final r = computeVo2Max(input(avgSpeedCmS: 278));
      expect(r.activityClass, 'running');
      expect(r.metsEstimate, closeTo(10.5, 0.3));
    });

    test('caloric fallback when no speed (cycling)', () {
      // 300 kcal / 30 min / (70·0.0175) = 10/1.225 = 8.16 METs.
      final r = computeVo2Max(input(
        sportType: 9, // cycling — not ambulatory, no speed
        calories: 300,
        weightKg: 70,
        avgHrBpm: 140,
      ));
      expect(r.status, Vo2Status.produced);
      expect(r.metsSource, MetsSource.caloric);
      expect(r.activityClass, 'cycling');
      expect(r.metsEstimate, closeTo(8.2, 0.2));
      expect(r.confidence, 0.5);
    });

    test('METs clamp ceiling holds', () {
      // Absurd speed → METs clamps at 23.
      final r = computeVo2Max(input(avgSpeedCmS: 5000, avgHrBpm: 150));
      if (r.status == Vo2Status.produced) {
        expect(r.metsEstimate! <= 23.0, isTrue);
      }
    });
  });

  group('guard rails', () {
    test('%HRR below floor → insufficientData', () {
      // avgHr 100 → (100-60)/130 = 0.31 < 0.40.
      final r = computeVo2Max(input(sportType: 4, avgSpeedCmS: 111, avgHrBpm: 100));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('%HRR above ceiling → insufficientData', () {
      // avgHr 188 → (188-60)/130 = 0.98 > 0.95.
      final r = computeVo2Max(input(avgSpeedCmS: 250, avgHrBpm: 188));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('resting HR ≥ max HR → insufficientData', () {
      final r = computeVo2Max(input(avgSpeedCmS: 250, restingHrBpm: 200));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('missing age → missingProfile', () {
      final r = computeVo2Max(input(avgSpeedCmS: 250, ageYears: null));
      expect(r.status, Vo2Status.missingProfile);
    });

    test('excluded sport (yoga) → insufficientData', () {
      final r = computeVo2Max(input(sportType: 22, avgSpeedCmS: 250));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('short session → insufficientData', () {
      final r = computeVo2Max(input(durationSec: 300, avgSpeedCmS: 250));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('no speed and no weight → insufficientData', () {
      final r = computeVo2Max(input(sportType: 9, avgHrBpm: 140));
      expect(r.status, Vo2Status.insufficientData);
    });

    test('missing HR → insufficientData', () {
      final r = computeVo2Max(input(avgSpeedCmS: 250, avgHrBpm: null));
      expect(r.status, Vo2Status.insufficientData);
    });
  });

  group('fitness rating + fitness age', () {
    test('at-median male → Good, fitnessAge ≈ chronological', () {
      final f = fitnessRating(48.0, 25, SexAtBirth.male);
      expect(f.rating, 'Good');
      expect(f.fitnessAge, closeTo(25, 1));
    });

    test('well above median → Superior, younger fitness age', () {
      final f = fitnessRating(60.0, 25, SexAtBirth.male);
      expect(f.rating, 'Superior');
      expect(f.fitnessAge, lessThan(25));
    });

    test('well below median → Poor, older fitness age', () {
      final f = fitnessRating(30.0, 25, SexAtBirth.male);
      expect(f.rating, 'Poor');
      expect(f.fitnessAge, greaterThan(25));
    });

    test('female norm differs from male at same VO2', () {
      // 40 vs female median 38 (age 25) → ratio ~1.05 → Good.
      final f = fitnessRating(40.0, 25, SexAtBirth.female);
      expect(f.rating, 'Good');
    });
  });

  group('rollingVo2Avg', () {
    final asOf = DateTime.utc(2026, 6, 30);

    test('only samples within the window count', () {
      final avg = rollingVo2Avg([
        Vo2Sample(at: asOf.subtract(const Duration(days: 1)), vo2: 40),
        Vo2Sample(at: asOf.subtract(const Duration(days: 3)), vo2: 50),
        Vo2Sample(at: asOf.subtract(const Duration(days: 10)), vo2: 30),
      ], asOf: asOf, windowDays: 7);
      expect(avg, 45.0);
    });

    test('confidence-weighted mean', () {
      final avg = rollingVo2Avg([
        Vo2Sample(
            at: asOf.subtract(const Duration(days: 1)), vo2: 40, confidence: 0.5),
        Vo2Sample(
            at: asOf.subtract(const Duration(days: 2)), vo2: 50, confidence: 1.5),
      ], asOf: asOf);
      // (40·0.5 + 50·1.5)/2.0 = 95/2 = 47.5.
      expect(avg, 47.5);
    });

    test('empty / all-out-of-window → null', () {
      expect(rollingVo2Avg([], asOf: asOf), isNull);
      expect(
        rollingVo2Avg([
          Vo2Sample(at: asOf.subtract(const Duration(days: 30)), vo2: 40),
        ], asOf: asOf, windowDays: 7),
        isNull,
      );
    });

    test('all zero-confidence falls back to plain mean', () {
      final avg = rollingVo2Avg([
        Vo2Sample(at: asOf.subtract(const Duration(days: 1)), vo2: 40, confidence: 0),
        Vo2Sample(at: asOf.subtract(const Duration(days: 2)), vo2: 50, confidence: 0),
      ], asOf: asOf);
      expect(avg, 45.0);
    });
  });
}
