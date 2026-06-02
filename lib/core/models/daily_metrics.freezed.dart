// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DailyMetrics {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  DateTime get localDate => throw _privateConstructorUsedError;
  int get tzOffsetMin => throw _privateConstructorUsedError; // Cardiac
  int? get restingHrBpm => throw _privateConstructorUsedError;
  double? get hrvRmssdMs => throw _privateConstructorUsedError;
  double? get hrvSdnnMs => throw _privateConstructorUsedError;
  double? get restingRespRateBpm => throw _privateConstructorUsedError; // SpO2
  double? get spo2OvernightAvg => throw _privateConstructorUsedError;
  int? get spo2OvernightMin => throw _privateConstructorUsedError; // BP
  int? get systolicMmhg => throw _privateConstructorUsedError;
  int? get diastolicMmhg => throw _privateConstructorUsedError; // Sleep
  int? get sleepTotalMin => throw _privateConstructorUsedError;
  double? get sleepDeepPct => throw _privateConstructorUsedError;
  double? get sleepRemPct => throw _privateConstructorUsedError;
  double? get sleepLightPct => throw _privateConstructorUsedError;
  double? get sleepEfficiencyPct => throw _privateConstructorUsedError;
  DateTime? get bedtime => throw _privateConstructorUsedError;
  DateTime? get wake => throw _privateConstructorUsedError; // Activity
  int? get steps => throw _privateConstructorUsedError;
  int? get distanceM => throw _privateConstructorUsedError;
  double? get caloriesKcal => throw _privateConstructorUsedError;
  int? get activeMinutes =>
      throw _privateConstructorUsedError; // Vascular / cardiac advanced
  double? get stiffnessIndex => throw _privateConstructorUsedError;
  double? get augmentationIndex => throw _privateConstructorUsedError;
  double? get strokeVolumeIndex => throw _privateConstructorUsedError;
  double? get breathingDisruptionsHr =>
      throw _privateConstructorUsedError; // Scores (snapshots)
  int? get recoveryScore => throw _privateConstructorUsedError;
  int? get wellnessScore => throw _privateConstructorUsedError; // Cycle
  int? get cyclePhase => throw _privateConstructorUsedError; // Provenance
  DateTime get computedAt => throw _privateConstructorUsedError;
  String get algorithmVersion => throw _privateConstructorUsedError;
  DataSource get source => throw _privateConstructorUsedError;

  /// Create a copy of DailyMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyMetricsCopyWith<DailyMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyMetricsCopyWith<$Res> {
  factory $DailyMetricsCopyWith(
    DailyMetrics value,
    $Res Function(DailyMetrics) then,
  ) = _$DailyMetricsCopyWithImpl<$Res, DailyMetrics>;
  @useResult
  $Res call({
    String id,
    String userId,
    DateTime localDate,
    int tzOffsetMin,
    int? restingHrBpm,
    double? hrvRmssdMs,
    double? hrvSdnnMs,
    double? restingRespRateBpm,
    double? spo2OvernightAvg,
    int? spo2OvernightMin,
    int? systolicMmhg,
    int? diastolicMmhg,
    int? sleepTotalMin,
    double? sleepDeepPct,
    double? sleepRemPct,
    double? sleepLightPct,
    double? sleepEfficiencyPct,
    DateTime? bedtime,
    DateTime? wake,
    int? steps,
    int? distanceM,
    double? caloriesKcal,
    int? activeMinutes,
    double? stiffnessIndex,
    double? augmentationIndex,
    double? strokeVolumeIndex,
    double? breathingDisruptionsHr,
    int? recoveryScore,
    int? wellnessScore,
    int? cyclePhase,
    DateTime computedAt,
    String algorithmVersion,
    DataSource source,
  });
}

