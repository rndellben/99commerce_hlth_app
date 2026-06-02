import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hlth_app/core/database/enums.dart';

part 'health_samples.freezed.dart';

/// hlth-repository-api.md §3 — single-channel HR sample.
/// hlth-db-schema.md §3.1.
@freezed
class HrSample with _$HrSample {
  const factory HrSample({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime capturedAt,
    required int tzOffsetMin,
    required int bpm,
    required int intervalMin,
    required bool isResting,
    required DataSource source,
    int? quality,
    String? algorithmVersion,
  }) = _HrSample;
}

/// hlth-db-schema.md §3.2.
@freezed
class HrvSample with _$HrvSample {
  const factory HrvSample({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime capturedAt,
    required int tzOffsetMin,
    required double rmssdMs,
    double? sdnnMs,
    double? pnn50Pct,
    int? meanHrBpm,
    int? beatCount,
    required DataSource source,
    int? quality,
    String? algorithmVersion,
  }) = _HrvSample;
}

/// hlth-db-schema.md §3.4.
@freezed
class Spo2Sample with _$Spo2Sample {
  const factory Spo2Sample({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime capturedAt,
    required int tzOffsetMin,
    required int pctMin,
    required int pctMax,
    required int bucketMin,
    required DataSource source,
    int? quality,
    String? algorithmVersion,
  }) = _Spo2Sample;
}

/// hlth-db-schema.md §3.5.
@freezed
class BpReading with _$BpReading {
  const factory BpReading({
    required String id,
    required String userId,
    required String deviceId,
    required DateTime capturedAt,
    required int tzOffsetMin,
    required int systolicMmhg,
    required int diastolicMmhg,
    int? pulseBpm,
    required BpDerivation derivation,
    int? position,
    required DataSource source,
    int? quality,
    String? algorithmVersion,
  }) = _BpReading;
}
