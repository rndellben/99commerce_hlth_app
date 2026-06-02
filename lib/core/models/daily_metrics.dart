import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'daily_metrics.freezed.dart';

/// hlth-db-schema.md §4.2 — derived per-user-per-day rollup.
@freezed
class DailyMetrics with _$DailyMetrics {
  const factory DailyMetrics({
    required String id,
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
    // Cardiac
    int? restingHrBpm,
    double? hrvRmssdMs,
    double? hrvSdnnMs,
    double? restingRespRateBpm,
    // SpO2
    double? spo2OvernightAvg,
    int? spo2OvernightMin,
    // BP
    int? systolicMmhg,
    int? diastolicMmhg,
    // Sleep
    int? sleepTotalMin,
    double? sleepDeepPct,
    double? sleepRemPct,
    double? sleepLightPct,
    double? sleepEfficiencyPct,
    DateTime? bedtime,
    DateTime? wake,
    // Activity
    int? steps,
    int? distanceM,
    double? caloriesKcal,
    int? activeMinutes,
    // Vascular / cardiac advanced
    double? stiffnessIndex,
    double? augmentationIndex,
    double? strokeVolumeIndex,
    double? breathingDisruptionsHr,
    // Scores (snapshots)
    int? recoveryScore,
    int? wellnessScore,
    // Cycle
    int? cyclePhase,
    // Provenance
    required DateTime computedAt,
    required String algorithmVersion,
    required DataSource source,
  }) = _DailyMetrics;
}
