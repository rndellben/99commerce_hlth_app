// Gap-aware respiratory-rate estimation from PPG-derived R-R intervals (RSA).
//
// Dart port of respiratory_lombscargle.py. Replaces the FFT/Welch-on-resampled
// path (FrequencyDomainHrv), which computed breathing from a uniformly
// resampled R-R series that necessarily includes INTERPOLATED (synthetic)
// points filling BLE gaps — and interpolation imposes its own periodicity,
// which can manufacture a spurious respiratory peak (the bogus 22 / 9.4 br/min
// seen in testing).
//
// This module instead:
//   1. Uses ONLY real beats. Any R-R interval that spans a dropped/interpolated
//      region is excluded, not filled.
//   2. Runs the Lomb-Scargle periodogram, which is built for IRREGULARLY
//      sampled data — no resampling, no synthetic points, no interpolation
//      cadence artifact.
//   3. Rejects respiratory peaks that sit on the packet-loss cadence (or its
//      low harmonics), when that cadence is known.
//   4. Returns a confidence score and an explicit reason when it refuses,
//      rather than a false-precise number.
//
// Pure Dart (no scipy). The Lomb-Scargle is the standard Press & Rybicki form;
// because the spectrum is renormalised to unit sum, the scipy normalisation
// constant cancels and is not needed.

import 'dart:math' as math;

/// Tuning parameters. Defaults match respiratory_lombscargle.py and were set
/// from synthetic RSA — recalibrate [minPeakRatio] / [minPeakOverP90] against
/// real captures with a reference breathing rate if genuinely quiet RSA comes
/// in below the synthetic gates.
class RespConfig {
  // Respiratory search band (breaths/min). 6-40 covers resting → heavy.
  final double respBpmMin;
  final double respBpmMax;

  // Physiologic R-R bounds (ms). Outside this is not a real beat.
  final double rrMinMs;
  final double rrMaxMs;

  // An R-R interval longer than (local median × gapRatio) is treated as
  // spanning a gap and excluded from the RSA series (length-based fallback,
  // used only when no explicit valid mask is supplied).
  final double gapRatio;

  // Peak acceptance: the dominant peak must rise above the spectrum's median
  // (noise floor) by at least this ratio. Real RSA shows >1000×; white-noise
  // R-R shows <20×; 50× sits well inside that gap.
  final double minPeakRatio;

  // Second gate: the dominant peak must also stand clearly above the 90th
  // percentile of the band. Random series produce many tall spikes but no
  // single dominant peak; real RSA does. Real >180×, noise <4×; 10× separates.
  final double minPeakOverP90;

  // Packet-loss-cadence rejection tolerance and harmonic count.
  final double lossCadenceTolBpm;
  final int lossCadenceHarmonics;

  // Minimum valid R-R intervals and analysis span (s) to attempt an estimate.
  final int minValidRr;
  final double minSpanS;

  // Frequency-grid resolution across the respiratory band.
  final int nFreq;

  const RespConfig({
    this.respBpmMin = 6.0,
    this.respBpmMax = 40.0,
    this.rrMinMs = 300.0,
    this.rrMaxMs = 2000.0,
    this.gapRatio = 1.8,
    this.minPeakRatio = 50.0,
    this.minPeakOverP90 = 10.0,
    this.lossCadenceTolBpm = 1.5,
    this.lossCadenceHarmonics = 3,
    this.minValidRr = 20,
    this.minSpanS = 40.0,
    this.nFreq = 600,
  });
}

/// Outcome of [estimateRespiratoryRate]. When [ok] is false, [respBpm] is null
/// and [reason] explains why — render "—" and do NOT persist a number.
class RespResult {
  final bool ok;
  final double? respBpm;
  final double confidence; // 0..1
  final String reason;
  final double peakProminence; // peak-to-median ratio at the dominant peak
  final int nValidRr;
  final double validSpanS;
  final double? secondPeakBpm;

  const RespResult({
    required this.ok,
    required this.respBpm,
    required this.confidence,
    required this.reason,
    this.peakProminence = 0.0,
    this.nValidRr = 0,
    this.validSpanS = 0.0,
    this.secondPeakBpm,
  });
}

