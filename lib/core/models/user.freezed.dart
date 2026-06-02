// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$User {
  String get id => throw _privateConstructorUsedError;
  String? get email => throw _privateConstructorUsedError;
  String? get phone => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get deletedAt => throw _privateConstructorUsedError;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserCopyWith<User> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserCopyWith<$Res> {
  factory $UserCopyWith(User value, $Res Function(User) then) =
      _$UserCopyWithImpl<$Res, User>;
  @useResult
  $Res call({
    String id,
    String? email,
    String? phone,
    String? displayName,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class _$UserCopyWithImpl<$Res, $Val extends User>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? phone = freezed,
    Object? displayName = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            email: freezed == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String?,
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
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
abstract class _$$UserImplCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$$UserImplCopyWith(
    _$UserImpl value,
    $Res Function(_$UserImpl) then,
  ) = __$$UserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? email,
    String? phone,
    String? displayName,
    DateTime createdAt,
    DateTime updatedAt,
    DateTime? deletedAt,
  });
}

/// @nodoc
class __$$UserImplCopyWithImpl<$Res>
    extends _$UserCopyWithImpl<$Res, _$UserImpl>
    implements _$$UserImplCopyWith<$Res> {
  __$$UserImplCopyWithImpl(_$UserImpl _value, $Res Function(_$UserImpl) _then)
    : super(_value, _then);

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = freezed,
    Object? phone = freezed,
    Object? displayName = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? deletedAt = freezed,
  }) {
    return _then(
      _$UserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        email: freezed == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String?,
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        deletedAt: freezed == deletedAt
            ? _value.deletedAt
            : deletedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$UserImpl implements _User {
  const _$UserImpl({
    required this.id,
    this.email,
    this.phone,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  @override
  final String id;
  @override
  final String? email;
  @override
  final String? phone;
  @override
  final String? displayName;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  @override
  String toString() {
    return 'User(id: $id, email: $email, phone: $phone, displayName: $displayName, createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.deletedAt, deletedAt) ||
                other.deletedAt == deletedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    email,
    phone,
    displayName,
    createdAt,
    updatedAt,
    deletedAt,
  );

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      __$$UserImplCopyWithImpl<_$UserImpl>(this, _$identity);
}

abstract class _User implements User {
  const factory _User({
    required final String id,
    final String? email,
    final String? phone,
    final String? displayName,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final DateTime? deletedAt,
  }) = _$UserImpl;

  @override
  String get id;
  @override
  String? get email;
  @override
  String? get phone;
  @override
  String? get displayName;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get deletedAt;

  /// Create a copy of User
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserImplCopyWith<_$UserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$UserProfile {
  String get userId => throw _privateConstructorUsedError;
  DateTime? get dateOfBirth => throw _privateConstructorUsedError;
  SexAtBirth get sexAtBirth => throw _privateConstructorUsedError;
  double? get heightCm => throw _privateConstructorUsedError;
  double? get weightKg => throw _privateConstructorUsedError;
  bool get usesMetric => throw _privateConstructorUsedError;
  bool get uses24hClock => throw _privateConstructorUsedError;
  int? get restingHrBaseline => throw _privateConstructorUsedError;
  bool get cycleTrackingEnabled => throw _privateConstructorUsedError;
  DateTime? get lastPeriodStartDate => throw _privateConstructorUsedError;
  int? get typicalCycleLength => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileCopyWith<UserProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileCopyWith<$Res> {
  factory $UserProfileCopyWith(
    UserProfile value,
    $Res Function(UserProfile) then,
  ) = _$UserProfileCopyWithImpl<$Res, UserProfile>;
  @useResult
  $Res call({
    String userId,
    DateTime? dateOfBirth,
    SexAtBirth sexAtBirth,
    double? heightCm,
    double? weightKg,
    bool usesMetric,
    bool uses24hClock,
    int? restingHrBaseline,
    bool cycleTrackingEnabled,
    DateTime? lastPeriodStartDate,
    int? typicalCycleLength,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$UserProfileCopyWithImpl<$Res, $Val extends UserProfile>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? dateOfBirth = freezed,
    Object? sexAtBirth = null,
    Object? heightCm = freezed,
    Object? weightKg = freezed,
    Object? usesMetric = null,
    Object? uses24hClock = null,
    Object? restingHrBaseline = freezed,
    Object? cycleTrackingEnabled = null,
    Object? lastPeriodStartDate = freezed,
    Object? typicalCycleLength = freezed,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            dateOfBirth: freezed == dateOfBirth
                ? _value.dateOfBirth
                : dateOfBirth // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            sexAtBirth: null == sexAtBirth
                ? _value.sexAtBirth
                : sexAtBirth // ignore: cast_nullable_to_non_nullable
                      as SexAtBirth,
            heightCm: freezed == heightCm
                ? _value.heightCm
                : heightCm // ignore: cast_nullable_to_non_nullable
                      as double?,
            weightKg: freezed == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double?,
            usesMetric: null == usesMetric
                ? _value.usesMetric
                : usesMetric // ignore: cast_nullable_to_non_nullable
                      as bool,
            uses24hClock: null == uses24hClock
                ? _value.uses24hClock
                : uses24hClock // ignore: cast_nullable_to_non_nullable
                      as bool,
            restingHrBaseline: freezed == restingHrBaseline
                ? _value.restingHrBaseline
                : restingHrBaseline // ignore: cast_nullable_to_non_nullable
                      as int?,
            cycleTrackingEnabled: null == cycleTrackingEnabled
                ? _value.cycleTrackingEnabled
                : cycleTrackingEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastPeriodStartDate: freezed == lastPeriodStartDate
                ? _value.lastPeriodStartDate
                : lastPeriodStartDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            typicalCycleLength: freezed == typicalCycleLength
                ? _value.typicalCycleLength
                : typicalCycleLength // ignore: cast_nullable_to_non_nullable
                      as int?,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserProfileImplCopyWith<$Res>
    implements $UserProfileCopyWith<$Res> {
  factory _$$UserProfileImplCopyWith(
    _$UserProfileImpl value,
    $Res Function(_$UserProfileImpl) then,
  ) = __$$UserProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String userId,
    DateTime? dateOfBirth,
    SexAtBirth sexAtBirth,
    double? heightCm,
    double? weightKg,
    bool usesMetric,
    bool uses24hClock,
    int? restingHrBaseline,
    bool cycleTrackingEnabled,
    DateTime? lastPeriodStartDate,
    int? typicalCycleLength,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$UserProfileImplCopyWithImpl<$Res>
    extends _$UserProfileCopyWithImpl<$Res, _$UserProfileImpl>
    implements _$$UserProfileImplCopyWith<$Res> {
  __$$UserProfileImplCopyWithImpl(
    _$UserProfileImpl _value,
    $Res Function(_$UserProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? dateOfBirth = freezed,
    Object? sexAtBirth = null,
    Object? heightCm = freezed,
    Object? weightKg = freezed,
    Object? usesMetric = null,
    Object? uses24hClock = null,
    Object? restingHrBaseline = freezed,
    Object? cycleTrackingEnabled = null,
    Object? lastPeriodStartDate = freezed,
    Object? typicalCycleLength = freezed,
    Object? updatedAt = null,
  }) {
    return _then(
      _$UserProfileImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        dateOfBirth: freezed == dateOfBirth
            ? _value.dateOfBirth
            : dateOfBirth // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        sexAtBirth: null == sexAtBirth
            ? _value.sexAtBirth
            : sexAtBirth // ignore: cast_nullable_to_non_nullable
                  as SexAtBirth,
        heightCm: freezed == heightCm
            ? _value.heightCm
            : heightCm // ignore: cast_nullable_to_non_nullable
                  as double?,
        weightKg: freezed == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double?,
        usesMetric: null == usesMetric
            ? _value.usesMetric
            : usesMetric // ignore: cast_nullable_to_non_nullable
                  as bool,
        uses24hClock: null == uses24hClock
            ? _value.uses24hClock
            : uses24hClock // ignore: cast_nullable_to_non_nullable
                  as bool,
        restingHrBaseline: freezed == restingHrBaseline
            ? _value.restingHrBaseline
            : restingHrBaseline // ignore: cast_nullable_to_non_nullable
                  as int?,
        cycleTrackingEnabled: null == cycleTrackingEnabled
            ? _value.cycleTrackingEnabled
            : cycleTrackingEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastPeriodStartDate: freezed == lastPeriodStartDate
            ? _value.lastPeriodStartDate
            : lastPeriodStartDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        typicalCycleLength: freezed == typicalCycleLength
            ? _value.typicalCycleLength
            : typicalCycleLength // ignore: cast_nullable_to_non_nullable
                  as int?,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$UserProfileImpl implements _UserProfile {
  const _$UserProfileImpl({
    required this.userId,
    this.dateOfBirth,
    this.sexAtBirth = SexAtBirth.unknown,
    this.heightCm,
    this.weightKg,
    this.usesMetric = true,
    this.uses24hClock = true,
    this.restingHrBaseline,
    this.cycleTrackingEnabled = false,
    this.lastPeriodStartDate,
    this.typicalCycleLength,
    required this.updatedAt,
  });

  @override
  final String userId;
  @override
  final DateTime? dateOfBirth;
  @override
  @JsonKey()
  final SexAtBirth sexAtBirth;
  @override
  final double? heightCm;
  @override
  final double? weightKg;
  @override
  @JsonKey()
  final bool usesMetric;
  @override
  @JsonKey()
  final bool uses24hClock;
  @override
  final int? restingHrBaseline;
  @override
  @JsonKey()
  final bool cycleTrackingEnabled;
  @override
  final DateTime? lastPeriodStartDate;
  @override
  final int? typicalCycleLength;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'UserProfile(userId: $userId, dateOfBirth: $dateOfBirth, sexAtBirth: $sexAtBirth, heightCm: $heightCm, weightKg: $weightKg, usesMetric: $usesMetric, uses24hClock: $uses24hClock, restingHrBaseline: $restingHrBaseline, cycleTrackingEnabled: $cycleTrackingEnabled, lastPeriodStartDate: $lastPeriodStartDate, typicalCycleLength: $typicalCycleLength, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.dateOfBirth, dateOfBirth) ||
                other.dateOfBirth == dateOfBirth) &&
            (identical(other.sexAtBirth, sexAtBirth) ||
                other.sexAtBirth == sexAtBirth) &&
            (identical(other.heightCm, heightCm) ||
                other.heightCm == heightCm) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.usesMetric, usesMetric) ||
                other.usesMetric == usesMetric) &&
            (identical(other.uses24hClock, uses24hClock) ||
                other.uses24hClock == uses24hClock) &&
            (identical(other.restingHrBaseline, restingHrBaseline) ||
                other.restingHrBaseline == restingHrBaseline) &&
            (identical(other.cycleTrackingEnabled, cycleTrackingEnabled) ||
                other.cycleTrackingEnabled == cycleTrackingEnabled) &&
            (identical(other.lastPeriodStartDate, lastPeriodStartDate) ||
                other.lastPeriodStartDate == lastPeriodStartDate) &&
            (identical(other.typicalCycleLength, typicalCycleLength) ||
                other.typicalCycleLength == typicalCycleLength) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    dateOfBirth,
    sexAtBirth,
    heightCm,
    weightKg,
    usesMetric,
    uses24hClock,
    restingHrBaseline,
    cycleTrackingEnabled,
    lastPeriodStartDate,
    typicalCycleLength,
    updatedAt,
  );

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      __$$UserProfileImplCopyWithImpl<_$UserProfileImpl>(this, _$identity);
}

abstract class _UserProfile implements UserProfile {
  const factory _UserProfile({
    required final String userId,
    final DateTime? dateOfBirth,
    final SexAtBirth sexAtBirth,
    final double? heightCm,
    final double? weightKg,
    final bool usesMetric,
    final bool uses24hClock,
    final int? restingHrBaseline,
    final bool cycleTrackingEnabled,
    final DateTime? lastPeriodStartDate,
    final int? typicalCycleLength,
    required final DateTime updatedAt,
  }) = _$UserProfileImpl;

  @override
  String get userId;
  @override
  DateTime? get dateOfBirth;
  @override
  SexAtBirth get sexAtBirth;
  @override
  double? get heightCm;
  @override
  double? get weightKg;
  @override
  bool get usesMetric;
  @override
  bool get uses24hClock;
  @override
  int? get restingHrBaseline;
  @override
  bool get cycleTrackingEnabled;
  @override
  DateTime? get lastPeriodStartDate;
  @override
  int? get typicalCycleLength;
  @override
  DateTime get updatedAt;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
