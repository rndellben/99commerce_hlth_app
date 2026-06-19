import 'package:freezed_annotation/freezed_annotation.dart';

part 'bp_calibration.freezed.dart';

/// User-entered cuff reading used to anchor the band's HR→BP estimate.
/// hlth-db-schema.md §6.2.
///
/// Only one calibration per user is `isActive` at a time. New active rows
/// supersede older ones — older rows stay so historical `bp_readings`
/// can still resolve `calibrated_against_id`.
@freezed
class BpCalibration with _$BpCalibration {
  const factory BpCalibration({
    required String id,
    required String userId,
    required DateTime capturedAt,
    required int cuffSystolic,
    required int cuffDiastolic,
    int? bandSystolic,
    int? bandDiastolic,
    int? hrAtCalibration,
    int? ageAtCalibration,
    @Default(false) bool bandWriteSucceeded,
    String? notes,
    @Default(true) bool isActive,
    required DateTime createdAt,
  }) = _BpCalibration;
}