/// Estimate respiratory rate (breaths/min) from R-R intervals via RSA +
/// Lomb-Scargle on real beats only.
///
///   [rrMs]          consecutive R-R intervals (ms), in time order.
///   [rrValidMask]   optional, same length as [rrMs]. true = interval between
///                   two REAL beats; false = spans a dropped/interpolated
///                   region. Pass it when you have it (recommended — e.g. the
///                   adaptive cleaner's gap labels). When omitted, gaps are
///                   inferred from interval length via [RespConfig.gapRatio].
///   [lossCadenceBpm] optional known packet-loss cadence (br/min) for artifact
///                   rejection. Pass null to skip the check.
RespResult estimateRespiratoryRate(
  List<double> rrMs, {
  RespConfig cfg = const RespConfig(),
  List<bool>? rrValidMask,
  double? lossCadenceBpm,
}) {
  final n = rrMs.length;
  if (n < cfg.minValidRr) {
    return RespResult(
      ok: false,
      respBpm: null,
      confidence: 0.0,
      reason: 'too few R-R intervals ($n < ${cfg.minValidRr})',
    );
  }

  // 1) Validity mask: physiologic, then either the provided mask or a
  //    length-based gap inference.
  final physiologic =
      List<bool>.generate(n, (i) => rrMs[i] >= cfg.rrMinMs && rrMs[i] <= cfg.rrMaxMs);

  final valid = List<bool>.filled(n, false);
  if (rrValidMask != null) {
    if (rrValidMask.length != n) {
      return const RespResult(
        ok: false,
        respBpm: null,
        confidence: 0.0,
        reason: 'rrValidMask length mismatch with rrMs',
      );
    }
    for (int i = 0; i < n; i++) {
      valid[i] = physiologic[i] && rrValidMask[i];
    }
  } else {
    final phys = [for (int i = 0; i < n; i++) if (physiologic[i]) rrMs[i]];
    final med = phys.isNotEmpty ? _median(phys) : _median(rrMs);
    for (int i = 0; i < n; i++) {
      valid[i] = physiologic[i] && rrMs[i] <= med * cfg.gapRatio;
    }
  }

  final nValid = valid.where((v) => v).length;
  if (nValid < cfg.minValidRr) {
    return RespResult(
      ok: false,
      respBpm: null,
      confidence: 0.0,
      reason: 'too few VALID real intervals after gap removal '
          '($nValid < ${cfg.minValidRr})',
      nValidRr: nValid,
    );
  }

  // 2) Beat timestamps from cumulative intervals. A removed (gap) interval
  //    leaves a real time jump — exactly what Lomb-Scargle handles. Sample the
  //    RSA carrier (instantaneous R-R) at the midpoint time of each VALID
  //    interval.
  final tBeats = List<double>.filled(n + 1, 0.0);
  for (int i = 0; i < n; i++) {
    tBeats[i + 1] = tBeats[i] + rrMs[i];
  }
  for (int i = 0; i <= n; i++) {
    tBeats[i] /= 1000.0; // seconds
  }
  final t = <double>[];
  final y = <double>[];
  for (int i = 0; i < n; i++) {
    if (!valid[i]) continue;
    t.add(0.5 * (tBeats[i] + tBeats[i + 1]));
    y.add(rrMs[i]);
  }

  final span = t.length > 1 ? t.last - t.first : 0.0;
  if (span < cfg.minSpanS) {
    return RespResult(
      ok: false,
      respBpm: null,
      confidence: 0.0,
      reason: 'valid span too short (${span.toStringAsFixed(1)}s '
          '< ${cfg.minSpanS}s)',
      nValidRr: nValid,
      validSpanS: span,
    );
  }

  // 3) Linear detrend — strips gross baseline slope; the band already excludes
  //    < respBpmMin, so this is belt-and-suspenders against wander.
  final detrended = _linearDetrend(t, y);

  // 4) Frequency grid over the respiratory band.
  final fMin = cfg.respBpmMin / 60.0;
  final fMax = cfg.respBpmMax / 60.0;
  final freqsBpm = List<double>.filled(cfg.nFreq, 0.0);
  final ang = List<double>.filled(cfg.nFreq, 0.0);
  for (int i = 0; i < cfg.nFreq; i++) {
    final f = fMin + (fMax - fMin) * i / (cfg.nFreq - 1);
    ang[i] = 2.0 * math.pi * f;
    freqsBpm[i] = f * 60.0;
  }

  final power = _lombscargleNormalized(t, detrended, ang);
  if (!power.any((p) => p > 0)) {
    return RespResult(
      ok: false,
      respBpm: null,
      confidence: 0.0,
      reason: 'flat / zero spectrum',
      nValidRr: nValid,
      validSpanS: span,
    );
  }

  // 5) Dominant in-band peak.
  int peakIdx = 0;
  for (int i = 1; i < power.length; i++) {
    if (power[i] > power[peakIdx]) peakIdx = i;
  }
  final peakBpm = freqsBpm[peakIdx];

  final positive = [for (final p in power) if (p > 0) p];
  final floor = positive.isNotEmpty ? _median(positive) : 0.0;
  final peakFrac = floor > 0 ? power[peakIdx] / floor : 0.0;
  final p90 = _percentile(power, 90);
  final peakOverP90 = p90 > 0 ? power[peakIdx] / p90 : 0.0;

  // Second peak, for diagnostics / harmonic checks.
  final masked = List<double>.from(power);
  final guard = cfg.nFreq ~/ 60;
  final lo = math.max(0, peakIdx - guard);
  final hi = math.min(power.length, peakIdx + guard);
  for (int i = lo; i < hi; i++) {
    masked[i] = 0.0;
  }
  int secondIdx = 0;
  for (int i = 1; i < masked.length; i++) {
    if (masked[i] > masked[secondIdx]) secondIdx = i;
  }
  final secondBpm = masked[secondIdx] > 0 ? freqsBpm[secondIdx] : null;

  // 6) Confidence gate on peak prominence.
  if (peakFrac < cfg.minPeakRatio || peakOverP90 < cfg.minPeakOverP90) {
    return RespResult(
      ok: false,
      respBpm: null,
      confidence: _confidence(peakFrac, span, nValid, cfg),
      reason: 'no dominant respiratory peak '
          '(peak/floor ${peakFrac.toStringAsFixed(1)}, '
          'peak/p90 ${peakOverP90.toStringAsFixed(1)}; '
          'need ≥ ${cfg.minPeakRatio} and ≥ ${cfg.minPeakOverP90})',
      peakProminence: peakFrac,
      nValidRr: nValid,
      validSpanS: span,
      secondPeakBpm: secondBpm,
    );
  }

  // 7) Packet-loss-cadence rejection.
  if (lossCadenceBpm != null && lossCadenceBpm > 0) {
    for (int h = 1; h <= cfg.lossCadenceHarmonics; h++) {
      final cadence = lossCadenceBpm * h;
      if ((peakBpm - cadence).abs() <= cfg.lossCadenceTolBpm) {
        return RespResult(
          ok: false,
          respBpm: null,
          confidence: _confidence(peakFrac, span, nValid, cfg) * 0.5,
          reason: 'peak ${peakBpm.toStringAsFixed(1)} br/min coincides with '
              'packet-loss cadence harmonic $h (${cadence.toStringAsFixed(1)}) '
              '→ rejected as artifact',
          peakProminence: peakFrac,
          nValidRr: nValid,
          validSpanS: span,
          secondPeakBpm: secondBpm,
        );
      }
    }
  }

  // 8) Sub-bin parabolic refinement around the peak.
  final refinedBpm = _parabolicRefine(freqsBpm, power, peakIdx);

  return RespResult(
    ok: true,
    respBpm: double.parse(refinedBpm.toStringAsFixed(1)),
    confidence: _confidence(peakFrac, span, nValid, cfg),
    reason: 'ok',
    peakProminence: peakFrac,
    nValidRr: nValid,
    validSpanS: span,
    secondPeakBpm: secondBpm,
  );
}

