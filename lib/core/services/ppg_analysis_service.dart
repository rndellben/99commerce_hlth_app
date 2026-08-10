import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/processing/ectopic_adaptive.dart';
import 'package:hlth_app/core/processing/frequency_domain_hrv.dart';
import 'package:hlth_app/core/processing/hrv_calculator.dart';
import 'package:hlth_app/core/processing/respiratory_rate.dart';
import 'package:hlth_app/core/processing/signal_processor.dart';

/// Structured result of [PpgAnalysisService.analyze]. Carries every value
/// the BLE Debug screen used to log inline, plus the quality verdict, so
/// both the debug log and the headless scheduled-capture path read from the
/// same source of truth.
class PpgAnalysisResult {
  const PpgAnalysisResult({
    required this.log,
    required this.fsNativeHz,
    required this.usedCounterTiming,
    required this.blePacketLoss,
    required this.blePacketLossPct,
    required this.greenZeroCount,
    this.peakCount = 0,
    this.rrCount = 0,
    this.ectopicDropped = 0,
    this.hrBpm,
    this.hrvRmssdMs,
    this.hrvSdnnMs,
    this.hrvPnn50,
    this.lfPowerMs2,
    this.hfPowerMs2,
    this.lfHfRatio,
    this.respRateBpm,
    this.rrIrregularityPct,
    this.ectopicBeatPct,
    this.rrEntropyNorm,
    this.rrIntervalsMs = const [],
    this.cleanedRrMs = const [],
    this.passedQualityGate = false,
    this.rejectReasons = const [],
    this.error,
  });

  /// Step-by-step lines, identical to what the debug screen logged inline.
  final List<String> log;

  final int fsNativeHz;
  final bool usedCounterTiming;
  final int blePacketLoss;
  final double blePacketLossPct;
  final int greenZeroCount;

  final int peakCount;
  final int rrCount;
  final int ectopicDropped;

  final double? hrBpm;
  final double? hrvRmssdMs;
  final double? hrvSdnnMs;
  final double? hrvPnn50;
  final double? lfPowerMs2;
  final double? hfPowerMs2;
  final double? lfHfRatio;
  final double? respRateBpm;

  /// R-R irregularity index — coefficient of variation (stddev/mean × 100) of
  /// the RAW R-R intervals, computed BEFORE ectopic cleaning. This is the
  /// irregular-rhythm screen Ryan asked for: a steady heart sits low (~2-6%),
  /// sustained beat-to-beat irregularity (the AFib signature) reads high.
  /// Computed on raw R-R on purpose — cleaning removes the very beats that
  /// carry the signal.
  final double? rrIrregularityPct;

  /// Fraction of beats dropped as ectopic (× 100) — the "irregular
  /// irregularity" companion to [rrIrregularityPct]. High when many beats
  /// fall outside the moving-median band.
  final double? ectopicBeatPct;

  /// Normalised Shannon entropy (0..1) of the gap-stripped R-R histogram —
  /// the AFib guide's third irregularity axis. Sinus rhythm concentrates
  /// intervals in a narrow band (low entropy); disordered timing spreads
  /// them across many bins (high entropy). Independent of the CoV/ectopic
  /// pair, so it corroborates rather than duplicates them.
  final double? rrEntropyNorm;

  /// The derived R-R interval series in milliseconds, BEFORE ectopic cleaning
  /// (sub-sample refined). This is the array the cleaner operates on — what to
  /// export for off-device cleaner tuning (alpha/window).
  final List<double> rrIntervalsMs;

  /// R-R series AFTER moving-median ectopic cleaning (what HRV/respiratory use).
  final List<double> cleanedRrMs;

  /// Whether the capture cleared the quality gate. Only persist when true.
  final bool passedQualityGate;
  final List<String> rejectReasons;

  /// Non-null if the pipeline threw (e.g. no peaks). [passedQualityGate]
  /// is false in that case.
  final String? error;
}

