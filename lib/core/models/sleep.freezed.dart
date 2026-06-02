// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sleep.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SleepSession {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  DateTime get endedAt => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError;
  SleepSessionType get type => throw _privateConstructorUsedError;
  int get protocolVersion => throw _privateConstructorUsedError;
  int get totalMin => throw _privateConstructorUsedError;
  int get deepMin => throw _privateConstructorUsedError;
  int get lightMin => throw _privateConstructorUsedError;
  int get remMin => throw _privateConstructorUsedError;
  int get awakeMin => throw _privateConstructorUsedError;
  int get coverageGapMin => throw _privateConstructorUsedError;
  double? get efficiencyPct => throw _privateConstructorUsedError;
  bool get hasUnweared => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;

  /// Create a copy of SleepSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SleepSessionCopyWith<SleepSession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SleepSessionCopyWith<$Res> {
  factory $SleepSessionCopyWith(
    SleepSession value,
    $Res Function(SleepSession) then,
  ) = _$SleepSessionCopyWithImpl<$Res, SleepSession>;
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime startedAt,
    DateTime endedAt,
    int tzOffsetMin,
    SleepSessionType type,
    int protocolVersion,
    int totalMin,
    int deepMin,
    int lightMin,
    int remMin,
    int awakeMin,
    int coverageGapMin,
    double? efficiencyPct,
    bool hasUnweared,
    DataSource source,
  });
}

/// @nodoc
class _$SleepSessionCopyWithImpl<$Res, $Val extends SleepSession>
    implements $SleepSessionCopyWith<$Res> {
  _$SleepSessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SleepSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? startedAt = null,
    Object? endedAt = null,
    Object? tzOffsetMin = null,
    Object? type = null,
    Object? protocolVersion = null,
    Object? totalMin = null,
    Object? deepMin = null,
    Object? lightMin = null,
    Object? remMin = null,
    Object? awakeMin = null,
    Object? coverageGapMin = null,
    Object? efficiencyPct = freezed,
    Object? hasUnweared = null,
    Object? source = null,
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
            deviceId: null == deviceId
                ? _value.deviceId
                : deviceId // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endedAt: null == endedAt
                ? _value.endedAt
                : endedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as SleepSessionType,
            protocolVersion: null == protocolVersion
                ? _value.protocolVersion
                : protocolVersion // ignore: cast_nullable_to_non_nullable
                      as int,
            totalMin: null == totalMin
                ? _value.totalMin
                : totalMin // ignore: cast_nullable_to_non_nullable
                      as int,
            deepMin: null == deepMin
                ? _value.deepMin
                : deepMin // ignore: cast_nullable_to_non_nullable
                      as int,
            lightMin: null == lightMin
                ? _value.lightMin
                : lightMin // ignore: cast_nullable_to_non_nullable
                      as int,
            remMin: null == remMin
                ? _value.remMin
                : remMin // ignore: cast_nullable_to_non_nullable
                      as int,
            awakeMin: null == awakeMin
                ? _value.awakeMin
                : awakeMin // ignore: cast_nullable_to_non_nullable
                      as int,
            coverageGapMin: null == coverageGapMin
                ? _value.coverageGapMin
                : coverageGapMin // ignore: cast_nullable_to_non_nullable
                      as int,
            efficiencyPct: freezed == efficiencyPct
                ? _value.efficiencyPct
                : efficiencyPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            hasUnweared: null == hasUnweared
                ? _value.hasUnweared
                : hasUnweared // ignore: cast_nullable_to_non_nullable
                      as bool,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SleepSessionImplCopyWith<$Res>
    implements $SleepSessionCopyWith<$Res> {
  factory _$$SleepSessionImplCopyWith(
    _$SleepSessionImpl value,
    $Res Function(_$SleepSessionImpl) then,
  ) = __$$SleepSessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime startedAt,
    DateTime endedAt,
    int tzOffsetMin,
    SleepSessionType type,
    int protocolVersion,
    int totalMin,
    int deepMin,
    int lightMin,
    int remMin,
    int awakeMin,
    int coverageGapMin,
    double? efficiencyPct,
    bool hasUnweared,
    DataSource source,
  });
}