/// Standard Lomb-Scargle periodogram, renormalised to unit sum so the output
/// reads as a power distribution (used for the prominence/confidence ratios).
List<double> _lombscargleNormalized(
    List<double> t, List<double> y, List<double> angFreqs) {
  final mean = y.reduce((a, b) => a + b) / y.length;
  final yc = [for (final v in y) v - mean];

  final pgram = List<double>.filled(angFreqs.length, 0.0);
  for (int k = 0; k < angFreqs.length; k++) {
    final w = angFreqs[k];
    if (w == 0) continue;
    double sin2 = 0, cos2 = 0;
    for (final tj in t) {
      sin2 += math.sin(2 * w * tj);
      cos2 += math.cos(2 * w * tj);
    }
    final tau = math.atan2(sin2, cos2) / (2 * w);
    double cc = 0, ss = 0, ycos = 0, ysin = 0;
    for (int j = 0; j < t.length; j++) {
      final dt = t[j] - tau;
      final c = math.cos(w * dt);
      final s = math.sin(w * dt);
      cc += c * c;
      ss += s * s;
      ycos += yc[j] * c;
      ysin += yc[j] * s;
    }
    final termC = cc > 0 ? (ycos * ycos) / cc : 0.0;
    final termS = ss > 0 ? (ysin * ysin) / ss : 0.0;
    final p = 0.5 * (termC + termS);
    pgram[k] = p > 0 ? p : 0.0;
  }

  double total = 0;
  for (final p in pgram) {
    total += p;
  }
  if (total <= 0 || !total.isFinite) {
    return List<double>.filled(pgram.length, 0.0);
  }
  return [for (final p in pgram) p / total];
}