/// @nodoc
class _$DailyMetricsCopyWithImpl<$Res, $Val extends DailyMetrics>
    implements $DailyMetricsCopyWith<$Res> {
  _$DailyMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? localDate = null,
    Object? tzOffsetMin = null,
    Object? restingHrBpm = freezed,
    Object? hrvRmssdMs = freezed,
    Object? hrvSdnnMs = freezed,
    Object? restingRespRateBpm = freezed,
    Object? spo2OvernightAvg = freezed,
    Object? spo2OvernightMin = freezed,
    Object? systolicMmhg = freezed,
    Object? diastolicMmhg = freezed,
    Object? sleepTotalMin = freezed,
    Object? sleepDeepPct = freezed,
    Object? sleepRemPct = freezed,
    Object? sleepLightPct = freezed,
    Object? sleepEfficiencyPct = freezed,
    Object? bedtime = freezed,
    Object? wake = freezed,
    Object? steps = freezed,
    Object? distanceM = freezed,
    Object? caloriesKcal = freezed,
    Object? activeMinutes = freezed,
    Object? stiffnessIndex = freezed,
    Object? augmentationIndex = freezed,
    Object? strokeVolumeIndex = freezed,
    Object? breathingDisruptionsHr = freezed,
    Object? recoveryScore = freezed,
    Object? wellnessScore = freezed,
    Object? cyclePhase = freezed,
    Object? computedAt = null,
    Object? algorithmVersion = null,
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
            localDate: null == localDate
                ? _value.localDate
                : localDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            tzOffsetMin: null == tzOffsetMin
                ? _value.tzOffsetMin
                : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                      as int,
            restingHrBpm: freezed == restingHrBpm
                ? _value.restingHrBpm
                : restingHrBpm // ignore: cast_nullable_to_non_nullable
                      as int?,
            hrvRmssdMs: freezed == hrvRmssdMs
                ? _value.hrvRmssdMs
                : hrvRmssdMs // ignore: cast_nullable_to_non_nullable
                      as double?,
            hrvSdnnMs: freezed == hrvSdnnMs
                ? _value.hrvSdnnMs
                : hrvSdnnMs // ignore: cast_nullable_to_non_nullable
                      as double?,
            restingRespRateBpm: freezed == restingRespRateBpm
                ? _value.restingRespRateBpm
                : restingRespRateBpm // ignore: cast_nullable_to_non_nullable
                      as double?,
            spo2OvernightAvg: freezed == spo2OvernightAvg
                ? _value.spo2OvernightAvg
                : spo2OvernightAvg // ignore: cast_nullable_to_non_nullable
                      as double?,
            spo2OvernightMin: freezed == spo2OvernightMin
                ? _value.spo2OvernightMin
                : spo2OvernightMin // ignore: cast_nullable_to_non_nullable
                      as int?,
            systolicMmhg: freezed == systolicMmhg
                ? _value.systolicMmhg
                : systolicMmhg // ignore: cast_nullable_to_non_nullable
                      as int?,
            diastolicMmhg: freezed == diastolicMmhg
                ? _value.diastolicMmhg
                : diastolicMmhg // ignore: cast_nullable_to_non_nullable
                      as int?,
            sleepTotalMin: freezed == sleepTotalMin
                ? _value.sleepTotalMin
                : sleepTotalMin // ignore: cast_nullable_to_non_nullable
                      as int?,
            sleepDeepPct: freezed == sleepDeepPct
                ? _value.sleepDeepPct
                : sleepDeepPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            sleepRemPct: freezed == sleepRemPct
                ? _value.sleepRemPct
                : sleepRemPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            sleepLightPct: freezed == sleepLightPct
                ? _value.sleepLightPct
                : sleepLightPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            sleepEfficiencyPct: freezed == sleepEfficiencyPct
                ? _value.sleepEfficiencyPct
                : sleepEfficiencyPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            bedtime: freezed == bedtime
                ? _value.bedtime
                : bedtime // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            wake: freezed == wake
                ? _value.wake
                : wake // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            steps: freezed == steps
                ? _value.steps
                : steps // ignore: cast_nullable_to_non_nullable
                      as int?,
            distanceM: freezed == distanceM
                ? _value.distanceM
                : distanceM // ignore: cast_nullable_to_non_nullable
                      as int?,
            caloriesKcal: freezed == caloriesKcal
                ? _value.caloriesKcal
                : caloriesKcal // ignore: cast_nullable_to_non_nullable
                      as double?,
            activeMinutes: freezed == activeMinutes
                ? _value.activeMinutes
                : activeMinutes // ignore: cast_nullable_to_non_nullable
                      as int?,
            stiffnessIndex: freezed == stiffnessIndex
                ? _value.stiffnessIndex
                : stiffnessIndex // ignore: cast_nullable_to_non_nullable
                      as double?,
            augmentationIndex: freezed == augmentationIndex
                ? _value.augmentationIndex
                : augmentationIndex // ignore: cast_nullable_to_non_nullable
                      as double?,
            strokeVolumeIndex: freezed == strokeVolumeIndex
                ? _value.strokeVolumeIndex
                : strokeVolumeIndex // ignore: cast_nullable_to_non_nullable
                      as double?,
            breathingDisruptionsHr: freezed == breathingDisruptionsHr
                ? _value.breathingDisruptionsHr
                : breathingDisruptionsHr // ignore: cast_nullable_to_non_nullable
                      as double?,
            recoveryScore: freezed == recoveryScore
                ? _value.recoveryScore
                : recoveryScore // ignore: cast_nullable_to_non_nullable
                      as int?,
            wellnessScore: freezed == wellnessScore
                ? _value.wellnessScore
                : wellnessScore // ignore: cast_nullable_to_non_nullable
                      as int?,
            cyclePhase: freezed == cyclePhase
                ? _value.cyclePhase
                : cyclePhase // ignore: cast_nullable_to_non_nullable
                      as int?,
            computedAt: null == computedAt
                ? _value.computedAt
                : computedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            algorithmVersion: null == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String,
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
abstract class _$$DailyMetricsImplCopyWith<$Res>
    implements $DailyMetricsCopyWith<$Res> {
  factory _$$DailyMetricsImplCopyWith(
    _$DailyMetricsImpl value,
    $Res Function(_$DailyMetricsImpl) then,
  ) = __$$DailyMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    DateTime localDate,
    int tzOffsetMin,
    int? restingHrBpm,
    double? hrvRmssdMs,
    double? hrvSdnnMs,
    double? restingRespRateBpm,
    double? spo2OvernightAvg,
    int? spo2OvernightMin,
    int? systolicMmhg,
    int? diastolicMmhg,
    int? sleepTotalMin,
    double? sleepDeepPct,
    double? sleepRemPct,
    double? sleepLightPct,
    double? sleepEfficiencyPct,
    DateTime? bedtime,
    DateTime? wake,
    int? steps,
    int? distanceM,
    double? caloriesKcal,
    int? activeMinutes,
    double? stiffnessIndex,
    double? augmentationIndex,
    double? strokeVolumeIndex,
    double? breathingDisruptionsHr,
    int? recoveryScore,
    int? wellnessScore,
    int? cyclePhase,
    DateTime computedAt,
    String algorithmVersion,
    DataSource source,
  });
}

