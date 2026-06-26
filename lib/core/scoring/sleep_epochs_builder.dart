import 'package:hlth_app/core/database/enums.dart' as dbenums;
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/scoring/vascular_load.dart' as vl;

/// Reconstructs the engine's per-epoch [vl.SleepEpochs] for one session.
///
/// We lay a 1-minute grid over [start, end). Each timestamped sample is
/// bucketed into the minute it falls in (mean if several land together),
/// every other epoch is NaN — so `reduceSession`'s `.isFinite` checks see
/// exactly the real samples, never fabricated fill. Stage per epoch comes
/// from the sleep_epochs spans. `motion` is false for every epoch: we have
/// no per-epoch motion signal, and the band's staging already routes gross
/// movement into `wake` (which the asleep mask drops). Documented limitation.
class SleepEpochsBuilder {
  static vl.SleepEpochs build({
    required DateTime start,
    required DateTime end,
    required List<SleepEpoch> stages,
    required List<HrSample> hr,
    required List<HrvSample> hrv,
    required List<StressSample> stress,
  }) {
    final totalMin = end.difference(start).inMinutes;
    final n = totalMin <= 0 ? 0 : totalMin;

    final hrOut = List<double>.filled(n, double.nan);
    final rmssdOut = List<double>.filled(n, double.nan);
    final stressOut = List<double>.filled(n, double.nan);
    final stageOut =
        List<vl.SleepStage>.filled(n, vl.SleepStage.wake);
    final motionOut = List<bool>.filled(n, false);

    int idxFor(DateTime t) => t.difference(start).inMinutes;

    // Stage: paint each epoch span onto the grid.
    for (final e in stages) {
      final from = idxFor(e.startedAt);
      final to = idxFor(e.startedAt.add(Duration(minutes: e.durationMin)));
      final s = _mapStage(e.stage);
      for (var i = from; i < to && i < n; i++) {
        if (i >= 0) stageOut[i] = s;
      }
    }

    // Samples: bucket-mean into the grid.
    _bucketMean(hr.map((s) => (s.capturedAt, s.bpm.toDouble())), start, n, hrOut);
    _bucketMean(
        hrv.map((s) => (s.capturedAt, s.rmssdMs)), start, n, rmssdOut);
    _bucketMean(
        stress.map((s) => (s.capturedAt, s.stressScore.toDouble())),
        start, n, stressOut);

    return vl.SleepEpochs(
      hr: hrOut,
      rmssd: rmssdOut,
      stage: stageOut,
      motion: motionOut,
      stress: stressOut,
      epochMinutes: 1.0,
    );
  }

  static void _bucketMean(
    Iterable<(DateTime, double)> samples,
    DateTime start,
    int n,
    List<double> out,
  ) {
    final sums = List<double>.filled(n, 0);
    final counts = List<int>.filled(n, 0);
    for (final (t, v) in samples) {
      if (!v.isFinite) continue;
      final i = t.difference(start).inMinutes;
      if (i < 0 || i >= n) continue;
      sums[i] += v;
      counts[i] += 1;
    }
    for (var i = 0; i < n; i++) {
      if (counts[i] > 0) out[i] = sums[i] / counts[i];
    }
  }

  static vl.SleepStage _mapStage(dbenums.SleepStage s) {
    switch (s) {
      case dbenums.SleepStage.deep:
        return vl.SleepStage.deep;
      case dbenums.SleepStage.light:
        return vl.SleepStage.light;
      case dbenums.SleepStage.rem:
        return vl.SleepStage.rem;
      default: // awake, noSleep, unweared → treated as wake (asleep mask drops)
        return vl.SleepStage.wake;
    }
  }
}
