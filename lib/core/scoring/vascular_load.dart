// Vendored verbatim from Ryan's vascular_load.dart (2026-06-23 delivery).
// Source of truth — do NOT edit logic; only this ignore header is added.
// ignore_for_file: unused_element, prefer_null_aware_operators
// ============================================================================
// vascular_load.dart
//
// On-device Vascular Load metric for the hlth band (WHOOP-style).
// Runs ONCE DAILY, triggered by the end-of-sleep event on wake.
//
//   ENGINE A (v1, SHIPPING):  cardiovascular-stress proxy from signals we trust
//                             - sleeping HR trough (5th percentile)
//                             - sleeping HRV (median RMSSD over deep-sleep epochs)
//                             - stored stress (nightly mean)
//                             Normalised to the user's own rolling baseline.
//                             Single 0-100 score + trend. No fake sub-scores.
//
//   ENGINE B (v1.5, SHADOW):  true PPG morphology (Stiffness/Augmentation/
//                             Reflection indices) from an ensemble-averaged
//                             pulse. PROVEN not trustworthy at 25 Hz (only ~3
//                             samples span the systolic->diastolic interval;
//                             diastolic-peak SNR ~0.5). Runs behind a feature
//                             flag, LOGS ONLY, until the 100 Hz sensor lands.
//
// Validated logic-for-logic against engine_a.py / morph_feasibility.py.
// Weights and floors are starting values; tune on real multi-night data.
// ============================================================================

import 'dart:math' as math;

// ---------------------------------------------------------------------------
// SLEEP STAGES (band already produces full staging)
// ---------------------------------------------------------------------------
enum SleepStage { deep, light, rem, wake }

// ---------------------------------------------------------------------------
// PER-EPOCH INPUT for one sleep session (e.g. 1-minute epochs).
// All lists must be the same length. These come from the device's stored
// session metrics; no raw PPG is needed by Engine A.
// ---------------------------------------------------------------------------
class SleepEpochs {
  final List<double> hr;          // sleeping HR per epoch (bpm)
  final List<double> rmssd;       // RMSSD per epoch (ms) - already timing-fixed
  final List<SleepStage> stage;   // stage per epoch
  final List<bool> motion;        // true = movement in this epoch (gate it out)
  final List<double> stress;      // stored stress per epoch (0..100)
  final double epochMinutes;      // minutes per epoch (e.g. 1.0)

  SleepEpochs({
    required this.hr,
    required this.rmssd,
    required this.stage,
    required this.motion,
    required this.stress,
    this.epochMinutes = 1.0,
  });

  int get length => hr.length;
}

// ---------------------------------------------------------------------------
// NIGHTLY RECORD - the tiny struct persisted on-device between sessions.
// One per sleep session. The daily score reads tonight + previous 3 valid.
// ---------------------------------------------------------------------------
class NightlyRecord {
  final String date;          // local sleep date, e.g. "2026-06-24"
  final double hrP5;          // 5th-percentile sleeping HR (bpm) - the trough
  final double rmssdMedian;   // median RMSSD over deep-sleep, motion-free epochs
  final double stressMean;    // mean stored stress over asleep epochs
  final double coverage;      // fraction of session with valid signal (0..1)
  final bool valid;           // passed min-sleep + min-coverage + finite signals

