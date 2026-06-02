// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Device {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String? get macAddress => throw _privateConstructorUsedError;
  String? get iosPeripheralUuid => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  String? get hardwareVersion => throw _privateConstructorUsedError;
  String? get firmwareVersion => throw _privateConstructorUsedError;
  String? get userIdOnBand => throw _privateConstructorUsedError;
  DateTime get pairedAt => throw _privateConstructorUsedError;
  DateTime? get lastConnectedAt => throw _privateConstructorUsedError;
  int? get lastBatteryPercent => throw _privateConstructorUsedError;
  bool? get lastCharging => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  Map<String, dynamic> get capabilities => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeviceCopyWith<Device> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeviceCopyWith<$Res> {
  factory $DeviceCopyWith(Device value, $Res Function(Device) then) =
      _$DeviceCopyWithImpl<$Res, Device>;
  @useResult
  $Res call({
    String id,
    String userId,
    String? macAddress,
    String? iosPeripheralUuid,
    String displayName,
    String? model,
    String? hardwareVersion,
    String? firmwareVersion,
    String? userIdOnBand,
    DateTime pairedAt,
    DateTime? lastConnectedAt,
    int? lastBatteryPercent,
    bool? lastCharging,
    bool isActive,
    Map<String, dynamic> capabilities,
    DateTime? deletedAt,
  });
}

/// @nodoc
class _$DeviceCopyWithImpl<$Res, $Val extends Device>
    implements $DeviceCopyWith<$Res> {
  _$DeviceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? macAddress = freezed,
    Object? iosPeripheralUuid = freezed,
    Object? displayName = null,
    Object? model = freezed,
    Object? hardwareVersion = freezed,
    Object? firmwareVersion = freezed,
    Object? userIdOnBand = freezed,
    Object? pairedAt = null,
    Object? lastConnectedAt = freezed,
    Object? lastBatteryPercent = freezed,
    Object? lastCharging = freezed,
    Object? isActive = null,
    Object? capabilities = null,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            macAddress: freezed == macAddress
                ? _value.macAddress
                : macAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
            iosPeripheralUuid: freezed == iosPeripheralUuid
                ? _value.iosPeripheralUuid
                : iosPeripheralUuid // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            hardwareVersion: freezed == hardwareVersion
                ? _value.hardwareVersion
                : hardwareVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
            firmwareVersion: freezed == firmwareVersion
                ? _value.firmwareVersion
                : firmwareVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
            userIdOnBand: freezed == userIdOnBand
                ? _value.userIdOnBand
                : userIdOnBand // ignore: cast_nullable_to_non_nullable
                      as String?,
            pairedAt: null == pairedAt
                ? _value.pairedAt
                : pairedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            lastConnectedAt: freezed == lastConnectedAt
                ? _value.lastConnectedAt
                : lastConnectedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastBatteryPercent: freezed == lastBatteryPercent
                ? _value.lastBatteryPercent
                : lastBatteryPercent // ignore: cast_nullable_to_non_nullable
                      as int?,
            lastCharging: freezed == lastCharging
                ? _value.lastCharging
                : lastCharging // ignore: cast_nullable_to_non_nullable
                      as bool?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            capabilities: null == capabilities
                ? _value.capabilities
                : capabilities // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            deletedAt: freezed == deletedAt
                ? _value.deletedAt
                : deletedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeviceImplCopyWith<$Res> implements $DeviceCopyWith<$Res> {
  factory _$$DeviceImplCopyWith(
    _$DeviceImpl value,
    $Res Function(_$DeviceImpl) then,
  ) = __$$DeviceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String? macAddress,
    String? iosPeripheralUuid,
    String displayName,
    String? model,
    String? hardwareVersion,
    String? firmwareVersion,
    String? userIdOnBand,
    DateTime pairedAt,
    DateTime? lastConnectedAt,
    int? lastBatteryPercent,
    bool? lastCharging,
    bool isActive,
    Map<String, dynamic> capabilities,
    DateTime? deletedAt,
  });
}

