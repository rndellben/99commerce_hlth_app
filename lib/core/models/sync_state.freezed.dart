// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SyncState {
  String get id => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  String get metricKey => throw _privateConstructorUsedError;
  DateTime? get lastSuccessfulSync => throw _privateConstructorUsedError;
  DateTime? get lastAttemptedSync => throw _privateConstructorUsedError;
  String? get lastSyncError => throw _privateConstructorUsedError;
  int? get lastSyncedDayIndex => throw _privateConstructorUsedError;
  int get bytesSyncedLifetime => throw _privateConstructorUsedError;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncStateCopyWith<SyncState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncStateCopyWith<$Res> {
  factory $SyncStateCopyWith(SyncState value, $Res Function(SyncState) then) =
      _$SyncStateCopyWithImpl<$Res, SyncState>;
  @useResult
  $Res call({
    String id,
    String deviceId,
    String metricKey,
    DateTime? lastSuccessfulSync,
    DateTime? lastAttemptedSync,
    String? lastSyncError,
    int? lastSyncedDayIndex,
    int bytesSyncedLifetime,
  });
}

/// @nodoc
class _$SyncStateCopyWithImpl<$Res, $Val extends SyncState>
    implements $SyncStateCopyWith<$Res> {
  _$SyncStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceId = null,
    Object? metricKey = null,
    Object? lastSuccessfulSync = freezed,
    Object? lastAttemptedSync = freezed,
    Object? lastSyncError = freezed,
    Object? lastSyncedDayIndex = freezed,
    Object? bytesSyncedLifetime = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            deviceId: null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            metricKey: null == metricKey
                ? _value.metricKey
                : metricKey // ignore: cast_nullable_to_non_nullable
                      as String,
            lastSuccessfulSync: freezed == lastSuccessfulSync
                ? _value.lastSuccessfulSync
                : lastSuccessfulSync // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastAttemptedSync: freezed == lastAttemptedSync
                ? _value.lastAttemptedSync
                : lastAttemptedSync // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            lastSyncError: freezed == lastSyncError
                ? _value.lastSyncError
                : lastSyncError // ignore: cast_nullable_to_non_nullable
                      as String?,
            lastSyncedDayIndex: freezed == lastSyncedDayIndex
                ? _value.lastSyncedDayIndex
                : lastSyncedDayIndex // ignore: cast_nullable_to_non_nullable
                      as int?,
            bytesSyncedLifetime: null == bytesSyncedLifetime
                ? _value.bytesSyncedLifetime
                : bytesSyncedLifetime // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncStateImplCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory _$$SyncStateImplCopyWith(
    _$SyncStateImpl value,
    $Res Function(_$SyncStateImpl) then,
  ) = __$$SyncStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String deviceId,
    String metricKey,
    DateTime? lastSuccessfulSync,
    DateTime? lastAttemptedSync,
    String? lastSyncError,
    int? lastSyncedDayIndex,
    int bytesSyncedLifetime,
  });
}

/// @nodoc
class __$$SyncStateImplCopyWithImpl<$Res>
    extends _$SyncStateCopyWithImpl<$Res, _$SyncStateImpl>
    implements _$$SyncStateImplCopyWith<$Res> {
  __$$SyncStateImplCopyWithImpl(
    _$SyncStateImpl _value,
    $Res Function(_$SyncStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? deviceId = null,
    Object? metricKey = null,
    Object? lastSuccessfulSync = freezed,
    Object? lastAttemptedSync = freezed,
    Object? lastSyncError = freezed,
    Object? lastSyncedDayIndex = freezed,
    Object? bytesSyncedLifetime = null,
  }) {
    return _then(
      _$SyncStateImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceId: null == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        metricKey: null == metricKey
            ? _value.metricKey
            : metricKey // ignore: cast_nullable_to_non_nullable
                  as String,
        lastSuccessfulSync: freezed == lastSuccessfulSync
            ? _value.lastSuccessfulSync
            : lastSuccessfulSync // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastAttemptedSync: freezed == lastAttemptedSync
            ? _value.lastAttemptedSync
            : lastAttemptedSync // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        lastSyncError: freezed == lastSyncError
            ? _value.lastSyncError
            : lastSyncError // ignore: cast_nullable_to_non_nullable
                  as String?,
        lastSyncedDayIndex: freezed == lastSyncedDayIndex
            ? _value.lastSyncedDayIndex
            : lastSyncedDayIndex // ignore: cast_nullable_to_non_nullable
                  as int?,
        bytesSyncedLifetime: null == bytesSyncedLifetime
            ? _value.bytesSyncedLifetime
            : bytesSyncedLifetime // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$SyncStateImpl implements _SyncState {
  const _$SyncStateImpl({
    required this.id,
    required this.deviceId,
    required this.metricKey,
    this.lastSuccessfulSync,
    this.lastAttemptedSync,
    this.lastSyncError,
    this.lastSyncedDayIndex,
    this.bytesSyncedLifetime = 0,
  });

  @override
  final String id;
  @override
  final String deviceId;
  @override
  final String metricKey;
  @override
  final DateTime? lastSuccessfulSync;
  @override
  final DateTime? lastAttemptedSync;
  @override
  final String? lastSyncError;
  @override
  final int? lastSyncedDayIndex;
  @override
  @JsonKey()
  final int bytesSyncedLifetime;

  @override
  String toString() {
    return 'SyncState(id: $id, deviceId: $deviceId, metricKey: $metricKey, lastSuccessfulSync: $lastSuccessfulSync, lastAttemptedSync: $lastAttemptedSync, lastSyncError: $lastSyncError, lastSyncedDayIndex: $lastSyncedDayIndex, bytesSyncedLifetime: $bytesSyncedLifetime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncStateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.metricKey, metricKey) ||
                other.metricKey == metricKey) &&
            (identical(other.lastSuccessfulSync, lastSuccessfulSync) ||
                other.lastSuccessfulSync == lastSuccessfulSync) &&
            (identical(other.lastAttemptedSync, lastAttemptedSync) ||
                other.lastAttemptedSync == lastAttemptedSync) &&
            (identical(other.lastSyncError, lastSyncError) ||
                other.lastSyncError == lastSyncError) &&
            (identical(other.lastSyncedDayIndex, lastSyncedDayIndex) ||
                other.lastSyncedDayIndex == lastSyncedDayIndex) &&
            (identical(other.bytesSyncedLifetime, bytesSyncedLifetime) ||
                other.bytesSyncedLifetime == bytesSyncedLifetime));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    deviceId,
    metricKey,
    lastSuccessfulSync,
    lastAttemptedSync,
    lastSyncError,
    lastSyncedDayIndex,
    bytesSyncedLifetime,
  );

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncStateImplCopyWith<_$SyncStateImpl> get copyWith =>
      __$$SyncStateImplCopyWithImpl<_$SyncStateImpl>(this, _$identity);
}

abstract class _SyncState implements SyncState {
  const factory _SyncState({
    required final String id,
    required final String deviceId,
    required final String metricKey,
    final DateTime? lastSuccessfulSync,
    final DateTime? lastAttemptedSync,
    final String? lastSyncError,
    final int? lastSyncedDayIndex,
    final int bytesSyncedLifetime,
  }) = _$SyncStateImpl;

  @override
  String get id;
  @override
  String get deviceId;
  @override
  String get metricKey;
  @override
  DateTime? get lastSuccessfulSync;
  @override
  DateTime? get lastAttemptedSync;
  @override
  String? get lastSyncError;
  @override
  int? get lastSyncedDayIndex;
  @override
  int get bytesSyncedLifetime;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncStateImplCopyWith<_$SyncStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