  const NightlyRecord({
    required this.date,
    required this.hrP5,
    required this.rmssdMedian,
    required this.stressMean,
    required this.coverage,
    required this.valid,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'hrP5': hrP5,
        'rmssdMedian': rmssdMedian,
        'stressMean': stressMean,
        'coverage': coverage,
        'valid': valid,
      };

  factory NightlyRecord.fromJson(Map<String, dynamic> j) => NightlyRecord(
        date: j['date'] as String,
        hrP5: (j['hrP5'] as num).toDouble(),
        rmssdMedian: (j['rmssdMedian'] as num).toDouble(),
        stressMean: (j['stressMean'] as num).toDouble(),
        coverage: (j['coverage'] as num).toDouble(),
        valid: j['valid'] as bool,
      );

  static const NightlyRecord invalidNight = NightlyRecord(
    date: '', hrP5: double.nan, rmssdMedian: double.nan,
    stressMean: double.nan, coverage: 0, valid: false,
  );
}

// ===========================================================================
// 1) NIGHTLY REDUCTION:  SleepEpochs -> NightlyRecord
//    HR  -> 5th-percentile over asleep, non-motion epochs (the cardiac trough)
//    HRV -> median RMSSD over DEEP-sleep, motion-free epochs (stable sleep);
//           falls back to all asleep+non-motion if too little deep sleep
//    Stress -> mean over asleep epochs
// ===========================================================================
class VascularLoadConfig {
  final double minSleepHours;   // night must have at least this much sleep
  final double minCoverage;     // fraction of session that must be valid
  const VascularLoadConfig({this.minSleepHours = 3.0, this.minCoverage = 0.5});
}

NightlyRecord reduceSession(
  String date,
  SleepEpochs e, {
  VascularLoadConfig cfg = const VascularLoadConfig(),
}) {
  final n = e.length;
  if (n == 0) return NightlyRecord.invalidNight;

  // asleep mask
  final asleep = List<bool>.generate(n, (i) => e.stage[i] != SleepStage.wake);
  final asleepCount = asleep.where((b) => b).length;
  final sleepHours = asleepCount * e.epochMinutes / 60.0;
  final coverage = asleepCount / n;

  // HR trough: 5th percentile over asleep, non-motion, finite epochs
  final hrVals = <double>[];
  for (var i = 0; i < n; i++) {
    if (asleep[i] && !e.motion[i] && e.hr[i].isFinite) hrVals.add(e.hr[i]);
  }
  final hrP5 = hrVals.length >= 10 ? _percentile(hrVals, 5) : double.nan;

  // HRV: median RMSSD over deep-sleep, motion-free epochs (stable sleep)
  final deepRmssd = <double>[];
  for (var i = 0; i < n; i++) {
    if (e.stage[i] == SleepStage.deep && !e.motion[i] && e.rmssd[i].isFinite) {
      deepRmssd.add(e.rmssd[i]);
    }
  }
  double rmssdMedian;
  if (deepRmssd.length >= 5) {
    rmssdMedian = _median(deepRmssd);
  } else {
    final fb = <double>[];
    for (var i = 0; i < n; i++) {
      if (asleep[i] && !e.motion[i] && e.rmssd[i].isFinite) fb.add(e.rmssd[i]);
    }
    rmssdMedian = fb.length >= 5 ? _median(fb) : double.nan;
  }

  // Stress: mean over asleep epochs
  final stressVals = <double>[];
  for (var i = 0; i < n; i++) {
    if (asleep[i] && e.stress[i].isFinite) stressVals.add(e.stress[i]);
  }
  final stressMean =
      stressVals.length >= 5 ? _mean(stressVals) : double.nan;

  final valid = sleepHours >= cfg.minSleepHours &&
      coverage >= cfg.minCoverage &&
      hrP5.isFinite &&
      rmssdMedian.isFinite;

  return NightlyRecord(
    date: date,
    hrP5: hrP5,
    rmssdMedian: rmssdMedian,
    stressMean: stressMean,
    coverage: coverage,
    valid: valid,
  );
}

// ===========================================================================
// 2) THE DAILY SCORE (Engine A)
// ===========================================================================

// Weights: HR and HRV are the validated cardiovascular signals; stress supports.
const double _wHr = 0.4;
const double _wHrv = 0.4;
const double _wStress = 0.2;
const double _scale = 15.0; // maps the z-blend onto +/- points around 50

// Physiological night-to-night noise floors. With only 3 baseline nights the
// sample IQR can collapse toward 0 and make a normal fluctuation look enormous
// (this was a real bug caught in validation). Never divide by a spread smaller
// than the real biological variability of each metric, and clamp each z.
// TUNE THESE ON REAL DATA.
const double _floorHr = 3.0;     // bpm  (sleeping trough HR ~3 bpm/night)
const double _floorRmssd = 8.0;  // ms   (RMSSD night-to-night ~8 ms)
const double _floorStress = 6.0; // pts  (stress index ~6 pts)
const double _zClamp = 3.0;      // cap each signal at +/-3 'normal nights'

// Scoring-model knobs (TUNE ON REAL DATA).
// The 4-night window (tonight + previous 3 valid) is combined into one
// 'current value' with last night weighted a little extra. This makes the
// metric a calm trend that still responds to a genuinely bad night.
//   0.25 = all four nights equal (most stable, Samsung-like)
//   0.40 = a little extra on last night (default; calm-with-a-nudge)
//   higher = more reactive
const double _lastNightWeight = 0.40;
const int _windowN = 4;        // tonight + previous 3 valid
const int _baselineMax = 14;   // rolling personal baseline (grows from >=3)

double _robustZ(double x, List<double> ref, double floor) {
  final r = ref.where((v) => v.isFinite).toList();
  if (r.length < 2 || !x.isFinite) return 0.0;
  final med = _median(r);
  final iqr = _percentile(r, 75) - _percentile(r, 25);
  final spread = math.max(math.max(iqr, _std(r)), floor);
  final z = (x - med) / spread;
  return z.clamp(-_zClamp, _zClamp).toDouble();
}

/// One night's vascular-load value in robust-z units vs the [baseline].
/// Higher = more vascular stress. Combines HR(+), HRV(-), stress(+).
double _nightLoad(NightlyRecord r, List<NightlyRecord> baseline) {
  final zHr =
      _robustZ(r.hrP5, baseline.map((b) => b.hrP5).toList(), _floorHr);
  final zHrv = _robustZ(
      r.rmssdMedian, baseline.map((b) => b.rmssdMedian).toList(), _floorRmssd);
  final zStress = _robustZ(
      r.stressMean, baseline.map((b) => b.stressMean).toList(), _floorStress);
  return _wHr * zHr - _wHrv * zHrv + _wStress * zStress;
}

enum VlStatus { calibrating, noData, produced }

class VascularLoadResult {
  final VlStatus status;
  final String message;       // user-facing reason / context
  final double? score;        // 0..100, 50 = personal baseline
  final String? label;        // Lower than usual / Normal / Higher than usual
  final String? trend;        // below baseline / stable / elevated vs baseline
  final Map<String, double> components;

