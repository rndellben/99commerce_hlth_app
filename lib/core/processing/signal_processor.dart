import 'dart:math';
import 'dart:typed_data';

/// Shared signal processing pipeline — foundation for all health features.
/// Ported from hlth-engineering-primer.md Section 2.
class SignalProcessor {
  final int samplingRate;

  SignalProcessor({this.samplingRate = 75});

  /// Zero-phase bandpass via biquad bandpass + filtfilt.
  ///
  /// Coefficients are the standard audio-EQ cookbook (RBJ) bandpass biquad
  /// — a 2nd-order BPF with geometric-center f0 = sqrt(low*high) and
  /// Q = f0/(high-low). Applied forward then backward to get zero phase
  /// (matches scipy's `sosfiltfilt` for our purposes, though scipy uses
  /// a true 4th-order Butterworth — adequate for HR/respiratory bands).
  ///
  ///   cardiac:     lowcut=0.5, highcut=5.0  (heartbeat fundamental)
  ///   respiratory: lowcut=0.1, highcut=0.5  (breathing modulation)
  Float64List bandpassFilter(
    Float64List signal,
    double lowcut,
    double highcut,
  ) {
    // Geometric center + bandwidth → Q.
    final f0 = sqrt(lowcut * highcut);
    final bw = highcut - lowcut;
    final q = f0 / bw;

    final omega = 2.0 * pi * f0 / samplingRate;
    final alpha = sin(omega) / (2.0 * q);
    final cosOmega = cos(omega);

    // RBJ BPF (constant 0 dB peak gain).
    final b0 = alpha;
    const b1 = 0.0;
    final b2 = -alpha;
    final a0 = 1.0 + alpha;
    final a1 = -2.0 * cosOmega;
    final a2 = 1.0 - alpha;

    final coeffs = _BiquadCoeffs(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);

    final forward = _applyBiquad(signal, coeffs);
    final reversed = _reverse(forward);
    final backward = _applyBiquad(reversed, coeffs);
    return _reverse(backward);
  }

  Float64List _applyBiquad(Float64List signal, _BiquadCoeffs c) {
    final out = Float64List(signal.length);
    if (signal.isEmpty) return out;
    // Pre-load the filter so it starts in steady state for a constant
    // input of `signal[0]`. Mirrors scipy's `lfilter_zi(b, a) * signal[0]`
    // pattern. Without this, the filter sees a step from 0 → signal[0]
    // at sample 0 and rings at its natural frequency for many seconds —
    // catastrophic for the respiratory band (0.1-0.5 Hz, ringing period
    // ≈ 4-10 s) where the ringing artifact dominates short captures and
    // produces a constant output regardless of the real input (the
    // "respiratory rate stuck at 7.8 bpm" bug).
    //
    // For our RBJ bandpass, DC gain is 0 (b0 + b1 + b2 = α + 0 + (−α) = 0)
    // so the steady-state output for constant input is 0. Loading
    // x1 = x2 = signal[0] with y1 = y2 = 0 puts the filter in that
    // steady state at sample 0; only the AC component of subsequent
    // samples drives the response.
    double x1 = signal[0], x2 = signal[0], y1 = 0, y2 = 0;
    for (int i = 0; i < signal.length; i++) {
      final x = signal[i];
      final y = c.b0 * x + c.b1 * x1 + c.b2 * x2 - c.a1 * y1 - c.a2 * y2;
      out[i] = y;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
    }
    return out;
  }

  Float64List _reverse(Float64List s) {
    final out = Float64List(s.length);
    for (int i = 0; i < s.length; i++) {
      out[i] = s[s.length - 1 - i];
    }
    return out;
  }