/// @nodoc
class __$$SleepSessionImplCopyWithImpl<$Res>
    extends _$SleepSessionCopyWithImpl<$Res, _$SleepSessionImpl>
    implements _$$SleepSessionImplCopyWith<$Res> {
  __$$SleepSessionImplCopyWithImpl(
    _$SleepSessionImpl _value,
    $Res Function(_$SleepSessionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SleepSession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? startedAt = null,
    Object? endedAt = null,
    Object? tzOffsetMin = null,
    Object? type = null,
    Object? protocolVersion = null,
    Object? totalMin = null,
    Object? deepMin = null,
    Object? lightMin = null,
    Object? remMin = null,
    Object? awakeMin = null,
    Object? coverageGapMin = null,
    Object? efficiencyPct = freezed,
    Object? hasUnweared = null,
    Object? source = null,
  }) {
    return _then(
      _$SleepSessionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceId: null == deviceId
            ? _value.deviceId
            : deviceId // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endedAt: null == endedAt
            ? _value.endedAt
            : endedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as SleepSessionType,
        protocolVersion: null == protocolVersion
            ? _value.protocolVersion
            : protocolVersion // ignore: cast_nullable_to_non_nullable
                  as int,
        totalMin: null == totalMin
            ? _value.totalMin
            : totalMin // ignore: cast_nullable_to_non_nullable
                  as int,
        deepMin: null == deepMin
            ? _value.deepMin
            : deepMin // ignore: cast_nullable_to_non_nullable
                  as int,
        lightMin: null == lightMin
            ? _value.lightMin
            : lightMin // ignore: cast_nullable_to_non_nullable
                  as int,
        remMin: null == remMin
            ? _value.remMin
            : remMin // ignore: cast_nullable_to_non_nullable
                  as int,
        awakeMin: null == awakeMin
            ? _value.awakeMin
            : awakeMin // ignore: cast_nullable_to_non_nullable
                  as int,
        coverageGapMin: null == coverageGapMin
            ? _value.coverageGapMin
            : coverageGapMin // ignore: cast_nullable_to_non_nullable
                  as int,
        efficiencyPct: freezed == efficiencyPct
            ? _value.efficiencyPct
            : efficiencyPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        hasUnweared: null == hasUnweared
            ? _value.hasUnweared
            : hasUnweared // ignore: cast_nullable_to_non_nullable
                  as bool,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
      ),
    );
  }
}

/// @nodoc

