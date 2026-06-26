import 'package:freezed_annotation/freezed_annotation.dart';

part 'nightly_record_row.freezed.dart';

/// Persisted form of Ryan's engine `NightlyRecord` (NIGHTLY_RECORD_SCHEMA.md).
@freezed
class NightlyRecordRow with _$NightlyRecordRow {
  const factory NightlyRecordRow({
    required String id,
    required String userId,
    required DateTime localDate,
    double? hrP5,
    double? rmssdMedian,
    double? stressMean,
    required double coverage,
    required bool valid,
    required DateTime computedAt,
    required String algorithmVersion,
  }) = _NightlyRecordRow;
}
