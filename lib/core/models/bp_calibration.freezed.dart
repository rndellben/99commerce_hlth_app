// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bp_calibration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BpCalibration {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  DateTime get capturedAt => throw _privateConstructorUsedError;
  int get cuffSystolic => throw _privateConstructorUsedError;
  int get cuffDiastolic => throw _privateConstructorUsedError;
  int? get bandSystolic => throw _privateConstructorUsedError;
  int? get bandDiastolic => throw _privateConstructorUsedError;
  int? get hrAtCalibration => throw _privateConstructorUsedError;
  int? get ageAtCalibration => throw _privateConstructorUsedError;
  bool get bandWriteSucceeded => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of BpCalibration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BpCalibrationCopyWith<BpCalibration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BpCalibrationCopyWith<$Res> {
  factory $BpCalibrationCopyWith(
    BpCalibration value,
    $Res Function(BpCalibration) then,
  ) = _$BpCalibrationCopyWithImpl<$Res, BpCalibration>;
  @useResult
  $Res call({
    String id,
    String userId,
    DateTime capturedAt,
    int cuffSystolic,
    int cuffDiastolic,
    int? bandSystolic,
    int? bandDiastolic,
    int? hrAtCalibration,
    int? ageAtCalibration,
    bool bandWriteSucceeded,
    String? notes,
    bool isActive,
    DateTime createdAt,
  });
}

