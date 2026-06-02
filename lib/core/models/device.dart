import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';

/// hlth-repository-api.md §3 / hlth-db-schema.md §2.1.
@freezed
class Device with _$Device {
  const factory Device({
    required String id,
    required String userId,
    String? macAddress,
    String? iosPeripheralUuid,
    required String displayName,
    String? model,
    String? hardwareVersion,
    String? firmwareVersion,
    String? userIdOnBand,
    required DateTime pairedAt,
    DateTime? lastConnectedAt,
    int? lastBatteryPercent,
    bool? lastCharging,
    @Default(true) bool isActive,
    @Default({}) Map<String, dynamic> capabilities,
    DateTime? deletedAt,
  }) = _Device;
}