/// Remove the least-squares linear trend y ≈ a·t + b.
List<double> _linearDetrend(List<double> t, List<double> y) {
  final n = t.length;
  double st = 0, sy = 0, stt = 0, sty = 0;
  for (int i = 0; i < n; i++) {
    st += t[i];
    sy += y[i];
    stt += t[i] * t[i];
    sty += t[i] * y[i];
  }
  final denom = n * stt - st * st;
  if (denom == 0) return List<double>.from(y);
  final a = (n * sty - st * sy) / denom;
  final b = (sy - a * st) / n;
  return [for (int i = 0; i < n; i++) y[i] - (a * t[i] + b)];
}

double _parabolicRefine(List<double> x, List<double> y, int i) {
  if (i <= 0 || i >= x.length - 1) return x[i];
  final y0 = y[i - 1], y1 = y[i], y2 = y[i + 1];
  final denom = y0 - 2 * y1 + y2;
  if (denom == 0) return x[i];
  final delta = 0.5 * (y0 - y2) / denom;
  return x[i] + delta * (x[i + 1] - x[i]);
}

double _confidence(double peakFrac, double spanS, int nValid, RespConfig cfg) {
  final p = _clip(
      (_log10(math.max(peakFrac, 1.0)) - _log10(cfg.minPeakRatio)) /
          (_log10(2000.0) - _log10(cfg.minPeakRatio)),
      0,
      1);
  final s = _clip((spanS - cfg.minSpanS) / (180.0 - cfg.minSpanS), 0, 1);
  final nn = _clip((nValid - cfg.minValidRr) / (200.0 - cfg.minValidRr), 0, 1);
  final conf = 0.55 * p + 0.25 * s + 0.20 * nn;
  return double.parse(conf.toStringAsFixed(3));
}

// ── numeric helpers ──────────────────────────────────────────────────────────

double _log10(double x) => math.log(x) / math.ln10;

double _clip(double x, double lo, double hi) => x < lo ? lo : (x > hi ? hi : x);

double _median(List<double> a) {
  final s = List<double>.from(a)..sort();
  if (s.isEmpty) return 0.0;
  return s.length.isOdd
      ? s[s.length ~/ 2]
      : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2.0;
}

double _percentile(List<double> a, double p) {
  if (a.isEmpty) return 0.0;
  final s = List<double>.from(a)..sort();
  final rank = (p / 100.0) * (s.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return s[lo];
  return s[lo] + (s[hi] - s[lo]) * (rank - lo);
}
