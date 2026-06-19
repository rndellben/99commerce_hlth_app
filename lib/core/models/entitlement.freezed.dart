// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entitlement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Entitlement {
  SubscriptionTier get tier => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  Set<String> get enabledFeatures => throw _privateConstructorUsedError;

  /// Create a copy of Entitlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EntitlementCopyWith<Entitlement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntitlementCopyWith<$Res> {
  factory $EntitlementCopyWith(
    Entitlement value,
    $Res Function(Entitlement) then,
  ) = _$EntitlementCopyWithImpl<$Res, Entitlement>;
  @useResult
  $Res call({
    SubscriptionTier tier,
    DateTime? expiresAt,
    Set<String> enabledFeatures,
  });
}

/// @nodoc
class _$EntitlementCopyWithImpl<$Res, $Val extends Entitlement>
    implements $EntitlementCopyWith<$Res> {
  _$EntitlementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Entitlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tier = null,
    Object? expiresAt = freezed,
    Object? enabledFeatures = null,
  }) {
    return _then(
      _value.copyWith(
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as SubscriptionTier,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            enabledFeatures: null == enabledFeatures
                ? _value.enabledFeatures
                : enabledFeatures // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EntitlementImplCopyWith<$Res>
    implements $EntitlementCopyWith<$Res> {
  factory _$$EntitlementImplCopyWith(
    _$EntitlementImpl value,
    $Res Function(_$EntitlementImpl) then,
  ) = __$$EntitlementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SubscriptionTier tier,
    DateTime? expiresAt,
    Set<String> enabledFeatures,
  });
}

/// @nodoc
class __$$EntitlementImplCopyWithImpl<$Res>
    extends _$EntitlementCopyWithImpl<$Res, _$EntitlementImpl>
    implements _$$EntitlementImplCopyWith<$Res> {
  __$$EntitlementImplCopyWithImpl(
    _$EntitlementImpl _value,
    $Res Function(_$EntitlementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Entitlement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? tier = null,
    Object? expiresAt = freezed,
    Object? enabledFeatures = null,
  }) {
    return _then(
      _$EntitlementImpl(
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as SubscriptionTier,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        enabledFeatures: null == enabledFeatures
            ? _value._enabledFeatures
            : enabledFeatures // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// @nodoc

class _$EntitlementImpl extends _Entitlement {
  const _$EntitlementImpl({
    required this.tier,
    this.expiresAt,
    final Set<String> enabledFeatures = const {},
  }) : _enabledFeatures = enabledFeatures,
       super._();

  @override
  final SubscriptionTier tier;
  @override
  final DateTime? expiresAt;
  final Set<String> _enabledFeatures;
  @override
  @JsonKey()
  Set<String> get enabledFeatures {
    if (_enabledFeatures is EqualUnmodifiableSetView) return _enabledFeatures;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_enabledFeatures);
  }

  @override
  String toString() {
    return 'Entitlement(tier: $tier, expiresAt: $expiresAt, enabledFeatures: $enabledFeatures)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntitlementImpl &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            const DeepCollectionEquality().equals(
              other._enabledFeatures,
              _enabledFeatures,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    tier,
    expiresAt,
    const DeepCollectionEquality().hash(_enabledFeatures),
  );

  /// Create a copy of Entitlement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntitlementImplCopyWith<_$EntitlementImpl> get copyWith =>
      __$$EntitlementImplCopyWithImpl<_$EntitlementImpl>(this, _$identity);
}

abstract class _Entitlement extends Entitlement {
  const factory _Entitlement({
    required final SubscriptionTier tier,
    final DateTime? expiresAt,
    final Set<String> enabledFeatures,
  }) = _$EntitlementImpl;
  const _Entitlement._() : super._();

  @override
  SubscriptionTier get tier;
  @override
  DateTime? get expiresAt;
  @override
  Set<String> get enabledFeatures;

  /// Create a copy of Entitlement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntitlementImplCopyWith<_$EntitlementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
