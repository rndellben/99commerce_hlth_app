import 'package:freezed_annotation/freezed_annotation.dart';

part 'baseline.freezed.dart';

/// hlth-db-schema.md §6.1 — rolling baseline (14/30/90-day window).
@freezed
class Baseline with _$Baseline {
  const factory Baseline({
    required String id,
    required String userId,
    required String metricKey,
    required int windowDays,
    required DateTime computedForDate,
    required double meanValue,
    required double stddevValue,
    required int sampleCount,
    required DateTime computedAt,
    required String algorithmVersion,
  }) = _Baseline;
}