/// @nodoc
class __$$DailyMetricsImplCopyWithImpl<$Res>
    extends _$DailyMetricsCopyWithImpl<$Res, _$DailyMetricsImpl>
    implements _$$DailyMetricsImplCopyWith<$Res> {
  __$$DailyMetricsImplCopyWithImpl(
    _$DailyMetricsImpl _value,
    $Res Function(_$DailyMetricsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? localDate = null,
    Object? tzOffsetMin = null,
    Object? restingHrBpm = freezed,
    Object? hrvRmssdMs = freezed,
    Object? hrvSdnnMs = freezed,
    Object? restingRespRateBpm = freezed,
    Object? spo2OvernightAvg = freezed,
    Object? spo2OvernightMin = freezed,
    Object? systolicMmhg = freezed,
    Object? diastolicMmhg = freezed,
    Object? sleepTotalMin = freezed,
    Object? sleepDeepPct = freezed,
    Object? sleepRemPct = freezed,
    Object? sleepLightPct = freezed,
    Object? sleepEfficiencyPct = freezed,
    Object? bedtime = freezed,
    Object? wake = freezed,
    Object? steps = freezed,
    Object? distanceM = freezed,
    Object? caloriesKcal = freezed,
    Object? activeMinutes = freezed,
    Object? stiffnessIndex = freezed,
    Object? augmentationIndex = freezed,
    Object? strokeVolumeIndex = freezed,
    Object? breathingDisruptionsHr = freezed,
    Object? recoveryScore = freezed,
    Object? wellnessScore = freezed,
    Object? cyclePhase = freezed,
    Object? computedAt = null,
    Object? algorithmVersion = null,
    Object? source = null,
  }) {
    return _then(
      _$DailyMetricsImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        localDate: null == localDate
            ? _value.localDate
            : localDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        tzOffsetMin: null == tzOffsetMin
            ? _value.tzOffsetMin
            : tzOffsetMin // ignore: cast_nullable_to_non_nullable
                  as int,
        restingHrBpm: freezed == restingHrBpm
            ? _value.restingHrBpm
            : restingHrBpm // ignore: cast_nullable_to_non_nullable
                  as int?,
        hrvRmssdMs: freezed == hrvRmssdMs
            ? _value.hrvRmssdMs
            : hrvRmssdMs // ignore: cast_nullable_to_non_nullable
                  as double?,
        hrvSdnnMs: freezed == hrvSdnnMs
            ? _value.hrvSdnnMs
            : hrvSdnnMs // ignore: cast_nullable_to_non_nullable
                  as double?,
        restingRespRateBpm: freezed == restingRespRateBpm
            ? _value.restingRespRateBpm
            : restingRespRateBpm // ignore: cast_nullable_to_non_nullable
                  as double?,
        spo2OvernightAvg: freezed == spo2OvernightAvg
            ? _value.spo2OvernightAvg
            : spo2OvernightAvg // ignore: cast_nullable_to_non_nullable
                  as double?,
        spo2OvernightMin: freezed == spo2OvernightMin
            ? _value.spo2OvernightMin
            : spo2OvernightMin // ignore: cast_nullable_to_non_nullable
                  as int?,
        systolicMmhg: freezed == systolicMmhg
            ? _value.systolicMmhg
            : systolicMmhg // ignore: cast_nullable_to_non_nullable
                  as int?,
        diastolicMmhg: freezed == diastolicMmhg
            ? _value.diastolicMmhg
            : diastolicMmhg // ignore: cast_nullable_to_non_nullable
                  as int?,
        sleepTotalMin: freezed == sleepTotalMin
            ? _value.sleepTotalMin
            : sleepTotalMin // ignore: cast_nullable_to_non_nullable
                  as int?,
        sleepDeepPct: freezed == sleepDeepPct
            ? _value.sleepDeepPct
            : sleepDeepPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        sleepRemPct: freezed == sleepRemPct
            ? _value.sleepRemPct
            : sleepRemPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        sleepLightPct: freezed == sleepLightPct
            ? _value.sleepLightPct
            : sleepLightPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        sleepEfficiencyPct: freezed == sleepEfficiencyPct
            ? _value.sleepEfficiencyPct
            : sleepEfficiencyPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        bedtime: freezed == bedtime
            ? _value.bedtime
            : bedtime // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        wake: freezed == wake
            ? _value.wake
            : wake // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        steps: freezed == steps
            ? _value.steps
            : steps // ignore: cast_nullable_to_non_nullable
                  as int?,
        distanceM: freezed == distanceM
            ? _value.distanceM
            : distanceM // ignore: cast_nullable_to_non_nullable
                  as int?,
        caloriesKcal: freezed == caloriesKcal
            ? _value.caloriesKcal
            : caloriesKcal // ignore: cast_nullable_to_non_nullable
                  as double?,
        activeMinutes: freezed == activeMinutes
            ? _value.activeMinutes
            : activeMinutes // ignore: cast_nullable_to_non_nullable
                  as int?,
        stiffnessIndex: freezed == stiffnessIndex
            ? _value.stiffnessIndex
            : stiffnessIndex // ignore: cast_nullable_to_non_nullable
                  as double?,
        augmentationIndex: freezed == augmentationIndex
            ? _value.augmentationIndex
            : augmentationIndex // ignore: cast_nullable_to_non_nullable
                  as double?,
        strokeVolumeIndex: freezed == strokeVolumeIndex
            ? _value.strokeVolumeIndex
            : strokeVolumeIndex // ignore: cast_nullable_to_non_nullable
                  as double?,
        breathingDisruptionsHr: freezed == breathingDisruptionsHr
            ? _value.breathingDisruptionsHr
            : breathingDisruptionsHr // ignore: cast_nullable_to_non_nullable
                  as double?,
        recoveryScore: freezed == recoveryScore
            ? _value.recoveryScore
            : recoveryScore // ignore: cast_nullable_to_non_nullable
                  as int?,
        wellnessScore: freezed == wellnessScore
            ? _value.wellnessScore
            : wellnessScore // ignore: cast_nullable_to_non_nullable
                  as int?,
        cyclePhase: freezed == cyclePhase
            ? _value.cyclePhase
            : cyclePhase // ignore: cast_nullable_to_non_nullable
                  as int?,
        computedAt: null == computedAt
            ? _value.computedAt
            : computedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        algorithmVersion: null == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as DataSource,
      ),
    );
  }
}

