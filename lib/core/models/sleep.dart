import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'sleep.freezed.dart';

/// hlth-db-schema.md §4.3.
@freezed
class SleepSession with _$SleepSession {
  const factory SleepSession({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int tzOffsetMin,
    required SleepSessionType type,
    required int protocolVersion,
    required int totalMin,
    @Default(0) int deepMin,
    @Default(0) int lightMin,
    @Default(0) int remMin,
    @Default(0) int awakeMin,
    @Default(0) int coverageGapMin,
    double? efficiencyPct,
    @Default(false) bool hasUnweared,
    required DataSource source,
  }) = _SleepSession;
}

/// hlth-db-schema.md §4.4.
@freezed
class SleepEpoch with _$SleepEpoch {
  const factory SleepEpoch({
    required String id,
    required String sessionId,
    required String userId,
    required DateTime startedAt,
    required int durationMin,
    required SleepStage stage,
    required DataSource source,
  }) = _SleepEpoch;
}
