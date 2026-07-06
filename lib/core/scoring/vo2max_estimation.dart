// ============================================================================
// vo2max_estimation.dart
//
// On-device aerobic-fitness (VO2 max) estimate for the hlth band.
// Runs once per QUALIFYING exercise session (≥10 min sustained, valid HR),
// triggered after the band's workout summary is synced.
//
//   ALGORITHM A (SHIPPING):  Åstrand-Ryhming submaximal adaptation.
//                            VO2max = (METs / %HRR) · 3.5 · ageCorrection
//                            %HRR from Karvonen (avg HR vs resting/age-max).
//                            METs derived from the band SUMMARY (speed→ACSM,
//                            with a caloric fallback) — the H59 gives no raw
//                            accelerometer, so the guide's Freedson path is
//                            unusable here.
//
//   Algorithm B (Cole HR-recovery) is intentionally NOT implemented: it needs
//   a post-workout 60 s recovery-HR sample the band rarely provides. The
//   per-session estimate is Algorithm A directly; callers show a rolling
//   average over recent qualifying sessions (see [rollingVo2Avg]).
//
// Spec: Transfered Files/Build guide/health-features-build-guide.md:511-664.
// Pure: no I/O, only dart:math. The fitness rating/age norms are a TUNABLE
// assumption (the guide ships no such table) — validate before relying on it.
// ============================================================================

import 'dart:math' as math;

import 'package:hlth_app/core/database/enums.dart' show SexAtBirth;

// SDK sport-type bytes (mirror BleService.sportTypeX). Only the ones whose
// intensity we can defensibly estimate from a summary are listed.
const int _sportWalking = 4;
const int _sportRunning = 7;
const int _sportCycling = 9;
const int _sportHiking = 8;
const int _sportRowing = 27;
const int _sportElliptical = 26;
const int _sportYoga = 22;
const int _sportStrength = 88;

/// Sport types we refuse to score: intensity-from-summary is meaningless for
/// non-aerobic / non-steady work (the %HRR→VO2 relationship doesn't hold).
const Set<int> excludedSportTypes = {_sportYoga, _sportStrength};

enum Vo2Status {
  /// A VO2 max value was produced.
  produced,

  /// The session is valid but we lack the inputs to estimate (no usable
  /// intensity signal, or HR outside the submaximal band).
  insufficientData,

  /// The user profile is missing data the formula requires (age).
  missingProfile,
}

/// How the intensity (METs) input was derived, lowest-to-highest trust.
enum MetsSource { none, caloric, speedWalking, speedRunning }

// ---------------------------------------------------------------------------
// CONFIG — every tunable knob in one place (mirrors VascularLoadConfig).
// ---------------------------------------------------------------------------
class Vo2Config {
  /// Minimum session length to qualify (spec STEP 1: 10+ min sustained).
  final int minDurationSec;

  /// Karvonen %HRR must sit in this submaximal band for Algorithm A to be
  /// valid. Below the floor the activity wasn't intense enough; above the
  /// ceiling we're near-max and the linear %HRR↔%VO2 relation + division
  /// become unstable. (Spec STEP 1 uses a 50% HRR floor; we allow 40% with
  /// no extra penalty since the band's avg HR already smooths bursts.)
  final double minPctHrr;
  final double maxPctHrr;

  /// Speed (m/min) at/above which an ambulatory session is treated as running
  /// rather than walking (~8 km/h). Below → ACSM walking equation.
  final double walkRunSplitMperMin;

  /// Physiological clamps.
  final double metsFloor;
  final double metsCeil;
  final double vo2Floor;
  final double vo2Ceil;

  const Vo2Config({
    this.minDurationSec = 600,
    this.minPctHrr = 0.40,
    this.maxPctHrr = 0.95,
    this.walkRunSplitMperMin = 134.0,
    this.metsFloor = 1.0,
    this.metsCeil = 23.0,
    this.vo2Floor = 15.0,
    this.vo2Ceil = 80.0,
  });
}

// ---------------------------------------------------------------------------
// INPUT — one qualifying session reduced to the fields the formula needs.
// ---------------------------------------------------------------------------
class Vo2SessionInput {
  final int sportType; // SDK byte
  final int durationSec;
  final int distanceM; // 0 if unknown / no GPS
  final double calories; // kcal for the session (0 if unknown)
  final int? avgSpeedCmS; // cm/s (band summary)
  final int? avgHrBpm;
  final int? ageYears;
  final SexAtBirth sex;
  final double? weightKg;
  final int? restingHrBpm; // Karvonen denominator

  const Vo2SessionInput({
    required this.sportType,
    required this.durationSec,
    this.distanceM = 0,
    this.calories = 0,
    this.avgSpeedCmS,
    this.avgHrBpm,
    this.ageYears,
    this.sex = SexAtBirth.unknown,
    this.weightKg,
    this.restingHrBpm,
  });
}

