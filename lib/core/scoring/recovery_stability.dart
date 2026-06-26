// ignore_for_file: unused_element, prefer_null_aware_operators
// ^ Vendored, validated engine (parity-checked against the Python reference);
//   kept verbatim. The two lints above are from the upstream source.
// ============================================================================
// recovery_stability.dart  (v2 - CORRECT ARCHITECTURE)
//
// On-device Recovery / Stability score (0-100) for the hlth wearable app.
// Runs ONCE DAILY, triggered by the end-of-sleep event on wake.
//
// This is a LINE-FOR-LINE port of recovery_stability_reference.py (the source
// of truth). Validate the Python first; verify this Dart via _parity_check.py.
//
// WHAT CHANGED FROM v1
//   v1 was a single-night scorer (wrong architecture). v2 mirrors the SHIPPING
//   Vascular Load engine (vascular_load.dart):
//     * a tiny per-night RecoveryNightlyRecord persisted on-device (aggregates
//       only, NO raw PPG waveforms stored),
//     * a 4-NIGHT WEIGHTED WINDOW (tonight + previous 3 valid), last night
//       weighted extra (_lastNightWeight = 0.50; knobs 0.40 / 0.60),
//     * a rolling personal baseline of the last <=14 WORN-VALID sleeps (grows
//       from >=3, caps at 14 - NOT 14 calendar days),
//     * robust-z deviations with biological noise floors + z-clamp,
//     * graceful cold-start (provisional below maturity).
//
// HOLISTIC DESIGN
//   Activity/accelerometer context is NOT just an epoch gate. It SHIFTS the
//   EXPECTED autonomic baseline in BOTH directions: a hard training day
//   FORGIVES a HRV/deep dip (expected after load) AND CAPS a euphoric spike
//   (vagal rebound != recovery); a sedentary day scores the same dip as a real
//   red flag. The SAME physiology -> a DIFFERENT score by activity context.
//
// HRV / PPG SEMANTICS (evidence-grounded)
//   RMSSD DRIVES the score (preferred field-recovery HRV metric). SDNN,
//   ectopic%, R-R CoV%, quality-gate, ble_loss% are CONFIDENCE / artifact
//   inputs only (RMSSD is most meaningful but most fragile). LF/HF is TELEMETRY
//   ONLY - never a score component (invalid as a sympathovagal index; aliases
//   under the slow breathing of sleep).
//
//   Weights and floors are starting values; tune on real multi-night data.
// ============================================================================

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// SDK AGGREGATE METRIC KEYS (exact keys the SDK emits)
// ---------------------------------------------------------------------------
class MetricKeys {
  static const hrvRmssdMs = 'hrv_rmssd_ms';
  static const restingHrBpm = 'resting_hr_bpm';
  static const respRateBpm = 'resp_rate_bpm';
  static const sleepTotalMin = 'sleep_total_min';
  static const sleepEfficiencyPct = 'sleep_efficiency_pct';
  static const steps = 'steps';
  static const activeMinutes = 'active_minutes';
  static const caloriesKcal = 'calories_kcal'; // NOT scored
  static const distanceM = 'distance_m'; // NOT scored
  // richer PPG-derived fields (CONFIDENCE / artifact rejection only)
  static const hrvSdnnMs = 'hrv_sdnn_ms';
  static const hrvPnn50Pct = 'hrv_pnn50_pct';
  static const hrvLfHf = 'hrv_lf_hf'; // TELEMETRY ONLY - never scored
  static const rrIrregularityPct = 'rr_irregularity_pct';
  static const ectopicPct = 'ectopic_pct';
  static const ppgQualityGate = 'ppg_quality_gate'; // 1.0 PASS / 0.0 FAIL
  static const bleLossPct = 'ble_loss_pct';
}

// ---------------------------------------------------------------------------
// ADAPTER TYPES (positional enums match the DB ints)
// ---------------------------------------------------------------------------
enum SleepStageLike { awake, light, deep, rem, noSleep, unweared } // 0..5
enum SleepSessionTypeLike { night, nap } // 0,1

class SleepSessionLike {
  final int totalMin;
  final int deepMin, lightMin, remMin, awakeMin;
  final int coverageGapMin;
  final double? efficiencyPct; // 0..1 in real data; 0..100 tolerated
  final bool hasUnweared;
  final int protocolVersion; // 1 = no REM, 2 = REM-capable
  final SleepSessionTypeLike type;
  final bool hasStageDetail;

  SleepSessionLike({
    required this.totalMin,
    this.deepMin = 0,
    this.lightMin = 0,
    this.remMin = 0,
    this.awakeMin = 0,
    this.coverageGapMin = 0,
    this.efficiencyPct,
    this.hasUnweared = false,
    this.protocolVersion = 2,
    this.type = SleepSessionTypeLike.night,
    this.hasStageDetail = true,
  });

  bool get remAvailable => protocolVersion >= 2 && hasStageDetail;
}

// ---------------------------------------------------------------------------
// CONFIG
// ---------------------------------------------------------------------------
class RecoveryConfig {
  // Fixed component weights (must sum to 1.0)
  final double wDeep, wRem, wHrv, wHr, wResp;

  // 4-night weighted window
  final double lastNightWeight; // 0.50 default
  final double lastNightWeightLow; // 0.40 knob
  final double lastNightWeightHigh; // 0.60 knob
  final int windowN; // 4

