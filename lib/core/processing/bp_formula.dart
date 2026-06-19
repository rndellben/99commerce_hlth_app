/// Port of the QRing SDK's `CalcBloodPressureByHeart` to Dart.
///
/// Source: decompiled from `classes.jar` →
/// `com.oudmon.ble.base.util.CalcBloodPressureByHeart`.
///
/// The original is a deterministic linear model (despite using
/// `Math.random` for tiny jitter); we drop the randomness so a given
/// (hr, age, calibration) tuple always returns the same value — that
/// makes UI and history predictable.
///
/// The model has two modes:
///
///   * **Uncalibrated** — no cuff baseline written yet. SBP is an
///     age-bracket default offset (`AGE_BP_COF`) anchored at the lower
///     of `MIN_SBP / MAX_SBP`, then adjusted by `(hr − HR_LOWER) × 0.45`.
///   * **Calibrated** — once the user enters a cuff reading at HR `H₀`,
///     the model stores `(last_sbp = cuff_sbp, last_hr = H₀)` and every
///     future reading drifts linearly: `sbp = last_sbp + (hr − H₀) × 0.45`.
///
/// DBP is just `sbp − ~37 mmHg` per the SDK's `MIN_BP_DIFF` constant.
/// The jitter range `[MIN_BP_DIFF, MAX_BP_DIFF] = [37, 43]` produces an
/// average gap of 40 mmHg, which matches typical resting BP ratios.
class BpFormula {
  // Constants ported verbatim from CalcBloodPressureByHeart static init.
  static const int minBpDiff = 37;
  static const int maxBpDiff = 43;
  static const int maxSbp = 120;
  static const int minSbp = 100;
  static const int hrUpper = 85;
  static const int hrLower = 65;
  static const double hrBpRate = 0.45; // mmHg per bpm
  static const int hrDefault = 80;
  static const int ageDefault = 25;

  // Age brackets — values are upper bounds; index into AGE_BP_COF.
  static const List<int> _ageBuckets = [20, 30, 40, 50, 60];
  static const List<int> _ageBpCoefficient = [-10, 5, 15, 20, 25, 30];

  /// SBP estimate from HR + age, with optional cuff calibration.
  ///
  /// When [cuff] is null the uncalibrated branch runs. When provided,
  /// the calibrated branch returns `cuff.systolic + (hr − cuff.hr) × 0.45`,
  /// matching the SDK's "g_last_sbp + delta" path. Result is clamped
  /// to a sane physiological range to mirror the SDK's bounds checking.
  static int calSbp(int hr, int age, {BpCalibrationAnchor? cuff}) {
    if (cuff != null) {
      final delta = (hr - cuff.hrAtCalibration) * hrBpRate;
      final raw = cuff.systolic + delta;
      return raw.round().clamp(70, 200);
    }
    // Uncalibrated path: pick an age-bracket coefficient, anchor at the
    // mid-point of [MIN_SBP, MAX_SBP], then adjust by HR.
    var bucket = _ageBpCoefficient.length - 1;
    for (var i = 0; i < _ageBuckets.length; i++) {
      if (age < _ageBuckets[i]) {
        bucket = i;
        break;
      }
    }
    final midSbp = (minSbp + maxSbp) / 2; // 110, deterministic vs SDK's random
    final ageAdjusted = midSbp + _ageBpCoefficient[bucket];
    final hrAdjusted = hr >= hrLower
        ? ageAdjusted + (hr - hrLower) * hrBpRate
        : ageAdjusted - (hrLower - hr) * hrBpRate;
    return hrAdjusted.round().clamp(70, 200);
  }

  /// DBP estimate from a derived SBP. The SDK uses a random gap in
  /// `[MIN_BP_DIFF, MAX_BP_DIFF]`; we use the midpoint (40) for
  /// determinism. When [cuff] is provided, preserves the user's actual
  /// observed SBP−DBP gap instead — that's more accurate than the
  /// population midpoint for this individual.
  static int calDbp(int sbp, {BpCalibrationAnchor? cuff}) {
    if (cuff != null) {
      final gap = cuff.systolic - cuff.diastolic;
      return (sbp - gap).clamp(40, 130);
    }
    const midGap = (minBpDiff + maxBpDiff) ~/ 2; // 40
    return (sbp - midGap).clamp(40, 130);
  }

  /// Compute (sbp, dbp) at once. Convenience wrapper — most callers want
  /// the pair together.
  static ({int sbp, int dbp}) calBp(
    int hr,
    int age, {
    BpCalibrationAnchor? cuff,
  }) {
    final sbp = calSbp(hr, age, cuff: cuff);
    final dbp = calDbp(sbp, cuff: cuff);
    return (sbp: sbp, dbp: dbp);
  }
}

/// Minimal anchor for the calibrated BP path. Built from a
/// `BpCalibration` row plus the HR captured at cuff time.
class BpCalibrationAnchor {
  const BpCalibrationAnchor({
    required this.systolic,
    required this.diastolic,
    required this.hrAtCalibration,
  });

  final int systolic;
  final int diastolic;
  final int hrAtCalibration;
}

/// Calibrated BP pair plus the metadata needed to tell the UI which path
/// produced it. `appCalibrated == true` means we applied the cuff formula;
/// `false` means we returned the original band reading unchanged (no
/// active calibration, or missing HR to anchor against).
class CalibratedBp {
  const CalibratedBp({
    required this.sbp,
    required this.dbp,
    required this.appCalibrated,
  });

  final int sbp;
  final int dbp;
  final bool appCalibrated;
}

/// Apply a cuff [anchor] to a raw band reading.
///
/// * When [hr] is non-null and an anchor is provided, runs the linear
///   HR-coupling formula `cuff.sbp + (hr − cuff.hr) × 0.45`.
/// * When HR is unknown (older readings, scheduled rows that lost their
///   pulseBpm), falls back to a constant offset against the band's
///   default 120/80 baseline — less accurate but at least anchors the
///   user's typical reading.
/// * When no anchor exists, returns the raw values unchanged.
CalibratedBp applyBpCalibration({
  required int rawSbp,
  required int rawDbp,
  int? hr,
  BpCalibrationAnchor? anchor,
}) {
  if (anchor == null) {
    return CalibratedBp(sbp: rawSbp, dbp: rawDbp, appCalibrated: false);
  }
  if (hr != null) {
    final bp = BpFormula.calBp(hr, 0, cuff: anchor); // age unused when cuff is set
    return CalibratedBp(sbp: bp.sbp, dbp: bp.dbp, appCalibrated: true);
  }
  // No HR for this reading — apply a constant offset using the SDK's
  // default 120/80 anchor. Not as precise as the HR-coupled path but
  // still moves the reading toward the user's cuff value.
  final dSbp = anchor.systolic - 120;
  final dDbp = anchor.diastolic - 80;
  return CalibratedBp(
    sbp: (rawSbp + dSbp).clamp(70, 200),
    dbp: (rawDbp + dDbp).clamp(40, 130),
    appCalibrated: true,
  );
}