/// @nodoc
class _$BpCalibrationCopyWithImpl<$Res, $Val extends BpCalibration>
    implements $BpCalibrationCopyWith<$Res> {
  _$BpCalibrationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BpCalibration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? capturedAt = null,
    Object? cuffSystolic = null,
    Object? cuffDiastolic = null,
    Object? bandSystolic = freezed,
    Object? bandDiastolic = freezed,
    Object? hrAtCalibration = freezed,
    Object? ageAtCalibration = freezed,
    Object? bandWriteSucceeded = null,
    Object? notes = freezed,
    Object? isActive = null,
    Object? createdAt = null,
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
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            cuffSystolic: null == cuffSystolic
                ? _value.cuffSystolic
                : cuffSystolic // ignore: cast_nullable_to_non_nullable
                      as int,
            cuffDiastolic: null == cuffDiastolic
                ? _value.cuffDiastolic
                : cuffDiastolic // ignore: cast_nullable_to_non_nullable
                      as int,
            bandSystolic: freezed == bandSystolic
                ? _value.bandSystolic
                : bandSystolic // ignore: cast_nullable_to_non_nullable
                      as int?,
            bandDiastolic: freezed == bandDiastolic
                ? _value.bandDiastolic
                : bandDiastolic // ignore: cast_nullable_to_non_nullable
                      as int?,
            hrAtCalibration: freezed == hrAtCalibration
                ? _value.hrAtCalibration
                : hrAtCalibration // ignore: cast_nullable_to_non_nullable
                      as int?,
            ageAtCalibration: freezed == ageAtCalibration
                ? _value.ageAtCalibration
                : ageAtCalibration // ignore: cast_nullable_to_non_nullable
                      as int?,
            bandWriteSucceeded: null == bandWriteSucceeded
                ? _value.bandWriteSucceeded
                : bandWriteSucceeded // ignore: cast_nullable_to_non_nullable
                      as bool,
            notes: freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BpCalibrationImplCopyWith<$Res>
    implements $BpCalibrationCopyWith<$Res> {
  factory _$$BpCalibrationImplCopyWith(
    _$BpCalibrationImpl value,
    $Res Function(_$BpCalibrationImpl) then,
  ) = __$$BpCalibrationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    DateTime capturedAt,
    int cuffSystolic,
    int cuffDiastolic,
    int? bandSystolic,
    int? bandDiastolic,
    int? hrAtCalibration,
    int? ageAtCalibration,
    bool bandWriteSucceeded,
    String? notes,
    bool isActive,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$BpCalibrationImplCopyWithImpl<$Res>
    extends _$BpCalibrationCopyWithImpl<$Res, _$BpCalibrationImpl>
    implements _$$BpCalibrationImplCopyWith<$Res> {
  __$$BpCalibrationImplCopyWithImpl(
    _$BpCalibrationImpl _value,
    $Res Function(_$BpCalibrationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BpCalibration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? capturedAt = null,
    Object? cuffSystolic = null,
    Object? cuffDiastolic = null,
    Object? bandSystolic = freezed,
    Object? bandDiastolic = freezed,
    Object? hrAtCalibration = freezed,
    Object? ageAtCalibration = freezed,
    Object? bandWriteSucceeded = null,
    Object? notes = freezed,
    Object? isActive = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$BpCalibrationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        cuffSystolic: null == cuffSystolic
            ? _value.cuffSystolic
            : cuffSystolic // ignore: cast_nullable_to_non_nullable
                  as int,
        cuffDiastolic: null == cuffDiastolic
            ? _value.cuffDiastolic
            : cuffDiastolic // ignore: cast_nullable_to_non_nullable
                  as int,
        bandSystolic: freezed == bandSystolic
            ? _value.bandSystolic
            : bandSystolic // ignore: cast_nullable_to_non_nullable
                  as int?,
        bandDiastolic: freezed == bandDiastolic
            ? _value.bandDiastolic
            : bandDiastolic // ignore: cast_nullable_to_non_nullable
                  as int?,
        hrAtCalibration: freezed == hrAtCalibration
            ? _value.hrAtCalibration
            : hrAtCalibration // ignore: cast_nullable_to_non_nullable
                  as int?,
        ageAtCalibration: freezed == ageAtCalibration
            ? _value.ageAtCalibration
            : ageAtCalibration // ignore: cast_nullable_to_non_nullable
                  as int?,
        bandWriteSucceeded: null == bandWriteSucceeded
            ? _value.bandWriteSucceeded
            : bandWriteSucceeded // ignore: cast_nullable_to_non_nullable
                  as bool,
        notes: freezed == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$BpCalibrationImpl implements _BpCalibration {
  const _$BpCalibrationImpl({
    required this.id,
    required this.userId,
    required this.capturedAt,
    required this.cuffSystolic,
    required this.cuffDiastolic,
    this.bandSystolic,
    this.bandDiastolic,
    this.hrAtCalibration,
    this.ageAtCalibration,
    this.bandWriteSucceeded = false,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final DateTime capturedAt;
  @override
  final int cuffSystolic;
  @override
  final int cuffDiastolic;
  @override
  final int? bandSystolic;
  @override
  final int? bandDiastolic;
  @override
  final int? hrAtCalibration;
  @override
  final int? ageAtCalibration;
  @override
  @JsonKey()
  final bool bandWriteSucceeded;
  @override
  final String? notes;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'BpCalibration(id: $id, userId: $userId, capturedAt: $capturedAt, cuffSystolic: $cuffSystolic, cuffDiastolic: $cuffDiastolic, bandSystolic: $bandSystolic, bandDiastolic: $bandDiastolic, hrAtCalibration: $hrAtCalibration, ageAtCalibration: $ageAtCalibration, bandWriteSucceeded: $bandWriteSucceeded, notes: $notes, isActive: $isActive, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BpCalibrationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.cuffSystolic, cuffSystolic) ||
                other.cuffSystolic == cuffSystolic) &&
            (identical(other.cuffDiastolic, cuffDiastolic) ||
                other.cuffDiastolic == cuffDiastolic) &&
            (identical(other.bandSystolic, bandSystolic) ||
                other.bandSystolic == bandSystolic) &&
            (identical(other.bandDiastolic, bandDiastolic) ||
                other.bandDiastolic == bandDiastolic) &&
            (identical(other.hrAtCalibration, hrAtCalibration) ||
                other.hrAtCalibration == hrAtCalibration) &&
            (identical(other.ageAtCalibration, ageAtCalibration) ||
                other.ageAtCalibration == ageAtCalibration) &&
            (identical(other.bandWriteSucceeded, bandWriteSucceeded) ||
                other.bandWriteSucceeded == bandWriteSucceeded) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    capturedAt,
    cuffSystolic,
    cuffDiastolic,
    bandSystolic,
    bandDiastolic,
    hrAtCalibration,
    ageAtCalibration,
    bandWriteSucceeded,
    notes,
    isActive,
    createdAt,
  );

  /// Create a copy of BpCalibration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BpCalibrationImplCopyWith<_$BpCalibrationImpl> get copyWith =>
      __$$BpCalibrationImplCopyWithImpl<_$BpCalibrationImpl>(this, _$identity);
}

abstract class _BpCalibration implements BpCalibration {
  const factory _BpCalibration({
    required final String id,
    required final String userId,
    required final DateTime capturedAt,
    required final int cuffSystolic,
    required final int cuffDiastolic,
    final int? bandSystolic,
    final int? bandDiastolic,
    final int? hrAtCalibration,
    final int? ageAtCalibration,
    final bool bandWriteSucceeded,
    final String? notes,
    final bool isActive,
    required final DateTime createdAt,
  }) = _$BpCalibrationImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  DateTime get capturedAt;
  @override
  int get cuffSystolic;
  @override
  int get cuffDiastolic;
  @override
  int? get bandSystolic;
  @override
  int? get bandDiastolic;
  @override
  int? get hrAtCalibration;
  @override
  int? get ageAtCalibration;
  @override
  bool get bandWriteSucceeded;
  @override
  String? get notes;
  @override
  bool get isActive;
  @override
  DateTime get createdAt;

  /// Create a copy of BpCalibration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BpCalibrationImplCopyWith<_$BpCalibrationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