class _$SleepSessionImpl implements _SleepSession {
  const _$SleepSessionImpl({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.startedAt,
    required this.endedAt,
    required this.tzOffsetMin,
    required this.type,
    required this.protocolVersion,
    required this.totalMin,
    this.deepMin = 0,
    this.lightMin = 0,
    this.remMin = 0,
    this.awakeMin = 0,
    this.coverageGapMin = 0,
    this.efficiencyPct,
    this.hasUnweared = false,
    required this.source,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String deviceId;
  @override
  final DateTime startedAt;
  @override
  final DateTime endedAt;
  @override
  final int tzOffsetMin;
  @override
  final SleepSessionType type;
  @override
  final int protocolVersion;
  @override
  final int totalMin;
  @override
  @JsonKey()
  final int deepMin;
  @override
  @JsonKey()
  final int lightMin;
  @override
  @JsonKey()
  final int remMin;
  @override
  @JsonKey()
  final int awakeMin;
  @override
  @JsonKey()
  final int coverageGapMin;
  @override
  final double? efficiencyPct;
  @override
  @JsonKey()
  final bool hasUnweared;
  @override
  final DataSource source;

  @override
  String toString() {
    return 'SleepSession(id: $id, userId: $userId, deviceId: $deviceId, startedAt: $startedAt, endedAt: $endedAt, tzOffsetMin: $tzOffsetMin, type: $type, protocolVersion: $protocolVersion, totalMin: $totalMin, deepMin: $deepMin, lightMin: $lightMin, remMin: $remMin, awakeMin: $awakeMin, coverageGapMin: $coverageGapMin, efficiencyPct: $efficiencyPct, hasUnweared: $hasUnweared, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SleepSessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.endedAt, endedAt) || other.endedAt == endedAt) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.protocolVersion, protocolVersion) ||
                other.protocolVersion == protocolVersion) &&
            (identical(other.totalMin, totalMin) ||
                other.totalMin == totalMin) &&
            (identical(other.deepMin, deepMin) || other.deepMin == deepMin) &&
            (identical(other.lightMin, lightMin) ||
                other.lightMin == lightMin) &&
            (identical(other.remMin, remMin) || other.remMin == remMin) &&
            (identical(other.awakeMin, awakeMin) ||
                other.awakeMin == awakeMin) &&
            (identical(other.coverageGapMin, coverageGapMin) ||
                other.coverageGapMin == coverageGapMin) &&
            (identical(other.efficiencyPct, efficiencyPct) ||
                other.efficiencyPct == efficiencyPct) &&
            (identical(other.hasUnweared, hasUnweared) ||
                other.hasUnweared == hasUnweared) &&
            (identical(other.source, source) || other.source == source));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceId,
    startedAt,
    endedAt,
    tzOffsetMin,
    type,
    protocolVersion,
    totalMin,
    deepMin,
    lightMin,
    remMin,
    awakeMin,
    coverageGapMin,
    efficiencyPct,
    hasUnweared,
    source,
  );

  /// Create a copy of SleepSession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SleepSessionImplCopyWith<_$SleepSessionImpl> get copyWith =>
      __$$SleepSessionImplCopyWithImpl<_$SleepSessionImpl>(this, _$identity);
}

abstract class _SleepSession implements SleepSession {
  const factory _SleepSession({
    required final String id,
    required final String userId,
    required final String deviceId,
    required final DateTime startedAt,
    required final DateTime endedAt,
    required final int tzOffsetMin,
    required final SleepSessionType type,
    required final int protocolVersion,
    required final int totalMin,
    final int deepMin,
    final int lightMin,
    final int remMin,
    final int awakeMin,
    final int coverageGapMin,
    final double? efficiencyPct,
    final bool hasUnweared,
    required final DataSource source,
  }) = _$SleepSessionImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get deviceId;
  @override
  DateTime get startedAt;
  @override
  DateTime get endedAt;
  @override
  int get tzOffsetMin;
  @override
  SleepSessionType get type;
  @override
  int get protocolVersion;
  @override
  int get totalMin;
  @override
  int get deepMin;
  @override
  int get lightMin;
  @override
  int get remMin;
  @override
  int get awakeMin;
  @override
  int get coverageGapMin;
  @override
  double? get efficiencyPct;
  @override
  bool get hasUnweared;
  @override
  DataSource get source;

  /// Create a copy of SleepSession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SleepSessionImplCopyWith<_$SleepSessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SleepEpoch {
  String get id => throw _privateConstructorUsedError;
  String get sessionId => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  DateTime get startedAt => throw _privateConstructorUsedError;
  int get durationMin => throw _privateConstructorUsedError;
  SleepStage get stage => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;

  /// Create a copy of SleepEpoch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SleepEpochCopyWith<SleepEpoch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SleepEpochCopyWith<$Res> {
  factory $SleepEpochCopyWith(
    SleepEpoch value,
    $Res Function(SleepEpoch) then,
  ) = _$SleepEpochCopyWithImpl<$Res, SleepEpoch>;
  @useResult
  $Res call({
    String id,
    String sessionId,
    String userId,
    DateTime startedAt,
    int durationMin,
    SleepStage stage,
    DataSource source,
  });
}

