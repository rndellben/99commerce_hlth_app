import 'dart:math';
import 'dart:typed_data';

/// Frequency-domain HRV (LF/HF). Ports the canonical pipeline from
/// `hlth_pipeline/BIOBSS/biobss/hrvtools/hrv_freqdomain.py`:
///
///   1. Build a tachogram: beat times `t = cumsum(rr)/1000` (seconds),
///      values are R-R intervals (ms).
///   2. Cubic-spline interpolate onto a regular 4 Hz grid.
///   3. Detrend (subtract mean), apply a Hann window, zero-pad to the
///      next power of two, run a radix-2 FFT.
///   4. Compute the one-sided PSD (Welch's method with a single full
///      window).
///   5. Trapezoidal-integrate the PSD over the LF (0.04-0.15 Hz) and HF
///      (0.15-0.40 Hz) bands. Ratio = LF / HF.
///
/// Output powers are in ms² (absolute), ratio is dimensionless.
class FrequencyDomainHrv {
  /// Hard-coded resample rate. The HRV literature standardises on 4 Hz
  /// so absolute band powers are comparable across studies; do not
  /// vary unless you also retune downstream consumers (stress score).
  static const double resampleHz = 4.0;

  static const double lfLowHz = 0.04;
  static const double lfHighHz = 0.15;
  static const double hfLowHz = 0.15;
  static const double hfHighHz = 0.40;

  /// Compute LF, HF and LF/HF ratio from cleaned R-R intervals in ms.
  ///
  /// Returns `null` if the input is too short to give a meaningful
  /// estimate. The LF band's lowest frequency is 0.04 Hz, so we need
  /// at least `1 / 0.04 = 25 s` of tachogram to resolve a single LF
  /// cycle — anything shorter and LF power is just an arithmetic
  /// artefact of the windowing.
  FrequencyDomainMetrics? calculate(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 4) return null;