  // Rolling baseline
  final int baselineWindowMax; // 14
  final int baselineMinNights; // 3

  // Maturity / cold-start
  final int minValidNightsForScore; // 4

  // Night validity gates
  final int minSleepMin;
  final double minEfficiencyPct;
  final double maxCoverageGapFrac;

  // Score bounds
  final double hardFloor, hardCeiling, singleNightCeiling;
  final int consecutiveNightsForFullCeiling;

  // Robust noise floors + z-clamp
  final double zClamp;
  final double lnRmssdMadFloor;
  final double hrNoiseFloorBpm;
  final double respNoiseFloorBpm;
  final double deepMinFloor;
  final double remPctFloor;

  // Component scaling
  final double deepZScale, remZScale, hrvZScale, hrZScale, respZScale;
  final double hrvScoreFloor, hrvScoreCeil;

  // Cold-start anchors
  final double deepCold5059, deepCold6069, deepCold70, deepColdDefault;
  final double remPctCold5069, remPctCold70, remPctColdDefault;
  final double lnRmssdCold5059, lnRmssdCold6069, lnRmssdCold70, lnRmssdColdDefault;
  final double restingHrColdDefault, respRateColdDefault;

  // Age accommodations
  final int deepAgeFloorAge;
  final double deepAgeFloorScore;
  final double hrvElderlyCapAge, hrvElderlyCapScore, hrvElderlyCapZ;
  final double betaBlockerBaselineShift, betaBlockerMinHrComponent;

  // Rebound caps
  final double deepReboundRatio, deepReboundCapScore;
  final double remReboundRatio, remReboundCapScore;

  // Activity-adjusted expectations (both directions)
  final bool enableActivityModifier;
  final double activityNoiseFloorMin;
  final double activityStepsFloor;
  final double activityExpectationShift;
  final double activityEuphoriaCapFrac;
  final double activityHardZ;

  // Sleep regularity
  final double bedtimeSdThresholdMin, bedtimeSdPenalty;

  // Joint penalty
  final double jointDeepRemPenalty, bottomQuartileScore;

  // Multi-signal decline override
  final int badNightLowComponents;
  final double lowComponentThreshold, respTachypneaBpm;

  // Asymmetric smoothing
  final double emaAlphaUp, emaAlphaDown;

  // Confidence
  final double confidencePerMissingCore;
  final double ectopicWarnPct, ectopicRejectPct;
  final double rrIrregularityWarnPct, rrIrregularityRejectPct;
  final double bleLossWarnPct, sdnnRmssdDivergence;

  const RecoveryConfig({
    this.wDeep = 0.30,
    this.wRem = 0.20,
    this.wHrv = 0.20,
    this.wHr = 0.15,
    this.wResp = 0.15,
    this.lastNightWeight = 0.50,
    this.lastNightWeightLow = 0.40,
    this.lastNightWeightHigh = 0.60,
    this.windowN = 4,
    this.baselineWindowMax = 14,
    this.baselineMinNights = 3,
    this.minValidNightsForScore = 4,
    this.minSleepMin = 180,
    this.minEfficiencyPct = 0.50,
    this.maxCoverageGapFrac = 0.50,
    this.hardFloor = 8,
    this.hardCeiling = 96,
    this.singleNightCeiling = 85,
    this.consecutiveNightsForFullCeiling = 3,
    this.zClamp = 3.0,
    this.lnRmssdMadFloor = 0.10,
    this.hrNoiseFloorBpm = 3.0,
    this.respNoiseFloorBpm = 1.0,
    this.deepMinFloor = 8.0,
    this.remPctFloor = 2.5,
    this.deepZScale = 15.0,
    this.remZScale = 15.0,
    this.hrvZScale = 15.0,
    this.hrZScale = 15.0,
    this.respZScale = 12.0,
    this.hrvScoreFloor = 5,
    this.hrvScoreCeil = 95,
    this.deepCold5059 = 70.0,
    this.deepCold6069 = 50.0,
    this.deepCold70 = 38.0,
    this.deepColdDefault = 75.0,
    this.remPctCold5069 = 20.0,
    this.remPctCold70 = 18.0,
    this.remPctColdDefault = 20.0,
    this.lnRmssdCold5059 = 3.47,
    this.lnRmssdCold6069 = 3.09,
    this.lnRmssdCold70 = 2.71,
    this.lnRmssdColdDefault = 3.30,
    this.restingHrColdDefault = 60.0,
    this.respRateColdDefault = 16.0,
    this.deepAgeFloorAge = 65,
    this.deepAgeFloorScore = 30,
    this.hrvElderlyCapAge = 65,
    this.hrvElderlyCapScore = 85,
    this.hrvElderlyCapZ = 2.5,
    this.betaBlockerBaselineShift = 12,
    this.betaBlockerMinHrComponent = 40,
    this.deepReboundRatio = 1.4,
    this.deepReboundCapScore = 75,
    this.remReboundRatio = 1.5,
    this.remReboundCapScore = 75,
    this.enableActivityModifier = true,
    this.activityNoiseFloorMin = 10.0,
    this.activityStepsFloor = 1500.0,
    this.activityExpectationShift = 0.45,
    this.activityEuphoriaCapFrac = 0.50,
    this.activityHardZ = 0.75,
    this.bedtimeSdThresholdMin = 90,
    this.bedtimeSdPenalty = 5,
    this.jointDeepRemPenalty = 5,
    this.bottomQuartileScore = 35,
    this.badNightLowComponents = 3,
    this.lowComponentThreshold = 35.0,
    this.respTachypneaBpm = 20.0,
    this.emaAlphaUp = 0.30,
    this.emaAlphaDown = 0.25,
    this.confidencePerMissingCore = 0.18,
    this.ectopicWarnPct = 5.0,
    this.ectopicRejectPct = 15.0,
    this.rrIrregularityWarnPct = 8.0,
    this.rrIrregularityRejectPct = 20.0,
    this.bleLossWarnPct = 10.0,
    this.sdnnRmssdDivergence = 0.60,
  });
}