  /// Signal quality assessment (0-100).
  /// Reject segments below 50.
  double assessQuality(Float64List ppgSegment) {
    if (ppgSegment.length < samplingRate * 2) return 0;

    // 1. Spectral SNR: cardiac band power vs total power
    final cardiacFiltered =
        bandpassFilter(ppgSegment, 0.7, 3.5);
    final cardiacPower = _signalPower(cardiacFiltered);
    final totalPower = _signalPower(ppgSegment);
    final snrScore =
        totalPower > 0 ? (cardiacPower / totalPower) * 100 : 0.0;

    // 2. Peak regularity
    final peaks = detectPeaks(cardiacFiltered);
    if (peaks.length < 3) return 0;

    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / samplingRate);
    }
    final meanInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    final stdInterval = _std(intervals);
    final cv = stdInterval / meanInterval;
    final regularityScore = max(0.0, (1.0 - cv / 0.3)) * 100;

    return min(100.0, max(0.0, snrScore * 0.5 + regularityScore * 0.5));
  }

  /// Detect heartbeat peaks in a bandpass-filtered PPG signal.
  ///
  /// Ports `scipy.signal.find_peaks` semantics: collect strict local
  /// maxima, then apply height → prominence → distance filters as
  /// independent stages. Matches the reference pipeline at
  /// `hlth_pipeline/pipeline/peaks.py` exactly.
  ///
  /// Thresholds (from `hlth-engineering-primer.md` §2 Stage 4):
  ///   * `min_distance = minDistanceSeconds * fs`
  ///   * `height       = median + 0.3·σ` — must clear the noise floor
  ///   * `prominence   = 0.1·σ`          — must stand out from neighbours
  ///
  /// [minDistanceSeconds] gates how close two peaks can be. Default
  /// `0.33` caps cardiac HR at 180 bpm. For the respiratory band
  /// (0.1-0.5 Hz, breaths every 2-10 sec) pass `2.0` so the algorithm
  /// doesn't false-trigger on within-breath wobble.
  ///
  /// Prominence is computed the scipy way (`peak_prominences`): from each
  /// candidate, walk outward until a strictly-higher sample is found,
  /// take the minimum along the way as the left/right base, prominence =
  /// `peak − max(left_base, right_base)`. The previous Dart impl used a
  /// fixed ±min_distance window for the local-min search, which grossly
  /// underestimates real prominence and was the root cause of the
  /// 4-7 peaks-per-30s under-count on H59 captures.
  /// Stage-by-stage survivor counts from the most recent [detectPeaks] call,
  /// for debug logging — lets a capture's log show exactly where beats were
  /// kept or dropped (height floor vs prominence vs distance).
  PeakDetectStats lastPeakStats = const PeakDetectStats.zero();

  List<int> detectPeaks(
    Float64List ppgFiltered, {
    double minDistanceSeconds = 0.33,
    double localWindowSeconds = 3.0,
    double heightK = 0.3,
  }) {
    if (ppgFiltered.length < 3) {
      lastPeakStats = const PeakDetectStats.zero();
      return const [];
    }

    final minDistance = (minDistanceSeconds * samplingRate).toInt();
    final prominenceThreshold = 0.1 * _std(ppgFiltered.toList());

    // Stage 1: every strict local maximum is a candidate.
    final candidates = <int>[];
    for (int i = 1; i < ppgFiltered.length - 1; i++) {
      if (ppgFiltered[i] > ppgFiltered[i - 1] &&
          ppgFiltered[i] > ppgFiltered[i + 1]) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) {
      lastPeakStats = const PeakDetectStats.zero();
      return const [];
    }

    // Stage 2: LOCAL adaptive height floor. A single global floor
    // (median + k·std over the whole window) systematically drops real beats
    // in any stretch where the pulse amplitude dips below average — the H59's
    // amplitude drifts over a 90s capture, so a global floor under-counts
    // (derived HR reads ~half the band's). Instead, compare each candidate to
    // the median + k·std of a ~[localWindowSeconds] window around it, so the
    // threshold tracks the local envelope: low-amplitude stretches get a low
    // floor (beats kept), motion-inflated stretches get a high floor (junk
    // rejected). On a clean, uniform-amplitude capture local ≈ global, so this
    // leaves good captures unchanged.
    final half = (localWindowSeconds * samplingRate / 2).round().clamp(1, ppgFiltered.length);
    final afterHeight = <int>[];
    for (final idx in candidates) {
      final lo = (idx - half).clamp(0, ppgFiltered.length);
      final hi = (idx + half).clamp(0, ppgFiltered.length);
      final win = ppgFiltered.sublist(lo, hi);
      final localFloor = _median(win) + heightK * _std(win.toList());
      if (ppgFiltered[idx] > localFloor) afterHeight.add(idx);
    }

    // Stage 3: scipy-style prominence floor (rejects ripple on a slow wave).
    final survivors = <int>[];
    for (final idx in afterHeight) {
      if (_peakProminence(ppgFiltered, idx) > prominenceThreshold) {
        survivors.add(idx);
      }
    }
    if (survivors.isEmpty) {
      lastPeakStats =
          PeakDetectStats(candidates.length, afterHeight.length, 0, 0);
      return const [];
    }

    // Stage 4: distance filter (scipy `_select_by_peak_distance`). Walk
    // surviving peaks in height-descending order; when a tall peak is
    // kept, mark any shorter peak inside ±min_distance as removed. This
    // resolves clusters of close maxima without the buggy "replace on the
    // fly" logic of the previous implementation.
    final keep = List<bool>.filled(survivors.length, true);
    final orderByHeight = List<int>.generate(survivors.length, (i) => i)
      ..sort((a, b) => ppgFiltered[survivors[b]]
          .compareTo(ppgFiltered[survivors[a]]));
    for (final k in orderByHeight) {
      if (!keep[k]) continue;
      final myIdx = survivors[k];
      for (int j = 0; j < survivors.length; j++) {
        if (j == k || !keep[j]) continue;
        if ((survivors[j] - myIdx).abs() < minDistance) keep[j] = false;
      }
    }

    final result = <int>[];
    for (int k = 0; k < survivors.length; k++) {
      if (keep[k]) result.add(survivors[k]);
    }
    lastPeakStats = PeakDetectStats(
        candidates.length, afterHeight.length, survivors.length, result.length);
    return result;
  }

  /// scipy-style prominence: walk outward from `peak` until a sample
  /// strictly higher than the peak is hit (or the signal boundary), then
  /// take the minimum value seen on each side. Prominence is the peak
  /// height minus the higher of the two side-minima.
  double _peakProminence(Float64List signal, int peak) {
    final h = signal[peak];

    double leftMin = h;
    for (int i = peak - 1; i >= 0; i--) {
      if (signal[i] > h) break;
      if (signal[i] < leftMin) leftMin = signal[i];
    }

    double rightMin = h;
    for (int i = peak + 1; i < signal.length; i++) {
      if (signal[i] > h) break;
      if (signal[i] < rightMin) rightMin = signal[i];
    }

    return h - max(leftMin, rightMin);
  }

  /// Reconstruct a uniformly-spaced (in band time) PPG signal from samples
  /// tagged with the band's rolling 0-255 sample counter (`ppg_count`).
  ///
  /// [counts] and [greens] are parallel arrays in arrival order — one entry
  /// per received sample. Samples with `green <= 0` are treated as gaps
  /// (sensor blank), as are missing counter values (BLE loss). Each kept
  /// sample is placed at its unwrapped band-index position and the missing
  /// positions are linearly interpolated, so the output is uniform in the
  /// band's own sample clock.
  ///
  /// Why this beats the naive `count / wall-clock` average: the H59 streams
  /// raw samples in bursty BLE batches whose phone arrival times bunch up
  /// (3 within a few ms, then a ~100 ms gap), and it also drops ~2-8% of
  /// samples. Treating the survivors as evenly spaced warps every R-R
  /// interval that straddles a burst boundary or a dropout. The band's own
  /// counter is uniform regardless of how packets arrive, so anchoring to
  /// it removes that distortion.
  ///
  /// Counter wraps (255→0) are unwrapped via mod-256 deltas, so a single
  /// gap longer than 256 samples (~10 s at 25 Hz) would be undercounted —
  /// but that's a connection blackout that shows up elsewhere.
  ///
  /// Returns null if fewer than [minSamples] usable (green>0) samples are
  /// present, or the inputs are misaligned.
  CounterReconstruction? reconstructUniformFromCounter(
    List<int> counts,
    List<double> greens, {
    int minSamples = 10,
  }) {
    if (counts.length != greens.length || counts.length < 2) return null;

    // Unwrap the counter to absolute band indices, keeping only green>0.
    final absIdx = <int>[];
    final vals = <double>[];
    int abs = 0;
    for (int i = 0; i < counts.length; i++) {
      if (i > 0) abs += (counts[i] - counts[i - 1]) & 0xFF;
      if (greens[i] > 0) {
        absIdx.add(abs);
        vals.add(greens[i]);
      }
    }
    if (absIdx.length < minSamples) return null;

    // Lay the kept samples on a contiguous band-index grid, linearly
    // interpolating any index with no real sample.
    final span = absIdx.last - absIdx.first + 1;
    final grid = Float64List(span);
    int p = 0;
    for (int j = 0; j < span; j++) {
      final target = absIdx.first + j;
      while (p < absIdx.length - 1 && absIdx[p + 1] <= target) {
        p++;
      }
      if (absIdx[p] == target || p == absIdx.length - 1) {
        grid[j] = vals[p];
      } else {
        final a0 = absIdx[p], a1 = absIdx[p + 1];
        final frac = (target - a0) / (a1 - a0);
        grid[j] = vals[p] * (1 - frac) + vals[p + 1] * frac;
      }
    }

    return CounterReconstruction(
      samples: grid,
      bandSampleCount: span,
      keptSamples: absIdx.length,
      gapsInterpolated: span - absIdx.length,
    );
  }

  /// Extract R-R intervals in milliseconds from integer peak indices.
  List<double> extractRRIntervals(List<int> peaks) =>
      _rrFromPositions([for (final p in peaks) p.toDouble()]);

  /// As [extractRRIntervals] but from sub-sample-refined peak positions
  /// (see [refinePeaksParabolic]). Prefer this whenever the source PPG
  /// was upsampled: the integer peak grid otherwise quantises every R-R
  /// interval to the sample period (13.3 ms at 75 Hz), and that jitter
  /// inflates RMSSD and biases the RSA respiratory estimate high.
  List<double> extractRRIntervalsRefined(Float64List signal, List<int> peaks) =>
      _rrFromPositions(refinePeaksParabolic(signal, peaks));

  List<double> _rrFromPositions(List<double> positions) {
    final rrIntervals = <double>[];
    for (int i = 1; i < positions.length; i++) {
      final rrMs = (positions[i] - positions[i - 1]) / samplingRate * 1000;
      // Physiological validation: 300ms (200bpm) to 2000ms (30bpm)
      if (rrMs >= 300 && rrMs <= 2000) {
        rrIntervals.add(rrMs);
      }
    }
    return rrIntervals;
  }

  /// Refine integer peak indices to sub-sample positions via parabolic
  /// interpolation over each peak and its two immediate neighbours.
  ///
  /// The 25 Hz native PPG is upsampled to 75 Hz before peak detection, but
  /// the interpolated samples add no real temporal resolution — the peak
  /// picker still snaps to the sample grid, so every R-R interval carries
  /// up to ±1 sample of quantisation error. Fitting a parabola to the
  /// (y[i-1], y[i], y[i+1]) triple and taking its vertex recovers the true
  /// peak time to a fraction of a sample, removing the jitter that
  /// otherwise reads as elevated HRV (per Ryan's 2026-06-17 note that the
  /// upsample "will force the HRV to read high").
  List<double> refinePeaksParabolic(Float64List signal, List<int> peaks) {
    final refined = <double>[];
    for (final p in peaks) {
      if (p <= 0 || p >= signal.length - 1) {
        refined.add(p.toDouble());
        continue;
      }
      final yl = signal[p - 1], y0 = signal[p], yr = signal[p + 1];
      final denom = yl - 2 * y0 + yr;
      // denom == 0 → the triple is colinear (no curvature); leave the peak
      // on the integer grid. The vertex of a concave-down parabola lies
      // within ±0.5 samples; clamp guards against a non-concave triple
      // (which `detectPeaks` shouldn't produce, but costs nothing to fence).
      final delta = denom != 0 ? (0.5 * (yl - yr) / denom).clamp(-0.5, 0.5) : 0.0;
      refined.add(p + delta);
    }
    return refined;
  }

  /// Heart rate in BPM from R-R intervals.
  double? calculateHeartRate(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) return null;
    final meanRr =
        rrIntervalsMs.reduce((a, b) => a + b) / rrIntervalsMs.length;
    final hr = 60000 / meanRr;

    // Sanity check: 30-220 bpm
    if (hr < 30 || hr > 220) return null;
    return double.parse(hr.toStringAsFixed(1));
  }

  /// Calculate SpO2 from red and infrared AC/DC components.
  double? calculateSpO2({
    required double redAc,
    required double redDc,
    required double irAc,
    required double irDc,
  }) {
    if (redDc == 0 || irDc == 0) return null;
    final r = (redAc / redDc) / (irAc / irDc);
    final spo2 = 110 - 25 * r;

    // Sanity check: 70-100%
    if (spo2 < 70 || spo2 > 100) return null;
    return double.parse(spo2.toStringAsFixed(1));
  }

  // --- Helper functions ---

  double _signalPower(Float64List signal) {
    double sum = 0;
    for (final s in signal) {
      sum += s * s;
    }
    return sum / signal.length;
  }

  double _median(Float64List data) {
    final sorted = Float64List.fromList(data)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _std(List<double> data) {
    final mean = data.reduce((a, b) => a + b) / data.length;
    double sumSquaredDiffs = 0;
    for (final d in data) {
      sumSquaredDiffs += (d - mean) * (d - mean);
    }
    return sqrt(sumSquaredDiffs / data.length);
  }

}