/// @nodoc

class _$DailyMetricsImpl implements _DailyMetrics {
  const _$DailyMetricsImpl({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.tzOffsetMin,
    this.restingHrBpm,
    this.hrvRmssdMs,
    this.hrvSdnnMs,
    this.restingRespRateBpm,
    this.spo2OvernightAvg,
    this.spo2OvernightMin,
    this.systolicMmhg,
    this.diastolicMmhg,
    this.sleepTotalMin,
    this.sleepDeepPct,
    this.sleepRemPct,
    this.sleepLightPct,
    this.sleepEfficiencyPct,
    this.bedtime,
    this.wake,
    this.steps,
    this.distanceM,
    this.caloriesKcal,
    this.activeMinutes,
    this.stiffnessIndex,
    this.augmentationIndex,
    this.strokeVolumeIndex,
    this.breathingDisruptionsHr,
    this.recoveryScore,
    this.wellnessScore,
    this.cyclePhase,
    required this.computedAt,
    required this.algorithmVersion,
    required this.source,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final DateTime localDate;
  @override
  final int tzOffsetMin;
  // Cardiac
  @override
  final int? restingHrBpm;
  @override
  final double? hrvRmssdMs;
  @override
  final double? hrvSdnnMs;
  @override
  final double? restingRespRateBpm;
  // SpO2
  @override
  final double? spo2OvernightAvg;
  @override
  final int? spo2OvernightMin;
  // BP
  @override
  final int? systolicMmhg;
  @override
  final int? diastolicMmhg;
  // Sleep
  @override
  final int? sleepTotalMin;
  @override
  final double? sleepDeepPct;
  @override
  final double? sleepRemPct;
  @override
  final double? sleepLightPct;
  @override
  final double? sleepEfficiencyPct;
  @override
  final DateTime? bedtime;
  @override
  final DateTime? wake;
  // Activity
  @override
  final int? steps;
  @override
  final int? distanceM;
  @override
  final double? caloriesKcal;
  @override
  final int? activeMinutes;
  // Vascular / cardiac advanced
  @override
  final double? stiffnessIndex;
  @override
  final double? augmentationIndex;
  @override
  final double? strokeVolumeIndex;
  @override
  final double? breathingDisruptionsHr;
  // Scores (snapshots)
  @override
  final int? recoveryScore;
  @override
  final int? wellnessScore;
  // Cycle
  @override
  final int? cyclePhase;
  // Provenance
  @override
  final DateTime computedAt;
  @override
  final String algorithmVersion;
  @override
  final DataSource source;

  @override
  String toString() {
    return 'DailyMetrics(id: $id, userId: $userId, localDate: $localDate, tzOffsetMin: $tzOffsetMin, restingHrBpm: $restingHrBpm, hrvRmssdMs: $hrvRmssdMs, hrvSdnnMs: $hrvSdnnMs, restingRespRateBpm: $restingRespRateBpm, spo2OvernightAvg: $spo2OvernightAvg, spo2OvernightMin: $spo2OvernightMin, systolicMmhg: $systolicMmhg, diastolicMmhg: $diastolicMmhg, sleepTotalMin: $sleepTotalMin, sleepDeepPct: $sleepDeepPct, sleepRemPct: $sleepRemPct, sleepLightPct: $sleepLightPct, sleepEfficiencyPct: $sleepEfficiencyPct, bedtime: $bedtime, wake: $wake, steps: $steps, distanceM: $distanceM, caloriesKcal: $caloriesKcal, activeMinutes: $activeMinutes, stiffnessIndex: $stiffnessIndex, augmentationIndex: $augmentationIndex, strokeVolumeIndex: $strokeVolumeIndex, breathingDisruptionsHr: $breathingDisruptionsHr, recoveryScore: $recoveryScore, wellnessScore: $wellnessScore, cyclePhase: $cyclePhase, computedAt: $computedAt, algorithmVersion: $algorithmVersion, source: $source)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyMetricsImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.localDate, localDate) ||
                other.localDate == localDate) &&
            (identical(other.tzOffsetMin, tzOffsetMin) ||
                other.tzOffsetMin == tzOffsetMin) &&
            (identical(other.restingHrBpm, restingHrBpm) ||
                other.restingHrBpm == restingHrBpm) &&
            (identical(other.hrvRmssdMs, hrvRmssdMs) ||
                other.hrvRmssdMs == hrvRmssdMs) &&
            (identical(other.hrvSdnnMs, hrvSdnnMs) ||
                other.hrvSdnnMs == hrvSdnnMs) &&
            (identical(other.restingRespRateBpm, restingRespRateBpm) ||
                other.restingRespRateBpm == restingRespRateBpm) &&
            (identical(other.spo2OvernightAvg, spo2OvernightAvg) ||
                other.spo2OvernightAvg == spo2OvernightAvg) &&
            (identical(other.spo2OvernightMin, spo2OvernightMin) ||
                other.spo2OvernightMin == spo2OvernightMin) &&
            (identical(other.systolicMmhg, systolicMmhg) ||
                other.systolicMmhg == systolicMmhg) &&
            (identical(other.diastolicMmhg, diastolicMmhg) ||
                other.diastolicMmhg == diastolicMmhg) &&
            (identical(other.sleepTotalMin, sleepTotalMin) ||
                other.sleepTotalMin == sleepTotalMin) &&
            (identical(other.sleepDeepPct, sleepDeepPct) ||
                other.sleepDeepPct == sleepDeepPct) &&
            (identical(other.sleepRemPct, sleepRemPct) ||
                other.sleepRemPct == sleepRemPct) &&
            (identical(other.sleepLightPct, sleepLightPct) ||
                other.sleepLightPct == sleepLightPct) &&
            (identical(other.sleepEfficiencyPct, sleepEfficiencyPct) ||
                other.sleepEfficiencyPct == sleepEfficiencyPct) &&
            (identical(other.bedtime, bedtime) || other.bedtime == bedtime) &&
            (identical(other.wake, wake) || other.wake == wake) &&
            (identical(other.steps, steps) || other.steps == steps) &&
            (identical(other.distanceM, distanceM) ||
                other.distanceM == distanceM) &&
            (identical(other.caloriesKcal, caloriesKcal) ||
                other.caloriesKcal == caloriesKcal) &&
            (identical(other.activeMinutes, activeMinutes) ||
                other.activeMinutes == activeMinutes) &&
            (identical(other.stiffnessIndex, stiffnessIndex) ||
                other.stiffnessIndex == stiffnessIndex) &&
            (identical(other.augmentationIndex, augmentationIndex) ||
                other.augmentationIndex == augmentationIndex) &&
            (identical(other.strokeVolumeIndex, strokeVolumeIndex) ||
                other.strokeVolumeIndex == strokeVolumeIndex) &&
            (identical(other.breathingDisruptionsHr, breathingDisruptionsHr) ||
                other.breathingDisruptionsHr == breathingDisruptionsHr) &&
            (identical(other.recoveryScore, recoveryScore) ||
                other.recoveryScore == recoveryScore) &&
            (identical(other.wellnessScore, wellnessScore) ||
                other.wellnessScore == wellnessScore) &&
            (identical(other.cyclePhase, cyclePhase) ||
                other.cyclePhase == cyclePhase) &&
            (identical(other.computedAt, computedAt) ||
                other.computedAt == computedAt) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion) &&
            (identical(other.source, source) || other.source == source));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    userId,
    localDate,
    tzOffsetMin,
    restingHrBpm,
    hrvRmssdMs,
    hrvSdnnMs,
    restingRespRateBpm,
    spo2OvernightAvg,
    spo2OvernightMin,
    systolicMmhg,
    diastolicMmhg,
    sleepTotalMin,
    sleepDeepPct,
    sleepRemPct,
    sleepLightPct,
    sleepEfficiencyPct,
    bedtime,
    wake,
    steps,
    distanceM,
    caloriesKcal,
    activeMinutes,
    stiffnessIndex,
    augmentationIndex,
    strokeVolumeIndex,
    breathingDisruptionsHr,
    recoveryScore,
    wellnessScore,
    cyclePhase,
    computedAt,
    algorithmVersion,
    source,
  ]);

  /// Create a copy of DailyMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyMetricsImplCopyWith<_$DailyMetricsImpl> get copyWith =>
      __$$DailyMetricsImplCopyWithImpl<_$DailyMetricsImpl>(this, _$identity);
}