  const VascularLoadResult({
    required this.status,
    this.message = '',
    this.score,
    this.label,
    this.trend,
    this.components = const {},
  });

  bool get produced => status == VlStatus.produced;
}

/// Compute the daily Vascular Load score.
///
/// [history]            previous NightlyRecords, most recent LAST.
/// [tonight]            tonight's NightlyRecord (the trigger session).
/// [bankedValidCount]   total valid wear-with-sleep nights recorded so far,
///                      NOT counting tonight. Drives the cold-start lock.
///
/// Model: today's value = the 4-night window (tonight + previous 3 valid)
/// combined with last night weighted a little extra (_lastNightWeight),
/// scored against the rolling up-to-14-night personal baseline. Calm trend
/// that still responds to a genuinely bad night.
///
/// Cold start: locked until 4 valid nights are banked; the first score is
/// produced on the 5th qualifying wear. Sleeps need not be consecutive, but
/// a valid sleep last night is mandatory (no wear last night -> no score).
VascularLoadResult computeVascularLoad({
  required List<NightlyRecord> history,
  required NightlyRecord tonight,
  required int bankedValidCount,
}) {
  // mandatory: valid sleep last night
  if (!tonight.valid) {
    return const VascularLoadResult(
      status: VlStatus.noData,
      message: 'No valid sleep last night - no score today.',
    );
  }
  // cold start
  if (bankedValidCount < 4) {
    final need = 4 - bankedValidCount;
    return VascularLoadResult(
      status: VlStatus.calibrating,
      message:
          'Calibrating - $need more sleep${need == 1 ? '' : 's'} needed before your score unlocks.',
    );
  }

  final prevValid = history.where((r) => r.valid).toList();
  if (prevValid.length < 3) {
    return const VascularLoadResult(
      status: VlStatus.noData,
      message: 'Need 3 prior valid nights in the history window.',
    );
  }

  // Ingredient 2: personal yardstick = rolling up-to-14 valid nights.
  // Grows from whatever valid nights exist (min 3) until 14 accumulate.
  final baseline = prevValid.length > _baselineMax
      ? prevValid.sublist(prevValid.length - _baselineMax)
      : prevValid;

  // Ingredient 1: the 4-night window = previous 3 valid + tonight.
  final prior3 = prevValid.sublist(prevValid.length - (_windowN - 1));
  final window = <NightlyRecord>[...prior3, tonight]; // length 4, tonight last

  // per-night load values vs the baseline
  final loads = window.map((r) => _nightLoad(r, baseline)).toList();
  final lastNightLoad = loads.last;

  // weighted aggregate: last night gets _lastNightWeight; the other 3 share
  // the remainder equally. 0.25 => all four equal.
  final others = (1 - _lastNightWeight) / (loads.length - 1);
  double current = 0;
  for (var i = 0; i < loads.length; i++) {
    current += (i == loads.length - 1 ? _lastNightWeight : others) * loads[i];
  }

  final score = (50 + _scale * current).clamp(0, 100).toDouble();

  // tonight's component z's (for debug/telemetry)
  final zHr =
      _robustZ(tonight.hrP5, baseline.map((r) => r.hrP5).toList(), _floorHr);
  final zHrv = _robustZ(tonight.rmssdMedian,
      baseline.map((r) => r.rmssdMedian).toList(), _floorRmssd);
  final zStress = _robustZ(tonight.stressMean,
      baseline.map((r) => r.stressMean).toList(), _floorStress);

  String label;
  if (score >= 65) {
    label = 'Higher than usual';
  } else if (score <= 35) {
    label = 'Lower than usual';
  } else {
    label = 'Normal';
  }

  String trend = 'stable';
  if (score >= 60) {
    trend = 'elevated vs baseline';
  } else if (score <= 40) {
    trend = 'below baseline';
  }

  return VascularLoadResult(
    status: VlStatus.produced,
    message: 'ok',
    score: double.parse(score.toStringAsFixed(1)),
    label: label,
    trend: trend,
    components: {
      'zHr': double.parse(zHr.toStringAsFixed(2)),
      'zHrv': double.parse(zHrv.toStringAsFixed(2)),
      'zStress': double.parse(zStress.toStringAsFixed(2)),
      'currentLoad': double.parse(current.toStringAsFixed(3)),
      'lastNightLoad': double.parse(lastNightLoad.toStringAsFixed(3)),
      'windowN': loads.length.toDouble(),
      'baselineN': baseline.length.toDouble(),
    },
  );
}

// ===========================================================================
// 3) ENGINE B - MORPHOLOGY (v1.5), SHADOW MODE ONLY
//    Feature-flagged OFF for the user-facing score. When enabled it builds an
//    ensemble-averaged pulse and logs the dicrotic-notch / diastolic-peak SNR
//    so we accumulate evidence. At 25 Hz the diastolic peak is NOT resolvable
//    (SNR ~0.5); expected to become reliable at 100 Hz.
//    Reuses refinePeakTimesSubSample() from the ectopic file for beat alignment.
// ===========================================================================
class MorphologyShadowResult {
  final bool resolvable;        // did notch+diastolic clear the SNR bar?
  final double notchSnr;
  final double diastolicSnr;
  final double? stiffnessIndex; // only meaningful if resolvable
  final double? reflectionIndex;
  final int beatsUsed;
  const MorphologyShadowResult({
    required this.resolvable,
    required this.notchSnr,
    required this.diastolicSnr,
    required this.beatsUsed,
    this.stiffnessIndex,
    this.reflectionIndex,
  });
}

/// Feature flag. KEEP FALSE until the 100 Hz sensor (v1.5) is in hardware.
const bool kEnableMorphologyShadow = false;

/// Placeholder hook. Wire to the IR ensemble-pulse builder when v1.5 lands.
/// Returns null when the flag is off so it never touches the user score.
MorphologyShadowResult? runMorphologyShadow(/* IR pulse buffers */) {
  if (!kEnableMorphologyShadow) return null;
  // TODO(v1.5): build ensemble pulse via refinePeakTimesSubSample alignment,
  // locate notch/diastolic on the mean pulse, compute SNR, SI=h/dT, RI.
  // Log result; do NOT feed into computeVascularLoad until validated at 100 Hz.
  return null;
}

// ===========================================================================
// MATH HELPERS (no external deps)
// ===========================================================================
double _mean(List<double> x) =>
    x.isEmpty ? double.nan : x.reduce((a, b) => a + b) / x.length;

double _std(List<double> x) {
  if (x.length < 2) return 0.0;
  final m = _mean(x);
  final v = x.map((e) => (e - m) * (e - m)).reduce((a, b) => a + b) / x.length;
  return math.sqrt(v);
}

double _median(List<double> x) => _percentile(x, 50);

/// Linear-interpolated percentile (p in 0..100). Matches numpy default.
double _percentile(List<double> xIn, double p) {
  if (xIn.isEmpty) return double.nan;
  final x = List<double>.from(xIn)..sort();
  if (x.length == 1) return x.first;
  final rank = (p / 100.0) * (x.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return x[lo];
  final frac = rank - lo;
  return x[lo] * (1 - frac) + x[hi] * frac;
}

// ===========================================================================
// INTEGRATION NOTES
// ===========================================================================
//
// DAILY FLOW (on the end-of-sleep / wake trigger):
//   1. final epochs = loadStoredSleepEpochs(lastSession);   // device storage
//   2. final tonight = reduceSession(todayDate, epochs);
//   3. final history = loadNightlyRecords();                // previous records
//   4. final banked  = history.where((r) => r.valid).length;
//   5. final result  = computeVascularLoad(
//          history: history, tonight: tonight, bankedValidCount: banked);
//   6. persist: appendNightlyRecord(tonight);               // becomes history
//   7. if (result.produced) showScore(result); else showState(result.message);
//
// WHAT THE DEVICE STORES BETWEEN SESSIONS:
//   - a rolling list of NightlyRecord (keep last ~14; score uses previous 3 valid)
//   - NO raw PPG waveforms. Each night is the tiny struct above.
//
// COLD START / TRIGGER (encoded in computeVascularLoad):
//   - locked until 4 valid nights banked; first score on the 5th wear
//   - sleeps need NOT be consecutive
//   - valid sleep LAST NIGHT is mandatory; otherwise no score that day
//   - each score uses tonight + previous 3 valid nights (last night weighted
//     a little extra) measured against the rolling up-to-14-night baseline
//
// TUNING TODO (on real multi-night data):
//   - weights _wHr/_wHrv/_wStress
//   - noise floors _floorHr/_floorRmssd/_floorStress
//   - label thresholds (65/35) and trend thresholds (60/40)
//
// DEFERRED TO v1.5 (do not ship in v1):
//   - Engine B morphology (SI/AI/RI) - not trustworthy at 25 Hz
//   - pulsatile/resistive sub-score split
//   - SpO2 as an input (and FIX RED-LED CLIPPING first: red railed at 65535)