class _BiquadCoeffs {
  final double b0, b1, b2, a1, a2;
  const _BiquadCoeffs(this.b0, this.b1, this.b2, this.a1, this.a2);
}

/// Stage-by-stage survivor counts through [SignalProcessor.detectPeaks], for
/// debug logging: how many local-maxima candidates survived the local height
/// floor, the prominence floor, and the distance filter in turn.
class PeakDetectStats {
  final int candidates;
  final int afterHeight;
  final int afterProminence;
  final int afterDistance;
  const PeakDetectStats(this.candidates, this.afterHeight,
      this.afterProminence, this.afterDistance);
  const PeakDetectStats.zero()
      : candidates = 0,
        afterHeight = 0,
        afterProminence = 0,
        afterDistance = 0;
}

/// Result of [SignalProcessor.reconstructUniformFromCounter].
class CounterReconstruction {
  const CounterReconstruction({
    required this.samples,
    required this.bandSampleCount,
    required this.keptSamples,
    required this.gapsInterpolated,
  });

  /// Green values placed at their true band-index positions, uniformly
  /// spaced in band time, with gaps linearly interpolated. Feed this to
  /// the rest of the pipeline as the raw signal, using
  /// `bandSampleCount / captureDurationSeconds` as the native sample rate.
  final Float64List samples;

  /// Total band-index span the signal covers (== `samples.length`).
  final int bandSampleCount;

  /// How many real (green>0) samples contributed.
  final int keptSamples;

  /// How many grid positions were filled by interpolation (BLE drops +
  /// green=0 blanks). `gapsInterpolated / bandSampleCount` is the fraction
  /// of the signal that is reconstructed rather than measured.
  final int gapsInterpolated;
}