// ---------------------------------------------------------------------------
// RESULT
// ---------------------------------------------------------------------------
class Vo2Result {
  final Vo2Status status;
  final double? vo2maxMl; // mL/kg/min, clamped
  final double confidence; // 0..1
  final double? metsEstimate; // derived intensity (debug / components)
  final MetsSource metsSource;
  final String? activityClass; // 'walking' | 'running' | 'cycling' | 'other'
  final String? rating; // Poor..Superior (null unless produced)
  final int? fitnessAge; // years (null unless produced)
  final String message;

  const Vo2Result({
    required this.status,
    required this.confidence,
    required this.message,
    this.vo2maxMl,
    this.metsEstimate,
    this.metsSource = MetsSource.none,
    this.activityClass,
    this.rating,
    this.fitnessAge,
  });

  factory Vo2Result.fail(Vo2Status status, String message) =>
      Vo2Result(status: status, confidence: 0, message: message);
}

// ===========================================================================
// AGE CORRECTION — Åstrand table (guide lines 545-561), verbatim bands.
// ===========================================================================
double ageCorrection(int age) {
  if (age < 25) return 1.0;
  if (age < 35) return 0.87;
  if (age < 40) return 0.83;
  if (age < 45) return 0.78;
  if (age < 50) return 0.75;
  if (age < 55) return 0.71;
  if (age < 60) return 0.68;
  return 0.65;
}

// ===========================================================================
// METs DERIVATION — no accelerometer, so derive from the band summary.
//   Tier 1 (preferred): speed → ACSM metabolic equations (walking / running).
//   Tier 2 (fallback):  calories → METs (needs body weight). Lower trust:
//                        band kcal is itself HR-derived (mild circularity).
// Returns null when neither tier is computable.
// ===========================================================================
class _Mets {
  final double mets;
  final double confidence;
  final MetsSource source;
  final String activityClass;
  const _Mets(this.mets, this.confidence, this.source, this.activityClass);
}

_Mets? _deriveMets(Vo2SessionInput s, Vo2Config cfg) {
  final durMin = s.durationSec / 60.0;

  // Resolve average speed (m/min) from explicit avg speed or distance/time.
  double? speedMperMin;
  if (s.avgSpeedCmS != null && s.avgSpeedCmS! > 0) {
    speedMperMin = s.avgSpeedCmS! * 0.6; // cm/s → m/min
  } else if (s.distanceM > 0 && s.durationSec > 0) {
    speedMperMin = (s.distanceM / s.durationSec) * 60.0; // m/s → m/min
  }

  final ambulatory = s.sportType == _sportWalking ||
      s.sportType == _sportRunning ||
      s.sportType == _sportHiking;

  // Tier 1 — ACSM speed equations (ambulatory sports with a valid speed).
  if (ambulatory && speedMperMin != null && speedMperMin > 0) {
    final isRunning = s.sportType == _sportRunning ||
        speedMperMin >= cfg.walkRunSplitMperMin;
    // grade = 0: the band summary exposes elevation only for GPS workouts and
    // it isn't threaded into this input; flat-ground is the safe default.
    final vo2 = isRunning
        ? 0.2 * speedMperMin + 3.5 // running, grade 0
        : 0.1 * speedMperMin + 3.5; // walking, grade 0
    final mets = _clamp(vo2 / 3.5, cfg.metsFloor, cfg.metsCeil);
    return isRunning
        ? _Mets(mets, 0.9, MetsSource.speedRunning, 'running')
        : _Mets(mets, 0.75, MetsSource.speedWalking, 'walking');
  }

  // Tier 2 — caloric fallback (any sport, when weight + calories are known).
  if (s.weightKg != null &&
      s.weightKg! > 0 &&
      s.calories > 0 &&
      durMin > 0) {
    // 1 MET ≈ 0.0175 kcal·kg⁻¹·min⁻¹.
    final mets =
        _clamp((s.calories / durMin) / (s.weightKg! * 0.0175), cfg.metsFloor, cfg.metsCeil);
    final cls = s.sportType == _sportCycling
        ? 'cycling'
        : (s.sportType == _sportRowing || s.sportType == _sportElliptical)
            ? 'other'
            : (ambulatory ? 'walking' : 'other');
    return _Mets(mets, 0.5, MetsSource.caloric, cls);
  }

  return null;
}