    // Tachogram: cumulative beat times in seconds.
    final beatTimes = Float64List(rrIntervalsMs.length);
    double t = 0;
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      t += rrIntervalsMs[i] / 1000.0;
      beatTimes[i] = t;
    }
    final durationS = beatTimes[rrIntervalsMs.length - 1] - beatTimes[0];
    if (durationS < 25) return null;

    // Cubic-spline interpolate onto a regular 4 Hz grid.
    final resampled = _cubicSplineResample(
      beatTimes,
      Float64List.fromList(rrIntervalsMs),
      resampleHz,
    );
    if (resampled.length < 8) return null;

    // Detrend.
    double mean = 0;
    for (final v in resampled) {
      mean += v;
    }
    mean /= resampled.length;
    for (int i = 0; i < resampled.length; i++) {
      resampled[i] -= mean;
    }

    // Hann window.
    final n = resampled.length;
    double windowEnergy = 0;
    for (int i = 0; i < n; i++) {
      final w = 0.5 * (1 - cos(2 * pi * i / (n - 1)));
      resampled[i] *= w;
      windowEnergy += w * w;
    }

    // Zero-pad to next power of two for the radix-2 FFT.
    final fftSize = _nextPow2(n);
    final reBuf = Float64List(fftSize);
    final imBuf = Float64List(fftSize);
    for (int i = 0; i < n; i++) {
      reBuf[i] = resampled[i];
    }
    _fftRadix2InPlace(reBuf, imBuf);

    // One-sided PSD. Scaling matches `scipy.signal.welch(..., window='hann')`:
    //   PSD(f) = |X(f)|² / (fs · Σ window²)
    // doubling the non-DC, non-Nyquist bins to fold the negative-frequency
    // power into the one-sided spectrum.
    final halfBins = fftSize ~/ 2 + 1;
    final freqs = Float64List(halfBins);
    final psd = Float64List(halfBins);
    final scale = 1.0 / (resampleHz * windowEnergy);
    for (int k = 0; k < halfBins; k++) {
      freqs[k] = k * resampleHz / fftSize;
      final mag2 = reBuf[k] * reBuf[k] + imBuf[k] * imBuf[k];
      final isEdge = k == 0 || k == halfBins - 1 && fftSize.isEven;
      psd[k] = mag2 * scale * (isEdge ? 1.0 : 2.0);
    }

    final lf = _bandPower(freqs, psd, lfLowHz, lfHighHz);
    final hf = _bandPower(freqs, psd, hfLowHz, hfHighHz);
    if (lf <= 0 || hf <= 0) return null;

    return FrequencyDomainMetrics(
      lfPowerMs2: lf,
      hfPowerMs2: hf,
      lfHfRatio: lf / hf,
      tachogramDurationS: durationS,
      resampledSamples: n,
    );
  }

  /// Natural cubic spline interpolation onto a regular grid at [fs] Hz,
  /// spanning the tachogram's first to last beat.
  ///
  /// scipy's `interp1d(kind='cubic')` uses a not-a-knot boundary
  /// condition; we use natural (second derivative = 0 at the
  /// endpoints) since it's the standard textbook formulation. The
  /// difference is well under 1% for inputs of >10 beats per the HRV
  /// literature, and the not-a-knot variant requires building a
  /// non-tridiagonal system that is not worth the implementation cost
  /// here.
  Float64List _cubicSplineResample(
    Float64List xs,
    Float64List ys,
    double fs,
  ) {
    final n = xs.length;
    // Solve for second derivatives M_i with natural BC (M_0 = M_{n-1} = 0).
    final h = Float64List(n - 1);
    for (int i = 0; i < n - 1; i++) {
      h[i] = xs[i + 1] - xs[i];
    }
    final mu = Float64List(n);
    final lambda = Float64List(n);
    final d = Float64List(n);
    for (int i = 1; i < n - 1; i++) {
      mu[i] = h[i - 1] / (h[i - 1] + h[i]);
      lambda[i] = h[i] / (h[i - 1] + h[i]);
      d[i] = 6 *
          ((ys[i + 1] - ys[i]) / h[i] - (ys[i] - ys[i - 1]) / h[i - 1]) /
          (h[i - 1] + h[i]);
    }
    // Thomas algorithm on the tridiagonal system, with M_0 = M_{n-1} = 0.
    final m = Float64List(n);
    final cPrime = Float64List(n);
    final dPrime = Float64List(n);
    cPrime[1] = lambda[1] / 2.0;
    dPrime[1] = d[1] / 2.0;
    for (int i = 2; i < n - 1; i++) {
      final denom = 2.0 - mu[i] * cPrime[i - 1];
      cPrime[i] = lambda[i] / denom;
      dPrime[i] = (d[i] - mu[i] * dPrime[i - 1]) / denom;
    }
    if (n - 2 >= 1) {
      m[n - 2] = dPrime[n - 2];
      for (int i = n - 3; i >= 1; i--) {
        m[i] = dPrime[i] - cPrime[i] * m[i + 1];
      }
    }

    // Evaluate spline on the regular grid.
    final dt = 1.0 / fs;
    final out = <double>[];
    int j = 0;
    for (double x = xs[0]; x <= xs[n - 1]; x += dt) {
      while (j < n - 2 && xs[j + 1] < x) {
        j++;
      }
      final a = xs[j];
      final b = xs[j + 1];
      final hj = h[j];
      final ma = m[j];
      final mb = m[j + 1];
      final ya = ys[j];
      final yb = ys[j + 1];
      // Standard natural-spline piecewise formula.
      final t1 = ma * pow(b - x, 3) / (6 * hj);
      final t2 = mb * pow(x - a, 3) / (6 * hj);
      final t3 = (ya / hj - ma * hj / 6) * (b - x);
      final t4 = (yb / hj - mb * hj / 6) * (x - a);
      out.add(t1 + t2 + t3 + t4);
    }
    return Float64List.fromList(out);
  }

  /// In-place iterative radix-2 Cooley-Tukey FFT. Length must be a power
  /// of two. Output is `X[k]` in `re[k] + j·im[k]`.
  void _fftRadix2InPlace(Float64List re, Float64List im) {
    final n = re.length;
    // Bit-reversal permutation.
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    // Butterflies.
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * pi / len;
      final wRe = cos(ang);
      final wIm = sin(ang);
      for (int i = 0; i < n; i += len) {
        double wR = 1.0;
        double wI = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final iA = i + k;
          final iB = iA + len ~/ 2;
          final uR = re[iA];
          final uI = im[iA];
          final vR = re[iB] * wR - im[iB] * wI;
          final vI = re[iB] * wI + im[iB] * wR;
          re[iA] = uR + vR;
          im[iA] = uI + vI;
          re[iB] = uR - vR;
          im[iB] = uI - vI;
          final nextR = wR * wRe - wI * wIm;
          wI = wR * wIm + wI * wRe;
          wR = nextR;
        }
      }
    }
  }

  /// Trapezoidal integration of [psd] over `[fLow, fHigh)`, matching
  /// `numpy.trapz` with `numpy.logical_and(f>=fLow, f<fHigh)`.
  double _bandPower(
    Float64List freqs,
    Float64List psd,
    double fLow,
    double fHigh,
  ) {
    double total = 0;
    for (int i = 0; i < freqs.length - 1; i++) {
      if (freqs[i] >= fLow && freqs[i + 1] < fHigh) {
        total += 0.5 * (psd[i] + psd[i + 1]) * (freqs[i + 1] - freqs[i]);
      }
    }
    return total;
  }

  int _nextPow2(int n) {
    int p = 1;
    while (p < n) {
      p <<= 1;
    }
    return p;
  }
}

/// Result of [FrequencyDomainHrv.calculate]. All powers are absolute,
/// expressed in ms² (matches the canonical `hrvanalysis` library).
class FrequencyDomainMetrics {
  const FrequencyDomainMetrics({
    required this.lfPowerMs2,
    required this.hfPowerMs2,
    required this.lfHfRatio,
    required this.tachogramDurationS,
    required this.resampledSamples,
  });

  final double lfPowerMs2;
  final double hfPowerMs2;
  final double lfHfRatio;

  /// Duration of the input tachogram in seconds. Useful for callers
  /// that want to flag stability — anything under ~60 s is unstable
  /// for LF, anything under 25 s is rejected outright in `calculate`.
  final double tachogramDurationS;
  final int resampledSamples;
}