/// Runs the PPG capture → metrics pipeline. Extracted verbatim from the BLE
/// Debug "Analyze" flow so the scheduled-capture service and the debug
/// screen share one implementation.
///
/// Input is the raw stream as buffered during a `startMeasureHrRaw` window:
/// [counts] is the band's per-sample `ppg_count` (one per received sample)
/// and [greens] is the aligned green-channel value (0 = blank). Pass the
/// band's own HR as [bandHr] to enable the quality gate's HR cross-check.
class PpgAnalysisService {
  /// Derived HR must be within this fraction of the band's HR. Loose (0.45)
  /// on purpose: the band's realtime HR is coarse, LAGS, and can be plain
  /// wrong — verified on-device 2026-07-06, a pristine capture (0% BLE loss,
  /// 99 peaks, RMSSD 47 ms) derived a clean resting 72 bpm while the band
  /// reported a stuck 108, a 33% gap that the old 0.30 threshold wrongly
  /// rejected — taking HRV, respiratory AND rhythm down with it. A genuine
  /// peak half/double-count error is ≥50% off, so 0.45 still catches those
  /// while no longer vetoing good captures against a bad band HR. The primary
  /// missed-beat guard is [minBeatCoverage] (self-consistent, doesn't trust
  /// the band's HR), and each derived metric has its own downstream gate
  /// (respiratory peak prominence, HRV min-beats), so this cross-check only
  /// needs to catch gross mis-counts.
  static const maxHrDivergence = 0.45;

  /// At most this fraction of beats may be dropped as ectopic.
  static const maxEctopicDropFrac = 0.20;

  /// We must detect at least this fraction of the beats the DERIVED HR
  /// implies over the capture window. Measured against the derived HR (not
  /// the band's) so it's self-consistent and immune to the band's stale HR:
  /// it catches the real failure — a capture where the median R-R says a
  /// normal rate but only a handful of beats were actually found (the rest
  /// missed), which inflates the coefficient of variation with phantom long
  /// intervals. A 91 s capture whose median R-R implies 85 bpm should yield
  /// ~129 beats; 4 detected (≈3%) is garbage.
  static const minBeatCoverage = 0.60;

  /// Minimum valid R-R intervals before the rhythm-irregularity index is
  /// computed at all. CoV from a handful of beats is meaningless.
  static const minRrForRhythm = 20;

  static const _fsTarget = 75;

