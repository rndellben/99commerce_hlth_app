// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'score.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Score {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  ScoreType get scoreType => throw _privateConstructorUsedError;
  DateTime get computedForDate => throw _privateConstructorUsedError;
  double get score => throw _privateConstructorUsedError;
  double? get rawScore => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  double? get confidence => throw _privateConstructorUsedError;
  bool get provisional => throw _privateConstructorUsedError;
  Map<String, double>? get components => throw _privateConstructorUsedError;
  DateTime get computedAt => throw _privateConstructorUsedError;
  String get algorithmVersion => throw _privateConstructorUsedError;

  /// Create a copy of Score
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScoreCopyWith<Score> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScoreCopyWith<$Res> {
  factory $ScoreCopyWith(Score value, $Res Function(Score) then) =
      _$ScoreCopyWithImpl<$Res, Score>;
  @useResult
  $Res call({
    String id,
    String userId,
    ScoreType scoreType,
    DateTime computedForDate,
    double score,
    double? rawScore,
    String? label,
    double? confidence,
    bool provisional,
    Map<String, double>? components,
    DateTime computedAt,
    String algorithmVersion,
  });
}

/// @nodoc
class _$ScoreCopyWithImpl<$Res, $Val extends Score>
    implements $ScoreCopyWith<$Res> {
  _$ScoreCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Score
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? scoreType = null,
    Object? computedForDate = null,
    Object? score = null,
    Object? rawScore = freezed,
    Object? label = freezed,
    Object? confidence = freezed,
    Object? provisional = null,
    Object? components = freezed,
    Object? computedAt = null,
    Object? algorithmVersion = null,
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
            scoreType: null == scoreType
                ? _value.scoreType
                : scoreType // ignore: cast_nullable_to_non_nullable
                      as ScoreType,
            computedForDate: null == computedForDate
                ? _value.computedForDate
                : computedForDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            score: null == score
                ? _value.score
                : score // ignore: cast_nullable_to_non_nullable
                      as double,
            rawScore: freezed == rawScore
                ? _value.rawScore
                : rawScore // ignore: cast_nullable_to_non_nullable
                      as double?,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
            confidence: freezed == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                      as double?,
            provisional: null == provisional
                ? _value.provisional
                : provisional // ignore: cast_nullable_to_non_nullable
                      as bool,
            components: freezed == components
                ? _value.components
                : components // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>?,
            computedAt: null == computedAt
                ? _value.computedAt
                : computedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            algorithmVersion: null == algorithmVersion
                ? _value.algorithmVersion
                : algorithmVersion // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ScoreImplCopyWith<$Res> implements $ScoreCopyWith<$Res> {
  factory _$$ScoreImplCopyWith(
    _$ScoreImpl value,
    $Res Function(_$ScoreImpl) then,
  ) = __$$ScoreImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    ScoreType scoreType,
    DateTime computedForDate,
    double score,
    double? rawScore,
    String? label,
    double? confidence,
    bool provisional,
    Map<String, double>? components,
    DateTime computedAt,
    String algorithmVersion,
  });
}