/// @nodoc
class _$SleepEpochCopyWithImpl<$Res, $Val extends SleepEpoch>
    implements $SleepEpochCopyWith<$Res> {
  _$SleepEpochCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SleepEpoch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? userId = null,
    Object? startedAt = null,
    Object? durationMin = null,
    Object? stage = null,
    Object? source = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            sessionId: null == sessionId
                ? _value.sessionId
                : sessionId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            startedAt: null == startedAt
                ? _value.startedAt
                : startedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            durationMin: null == durationMin
                ? _value.durationMin
                : durationMin // ignore: cast_nullable_to_non_nullable
                      as int,
            stage: null == stage
                ? _value.stage
                : stage // ignore: cast_nullable_to_non_nullable
                      as SleepStage,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SleepEpochImplCopyWith<$Res>
    implements $SleepEpochCopyWith<$Res> {
  factory _$$SleepEpochImplCopyWith(
    _$SleepEpochImpl value,
    $Res Function(_$SleepEpochImpl) then,
  ) = __$$SleepEpochImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String sessionId,
    String userId,
    DateTime startedAt,
    int durationMin,
    SleepStage stage,
    DataSource source,
  });
}

/// @nodoc
class __$$SleepEpochImplCopyWithImpl<$Res>
    extends _$SleepEpochCopyWithImpl<$Res, _$SleepEpochImpl>
    implements _$$SleepEpochImplCopyWith<$Res> {
  __$$SleepEpochImplCopyWithImpl(
    _$SleepEpochImpl _value,
    $Res Function(_$SleepEpochImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SleepEpoch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? sessionId = null,
    Object? userId = null,
    Object? startedAt = null,
    Object? durationMin = null,
    Object? stage = null,
    Object? source = null,
  }) {
    return _then(
      _$SleepEpochImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        sessionId: null == sessionId
            ? _value.sessionId
            : sessionId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        startedAt: null == startedAt
            ? _value.startedAt
            : startedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        durationMin: null == durationMin
            ? _value.durationMin
            : durationMin // ignore: cast_nullable_to_non_nullable
                  as int,
        stage: null == stage
            ? _value.stage
            : stage // ignore: cast_nullable_to_non_nullable
                  as SleepStage,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
      ),
    );
  }
}

/// @nodoc

class _$SleepEpochImpl implements _SleepEpoch {
  const _$SleepEpochImpl({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.startedAt,
    required this.durationMin,
    required this.stage,
    required this.source,
  });

  @override
  final String id;
  @override
  final String sessionId;
  @override
  final String userId;
  @override
  final DateTime startedAt;
  @override
  final int durationMin;
  @override
  final SleepStage stage;
  @override
  final DataSource source;

  @override
  String toString() {
    return 'SleepEpoch(id: $id, sessionId: $sessionId, userId: $userId, startedAt: $startedAt, durationMin: $durationMin, stage: $stage, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SleepEpochImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.sessionId, sessionId) ||
                other.sessionId == sessionId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.durationMin, durationMin) ||
                other.durationMin == durationMin) &&
            (identical(other.stage, stage) || other.stage == stage) &&
            (identical(other.source, source) || other.source == source));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    sessionId,
    userId,
    startedAt,
    durationMin,
    stage,
    source,
  );

  /// Create a copy of SleepEpoch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SleepEpochImplCopyWith<_$SleepEpochImpl> get copyWith =>
      __$$SleepEpochImplCopyWithImpl<_$SleepEpochImpl>(this, _$identity);
}

abstract class _SleepEpoch implements SleepEpoch {
  const factory _SleepEpoch({
    required final String id,
    required final String sessionId,
    required final String userId,
    required final DateTime startedAt,
    required final int durationMin,
    required final SleepStage stage,
    required final DataSource source,
  }) = _$SleepEpochImpl;

  @override
  String get id;
  @override
  String get sessionId;
  @override
  String get userId;
  @override
  DateTime get startedAt;
  @override
  int get durationMin;
  @override
  SleepStage get stage;
  @override
  DataSource get source;

  /// Create a copy of SleepEpoch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SleepEpochImplCopyWith<_$SleepEpochImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