// ---------------------------------------------------------------------------
// NIGHTLY RECORD - the tiny struct persisted on-device between sessions.
// NO raw PPG waveforms stored.
// ---------------------------------------------------------------------------
class RecoveryNightlyRecord {
  final String date;
  final double deepMin;
  final double remPct;
  final double lnRmssd;
  final double restingHr;
  final double respRate;
  final double activityLoad;
  final double activitySteps;
  final bool remAvailable;
  final double confidence;
  final double coverage;
  final bool valid;

  const RecoveryNightlyRecord({
    required this.date,
    required this.deepMin,
    required this.remPct,
    required this.lnRmssd,
    required this.restingHr,
    required this.respRate,
    required this.activityLoad,
    required this.activitySteps,
    required this.remAvailable,
    required this.confidence,
    required this.coverage,
    required this.valid,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'deepMin': deepMin,
        'remPct': remPct,
        'lnRmssd': lnRmssd,
        'restingHr': restingHr,
        'respRate': respRate,
        'activityLoad': activityLoad,
        'activitySteps': activitySteps,
        'remAvailable': remAvailable,
        'confidence': confidence,
        'coverage': coverage,
        'valid': valid,
      };

  factory RecoveryNightlyRecord.fromJson(Map<String, dynamic> j) =>
      RecoveryNightlyRecord(
        date: j['date'] as String,
        deepMin: (j['deepMin'] as num).toDouble(),
        remPct: (j['remPct'] as num).toDouble(),
        lnRmssd: (j['lnRmssd'] as num).toDouble(),
        restingHr: (j['restingHr'] as num).toDouble(),
        respRate: (j['respRate'] as num).toDouble(),
        activityLoad: (j['activityLoad'] as num).toDouble(),
        activitySteps: (j['activitySteps'] as num).toDouble(),
        remAvailable: j['remAvailable'] as bool,
        confidence: (j['confidence'] as num).toDouble(),
        coverage: (j['coverage'] as num).toDouble(),
        valid: j['valid'] as bool,
      );

  static const RecoveryNightlyRecord invalid = RecoveryNightlyRecord(
    date: '',
    deepMin: double.nan,
    remPct: double.nan,
    lnRmssd: double.nan,
    restingHr: double.nan,
    respRate: double.nan,
    activityLoad: double.nan,
    activitySteps: double.nan,
    remAvailable: false,
    confidence: 0.0,
    coverage: 0.0,
    valid: false,
  );
}

// ---------------------------------------------------------------------------
// INPUT / RESULT
// ---------------------------------------------------------------------------
class RecoveryInput {
  final SleepSessionLike sleep;
  final Map<String, double?> metrics;
  final int? ageYears;
  final bool betaBlocker;

  RecoveryInput({
    required this.sleep,
    required this.metrics,
    this.ageYears,
    this.betaBlocker = false,
  });

