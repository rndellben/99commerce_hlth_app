// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'health_samples.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$HrSample {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  DateTime get capturedAt => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError;
  int get bpm => throw _privateConstructorUsedError;
  int get intervalMin => throw _privateConstructorUsedError;
  bool get isResting => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;
  int? get quality => throw _privateConstructorUsedError;
  String? get algorithmVersion => throw _privateConstructorUsedError;

  /// Create a copy of HrSample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HrSampleCopyWith<HrSample> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HrSampleCopyWith<$Res> {
  factory $HrSampleCopyWith(HrSample value, $Res Function(HrSample) then) =
      _$HrSampleCopyWithImpl<$Res, HrSample>;
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int bpm,
    int intervalMin,
    bool isResting,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class _$HrSampleCopyWithImpl<$Res, $Val extends HrSample>
    implements $HrSampleCopyWith<$Res> {
  _$HrSampleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HrSample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? bpm = null,
    Object? intervalMin = null,
    Object? isResting = null,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
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
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            bpm: null == bpm
                ? _value.bpm
                : bpm // ignore: cast_nullable_to_non_nullable
                      as int,
            intervalMin: null == intervalMin
                ? _value.intervalMin
                : intervalMin // ignore: cast_nullable_to_non_nullable
                      as int,
            isResting: null == isResting
                ? _value.isResting
                : isResting // ignore: cast_nullable_to_non_nullable
                      as bool,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
            quality: freezed == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                      as int?,
            algorithmVersion: freezed == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HrSampleImplCopyWith<$Res>
    implements $HrSampleCopyWith<$Res> {
  factory _$$HrSampleImplCopyWith(
    _$HrSampleImpl value,
    $Res Function(_$HrSampleImpl) then,
  ) = __$$HrSampleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int bpm,
    int intervalMin,
    bool isResting,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class __$$HrSampleImplCopyWithImpl<$Res>
    extends _$HrSampleCopyWithImpl<$Res, _$HrSampleImpl>
    implements _$$HrSampleImplCopyWith<$Res> {
  __$$HrSampleImplCopyWithImpl(
    _$HrSampleImpl _value,
    $Res Function(_$HrSampleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HrSample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? bpm = null,
    Object? intervalMin = null,
    Object? isResting = null,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
  }) {
    return _then(
      _$HrSampleImpl(
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
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        bpm: null == bpm
            ? _value.bpm
            : bpm // ignore: cast_nullable_to_non_nullable
                  as int,
        intervalMin: null == intervalMin
            ? _value.intervalMin
            : intervalMin // ignore: cast_nullable_to_non_nullable
                  as int,
        isResting: null == isResting
            ? _value.isResting
            : isResting // ignore: cast_nullable_to_non_nullable
                  as bool,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
        quality: freezed == quality
            ? _value.quality
            : quality // ignore: cast_nullable_to_non_nullable
                  as int?,
        algorithmVersion: freezed == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$HrSampleImpl implements _HrSample {
  const _$HrSampleImpl({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAt,
    required this.tzOffsetMin,
    required this.bpm,
    required this.intervalMin,
    required this.isResting,
    required this.source,
    this.quality,
    this.algorithmVersion,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String deviceId;
  @override
  final DateTime capturedAt;
  @override
  final int tzOffsetMin;
  @override
  final int bpm;
  @override
  final int intervalMin;
  @override
  final bool isResting;
  @override
  final DataSource source;
  @override
  final int? quality;
  @override
  final String? algorithmVersion;

  @override
  String toString() {
    return 'HrSample(id: $id, userId: $userId, deviceId: $deviceId, capturedAt: $capturedAt, tzOffsetMin: $tzOffsetMin, bpm: $bpm, intervalMin: $intervalMin, isResting: $isResting, source: $source, quality: $quality, algorithmVersion: $algorithmVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HrSampleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.bpm, bpm) || other.bpm == bpm) &&
            (identical(other.intervalMin, intervalMin) ||
                other.intervalMin == intervalMin) &&
            (identical(other.isResting, isResting) ||
                other.isResting == isResting) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceId,
    capturedAt,
    tzOffsetMin,
    bpm,
    intervalMin,
    isResting,
    source,
    quality,
    algorithmVersion,
  );

  /// Create a copy of HrSample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HrSampleImplCopyWith<_$HrSampleImpl> get copyWith =>
      __$$HrSampleImplCopyWithImpl<_$HrSampleImpl>(this, _$identity);
}

abstract class _HrSample implements HrSample {
  const factory _HrSample({
    required final String id,
    required final String userId,
    required final String deviceId,
    required final DateTime capturedAt,
    required final int tzOffsetMin,
    required final int bpm,
    required final int intervalMin,
    required final bool isResting,
    required final DataSource source,
    final int? quality,
    final String? algorithmVersion,
  }) = _$HrSampleImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get deviceId;
  @override
  DateTime get capturedAt;
  @override
  int get tzOffsetMin;
  @override
  int get bpm;
  @override
  int get intervalMin;
  @override
  bool get isResting;
  @override
  DataSource get source;
  @override
  int? get quality;
  @override
  String? get algorithmVersion;

  /// Create a copy of HrSample
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HrSampleImplCopyWith<_$HrSampleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$HrvSample {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  DateTime get capturedAt => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError;
  double get rmssdMs => throw _privateConstructorUsedError;
  double? get sdnnMs => throw _privateConstructorUsedError;
  double? get pnn50Pct => throw _privateConstructorUsedError;
  int? get meanHrBpm => throw _privateConstructorUsedError;
  int? get beatCount => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;
  int? get quality => throw _privateConstructorUsedError;
  String? get algorithmVersion => throw _privateConstructorUsedError;

  /// Create a copy of HrvSample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $HrvSampleCopyWith<HrvSample> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $HrvSampleCopyWith<$Res> {
  factory $HrvSampleCopyWith(HrvSample value, $Res Function(HrvSample) then) =
      _$HrvSampleCopyWithImpl<$Res, HrvSample>;
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    double rmssdMs,
    double? sdnnMs,
    double? pnn50Pct,
    int? meanHrBpm,
    int? beatCount,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class _$HrvSampleCopyWithImpl<$Res, $Val extends HrvSample>
    implements $HrvSampleCopyWith<$Res> {
  _$HrvSampleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of HrvSample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? rmssdMs = null,
    Object? sdnnMs = freezed,
    Object? pnn50Pct = freezed,
    Object? meanHrBpm = freezed,
    Object? beatCount = freezed,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
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
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            rmssdMs: null == rmssdMs
                ? _value.rmssdMs
                : rmssdMs // ignore: cast_nullable_to_non_nullable
                      as double,
            sdnnMs: freezed == sdnnMs
                ? _value.sdnnMs
                : sdnnMs // ignore: cast_nullable_to_non_nullable
                      as double?,
            pnn50Pct: freezed == pnn50Pct
                ? _value.pnn50Pct
                : pnn50Pct // ignore: cast_nullable_to_non_nullable
                      as double?,
            meanHrBpm: freezed == meanHrBpm
                ? _value.meanHrBpm
                : meanHrBpm // ignore: cast_nullable_to_non_nullable
                      as int?,
            beatCount: freezed == beatCount
                ? _value.beatCount
                : beatCount // ignore: cast_nullable_to_non_nullable
                      as int?,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
            quality: freezed == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                      as int?,
            algorithmVersion: freezed == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$HrvSampleImplCopyWith<$Res>
    implements $HrvSampleCopyWith<$Res> {
  factory _$$HrvSampleImplCopyWith(
    _$HrvSampleImpl value,
    $Res Function(_$HrvSampleImpl) then,
  ) = __$$HrvSampleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    double rmssdMs,
    double? sdnnMs,
    double? pnn50Pct,
    int? meanHrBpm,
    int? beatCount,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class __$$HrvSampleImplCopyWithImpl<$Res>
    extends _$HrvSampleCopyWithImpl<$Res, _$HrvSampleImpl>
    implements _$$HrvSampleImplCopyWith<$Res> {
  __$$HrvSampleImplCopyWithImpl(
    _$HrvSampleImpl _value,
    $Res Function(_$HrvSampleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of HrvSample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? rmssdMs = null,
    Object? sdnnMs = freezed,
    Object? pnn50Pct = freezed,
    Object? meanHrBpm = freezed,
    Object? beatCount = freezed,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
  }) {
    return _then(
      _$HrvSampleImpl(
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
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        rmssdMs: null == rmssdMs
            ? _value.rmssdMs
            : rmssdMs // ignore: cast_nullable_to_non_nullable
                  as double,
        sdnnMs: freezed == sdnnMs
            ? _value.sdnnMs
            : sdnnMs // ignore: cast_nullable_to_non_nullable
                  as double?,
        pnn50Pct: freezed == pnn50Pct
            ? _value.pnn50Pct
            : pnn50Pct // ignore: cast_nullable_to_non_nullable
                  as double?,
        meanHrBpm: freezed == meanHrBpm
            ? _value.meanHrBpm
            : meanHrBpm // ignore: cast_nullable_to_non_nullable
                  as int?,
        beatCount: freezed == beatCount
            ? _value.beatCount
            : beatCount // ignore: cast_nullable_to_non_nullable
                  as int?,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
        quality: freezed == quality
            ? _value.quality
            : quality // ignore: cast_nullable_to_non_nullable
                  as int?,
        algorithmVersion: freezed == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$HrvSampleImpl implements _HrvSample {
  const _$HrvSampleImpl({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAt,
    required this.tzOffsetMin,
    required this.rmssdMs,
    this.sdnnMs,
    this.pnn50Pct,
    this.meanHrBpm,
    this.beatCount,
    required this.source,
    this.quality,
    this.algorithmVersion,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String deviceId;
  @override
  final DateTime capturedAt;
  @override
  final int tzOffsetMin;
  @override
  final double rmssdMs;
  @override
  final double? sdnnMs;
  @override
  final double? pnn50Pct;
  @override
  final int? meanHrBpm;
  @override
  final int? beatCount;
  @override
  final DataSource source;
  @override
  final int? quality;
  @override
  final String? algorithmVersion;

  @override
  String toString() {
    return 'HrvSample(id: $id, userId: $userId, deviceId: $deviceId, capturedAt: $capturedAt, tzOffsetMin: $tzOffsetMin, rmssdMs: $rmssdMs, sdnnMs: $sdnnMs, pnn50Pct: $pnn50Pct, meanHrBpm: $meanHrBpm, beatCount: $beatCount, source: $source, quality: $quality, algorithmVersion: $algorithmVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$HrvSampleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.rmssdMs, rmssdMs) || other.rmssdMs == rmssdMs) &&
            (identical(other.sdnnMs, sdnnMs) || other.sdnnMs == sdnnMs) &&
            (identical(other.pnn50Pct, pnn50Pct) ||
                other.pnn50Pct == pnn50Pct) &&
            (identical(other.meanHrBpm, meanHrBpm) ||
                other.meanHrBpm == meanHrBpm) &&
            (identical(other.beatCount, beatCount) ||
                other.beatCount == beatCount) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceId,
    capturedAt,
    tzOffsetMin,
    rmssdMs,
    sdnnMs,
    pnn50Pct,
    meanHrBpm,
    beatCount,
    source,
    quality,
    algorithmVersion,
  );

  /// Create a copy of HrvSample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$HrvSampleImplCopyWith<_$HrvSampleImpl> get copyWith =>
      __$$HrvSampleImplCopyWithImpl<_$HrvSampleImpl>(this, _$identity);
}

abstract class _HrvSample implements HrvSample {
  const factory _HrvSample({
    required final String id,
    required final String userId,
    required final String deviceId,
    required final DateTime capturedAt,
    required final int tzOffsetMin,
    required final double rmssdMs,
    final double? sdnnMs,
    final double? pnn50Pct,
    final int? meanHrBpm,
    final int? beatCount,
    required final DataSource source,
    final int? quality,
    final String? algorithmVersion,
  }) = _$HrvSampleImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get deviceId;
  @override
  DateTime get capturedAt;
  @override
  int get tzOffsetMin;
  @override
  double get rmssdMs;
  @override
  double? get sdnnMs;
  @override
  double? get pnn50Pct;
  @override
  int? get meanHrBpm;
  @override
  int? get beatCount;
  @override
  DataSource get source;
  @override
  int? get quality;
  @override
  String? get algorithmVersion;

  /// Create a copy of HrvSample
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$HrvSampleImplCopyWith<_$HrvSampleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Spo2Sample {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  DateTime get capturedAt => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError;
  int get pctMin => throw _privateConstructorUsedError;
  int get pctMax => throw _privateConstructorUsedError;
  int get bucketMin => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;
  int? get quality => throw _privateConstructorUsedError;
  String? get algorithmVersion => throw _privateConstructorUsedError;

  /// Create a copy of Spo2Sample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Spo2SampleCopyWith<Spo2Sample> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Spo2SampleCopyWith<$Res> {
  factory $Spo2SampleCopyWith(
    Spo2Sample value,
    $Res Function(Spo2Sample) then,
  ) = _$Spo2SampleCopyWithImpl<$Res, Spo2Sample>;
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int pctMin,
    int pctMax,
    int bucketMin,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class _$Spo2SampleCopyWithImpl<$Res, $Val extends Spo2Sample>
    implements $Spo2SampleCopyWith<$Res> {
  _$Spo2SampleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Spo2Sample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? pctMin = null,
    Object? pctMax = null,
    Object? bucketMin = null,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
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
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            pctMin: null == pctMin
                ? _value.pctMin
                : pctMin // ignore: cast_nullable_to_non_nullable
                      as int,
            pctMax: null == pctMax
                ? _value.pctMax
                : pctMax // ignore: cast_nullable_to_non_nullable
                      as int,
            bucketMin: null == bucketMin
                ? _value.bucketMin
                : bucketMin // ignore: cast_nullable_to_non_nullable
                      as int,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
            quality: freezed == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                      as int?,
            algorithmVersion: freezed == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$Spo2SampleImplCopyWith<$Res>
    implements $Spo2SampleCopyWith<$Res> {
  factory _$$Spo2SampleImplCopyWith(
    _$Spo2SampleImpl value,
    $Res Function(_$Spo2SampleImpl) then,
  ) = __$$Spo2SampleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int pctMin,
    int pctMax,
    int bucketMin,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class __$$Spo2SampleImplCopyWithImpl<$Res>
    extends _$Spo2SampleCopyWithImpl<$Res, _$Spo2SampleImpl>
    implements _$$Spo2SampleImplCopyWith<$Res> {
  __$$Spo2SampleImplCopyWithImpl(
    _$Spo2SampleImpl _value,
    $Res Function(_$Spo2SampleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Spo2Sample
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? pctMin = null,
    Object? pctMax = null,
    Object? bucketMin = null,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
  }) {
    return _then(
      _$Spo2SampleImpl(
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
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        pctMin: null == pctMin
            ? _value.pctMin
            : pctMin // ignore: cast_nullable_to_non_nullable
                  as int,
        pctMax: null == pctMax
            ? _value.pctMax
            : pctMax // ignore: cast_nullable_to_non_nullable
                  as int,
        bucketMin: null == bucketMin
            ? _value.bucketMin
            : bucketMin // ignore: cast_nullable_to_non_nullable
                  as int,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
        quality: freezed == quality
            ? _value.quality
            : quality // ignore: cast_nullable_to_non_nullable
                  as int?,
        algorithmVersion: freezed == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$Spo2SampleImpl implements _Spo2Sample {
  const _$Spo2SampleImpl({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAt,
    required this.tzOffsetMin,
    required this.pctMin,
    required this.pctMax,
    required this.bucketMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String deviceId;
  @override
  final DateTime capturedAt;
  @override
  final int tzOffsetMin;
  @override
  final int pctMin;
  @override
  final int pctMax;
  @override
  final int bucketMin;
  @override
  final DataSource source;
  @override
  final int? quality;
  @override
  final String? algorithmVersion;

  @override
  String toString() {
    return 'Spo2Sample(id: $id, userId: $userId, deviceId: $deviceId, capturedAt: $capturedAt, tzOffsetMin: $tzOffsetMin, pctMin: $pctMin, pctMax: $pctMax, bucketMin: $bucketMin, source: $source, quality: $quality, algorithmVersion: $algorithmVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Spo2SampleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.pctMin, pctMin) || other.pctMin == pctMin) &&
            (identical(other.pctMax, pctMax) || other.pctMax == pctMax) &&
            (identical(other.bucketMin, bucketMin) ||
                other.bucketMin == bucketMin) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceId,
    capturedAt,
    tzOffsetMin,
    pctMin,
    pctMax,
    bucketMin,
    source,
    quality,
    algorithmVersion,
  );

  /// Create a copy of Spo2Sample
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Spo2SampleImplCopyWith<_$Spo2SampleImpl> get copyWith =>
      __$$Spo2SampleImplCopyWithImpl<_$Spo2SampleImpl>(this, _$identity);
}

abstract class _Spo2Sample implements Spo2Sample {
  const factory _Spo2Sample({
    required final String id,
    required final String userId,
    required final String deviceId,
    required final DateTime capturedAt,
    required final int tzOffsetMin,
    required final int pctMin,
    required final int pctMax,
    required final int bucketMin,
    required final DataSource source,
    final int? quality,
    final String? algorithmVersion,
  }) = _$Spo2SampleImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get deviceId;
  @override
  DateTime get capturedAt;
  @override
  int get tzOffsetMin;
  @override
  int get pctMin;
  @override
  int get pctMax;
  @override
  int get bucketMin;
  @override
  DataSource get source;
  @override
  int? get quality;
  @override
  String? get algorithmVersion;

  /// Create a copy of Spo2Sample
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Spo2SampleImplCopyWith<_$Spo2SampleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BpReading {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get deviceId => throw _privateConstructorUsedError;
  DateTime get capturedAt => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError;
  int get systolicMmhg => throw _privateConstructorUsedError;
  int get diastolicMmhg => throw _privateConstructorUsedError;
  int? get pulseBpm => throw _privateConstructorUsedError;
  BpDerivation get derivation => throw _privateConstructorUsedError;
  int? get position => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;
  int? get quality => throw _privateConstructorUsedError;
  String? get algorithmVersion => throw _privateConstructorUsedError;

  /// Create a copy of BpReading
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BpReadingCopyWith<BpReading> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BpReadingCopyWith<$Res> {
  factory $BpReadingCopyWith(BpReading value, $Res Function(BpReading) then) =
      _$BpReadingCopyWithImpl<$Res, BpReading>;
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int systolicMmhg,
    int diastolicMmhg,
    int? pulseBpm,
    BpDerivation derivation,
    int? position,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class _$BpReadingCopyWithImpl<$Res, $Val extends BpReading>
    implements $BpReadingCopyWith<$Res> {
  _$BpReadingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BpReading
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? systolicMmhg = null,
    Object? diastolicMmhg = null,
    Object? pulseBpm = freezed,
    Object? derivation = null,
    Object? position = freezed,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
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
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            systolicMmhg: null == systolicMmhg
                ? _value.systolicMmhg
                : systolicMmhg // ignore: cast_nullable_to_non_nullable
                      as int,
            diastolicMmhg: null == diastolicMmhg
                ? _value.diastolicMmhg
                : diastolicMmhg // ignore: cast_nullable_to_non_nullable
                      as int,
            pulseBpm: freezed == pulseBpm
                ? _value.pulseBpm
                : pulseBpm // ignore: cast_nullable_to_non_nullable
                      as int?,
            derivation: null == derivation
                ? _value.derivation
                : derivation // ignore: cast_nullable_to_non_nullable
                      as BpDerivation,
            position: freezed == position
                ? _value.position
                : position // ignore: cast_nullable_to_non_nullable
                      as int?,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as DataSource,
            quality: freezed == quality
                ? _value.quality
                : quality // ignore: cast_nullable_to_non_nullable
                      as int?,
            algorithmVersion: freezed == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BpReadingImplCopyWith<$Res>
    implements $BpReadingCopyWith<$Res> {
  factory _$$BpReadingImplCopyWith(
    _$BpReadingImpl value,
    $Res Function(_$BpReadingImpl) then,
  ) = __$$BpReadingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String deviceId,
    DateTime capturedAt,
    int tzOffsetMin,
    int systolicMmhg,
    int diastolicMmhg,
    int? pulseBpm,
    BpDerivation derivation,
    int? position,
    DataSource source,
    int? quality,
    String? algorithmVersion,
  });
}

/// @nodoc
class __$$BpReadingImplCopyWithImpl<$Res>
    extends _$BpReadingCopyWithImpl<$Res, _$BpReadingImpl>
    implements _$$BpReadingImplCopyWith<$Res> {
  __$$BpReadingImplCopyWithImpl(
    _$BpReadingImpl _value,
    $Res Function(_$BpReadingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BpReading
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? deviceId = null,
    Object? capturedAt = null,
    Object? tzOffsetMin = null,
    Object? systolicMmhg = null,
    Object? diastolicMmhg = null,
    Object? pulseBpm = freezed,
    Object? derivation = null,
    Object? position = freezed,
    Object? source = null,
    Object? quality = freezed,
    Object? algorithmVersion = freezed,
  }) {
    return _then(
      _$BpReadingImpl(
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
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        systolicMmhg: null == systolicMmhg
            ? _value.systolicMmhg
            : systolicMmhg // ignore: cast_nullable_to_non_nullable
                  as int,
        diastolicMmhg: null == diastolicMmhg
            ? _value.diastolicMmhg
            : diastolicMmhg // ignore: cast_nullable_to_non_nullable
                  as int,
        pulseBpm: freezed == pulseBpm
            ? _value.pulseBpm
            : pulseBpm // ignore: cast_nullable_to_non_nullable
                  as int?,
        derivation: null == derivation
            ? _value.derivation
            : derivation // ignore: cast_nullable_to_non_nullable
                  as BpDerivation,
        position: freezed == position
            ? _value.position
            : position // ignore: cast_nullable_to_non_nullable
                  as int?,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
        quality: freezed == quality
            ? _value.quality
            : quality // ignore: cast_nullable_to_non_nullable
                  as int?,
        algorithmVersion: freezed == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$BpReadingImpl implements _BpReading {
  const _$BpReadingImpl({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAt,
    required this.tzOffsetMin,
    required this.systolicMmhg,
    required this.diastolicMmhg,
    this.pulseBpm,
    required this.derivation,
    this.position,
    required this.source,
    this.quality,
    this.algorithmVersion,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String deviceId;
  @override
  final DateTime capturedAt;
  @override
  final int tzOffsetMin;
  @override
  final int systolicMmhg;
  @override
  final int diastolicMmhg;
  @override
  final int? pulseBpm;
  @override
  final BpDerivation derivation;
  @override
  final int? position;
  @override
  final DataSource source;
  @override
  final int? quality;
  @override
  final String? algorithmVersion;

  @override
  String toString() {
    return 'BpReading(id: $id, userId: $userId, deviceId: $deviceId, capturedAt: $capturedAt, tzOffsetMin: $tzOffsetMin, systolicMmhg: $systolicMmhg, diastolicMmhg: $diastolicMmhg, pulseBpm: $pulseBpm, derivation: $derivation, position: $position, source: $source, quality: $quality, algorithmVersion: $algorithmVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BpReadingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.deviceId, deviceId) ||
                other.deviceId == deviceId) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.systolicMmhg, systolicMmhg) ||
                other.systolicMmhg == systolicMmhg) &&
            (identical(other.diastolicMmhg, diastolicMmhg) ||
                other.diastolicMmhg == diastolicMmhg) &&
            (identical(other.pulseBpm, pulseBpm) ||
                other.pulseBpm == pulseBpm) &&
            (identical(other.derivation, derivation) ||
                other.derivation == derivation) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.quality, quality) || other.quality == quality) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    deviceId,
    capturedAt,
    tzOffsetMin,
    systolicMmhg,
    diastolicMmhg,
    pulseBpm,
    derivation,
    position,
    source,
    quality,
    algorithmVersion,
  );

  /// Create a copy of BpReading
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BpReadingImplCopyWith<_$BpReadingImpl> get copyWith =>
      __$$BpReadingImplCopyWithImpl<_$BpReadingImpl>(this, _$identity);
}

abstract class _BpReading implements BpReading {
  const factory _BpReading({
    required final String id,
    required final String userId,
    required final String deviceId,
    required final DateTime capturedAt,
    required final int tzOffsetMin,
    required final int systolicMmhg,
    required final int diastolicMmhg,
    final int? pulseBpm,
    required final BpDerivation derivation,
    final int? position,
    required final DataSource source,
    final int? quality,
    final String? algorithmVersion,
  }) = _$BpReadingImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get deviceId;
  @override
  DateTime get capturedAt;
  @override
  int get tzOffsetMin;
  @override
  int get systolicMmhg;
  @override
  int get diastolicMmhg;
  @override
  int? get pulseBpm;
  @override
  BpDerivation get derivation;
  @override
  int? get position;
  @override
  DataSource get source;
  @override
  int? get quality;
  @override
  String? get algorithmVersion;

  /// Create a copy of BpReading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BpReadingImplCopyWith<_$BpReadingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