/// @nodoc
class __$$DeviceImplCopyWithImpl<$Res>
    extends _$DeviceCopyWithImpl<$Res, _$DeviceImpl>
    implements _$$DeviceImplCopyWith<$Res> {
  __$$DeviceImplCopyWithImpl(
    _$DeviceImpl _value,
    $Res Function(_$DeviceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? macAddress = freezed,
    Object? iosPeripheralUuid = freezed,
    Object? displayName = null,
    Object? model = freezed,
    Object? hardwareVersion = freezed,
    Object? firmwareVersion = freezed,
    Object? userIdOnBand = freezed,
    Object? pairedAt = null,
    Object? lastConnectedAt = freezed,
    Object? lastBatteryPercent = freezed,
    Object? lastCharging = freezed,
    Object? isActive = null,
    Object? capabilities = null,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _$DeviceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        macAddress: freezed == macAddress
            ? _value.macAddress
            : macAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
        iosPeripheralUuid: freezed == iosPeripheralUuid
            ? _value.iosPeripheralUuid
            : iosPeripheralUuid // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        hardwareVersion: freezed == hardwareVersion
            ? _value.hardwareVersion
            : hardwareVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
        firmwareVersion: freezed == firmwareVersion
            ? _value.firmwareVersion
            : firmwareVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
        userIdOnBand: freezed == userIdOnBand
            ? _value.userIdOnBand
            : userIdOnBand // ignore: cast_nullable_to_non_nullable
                  as String?,
        pairedAt: null == pairedAt
            ? _value.pairedAt
            : pairedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        lastConnectedAt: freezed == lastConnectedAt
            ? _value.lastConnectedAt
            : lastConnectedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastBatteryPercent: freezed == lastBatteryPercent
            ? _value.lastBatteryPercent
            : lastBatteryPercent // ignore: cast_nullable_to_non_nullable
                  as int?,
        lastCharging: freezed == lastCharging
            ? _value.lastCharging
            : lastCharging // ignore: cast_nullable_to_non_nullable
                  as bool?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        capabilities: null == capabilities
            ? _value._capabilities
            : capabilities // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$DeviceImpl implements _Device {
  const _$DeviceImpl({
    required this.id,
    required this.userId,
    this.macAddress,
    this.iosPeripheralUuid,
    required this.displayName,
    this.model,
    this.hardwareVersion,
    this.firmwareVersion,
    this.userIdOnBand,
    required this.pairedAt,
    this.lastConnectedAt,
    this.lastBatteryPercent,
    this.lastCharging,
    this.isActive = true,
    final Map<String, dynamic> capabilities = const {},
    this.deletedAt,
  }) : _capabilities = capabilities;

  @override
  final String id;
  @override
  final String userId;
  @override
  final String? macAddress;
  @override
  final String? iosPeripheralUuid;
  @override
  final String displayName;
  @override
  final String? model;
  @override
  final String? hardwareVersion;
  @override
  final String? firmwareVersion;
  @override
  final String? userIdOnBand;
  @override
  final DateTime pairedAt;
  @override
  final DateTime? lastConnectedAt;
  @override
  final int? lastBatteryPercent;
  @override
  final bool? lastCharging;
  @override
  @JsonKey()
  final bool isActive;
  final Map<String, dynamic> _capabilities;
  @override
  @JsonKey()
  Map<String, dynamic> get capabilities {
    if (_capabilities is EqualUnmodifiableMapView) return _capabilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_capabilities);
  }

  @override
  final DateTime? deletedAt;

  @override
  String toString() {
    return 'Device(id: $id, userId: $userId, macAddress: $macAddress, iosPeripheralUuid: $iosPeripheralUuid, displayName: $displayName, model: $model, hardwareVersion: $hardwareVersion, firmwareVersion: $firmwareVersion, userIdOnBand: $userIdOnBand, pairedAt: $pairedAt, lastConnectedAt: $lastConnectedAt, lastBatteryPercent: $lastBatteryPercent, lastCharging: $lastCharging, isActive: $isActive, capabilities: $capabilities, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeviceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.macAddress, macAddress) ||
                other.macAddress == macAddress) &&
            (identical(other.iosPeripheralUuid, iosPeripheralUuid) ||
                other.iosPeripheralUuid == iosPeripheralUuid) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.hardwareVersion, hardwareVersion) ||
                other.hardwareVersion == hardwareVersion) &&
            (identical(other.firmwareVersion, firmwareVersion) ||
                other.firmwareVersion == firmwareVersion) &&
            (identical(other.userIdOnBand, userIdOnBand) ||
                other.userIdOnBand == userIdOnBand) &&
            (identical(other.pairedAt, pairedAt) ||
                other.pairedAt == pairedAt) &&
            (identical(other.lastConnectedAt, lastConnectedAt) ||
                other.lastConnectedAt == lastConnectedAt) &&
            (identical(other.lastBatteryPercent, lastBatteryPercent) ||
                other.lastBatteryPercent == lastBatteryPercent) &&
            (identical(other.lastCharging, lastCharging) ||
                other.lastCharging == lastCharging) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality().equals(
              other._capabilities,
              _capabilities,
            ) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    macAddress,
    iosPeripheralUuid,
    displayName,
    model,
    hardwareVersion,
    firmwareVersion,
    userIdOnBand,
    pairedAt,
    lastConnectedAt,
    lastBatteryPercent,
    lastCharging,
    isActive,
    const DeepCollectionEquality().hash(_capabilities),
    deletedAt,
  );

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeviceImplCopyWith<_$DeviceImpl> get copyWith =>
      __$$DeviceImplCopyWithImpl<_$DeviceImpl>(this, _$identity);
}

abstract class _Device implements Device {
  const factory _Device({
    required final String id,
    required final String userId,
    final String? macAddress,
    final String? iosPeripheralUuid,
    required final String displayName,
    final String? model,
    final String? hardwareVersion,
    final String? firmwareVersion,
    final String? userIdOnBand,
    required final DateTime pairedAt,
    final DateTime? lastConnectedAt,
    final int? lastBatteryPercent,
    final bool? lastCharging,
    final bool isActive,
    final Map<String, dynamic> capabilities,
    final DateTime? deletedAt,
  }) = _$DeviceImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String? get macAddress;
  @override
  String? get iosPeripheralUuid;
  @override
  String get displayName;
  @override
  String? get model;
  @override
  String? get hardwareVersion;
  @override
  String? get firmwareVersion;
  @override
  String? get userIdOnBand;
  @override
  DateTime get pairedAt;
  @override
  DateTime? get lastConnectedAt;
  @override
  int? get lastBatteryPercent;
  @override
  bool? get lastCharging;
  @override
  bool get isActive;
  @override
  Map<String, dynamic> get capabilities;
  @override
  DateTime? get deletedAt;

  /// Create a copy of Device
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeviceImplCopyWith<_$DeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