  double? metric(String key) {
    final v = metrics[key];
    return v == null ? null : v.toDouble();
  }
}

class RecoveryComponentBreakdown {
  final String name;
  final double score;
  final double weight;
  final bool available;
  final String note;
  const RecoveryComponentBreakdown(
      this.name, this.score, this.weight, this.available,
      [this.note = '']);
  double get weighted => score * weight;
}

enum RecoveryStatus { produced, invalidNight, noData, calibrating } // 0..3

class RecoveryResult {
  final RecoveryStatus status;
  final String message;
  final double? rawScore;
  final double? score;
  final String? label;
  final double confidence;
  final bool overrideTriggered;
  final bool provisional;
  final Map<String, RecoveryComponentBreakdown> components;
  final Map<String, dynamic> debug;
  const RecoveryResult({
    required this.status,
    this.message = '',
    this.rawScore,
    this.score,
    this.label,
    this.confidence = 0.0,
    this.overrideTriggered = false,
    this.provisional = false,
    this.components = const {},
    this.debug = const {},
  });
  bool get produced => status == RecoveryStatus.produced;
}

// ===========================================================================
// MATH HELPERS (mirror the Python reference / vascular_load.dart exactly)
// ===========================================================================
double _clamp(double x, double lo, double hi) => math.max(lo, math.min(hi, x));
double _round1(double x) => (x * 10).round() / 10;
double _round2(double x) => (x * 100).round() / 100;

double _mean(List<double> xIn) {
  final x = xIn.where((v) => v.isFinite).toList();
  if (x.isEmpty) return double.nan;
  return x.reduce((a, b) => a + b) / x.length;
}

double _std(List<double> xIn) {
  final x = xIn.where((v) => v.isFinite).toList();
  if (x.length < 2) return 0.0;
  final m = x.reduce((a, b) => a + b) / x.length;
  final v = x.map((e) => (e - m) * (e - m)).reduce((a, b) => a + b) / x.length;
  return math.sqrt(v);
}

double _percentile(List<double> xIn, double p) {
  final x = xIn.where((v) => v.isFinite).toList()..sort();
  if (x.isEmpty) return double.nan;
  if (x.length == 1) return x.first;
  final rank = (p / 100.0) * (x.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return x[lo];
  final frac = rank - lo;
  return x[lo] * (1 - frac) + x[hi] * frac;
}

double _median(List<double> x) => _percentile(x, 50);

double _robustZ(double x, List<double> ref, double floor, double zClamp) {
  final r = ref.where((v) => v.isFinite).toList();
  if (r.length < 2 || !x.isFinite) return 0.0;
  final med = _median(r);
  final iqr = _percentile(r, 75) - _percentile(r, 25);
  final spread = math.max(math.max(iqr, _std(r)), floor);
  final z = (x - med) / spread;
  return _clamp(z, -zClamp, zClamp);
}

// ===========================================================================
// 1) NIGHTLY REDUCTION:  RecoveryInput -> RecoveryNightlyRecord
// ===========================================================================
RecoveryNightlyRecord reduceNight(String date, RecoveryInput inp,
    {RecoveryConfig cfg = const RecoveryConfig()}) {
  final s = inp.sleep;
  if (s.type == SleepSessionTypeLike.nap) return RecoveryNightlyRecord.invalid;

  final windowMin = s.totalMin + s.awakeMin + s.coverageGapMin;
  final coverageGapFrac = windowMin > 0 ? s.coverageGapMin / windowMin : 1.0;
  final coverage = 1.0 - coverageGapFrac;
  final effPct = (s.efficiencyPct != null && s.efficiencyPct! > 1.5)
      ? s.efficiencyPct! / 100.0
      : s.efficiencyPct;

  final valid = s.totalMin >= cfg.minSleepMin &&
      coverageGapFrac <= cfg.maxCoverageGapFrac &&
      (effPct == null || effPct >= cfg.minEfficiencyPct);

  final deepMin = s.hasStageDetail ? s.deepMin.toDouble() : double.nan;
  final remPct = (s.remAvailable && s.totalMin > 0)
      ? s.remMin / s.totalMin * 100.0
      : double.nan;

  final rmssd = inp.metric(MetricKeys.hrvRmssdMs);
  final lnRmssd = (rmssd != null && rmssd > 0) ? math.log(rmssd) : double.nan;

  final hr = inp.metric(MetricKeys.restingHrBpm);
  final restingHr = (hr != null && hr > 0) ? hr : double.nan;

  final rr = inp.metric(MetricKeys.respRateBpm);
  final respRate = (rr != null && rr > 0) ? rr : double.nan;

  final active = inp.metric(MetricKeys.activeMinutes);
  final activityLoad = active ?? double.nan;
  final steps = inp.metric(MetricKeys.steps);
  final activitySteps = steps ?? double.nan;

  final confidence = _nightlyConfidence(inp, s, coverageGapFrac, cfg);

  return RecoveryNightlyRecord(
    date: date,
    deepMin: deepMin,
    remPct: remPct,
    lnRmssd: lnRmssd,
    restingHr: restingHr,
    respRate: respRate,
    activityLoad: activityLoad,
    activitySteps: activitySteps,
    remAvailable: s.remAvailable,
    confidence: confidence,
    coverage: coverage,
    valid: valid,
  );
}

double _nightlyConfidence(RecoveryInput inp, SleepSessionLike s,
    double coverageGapFrac, RecoveryConfig cfg) {
  var conf = 1.0;
  if (s.hasUnweared) conf *= 0.9;
  if (coverageGapFrac > 0.2) conf *= 0.9;

  final gate = inp.metric(MetricKeys.ppgQualityGate);
  if (gate != null && gate < 0.5) conf *= 0.5;

  final ect = inp.metric(MetricKeys.ectopicPct);
  if (ect != null) {
    if (ect >= cfg.ectopicRejectPct) {
      conf *= 0.4;
    } else if (ect >= cfg.ectopicWarnPct) {
      conf *= 0.8;
    }
  }

  final irr = inp.metric(MetricKeys.rrIrregularityPct);
  if (irr != null) {
    if (irr >= cfg.rrIrregularityRejectPct) {
      conf *= 0.5;
    } else if (irr >= cfg.rrIrregularityWarnPct) {
      conf *= 0.85;
    }
  }

  final ble = inp.metric(MetricKeys.bleLossPct);
  if (ble != null && ble >= cfg.bleLossWarnPct) conf *= 0.9;

  final rmssd = inp.metric(MetricKeys.hrvRmssdMs);
  final sdnn = inp.metric(MetricKeys.hrvSdnnMs);
  if (rmssd != null && sdnn != null && rmssd > 0 && sdnn > 0) {
    if ((math.log(sdnn) - math.log(rmssd)).abs() > cfg.sdnnRmssdDivergence) {
      conf *= 0.85;
    }
  }

  return _clamp(conf, 0.0, 1.0);
}

// ===========================================================================
// 2) ROLLING BASELINE (last <=14 WORN-VALID sleeps)
// ===========================================================================
class RecoveryBaseline {
  final double? deepMinMedian, remPctMedian, lnRmssdMedian;
  final double? restingHrMedian, respRateMedian;
  final double? activityLoadMedian, activityStepsMedian;
  final List<double> deepRef, remRef, lnRmssdRef, hrRef, respRef;
  final List<double> activityRef, activityStepsRef;
  final int nNights;
  const RecoveryBaseline({
    this.deepMinMedian,
    this.remPctMedian,
    this.lnRmssdMedian,
    this.restingHrMedian,
    this.respRateMedian,
    this.activityLoadMedian,
    this.activityStepsMedian,
    this.deepRef = const [],
    this.remRef = const [],
    this.lnRmssdRef = const [],
    this.hrRef = const [],
    this.respRef = const [],
    this.activityRef = const [],
    this.activityStepsRef = const [],
    this.nNights = 0,
  });
}

RecoveryBaseline buildBaseline(List<RecoveryNightlyRecord> history,
    {RecoveryConfig cfg = const RecoveryConfig()}) {
  final valid = history.where((r) => r.valid).toList();
  final window = valid.length > cfg.baselineWindowMax
      ? valid.sublist(valid.length - cfg.baselineWindowMax)
      : valid;

  List<double> col(double Function(RecoveryNightlyRecord) g) =>
      window.map(g).where((v) => v.isFinite).toList();

  final deepRef = col((r) => r.deepMin);
  final remRef = col((r) => r.remPct);
  final lnRef = col((r) => r.lnRmssd);
  final hrRef = col((r) => r.restingHr);
  final respRef = col((r) => r.respRate);
  final actRef = col((r) => r.activityLoad);
  final stepsRef = col((r) => r.activitySteps);

  double? medOrNull(List<double> xs) => xs.isNotEmpty ? _median(xs) : null;

  return RecoveryBaseline(
    deepMinMedian: medOrNull(deepRef),
    remPctMedian: medOrNull(remRef),
    lnRmssdMedian: medOrNull(lnRef),
    restingHrMedian: medOrNull(hrRef),
    respRateMedian: medOrNull(respRef),
    activityLoadMedian: medOrNull(actRef),
    activityStepsMedian: medOrNull(stepsRef),
    deepRef: deepRef,
    remRef: remRef,
    lnRmssdRef: lnRef,
    hrRef: hrRef,
    respRef: respRef,
    activityRef: actRef,
    activityStepsRef: stepsRef,
    nNights: window.length,
  );
}

// ===========================================================================
// 3) ACTIVITY LOAD (personal-relative robust-z; both-direction expectation)
// ===========================================================================
double _activityLoadZ(
    RecoveryNightlyRecord r, RecoveryBaseline b, RecoveryConfig cfg) {
  if (r.activityLoad.isFinite && b.activityRef.length >= 2) {
    return _robustZ(r.activityLoad, b.activityRef, cfg.activityNoiseFloorMin,
        cfg.zClamp);
  }
  if (r.activitySteps.isFinite && b.activityStepsRef.length >= 2) {
    return _robustZ(r.activitySteps, b.activityStepsRef, cfg.activityStepsFloor,
        cfg.zClamp);
  }
  return 0.0;
}

double _activityAdjustZ(double signalZ, double activityZ,
    {required bool higherIsBetter, required RecoveryConfig cfg}) {
  if (!cfg.enableActivityModifier || activityZ <= 0) return signalZ;
  if (signalZ < 0) {
    final forgiven = signalZ + cfg.activityExpectationShift * activityZ;
    return math.min(forgiven, 0.0);
  }
  if (activityZ >= cfg.activityHardZ) {
    return signalZ * cfg.activityEuphoriaCapFrac;
  }
  return signalZ;
}

// ===========================================================================
// COLD-START ANCHORS
// ===========================================================================
double _deepCold(int? age, RecoveryConfig cfg) {
  if (age == null) return cfg.deepColdDefault;
  if (age >= 70) return cfg.deepCold70;
  if (age >= 60) return cfg.deepCold6069;
  if (age >= 50) return cfg.deepCold5059;
  return cfg.deepColdDefault;
}

double _remCold(int? age, RecoveryConfig cfg) {
  if (age == null) return cfg.remPctColdDefault;
  if (age >= 70) return cfg.remPctCold70;
  return cfg.remPctCold5069;
}

double _lnRmssdCold(int? age, RecoveryConfig cfg) {
  if (age == null) return cfg.lnRmssdColdDefault;
  if (age >= 70) return cfg.lnRmssdCold70;
  if (age >= 60) return cfg.lnRmssdCold6069;
  if (age >= 50) return cfg.lnRmssdCold5059;
  return cfg.lnRmssdColdDefault;
}

// ===========================================================================
// 4) PER-NIGHT COMPONENT SCORES (robust-z vs baseline, activity-adjusted)
// ===========================================================================
RecoveryComponentBreakdown _scoreDeep(RecoveryNightlyRecord r,
    RecoveryBaseline b, int? age, double activityZ, RecoveryConfig cfg) {
  if (!r.deepMin.isFinite) {
    return RecoveryComponentBreakdown(
        'deep', 50, cfg.wDeep, false, 'no stage detail (weight redistributed)');
  }
  double z;
  String refNote;
  if (b.deepRef.length >= 2) {
    z = _robustZ(r.deepMin, b.deepRef, cfg.deepMinFloor, cfg.zClamp);
    refNote = 'baseline ${b.deepMinMedian!.toStringAsFixed(0)}m (n=${b.deepRef.length})';
  } else {
    final ref = _deepCold(age, cfg);
    z = ref > 0
        ? _clamp((r.deepMin - ref) / cfg.deepColdDefault * 3.0, -cfg.zClamp, cfg.zClamp)
        : 0.0;
    refNote = 'cold-start ${ref.toStringAsFixed(0)}m';
  }
  z = _activityAdjustZ(z, activityZ, higherIsBetter: true, cfg: cfg);
  var score = _clamp(50 + z * cfg.deepZScale, 0, 100);
  if (b.deepMinMedian != null &&
      b.deepMinMedian! > 0 &&
      r.deepMin > b.deepMinMedian! * cfg.deepReboundRatio) {
    score = math.min(score, cfg.deepReboundCapScore);
  }
  if (age != null && age >= cfg.deepAgeFloorAge && score < cfg.deepAgeFloorScore) {
    score = cfg.deepAgeFloorScore;
    refNote += ' (age floor)';
  }
  return RecoveryComponentBreakdown('deep', score, cfg.wDeep, true,
      'deep ${r.deepMin.toStringAsFixed(0)}m vs $refNote z=${z.toStringAsFixed(2)}');
}

RecoveryComponentBreakdown _scoreRem(RecoveryNightlyRecord r,
    RecoveryBaseline b, int? age, double activityZ, RecoveryConfig cfg) {
  if (!r.remAvailable || !r.remPct.isFinite) {
    return RecoveryComponentBreakdown(
        'rem', 50, cfg.wRem, false, 'REM not measured (weight redistributed)');
  }
  double z;
  String refNote;
  if (b.remRef.length >= 2) {
    z = _robustZ(r.remPct, b.remRef, cfg.remPctFloor, cfg.zClamp);
    refNote = 'baseline ${b.remPctMedian!.toStringAsFixed(1)}% (n=${b.remRef.length})';
  } else {
    final ref = _remCold(age, cfg);
    z = _clamp((r.remPct - ref) / cfg.remPctFloor, -cfg.zClamp, cfg.zClamp);
    refNote = 'cold-start ${ref.toStringAsFixed(1)}%';
  }
  z = _activityAdjustZ(z, activityZ, higherIsBetter: true, cfg: cfg);
  var score = _clamp(50 + z * cfg.remZScale, 0, 100);
  if (b.remPctMedian != null &&
      b.remPctMedian! > 0 &&
      r.remPct > b.remPctMedian! * cfg.remReboundRatio) {
    score = math.min(score, cfg.remReboundCapScore);
  }
  return RecoveryComponentBreakdown('rem', score, cfg.wRem, true,
      'REM ${r.remPct.toStringAsFixed(1)}% vs $refNote z=${z.toStringAsFixed(2)}');
}

RecoveryComponentBreakdown _scoreHrv(RecoveryNightlyRecord r,
    RecoveryBaseline b, int? age, double activityZ, RecoveryConfig cfg) {
  if (!r.lnRmssd.isFinite) {
    return RecoveryComponentBreakdown(
        'hrv', 50, cfg.wHrv, false, 'RMSSD missing (weight redistributed)');
  }
  double z;
  String refNote;
  if (b.lnRmssdRef.length >= 2) {
    final med = b.lnRmssdMedian!;
    final absDev = b.lnRmssdRef.map((v) => (v - med).abs()).toList();
    final mad = math.max(_median(absDev), cfg.lnRmssdMadFloor);
    z = _clamp((r.lnRmssd - med) / (1.4826 * mad), -cfg.zClamp, cfg.zClamp);
    refNote = 'baseline lnRMSSD ${med.toStringAsFixed(2)} (n=${b.lnRmssdRef.length})';
  } else {
    final med = _lnRmssdCold(age, cfg);
    final mad = cfg.lnRmssdMadFloor;
    z = _clamp((r.lnRmssd - med) / (1.4826 * mad), -cfg.zClamp, cfg.zClamp);
    refNote = 'cold-start lnRMSSD ${med.toStringAsFixed(2)}';
  }
  z = _activityAdjustZ(z, activityZ, higherIsBetter: true, cfg: cfg);
  var score = _clamp(50 + z * cfg.hrvZScale, cfg.hrvScoreFloor, cfg.hrvScoreCeil);
  if (age != null && age >= cfg.hrvElderlyCapAge && z > cfg.hrvElderlyCapZ) {
    score = math.min(score, cfg.hrvElderlyCapScore);
    refNote += ' (elderly high-HRV cap)';
  }
  return RecoveryComponentBreakdown('hrv', score, cfg.wHrv, true,
      'RMSSD z=${z.toStringAsFixed(2)} vs $refNote');
}

RecoveryComponentBreakdown _scoreRestingHr(RecoveryNightlyRecord r,
    RecoveryBaseline b, bool betaBlocker, double activityZ, RecoveryConfig cfg) {
  if (!r.restingHr.isFinite) {
    return RecoveryComponentBreakdown(
        'hr', 50, cfg.wHr, false, 'resting HR missing (weight redistributed)');
  }
  double zRaw;
  String refNote;
  if (b.hrRef.length >= 2) {
    zRaw = _robustZ(r.restingHr, b.hrRef, cfg.hrNoiseFloorBpm, cfg.zClamp);
    refNote = 'baseline ${b.restingHrMedian!.toStringAsFixed(0)}bpm (n=${b.hrRef.length})';
  } else {
    var ref = cfg.restingHrColdDefault;
    if (betaBlocker) ref -= cfg.betaBlockerBaselineShift;
    zRaw = _clamp((r.restingHr - ref) / cfg.hrNoiseFloorBpm, -cfg.zClamp, cfg.zClamp);
    refNote = 'cold-start ${ref.toStringAsFixed(0)}bpm';
  }
  var z = -zRaw; // lower HR = better
  z = _activityAdjustZ(z, activityZ, higherIsBetter: true, cfg: cfg);
  var score = _clamp(50 + z * cfg.hrZScale, 0, 100);
  if (betaBlocker && z >= 0) {
    score = math.max(score, cfg.betaBlockerMinHrComponent);
  }
  return RecoveryComponentBreakdown('hr', score, cfg.wHr, true,
      'HR ${r.restingHr.toStringAsFixed(0)}bpm vs $refNote z=${z.toStringAsFixed(2)}');
}

RecoveryComponentBreakdown _scoreResp(
    RecoveryNightlyRecord r, RecoveryBaseline b, RecoveryConfig cfg) {
  if (!r.respRate.isFinite) {
    return RecoveryComponentBreakdown(
        'resp', 50, cfg.wResp, false, 'resp rate missing (weight redistributed)');
  }
  double zRaw;
  String refNote;
  if (b.respRef.length >= 2) {
    zRaw = _robustZ(r.respRate, b.respRef, cfg.respNoiseFloorBpm, cfg.zClamp);
    refNote = 'baseline ${b.respRateMedian!.toStringAsFixed(1)} (n=${b.respRef.length})';
  } else {
    final ref = cfg.respRateColdDefault;
    zRaw = _clamp((r.respRate - ref) / cfg.respNoiseFloorBpm, -cfg.zClamp, cfg.zClamp);
    refNote = 'cold-start ${ref.toStringAsFixed(1)}';
  }
  final z = -zRaw; // elevated resp = worse; NOT activity-adjusted
  final score = _clamp(50 + z * cfg.respZScale, 0, 100);
  return RecoveryComponentBreakdown('resp', score, cfg.wResp, true,
      'RR ${r.respRate.toStringAsFixed(1)} vs $refNote z=${z.toStringAsFixed(2)}');
}

// ===========================================================================
// SMOOTHING
// ===========================================================================
double smoothRecoveryScore(double raw, double? previousDisplayed,
    RecoveryConfig cfg, bool forceRaw) {
  if (previousDisplayed == null || forceRaw) return raw;
  final delta = raw - previousDisplayed;
  final alpha = delta >= 0 ? cfg.emaAlphaUp : cfg.emaAlphaDown;
  return previousDisplayed + alpha * delta;
}

// ===========================================================================
// 5) THE DAILY SCORE - computeRecovery(history, tonight, bankedValidCount)
// ===========================================================================
RecoveryResult computeRecovery({
  required List<RecoveryNightlyRecord> history,
  required RecoveryNightlyRecord tonight,
  required int bankedValidCount,
  int? ageYears,
  bool betaBlocker = false,
  double? previousDisplayedScore,
  int consecutiveAboveMedianNights = 0,
  double? bedtimeSdMin7d,
  double? lastNightWeight,
  RecoveryConfig cfg = const RecoveryConfig(),
}) {
  final wLast = lastNightWeight ?? cfg.lastNightWeight;

  if (!tonight.valid) {
    return const RecoveryResult(
      status: RecoveryStatus.invalidNight,
      message: 'No valid sleep last night - no Recovery score today.',
    );
  }

  final prevValid = history.where((r) => r.valid).toList();
  final provisional = bankedValidCount < cfg.minValidNightsForScore;
  final base = buildBaseline(history, cfg: cfg);

  // assemble the 4-night window: previous (windowN-1) valid + tonight
  final prior = prevValid.length >= (cfg.windowN - 1)
      ? prevValid.sublist(prevValid.length - (cfg.windowN - 1))
      : prevValid;
  final window = <RecoveryNightlyRecord>[...prior, tonight];

  // per-night composite (returns null composite if no signals)
  ({double? composite, Map<String, RecoveryComponentBreakdown> eff, double actZ})
      nightComposite(RecoveryNightlyRecord r) {
    final actZ = _activityLoadZ(r, base, cfg);
    final deep = _scoreDeep(r, base, ageYears, actZ, cfg);
    final rem = _scoreRem(r, base, ageYears, actZ, cfg);
    final hrv = _scoreHrv(r, base, ageYears, actZ, cfg);
    final hr = _scoreRestingHr(r, base, betaBlocker, actZ, cfg);
    final resp = _scoreResp(r, base, cfg);
    final comps = [deep, rem, hrv, hr, resp];
    final avail = comps.where((c) => c.available).toList();
    if (avail.isEmpty) return (composite: null, eff: {}, actZ: actZ);
    final wsum = avail.map((c) => c.weight).reduce((a, b) => a + b);
    var composite = 0.0;
    final eff = <String, RecoveryComponentBreakdown>{};
    for (final c in comps) {
      final e = c.available ? c.weight / wsum : 0.0;
      eff[c.name] =
          RecoveryComponentBreakdown(c.name, c.score, e, c.available, c.note);
      if (c.available) composite += c.score * e;
    }
    if (eff['deep']!.available &&
        eff['rem']!.available &&
        eff['deep']!.score <= cfg.bottomQuartileScore &&
        eff['rem']!.score <= cfg.bottomQuartileScore) {
      composite -= cfg.jointDeepRemPenalty;
    }
    return (composite: composite, eff: eff, actZ: actZ);
  }

  final nightScores = <double>[];
  for (final r in window) {
    final nc = nightComposite(r);
    nightScores.add(nc.composite ?? 50.0);
  }

  final tonightNc = nightComposite(tonight);
  if (tonightNc.composite == null) {
    return const RecoveryResult(
      status: RecoveryStatus.noData,
      message: 'No trustworthy recovery signals last night.',
      confidence: 0,
    );
  }
  final tonightComps = tonightNc.eff;

  // 4-night weighted blend: last night = wLast; others share remainder
  final n = nightScores.length;
  double windowed;
  if (n == 1) {
    windowed = nightScores[0];
  } else {
    final others = (1 - wLast) / (n - 1);
    windowed = 0.0;
    for (var i = 0; i < n; i++) {
      windowed += (i == n - 1 ? wLast : others) * nightScores[i];
    }
  }

  if ((bedtimeSdMin7d ?? 0) > cfg.bedtimeSdThresholdMin) {
    windowed -= cfg.bedtimeSdPenalty;
  }

  final ceiling = consecutiveAboveMedianNights >= cfg.consecutiveNightsForFullCeiling
      ? cfg.hardCeiling
      : math.min(cfg.singleNightCeiling, cfg.hardCeiling);
  final rawScore = _clamp(windowed, cfg.hardFloor, ceiling);

  final availTonight = tonightComps.values.where((c) => c.available).toList();
  final lowCount =
      availTonight.where((c) => c.score <= cfg.lowComponentThreshold).length;
  final respOverride =
      tonight.respRate.isFinite && tonight.respRate > cfg.respTachypneaBpm;
  final overrideTriggered =
      (lowCount >= cfg.badNightLowComponents) || respOverride;

  final smoothed = smoothRecoveryScore(
      rawScore, previousDisplayedScore, cfg, overrideTriggered);
  final finalScore = _clamp(smoothed, cfg.hardFloor, ceiling);

  final missingCore = tonightComps.values.where((c) => !c.available).length;
  var confidence =
      _clamp(1.0 - missingCore * cfg.confidencePerMissingCore, 0.0, 1.0);
  confidence *= tonight.confidence;
  if (provisional) confidence *= 0.8;

  var status = RecoveryStatus.produced;
  var message = 'ok';
  if (bankedValidCount < cfg.minValidNightsForScore) {
    final need = cfg.minValidNightsForScore - bankedValidCount;
    status = RecoveryStatus.calibrating;
    message = 'Calibrating - $need more valid night${need == 1 ? '' : 's'} '
        'before your baseline matures; score shown is provisional.';
  } else if (prevValid.length < (cfg.windowN - 1)) {
    message = 'Provisional - only ${prevValid.length} prior valid night(s); '
        'window not yet full.';
  }

  return RecoveryResult(
    status: status,
    message: message,
    rawScore: _round1(rawScore),
    score: _round1(finalScore),
    label: _label(finalScore),
    confidence: _round2(confidence),
    overrideTriggered: overrideTriggered,
    provisional: provisional,
    components: tonightComps,
    debug: {
      'windowed': _round2(windowed),
      'window_n': n.toDouble(),
      'baseline_n': base.nNights.toDouble(),
      'last_night_weight': wLast,
      'tonight_composite': _round2(tonightNc.composite!),
      'tonight_activity_z': _round2(tonightNc.actZ),
      'night_scores': nightScores.map(_round1).toList(),
    },
  );
}

String _label(double s) {
  if (s >= 75) return 'Excellent';
  if (s >= 60) return 'Good';
  if (s >= 40) return 'Moderate';
  return 'Low';
}

// ===========================================================================
// DAILY FLOW (on the end-of-sleep / wake trigger):
//   1. final tonight = reduceNight(date, RecoveryInput(sleep, metrics, ...));
//   2. final history = loadNightlyRecords();
//   3. final banked  = history.where((r) => r.valid).length;
//   4. final result  = computeRecovery(history: history, tonight: tonight,
//          bankedValidCount: banked, ageYears: ..., ...);
//   5. persist: appendNightlyRecord(tonight);
//   6. if (result.produced) showScore(result); else showState(result.message);
//
// WHAT THE DEVICE STORES BETWEEN SESSIONS:
//   - a rolling list of RecoveryNightlyRecord (keep last ~14)
//   - NO raw PPG waveforms. Raw PPG is read at capture for the richer HRV /
//     confidence fields, then reduced to the tiny struct above.
//
// TUNING TODO (on real multi-night data):
//   - lastNightWeight (0.40 / 0.50 / 0.60 knobs), component weights
//   - noise floors, z-clamp, activityExpectationShift / euphoriaCapFrac
//   - label thresholds (75/60/40)
// ===========================================================================