// ===========================================================================
// ALGORITHM A — the per-session estimate.
// ===========================================================================
Vo2Result computeVo2Max(Vo2SessionInput s, {Vo2Config cfg = const Vo2Config()}) {
  // Profile gate: age is required (Åstrand age correction + max-HR).
  final age = s.ageYears;
  if (age == null || age < 5 || age > 120) {
    return Vo2Result.fail(Vo2Status.missingProfile, 'missing/implausible age');
  }
  if (excludedSportTypes.contains(s.sportType)) {
    return Vo2Result.fail(
        Vo2Status.insufficientData, 'sport type not aerobic-scoreable');
  }
  if (s.durationSec < cfg.minDurationSec) {
    return Vo2Result.fail(Vo2Status.insufficientData,
        'session shorter than ${cfg.minDurationSec ~/ 60} min');
  }

  // Intensity (METs).
  final m = _deriveMets(s, cfg);
  if (m == null) {
    return Vo2Result.fail(Vo2Status.insufficientData,
        'no usable intensity signal (no speed/distance and no weight+calories)');
  }

  // Karvonen %HRR.
  final avgHr = s.avgHrBpm;
  final restHr = s.restingHrBpm;
  if (avgHr == null || avgHr <= 0 || restHr == null || restHr <= 0) {
    return Vo2Result.fail(
        Vo2Status.insufficientData, 'missing avg or resting HR');
  }
  final hrMax = 220 - age;
  final hrReserve = hrMax - restHr;
  if (hrReserve <= 0) {
    return Vo2Result.fail(
        Vo2Status.insufficientData, 'resting HR ≥ age-predicted max HR');
  }
  final pctHrr = (avgHr - restHr) / hrReserve;
  if (pctHrr < cfg.minPctHrr || pctHrr > cfg.maxPctHrr) {
    return Vo2Result.fail(Vo2Status.insufficientData,
        'avg HR outside submaximal band (%HRR=${pctHrr.toStringAsFixed(2)})');
  }

  // VO2max = (METs / %HRR) · 3.5 · ageCorrection, clamped.
  final raw = (m.mets / pctHrr) * 3.5 * ageCorrection(age);
  final vo2 = _clamp(raw, cfg.vo2Floor, cfg.vo2Ceil);

  final fit = fitnessRating(vo2, age, s.sex);
  return Vo2Result(
    status: Vo2Status.produced,
    vo2maxMl: _round1(vo2),
    confidence: m.confidence,
    metsEstimate: _round1(m.mets),
    metsSource: m.source,
    activityClass: m.activityClass,
    rating: fit.rating,
    fitnessAge: fit.fitnessAge,
    message: 'ok (${m.activityClass}, METs ${m.mets.toStringAsFixed(1)}, '
        '%HRR ${pctHrr.toStringAsFixed(2)})',
  );
}

// ===========================================================================
// FITNESS RATING + AGE — TUNABLE norms (not in the guide).
// Median VO2max declines roughly linearly with age from a sex-specific peak.
// rating = user VO2 vs the median for their own age/sex.
// fitnessAge = the age whose median VO2 equals the user's estimate.
// ===========================================================================
class FitnessRating {
  final String rating;
  final int fitnessAge;
  const FitnessRating(this.rating, this.fitnessAge);
}

const double _peakAge = 25.0;

double _medianVo2(int age, SexAtBirth sex) {
  final isMale = sex == SexAtBirth.male;
  final base = isMale ? 48.0 : 38.0; // median at age 25
  final decline = isMale ? 0.38 : 0.32; // mL/kg/min per year
  final a = age < _peakAge ? _peakAge : age.toDouble();
  return math.max(15.0, base - decline * (a - _peakAge));
}

FitnessRating fitnessRating(double vo2, int age, SexAtBirth sex) {
  final median = _medianVo2(age, sex);
  final ratio = vo2 / median;
  final String rating;
  if (ratio < 0.85) {
    rating = 'Poor';
  } else if (ratio < 0.95) {
    rating = 'Fair';
  } else if (ratio < 1.10) {
    rating = 'Good';
  } else if (ratio < 1.25) {
    rating = 'Excellent';
  } else {
    rating = 'Superior';
  }

  // Invert the median curve: fitnessAge such that median(age) == vo2.
  final isMale = sex == SexAtBirth.male;
  final base = isMale ? 48.0 : 38.0;
  final decline = isMale ? 0.38 : 0.32;
  final inverted = _peakAge + (base - vo2) / decline;
  final fitnessAge = _clamp(inverted, 18, 90).round();
  return FitnessRating(rating, fitnessAge);
}

// ===========================================================================
// ROLLING AVERAGE — what the daily fitness Score / card headline shows.
// Confidence-weighted mean of recent per-session estimates within a window.
// Pure: the caller supplies [asOf] (no DateTime.now() in the engine).
// ===========================================================================
class Vo2Sample {
  final DateTime at;
  final double vo2;
  final double confidence;
  const Vo2Sample({required this.at, required this.vo2, this.confidence = 1.0});
}

double? rollingVo2Avg(
  List<Vo2Sample> samples, {
  required DateTime asOf,
  int windowDays = 7,
}) {
  final cutoff = asOf.subtract(Duration(days: windowDays));
  final inWindow = samples
      .where((s) => !s.at.isBefore(cutoff) && !s.at.isAfter(asOf))
      .toList();
  if (inWindow.isEmpty) return null;
  var wsum = 0.0;
  var w = 0.0;
  for (final s in inWindow) {
    final c = s.confidence <= 0 ? 0.0 : s.confidence;
    wsum += s.vo2 * c;
    w += c;
  }
  if (w <= 0) {
    // All zero-confidence — fall back to a plain mean so we still show a value.
    final mean = inWindow.map((s) => s.vo2).reduce((a, b) => a + b) /
        inWindow.length;
    return _round1(mean);
  }
  return _round1(wsum / w);
}

// ── helpers ────────────────────────────────────────────────────────────────
double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double _round1(double v) => (v * 10).roundToDouble() / 10;