/// @nodoc
class __$$ScoreImplCopyWithImpl<$Res>
    extends _$ScoreCopyWithImpl<$Res, _$ScoreImpl>
    implements _$$ScoreImplCopyWith<$Res> {
  __$$ScoreImplCopyWithImpl(
    _$ScoreImpl _value,
    $Res Function(_$ScoreImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Score
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? scoreType = null,
    Object? computedForDate = null,
    Object? score = null,
    Object? rawScore = freezed,
    Object? label = freezed,
    Object? confidence = freezed,
    Object? provisional = null,
    Object? components = freezed,
    Object? computedAt = null,
    Object? algorithmVersion = null,
  }) {
    return _then(
      _$ScoreImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        scoreType: null == scoreType
            ? _value.scoreType
            : scoreType // ignore: cast_nullable_to_non_nullable
                  as ScoreType,
        computedForDate: null == computedForDate
            ? _value.computedForDate
            : computedForDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        score: null == score
            ? _value.score
            : score // ignore: cast_nullable_to_non_nullable
                  as double,
        rawScore: freezed == rawScore
            ? _value.rawScore
            : rawScore // ignore: cast_nullable_to_non_nullable
                  as double?,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
        confidence: freezed == confidence
            ? _value.confidence
            : confidence // ignore: cast_nullable_to_non_nullable
                  as double?,
        provisional: null == provisional
            ? _value.provisional
            : provisional // ignore: cast_nullable_to_non_nullable
                  as bool,
        components: freezed == components
            ? _value._components
            : components // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>?,
        computedAt: null == computedAt
            ? _value.computedAt
            : computedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        algorithmVersion: null == algorithmVersion
            ? _value.algorithmVersion
            : algorithmVersion // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc

class _$ScoreImpl implements _Score {
  const _$ScoreImpl({
    required this.id,
    required this.userId,
    required this.scoreType,
    required this.computedForDate,
    required this.score,
    this.rawScore,
    this.label,
    this.confidence,
    this.provisional = false,
    final Map<String, double>? components,
    required this.computedAt,
    required this.algorithmVersion,
  }) : _components = components;

  @override
  final String id;
  @override
  final String userId;
  @override
  final ScoreType scoreType;
  @override
  final DateTime computedForDate;
  @override
  final double score;
  @override
  final double? rawScore;
  @override
  final String? label;
  @override
  final double? confidence;
  @override
  @JsonKey()
  final bool provisional;
  final Map<String, double>? _components;
  @override
  Map<String, double>? get components {
    final value = _components;
    if (value == null) return null;
    if (_components is EqualUnmodifiableMapView) return _components;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime computedAt;
  @override
  final String algorithmVersion;

  @override
  String toString() {
    return 'Score(id: $id, userId: $userId, scoreType: $scoreType, computedForDate: $computedForDate, score: $score, rawScore: $rawScore, label: $label, confidence: $confidence, provisional: $provisional, components: $components, computedAt: $computedAt, algorithmVersion: $algorithmVersion)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScoreImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.scoreType, scoreType) ||
                other.scoreType == scoreType) &&
            (identical(other.computedForDate, computedForDate) ||
                other.computedForDate == computedForDate) &&
            (identical(other.score, score) || other.score == score) &&
            (identical(other.rawScore, rawScore) ||
                other.rawScore == rawScore) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.provisional, provisional) ||
                other.provisional == provisional) &&
            const DeepCollectionEquality().equals(
              other._components,
              _components,
            ) &&
            (identical(other.computedAt, computedAt) ||
                other.computedAt == computedAt) &&
            (identical(other.algorithmVersion, algorithmVersion) ||
                other.algorithmVersion == algorithmVersion));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    scoreType,
    computedForDate,
    score,
    rawScore,
    label,
    confidence,
    provisional,
    const DeepCollectionEquality().hash(_components),
    computedAt,
    algorithmVersion,
  );

  /// Create a copy of Score
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScoreImplCopyWith<_$ScoreImpl> get copyWith =>
      __$$ScoreImplCopyWithImpl<_$ScoreImpl>(this, _$identity);
}

abstract class _Score implements Score {
  const factory _Score({
    required final String id,
    required final String userId,
    required final ScoreType scoreType,
    required final DateTime computedForDate,
    required final double score,
    final double? rawScore,
    final String? label,
    final double? confidence,
    final bool provisional,
    final Map<String, double>? components,
    required final DateTime computedAt,
    required final String algorithmVersion,
  }) = _$ScoreImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  ScoreType get scoreType;
  @override
  DateTime get computedForDate;
  @override
  double get score;
  @override
  double? get rawScore;
  @override
  String? get label;
  @override
  double? get confidence;
  @override
  bool get provisional;
  @override
  Map<String, double>? get components;
  @override
  DateTime get computedAt;
  @override
  String get algorithmVersion;

  /// Create a copy of Score
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScoreImplCopyWith<_$ScoreImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
