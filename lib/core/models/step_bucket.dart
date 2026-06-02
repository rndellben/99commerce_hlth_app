import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'step_bucket.freezed.dart';

/// hlth-db-schema.md §4.1 — 15-minute step bucket.
@freezed
class StepBucket with _$StepBucket {
  const factory StepBucket({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime bucketStartAt,
    required int tzOffsetMin,
    required int steps,
    required int distanceM,
    required double caloriesKcal,
    @Default(0) int runSteps,
    required DataSource source,
  }) = _StepBucket;
}