  PpgAnalysisResult analyze({
    required List<int> counts,
    required List<double> greens,
    required int greenZeroCount,
    required double durationSec,
    int? bandHr,
  }) {
    final log = <String>[];

    // ── Timing: counter-based reconstruction, else uniform fallback ──────
    final sp0 = SignalProcessor();
    final recon = (counts.length == greens.length && counts.length > 1)
        ? sp0.reconstructUniformFromCounter(counts, greens)
        : null;

    final Float64List raw;
    final int fsNative;
    if (recon != null) {
      raw = recon.samples;
      fsNative = (recon.bandSampleCount / durationSec).round().clamp(5, 200);
      final interpPct = recon.bandSampleCount > 0
          ? recon.gapsInterpolated / recon.bandSampleCount * 100
          : 0.0;
      log.add('Analyze: counter-based timing — ${recon.keptSamples} real '
          'samples across ${recon.bandSampleCount} band-indices '
          '(${interpPct.toStringAsFixed(0)}% interpolated) '
          'over ${durationSec.toStringAsFixed(1)}s → fs_band ≈ $fsNative Hz');
    } else {
      final greenOnly = [for (final g in greens) if (g > 0) g];
      raw = Float64List.fromList(greenOnly);
      fsNative = (greenOnly.length / durationSec).round().clamp(5, 200);
      log.add('Analyze: uniform timing (no counter) — ${greenOnly.length} '
          'samples over ${durationSec.toStringAsFixed(1)}s → '
          'fs_native ≈ $fsNative Hz');
    }

    // ── BLE-loss diagnostic from the counter sequence ────────────────────
    var blePacketLoss = 0;
    var blePacketLossPct = 0.0;
    if (counts.length > 1) {
      var missing = 0;
      var dupes = 0;
      for (int i = 1; i < counts.length; i++) {
        final delta = (counts[i] - counts[i - 1]) & 0xFF;
        if (delta == 0) {
          dupes++;
        } else if (delta > 1) {
          missing += delta - 1;
        }
      }
      final received = counts.length;
      final expected = received + missing;
      blePacketLoss = missing;
      blePacketLossPct = expected > 0 ? missing / expected * 100 : 0.0;
      log.add('  ppg_count: $received received, $missing lost in transit '
          '(${blePacketLossPct.toStringAsFixed(0)}% BLE loss)'
          '${dupes > 0 ? ", $dupes dup" : ""}');
      log.add('  green=0 blanks (poor contact): $greenZeroCount');
    }

    // ── Raw stats + ±3σ clip (catch ADC saturation spikes) ───────────────
    final rawStats = _stats(raw);
    log.add('  raw: min=${rawStats.min.toStringAsFixed(0)} '
        'max=${rawStats.max.toStringAsFixed(0)} '
        'mean=${rawStats.mean.toStringAsFixed(0)} '
        'std=${rawStats.std.toStringAsFixed(1)}');
    final clipLo = rawStats.mean - 3.0 * rawStats.std;
    final clipHi = rawStats.mean + 3.0 * rawStats.std;
    var clippedCount = 0;
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] < clipLo) {
        raw[i] = clipLo;
        clippedCount++;
      } else if (raw[i] > clipHi) {
        raw[i] = clipHi;
        clippedCount++;
      }
    }
    if (clippedCount > 0) {
      log.add('  clipped $clippedCount outliers (>3σ) → '
          'new std=${_stats(raw).std.toStringAsFixed(1)}');
    }

    // ── Upsample to 75 Hz + DC removal, both polarities ──────────────────
    final upsampledPos = _linearResample(raw, fsNative, _fsTarget);
    double sum = 0;
    for (final v in upsampledPos) {
      sum += v;
    }
    final dc = sum / upsampledPos.length;
    for (int i = 0; i < upsampledPos.length; i++) {
      upsampledPos[i] -= dc;
    }
    final upsampledNeg =
        Float64List.fromList(upsampledPos.map((v) => -v).toList());
    log.add('  resampled ${raw.length} → ${upsampledPos.length} samples '
        '@ ${_fsTarget}Hz, dc=${dc.toStringAsFixed(0)} removed');

    final sp = SignalProcessor(samplingRate: _fsTarget);
    final cardiacPosFull = sp.bandpassFilter(upsampledPos, 0.5, 5.0);
    final cardiacNegFull = sp.bandpassFilter(upsampledNeg, 0.5, 5.0);

    // Trim 2s each side to drop filtfilt ring + gain-step transients.
    const trimSamples = _fsTarget * 2;
    final canTrim = cardiacPosFull.length > trimSamples * 2 + 100;
    final cardiacPos = canTrim
        ? Float64List.fromList(
            cardiacPosFull.sublist(trimSamples, cardiacPosFull.length - trimSamples))
        : cardiacPosFull;
    final cardiacNeg = canTrim
        ? Float64List.fromList(
            cardiacNegFull.sublist(trimSamples, cardiacNegFull.length - trimSamples))
        : cardiacNegFull;
    final cpStats = _stats(cardiacPos);
    log.add('  bandpassed (0.5-5Hz${canTrim ? ", trimmed ±2s" : ""}): '
        'min=${cpStats.min.toStringAsFixed(1)} '
        'max=${cpStats.max.toStringAsFixed(1)} '
        'std=${cpStats.std.toStringAsFixed(2)}');

    final peaksPos = sp.detectPeaks(cardiacPos);
    final statsPos = sp.lastPeakStats;
    final peaksNeg = sp.detectPeaks(cardiacNeg);
    final statsNeg = sp.lastPeakStats;
    log.add('  peaks: as-is=${peaksPos.length}, inverted=${peaksNeg.length}');

    final useInverted = peaksNeg.length > peaksPos.length;
    final cardiac = useInverted ? cardiacNeg : cardiacPos;
    final peaks = useInverted ? peaksNeg : peaksPos;
    final stats = useInverted ? statsNeg : statsPos;
    log.add('  using polarity: ${useInverted ? "inverted" : "as-is"}');
    log.add('  peak stages: ${stats.candidates} local-maxima → '
        '${stats.afterHeight} past height floor → '
        '${stats.afterProminence} past prominence → '
        '${stats.afterDistance} after distance');

    if (peaks.isEmpty) {
      log.add('  ❌ no peaks detected at all — signal may be flat or too noisy');
      return PpgAnalysisResult(
        log: log,
        fsNativeHz: fsNative,
        usedCounterTiming: recon != null,
        blePacketLoss: blePacketLoss,
        blePacketLossPct: blePacketLossPct,
        greenZeroCount: greenZeroCount,
        error: 'no peaks detected',
      );
    }

    try {
      final rrIntervals = sp.extractRRIntervalsRefined(cardiac, peaks);
      log.add('  cardiac: ${peaks.length} peaks, ${rrIntervals.length} '
          'valid R-R intervals (300-2000ms, sub-sample refined)');
      if (rrIntervals.isEmpty) {
        log.add('  no valid R-R intervals — peaks may be too irregular');
        return PpgAnalysisResult(
          log: log,
          fsNativeHz: fsNative,
          usedCounterTiming: recon != null,
          blePacketLoss: blePacketLoss,
          blePacketLossPct: blePacketLossPct,
          greenZeroCount: greenZeroCount,
          peakCount: peaks.length,
          error: 'no valid R-R intervals',
        );
      }

      final hr = sp.calculateHeartRate(rrIntervals);
      log.add('  HR: ${hr ?? "—"} bpm');

      final calc = HrvCalculator();
      // Adaptive (Lipponen–Tarvainen / Kubios-style) cleaning: corrects flagged
      // beats by interpolation instead of deleting, and separates real ectopy
      // from BLE-gap intervals. validMask omitted → gaps inferred from interval
      // length (≥1.8× the local median). cleanedRr is full-length (corrected).
      final ectopic = cleanAdaptive(rrIntervals);
      final cleanedRr = ectopic.rrCorrected;
      final ectopicFlagged = (ectopic.ectopicFraction * rrIntervals.length).round();
      final gapFlagged = (ectopic.gapFraction * rrIntervals.length).round();
      log.add('  ectopic cleaning (adaptive QD, α=5.2, window=45): '
          '${rrIntervals.length} beats → ${ectopic.nNormal} normal, '
          '$ectopicFlagged ectopic '
          '(${(ectopic.ectopicFraction * 100).toStringAsFixed(1)}%), '
          '$gapFlagged gap '
          '(${(ectopic.gapFraction * 100).toStringAsFixed(1)}%) — '
          'flagged beats interpolated, not dropped');

      final hrv = calc.calculateFromLabeled(cleanedRr, ectopic.labels);
      if (hrv != null) {
        log.add('  HRV: rmssd=${hrv.rmssd.toStringAsFixed(1)}ms '
            'sdnn=${hrv.sdnn.toStringAsFixed(1)}ms '
            'pnn50=${hrv.pnn50.toStringAsFixed(1)}%');
      } else {
        log.add('  HRV: need ≥10 clean beats (have ${cleanedRr.length})');
      }

      final fdHrv = FrequencyDomainHrv().calculate(cleanedRr);
      if (fdHrv != null) {
        final note = fdHrv.tachogramDurationS < 60
            ? ' (LF unstable — tachogram <60s)'
            : '';
        log.add('  HRV freq: lf=${fdHrv.lfPowerMs2.toStringAsFixed(0)}ms² '
            'hf=${fdHrv.hfPowerMs2.toStringAsFixed(0)}ms² '
            'lf/hf=${fdHrv.lfHfRatio.toStringAsFixed(2)}$note');
      } else {
        log.add('  HRV freq: need ≥25s of clean tachogram '
            '(have ${cleanedRr.length} beats)');
      }

      // ── Quality gate (HR cross-check + ectopic load) ───────────────────
      final ectopicFrac = ectopic.ectopicFraction;
      final hrDivergence = (hr != null && bandHr != null && bandHr > 0)
          ? (hr - bandHr).abs() / bandHr
          : null;
      final rejectReasons = <String>[];
      // Beat-coverage check: did we actually detect enough beats to trust
      // anything? Compare detected R-R count to what the DERIVED HR implies
      // over the capture window — self-consistent, so a stale band HR can't
      // skew it.
      double? beatCoverage;
      if (hr != null && hr > 0 && durationSec > 0) {
        final expectedBeats = hr / 60.0 * durationSec;
        if (expectedBeats > 0) {
          beatCoverage = rrIntervals.length / expectedBeats;
          if (beatCoverage < minBeatCoverage) {
            rejectReasons.add(
                'only ${rrIntervals.length} beats detected vs ~'
                '${expectedBeats.round()} expected for HR '
                '${hr.toStringAsFixed(0)} '
                '(${(beatCoverage * 100).toStringAsFixed(0)}% < '
                '${(minBeatCoverage * 100).toStringAsFixed(0)}%) — '
                'signal too sparse to trust');
          }
        }
      }
      if (hrDivergence != null && hrDivergence > maxHrDivergence) {
        rejectReasons.add('derived HR ${hr!.toStringAsFixed(0)} vs band '
            '$bandHr (${(hrDivergence * 100).toStringAsFixed(0)}% off > '
            '${(maxHrDivergence * 100).toStringAsFixed(0)}%)');
      }
      if (ectopicFrac > maxEctopicDropFrac) {
        rejectReasons.add(
            'ectopic beats ${(ectopicFrac * 100).toStringAsFixed(0)}% '
            '> ${(maxEctopicDropFrac * 100).toStringAsFixed(0)}%');
      }
      final captureOk = rejectReasons.isEmpty;
      if (captureOk) {
        log.add('  quality gate: PASS${hrDivergence == null ? " (band HR "
            "unavailable — HR cross-check skipped)" : ""}');
      } else {
        log.add('  quality gate: ⚠️ REJECT — ${rejectReasons.join("; ")} — '
            're-measure (sit still, band snug)');
      }

      // ── Rhythm irregularity (raw R-R, pre-cleaning) ───────────────────
      // Only meaningful with enough beats AND a capture that cleared the gate
      // (sparse / motion-corrupted captures inflate CoV with phantom long
      // intervals). Below the threshold we leave it null rather than persist
      // a misleading number that could fire a false irregular-rhythm alert.
      final enoughBeats = rrIntervals.length >= minRrForRhythm;
      final rrIrregularityPct =
          (enoughBeats && captureOk) ? _rrCovPct(rrIntervals) : null;
      final ectopicBeatPct =
          (enoughBeats && captureOk) ? ectopicFrac * 100 : null;
      final rrEntropyNorm =
          (enoughBeats && captureOk) ? _rrEntropyNorm(rrIntervals) : null;
      if (rrIrregularityPct != null) {
        log.add('  rhythm: R-R irregularity (CoV) = '
            '${rrIrregularityPct.toStringAsFixed(1)}%, '
            'ectopic beats = ${ectopicBeatPct!.toStringAsFixed(1)}%'
            '${rrEntropyNorm != null ? ", entropy = "
                "${rrEntropyNorm.toStringAsFixed(2)}" : ""}');
      } else {
        log.add('  rhythm: not assessed (need ≥$minRrForRhythm clean beats on '
            'a passing capture; have ${rrIntervals.length}'
            '${captureOk ? "" : ", gate rejected"})');
      }

      // Respiratory rate, like the rhythm metric, is only trustworthy on a
      // capture that cleared the gate — a rejected capture's R-R tachogram is
      // artifact-contaminated and RSA can throw up a spurious low peak (the
      // stray ~9 bpm seen on motion/BLE-loss captures). Computing it only on
      // a passing capture keeps the log honest and matches the persistence
      // rule (we already never saved a rejected value).
      double? respRate;
      if (captureOk) {
        // Lomb-Scargle runs on the RAW beats (it does its own gap handling),
        // with the adaptive cleaner's gap labels as the validity mask so BLE
        // dropouts are excluded rather than interpolated into a fake rhythm.
        final validMask = [
          for (final l in ectopic.labels) l != BeatLabel.gap,
        ];
        final resp = RespiratoryRateCalculator()
            .estimate(rrIntervals, validMask: validMask);
        respRate = resp.ok ? resp.respBpm : null;
        if (resp.ok) {
          log.add('  respiratory rate (RSA, Lomb-Scargle): '
              '${resp.respBpm} breaths/min '
              '(confidence ${resp.confidence.toStringAsFixed(2)}, '
              '${resp.nValidRr} real beats / '
              '${resp.validSpanS.toStringAsFixed(0)}s)');
        } else {
          log.add('  respiratory rate: — (${resp.reason})');
        }
      } else {
        log.add('  respiratory rate: not assessed (gate rejected)');
      }

      return PpgAnalysisResult(
        log: log,
        fsNativeHz: fsNative,
        usedCounterTiming: recon != null,
        blePacketLoss: blePacketLoss,
        blePacketLossPct: blePacketLossPct,
        greenZeroCount: greenZeroCount,
        peakCount: peaks.length,
        rrCount: rrIntervals.length,
        ectopicDropped: ectopicFlagged,
        hrBpm: hr,
        hrvRmssdMs: hrv?.rmssd,
        hrvSdnnMs: hrv?.sdnn,
        hrvPnn50: hrv?.pnn50,
        lfPowerMs2: fdHrv?.lfPowerMs2,
        hfPowerMs2: fdHrv?.hfPowerMs2,
        lfHfRatio: fdHrv?.lfHfRatio,
        respRateBpm: respRate,
        rrIrregularityPct: rrIrregularityPct,
        ectopicBeatPct: ectopicBeatPct,
        rrEntropyNorm: rrEntropyNorm,
        rrIntervalsMs: rrIntervals,
        cleanedRrMs: cleanedRr,
        passedQualityGate: captureOk,
        rejectReasons: rejectReasons,
      );
    } catch (e) {
      log.add('  cardiac/respiratory pipeline error: $e');
      return PpgAnalysisResult(
        log: log,
        fsNativeHz: fsNative,
        usedCounterTiming: recon != null,
        blePacketLoss: blePacketLoss,
        blePacketLossPct: blePacketLossPct,
        greenZeroCount: greenZeroCount,
        peakCount: peaks.length,
        error: e.toString(),
      );
    }
  }

  /// Irregularity index — coefficient of variation (stddev/mean × 100) of the
  /// R-R intervals, computed AFTER excluding BLE missed-beat gaps but BEFORE
  /// ectopic cleaning.
  ///
  /// The H59's bursty stream drops ~8% of samples; an undetected beat shows up
  /// as a single ~2× interval (a data gap, not rhythm). A handful of those
  /// inflate a naive CoV to ~40% on a perfectly normal heart — verified on
  /// hardware. So we drop intervals far from the median (≥1.75× = missed beat,
  /// ≤0.4× = spurious double-detection) and measure scatter on what remains:
  /// low (~5-12%) in sinus rhythm, high only when beats are genuinely
  /// irregular. Pairs with [ectopicBeatPct] (how many beats fell outside the
  /// band) for the actual irregular-rhythm screen. Needs ≥3 kept beats.
  double? _rrCovPct(List<double> rr) {
    if (rr.length < 3) return null;
    final sorted = [...rr]..sort();
    final median = sorted[sorted.length ~/ 2];
    if (median <= 0) return null;
    final kept = [
      for (final v in rr)
        if (v >= 0.4 * median && v <= 1.75 * median) v
    ];
    if (kept.length < 3) return null;
    double sum = 0;
    for (final v in kept) {
      sum += v;
    }
    final mean = sum / kept.length;
    if (mean <= 0) return null;
    double sq = 0;
    for (final v in kept) {
      final d = v - mean;
      sq += d * d;
    }
    final sd = math.sqrt(sq / kept.length);
    return sd / mean * 100;
  }

  /// Normalised Shannon entropy (0..1) of the R-R histogram — the AFib
  /// guide's Layer-4 irregularity metric. Same gap-stripping as [_rrCovPct]
  /// (drop missed-beat / double-detection outliers so BLE loss doesn't fake
  /// disorder), then bin the survivors into fixed 25 ms bins across their
  /// range and take H = −Σ p·log(p), normalised by log(binsUsed) so the
  /// result is scale-free in [0,1]. Sinus rhythm packs intervals into a few
  /// neighbouring bins (low H); AFib's beat-to-beat chaos spreads them wide
  /// (high H). Independent of CoV magnitude — a rhythm can have modest scatter
  /// yet high disorder — so it's a genuine third axis, not a restatement.
  /// Needs ≥8 kept beats (a histogram from a handful of beats is noise).
  double? _rrEntropyNorm(List<double> rr) {
    if (rr.length < 8) return null;
    final sorted = [...rr]..sort();
    final median = sorted[sorted.length ~/ 2];
    if (median <= 0) return null;
    final kept = [
      for (final v in rr)
        if (v >= 0.4 * median && v <= 1.75 * median) v
    ];
    if (kept.length < 8) return null;

    const binMs = 25.0;
    var lo = kept.first, hi = kept.first;
    for (final v in kept) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = hi - lo;
    if (span < binMs) return 0; // all within one bin → no disorder
    final binCount = (span / binMs).ceil() + 1;
    final counts = List<int>.filled(binCount, 0);
    for (final v in kept) {
      var idx = ((v - lo) / binMs).floor();
      if (idx < 0) idx = 0;
      if (idx >= binCount) idx = binCount - 1;
      counts[idx]++;
    }
    final n = kept.length;
    var h = 0.0;
    var used = 0;
    for (final c in counts) {
      if (c == 0) continue;
      used++;
      final p = c / n;
      h -= p * (math.log(p) / math.ln2);
    }
    if (used <= 1) return 0;
    final hMax = math.log(used) / math.ln2; // maximum entropy for bins used
    return hMax <= 0 ? 0 : (h / hMax).clamp(0.0, 1.0);
  }

  ({double min, double max, double mean, double std}) _stats(Float64List s) {
    if (s.isEmpty) return (min: 0, max: 0, mean: 0, std: 0);
    double mn = s[0], mx = s[0], sum = 0;
    for (final v in s) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
      sum += v;
    }
    final mean = sum / s.length;
    double sq = 0;
    for (final v in s) {
      final d = v - mean;
      sq += d * d;
    }
    return (min: mn, max: mx, mean: mean, std: math.sqrt(sq / s.length));
  }

  Float64List _linearResample(Float64List signal, int fsIn, int fsOut) {
    if (fsIn == fsOut) return signal;
    final newLength = (signal.length * fsOut / fsIn).round();
    final out = Float64List(newLength);
    final ratio = (signal.length - 1) / (newLength - 1);
    for (int i = 0; i < newLength; i++) {
      final src = i * ratio;
      final lo = src.floor();
      final hi = (lo + 1).clamp(0, signal.length - 1);
      final frac = src - lo;
      out[i] = signal[lo] * (1 - frac) + signal[hi] * frac;
    }
    return out;
  }
}

final ppgAnalysisServiceProvider =
    Provider<PpgAnalysisService>((ref) => PpgAnalysisService());
