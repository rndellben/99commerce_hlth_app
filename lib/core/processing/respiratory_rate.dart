import 'package:hlth_app/core/processing/respiratory_lombscargle.dart';

/// Respiratory rate extraction.
///
/// Method: respiratory sinus arrhythmia (RSA). Breathing modulates the
/// beat-to-beat timing of the heart, so the breathing rhythm shows up as a
/// peak in the R-R interval series. We read that peak with a Lomb-Scargle
/// periodogram — no PPG morphology, so it's sensor-agnostic and unaffected by
/// the pending sensor swap.
///
/// Lomb-Scargle runs directly on the IRREGULARLY-spaced real beats, so it never
/// resamples the R-R series onto a uniform grid. That matters: the earlier
/// FFT/Welch-on-resampled path had to interpolate synthetic points across BLE
/// gaps, and interpolation has its own periodicity that manufactured spurious
/// peaks (the 22 and 9.4 bpm artifacts on lossy captures). This path uses real
/// beats only, rejects the packet-loss cadence, and refuses — returning `null`
/// — rather than emit a false-precise number when no respiratory peak
/// dominates. See [RespiratoryRateCalculator.estimate] for the full verdict
/// (confidence + reason).
class RespiratoryRateCalculator {
  /// Full Lomb-Scargle estimate, including confidence and the refuse-reason.
  ///
  ///   [rrIntervalsMs] R-R intervals (ms), time-ordered. Pass the raw refined
  ///                   series — Lomb-Scargle does its own gap handling and wants
  ///                   real beats, not the interpolated/corrected series.
  ///   [validMask]     optional per-interval validity (true = between two real
  ///                   beats). Pass the adaptive cleaner's gap labels when you
  ///                   have them; omit to let it infer gaps from interval length.
  ///   [lossCadenceBpm] optional known packet-loss cadence (br/min) to reject.
  RespResult estimate(
    List<double> rrIntervalsMs, {
    List<bool>? validMask,
    double? lossCadenceBpm,
  }) {
    return estimateRespiratoryRate(
      rrIntervalsMs,
      rrValidMask: validMask,
      lossCadenceBpm: lossCadenceBpm,
    );
  }

  /// Respiratory rate in breaths/min, or `null` when the estimator refuses
  /// (too few valid beats, span too short, or no dominant respiratory peak).
  /// Thin wrapper over [estimate] for callers that only need the number.
  double? fromRrIntervals(
    List<double> rrIntervalsMs, {
    List<bool>? validMask,
    double? lossCadenceBpm,
  }) {
    final res = estimate(
      rrIntervalsMs,
      validMask: validMask,
      lossCadenceBpm: lossCadenceBpm,
    );
    return res.ok ? res.respBpm : null;
  }
}
