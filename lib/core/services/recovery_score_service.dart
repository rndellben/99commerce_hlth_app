import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/scoring/recovery_stability.dart';

/// Computes and persists the daily Recovery / Stability score.
///
/// The validated engine (`recovery_stability.dart`) is treated as the source of
/// truth and is not modified — this service only ADAPTS our data into it:
/// each day's `daily_metrics` row is turned into a [RecoveryInput] (the stored
/// sleep stage %s + totals reconstruct the per-night sleep summary; the cardiac
/// / activity fields fill the metric map), reduced to a [RecoveryNightlyRecord],
/// then the trailing window is scored with [computeRecovery].
///
/// Triggered on the post-sleep sync tick (after [DailyAggregator] writes the
/// day's rollup), mirroring the engine's "end-of-sleep on wake" model.
class RecoveryScoreService {
  RecoveryScoreService({
    required this.dailyRepo,
    required this.scoreRepo,
    this.config = const RecoveryConfig(),
  });

  final DailyMetricsRepository dailyRepo;
  final ScoreRepository scoreRepo;
  final RecoveryConfig config;

  static const _algorithmVersion = 'recovery-stability-v2';

  /// How many trailing days to pull. Needs ≥14 valid for a full baseline plus
  /// the 4-night window; a few extra absorb non-worn / invalid nights.
  static const _historyDays = 20;

  /// Compute the Recovery score for [localDate] and persist it. Returns the
  /// persisted [Score], or null when there's no score to show (no data for the
  /// day, or no valid sleep last night).
  Future<Score?> computeForDay({
    required String userId,
    required DateTime localDate,
    int? ageYears,
    bool betaBlocker = false,
    double? lastNightWeight,
  }) async {
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final from = day.subtract(const Duration(days: _historyDays));

    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: from,
      toDate: day,
    );
    if (rows.isEmpty) return null;

    // Reduce every day in the window to a nightly record (ascending by date).
    final records = <RecoveryNightlyRecord>[];
    RecoveryNightlyRecord? tonight;
    final dayKey = _dateKey(day);
    for (final dm in rows) {
      final rec = reduceNight(_dateKey(dm.localDate), _inputFromDaily(dm),
          cfg: config);
      if (_dateKey(dm.localDate) == dayKey) {
        tonight = rec;
      } else if (dm.localDate.isBefore(day)) {
        records.add(rec);
      }
    }
    if (tonight == null) return null; // no rollup for the target day yet

    final bankedValid = records.where((r) => r.valid).length;
    final prev = await scoreRepo.getPrevious(
      userId: userId,
      scoreType: ScoreType.recovery,
      beforeDate: day,
    );

    final result = computeRecovery(
      history: records,
      tonight: tonight,
      bankedValidCount: bankedValid,
      ageYears: ageYears,
      betaBlocker: betaBlocker,
      previousDisplayedScore: prev?.score,
      lastNightWeight: lastNightWeight,
      cfg: config,
    );

    // No score to show: invalid sleep last night or no trustworthy signals.
    if (result.score == null) return null;

    final score = Score(
      id: ScoreRepository.idFor(userId, ScoreType.recovery, day),
      userId: userId,
      scoreType: ScoreType.recovery,
      computedForDate: day,
      score: result.score!,
      rawScore: result.rawScore,
      label: result.label,
      confidence: result.confidence,
      provisional: result.provisional,
      components: {
        for (final c in result.components.values) c.name: c.score,
      },
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    );
    await scoreRepo.upsert(score);
    return score;
  }

  String _dateKey(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Reconstruct the engine's per-night input from one `daily_metrics` row.
  /// Stage minutes are rebuilt from the stored fractions × total; awake /
  /// coverage-gap aren't stored daily, so coverage defaults to full and night
  /// validity rests on total-sleep + efficiency (the engine's other gates).
  RecoveryInput _inputFromDaily(DailyMetrics dm) {
    final total = dm.sleepTotalMin ?? 0;
    final deepMin = ((dm.sleepDeepPct ?? 0) * total).round();
    final lightMin = ((dm.sleepLightPct ?? 0) * total).round();
    final remMin = ((dm.sleepRemPct ?? 0) * total).round();
    final hasStage = dm.sleepDeepPct != null ||
        dm.sleepLightPct != null ||
        dm.sleepRemPct != null;
    final remAvail = dm.sleepRemPct != null;

    final sleep = SleepSessionLike(
      totalMin: total,
      deepMin: deepMin,
      lightMin: lightMin,
      remMin: remMin,
      efficiencyPct: dm.sleepEfficiencyPct, // stored 0–1; engine tolerates %
      protocolVersion: remAvail ? 2 : 1,
      hasStageDetail: hasStage,
    );

    final metrics = <String, double?>{
      MetricKeys.hrvRmssdMs: dm.hrvRmssdMs,
      MetricKeys.restingHrBpm: dm.restingHrBpm?.toDouble(),
      MetricKeys.respRateBpm: dm.restingRespRateBpm,
      MetricKeys.steps: dm.steps?.toDouble(),
      MetricKeys.activeMinutes: dm.activeMinutes?.toDouble(),
      // confidence / artifact inputs (optional — missing ones don't penalise)
      MetricKeys.hrvSdnnMs: dm.hrvSdnnMs,
      MetricKeys.rrIrregularityPct: dm.rrIrregularityPct,
      MetricKeys.ectopicPct: dm.ectopicBeatPct,
    };

    return RecoveryInput(
      sleep: sleep,
      metrics: metrics,
      ageYears: null,
      betaBlocker: false,
    );
  }
}

final recoveryScoreServiceProvider = Provider<RecoveryScoreService>((ref) {
  return RecoveryScoreService(
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    scoreRepo: ref.watch(scoreRepositoryProvider),
  );
});