abstract class _DailyMetrics implements DailyMetrics {
  const factory _DailyMetrics({
    required final String id,
    required final String userId,
    required final DateTime localDate,
    required final int tzOffsetMin,
    final int? restingHrBpm,
    final double? hrvRmssdMs,
    final double? hrvSdnnMs,
    final double? restingRespRateBpm,
    final double? spo2OvernightAvg,
    final int? spo2OvernightMin,
    final int? systolicMmhg,
    final int? diastolicMmhg,
    final int? sleepTotalMin,
    final double? sleepDeepPct,
    final double? sleepRemPct,
    final double? sleepLightPct,
    final double? sleepEfficiencyPct,
    final DateTime? bedtime,
    final DateTime? wake,
    final int? steps,
    final int? distanceM,
    final double? caloriesKcal,
    final int? activeMinutes,
    final double? stiffnessIndex,
    final double? augmentationIndex,
    final double? strokeVolumeIndex,
    final double? breathingDisruptionsHr,
    final int? recoveryScore,
    final int? wellnessScore,
    final int? cyclePhase,
    required final DateTime computedAt,
    required final String algorithmVersion,
    required final DataSource source,
  }) = _$DailyMetricsImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  DateTime get localDate;
  @override
  int get tzOffsetMin; // Cardiac
  @override
  int? get restingHrBpm;
  @override
  double? get hrvRmssdMs;
  @override
  double? get hrvSdnnMs;
  @override
  double? get restingRespRateBpm; // SpO2
  @override
  double? get spo2OvernightAvg;
  @override
  int? get spo2OvernightMin; // BP
  @override
  int? get systolicMmhg;
  @override
  int? get diastolicMmhg; // Sleep
  @override
  int? get sleepTotalMin;
  @override
  double? get sleepDeepPct;
  @override
  double? get sleepRemPct;
  @override
  double? get sleepLightPct;
  @override
  double? get sleepEfficiencyPct;
  @override
  DateTime? get bedtime;
  @override
  DateTime? get wake; // Activity
  @override
  int? get steps;
  @override
  int? get distanceM;
  @override
  double? get caloriesKcal;
  @override
  int? get activeMinutes; // Vascular / cardiac advanced
  @override
  double? get stiffnessIndex;
  @override
  double? get augmentationIndex;
  @override
  double? get strokeVolumeIndex;
  @override
  double? get breathingDisruptionsHr; // Scores (snapshots)
  @override
  int? get recoveryScore;
  @override
  int? get wellnessScore; // Cycle
  @override
  int? get cyclePhase; // Provenance
  @override
  DateTime get computedAt;
  @override
  String get algorithmVersion;
  @override
  DataSource get source;

  /// Create a copy of DailyMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyMetricsImplCopyWith<_$DailyMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
