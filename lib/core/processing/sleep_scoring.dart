import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/sleep.dart';

/// Composite sleep quality score (0-100). Direct port of the canonical
/// reference at `hlth_pipeline/features/recovery.py:sleep_score_from_stages`,
/// validated against the test fixtures in `notebooks/03_recovery_score.ipynb`.
///
/// Inputs (all already aggregated from a `SleepSession`):
///   * `totalSleepMin` — Total Sleep Time (TST), i.e. minutes asleep.
///   * `deepPct`       — Deep sleep as % of TST (0-100).
///   * `remPct`        — REM sleep as % of TST (0-100).
///   * `efficiencyPct` — Sleep efficiency = (asleep / time in bed) × 100.
///   * `latencyMin`    — Minutes from "in bed" to first sleep epoch.
///
/// Weights: duration 40%, deep 20%, REM 15%, efficiency 15%, latency 10%.
double sleepScoreFromStages({
  required int totalSleepMin,
  required double deepPct,
  required double remPct,
  required double efficiencyPct,
  required int latencyMin,
}) {
  // Duration: target 7-9 hours (420-540 min).
  final double duration;
  if (totalSleepMin < 360) {
    duration = 30;
  } else if (totalSleepMin < 420) {
    duration = 70;
  } else if (totalSleepMin <= 540) {
    duration = 100;
  } else if (totalSleepMin <= 600) {
    duration = 85;
  } else {
    duration = 70;
  }

  // Deep sleep: target 15-25%, peak at 20%.
  final deep = (deepPct >= 15 && deepPct <= 25)
      ? 100.0
      : (100 - 5 * (deepPct - 20).abs()).clamp(0.0, 100.0);

  // REM sleep: target 20-25%, peak at 22.5%.
  final rem = (remPct >= 20 && remPct <= 25)
      ? 100.0
      : (100 - 5 * (remPct - 22.5).abs()).clamp(0.0, 100.0);

  // Efficiency: target ≥85%; below 70% gets halved as a strong penalty.
  final efficiency = efficiencyPct >= 70
      ? (efficiencyPct + 15).clamp(0.0, 100.0)
      : (efficiencyPct * 0.5).clamp(0.0, 100.0);

  // Latency: target 10-20 min, insomnia threshold 40+.
  final double latency;
  if (latencyMin <= 20) {
    latency = 100;
  } else if (latencyMin <= 40) {
    latency = 70;
  } else {
    latency = (100.0 - 2 * latencyMin).clamp(0.0, 100.0);
  }

  final composite = 0.40 * duration +
      0.20 * deep +
      0.15 * rem +
      0.15 * efficiency +
      0.10 * latency;
  return composite.clamp(0.0, 100.0);
}

/// Minutes from session start to the first non-awake / non-unweared
/// epoch. Returns `null` when the session never enters a sleep stage
/// (e.g. the band was unworn through the whole window). Epochs are
/// assumed to be sorted by `startedAt` (matches what the adapter and
/// repository return).
int? sleepLatencyMin(SleepSession session, List<SleepEpoch> epochs) {
  for (final e in epochs) {
    if (e.stage == SleepStage.light ||
        e.stage == SleepStage.deep ||
        e.stage == SleepStage.rem) {
      final delta = e.startedAt.difference(session.startedAt);
      // Clamp at zero — band timestamps can drift a second or two
      // either side of the session boundary.
      final mins = delta.inMinutes;
      return mins < 0 ? 0 : mins;
    }
  }
  return null;
}
