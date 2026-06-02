// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    phone,
    displayName,
    createdAtUtc,
    updatedAtUtc,
    deletedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String? email;
  final String? phone;
  final String? displayName;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int? deletedAtUtc;
  const User({
    required this.id,
    this.email,
    this.phone,
    this.displayName,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.deletedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String?>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String?>(email),
      'phone': serializer.toJson<String?>(phone),
      'displayName': serializer.toJson<String?>(displayName),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
    };
  }

  User copyWith({
    String? id,
    Value<String?> email = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    int? createdAtUtc,
    int? updatedAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    email: email.present ? email.value : this.email,
    phone: phone.present ? phone.value : this.phone,
    displayName: displayName.present ? displayName.value : this.displayName,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    phone,
    displayName,
    createdAtUtc,
    updatedAtUtc,
    deletedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.displayName == this.displayName &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String?> email;
  final Value<String?> phone;
  final Value<String?> displayName;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.displayName = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? displayName,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (displayName != null) 'display_name': displayName,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String?>? email,
    Value<String?>? phone,
    Value<String?>? displayName,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _dateOfBirthMeta = const VerificationMeta(
    'dateOfBirth',
  );
  @override
  late final GeneratedColumn<String> dateOfBirth = GeneratedColumn<String>(
    'date_of_birth',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SexAtBirth, int> sexAtBirth =
      GeneratedColumn<int>(
        'sex_at_birth',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(2),
      ).withConverter<SexAtBirth>($UserProfilesTable.$convertersexAtBirth);
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usesMetricMeta = const VerificationMeta(
    'usesMetric',
  );
  @override
  late final GeneratedColumn<bool> usesMetric = GeneratedColumn<bool>(
    'uses_metric',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uses_metric" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _uses24hClockMeta = const VerificationMeta(
    'uses24hClock',
  );
  @override
  late final GeneratedColumn<bool> uses24hClock = GeneratedColumn<bool>(
    'uses24h_clock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uses24h_clock" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _restingHrBaselineMeta = const VerificationMeta(
    'restingHrBaseline',
  );
  @override
  late final GeneratedColumn<int> restingHrBaseline = GeneratedColumn<int>(
    'resting_hr_baseline',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleTrackingEnabledMeta =
      const VerificationMeta('cycleTrackingEnabled');
  @override
  late final GeneratedColumn<bool> cycleTrackingEnabled = GeneratedColumn<bool>(
    'cycle_tracking_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cycle_tracking_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPeriodStartDateMeta =
      const VerificationMeta('lastPeriodStartDate');
  @override
  late final GeneratedColumn<String> lastPeriodStartDate =
      GeneratedColumn<String>(
        'last_period_start_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _typicalCycleLengthMeta =
      const VerificationMeta('typicalCycleLength');
  @override
  late final GeneratedColumn<int> typicalCycleLength = GeneratedColumn<int>(
    'typical_cycle_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('date_of_birth')) {
      context.handle(
        _dateOfBirthMeta,
        dateOfBirth.isAcceptableOrUnknown(
          data['date_of_birth']!,
          _dateOfBirthMeta,
        ),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('uses_metric')) {
      context.handle(
        _usesMetricMeta,
        usesMetric.isAcceptableOrUnknown(data['uses_metric']!, _usesMetricMeta),
      );
    }
    if (data.containsKey('uses24h_clock')) {
      context.handle(
        _uses24hClockMeta,
        uses24hClock.isAcceptableOrUnknown(
          data['uses24h_clock']!,
          _uses24hClockMeta,
        ),
      );
    }
    if (data.containsKey('resting_hr_baseline')) {
      context.handle(
        _restingHrBaselineMeta,
        restingHrBaseline.isAcceptableOrUnknown(
          data['resting_hr_baseline']!,
          _restingHrBaselineMeta,
        ),
      );
    }
    if (data.containsKey('cycle_tracking_enabled')) {
      context.handle(
        _cycleTrackingEnabledMeta,
        cycleTrackingEnabled.isAcceptableOrUnknown(
          data['cycle_tracking_enabled']!,
          _cycleTrackingEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_period_start_date')) {
      context.handle(
        _lastPeriodStartDateMeta,
        lastPeriodStartDate.isAcceptableOrUnknown(
          data['last_period_start_date']!,
          _lastPeriodStartDateMeta,
        ),
      );
    }
    if (data.containsKey('typical_cycle_length')) {
      context.handle(
        _typicalCycleLengthMeta,
        typicalCycleLength.isAcceptableOrUnknown(
          data['typical_cycle_length']!,
          _typicalCycleLengthMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      dateOfBirth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_of_birth'],
      ),
      sexAtBirth: $UserProfilesTable.$convertersexAtBirth.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sex_at_birth'],
        )!,
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      usesMetric: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uses_metric'],
      )!,
      uses24hClock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uses24h_clock'],
      )!,
      restingHrBaseline: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resting_hr_baseline'],
      ),
      cycleTrackingEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cycle_tracking_enabled'],
      )!,
      lastPeriodStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_period_start_date'],
      ),
      typicalCycleLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}typical_cycle_length'],
      ),
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SexAtBirth, int, int> $convertersexAtBirth =
      const EnumIndexConverter<SexAtBirth>(SexAtBirth.values);
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final String userId;
  final String? dateOfBirth;
  final SexAtBirth sexAtBirth;
  final double? heightCm;
  final double? weightKg;
  final bool usesMetric;
  final bool uses24hClock;
  final int? restingHrBaseline;
  final bool cycleTrackingEnabled;
  final String? lastPeriodStartDate;
  final int? typicalCycleLength;
  final int updatedAtUtc;
  const UserProfile({
    required this.userId,
    this.dateOfBirth,
    required this.sexAtBirth,
    this.heightCm,
    this.weightKg,
    required this.usesMetric,
    required this.uses24hClock,
    this.restingHrBaseline,
    required this.cycleTrackingEnabled,
    this.lastPeriodStartDate,
    this.typicalCycleLength,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || dateOfBirth != null) {
      map['date_of_birth'] = Variable<String>(dateOfBirth);
    }
    {
      map['sex_at_birth'] = Variable<int>(
        $UserProfilesTable.$convertersexAtBirth.toSql(sexAtBirth),
      );
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    map['uses_metric'] = Variable<bool>(usesMetric);
    map['uses24h_clock'] = Variable<bool>(uses24hClock);
    if (!nullToAbsent || restingHrBaseline != null) {
      map['resting_hr_baseline'] = Variable<int>(restingHrBaseline);
    }
    map['cycle_tracking_enabled'] = Variable<bool>(cycleTrackingEnabled);
    if (!nullToAbsent || lastPeriodStartDate != null) {
      map['last_period_start_date'] = Variable<String>(lastPeriodStartDate);
    }
    if (!nullToAbsent || typicalCycleLength != null) {
      map['typical_cycle_length'] = Variable<int>(typicalCycleLength);
    }
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      userId: Value(userId),
      dateOfBirth: dateOfBirth == null && nullToAbsent
          ? const Value.absent()
          : Value(dateOfBirth),
      sexAtBirth: Value(sexAtBirth),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      usesMetric: Value(usesMetric),
      uses24hClock: Value(uses24hClock),
      restingHrBaseline: restingHrBaseline == null && nullToAbsent
          ? const Value.absent()
          : Value(restingHrBaseline),
      cycleTrackingEnabled: Value(cycleTrackingEnabled),
      lastPeriodStartDate: lastPeriodStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPeriodStartDate),
      typicalCycleLength: typicalCycleLength == null && nullToAbsent
          ? const Value.absent()
          : Value(typicalCycleLength),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      userId: serializer.fromJson<String>(json['userId']),
      dateOfBirth: serializer.fromJson<String?>(json['dateOfBirth']),
      sexAtBirth: $UserProfilesTable.$convertersexAtBirth.fromJson(
        serializer.fromJson<int>(json['sexAtBirth']),
      ),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      usesMetric: serializer.fromJson<bool>(json['usesMetric']),
      uses24hClock: serializer.fromJson<bool>(json['uses24hClock']),
      restingHrBaseline: serializer.fromJson<int?>(json['restingHrBaseline']),
      cycleTrackingEnabled: serializer.fromJson<bool>(
        json['cycleTrackingEnabled'],
      ),
      lastPeriodStartDate: serializer.fromJson<String?>(
        json['lastPeriodStartDate'],
      ),
      typicalCycleLength: serializer.fromJson<int?>(json['typicalCycleLength']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'dateOfBirth': serializer.toJson<String?>(dateOfBirth),
      'sexAtBirth': serializer.toJson<int>(
        $UserProfilesTable.$convertersexAtBirth.toJson(sexAtBirth),
      ),
      'heightCm': serializer.toJson<double?>(heightCm),
      'weightKg': serializer.toJson<double?>(weightKg),
      'usesMetric': serializer.toJson<bool>(usesMetric),
      'uses24hClock': serializer.toJson<bool>(uses24hClock),
      'restingHrBaseline': serializer.toJson<int?>(restingHrBaseline),
      'cycleTrackingEnabled': serializer.toJson<bool>(cycleTrackingEnabled),
      'lastPeriodStartDate': serializer.toJson<String?>(lastPeriodStartDate),
      'typicalCycleLength': serializer.toJson<int?>(typicalCycleLength),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  UserProfile copyWith({
    String? userId,
    Value<String?> dateOfBirth = const Value.absent(),
    SexAtBirth? sexAtBirth,
    Value<double?> heightCm = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    bool? usesMetric,
    bool? uses24hClock,
    Value<int?> restingHrBaseline = const Value.absent(),
    bool? cycleTrackingEnabled,
    Value<String?> lastPeriodStartDate = const Value.absent(),
    Value<int?> typicalCycleLength = const Value.absent(),
    int? updatedAtUtc,
  }) => UserProfile(
    userId: userId ?? this.userId,
    dateOfBirth: dateOfBirth.present ? dateOfBirth.value : this.dateOfBirth,
    sexAtBirth: sexAtBirth ?? this.sexAtBirth,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    usesMetric: usesMetric ?? this.usesMetric,
    uses24hClock: uses24hClock ?? this.uses24hClock,
    restingHrBaseline: restingHrBaseline.present
        ? restingHrBaseline.value
        : this.restingHrBaseline,
    cycleTrackingEnabled: cycleTrackingEnabled ?? this.cycleTrackingEnabled,
    lastPeriodStartDate: lastPeriodStartDate.present
        ? lastPeriodStartDate.value
        : this.lastPeriodStartDate,
    typicalCycleLength: typicalCycleLength.present
        ? typicalCycleLength.value
        : this.typicalCycleLength,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      userId: data.userId.present ? data.userId.value : this.userId,
      dateOfBirth: data.dateOfBirth.present
          ? data.dateOfBirth.value
          : this.dateOfBirth,
      sexAtBirth: data.sexAtBirth.present
          ? data.sexAtBirth.value
          : this.sexAtBirth,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      usesMetric: data.usesMetric.present
          ? data.usesMetric.value
          : this.usesMetric,
      uses24hClock: data.uses24hClock.present
          ? data.uses24hClock.value
          : this.uses24hClock,
      restingHrBaseline: data.restingHrBaseline.present
          ? data.restingHrBaseline.value
          : this.restingHrBaseline,
      cycleTrackingEnabled: data.cycleTrackingEnabled.present
          ? data.cycleTrackingEnabled.value
          : this.cycleTrackingEnabled,
      lastPeriodStartDate: data.lastPeriodStartDate.present
          ? data.lastPeriodStartDate.value
          : this.lastPeriodStartDate,
      typicalCycleLength: data.typicalCycleLength.present
          ? data.typicalCycleLength.value
          : this.typicalCycleLength,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('userId: $userId, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('sexAtBirth: $sexAtBirth, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('usesMetric: $usesMetric, ')
          ..write('uses24hClock: $uses24hClock, ')
          ..write('restingHrBaseline: $restingHrBaseline, ')
          ..write('cycleTrackingEnabled: $cycleTrackingEnabled, ')
          ..write('lastPeriodStartDate: $lastPeriodStartDate, ')
          ..write('typicalCycleLength: $typicalCycleLength, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
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
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.userId == this.userId &&
          other.dateOfBirth == this.dateOfBirth &&
          other.sexAtBirth == this.sexAtBirth &&
          other.heightCm == this.heightCm &&
          other.weightKg == this.weightKg &&
          other.usesMetric == this.usesMetric &&
          other.uses24hClock == this.uses24hClock &&
          other.restingHrBaseline == this.restingHrBaseline &&
          other.cycleTrackingEnabled == this.cycleTrackingEnabled &&
          other.lastPeriodStartDate == this.lastPeriodStartDate &&
          other.typicalCycleLength == this.typicalCycleLength &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<String> userId;
  final Value<String?> dateOfBirth;
  final Value<SexAtBirth> sexAtBirth;
  final Value<double?> heightCm;
  final Value<double?> weightKg;
  final Value<bool> usesMetric;
  final Value<bool> uses24hClock;
  final Value<int?> restingHrBaseline;
  final Value<bool> cycleTrackingEnabled;
  final Value<String?> lastPeriodStartDate;
  final Value<int?> typicalCycleLength;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.userId = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.sexAtBirth = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.usesMetric = const Value.absent(),
    this.uses24hClock = const Value.absent(),
    this.restingHrBaseline = const Value.absent(),
    this.cycleTrackingEnabled = const Value.absent(),
    this.lastPeriodStartDate = const Value.absent(),
    this.typicalCycleLength = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    required String userId,
    this.dateOfBirth = const Value.absent(),
    this.sexAtBirth = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.usesMetric = const Value.absent(),
    this.uses24hClock = const Value.absent(),
    this.restingHrBaseline = const Value.absent(),
    this.cycleTrackingEnabled = const Value.absent(),
    this.lastPeriodStartDate = const Value.absent(),
    this.typicalCycleLength = const Value.absent(),
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<UserProfile> custom({
    Expression<String>? userId,
    Expression<String>? dateOfBirth,
    Expression<int>? sexAtBirth,
    Expression<double>? heightCm,
    Expression<double>? weightKg,
    Expression<bool>? usesMetric,
    Expression<bool>? uses24hClock,
    Expression<int>? restingHrBaseline,
    Expression<bool>? cycleTrackingEnabled,
    Expression<String>? lastPeriodStartDate,
    Expression<int>? typicalCycleLength,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (sexAtBirth != null) 'sex_at_birth': sexAtBirth,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (usesMetric != null) 'uses_metric': usesMetric,
      if (uses24hClock != null) 'uses24h_clock': uses24hClock,
      if (restingHrBaseline != null) 'resting_hr_baseline': restingHrBaseline,
      if (cycleTrackingEnabled != null)
        'cycle_tracking_enabled': cycleTrackingEnabled,
      if (lastPeriodStartDate != null)
        'last_period_start_date': lastPeriodStartDate,
      if (typicalCycleLength != null)
        'typical_cycle_length': typicalCycleLength,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? userId,
    Value<String?>? dateOfBirth,
    Value<SexAtBirth>? sexAtBirth,
    Value<double?>? heightCm,
    Value<double?>? weightKg,
    Value<bool>? usesMetric,
    Value<bool>? uses24hClock,
    Value<int?>? restingHrBaseline,
    Value<bool>? cycleTrackingEnabled,
    Value<String?>? lastPeriodStartDate,
    Value<int?>? typicalCycleLength,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      userId: userId ?? this.userId,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sexAtBirth: sexAtBirth ?? this.sexAtBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      usesMetric: usesMetric ?? this.usesMetric,
      uses24hClock: uses24hClock ?? this.uses24hClock,
      restingHrBaseline: restingHrBaseline ?? this.restingHrBaseline,
      cycleTrackingEnabled: cycleTrackingEnabled ?? this.cycleTrackingEnabled,
      lastPeriodStartDate: lastPeriodStartDate ?? this.lastPeriodStartDate,
      typicalCycleLength: typicalCycleLength ?? this.typicalCycleLength,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (dateOfBirth.present) {
      map['date_of_birth'] = Variable<String>(dateOfBirth.value);
    }
    if (sexAtBirth.present) {
      map['sex_at_birth'] = Variable<int>(
        $UserProfilesTable.$convertersexAtBirth.toSql(sexAtBirth.value),
      );
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (usesMetric.present) {
      map['uses_metric'] = Variable<bool>(usesMetric.value);
    }
    if (uses24hClock.present) {
      map['uses24h_clock'] = Variable<bool>(uses24hClock.value);
    }
    if (restingHrBaseline.present) {
      map['resting_hr_baseline'] = Variable<int>(restingHrBaseline.value);
    }
    if (cycleTrackingEnabled.present) {
      map['cycle_tracking_enabled'] = Variable<bool>(
        cycleTrackingEnabled.value,
      );
    }
    if (lastPeriodStartDate.present) {
      map['last_period_start_date'] = Variable<String>(
        lastPeriodStartDate.value,
      );
    }
    if (typicalCycleLength.present) {
      map['typical_cycle_length'] = Variable<int>(typicalCycleLength.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('userId: $userId, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('sexAtBirth: $sexAtBirth, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('usesMetric: $usesMetric, ')
          ..write('uses24hClock: $uses24hClock, ')
          ..write('restingHrBaseline: $restingHrBaseline, ')
          ..write('cycleTrackingEnabled: $cycleTrackingEnabled, ')
          ..write('lastPeriodStartDate: $lastPeriodStartDate, ')
          ..write('typicalCycleLength: $typicalCycleLength, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _macAddressMeta = const VerificationMeta(
    'macAddress',
  );
  @override
  late final GeneratedColumn<String> macAddress = GeneratedColumn<String>(
    'mac_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _iosPeripheralUuidMeta = const VerificationMeta(
    'iosPeripheralUuid',
  );
  @override
  late final GeneratedColumn<String> iosPeripheralUuid =
      GeneratedColumn<String>(
        'ios_peripheral_uuid',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hardwareVersionMeta = const VerificationMeta(
    'hardwareVersion',
  );
  @override
  late final GeneratedColumn<String> hardwareVersion = GeneratedColumn<String>(
    'hardware_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firmwareVersionMeta = const VerificationMeta(
    'firmwareVersion',
  );
  @override
  late final GeneratedColumn<String> firmwareVersion = GeneratedColumn<String>(
    'firmware_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdOnBandMeta = const VerificationMeta(
    'userIdOnBand',
  );
  @override
  late final GeneratedColumn<String> userIdOnBand = GeneratedColumn<String>(
    'user_id_on_band',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pairedAtUtcMeta = const VerificationMeta(
    'pairedAtUtc',
  );
  @override
  late final GeneratedColumn<int> pairedAtUtc = GeneratedColumn<int>(
    'paired_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtUtcMeta =
      const VerificationMeta('lastConnectedAtUtc');
  @override
  late final GeneratedColumn<int> lastConnectedAtUtc = GeneratedColumn<int>(
    'last_connected_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastBatteryPercentMeta =
      const VerificationMeta('lastBatteryPercent');
  @override
  late final GeneratedColumn<int> lastBatteryPercent = GeneratedColumn<int>(
    'last_battery_percent',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChargingMeta = const VerificationMeta(
    'lastCharging',
  );
  @override
  late final GeneratedColumn<bool> lastCharging = GeneratedColumn<bool>(
    'last_charging',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("last_charging" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _capabilitiesMeta = const VerificationMeta(
    'capabilities',
  );
  @override
  late final GeneratedColumn<String> capabilities = GeneratedColumn<String>(
    'capabilities',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    macAddress,
    iosPeripheralUuid,
    displayName,
    model,
    hardwareVersion,
    firmwareVersion,
    userIdOnBand,
    pairedAtUtc,
    lastConnectedAtUtc,
    lastBatteryPercent,
    lastCharging,
    isActive,
    capabilities,
    deletedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('mac_address')) {
      context.handle(
        _macAddressMeta,
        macAddress.isAcceptableOrUnknown(data['mac_address']!, _macAddressMeta),
      );
    }
    if (data.containsKey('ios_peripheral_uuid')) {
      context.handle(
        _iosPeripheralUuidMeta,
        iosPeripheralUuid.isAcceptableOrUnknown(
          data['ios_peripheral_uuid']!,
          _iosPeripheralUuidMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('hardware_version')) {
      context.handle(
        _hardwareVersionMeta,
        hardwareVersion.isAcceptableOrUnknown(
          data['hardware_version']!,
          _hardwareVersionMeta,
        ),
      );
    }
    if (data.containsKey('firmware_version')) {
      context.handle(
        _firmwareVersionMeta,
        firmwareVersion.isAcceptableOrUnknown(
          data['firmware_version']!,
          _firmwareVersionMeta,
        ),
      );
    }
    if (data.containsKey('user_id_on_band')) {
      context.handle(
        _userIdOnBandMeta,
        userIdOnBand.isAcceptableOrUnknown(
          data['user_id_on_band']!,
          _userIdOnBandMeta,
        ),
      );
    }
    if (data.containsKey('paired_at_utc')) {
      context.handle(
        _pairedAtUtcMeta,
        pairedAtUtc.isAcceptableOrUnknown(
          data['paired_at_utc']!,
          _pairedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pairedAtUtcMeta);
    }
    if (data.containsKey('last_connected_at_utc')) {
      context.handle(
        _lastConnectedAtUtcMeta,
        lastConnectedAtUtc.isAcceptableOrUnknown(
          data['last_connected_at_utc']!,
          _lastConnectedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_battery_percent')) {
      context.handle(
        _lastBatteryPercentMeta,
        lastBatteryPercent.isAcceptableOrUnknown(
          data['last_battery_percent']!,
          _lastBatteryPercentMeta,
        ),
      );
    }
    if (data.containsKey('last_charging')) {
      context.handle(
        _lastChargingMeta,
        lastCharging.isAcceptableOrUnknown(
          data['last_charging']!,
          _lastChargingMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('capabilities')) {
      context.handle(
        _capabilitiesMeta,
        capabilities.isAcceptableOrUnknown(
          data['capabilities']!,
          _capabilitiesMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      macAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac_address'],
      ),
      iosPeripheralUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ios_peripheral_uuid'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      hardwareVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hardware_version'],
      ),
      firmwareVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firmware_version'],
      ),
      userIdOnBand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id_on_band'],
      ),
      pairedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paired_at_utc'],
      )!,
      lastConnectedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_connected_at_utc'],
      ),
      lastBatteryPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_battery_percent'],
      ),
      lastCharging: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}last_charging'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      capabilities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String id;
  final String userId;
  final String? macAddress;
  final String? iosPeripheralUuid;
  final String displayName;
  final String? model;
  final String? hardwareVersion;
  final String? firmwareVersion;
  final String? userIdOnBand;
  final int pairedAtUtc;
  final int? lastConnectedAtUtc;
  final int? lastBatteryPercent;
  final bool? lastCharging;
  final bool isActive;
  final String capabilities;
  final int? deletedAtUtc;
  const Device({
    required this.id,
    required this.userId,
    this.macAddress,
    this.iosPeripheralUuid,
    required this.displayName,
    this.model,
    this.hardwareVersion,
    this.firmwareVersion,
    this.userIdOnBand,
    required this.pairedAtUtc,
    this.lastConnectedAtUtc,
    this.lastBatteryPercent,
    this.lastCharging,
    required this.isActive,
    required this.capabilities,
    this.deletedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || macAddress != null) {
      map['mac_address'] = Variable<String>(macAddress);
    }
    if (!nullToAbsent || iosPeripheralUuid != null) {
      map['ios_peripheral_uuid'] = Variable<String>(iosPeripheralUuid);
    }
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || hardwareVersion != null) {
      map['hardware_version'] = Variable<String>(hardwareVersion);
    }
    if (!nullToAbsent || firmwareVersion != null) {
      map['firmware_version'] = Variable<String>(firmwareVersion);
    }
    if (!nullToAbsent || userIdOnBand != null) {
      map['user_id_on_band'] = Variable<String>(userIdOnBand);
    }
    map['paired_at_utc'] = Variable<int>(pairedAtUtc);
    if (!nullToAbsent || lastConnectedAtUtc != null) {
      map['last_connected_at_utc'] = Variable<int>(lastConnectedAtUtc);
    }
    if (!nullToAbsent || lastBatteryPercent != null) {
      map['last_battery_percent'] = Variable<int>(lastBatteryPercent);
    }
    if (!nullToAbsent || lastCharging != null) {
      map['last_charging'] = Variable<bool>(lastCharging);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['capabilities'] = Variable<String>(capabilities);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      userId: Value(userId),
      macAddress: macAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(macAddress),
      iosPeripheralUuid: iosPeripheralUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(iosPeripheralUuid),
      displayName: Value(displayName),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      hardwareVersion: hardwareVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(hardwareVersion),
      firmwareVersion: firmwareVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(firmwareVersion),
      userIdOnBand: userIdOnBand == null && nullToAbsent
          ? const Value.absent()
          : Value(userIdOnBand),
      pairedAtUtc: Value(pairedAtUtc),
      lastConnectedAtUtc: lastConnectedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAtUtc),
      lastBatteryPercent: lastBatteryPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBatteryPercent),
      lastCharging: lastCharging == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCharging),
      isActive: Value(isActive),
      capabilities: Value(capabilities),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      macAddress: serializer.fromJson<String?>(json['macAddress']),
      iosPeripheralUuid: serializer.fromJson<String?>(
        json['iosPeripheralUuid'],
      ),
      displayName: serializer.fromJson<String>(json['displayName']),
      model: serializer.fromJson<String?>(json['model']),
      hardwareVersion: serializer.fromJson<String?>(json['hardwareVersion']),
      firmwareVersion: serializer.fromJson<String?>(json['firmwareVersion']),
      userIdOnBand: serializer.fromJson<String?>(json['userIdOnBand']),
      pairedAtUtc: serializer.fromJson<int>(json['pairedAtUtc']),
      lastConnectedAtUtc: serializer.fromJson<int?>(json['lastConnectedAtUtc']),
      lastBatteryPercent: serializer.fromJson<int?>(json['lastBatteryPercent']),
      lastCharging: serializer.fromJson<bool?>(json['lastCharging']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      capabilities: serializer.fromJson<String>(json['capabilities']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'macAddress': serializer.toJson<String?>(macAddress),
      'iosPeripheralUuid': serializer.toJson<String?>(iosPeripheralUuid),
      'displayName': serializer.toJson<String>(displayName),
      'model': serializer.toJson<String?>(model),
      'hardwareVersion': serializer.toJson<String?>(hardwareVersion),
      'firmwareVersion': serializer.toJson<String?>(firmwareVersion),
      'userIdOnBand': serializer.toJson<String?>(userIdOnBand),
      'pairedAtUtc': serializer.toJson<int>(pairedAtUtc),
      'lastConnectedAtUtc': serializer.toJson<int?>(lastConnectedAtUtc),
      'lastBatteryPercent': serializer.toJson<int?>(lastBatteryPercent),
      'lastCharging': serializer.toJson<bool?>(lastCharging),
      'isActive': serializer.toJson<bool>(isActive),
      'capabilities': serializer.toJson<String>(capabilities),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
    };
  }

  Device copyWith({
    String? id,
    String? userId,
    Value<String?> macAddress = const Value.absent(),
    Value<String?> iosPeripheralUuid = const Value.absent(),
    String? displayName,
    Value<String?> model = const Value.absent(),
    Value<String?> hardwareVersion = const Value.absent(),
    Value<String?> firmwareVersion = const Value.absent(),
    Value<String?> userIdOnBand = const Value.absent(),
    int? pairedAtUtc,
    Value<int?> lastConnectedAtUtc = const Value.absent(),
    Value<int?> lastBatteryPercent = const Value.absent(),
    Value<bool?> lastCharging = const Value.absent(),
    bool? isActive,
    String? capabilities,
    Value<int?> deletedAtUtc = const Value.absent(),
  }) => Device(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    macAddress: macAddress.present ? macAddress.value : this.macAddress,
    iosPeripheralUuid: iosPeripheralUuid.present
        ? iosPeripheralUuid.value
        : this.iosPeripheralUuid,
    displayName: displayName ?? this.displayName,
    model: model.present ? model.value : this.model,
    hardwareVersion: hardwareVersion.present
        ? hardwareVersion.value
        : this.hardwareVersion,
    firmwareVersion: firmwareVersion.present
        ? firmwareVersion.value
        : this.firmwareVersion,
    userIdOnBand: userIdOnBand.present ? userIdOnBand.value : this.userIdOnBand,
    pairedAtUtc: pairedAtUtc ?? this.pairedAtUtc,
    lastConnectedAtUtc: lastConnectedAtUtc.present
        ? lastConnectedAtUtc.value
        : this.lastConnectedAtUtc,
    lastBatteryPercent: lastBatteryPercent.present
        ? lastBatteryPercent.value
        : this.lastBatteryPercent,
    lastCharging: lastCharging.present ? lastCharging.value : this.lastCharging,
    isActive: isActive ?? this.isActive,
    capabilities: capabilities ?? this.capabilities,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      macAddress: data.macAddress.present
          ? data.macAddress.value
          : this.macAddress,
      iosPeripheralUuid: data.iosPeripheralUuid.present
          ? data.iosPeripheralUuid.value
          : this.iosPeripheralUuid,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      model: data.model.present ? data.model.value : this.model,
      hardwareVersion: data.hardwareVersion.present
          ? data.hardwareVersion.value
          : this.hardwareVersion,
      firmwareVersion: data.firmwareVersion.present
          ? data.firmwareVersion.value
          : this.firmwareVersion,
      userIdOnBand: data.userIdOnBand.present
          ? data.userIdOnBand.value
          : this.userIdOnBand,
      pairedAtUtc: data.pairedAtUtc.present
          ? data.pairedAtUtc.value
          : this.pairedAtUtc,
      lastConnectedAtUtc: data.lastConnectedAtUtc.present
          ? data.lastConnectedAtUtc.value
          : this.lastConnectedAtUtc,
      lastBatteryPercent: data.lastBatteryPercent.present
          ? data.lastBatteryPercent.value
          : this.lastBatteryPercent,
      lastCharging: data.lastCharging.present
          ? data.lastCharging.value
          : this.lastCharging,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      capabilities: data.capabilities.present
          ? data.capabilities.value
          : this.capabilities,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('macAddress: $macAddress, ')
          ..write('iosPeripheralUuid: $iosPeripheralUuid, ')
          ..write('displayName: $displayName, ')
          ..write('model: $model, ')
          ..write('hardwareVersion: $hardwareVersion, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('userIdOnBand: $userIdOnBand, ')
          ..write('pairedAtUtc: $pairedAtUtc, ')
          ..write('lastConnectedAtUtc: $lastConnectedAtUtc, ')
          ..write('lastBatteryPercent: $lastBatteryPercent, ')
          ..write('lastCharging: $lastCharging, ')
          ..write('isActive: $isActive, ')
          ..write('capabilities: $capabilities, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    macAddress,
    iosPeripheralUuid,
    displayName,
    model,
    hardwareVersion,
    firmwareVersion,
    userIdOnBand,
    pairedAtUtc,
    lastConnectedAtUtc,
    lastBatteryPercent,
    lastCharging,
    isActive,
    capabilities,
    deletedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.macAddress == this.macAddress &&
          other.iosPeripheralUuid == this.iosPeripheralUuid &&
          other.displayName == this.displayName &&
          other.model == this.model &&
          other.hardwareVersion == this.hardwareVersion &&
          other.firmwareVersion == this.firmwareVersion &&
          other.userIdOnBand == this.userIdOnBand &&
          other.pairedAtUtc == this.pairedAtUtc &&
          other.lastConnectedAtUtc == this.lastConnectedAtUtc &&
          other.lastBatteryPercent == this.lastBatteryPercent &&
          other.lastCharging == this.lastCharging &&
          other.isActive == this.isActive &&
          other.capabilities == this.capabilities &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> macAddress;
  final Value<String?> iosPeripheralUuid;
  final Value<String> displayName;
  final Value<String?> model;
  final Value<String?> hardwareVersion;
  final Value<String?> firmwareVersion;
  final Value<String?> userIdOnBand;
  final Value<int> pairedAtUtc;
  final Value<int?> lastConnectedAtUtc;
  final Value<int?> lastBatteryPercent;
  final Value<bool?> lastCharging;
  final Value<bool> isActive;
  final Value<String> capabilities;
  final Value<int?> deletedAtUtc;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.macAddress = const Value.absent(),
    this.iosPeripheralUuid = const Value.absent(),
    this.displayName = const Value.absent(),
    this.model = const Value.absent(),
    this.hardwareVersion = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.userIdOnBand = const Value.absent(),
    this.pairedAtUtc = const Value.absent(),
    this.lastConnectedAtUtc = const Value.absent(),
    this.lastBatteryPercent = const Value.absent(),
    this.lastCharging = const Value.absent(),
    this.isActive = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String userId,
    this.macAddress = const Value.absent(),
    this.iosPeripheralUuid = const Value.absent(),
    required String displayName,
    this.model = const Value.absent(),
    this.hardwareVersion = const Value.absent(),
    this.firmwareVersion = const Value.absent(),
    this.userIdOnBand = const Value.absent(),
    required int pairedAtUtc,
    this.lastConnectedAtUtc = const Value.absent(),
    this.lastBatteryPercent = const Value.absent(),
    this.lastCharging = const Value.absent(),
    this.isActive = const Value.absent(),
    this.capabilities = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       displayName = Value(displayName),
       pairedAtUtc = Value(pairedAtUtc);
  static Insertable<Device> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? macAddress,
    Expression<String>? iosPeripheralUuid,
    Expression<String>? displayName,
    Expression<String>? model,
    Expression<String>? hardwareVersion,
    Expression<String>? firmwareVersion,
    Expression<String>? userIdOnBand,
    Expression<int>? pairedAtUtc,
    Expression<int>? lastConnectedAtUtc,
    Expression<int>? lastBatteryPercent,
    Expression<bool>? lastCharging,
    Expression<bool>? isActive,
    Expression<String>? capabilities,
    Expression<int>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (macAddress != null) 'mac_address': macAddress,
      if (iosPeripheralUuid != null) 'ios_peripheral_uuid': iosPeripheralUuid,
      if (displayName != null) 'display_name': displayName,
      if (model != null) 'model': model,
      if (hardwareVersion != null) 'hardware_version': hardwareVersion,
      if (firmwareVersion != null) 'firmware_version': firmwareVersion,
      if (userIdOnBand != null) 'user_id_on_band': userIdOnBand,
      if (pairedAtUtc != null) 'paired_at_utc': pairedAtUtc,
      if (lastConnectedAtUtc != null)
        'last_connected_at_utc': lastConnectedAtUtc,
      if (lastBatteryPercent != null)
        'last_battery_percent': lastBatteryPercent,
      if (lastCharging != null) 'last_charging': lastCharging,
      if (isActive != null) 'is_active': isActive,
      if (capabilities != null) 'capabilities': capabilities,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String?>? macAddress,
    Value<String?>? iosPeripheralUuid,
    Value<String>? displayName,
    Value<String?>? model,
    Value<String?>? hardwareVersion,
    Value<String?>? firmwareVersion,
    Value<String?>? userIdOnBand,
    Value<int>? pairedAtUtc,
    Value<int?>? lastConnectedAtUtc,
    Value<int?>? lastBatteryPercent,
    Value<bool?>? lastCharging,
    Value<bool>? isActive,
    Value<String>? capabilities,
    Value<int?>? deletedAtUtc,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      macAddress: macAddress ?? this.macAddress,
      iosPeripheralUuid: iosPeripheralUuid ?? this.iosPeripheralUuid,
      displayName: displayName ?? this.displayName,
      model: model ?? this.model,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      userIdOnBand: userIdOnBand ?? this.userIdOnBand,
      pairedAtUtc: pairedAtUtc ?? this.pairedAtUtc,
      lastConnectedAtUtc: lastConnectedAtUtc ?? this.lastConnectedAtUtc,
      lastBatteryPercent: lastBatteryPercent ?? this.lastBatteryPercent,
      lastCharging: lastCharging ?? this.lastCharging,
      isActive: isActive ?? this.isActive,
      capabilities: capabilities ?? this.capabilities,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (macAddress.present) {
      map['mac_address'] = Variable<String>(macAddress.value);
    }
    if (iosPeripheralUuid.present) {
      map['ios_peripheral_uuid'] = Variable<String>(iosPeripheralUuid.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (hardwareVersion.present) {
      map['hardware_version'] = Variable<String>(hardwareVersion.value);
    }
    if (firmwareVersion.present) {
      map['firmware_version'] = Variable<String>(firmwareVersion.value);
    }
    if (userIdOnBand.present) {
      map['user_id_on_band'] = Variable<String>(userIdOnBand.value);
    }
    if (pairedAtUtc.present) {
      map['paired_at_utc'] = Variable<int>(pairedAtUtc.value);
    }
    if (lastConnectedAtUtc.present) {
      map['last_connected_at_utc'] = Variable<int>(lastConnectedAtUtc.value);
    }
    if (lastBatteryPercent.present) {
      map['last_battery_percent'] = Variable<int>(lastBatteryPercent.value);
    }
    if (lastCharging.present) {
      map['last_charging'] = Variable<bool>(lastCharging.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (capabilities.present) {
      map['capabilities'] = Variable<String>(capabilities.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('macAddress: $macAddress, ')
          ..write('iosPeripheralUuid: $iosPeripheralUuid, ')
          ..write('displayName: $displayName, ')
          ..write('model: $model, ')
          ..write('hardwareVersion: $hardwareVersion, ')
          ..write('firmwareVersion: $firmwareVersion, ')
          ..write('userIdOnBand: $userIdOnBand, ')
          ..write('pairedAtUtc: $pairedAtUtc, ')
          ..write('lastConnectedAtUtc: $lastConnectedAtUtc, ')
          ..write('lastBatteryPercent: $lastBatteryPercent, ')
          ..write('lastCharging: $lastCharging, ')
          ..write('isActive: $isActive, ')
          ..write('capabilities: $capabilities, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HrSamplesTable extends HrSamples
    with TableInfo<$HrSamplesTable, HrSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HrSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _capturedAtUtcMeta = const VerificationMeta(
    'capturedAtUtc',
  );
  @override
  late final GeneratedColumn<int> capturedAtUtc = GeneratedColumn<int>(
    'captured_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($HrSamplesTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMinMeta = const VerificationMeta(
    'intervalMin',
  );
  @override
  late final GeneratedColumn<int> intervalMin = GeneratedColumn<int>(
    'interval_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRestingMeta = const VerificationMeta(
    'isResting',
  );
  @override
  late final GeneratedColumn<bool> isResting = GeneratedColumn<bool>(
    'is_resting',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_resting" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    bpm,
    intervalMin,
    isResting,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hr_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<HrSample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('captured_at_utc')) {
      context.handle(
        _capturedAtUtcMeta,
        capturedAtUtc.isAcceptableOrUnknown(
          data['captured_at_utc']!,
          _capturedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('interval_min')) {
      context.handle(
        _intervalMinMeta,
        intervalMin.isAcceptableOrUnknown(
          data['interval_min']!,
          _intervalMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intervalMinMeta);
    }
    if (data.containsKey('is_resting')) {
      context.handle(
        _isRestingMeta,
        isResting.isAcceptableOrUnknown(data['is_resting']!, _isRestingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HrSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HrSample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      capturedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $HrSamplesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      intervalMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_min'],
      )!,
      isResting: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_resting'],
      )!,
    );
  }

  @override
  $HrSamplesTable createAlias(String alias) {
    return $HrSamplesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class HrSample extends DataClass implements Insertable<HrSample> {
  final String id;
  final String userId;
  final String deviceId;
  final int capturedAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final int bpm;
  final int intervalMin;
  final bool isResting;
  const HrSample({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.bpm,
    required this.intervalMin,
    required this.isResting,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['captured_at_utc'] = Variable<int>(capturedAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $HrSamplesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['bpm'] = Variable<int>(bpm);
    map['interval_min'] = Variable<int>(intervalMin);
    map['is_resting'] = Variable<bool>(isResting);
    return map;
  }

  HrSamplesCompanion toCompanion(bool nullToAbsent) {
    return HrSamplesCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      capturedAtUtc: Value(capturedAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      bpm: Value(bpm),
      intervalMin: Value(intervalMin),
      isResting: Value(isResting),
    );
  }

  factory HrSample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HrSample(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      capturedAtUtc: serializer.fromJson<int>(json['capturedAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $HrSamplesTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      bpm: serializer.fromJson<int>(json['bpm']),
      intervalMin: serializer.fromJson<int>(json['intervalMin']),
      isResting: serializer.fromJson<bool>(json['isResting']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'capturedAtUtc': serializer.toJson<int>(capturedAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $HrSamplesTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'bpm': serializer.toJson<int>(bpm),
      'intervalMin': serializer.toJson<int>(intervalMin),
      'isResting': serializer.toJson<bool>(isResting),
    };
  }

  HrSample copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? capturedAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    int? bpm,
    int? intervalMin,
    bool? isResting,
  }) => HrSample(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    bpm: bpm ?? this.bpm,
    intervalMin: intervalMin ?? this.intervalMin,
    isResting: isResting ?? this.isResting,
  );
  HrSample copyWithCompanion(HrSamplesCompanion data) {
    return HrSample(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capturedAtUtc: data.capturedAtUtc.present
          ? data.capturedAtUtc.value
          : this.capturedAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      intervalMin: data.intervalMin.present
          ? data.intervalMin.value
          : this.intervalMin,
      isResting: data.isResting.present ? data.isResting.value : this.isResting,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HrSample(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('bpm: $bpm, ')
          ..write('intervalMin: $intervalMin, ')
          ..write('isResting: $isResting')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    bpm,
    intervalMin,
    isResting,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HrSample &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.capturedAtUtc == this.capturedAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.bpm == this.bpm &&
          other.intervalMin == this.intervalMin &&
          other.isResting == this.isResting);
}

class HrSamplesCompanion extends UpdateCompanion<HrSample> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> capturedAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> bpm;
  final Value<int> intervalMin;
  final Value<bool> isResting;
  final Value<int> rowid;
  const HrSamplesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capturedAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.bpm = const Value.absent(),
    this.intervalMin = const Value.absent(),
    this.isResting = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HrSamplesCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int capturedAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required int bpm,
    required int intervalMin,
    this.isResting = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       capturedAtUtc = Value(capturedAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       bpm = Value(bpm),
       intervalMin = Value(intervalMin);
  static Insertable<HrSample> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? capturedAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? bpm,
    Expression<int>? intervalMin,
    Expression<bool>? isResting,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (capturedAtUtc != null) 'captured_at_utc': capturedAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (bpm != null) 'bpm': bpm,
      if (intervalMin != null) 'interval_min': intervalMin,
      if (isResting != null) 'is_resting': isResting,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HrSamplesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? capturedAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? bpm,
    Value<int>? intervalMin,
    Value<bool>? isResting,
    Value<int>? rowid,
  }) {
    return HrSamplesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      bpm: bpm ?? this.bpm,
      intervalMin: intervalMin ?? this.intervalMin,
      isResting: isResting ?? this.isResting,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (capturedAtUtc.present) {
      map['captured_at_utc'] = Variable<int>(capturedAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $HrSamplesTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (intervalMin.present) {
      map['interval_min'] = Variable<int>(intervalMin.value);
    }
    if (isResting.present) {
      map['is_resting'] = Variable<bool>(isResting.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HrSamplesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('bpm: $bpm, ')
          ..write('intervalMin: $intervalMin, ')
          ..write('isResting: $isResting, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HrvSamplesTable extends HrvSamples
    with TableInfo<$HrvSamplesTable, HrvSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HrvSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _capturedAtUtcMeta = const VerificationMeta(
    'capturedAtUtc',
  );
  @override
  late final GeneratedColumn<int> capturedAtUtc = GeneratedColumn<int>(
    'captured_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($HrvSamplesTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rmssdMsMeta = const VerificationMeta(
    'rmssdMs',
  );
  @override
  late final GeneratedColumn<double> rmssdMs = GeneratedColumn<double>(
    'rmssd_ms',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sdnnMsMeta = const VerificationMeta('sdnnMs');
  @override
  late final GeneratedColumn<double> sdnnMs = GeneratedColumn<double>(
    'sdnn_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pnn50PctMeta = const VerificationMeta(
    'pnn50Pct',
  );
  @override
  late final GeneratedColumn<double> pnn50Pct = GeneratedColumn<double>(
    'pnn50_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meanHrBpmMeta = const VerificationMeta(
    'meanHrBpm',
  );
  @override
  late final GeneratedColumn<int> meanHrBpm = GeneratedColumn<int>(
    'mean_hr_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beatCountMeta = const VerificationMeta(
    'beatCount',
  );
  @override
  late final GeneratedColumn<int> beatCount = GeneratedColumn<int>(
    'beat_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    rmssdMs,
    sdnnMs,
    pnn50Pct,
    meanHrBpm,
    beatCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hrv_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<HrvSample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('captured_at_utc')) {
      context.handle(
        _capturedAtUtcMeta,
        capturedAtUtc.isAcceptableOrUnknown(
          data['captured_at_utc']!,
          _capturedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('rmssd_ms')) {
      context.handle(
        _rmssdMsMeta,
        rmssdMs.isAcceptableOrUnknown(data['rmssd_ms']!, _rmssdMsMeta),
      );
    } else if (isInserting) {
      context.missing(_rmssdMsMeta);
    }
    if (data.containsKey('sdnn_ms')) {
      context.handle(
        _sdnnMsMeta,
        sdnnMs.isAcceptableOrUnknown(data['sdnn_ms']!, _sdnnMsMeta),
      );
    }
    if (data.containsKey('pnn50_pct')) {
      context.handle(
        _pnn50PctMeta,
        pnn50Pct.isAcceptableOrUnknown(data['pnn50_pct']!, _pnn50PctMeta),
      );
    }
    if (data.containsKey('mean_hr_bpm')) {
      context.handle(
        _meanHrBpmMeta,
        meanHrBpm.isAcceptableOrUnknown(data['mean_hr_bpm']!, _meanHrBpmMeta),
      );
    }
    if (data.containsKey('beat_count')) {
      context.handle(
        _beatCountMeta,
        beatCount.isAcceptableOrUnknown(data['beat_count']!, _beatCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HrvSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HrvSample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      capturedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $HrvSamplesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      rmssdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rmssd_ms'],
      )!,
      sdnnMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sdnn_ms'],
      ),
      pnn50Pct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pnn50_pct'],
      ),
      meanHrBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mean_hr_bpm'],
      ),
      beatCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}beat_count'],
      ),
    );
  }

  @override
  $HrvSamplesTable createAlias(String alias) {
    return $HrvSamplesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class HrvSample extends DataClass implements Insertable<HrvSample> {
  final String id;
  final String userId;
  final String deviceId;
  final int capturedAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final double rmssdMs;
  final double? sdnnMs;
  final double? pnn50Pct;
  final int? meanHrBpm;
  final int? beatCount;
  const HrvSample({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.rmssdMs,
    this.sdnnMs,
    this.pnn50Pct,
    this.meanHrBpm,
    this.beatCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['captured_at_utc'] = Variable<int>(capturedAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $HrvSamplesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['rmssd_ms'] = Variable<double>(rmssdMs);
    if (!nullToAbsent || sdnnMs != null) {
      map['sdnn_ms'] = Variable<double>(sdnnMs);
    }
    if (!nullToAbsent || pnn50Pct != null) {
      map['pnn50_pct'] = Variable<double>(pnn50Pct);
    }
    if (!nullToAbsent || meanHrBpm != null) {
      map['mean_hr_bpm'] = Variable<int>(meanHrBpm);
    }
    if (!nullToAbsent || beatCount != null) {
      map['beat_count'] = Variable<int>(beatCount);
    }
    return map;
  }

  HrvSamplesCompanion toCompanion(bool nullToAbsent) {
    return HrvSamplesCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      capturedAtUtc: Value(capturedAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      rmssdMs: Value(rmssdMs),
      sdnnMs: sdnnMs == null && nullToAbsent
          ? const Value.absent()
          : Value(sdnnMs),
      pnn50Pct: pnn50Pct == null && nullToAbsent
          ? const Value.absent()
          : Value(pnn50Pct),
      meanHrBpm: meanHrBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(meanHrBpm),
      beatCount: beatCount == null && nullToAbsent
          ? const Value.absent()
          : Value(beatCount),
    );
  }

  factory HrvSample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HrvSample(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      capturedAtUtc: serializer.fromJson<int>(json['capturedAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $HrvSamplesTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      rmssdMs: serializer.fromJson<double>(json['rmssdMs']),
      sdnnMs: serializer.fromJson<double?>(json['sdnnMs']),
      pnn50Pct: serializer.fromJson<double?>(json['pnn50Pct']),
      meanHrBpm: serializer.fromJson<int?>(json['meanHrBpm']),
      beatCount: serializer.fromJson<int?>(json['beatCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'capturedAtUtc': serializer.toJson<int>(capturedAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $HrvSamplesTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'rmssdMs': serializer.toJson<double>(rmssdMs),
      'sdnnMs': serializer.toJson<double?>(sdnnMs),
      'pnn50Pct': serializer.toJson<double?>(pnn50Pct),
      'meanHrBpm': serializer.toJson<int?>(meanHrBpm),
      'beatCount': serializer.toJson<int?>(beatCount),
    };
  }

  HrvSample copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? capturedAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    double? rmssdMs,
    Value<double?> sdnnMs = const Value.absent(),
    Value<double?> pnn50Pct = const Value.absent(),
    Value<int?> meanHrBpm = const Value.absent(),
    Value<int?> beatCount = const Value.absent(),
  }) => HrvSample(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    rmssdMs: rmssdMs ?? this.rmssdMs,
    sdnnMs: sdnnMs.present ? sdnnMs.value : this.sdnnMs,
    pnn50Pct: pnn50Pct.present ? pnn50Pct.value : this.pnn50Pct,
    meanHrBpm: meanHrBpm.present ? meanHrBpm.value : this.meanHrBpm,
    beatCount: beatCount.present ? beatCount.value : this.beatCount,
  );
  HrvSample copyWithCompanion(HrvSamplesCompanion data) {
    return HrvSample(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capturedAtUtc: data.capturedAtUtc.present
          ? data.capturedAtUtc.value
          : this.capturedAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      rmssdMs: data.rmssdMs.present ? data.rmssdMs.value : this.rmssdMs,
      sdnnMs: data.sdnnMs.present ? data.sdnnMs.value : this.sdnnMs,
      pnn50Pct: data.pnn50Pct.present ? data.pnn50Pct.value : this.pnn50Pct,
      meanHrBpm: data.meanHrBpm.present ? data.meanHrBpm.value : this.meanHrBpm,
      beatCount: data.beatCount.present ? data.beatCount.value : this.beatCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HrvSample(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rmssdMs: $rmssdMs, ')
          ..write('sdnnMs: $sdnnMs, ')
          ..write('pnn50Pct: $pnn50Pct, ')
          ..write('meanHrBpm: $meanHrBpm, ')
          ..write('beatCount: $beatCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    rmssdMs,
    sdnnMs,
    pnn50Pct,
    meanHrBpm,
    beatCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HrvSample &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.capturedAtUtc == this.capturedAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.rmssdMs == this.rmssdMs &&
          other.sdnnMs == this.sdnnMs &&
          other.pnn50Pct == this.pnn50Pct &&
          other.meanHrBpm == this.meanHrBpm &&
          other.beatCount == this.beatCount);
}

class HrvSamplesCompanion extends UpdateCompanion<HrvSample> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> capturedAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<double> rmssdMs;
  final Value<double?> sdnnMs;
  final Value<double?> pnn50Pct;
  final Value<int?> meanHrBpm;
  final Value<int?> beatCount;
  final Value<int> rowid;
  const HrvSamplesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capturedAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rmssdMs = const Value.absent(),
    this.sdnnMs = const Value.absent(),
    this.pnn50Pct = const Value.absent(),
    this.meanHrBpm = const Value.absent(),
    this.beatCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HrvSamplesCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int capturedAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required double rmssdMs,
    this.sdnnMs = const Value.absent(),
    this.pnn50Pct = const Value.absent(),
    this.meanHrBpm = const Value.absent(),
    this.beatCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       capturedAtUtc = Value(capturedAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       rmssdMs = Value(rmssdMs);
  static Insertable<HrvSample> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? capturedAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<double>? rmssdMs,
    Expression<double>? sdnnMs,
    Expression<double>? pnn50Pct,
    Expression<int>? meanHrBpm,
    Expression<int>? beatCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (capturedAtUtc != null) 'captured_at_utc': capturedAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rmssdMs != null) 'rmssd_ms': rmssdMs,
      if (sdnnMs != null) 'sdnn_ms': sdnnMs,
      if (pnn50Pct != null) 'pnn50_pct': pnn50Pct,
      if (meanHrBpm != null) 'mean_hr_bpm': meanHrBpm,
      if (beatCount != null) 'beat_count': beatCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HrvSamplesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? capturedAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<double>? rmssdMs,
    Value<double?>? sdnnMs,
    Value<double?>? pnn50Pct,
    Value<int?>? meanHrBpm,
    Value<int?>? beatCount,
    Value<int>? rowid,
  }) {
    return HrvSamplesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rmssdMs: rmssdMs ?? this.rmssdMs,
      sdnnMs: sdnnMs ?? this.sdnnMs,
      pnn50Pct: pnn50Pct ?? this.pnn50Pct,
      meanHrBpm: meanHrBpm ?? this.meanHrBpm,
      beatCount: beatCount ?? this.beatCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (capturedAtUtc.present) {
      map['captured_at_utc'] = Variable<int>(capturedAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $HrvSamplesTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (rmssdMs.present) {
      map['rmssd_ms'] = Variable<double>(rmssdMs.value);
    }
    if (sdnnMs.present) {
      map['sdnn_ms'] = Variable<double>(sdnnMs.value);
    }
    if (pnn50Pct.present) {
      map['pnn50_pct'] = Variable<double>(pnn50Pct.value);
    }
    if (meanHrBpm.present) {
      map['mean_hr_bpm'] = Variable<int>(meanHrBpm.value);
    }
    if (beatCount.present) {
      map['beat_count'] = Variable<int>(beatCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HrvSamplesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rmssdMs: $rmssdMs, ')
          ..write('sdnnMs: $sdnnMs, ')
          ..write('pnn50Pct: $pnn50Pct, ')
          ..write('meanHrBpm: $meanHrBpm, ')
          ..write('beatCount: $beatCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $Spo2SamplesTable extends Spo2Samples
    with TableInfo<$Spo2SamplesTable, Spo2Sample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Spo2SamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _capturedAtUtcMeta = const VerificationMeta(
    'capturedAtUtc',
  );
  @override
  late final GeneratedColumn<int> capturedAtUtc = GeneratedColumn<int>(
    'captured_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($Spo2SamplesTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pctMinMeta = const VerificationMeta('pctMin');
  @override
  late final GeneratedColumn<int> pctMin = GeneratedColumn<int>(
    'pct_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pctMaxMeta = const VerificationMeta('pctMax');
  @override
  late final GeneratedColumn<int> pctMax = GeneratedColumn<int>(
    'pct_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bucketMinMeta = const VerificationMeta(
    'bucketMin',
  );
  @override
  late final GeneratedColumn<int> bucketMin = GeneratedColumn<int>(
    'bucket_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    pctMin,
    pctMax,
    bucketMin,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spo2_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<Spo2Sample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('captured_at_utc')) {
      context.handle(
        _capturedAtUtcMeta,
        capturedAtUtc.isAcceptableOrUnknown(
          data['captured_at_utc']!,
          _capturedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('pct_min')) {
      context.handle(
        _pctMinMeta,
        pctMin.isAcceptableOrUnknown(data['pct_min']!, _pctMinMeta),
      );
    } else if (isInserting) {
      context.missing(_pctMinMeta);
    }
    if (data.containsKey('pct_max')) {
      context.handle(
        _pctMaxMeta,
        pctMax.isAcceptableOrUnknown(data['pct_max']!, _pctMaxMeta),
      );
    } else if (isInserting) {
      context.missing(_pctMaxMeta);
    }
    if (data.containsKey('bucket_min')) {
      context.handle(
        _bucketMinMeta,
        bucketMin.isAcceptableOrUnknown(data['bucket_min']!, _bucketMinMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketMinMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Spo2Sample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Spo2Sample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      capturedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $Spo2SamplesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      pctMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pct_min'],
      )!,
      pctMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pct_max'],
      )!,
      bucketMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket_min'],
      )!,
    );
  }

  @override
  $Spo2SamplesTable createAlias(String alias) {
    return $Spo2SamplesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class Spo2Sample extends DataClass implements Insertable<Spo2Sample> {
  final String id;
  final String userId;
  final String deviceId;
  final int capturedAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final int pctMin;
  final int pctMax;
  final int bucketMin;
  const Spo2Sample({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.pctMin,
    required this.pctMax,
    required this.bucketMin,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['captured_at_utc'] = Variable<int>(capturedAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $Spo2SamplesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['pct_min'] = Variable<int>(pctMin);
    map['pct_max'] = Variable<int>(pctMax);
    map['bucket_min'] = Variable<int>(bucketMin);
    return map;
  }

  Spo2SamplesCompanion toCompanion(bool nullToAbsent) {
    return Spo2SamplesCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      capturedAtUtc: Value(capturedAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      pctMin: Value(pctMin),
      pctMax: Value(pctMax),
      bucketMin: Value(bucketMin),
    );
  }

  factory Spo2Sample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Spo2Sample(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      capturedAtUtc: serializer.fromJson<int>(json['capturedAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $Spo2SamplesTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      pctMin: serializer.fromJson<int>(json['pctMin']),
      pctMax: serializer.fromJson<int>(json['pctMax']),
      bucketMin: serializer.fromJson<int>(json['bucketMin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'capturedAtUtc': serializer.toJson<int>(capturedAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $Spo2SamplesTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'pctMin': serializer.toJson<int>(pctMin),
      'pctMax': serializer.toJson<int>(pctMax),
      'bucketMin': serializer.toJson<int>(bucketMin),
    };
  }

  Spo2Sample copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? capturedAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    int? pctMin,
    int? pctMax,
    int? bucketMin,
  }) => Spo2Sample(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    pctMin: pctMin ?? this.pctMin,
    pctMax: pctMax ?? this.pctMax,
    bucketMin: bucketMin ?? this.bucketMin,
  );
  Spo2Sample copyWithCompanion(Spo2SamplesCompanion data) {
    return Spo2Sample(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capturedAtUtc: data.capturedAtUtc.present
          ? data.capturedAtUtc.value
          : this.capturedAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      pctMin: data.pctMin.present ? data.pctMin.value : this.pctMin,
      pctMax: data.pctMax.present ? data.pctMax.value : this.pctMax,
      bucketMin: data.bucketMin.present ? data.bucketMin.value : this.bucketMin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Spo2Sample(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('pctMin: $pctMin, ')
          ..write('pctMax: $pctMax, ')
          ..write('bucketMin: $bucketMin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    pctMin,
    pctMax,
    bucketMin,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Spo2Sample &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.capturedAtUtc == this.capturedAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.pctMin == this.pctMin &&
          other.pctMax == this.pctMax &&
          other.bucketMin == this.bucketMin);
}

class Spo2SamplesCompanion extends UpdateCompanion<Spo2Sample> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> capturedAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> pctMin;
  final Value<int> pctMax;
  final Value<int> bucketMin;
  final Value<int> rowid;
  const Spo2SamplesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capturedAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.pctMin = const Value.absent(),
    this.pctMax = const Value.absent(),
    this.bucketMin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  Spo2SamplesCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int capturedAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required int pctMin,
    required int pctMax,
    required int bucketMin,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       capturedAtUtc = Value(capturedAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       pctMin = Value(pctMin),
       pctMax = Value(pctMax),
       bucketMin = Value(bucketMin);
  static Insertable<Spo2Sample> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? capturedAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? pctMin,
    Expression<int>? pctMax,
    Expression<int>? bucketMin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (capturedAtUtc != null) 'captured_at_utc': capturedAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (pctMin != null) 'pct_min': pctMin,
      if (pctMax != null) 'pct_max': pctMax,
      if (bucketMin != null) 'bucket_min': bucketMin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  Spo2SamplesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? capturedAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? pctMin,
    Value<int>? pctMax,
    Value<int>? bucketMin,
    Value<int>? rowid,
  }) {
    return Spo2SamplesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      pctMin: pctMin ?? this.pctMin,
      pctMax: pctMax ?? this.pctMax,
      bucketMin: bucketMin ?? this.bucketMin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (capturedAtUtc.present) {
      map['captured_at_utc'] = Variable<int>(capturedAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $Spo2SamplesTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (pctMin.present) {
      map['pct_min'] = Variable<int>(pctMin.value);
    }
    if (pctMax.present) {
      map['pct_max'] = Variable<int>(pctMax.value);
    }
    if (bucketMin.present) {
      map['bucket_min'] = Variable<int>(bucketMin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Spo2SamplesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('pctMin: $pctMin, ')
          ..write('pctMax: $pctMax, ')
          ..write('bucketMin: $bucketMin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BpReadingsTable extends BpReadings
    with TableInfo<$BpReadingsTable, BpReading> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BpReadingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _capturedAtUtcMeta = const VerificationMeta(
    'capturedAtUtc',
  );
  @override
  late final GeneratedColumn<int> capturedAtUtc = GeneratedColumn<int>(
    'captured_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($BpReadingsTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _systolicMmhgMeta = const VerificationMeta(
    'systolicMmhg',
  );
  @override
  late final GeneratedColumn<int> systolicMmhg = GeneratedColumn<int>(
    'systolic_mmhg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _diastolicMmhgMeta = const VerificationMeta(
    'diastolicMmhg',
  );
  @override
  late final GeneratedColumn<int> diastolicMmhg = GeneratedColumn<int>(
    'diastolic_mmhg',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pulseBpmMeta = const VerificationMeta(
    'pulseBpm',
  );
  @override
  late final GeneratedColumn<int> pulseBpm = GeneratedColumn<int>(
    'pulse_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BpDerivation, int> derivation =
      GeneratedColumn<int>(
        'derivation',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<BpDerivation>($BpReadingsTable.$converterderivation);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    systolicMmhg,
    diastolicMmhg,
    pulseBpm,
    derivation,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bp_readings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BpReading> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('captured_at_utc')) {
      context.handle(
        _capturedAtUtcMeta,
        capturedAtUtc.isAcceptableOrUnknown(
          data['captured_at_utc']!,
          _capturedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('systolic_mmhg')) {
      context.handle(
        _systolicMmhgMeta,
        systolicMmhg.isAcceptableOrUnknown(
          data['systolic_mmhg']!,
          _systolicMmhgMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_systolicMmhgMeta);
    }
    if (data.containsKey('diastolic_mmhg')) {
      context.handle(
        _diastolicMmhgMeta,
        diastolicMmhg.isAcceptableOrUnknown(
          data['diastolic_mmhg']!,
          _diastolicMmhgMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_diastolicMmhgMeta);
    }
    if (data.containsKey('pulse_bpm')) {
      context.handle(
        _pulseBpmMeta,
        pulseBpm.isAcceptableOrUnknown(data['pulse_bpm']!, _pulseBpmMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BpReading map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BpReading(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      capturedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $BpReadingsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      systolicMmhg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}systolic_mmhg'],
      )!,
      diastolicMmhg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diastolic_mmhg'],
      )!,
      pulseBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pulse_bpm'],
      ),
      derivation: $BpReadingsTable.$converterderivation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}derivation'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
    );
  }

  @override
  $BpReadingsTable createAlias(String alias) {
    return $BpReadingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
  static JsonTypeConverter2<BpDerivation, int, int> $converterderivation =
      const EnumIndexConverter<BpDerivation>(BpDerivation.values);
}

class BpReading extends DataClass implements Insertable<BpReading> {
  final String id;
  final String userId;
  final String deviceId;
  final int capturedAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final int systolicMmhg;
  final int diastolicMmhg;
  final int? pulseBpm;
  final BpDerivation derivation;
  final int? position;
  const BpReading({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.capturedAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.systolicMmhg,
    required this.diastolicMmhg,
    this.pulseBpm,
    required this.derivation,
    this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['captured_at_utc'] = Variable<int>(capturedAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $BpReadingsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['systolic_mmhg'] = Variable<int>(systolicMmhg);
    map['diastolic_mmhg'] = Variable<int>(diastolicMmhg);
    if (!nullToAbsent || pulseBpm != null) {
      map['pulse_bpm'] = Variable<int>(pulseBpm);
    }
    {
      map['derivation'] = Variable<int>(
        $BpReadingsTable.$converterderivation.toSql(derivation),
      );
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    return map;
  }

  BpReadingsCompanion toCompanion(bool nullToAbsent) {
    return BpReadingsCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      capturedAtUtc: Value(capturedAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      systolicMmhg: Value(systolicMmhg),
      diastolicMmhg: Value(diastolicMmhg),
      pulseBpm: pulseBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(pulseBpm),
      derivation: Value(derivation),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
    );
  }

  factory BpReading.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BpReading(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      capturedAtUtc: serializer.fromJson<int>(json['capturedAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $BpReadingsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      systolicMmhg: serializer.fromJson<int>(json['systolicMmhg']),
      diastolicMmhg: serializer.fromJson<int>(json['diastolicMmhg']),
      pulseBpm: serializer.fromJson<int?>(json['pulseBpm']),
      derivation: $BpReadingsTable.$converterderivation.fromJson(
        serializer.fromJson<int>(json['derivation']),
      ),
      position: serializer.fromJson<int?>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'capturedAtUtc': serializer.toJson<int>(capturedAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $BpReadingsTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'systolicMmhg': serializer.toJson<int>(systolicMmhg),
      'diastolicMmhg': serializer.toJson<int>(diastolicMmhg),
      'pulseBpm': serializer.toJson<int?>(pulseBpm),
      'derivation': serializer.toJson<int>(
        $BpReadingsTable.$converterderivation.toJson(derivation),
      ),
      'position': serializer.toJson<int?>(position),
    };
  }

  BpReading copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? capturedAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    int? systolicMmhg,
    int? diastolicMmhg,
    Value<int?> pulseBpm = const Value.absent(),
    BpDerivation? derivation,
    Value<int?> position = const Value.absent(),
  }) => BpReading(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    systolicMmhg: systolicMmhg ?? this.systolicMmhg,
    diastolicMmhg: diastolicMmhg ?? this.diastolicMmhg,
    pulseBpm: pulseBpm.present ? pulseBpm.value : this.pulseBpm,
    derivation: derivation ?? this.derivation,
    position: position.present ? position.value : this.position,
  );
  BpReading copyWithCompanion(BpReadingsCompanion data) {
    return BpReading(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      capturedAtUtc: data.capturedAtUtc.present
          ? data.capturedAtUtc.value
          : this.capturedAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      systolicMmhg: data.systolicMmhg.present
          ? data.systolicMmhg.value
          : this.systolicMmhg,
      diastolicMmhg: data.diastolicMmhg.present
          ? data.diastolicMmhg.value
          : this.diastolicMmhg,
      pulseBpm: data.pulseBpm.present ? data.pulseBpm.value : this.pulseBpm,
      derivation: data.derivation.present
          ? data.derivation.value
          : this.derivation,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BpReading(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('systolicMmhg: $systolicMmhg, ')
          ..write('diastolicMmhg: $diastolicMmhg, ')
          ..write('pulseBpm: $pulseBpm, ')
          ..write('derivation: $derivation, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    capturedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    systolicMmhg,
    diastolicMmhg,
    pulseBpm,
    derivation,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BpReading &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.capturedAtUtc == this.capturedAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.systolicMmhg == this.systolicMmhg &&
          other.diastolicMmhg == this.diastolicMmhg &&
          other.pulseBpm == this.pulseBpm &&
          other.derivation == this.derivation &&
          other.position == this.position);
}

class BpReadingsCompanion extends UpdateCompanion<BpReading> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> capturedAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> systolicMmhg;
  final Value<int> diastolicMmhg;
  final Value<int?> pulseBpm;
  final Value<BpDerivation> derivation;
  final Value<int?> position;
  final Value<int> rowid;
  const BpReadingsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.capturedAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.systolicMmhg = const Value.absent(),
    this.diastolicMmhg = const Value.absent(),
    this.pulseBpm = const Value.absent(),
    this.derivation = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BpReadingsCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int capturedAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required int systolicMmhg,
    required int diastolicMmhg,
    this.pulseBpm = const Value.absent(),
    required BpDerivation derivation,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       capturedAtUtc = Value(capturedAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       systolicMmhg = Value(systolicMmhg),
       diastolicMmhg = Value(diastolicMmhg),
       derivation = Value(derivation);
  static Insertable<BpReading> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? capturedAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? systolicMmhg,
    Expression<int>? diastolicMmhg,
    Expression<int>? pulseBpm,
    Expression<int>? derivation,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (capturedAtUtc != null) 'captured_at_utc': capturedAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (systolicMmhg != null) 'systolic_mmhg': systolicMmhg,
      if (diastolicMmhg != null) 'diastolic_mmhg': diastolicMmhg,
      if (pulseBpm != null) 'pulse_bpm': pulseBpm,
      if (derivation != null) 'derivation': derivation,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BpReadingsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? capturedAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? systolicMmhg,
    Value<int>? diastolicMmhg,
    Value<int?>? pulseBpm,
    Value<BpDerivation>? derivation,
    Value<int?>? position,
    Value<int>? rowid,
  }) {
    return BpReadingsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      systolicMmhg: systolicMmhg ?? this.systolicMmhg,
      diastolicMmhg: diastolicMmhg ?? this.diastolicMmhg,
      pulseBpm: pulseBpm ?? this.pulseBpm,
      derivation: derivation ?? this.derivation,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (capturedAtUtc.present) {
      map['captured_at_utc'] = Variable<int>(capturedAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $BpReadingsTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (systolicMmhg.present) {
      map['systolic_mmhg'] = Variable<int>(systolicMmhg.value);
    }
    if (diastolicMmhg.present) {
      map['diastolic_mmhg'] = Variable<int>(diastolicMmhg.value);
    }
    if (pulseBpm.present) {
      map['pulse_bpm'] = Variable<int>(pulseBpm.value);
    }
    if (derivation.present) {
      map['derivation'] = Variable<int>(
        $BpReadingsTable.$converterderivation.toSql(derivation.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BpReadingsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('capturedAtUtc: $capturedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('systolicMmhg: $systolicMmhg, ')
          ..write('diastolicMmhg: $diastolicMmhg, ')
          ..write('pulseBpm: $pulseBpm, ')
          ..write('derivation: $derivation, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StepBucketsTable extends StepBuckets
    with TableInfo<$StepBucketsTable, StepBucket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StepBucketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _bucketStartAtUtcMeta = const VerificationMeta(
    'bucketStartAtUtc',
  );
  @override
  late final GeneratedColumn<int> bucketStartAtUtc = GeneratedColumn<int>(
    'bucket_start_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($StepBucketsTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<int> distanceM = GeneratedColumn<int>(
    'distance_m',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesKcalMeta = const VerificationMeta(
    'caloriesKcal',
  );
  @override
  late final GeneratedColumn<double> caloriesKcal = GeneratedColumn<double>(
    'calories_kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runStepsMeta = const VerificationMeta(
    'runSteps',
  );
  @override
  late final GeneratedColumn<int> runSteps = GeneratedColumn<int>(
    'run_steps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    bucketStartAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    steps,
    distanceM,
    caloriesKcal,
    runSteps,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'step_buckets';
  @override
  VerificationContext validateIntegrity(
    Insertable<StepBucket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('bucket_start_at_utc')) {
      context.handle(
        _bucketStartAtUtcMeta,
        bucketStartAtUtc.isAcceptableOrUnknown(
          data['bucket_start_at_utc']!,
          _bucketStartAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bucketStartAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsMeta);
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    } else if (isInserting) {
      context.missing(_distanceMMeta);
    }
    if (data.containsKey('calories_kcal')) {
      context.handle(
        _caloriesKcalMeta,
        caloriesKcal.isAcceptableOrUnknown(
          data['calories_kcal']!,
          _caloriesKcalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_caloriesKcalMeta);
    }
    if (data.containsKey('run_steps')) {
      context.handle(
        _runStepsMeta,
        runSteps.isAcceptableOrUnknown(data['run_steps']!, _runStepsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StepBucket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepBucket(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      bucketStartAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bucket_start_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $StepBucketsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      )!,
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_m'],
      )!,
      caloriesKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calories_kcal'],
      )!,
      runSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_steps'],
      )!,
    );
  }

  @override
  $StepBucketsTable createAlias(String alias) {
    return $StepBucketsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class StepBucket extends DataClass implements Insertable<StepBucket> {
  final String id;
  final String userId;
  final String deviceId;
  final int bucketStartAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final int steps;
  final int distanceM;
  final double caloriesKcal;
  final int runSteps;
  const StepBucket({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.bucketStartAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.steps,
    required this.distanceM,
    required this.caloriesKcal,
    required this.runSteps,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['bucket_start_at_utc'] = Variable<int>(bucketStartAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $StepBucketsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['steps'] = Variable<int>(steps);
    map['distance_m'] = Variable<int>(distanceM);
    map['calories_kcal'] = Variable<double>(caloriesKcal);
    map['run_steps'] = Variable<int>(runSteps);
    return map;
  }

  StepBucketsCompanion toCompanion(bool nullToAbsent) {
    return StepBucketsCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      bucketStartAtUtc: Value(bucketStartAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      steps: Value(steps),
      distanceM: Value(distanceM),
      caloriesKcal: Value(caloriesKcal),
      runSteps: Value(runSteps),
    );
  }

  factory StepBucket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepBucket(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      bucketStartAtUtc: serializer.fromJson<int>(json['bucketStartAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $StepBucketsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      steps: serializer.fromJson<int>(json['steps']),
      distanceM: serializer.fromJson<int>(json['distanceM']),
      caloriesKcal: serializer.fromJson<double>(json['caloriesKcal']),
      runSteps: serializer.fromJson<int>(json['runSteps']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'bucketStartAtUtc': serializer.toJson<int>(bucketStartAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $StepBucketsTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'steps': serializer.toJson<int>(steps),
      'distanceM': serializer.toJson<int>(distanceM),
      'caloriesKcal': serializer.toJson<double>(caloriesKcal),
      'runSteps': serializer.toJson<int>(runSteps),
    };
  }

  StepBucket copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? bucketStartAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    int? steps,
    int? distanceM,
    double? caloriesKcal,
    int? runSteps,
  }) => StepBucket(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    bucketStartAtUtc: bucketStartAtUtc ?? this.bucketStartAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    steps: steps ?? this.steps,
    distanceM: distanceM ?? this.distanceM,
    caloriesKcal: caloriesKcal ?? this.caloriesKcal,
    runSteps: runSteps ?? this.runSteps,
  );
  StepBucket copyWithCompanion(StepBucketsCompanion data) {
    return StepBucket(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      bucketStartAtUtc: data.bucketStartAtUtc.present
          ? data.bucketStartAtUtc.value
          : this.bucketStartAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      caloriesKcal: data.caloriesKcal.present
          ? data.caloriesKcal.value
          : this.caloriesKcal,
      runSteps: data.runSteps.present ? data.runSteps.value : this.runSteps,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepBucket(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('bucketStartAtUtc: $bucketStartAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('caloriesKcal: $caloriesKcal, ')
          ..write('runSteps: $runSteps')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    deviceId,
    bucketStartAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    steps,
    distanceM,
    caloriesKcal,
    runSteps,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepBucket &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.bucketStartAtUtc == this.bucketStartAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.steps == this.steps &&
          other.distanceM == this.distanceM &&
          other.caloriesKcal == this.caloriesKcal &&
          other.runSteps == this.runSteps);
}

class StepBucketsCompanion extends UpdateCompanion<StepBucket> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> bucketStartAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> steps;
  final Value<int> distanceM;
  final Value<double> caloriesKcal;
  final Value<int> runSteps;
  final Value<int> rowid;
  const StepBucketsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.bucketStartAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.caloriesKcal = const Value.absent(),
    this.runSteps = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StepBucketsCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int bucketStartAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required int steps,
    required int distanceM,
    required double caloriesKcal,
    this.runSteps = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       bucketStartAtUtc = Value(bucketStartAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       steps = Value(steps),
       distanceM = Value(distanceM),
       caloriesKcal = Value(caloriesKcal);
  static Insertable<StepBucket> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? bucketStartAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? steps,
    Expression<int>? distanceM,
    Expression<double>? caloriesKcal,
    Expression<int>? runSteps,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (bucketStartAtUtc != null) 'bucket_start_at_utc': bucketStartAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
      if (runSteps != null) 'run_steps': runSteps,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StepBucketsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? bucketStartAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? steps,
    Value<int>? distanceM,
    Value<double>? caloriesKcal,
    Value<int>? runSteps,
    Value<int>? rowid,
  }) {
    return StepBucketsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      bucketStartAtUtc: bucketStartAtUtc ?? this.bucketStartAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      steps: steps ?? this.steps,
      distanceM: distanceM ?? this.distanceM,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      runSteps: runSteps ?? this.runSteps,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (bucketStartAtUtc.present) {
      map['bucket_start_at_utc'] = Variable<int>(bucketStartAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $StepBucketsTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<int>(distanceM.value);
    }
    if (caloriesKcal.present) {
      map['calories_kcal'] = Variable<double>(caloriesKcal.value);
    }
    if (runSteps.present) {
      map['run_steps'] = Variable<int>(runSteps.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StepBucketsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('bucketStartAtUtc: $bucketStartAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('caloriesKcal: $caloriesKcal, ')
          ..write('runSteps: $runSteps, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyMetricsTable extends DailyMetrics
    with TableInfo<$DailyMetricsTable, DailyMetric> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyMetricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _localDateMeta = const VerificationMeta(
    'localDate',
  );
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
    'local_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinMeta = const VerificationMeta(
    'tzOffsetMin',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMin = GeneratedColumn<int>(
    'tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restingHrBpmMeta = const VerificationMeta(
    'restingHrBpm',
  );
  @override
  late final GeneratedColumn<int> restingHrBpm = GeneratedColumn<int>(
    'resting_hr_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrvRmssdMsMeta = const VerificationMeta(
    'hrvRmssdMs',
  );
  @override
  late final GeneratedColumn<double> hrvRmssdMs = GeneratedColumn<double>(
    'hrv_rmssd_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrvSdnnMsMeta = const VerificationMeta(
    'hrvSdnnMs',
  );
  @override
  late final GeneratedColumn<double> hrvSdnnMs = GeneratedColumn<double>(
    'hrv_sdnn_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restingRespRateBpmMeta =
      const VerificationMeta('restingRespRateBpm');
  @override
  late final GeneratedColumn<double> restingRespRateBpm =
      GeneratedColumn<double>(
        'resting_resp_rate_bpm',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _spo2OvernightAvgMeta = const VerificationMeta(
    'spo2OvernightAvg',
  );
  @override
  late final GeneratedColumn<double> spo2OvernightAvg = GeneratedColumn<double>(
    'spo2_overnight_avg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spo2OvernightMinMeta = const VerificationMeta(
    'spo2OvernightMin',
  );
  @override
  late final GeneratedColumn<int> spo2OvernightMin = GeneratedColumn<int>(
    'spo2_overnight_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _systolicMmhgMeta = const VerificationMeta(
    'systolicMmhg',
  );
  @override
  late final GeneratedColumn<int> systolicMmhg = GeneratedColumn<int>(
    'systolic_mmhg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diastolicMmhgMeta = const VerificationMeta(
    'diastolicMmhg',
  );
  @override
  late final GeneratedColumn<int> diastolicMmhg = GeneratedColumn<int>(
    'diastolic_mmhg',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepTotalMinMeta = const VerificationMeta(
    'sleepTotalMin',
  );
  @override
  late final GeneratedColumn<int> sleepTotalMin = GeneratedColumn<int>(
    'sleep_total_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepDeepPctMeta = const VerificationMeta(
    'sleepDeepPct',
  );
  @override
  late final GeneratedColumn<double> sleepDeepPct = GeneratedColumn<double>(
    'sleep_deep_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepRemPctMeta = const VerificationMeta(
    'sleepRemPct',
  );
  @override
  late final GeneratedColumn<double> sleepRemPct = GeneratedColumn<double>(
    'sleep_rem_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepLightPctMeta = const VerificationMeta(
    'sleepLightPct',
  );
  @override
  late final GeneratedColumn<double> sleepLightPct = GeneratedColumn<double>(
    'sleep_light_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepEfficiencyPctMeta =
      const VerificationMeta('sleepEfficiencyPct');
  @override
  late final GeneratedColumn<double> sleepEfficiencyPct =
      GeneratedColumn<double>(
        'sleep_efficiency_pct',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bedtimeUtcMeta = const VerificationMeta(
    'bedtimeUtc',
  );
  @override
  late final GeneratedColumn<int> bedtimeUtc = GeneratedColumn<int>(
    'bedtime_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wakeUtcMeta = const VerificationMeta(
    'wakeUtc',
  );
  @override
  late final GeneratedColumn<int> wakeUtc = GeneratedColumn<int>(
    'wake_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<int> distanceM = GeneratedColumn<int>(
    'distance_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesKcalMeta = const VerificationMeta(
    'caloriesKcal',
  );
  @override
  late final GeneratedColumn<double> caloriesKcal = GeneratedColumn<double>(
    'calories_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMinutesMeta = const VerificationMeta(
    'activeMinutes',
  );
  @override
  late final GeneratedColumn<int> activeMinutes = GeneratedColumn<int>(
    'active_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stiffnessIndexMeta = const VerificationMeta(
    'stiffnessIndex',
  );
  @override
  late final GeneratedColumn<double> stiffnessIndex = GeneratedColumn<double>(
    'stiffness_index',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _augmentationIndexMeta = const VerificationMeta(
    'augmentationIndex',
  );
  @override
  late final GeneratedColumn<double> augmentationIndex =
      GeneratedColumn<double>(
        'augmentation_index',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _strokeVolumeIndexMeta = const VerificationMeta(
    'strokeVolumeIndex',
  );
  @override
  late final GeneratedColumn<double> strokeVolumeIndex =
      GeneratedColumn<double>(
        'stroke_volume_index',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _breathingDisruptionsHrMeta =
      const VerificationMeta('breathingDisruptionsHr');
  @override
  late final GeneratedColumn<double> breathingDisruptionsHr =
      GeneratedColumn<double>(
        'breathing_disruptions_hr',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recoveryScoreMeta = const VerificationMeta(
    'recoveryScore',
  );
  @override
  late final GeneratedColumn<int> recoveryScore = GeneratedColumn<int>(
    'recovery_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wellnessScoreMeta = const VerificationMeta(
    'wellnessScore',
  );
  @override
  late final GeneratedColumn<int> wellnessScore = GeneratedColumn<int>(
    'wellness_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cyclePhaseMeta = const VerificationMeta(
    'cyclePhase',
  );
  @override
  late final GeneratedColumn<int> cyclePhase = GeneratedColumn<int>(
    'cycle_phase',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _computedAtUtcMeta = const VerificationMeta(
    'computedAtUtc',
  );
  @override
  late final GeneratedColumn<int> computedAtUtc = GeneratedColumn<int>(
    'computed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($DailyMetricsTable.$convertersource);
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    bedtimeUtc,
    wakeUtc,
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
    computedAtUtc,
    algorithmVersion,
    source,
    deletedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_metrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyMetric> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(
        _localDateMeta,
        localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta),
      );
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('tz_offset_min')) {
      context.handle(
        _tzOffsetMinMeta,
        tzOffsetMin.isAcceptableOrUnknown(
          data['tz_offset_min']!,
          _tzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinMeta);
    }
    if (data.containsKey('resting_hr_bpm')) {
      context.handle(
        _restingHrBpmMeta,
        restingHrBpm.isAcceptableOrUnknown(
          data['resting_hr_bpm']!,
          _restingHrBpmMeta,
        ),
      );
    }
    if (data.containsKey('hrv_rmssd_ms')) {
      context.handle(
        _hrvRmssdMsMeta,
        hrvRmssdMs.isAcceptableOrUnknown(
          data['hrv_rmssd_ms']!,
          _hrvRmssdMsMeta,
        ),
      );
    }
    if (data.containsKey('hrv_sdnn_ms')) {
      context.handle(
        _hrvSdnnMsMeta,
        hrvSdnnMs.isAcceptableOrUnknown(data['hrv_sdnn_ms']!, _hrvSdnnMsMeta),
      );
    }
    if (data.containsKey('resting_resp_rate_bpm')) {
      context.handle(
        _restingRespRateBpmMeta,
        restingRespRateBpm.isAcceptableOrUnknown(
          data['resting_resp_rate_bpm']!,
          _restingRespRateBpmMeta,
        ),
      );
    }
    if (data.containsKey('spo2_overnight_avg')) {
      context.handle(
        _spo2OvernightAvgMeta,
        spo2OvernightAvg.isAcceptableOrUnknown(
          data['spo2_overnight_avg']!,
          _spo2OvernightAvgMeta,
        ),
      );
    }
    if (data.containsKey('spo2_overnight_min')) {
      context.handle(
        _spo2OvernightMinMeta,
        spo2OvernightMin.isAcceptableOrUnknown(
          data['spo2_overnight_min']!,
          _spo2OvernightMinMeta,
        ),
      );
    }
    if (data.containsKey('systolic_mmhg')) {
      context.handle(
        _systolicMmhgMeta,
        systolicMmhg.isAcceptableOrUnknown(
          data['systolic_mmhg']!,
          _systolicMmhgMeta,
        ),
      );
    }
    if (data.containsKey('diastolic_mmhg')) {
      context.handle(
        _diastolicMmhgMeta,
        diastolicMmhg.isAcceptableOrUnknown(
          data['diastolic_mmhg']!,
          _diastolicMmhgMeta,
        ),
      );
    }
    if (data.containsKey('sleep_total_min')) {
      context.handle(
        _sleepTotalMinMeta,
        sleepTotalMin.isAcceptableOrUnknown(
          data['sleep_total_min']!,
          _sleepTotalMinMeta,
        ),
      );
    }
    if (data.containsKey('sleep_deep_pct')) {
      context.handle(
        _sleepDeepPctMeta,
        sleepDeepPct.isAcceptableOrUnknown(
          data['sleep_deep_pct']!,
          _sleepDeepPctMeta,
        ),
      );
    }
    if (data.containsKey('sleep_rem_pct')) {
      context.handle(
        _sleepRemPctMeta,
        sleepRemPct.isAcceptableOrUnknown(
          data['sleep_rem_pct']!,
          _sleepRemPctMeta,
        ),
      );
    }
    if (data.containsKey('sleep_light_pct')) {
      context.handle(
        _sleepLightPctMeta,
        sleepLightPct.isAcceptableOrUnknown(
          data['sleep_light_pct']!,
          _sleepLightPctMeta,
        ),
      );
    }
    if (data.containsKey('sleep_efficiency_pct')) {
      context.handle(
        _sleepEfficiencyPctMeta,
        sleepEfficiencyPct.isAcceptableOrUnknown(
          data['sleep_efficiency_pct']!,
          _sleepEfficiencyPctMeta,
        ),
      );
    }
    if (data.containsKey('bedtime_utc')) {
      context.handle(
        _bedtimeUtcMeta,
        bedtimeUtc.isAcceptableOrUnknown(data['bedtime_utc']!, _bedtimeUtcMeta),
      );
    }
    if (data.containsKey('wake_utc')) {
      context.handle(
        _wakeUtcMeta,
        wakeUtc.isAcceptableOrUnknown(data['wake_utc']!, _wakeUtcMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('calories_kcal')) {
      context.handle(
        _caloriesKcalMeta,
        caloriesKcal.isAcceptableOrUnknown(
          data['calories_kcal']!,
          _caloriesKcalMeta,
        ),
      );
    }
    if (data.containsKey('active_minutes')) {
      context.handle(
        _activeMinutesMeta,
        activeMinutes.isAcceptableOrUnknown(
          data['active_minutes']!,
          _activeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('stiffness_index')) {
      context.handle(
        _stiffnessIndexMeta,
        stiffnessIndex.isAcceptableOrUnknown(
          data['stiffness_index']!,
          _stiffnessIndexMeta,
        ),
      );
    }
    if (data.containsKey('augmentation_index')) {
      context.handle(
        _augmentationIndexMeta,
        augmentationIndex.isAcceptableOrUnknown(
          data['augmentation_index']!,
          _augmentationIndexMeta,
        ),
      );
    }
    if (data.containsKey('stroke_volume_index')) {
      context.handle(
        _strokeVolumeIndexMeta,
        strokeVolumeIndex.isAcceptableOrUnknown(
          data['stroke_volume_index']!,
          _strokeVolumeIndexMeta,
        ),
      );
    }
    if (data.containsKey('breathing_disruptions_hr')) {
      context.handle(
        _breathingDisruptionsHrMeta,
        breathingDisruptionsHr.isAcceptableOrUnknown(
          data['breathing_disruptions_hr']!,
          _breathingDisruptionsHrMeta,
        ),
      );
    }
    if (data.containsKey('recovery_score')) {
      context.handle(
        _recoveryScoreMeta,
        recoveryScore.isAcceptableOrUnknown(
          data['recovery_score']!,
          _recoveryScoreMeta,
        ),
      );
    }
    if (data.containsKey('wellness_score')) {
      context.handle(
        _wellnessScoreMeta,
        wellnessScore.isAcceptableOrUnknown(
          data['wellness_score']!,
          _wellnessScoreMeta,
        ),
      );
    }
    if (data.containsKey('cycle_phase')) {
      context.handle(
        _cyclePhaseMeta,
        cyclePhase.isAcceptableOrUnknown(data['cycle_phase']!, _cyclePhaseMeta),
      );
    }
    if (data.containsKey('computed_at_utc')) {
      context.handle(
        _computedAtUtcMeta,
        computedAtUtc.isAcceptableOrUnknown(
          data['computed_at_utc']!,
          _computedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_computedAtUtcMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyMetric map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyMetric(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      localDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_date'],
      )!,
      tzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_min'],
      )!,
      restingHrBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resting_hr_bpm'],
      ),
      hrvRmssdMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hrv_rmssd_ms'],
      ),
      hrvSdnnMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hrv_sdnn_ms'],
      ),
      restingRespRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resting_resp_rate_bpm'],
      ),
      spo2OvernightAvg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}spo2_overnight_avg'],
      ),
      spo2OvernightMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spo2_overnight_min'],
      ),
      systolicMmhg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}systolic_mmhg'],
      ),
      diastolicMmhg: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diastolic_mmhg'],
      ),
      sleepTotalMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleep_total_min'],
      ),
      sleepDeepPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_deep_pct'],
      ),
      sleepRemPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_rem_pct'],
      ),
      sleepLightPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_light_pct'],
      ),
      sleepEfficiencyPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_efficiency_pct'],
      ),
      bedtimeUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bedtime_utc'],
      ),
      wakeUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wake_utc'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      ),
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_m'],
      ),
      caloriesKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calories_kcal'],
      ),
      activeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_minutes'],
      ),
      stiffnessIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stiffness_index'],
      ),
      augmentationIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}augmentation_index'],
      ),
      strokeVolumeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stroke_volume_index'],
      ),
      breathingDisruptionsHr: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}breathing_disruptions_hr'],
      ),
      recoveryScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recovery_score'],
      ),
      wellnessScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wellness_score'],
      ),
      cyclePhase: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_phase'],
      ),
      computedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}computed_at_utc'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
      source: $DailyMetricsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
    );
  }

  @override
  $DailyMetricsTable createAlias(String alias) {
    return $DailyMetricsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class DailyMetric extends DataClass implements Insertable<DailyMetric> {
  final String id;
  final String userId;
  final String localDate;
  final int tzOffsetMin;
  final int? restingHrBpm;
  final double? hrvRmssdMs;
  final double? hrvSdnnMs;
  final double? restingRespRateBpm;
  final double? spo2OvernightAvg;
  final int? spo2OvernightMin;
  final int? systolicMmhg;
  final int? diastolicMmhg;
  final int? sleepTotalMin;
  final double? sleepDeepPct;
  final double? sleepRemPct;
  final double? sleepLightPct;
  final double? sleepEfficiencyPct;
  final int? bedtimeUtc;
  final int? wakeUtc;
  final int? steps;
  final int? distanceM;
  final double? caloriesKcal;
  final int? activeMinutes;
  final double? stiffnessIndex;
  final double? augmentationIndex;
  final double? strokeVolumeIndex;
  final double? breathingDisruptionsHr;
  final int? recoveryScore;
  final int? wellnessScore;
  final int? cyclePhase;
  final int computedAtUtc;
  final String algorithmVersion;
  final DataSource source;
  final int? deletedAtUtc;
  const DailyMetric({
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
    this.bedtimeUtc,
    this.wakeUtc,
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
    required this.computedAtUtc,
    required this.algorithmVersion,
    required this.source,
    this.deletedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['local_date'] = Variable<String>(localDate);
    map['tz_offset_min'] = Variable<int>(tzOffsetMin);
    if (!nullToAbsent || restingHrBpm != null) {
      map['resting_hr_bpm'] = Variable<int>(restingHrBpm);
    }
    if (!nullToAbsent || hrvRmssdMs != null) {
      map['hrv_rmssd_ms'] = Variable<double>(hrvRmssdMs);
    }
    if (!nullToAbsent || hrvSdnnMs != null) {
      map['hrv_sdnn_ms'] = Variable<double>(hrvSdnnMs);
    }
    if (!nullToAbsent || restingRespRateBpm != null) {
      map['resting_resp_rate_bpm'] = Variable<double>(restingRespRateBpm);
    }
    if (!nullToAbsent || spo2OvernightAvg != null) {
      map['spo2_overnight_avg'] = Variable<double>(spo2OvernightAvg);
    }
    if (!nullToAbsent || spo2OvernightMin != null) {
      map['spo2_overnight_min'] = Variable<int>(spo2OvernightMin);
    }
    if (!nullToAbsent || systolicMmhg != null) {
      map['systolic_mmhg'] = Variable<int>(systolicMmhg);
    }
    if (!nullToAbsent || diastolicMmhg != null) {
      map['diastolic_mmhg'] = Variable<int>(diastolicMmhg);
    }
    if (!nullToAbsent || sleepTotalMin != null) {
      map['sleep_total_min'] = Variable<int>(sleepTotalMin);
    }
    if (!nullToAbsent || sleepDeepPct != null) {
      map['sleep_deep_pct'] = Variable<double>(sleepDeepPct);
    }
    if (!nullToAbsent || sleepRemPct != null) {
      map['sleep_rem_pct'] = Variable<double>(sleepRemPct);
    }
    if (!nullToAbsent || sleepLightPct != null) {
      map['sleep_light_pct'] = Variable<double>(sleepLightPct);
    }
    if (!nullToAbsent || sleepEfficiencyPct != null) {
      map['sleep_efficiency_pct'] = Variable<double>(sleepEfficiencyPct);
    }
    if (!nullToAbsent || bedtimeUtc != null) {
      map['bedtime_utc'] = Variable<int>(bedtimeUtc);
    }
    if (!nullToAbsent || wakeUtc != null) {
      map['wake_utc'] = Variable<int>(wakeUtc);
    }
    if (!nullToAbsent || steps != null) {
      map['steps'] = Variable<int>(steps);
    }
    if (!nullToAbsent || distanceM != null) {
      map['distance_m'] = Variable<int>(distanceM);
    }
    if (!nullToAbsent || caloriesKcal != null) {
      map['calories_kcal'] = Variable<double>(caloriesKcal);
    }
    if (!nullToAbsent || activeMinutes != null) {
      map['active_minutes'] = Variable<int>(activeMinutes);
    }
    if (!nullToAbsent || stiffnessIndex != null) {
      map['stiffness_index'] = Variable<double>(stiffnessIndex);
    }
    if (!nullToAbsent || augmentationIndex != null) {
      map['augmentation_index'] = Variable<double>(augmentationIndex);
    }
    if (!nullToAbsent || strokeVolumeIndex != null) {
      map['stroke_volume_index'] = Variable<double>(strokeVolumeIndex);
    }
    if (!nullToAbsent || breathingDisruptionsHr != null) {
      map['breathing_disruptions_hr'] = Variable<double>(
        breathingDisruptionsHr,
      );
    }
    if (!nullToAbsent || recoveryScore != null) {
      map['recovery_score'] = Variable<int>(recoveryScore);
    }
    if (!nullToAbsent || wellnessScore != null) {
      map['wellness_score'] = Variable<int>(wellnessScore);
    }
    if (!nullToAbsent || cyclePhase != null) {
      map['cycle_phase'] = Variable<int>(cyclePhase);
    }
    map['computed_at_utc'] = Variable<int>(computedAtUtc);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    {
      map['source'] = Variable<int>(
        $DailyMetricsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    return map;
  }

  DailyMetricsCompanion toCompanion(bool nullToAbsent) {
    return DailyMetricsCompanion(
      id: Value(id),
      userId: Value(userId),
      localDate: Value(localDate),
      tzOffsetMin: Value(tzOffsetMin),
      restingHrBpm: restingHrBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(restingHrBpm),
      hrvRmssdMs: hrvRmssdMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hrvRmssdMs),
      hrvSdnnMs: hrvSdnnMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hrvSdnnMs),
      restingRespRateBpm: restingRespRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(restingRespRateBpm),
      spo2OvernightAvg: spo2OvernightAvg == null && nullToAbsent
          ? const Value.absent()
          : Value(spo2OvernightAvg),
      spo2OvernightMin: spo2OvernightMin == null && nullToAbsent
          ? const Value.absent()
          : Value(spo2OvernightMin),
      systolicMmhg: systolicMmhg == null && nullToAbsent
          ? const Value.absent()
          : Value(systolicMmhg),
      diastolicMmhg: diastolicMmhg == null && nullToAbsent
          ? const Value.absent()
          : Value(diastolicMmhg),
      sleepTotalMin: sleepTotalMin == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepTotalMin),
      sleepDeepPct: sleepDeepPct == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepDeepPct),
      sleepRemPct: sleepRemPct == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepRemPct),
      sleepLightPct: sleepLightPct == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepLightPct),
      sleepEfficiencyPct: sleepEfficiencyPct == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepEfficiencyPct),
      bedtimeUtc: bedtimeUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(bedtimeUtc),
      wakeUtc: wakeUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(wakeUtc),
      steps: steps == null && nullToAbsent
          ? const Value.absent()
          : Value(steps),
      distanceM: distanceM == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceM),
      caloriesKcal: caloriesKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(caloriesKcal),
      activeMinutes: activeMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(activeMinutes),
      stiffnessIndex: stiffnessIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(stiffnessIndex),
      augmentationIndex: augmentationIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(augmentationIndex),
      strokeVolumeIndex: strokeVolumeIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(strokeVolumeIndex),
      breathingDisruptionsHr: breathingDisruptionsHr == null && nullToAbsent
          ? const Value.absent()
          : Value(breathingDisruptionsHr),
      recoveryScore: recoveryScore == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryScore),
      wellnessScore: wellnessScore == null && nullToAbsent
          ? const Value.absent()
          : Value(wellnessScore),
      cyclePhase: cyclePhase == null && nullToAbsent
          ? const Value.absent()
          : Value(cyclePhase),
      computedAtUtc: Value(computedAtUtc),
      algorithmVersion: Value(algorithmVersion),
      source: Value(source),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
    );
  }

  factory DailyMetric.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyMetric(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      localDate: serializer.fromJson<String>(json['localDate']),
      tzOffsetMin: serializer.fromJson<int>(json['tzOffsetMin']),
      restingHrBpm: serializer.fromJson<int?>(json['restingHrBpm']),
      hrvRmssdMs: serializer.fromJson<double?>(json['hrvRmssdMs']),
      hrvSdnnMs: serializer.fromJson<double?>(json['hrvSdnnMs']),
      restingRespRateBpm: serializer.fromJson<double?>(
        json['restingRespRateBpm'],
      ),
      spo2OvernightAvg: serializer.fromJson<double?>(json['spo2OvernightAvg']),
      spo2OvernightMin: serializer.fromJson<int?>(json['spo2OvernightMin']),
      systolicMmhg: serializer.fromJson<int?>(json['systolicMmhg']),
      diastolicMmhg: serializer.fromJson<int?>(json['diastolicMmhg']),
      sleepTotalMin: serializer.fromJson<int?>(json['sleepTotalMin']),
      sleepDeepPct: serializer.fromJson<double?>(json['sleepDeepPct']),
      sleepRemPct: serializer.fromJson<double?>(json['sleepRemPct']),
      sleepLightPct: serializer.fromJson<double?>(json['sleepLightPct']),
      sleepEfficiencyPct: serializer.fromJson<double?>(
        json['sleepEfficiencyPct'],
      ),
      bedtimeUtc: serializer.fromJson<int?>(json['bedtimeUtc']),
      wakeUtc: serializer.fromJson<int?>(json['wakeUtc']),
      steps: serializer.fromJson<int?>(json['steps']),
      distanceM: serializer.fromJson<int?>(json['distanceM']),
      caloriesKcal: serializer.fromJson<double?>(json['caloriesKcal']),
      activeMinutes: serializer.fromJson<int?>(json['activeMinutes']),
      stiffnessIndex: serializer.fromJson<double?>(json['stiffnessIndex']),
      augmentationIndex: serializer.fromJson<double?>(
        json['augmentationIndex'],
      ),
      strokeVolumeIndex: serializer.fromJson<double?>(
        json['strokeVolumeIndex'],
      ),
      breathingDisruptionsHr: serializer.fromJson<double?>(
        json['breathingDisruptionsHr'],
      ),
      recoveryScore: serializer.fromJson<int?>(json['recoveryScore']),
      wellnessScore: serializer.fromJson<int?>(json['wellnessScore']),
      cyclePhase: serializer.fromJson<int?>(json['cyclePhase']),
      computedAtUtc: serializer.fromJson<int>(json['computedAtUtc']),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
      source: $DailyMetricsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'localDate': serializer.toJson<String>(localDate),
      'tzOffsetMin': serializer.toJson<int>(tzOffsetMin),
      'restingHrBpm': serializer.toJson<int?>(restingHrBpm),
      'hrvRmssdMs': serializer.toJson<double?>(hrvRmssdMs),
      'hrvSdnnMs': serializer.toJson<double?>(hrvSdnnMs),
      'restingRespRateBpm': serializer.toJson<double?>(restingRespRateBpm),
      'spo2OvernightAvg': serializer.toJson<double?>(spo2OvernightAvg),
      'spo2OvernightMin': serializer.toJson<int?>(spo2OvernightMin),
      'systolicMmhg': serializer.toJson<int?>(systolicMmhg),
      'diastolicMmhg': serializer.toJson<int?>(diastolicMmhg),
      'sleepTotalMin': serializer.toJson<int?>(sleepTotalMin),
      'sleepDeepPct': serializer.toJson<double?>(sleepDeepPct),
      'sleepRemPct': serializer.toJson<double?>(sleepRemPct),
      'sleepLightPct': serializer.toJson<double?>(sleepLightPct),
      'sleepEfficiencyPct': serializer.toJson<double?>(sleepEfficiencyPct),
      'bedtimeUtc': serializer.toJson<int?>(bedtimeUtc),
      'wakeUtc': serializer.toJson<int?>(wakeUtc),
      'steps': serializer.toJson<int?>(steps),
      'distanceM': serializer.toJson<int?>(distanceM),
      'caloriesKcal': serializer.toJson<double?>(caloriesKcal),
      'activeMinutes': serializer.toJson<int?>(activeMinutes),
      'stiffnessIndex': serializer.toJson<double?>(stiffnessIndex),
      'augmentationIndex': serializer.toJson<double?>(augmentationIndex),
      'strokeVolumeIndex': serializer.toJson<double?>(strokeVolumeIndex),
      'breathingDisruptionsHr': serializer.toJson<double?>(
        breathingDisruptionsHr,
      ),
      'recoveryScore': serializer.toJson<int?>(recoveryScore),
      'wellnessScore': serializer.toJson<int?>(wellnessScore),
      'cyclePhase': serializer.toJson<int?>(cyclePhase),
      'computedAtUtc': serializer.toJson<int>(computedAtUtc),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
      'source': serializer.toJson<int>(
        $DailyMetricsTable.$convertersource.toJson(source),
      ),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
    };
  }

  DailyMetric copyWith({
    String? id,
    String? userId,
    String? localDate,
    int? tzOffsetMin,
    Value<int?> restingHrBpm = const Value.absent(),
    Value<double?> hrvRmssdMs = const Value.absent(),
    Value<double?> hrvSdnnMs = const Value.absent(),
    Value<double?> restingRespRateBpm = const Value.absent(),
    Value<double?> spo2OvernightAvg = const Value.absent(),
    Value<int?> spo2OvernightMin = const Value.absent(),
    Value<int?> systolicMmhg = const Value.absent(),
    Value<int?> diastolicMmhg = const Value.absent(),
    Value<int?> sleepTotalMin = const Value.absent(),
    Value<double?> sleepDeepPct = const Value.absent(),
    Value<double?> sleepRemPct = const Value.absent(),
    Value<double?> sleepLightPct = const Value.absent(),
    Value<double?> sleepEfficiencyPct = const Value.absent(),
    Value<int?> bedtimeUtc = const Value.absent(),
    Value<int?> wakeUtc = const Value.absent(),
    Value<int?> steps = const Value.absent(),
    Value<int?> distanceM = const Value.absent(),
    Value<double?> caloriesKcal = const Value.absent(),
    Value<int?> activeMinutes = const Value.absent(),
    Value<double?> stiffnessIndex = const Value.absent(),
    Value<double?> augmentationIndex = const Value.absent(),
    Value<double?> strokeVolumeIndex = const Value.absent(),
    Value<double?> breathingDisruptionsHr = const Value.absent(),
    Value<int?> recoveryScore = const Value.absent(),
    Value<int?> wellnessScore = const Value.absent(),
    Value<int?> cyclePhase = const Value.absent(),
    int? computedAtUtc,
    String? algorithmVersion,
    DataSource? source,
    Value<int?> deletedAtUtc = const Value.absent(),
  }) => DailyMetric(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    localDate: localDate ?? this.localDate,
    tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
    restingHrBpm: restingHrBpm.present ? restingHrBpm.value : this.restingHrBpm,
    hrvRmssdMs: hrvRmssdMs.present ? hrvRmssdMs.value : this.hrvRmssdMs,
    hrvSdnnMs: hrvSdnnMs.present ? hrvSdnnMs.value : this.hrvSdnnMs,
    restingRespRateBpm: restingRespRateBpm.present
        ? restingRespRateBpm.value
        : this.restingRespRateBpm,
    spo2OvernightAvg: spo2OvernightAvg.present
        ? spo2OvernightAvg.value
        : this.spo2OvernightAvg,
    spo2OvernightMin: spo2OvernightMin.present
        ? spo2OvernightMin.value
        : this.spo2OvernightMin,
    systolicMmhg: systolicMmhg.present ? systolicMmhg.value : this.systolicMmhg,
    diastolicMmhg: diastolicMmhg.present
        ? diastolicMmhg.value
        : this.diastolicMmhg,
    sleepTotalMin: sleepTotalMin.present
        ? sleepTotalMin.value
        : this.sleepTotalMin,
    sleepDeepPct: sleepDeepPct.present ? sleepDeepPct.value : this.sleepDeepPct,
    sleepRemPct: sleepRemPct.present ? sleepRemPct.value : this.sleepRemPct,
    sleepLightPct: sleepLightPct.present
        ? sleepLightPct.value
        : this.sleepLightPct,
    sleepEfficiencyPct: sleepEfficiencyPct.present
        ? sleepEfficiencyPct.value
        : this.sleepEfficiencyPct,
    bedtimeUtc: bedtimeUtc.present ? bedtimeUtc.value : this.bedtimeUtc,
    wakeUtc: wakeUtc.present ? wakeUtc.value : this.wakeUtc,
    steps: steps.present ? steps.value : this.steps,
    distanceM: distanceM.present ? distanceM.value : this.distanceM,
    caloriesKcal: caloriesKcal.present ? caloriesKcal.value : this.caloriesKcal,
    activeMinutes: activeMinutes.present
        ? activeMinutes.value
        : this.activeMinutes,
    stiffnessIndex: stiffnessIndex.present
        ? stiffnessIndex.value
        : this.stiffnessIndex,
    augmentationIndex: augmentationIndex.present
        ? augmentationIndex.value
        : this.augmentationIndex,
    strokeVolumeIndex: strokeVolumeIndex.present
        ? strokeVolumeIndex.value
        : this.strokeVolumeIndex,
    breathingDisruptionsHr: breathingDisruptionsHr.present
        ? breathingDisruptionsHr.value
        : this.breathingDisruptionsHr,
    recoveryScore: recoveryScore.present
        ? recoveryScore.value
        : this.recoveryScore,
    wellnessScore: wellnessScore.present
        ? wellnessScore.value
        : this.wellnessScore,
    cyclePhase: cyclePhase.present ? cyclePhase.value : this.cyclePhase,
    computedAtUtc: computedAtUtc ?? this.computedAtUtc,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
    source: source ?? this.source,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
  );
  DailyMetric copyWithCompanion(DailyMetricsCompanion data) {
    return DailyMetric(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      tzOffsetMin: data.tzOffsetMin.present
          ? data.tzOffsetMin.value
          : this.tzOffsetMin,
      restingHrBpm: data.restingHrBpm.present
          ? data.restingHrBpm.value
          : this.restingHrBpm,
      hrvRmssdMs: data.hrvRmssdMs.present
          ? data.hrvRmssdMs.value
          : this.hrvRmssdMs,
      hrvSdnnMs: data.hrvSdnnMs.present ? data.hrvSdnnMs.value : this.hrvSdnnMs,
      restingRespRateBpm: data.restingRespRateBpm.present
          ? data.restingRespRateBpm.value
          : this.restingRespRateBpm,
      spo2OvernightAvg: data.spo2OvernightAvg.present
          ? data.spo2OvernightAvg.value
          : this.spo2OvernightAvg,
      spo2OvernightMin: data.spo2OvernightMin.present
          ? data.spo2OvernightMin.value
          : this.spo2OvernightMin,
      systolicMmhg: data.systolicMmhg.present
          ? data.systolicMmhg.value
          : this.systolicMmhg,
      diastolicMmhg: data.diastolicMmhg.present
          ? data.diastolicMmhg.value
          : this.diastolicMmhg,
      sleepTotalMin: data.sleepTotalMin.present
          ? data.sleepTotalMin.value
          : this.sleepTotalMin,
      sleepDeepPct: data.sleepDeepPct.present
          ? data.sleepDeepPct.value
          : this.sleepDeepPct,
      sleepRemPct: data.sleepRemPct.present
          ? data.sleepRemPct.value
          : this.sleepRemPct,
      sleepLightPct: data.sleepLightPct.present
          ? data.sleepLightPct.value
          : this.sleepLightPct,
      sleepEfficiencyPct: data.sleepEfficiencyPct.present
          ? data.sleepEfficiencyPct.value
          : this.sleepEfficiencyPct,
      bedtimeUtc: data.bedtimeUtc.present
          ? data.bedtimeUtc.value
          : this.bedtimeUtc,
      wakeUtc: data.wakeUtc.present ? data.wakeUtc.value : this.wakeUtc,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      caloriesKcal: data.caloriesKcal.present
          ? data.caloriesKcal.value
          : this.caloriesKcal,
      activeMinutes: data.activeMinutes.present
          ? data.activeMinutes.value
          : this.activeMinutes,
      stiffnessIndex: data.stiffnessIndex.present
          ? data.stiffnessIndex.value
          : this.stiffnessIndex,
      augmentationIndex: data.augmentationIndex.present
          ? data.augmentationIndex.value
          : this.augmentationIndex,
      strokeVolumeIndex: data.strokeVolumeIndex.present
          ? data.strokeVolumeIndex.value
          : this.strokeVolumeIndex,
      breathingDisruptionsHr: data.breathingDisruptionsHr.present
          ? data.breathingDisruptionsHr.value
          : this.breathingDisruptionsHr,
      recoveryScore: data.recoveryScore.present
          ? data.recoveryScore.value
          : this.recoveryScore,
      wellnessScore: data.wellnessScore.present
          ? data.wellnessScore.value
          : this.wellnessScore,
      cyclePhase: data.cyclePhase.present
          ? data.cyclePhase.value
          : this.cyclePhase,
      computedAtUtc: data.computedAtUtc.present
          ? data.computedAtUtc.value
          : this.computedAtUtc,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      source: data.source.present ? data.source.value : this.source,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyMetric(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('localDate: $localDate, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('restingHrBpm: $restingHrBpm, ')
          ..write('hrvRmssdMs: $hrvRmssdMs, ')
          ..write('hrvSdnnMs: $hrvSdnnMs, ')
          ..write('restingRespRateBpm: $restingRespRateBpm, ')
          ..write('spo2OvernightAvg: $spo2OvernightAvg, ')
          ..write('spo2OvernightMin: $spo2OvernightMin, ')
          ..write('systolicMmhg: $systolicMmhg, ')
          ..write('diastolicMmhg: $diastolicMmhg, ')
          ..write('sleepTotalMin: $sleepTotalMin, ')
          ..write('sleepDeepPct: $sleepDeepPct, ')
          ..write('sleepRemPct: $sleepRemPct, ')
          ..write('sleepLightPct: $sleepLightPct, ')
          ..write('sleepEfficiencyPct: $sleepEfficiencyPct, ')
          ..write('bedtimeUtc: $bedtimeUtc, ')
          ..write('wakeUtc: $wakeUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('caloriesKcal: $caloriesKcal, ')
          ..write('activeMinutes: $activeMinutes, ')
          ..write('stiffnessIndex: $stiffnessIndex, ')
          ..write('augmentationIndex: $augmentationIndex, ')
          ..write('strokeVolumeIndex: $strokeVolumeIndex, ')
          ..write('breathingDisruptionsHr: $breathingDisruptionsHr, ')
          ..write('recoveryScore: $recoveryScore, ')
          ..write('wellnessScore: $wellnessScore, ')
          ..write('cyclePhase: $cyclePhase, ')
          ..write('computedAtUtc: $computedAtUtc, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('source: $source, ')
          ..write('deletedAtUtc: $deletedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    bedtimeUtc,
    wakeUtc,
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
    computedAtUtc,
    algorithmVersion,
    source,
    deletedAtUtc,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyMetric &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.localDate == this.localDate &&
          other.tzOffsetMin == this.tzOffsetMin &&
          other.restingHrBpm == this.restingHrBpm &&
          other.hrvRmssdMs == this.hrvRmssdMs &&
          other.hrvSdnnMs == this.hrvSdnnMs &&
          other.restingRespRateBpm == this.restingRespRateBpm &&
          other.spo2OvernightAvg == this.spo2OvernightAvg &&
          other.spo2OvernightMin == this.spo2OvernightMin &&
          other.systolicMmhg == this.systolicMmhg &&
          other.diastolicMmhg == this.diastolicMmhg &&
          other.sleepTotalMin == this.sleepTotalMin &&
          other.sleepDeepPct == this.sleepDeepPct &&
          other.sleepRemPct == this.sleepRemPct &&
          other.sleepLightPct == this.sleepLightPct &&
          other.sleepEfficiencyPct == this.sleepEfficiencyPct &&
          other.bedtimeUtc == this.bedtimeUtc &&
          other.wakeUtc == this.wakeUtc &&
          other.steps == this.steps &&
          other.distanceM == this.distanceM &&
          other.caloriesKcal == this.caloriesKcal &&
          other.activeMinutes == this.activeMinutes &&
          other.stiffnessIndex == this.stiffnessIndex &&
          other.augmentationIndex == this.augmentationIndex &&
          other.strokeVolumeIndex == this.strokeVolumeIndex &&
          other.breathingDisruptionsHr == this.breathingDisruptionsHr &&
          other.recoveryScore == this.recoveryScore &&
          other.wellnessScore == this.wellnessScore &&
          other.cyclePhase == this.cyclePhase &&
          other.computedAtUtc == this.computedAtUtc &&
          other.algorithmVersion == this.algorithmVersion &&
          other.source == this.source &&
          other.deletedAtUtc == this.deletedAtUtc);
}

class DailyMetricsCompanion extends UpdateCompanion<DailyMetric> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> localDate;
  final Value<int> tzOffsetMin;
  final Value<int?> restingHrBpm;
  final Value<double?> hrvRmssdMs;
  final Value<double?> hrvSdnnMs;
  final Value<double?> restingRespRateBpm;
  final Value<double?> spo2OvernightAvg;
  final Value<int?> spo2OvernightMin;
  final Value<int?> systolicMmhg;
  final Value<int?> diastolicMmhg;
  final Value<int?> sleepTotalMin;
  final Value<double?> sleepDeepPct;
  final Value<double?> sleepRemPct;
  final Value<double?> sleepLightPct;
  final Value<double?> sleepEfficiencyPct;
  final Value<int?> bedtimeUtc;
  final Value<int?> wakeUtc;
  final Value<int?> steps;
  final Value<int?> distanceM;
  final Value<double?> caloriesKcal;
  final Value<int?> activeMinutes;
  final Value<double?> stiffnessIndex;
  final Value<double?> augmentationIndex;
  final Value<double?> strokeVolumeIndex;
  final Value<double?> breathingDisruptionsHr;
  final Value<int?> recoveryScore;
  final Value<int?> wellnessScore;
  final Value<int?> cyclePhase;
  final Value<int> computedAtUtc;
  final Value<String> algorithmVersion;
  final Value<DataSource> source;
  final Value<int?> deletedAtUtc;
  final Value<int> rowid;
  const DailyMetricsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.tzOffsetMin = const Value.absent(),
    this.restingHrBpm = const Value.absent(),
    this.hrvRmssdMs = const Value.absent(),
    this.hrvSdnnMs = const Value.absent(),
    this.restingRespRateBpm = const Value.absent(),
    this.spo2OvernightAvg = const Value.absent(),
    this.spo2OvernightMin = const Value.absent(),
    this.systolicMmhg = const Value.absent(),
    this.diastolicMmhg = const Value.absent(),
    this.sleepTotalMin = const Value.absent(),
    this.sleepDeepPct = const Value.absent(),
    this.sleepRemPct = const Value.absent(),
    this.sleepLightPct = const Value.absent(),
    this.sleepEfficiencyPct = const Value.absent(),
    this.bedtimeUtc = const Value.absent(),
    this.wakeUtc = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.caloriesKcal = const Value.absent(),
    this.activeMinutes = const Value.absent(),
    this.stiffnessIndex = const Value.absent(),
    this.augmentationIndex = const Value.absent(),
    this.strokeVolumeIndex = const Value.absent(),
    this.breathingDisruptionsHr = const Value.absent(),
    this.recoveryScore = const Value.absent(),
    this.wellnessScore = const Value.absent(),
    this.cyclePhase = const Value.absent(),
    this.computedAtUtc = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.source = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyMetricsCompanion.insert({
    required String id,
    required String userId,
    required String localDate,
    required int tzOffsetMin,
    this.restingHrBpm = const Value.absent(),
    this.hrvRmssdMs = const Value.absent(),
    this.hrvSdnnMs = const Value.absent(),
    this.restingRespRateBpm = const Value.absent(),
    this.spo2OvernightAvg = const Value.absent(),
    this.spo2OvernightMin = const Value.absent(),
    this.systolicMmhg = const Value.absent(),
    this.diastolicMmhg = const Value.absent(),
    this.sleepTotalMin = const Value.absent(),
    this.sleepDeepPct = const Value.absent(),
    this.sleepRemPct = const Value.absent(),
    this.sleepLightPct = const Value.absent(),
    this.sleepEfficiencyPct = const Value.absent(),
    this.bedtimeUtc = const Value.absent(),
    this.wakeUtc = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.caloriesKcal = const Value.absent(),
    this.activeMinutes = const Value.absent(),
    this.stiffnessIndex = const Value.absent(),
    this.augmentationIndex = const Value.absent(),
    this.strokeVolumeIndex = const Value.absent(),
    this.breathingDisruptionsHr = const Value.absent(),
    this.recoveryScore = const Value.absent(),
    this.wellnessScore = const Value.absent(),
    this.cyclePhase = const Value.absent(),
    required int computedAtUtc,
    required String algorithmVersion,
    required DataSource source,
    this.deletedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       localDate = Value(localDate),
       tzOffsetMin = Value(tzOffsetMin),
       computedAtUtc = Value(computedAtUtc),
       algorithmVersion = Value(algorithmVersion),
       source = Value(source);
  static Insertable<DailyMetric> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? localDate,
    Expression<int>? tzOffsetMin,
    Expression<int>? restingHrBpm,
    Expression<double>? hrvRmssdMs,
    Expression<double>? hrvSdnnMs,
    Expression<double>? restingRespRateBpm,
    Expression<double>? spo2OvernightAvg,
    Expression<int>? spo2OvernightMin,
    Expression<int>? systolicMmhg,
    Expression<int>? diastolicMmhg,
    Expression<int>? sleepTotalMin,
    Expression<double>? sleepDeepPct,
    Expression<double>? sleepRemPct,
    Expression<double>? sleepLightPct,
    Expression<double>? sleepEfficiencyPct,
    Expression<int>? bedtimeUtc,
    Expression<int>? wakeUtc,
    Expression<int>? steps,
    Expression<int>? distanceM,
    Expression<double>? caloriesKcal,
    Expression<int>? activeMinutes,
    Expression<double>? stiffnessIndex,
    Expression<double>? augmentationIndex,
    Expression<double>? strokeVolumeIndex,
    Expression<double>? breathingDisruptionsHr,
    Expression<int>? recoveryScore,
    Expression<int>? wellnessScore,
    Expression<int>? cyclePhase,
    Expression<int>? computedAtUtc,
    Expression<String>? algorithmVersion,
    Expression<int>? source,
    Expression<int>? deletedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (localDate != null) 'local_date': localDate,
      if (tzOffsetMin != null) 'tz_offset_min': tzOffsetMin,
      if (restingHrBpm != null) 'resting_hr_bpm': restingHrBpm,
      if (hrvRmssdMs != null) 'hrv_rmssd_ms': hrvRmssdMs,
      if (hrvSdnnMs != null) 'hrv_sdnn_ms': hrvSdnnMs,
      if (restingRespRateBpm != null)
        'resting_resp_rate_bpm': restingRespRateBpm,
      if (spo2OvernightAvg != null) 'spo2_overnight_avg': spo2OvernightAvg,
      if (spo2OvernightMin != null) 'spo2_overnight_min': spo2OvernightMin,
      if (systolicMmhg != null) 'systolic_mmhg': systolicMmhg,
      if (diastolicMmhg != null) 'diastolic_mmhg': diastolicMmhg,
      if (sleepTotalMin != null) 'sleep_total_min': sleepTotalMin,
      if (sleepDeepPct != null) 'sleep_deep_pct': sleepDeepPct,
      if (sleepRemPct != null) 'sleep_rem_pct': sleepRemPct,
      if (sleepLightPct != null) 'sleep_light_pct': sleepLightPct,
      if (sleepEfficiencyPct != null)
        'sleep_efficiency_pct': sleepEfficiencyPct,
      if (bedtimeUtc != null) 'bedtime_utc': bedtimeUtc,
      if (wakeUtc != null) 'wake_utc': wakeUtc,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
      if (activeMinutes != null) 'active_minutes': activeMinutes,
      if (stiffnessIndex != null) 'stiffness_index': stiffnessIndex,
      if (augmentationIndex != null) 'augmentation_index': augmentationIndex,
      if (strokeVolumeIndex != null) 'stroke_volume_index': strokeVolumeIndex,
      if (breathingDisruptionsHr != null)
        'breathing_disruptions_hr': breathingDisruptionsHr,
      if (recoveryScore != null) 'recovery_score': recoveryScore,
      if (wellnessScore != null) 'wellness_score': wellnessScore,
      if (cyclePhase != null) 'cycle_phase': cyclePhase,
      if (computedAtUtc != null) 'computed_at_utc': computedAtUtc,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (source != null) 'source': source,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyMetricsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? localDate,
    Value<int>? tzOffsetMin,
    Value<int?>? restingHrBpm,
    Value<double?>? hrvRmssdMs,
    Value<double?>? hrvSdnnMs,
    Value<double?>? restingRespRateBpm,
    Value<double?>? spo2OvernightAvg,
    Value<int?>? spo2OvernightMin,
    Value<int?>? systolicMmhg,
    Value<int?>? diastolicMmhg,
    Value<int?>? sleepTotalMin,
    Value<double?>? sleepDeepPct,
    Value<double?>? sleepRemPct,
    Value<double?>? sleepLightPct,
    Value<double?>? sleepEfficiencyPct,
    Value<int?>? bedtimeUtc,
    Value<int?>? wakeUtc,
    Value<int?>? steps,
    Value<int?>? distanceM,
    Value<double?>? caloriesKcal,
    Value<int?>? activeMinutes,
    Value<double?>? stiffnessIndex,
    Value<double?>? augmentationIndex,
    Value<double?>? strokeVolumeIndex,
    Value<double?>? breathingDisruptionsHr,
    Value<int?>? recoveryScore,
    Value<int?>? wellnessScore,
    Value<int?>? cyclePhase,
    Value<int>? computedAtUtc,
    Value<String>? algorithmVersion,
    Value<DataSource>? source,
    Value<int?>? deletedAtUtc,
    Value<int>? rowid,
  }) {
    return DailyMetricsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      localDate: localDate ?? this.localDate,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      restingHrBpm: restingHrBpm ?? this.restingHrBpm,
      hrvRmssdMs: hrvRmssdMs ?? this.hrvRmssdMs,
      hrvSdnnMs: hrvSdnnMs ?? this.hrvSdnnMs,
      restingRespRateBpm: restingRespRateBpm ?? this.restingRespRateBpm,
      spo2OvernightAvg: spo2OvernightAvg ?? this.spo2OvernightAvg,
      spo2OvernightMin: spo2OvernightMin ?? this.spo2OvernightMin,
      systolicMmhg: systolicMmhg ?? this.systolicMmhg,
      diastolicMmhg: diastolicMmhg ?? this.diastolicMmhg,
      sleepTotalMin: sleepTotalMin ?? this.sleepTotalMin,
      sleepDeepPct: sleepDeepPct ?? this.sleepDeepPct,
      sleepRemPct: sleepRemPct ?? this.sleepRemPct,
      sleepLightPct: sleepLightPct ?? this.sleepLightPct,
      sleepEfficiencyPct: sleepEfficiencyPct ?? this.sleepEfficiencyPct,
      bedtimeUtc: bedtimeUtc ?? this.bedtimeUtc,
      wakeUtc: wakeUtc ?? this.wakeUtc,
      steps: steps ?? this.steps,
      distanceM: distanceM ?? this.distanceM,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      stiffnessIndex: stiffnessIndex ?? this.stiffnessIndex,
      augmentationIndex: augmentationIndex ?? this.augmentationIndex,
      strokeVolumeIndex: strokeVolumeIndex ?? this.strokeVolumeIndex,
      breathingDisruptionsHr:
          breathingDisruptionsHr ?? this.breathingDisruptionsHr,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      wellnessScore: wellnessScore ?? this.wellnessScore,
      cyclePhase: cyclePhase ?? this.cyclePhase,
      computedAtUtc: computedAtUtc ?? this.computedAtUtc,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      source: source ?? this.source,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (tzOffsetMin.present) {
      map['tz_offset_min'] = Variable<int>(tzOffsetMin.value);
    }
    if (restingHrBpm.present) {
      map['resting_hr_bpm'] = Variable<int>(restingHrBpm.value);
    }
    if (hrvRmssdMs.present) {
      map['hrv_rmssd_ms'] = Variable<double>(hrvRmssdMs.value);
    }
    if (hrvSdnnMs.present) {
      map['hrv_sdnn_ms'] = Variable<double>(hrvSdnnMs.value);
    }
    if (restingRespRateBpm.present) {
      map['resting_resp_rate_bpm'] = Variable<double>(restingRespRateBpm.value);
    }
    if (spo2OvernightAvg.present) {
      map['spo2_overnight_avg'] = Variable<double>(spo2OvernightAvg.value);
    }
    if (spo2OvernightMin.present) {
      map['spo2_overnight_min'] = Variable<int>(spo2OvernightMin.value);
    }
    if (systolicMmhg.present) {
      map['systolic_mmhg'] = Variable<int>(systolicMmhg.value);
    }
    if (diastolicMmhg.present) {
      map['diastolic_mmhg'] = Variable<int>(diastolicMmhg.value);
    }
    if (sleepTotalMin.present) {
      map['sleep_total_min'] = Variable<int>(sleepTotalMin.value);
    }
    if (sleepDeepPct.present) {
      map['sleep_deep_pct'] = Variable<double>(sleepDeepPct.value);
    }
    if (sleepRemPct.present) {
      map['sleep_rem_pct'] = Variable<double>(sleepRemPct.value);
    }
    if (sleepLightPct.present) {
      map['sleep_light_pct'] = Variable<double>(sleepLightPct.value);
    }
    if (sleepEfficiencyPct.present) {
      map['sleep_efficiency_pct'] = Variable<double>(sleepEfficiencyPct.value);
    }
    if (bedtimeUtc.present) {
      map['bedtime_utc'] = Variable<int>(bedtimeUtc.value);
    }
    if (wakeUtc.present) {
      map['wake_utc'] = Variable<int>(wakeUtc.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<int>(distanceM.value);
    }
    if (caloriesKcal.present) {
      map['calories_kcal'] = Variable<double>(caloriesKcal.value);
    }
    if (activeMinutes.present) {
      map['active_minutes'] = Variable<int>(activeMinutes.value);
    }
    if (stiffnessIndex.present) {
      map['stiffness_index'] = Variable<double>(stiffnessIndex.value);
    }
    if (augmentationIndex.present) {
      map['augmentation_index'] = Variable<double>(augmentationIndex.value);
    }
    if (strokeVolumeIndex.present) {
      map['stroke_volume_index'] = Variable<double>(strokeVolumeIndex.value);
    }
    if (breathingDisruptionsHr.present) {
      map['breathing_disruptions_hr'] = Variable<double>(
        breathingDisruptionsHr.value,
      );
    }
    if (recoveryScore.present) {
      map['recovery_score'] = Variable<int>(recoveryScore.value);
    }
    if (wellnessScore.present) {
      map['wellness_score'] = Variable<int>(wellnessScore.value);
    }
    if (cyclePhase.present) {
      map['cycle_phase'] = Variable<int>(cyclePhase.value);
    }
    if (computedAtUtc.present) {
      map['computed_at_utc'] = Variable<int>(computedAtUtc.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $DailyMetricsTable.$convertersource.toSql(source.value),
      );
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyMetricsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('localDate: $localDate, ')
          ..write('tzOffsetMin: $tzOffsetMin, ')
          ..write('restingHrBpm: $restingHrBpm, ')
          ..write('hrvRmssdMs: $hrvRmssdMs, ')
          ..write('hrvSdnnMs: $hrvSdnnMs, ')
          ..write('restingRespRateBpm: $restingRespRateBpm, ')
          ..write('spo2OvernightAvg: $spo2OvernightAvg, ')
          ..write('spo2OvernightMin: $spo2OvernightMin, ')
          ..write('systolicMmhg: $systolicMmhg, ')
          ..write('diastolicMmhg: $diastolicMmhg, ')
          ..write('sleepTotalMin: $sleepTotalMin, ')
          ..write('sleepDeepPct: $sleepDeepPct, ')
          ..write('sleepRemPct: $sleepRemPct, ')
          ..write('sleepLightPct: $sleepLightPct, ')
          ..write('sleepEfficiencyPct: $sleepEfficiencyPct, ')
          ..write('bedtimeUtc: $bedtimeUtc, ')
          ..write('wakeUtc: $wakeUtc, ')
          ..write('steps: $steps, ')
          ..write('distanceM: $distanceM, ')
          ..write('caloriesKcal: $caloriesKcal, ')
          ..write('activeMinutes: $activeMinutes, ')
          ..write('stiffnessIndex: $stiffnessIndex, ')
          ..write('augmentationIndex: $augmentationIndex, ')
          ..write('strokeVolumeIndex: $strokeVolumeIndex, ')
          ..write('breathingDisruptionsHr: $breathingDisruptionsHr, ')
          ..write('recoveryScore: $recoveryScore, ')
          ..write('wellnessScore: $wellnessScore, ')
          ..write('cyclePhase: $cyclePhase, ')
          ..write('computedAtUtc: $computedAtUtc, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('source: $source, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SleepSessionsTable extends SleepSessions
    with TableInfo<$SleepSessionsTable, SleepSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedTzOffsetMinMeta =
      const VerificationMeta('capturedTzOffsetMin');
  @override
  late final GeneratedColumn<int> capturedTzOffsetMin = GeneratedColumn<int>(
    'captured_tz_offset_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($SleepSessionsTable.$convertersource);
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endedAtUtcMeta = const VerificationMeta(
    'endedAtUtc',
  );
  @override
  late final GeneratedColumn<int> endedAtUtc = GeneratedColumn<int>(
    'ended_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SleepSessionType, int> type =
      GeneratedColumn<int>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SleepSessionType>($SleepSessionsTable.$convertertype);
  static const VerificationMeta _protocolVersionMeta = const VerificationMeta(
    'protocolVersion',
  );
  @override
  late final GeneratedColumn<int> protocolVersion = GeneratedColumn<int>(
    'protocol_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMinMeta = const VerificationMeta(
    'totalMin',
  );
  @override
  late final GeneratedColumn<int> totalMin = GeneratedColumn<int>(
    'total_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deepMinMeta = const VerificationMeta(
    'deepMin',
  );
  @override
  late final GeneratedColumn<int> deepMin = GeneratedColumn<int>(
    'deep_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lightMinMeta = const VerificationMeta(
    'lightMin',
  );
  @override
  late final GeneratedColumn<int> lightMin = GeneratedColumn<int>(
    'light_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remMinMeta = const VerificationMeta('remMin');
  @override
  late final GeneratedColumn<int> remMin = GeneratedColumn<int>(
    'rem_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _awakeMinMeta = const VerificationMeta(
    'awakeMin',
  );
  @override
  late final GeneratedColumn<int> awakeMin = GeneratedColumn<int>(
    'awake_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverageGapMinMeta = const VerificationMeta(
    'coverageGapMin',
  );
  @override
  late final GeneratedColumn<int> coverageGapMin = GeneratedColumn<int>(
    'coverage_gap_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _efficiencyPctMeta = const VerificationMeta(
    'efficiencyPct',
  );
  @override
  late final GeneratedColumn<double> efficiencyPct = GeneratedColumn<double>(
    'efficiency_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasUnwearedMeta = const VerificationMeta(
    'hasUnweared',
  );
  @override
  late final GeneratedColumn<bool> hasUnweared = GeneratedColumn<bool>(
    'has_unweared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_unweared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    deviceId,
    startedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    endedAtUtc,
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
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SleepSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('captured_tz_offset_min')) {
      context.handle(
        _capturedTzOffsetMinMeta,
        capturedTzOffsetMin.isAcceptableOrUnknown(
          data['captured_tz_offset_min']!,
          _capturedTzOffsetMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capturedTzOffsetMinMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('ended_at_utc')) {
      context.handle(
        _endedAtUtcMeta,
        endedAtUtc.isAcceptableOrUnknown(
          data['ended_at_utc']!,
          _endedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endedAtUtcMeta);
    }
    if (data.containsKey('protocol_version')) {
      context.handle(
        _protocolVersionMeta,
        protocolVersion.isAcceptableOrUnknown(
          data['protocol_version']!,
          _protocolVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_protocolVersionMeta);
    }
    if (data.containsKey('total_min')) {
      context.handle(
        _totalMinMeta,
        totalMin.isAcceptableOrUnknown(data['total_min']!, _totalMinMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMinMeta);
    }
    if (data.containsKey('deep_min')) {
      context.handle(
        _deepMinMeta,
        deepMin.isAcceptableOrUnknown(data['deep_min']!, _deepMinMeta),
      );
    }
    if (data.containsKey('light_min')) {
      context.handle(
        _lightMinMeta,
        lightMin.isAcceptableOrUnknown(data['light_min']!, _lightMinMeta),
      );
    }
    if (data.containsKey('rem_min')) {
      context.handle(
        _remMinMeta,
        remMin.isAcceptableOrUnknown(data['rem_min']!, _remMinMeta),
      );
    }
    if (data.containsKey('awake_min')) {
      context.handle(
        _awakeMinMeta,
        awakeMin.isAcceptableOrUnknown(data['awake_min']!, _awakeMinMeta),
      );
    }
    if (data.containsKey('coverage_gap_min')) {
      context.handle(
        _coverageGapMinMeta,
        coverageGapMin.isAcceptableOrUnknown(
          data['coverage_gap_min']!,
          _coverageGapMinMeta,
        ),
      );
    }
    if (data.containsKey('efficiency_pct')) {
      context.handle(
        _efficiencyPctMeta,
        efficiencyPct.isAcceptableOrUnknown(
          data['efficiency_pct']!,
          _efficiencyPctMeta,
        ),
      );
    }
    if (data.containsKey('has_unweared')) {
      context.handle(
        _hasUnwearedMeta,
        hasUnweared.isAcceptableOrUnknown(
          data['has_unweared']!,
          _hasUnwearedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SleepSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      )!,
      capturedTzOffsetMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_tz_offset_min'],
      )!,
      source: $SleepSessionsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      endedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at_utc'],
      )!,
      type: $SleepSessionsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}type'],
        )!,
      ),
      protocolVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol_version'],
      )!,
      totalMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_min'],
      )!,
      deepMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deep_min'],
      )!,
      lightMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}light_min'],
      )!,
      remMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rem_min'],
      )!,
      awakeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}awake_min'],
      )!,
      coverageGapMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coverage_gap_min'],
      )!,
      efficiencyPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}efficiency_pct'],
      ),
      hasUnweared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unweared'],
      )!,
    );
  }

  @override
  $SleepSessionsTable createAlias(String alias) {
    return $SleepSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
  static JsonTypeConverter2<SleepSessionType, int, int> $convertertype =
      const EnumIndexConverter<SleepSessionType>(SleepSessionType.values);
}

class SleepSession extends DataClass implements Insertable<SleepSession> {
  final String id;
  final String userId;
  final String deviceId;
  final int startedAtUtc;
  final int capturedTzOffsetMin;
  final DataSource source;
  final int? quality;
  final String? algorithmVersion;
  final int createdAtUtc;
  final int? deletedAtUtc;
  final int endedAtUtc;
  final SleepSessionType type;
  final int protocolVersion;
  final int totalMin;
  final int deepMin;
  final int lightMin;
  final int remMin;
  final int awakeMin;
  final int coverageGapMin;
  final double? efficiencyPct;
  final bool hasUnweared;
  const SleepSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.startedAtUtc,
    required this.capturedTzOffsetMin,
    required this.source,
    this.quality,
    this.algorithmVersion,
    required this.createdAtUtc,
    this.deletedAtUtc,
    required this.endedAtUtc,
    required this.type,
    required this.protocolVersion,
    required this.totalMin,
    required this.deepMin,
    required this.lightMin,
    required this.remMin,
    required this.awakeMin,
    required this.coverageGapMin,
    this.efficiencyPct,
    required this.hasUnweared,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['device_id'] = Variable<String>(deviceId);
    map['started_at_utc'] = Variable<int>(startedAtUtc);
    map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin);
    {
      map['source'] = Variable<int>(
        $SleepSessionsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    if (!nullToAbsent || algorithmVersion != null) {
      map['algorithm_version'] = Variable<String>(algorithmVersion);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['ended_at_utc'] = Variable<int>(endedAtUtc);
    {
      map['type'] = Variable<int>(
        $SleepSessionsTable.$convertertype.toSql(type),
      );
    }
    map['protocol_version'] = Variable<int>(protocolVersion);
    map['total_min'] = Variable<int>(totalMin);
    map['deep_min'] = Variable<int>(deepMin);
    map['light_min'] = Variable<int>(lightMin);
    map['rem_min'] = Variable<int>(remMin);
    map['awake_min'] = Variable<int>(awakeMin);
    map['coverage_gap_min'] = Variable<int>(coverageGapMin);
    if (!nullToAbsent || efficiencyPct != null) {
      map['efficiency_pct'] = Variable<double>(efficiencyPct);
    }
    map['has_unweared'] = Variable<bool>(hasUnweared);
    return map;
  }

  SleepSessionsCompanion toCompanion(bool nullToAbsent) {
    return SleepSessionsCompanion(
      id: Value(id),
      userId: Value(userId),
      deviceId: Value(deviceId),
      startedAtUtc: Value(startedAtUtc),
      capturedTzOffsetMin: Value(capturedTzOffsetMin),
      source: Value(source),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      algorithmVersion: algorithmVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(algorithmVersion),
      createdAtUtc: Value(createdAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      endedAtUtc: Value(endedAtUtc),
      type: Value(type),
      protocolVersion: Value(protocolVersion),
      totalMin: Value(totalMin),
      deepMin: Value(deepMin),
      lightMin: Value(lightMin),
      remMin: Value(remMin),
      awakeMin: Value(awakeMin),
      coverageGapMin: Value(coverageGapMin),
      efficiencyPct: efficiencyPct == null && nullToAbsent
          ? const Value.absent()
          : Value(efficiencyPct),
      hasUnweared: Value(hasUnweared),
    );
  }

  factory SleepSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepSession(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      startedAtUtc: serializer.fromJson<int>(json['startedAtUtc']),
      capturedTzOffsetMin: serializer.fromJson<int>(
        json['capturedTzOffsetMin'],
      ),
      source: $SleepSessionsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      quality: serializer.fromJson<int?>(json['quality']),
      algorithmVersion: serializer.fromJson<String?>(json['algorithmVersion']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      endedAtUtc: serializer.fromJson<int>(json['endedAtUtc']),
      type: $SleepSessionsTable.$convertertype.fromJson(
        serializer.fromJson<int>(json['type']),
      ),
      protocolVersion: serializer.fromJson<int>(json['protocolVersion']),
      totalMin: serializer.fromJson<int>(json['totalMin']),
      deepMin: serializer.fromJson<int>(json['deepMin']),
      lightMin: serializer.fromJson<int>(json['lightMin']),
      remMin: serializer.fromJson<int>(json['remMin']),
      awakeMin: serializer.fromJson<int>(json['awakeMin']),
      coverageGapMin: serializer.fromJson<int>(json['coverageGapMin']),
      efficiencyPct: serializer.fromJson<double?>(json['efficiencyPct']),
      hasUnweared: serializer.fromJson<bool>(json['hasUnweared']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'deviceId': serializer.toJson<String>(deviceId),
      'startedAtUtc': serializer.toJson<int>(startedAtUtc),
      'capturedTzOffsetMin': serializer.toJson<int>(capturedTzOffsetMin),
      'source': serializer.toJson<int>(
        $SleepSessionsTable.$convertersource.toJson(source),
      ),
      'quality': serializer.toJson<int?>(quality),
      'algorithmVersion': serializer.toJson<String?>(algorithmVersion),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'endedAtUtc': serializer.toJson<int>(endedAtUtc),
      'type': serializer.toJson<int>(
        $SleepSessionsTable.$convertertype.toJson(type),
      ),
      'protocolVersion': serializer.toJson<int>(protocolVersion),
      'totalMin': serializer.toJson<int>(totalMin),
      'deepMin': serializer.toJson<int>(deepMin),
      'lightMin': serializer.toJson<int>(lightMin),
      'remMin': serializer.toJson<int>(remMin),
      'awakeMin': serializer.toJson<int>(awakeMin),
      'coverageGapMin': serializer.toJson<int>(coverageGapMin),
      'efficiencyPct': serializer.toJson<double?>(efficiencyPct),
      'hasUnweared': serializer.toJson<bool>(hasUnweared),
    };
  }

  SleepSession copyWith({
    String? id,
    String? userId,
    String? deviceId,
    int? startedAtUtc,
    int? capturedTzOffsetMin,
    DataSource? source,
    Value<int?> quality = const Value.absent(),
    Value<String?> algorithmVersion = const Value.absent(),
    int? createdAtUtc,
    Value<int?> deletedAtUtc = const Value.absent(),
    int? endedAtUtc,
    SleepSessionType? type,
    int? protocolVersion,
    int? totalMin,
    int? deepMin,
    int? lightMin,
    int? remMin,
    int? awakeMin,
    int? coverageGapMin,
    Value<double?> efficiencyPct = const Value.absent(),
    bool? hasUnweared,
  }) => SleepSession(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    deviceId: deviceId ?? this.deviceId,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
    source: source ?? this.source,
    quality: quality.present ? quality.value : this.quality,
    algorithmVersion: algorithmVersion.present
        ? algorithmVersion.value
        : this.algorithmVersion,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    endedAtUtc: endedAtUtc ?? this.endedAtUtc,
    type: type ?? this.type,
    protocolVersion: protocolVersion ?? this.protocolVersion,
    totalMin: totalMin ?? this.totalMin,
    deepMin: deepMin ?? this.deepMin,
    lightMin: lightMin ?? this.lightMin,
    remMin: remMin ?? this.remMin,
    awakeMin: awakeMin ?? this.awakeMin,
    coverageGapMin: coverageGapMin ?? this.coverageGapMin,
    efficiencyPct: efficiencyPct.present
        ? efficiencyPct.value
        : this.efficiencyPct,
    hasUnweared: hasUnweared ?? this.hasUnweared,
  );
  SleepSession copyWithCompanion(SleepSessionsCompanion data) {
    return SleepSession(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      capturedTzOffsetMin: data.capturedTzOffsetMin.present
          ? data.capturedTzOffsetMin.value
          : this.capturedTzOffsetMin,
      source: data.source.present ? data.source.value : this.source,
      quality: data.quality.present ? data.quality.value : this.quality,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      endedAtUtc: data.endedAtUtc.present
          ? data.endedAtUtc.value
          : this.endedAtUtc,
      type: data.type.present ? data.type.value : this.type,
      protocolVersion: data.protocolVersion.present
          ? data.protocolVersion.value
          : this.protocolVersion,
      totalMin: data.totalMin.present ? data.totalMin.value : this.totalMin,
      deepMin: data.deepMin.present ? data.deepMin.value : this.deepMin,
      lightMin: data.lightMin.present ? data.lightMin.value : this.lightMin,
      remMin: data.remMin.present ? data.remMin.value : this.remMin,
      awakeMin: data.awakeMin.present ? data.awakeMin.value : this.awakeMin,
      coverageGapMin: data.coverageGapMin.present
          ? data.coverageGapMin.value
          : this.coverageGapMin,
      efficiencyPct: data.efficiencyPct.present
          ? data.efficiencyPct.value
          : this.efficiencyPct,
      hasUnweared: data.hasUnweared.present
          ? data.hasUnweared.value
          : this.hasUnweared,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepSession(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('type: $type, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('totalMin: $totalMin, ')
          ..write('deepMin: $deepMin, ')
          ..write('lightMin: $lightMin, ')
          ..write('remMin: $remMin, ')
          ..write('awakeMin: $awakeMin, ')
          ..write('coverageGapMin: $coverageGapMin, ')
          ..write('efficiencyPct: $efficiencyPct, ')
          ..write('hasUnweared: $hasUnweared')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    userId,
    deviceId,
    startedAtUtc,
    capturedTzOffsetMin,
    source,
    quality,
    algorithmVersion,
    createdAtUtc,
    deletedAtUtc,
    endedAtUtc,
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
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepSession &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.deviceId == this.deviceId &&
          other.startedAtUtc == this.startedAtUtc &&
          other.capturedTzOffsetMin == this.capturedTzOffsetMin &&
          other.source == this.source &&
          other.quality == this.quality &&
          other.algorithmVersion == this.algorithmVersion &&
          other.createdAtUtc == this.createdAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.endedAtUtc == this.endedAtUtc &&
          other.type == this.type &&
          other.protocolVersion == this.protocolVersion &&
          other.totalMin == this.totalMin &&
          other.deepMin == this.deepMin &&
          other.lightMin == this.lightMin &&
          other.remMin == this.remMin &&
          other.awakeMin == this.awakeMin &&
          other.coverageGapMin == this.coverageGapMin &&
          other.efficiencyPct == this.efficiencyPct &&
          other.hasUnweared == this.hasUnweared);
}

class SleepSessionsCompanion extends UpdateCompanion<SleepSession> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> deviceId;
  final Value<int> startedAtUtc;
  final Value<int> capturedTzOffsetMin;
  final Value<DataSource> source;
  final Value<int?> quality;
  final Value<String?> algorithmVersion;
  final Value<int> createdAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<int> endedAtUtc;
  final Value<SleepSessionType> type;
  final Value<int> protocolVersion;
  final Value<int> totalMin;
  final Value<int> deepMin;
  final Value<int> lightMin;
  final Value<int> remMin;
  final Value<int> awakeMin;
  final Value<int> coverageGapMin;
  final Value<double?> efficiencyPct;
  final Value<bool> hasUnweared;
  final Value<int> rowid;
  const SleepSessionsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.capturedTzOffsetMin = const Value.absent(),
    this.source = const Value.absent(),
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.endedAtUtc = const Value.absent(),
    this.type = const Value.absent(),
    this.protocolVersion = const Value.absent(),
    this.totalMin = const Value.absent(),
    this.deepMin = const Value.absent(),
    this.lightMin = const Value.absent(),
    this.remMin = const Value.absent(),
    this.awakeMin = const Value.absent(),
    this.coverageGapMin = const Value.absent(),
    this.efficiencyPct = const Value.absent(),
    this.hasUnweared = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SleepSessionsCompanion.insert({
    required String id,
    required String userId,
    required String deviceId,
    required int startedAtUtc,
    required int capturedTzOffsetMin,
    required DataSource source,
    this.quality = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    required int createdAtUtc,
    this.deletedAtUtc = const Value.absent(),
    required int endedAtUtc,
    required SleepSessionType type,
    required int protocolVersion,
    required int totalMin,
    this.deepMin = const Value.absent(),
    this.lightMin = const Value.absent(),
    this.remMin = const Value.absent(),
    this.awakeMin = const Value.absent(),
    this.coverageGapMin = const Value.absent(),
    this.efficiencyPct = const Value.absent(),
    this.hasUnweared = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       deviceId = Value(deviceId),
       startedAtUtc = Value(startedAtUtc),
       capturedTzOffsetMin = Value(capturedTzOffsetMin),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc),
       endedAtUtc = Value(endedAtUtc),
       type = Value(type),
       protocolVersion = Value(protocolVersion),
       totalMin = Value(totalMin);
  static Insertable<SleepSession> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? deviceId,
    Expression<int>? startedAtUtc,
    Expression<int>? capturedTzOffsetMin,
    Expression<int>? source,
    Expression<int>? quality,
    Expression<String>? algorithmVersion,
    Expression<int>? createdAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<int>? endedAtUtc,
    Expression<int>? type,
    Expression<int>? protocolVersion,
    Expression<int>? totalMin,
    Expression<int>? deepMin,
    Expression<int>? lightMin,
    Expression<int>? remMin,
    Expression<int>? awakeMin,
    Expression<int>? coverageGapMin,
    Expression<double>? efficiencyPct,
    Expression<bool>? hasUnweared,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (deviceId != null) 'device_id': deviceId,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (capturedTzOffsetMin != null)
        'captured_tz_offset_min': capturedTzOffsetMin,
      if (source != null) 'source': source,
      if (quality != null) 'quality': quality,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (endedAtUtc != null) 'ended_at_utc': endedAtUtc,
      if (type != null) 'type': type,
      if (protocolVersion != null) 'protocol_version': protocolVersion,
      if (totalMin != null) 'total_min': totalMin,
      if (deepMin != null) 'deep_min': deepMin,
      if (lightMin != null) 'light_min': lightMin,
      if (remMin != null) 'rem_min': remMin,
      if (awakeMin != null) 'awake_min': awakeMin,
      if (coverageGapMin != null) 'coverage_gap_min': coverageGapMin,
      if (efficiencyPct != null) 'efficiency_pct': efficiencyPct,
      if (hasUnweared != null) 'has_unweared': hasUnweared,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SleepSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? deviceId,
    Value<int>? startedAtUtc,
    Value<int>? capturedTzOffsetMin,
    Value<DataSource>? source,
    Value<int?>? quality,
    Value<String?>? algorithmVersion,
    Value<int>? createdAtUtc,
    Value<int?>? deletedAtUtc,
    Value<int>? endedAtUtc,
    Value<SleepSessionType>? type,
    Value<int>? protocolVersion,
    Value<int>? totalMin,
    Value<int>? deepMin,
    Value<int>? lightMin,
    Value<int>? remMin,
    Value<int>? awakeMin,
    Value<int>? coverageGapMin,
    Value<double?>? efficiencyPct,
    Value<bool>? hasUnweared,
    Value<int>? rowid,
  }) {
    return SleepSessionsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      capturedTzOffsetMin: capturedTzOffsetMin ?? this.capturedTzOffsetMin,
      source: source ?? this.source,
      quality: quality ?? this.quality,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      type: type ?? this.type,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      totalMin: totalMin ?? this.totalMin,
      deepMin: deepMin ?? this.deepMin,
      lightMin: lightMin ?? this.lightMin,
      remMin: remMin ?? this.remMin,
      awakeMin: awakeMin ?? this.awakeMin,
      coverageGapMin: coverageGapMin ?? this.coverageGapMin,
      efficiencyPct: efficiencyPct ?? this.efficiencyPct,
      hasUnweared: hasUnweared ?? this.hasUnweared,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (capturedTzOffsetMin.present) {
      map['captured_tz_offset_min'] = Variable<int>(capturedTzOffsetMin.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $SleepSessionsTable.$convertersource.toSql(source.value),
      );
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (endedAtUtc.present) {
      map['ended_at_utc'] = Variable<int>(endedAtUtc.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(
        $SleepSessionsTable.$convertertype.toSql(type.value),
      );
    }
    if (protocolVersion.present) {
      map['protocol_version'] = Variable<int>(protocolVersion.value);
    }
    if (totalMin.present) {
      map['total_min'] = Variable<int>(totalMin.value);
    }
    if (deepMin.present) {
      map['deep_min'] = Variable<int>(deepMin.value);
    }
    if (lightMin.present) {
      map['light_min'] = Variable<int>(lightMin.value);
    }
    if (remMin.present) {
      map['rem_min'] = Variable<int>(remMin.value);
    }
    if (awakeMin.present) {
      map['awake_min'] = Variable<int>(awakeMin.value);
    }
    if (coverageGapMin.present) {
      map['coverage_gap_min'] = Variable<int>(coverageGapMin.value);
    }
    if (efficiencyPct.present) {
      map['efficiency_pct'] = Variable<double>(efficiencyPct.value);
    }
    if (hasUnweared.present) {
      map['has_unweared'] = Variable<bool>(hasUnweared.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('deviceId: $deviceId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('capturedTzOffsetMin: $capturedTzOffsetMin, ')
          ..write('source: $source, ')
          ..write('quality: $quality, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('endedAtUtc: $endedAtUtc, ')
          ..write('type: $type, ')
          ..write('protocolVersion: $protocolVersion, ')
          ..write('totalMin: $totalMin, ')
          ..write('deepMin: $deepMin, ')
          ..write('lightMin: $lightMin, ')
          ..write('remMin: $remMin, ')
          ..write('awakeMin: $awakeMin, ')
          ..write('coverageGapMin: $coverageGapMin, ')
          ..write('efficiencyPct: $efficiencyPct, ')
          ..write('hasUnweared: $hasUnweared, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SleepEpochsTable extends SleepEpochs
    with TableInfo<$SleepEpochsTable, SleepEpoch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepEpochsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sleep_sessions (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinMeta = const VerificationMeta(
    'durationMin',
  );
  @override
  late final GeneratedColumn<int> durationMin = GeneratedColumn<int>(
    'duration_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SleepStage, int> stage =
      GeneratedColumn<int>(
        'stage',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<SleepStage>($SleepEpochsTable.$converterstage);
  @override
  late final GeneratedColumnWithTypeConverter<DataSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DataSource>($SleepEpochsTable.$convertersource);
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    userId,
    startedAtUtc,
    durationMin,
    stage,
    source,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_epochs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SleepEpoch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('duration_min')) {
      context.handle(
        _durationMinMeta,
        durationMin.isAcceptableOrUnknown(
          data['duration_min']!,
          _durationMinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SleepEpoch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepEpoch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      )!,
      durationMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_min'],
      )!,
      stage: $SleepEpochsTable.$converterstage.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}stage'],
        )!,
      ),
      source: $SleepEpochsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $SleepEpochsTable createAlias(String alias) {
    return $SleepEpochsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SleepStage, int, int> $converterstage =
      const EnumIndexConverter<SleepStage>(SleepStage.values);
  static JsonTypeConverter2<DataSource, int, int> $convertersource =
      const EnumIndexConverter<DataSource>(DataSource.values);
}

class SleepEpoch extends DataClass implements Insertable<SleepEpoch> {
  final String id;
  final String sessionId;
  final String userId;
  final int startedAtUtc;
  final int durationMin;
  final SleepStage stage;
  final DataSource source;
  final int createdAtUtc;
  const SleepEpoch({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.startedAtUtc,
    required this.durationMin,
    required this.stage,
    required this.source,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['user_id'] = Variable<String>(userId);
    map['started_at_utc'] = Variable<int>(startedAtUtc);
    map['duration_min'] = Variable<int>(durationMin);
    {
      map['stage'] = Variable<int>(
        $SleepEpochsTable.$converterstage.toSql(stage),
      );
    }
    {
      map['source'] = Variable<int>(
        $SleepEpochsTable.$convertersource.toSql(source),
      );
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    return map;
  }

  SleepEpochsCompanion toCompanion(bool nullToAbsent) {
    return SleepEpochsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      userId: Value(userId),
      startedAtUtc: Value(startedAtUtc),
      durationMin: Value(durationMin),
      stage: Value(stage),
      source: Value(source),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory SleepEpoch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepEpoch(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      userId: serializer.fromJson<String>(json['userId']),
      startedAtUtc: serializer.fromJson<int>(json['startedAtUtc']),
      durationMin: serializer.fromJson<int>(json['durationMin']),
      stage: $SleepEpochsTable.$converterstage.fromJson(
        serializer.fromJson<int>(json['stage']),
      ),
      source: $SleepEpochsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'userId': serializer.toJson<String>(userId),
      'startedAtUtc': serializer.toJson<int>(startedAtUtc),
      'durationMin': serializer.toJson<int>(durationMin),
      'stage': serializer.toJson<int>(
        $SleepEpochsTable.$converterstage.toJson(stage),
      ),
      'source': serializer.toJson<int>(
        $SleepEpochsTable.$convertersource.toJson(source),
      ),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
    };
  }

  SleepEpoch copyWith({
    String? id,
    String? sessionId,
    String? userId,
    int? startedAtUtc,
    int? durationMin,
    SleepStage? stage,
    DataSource? source,
    int? createdAtUtc,
  }) => SleepEpoch(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    userId: userId ?? this.userId,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    durationMin: durationMin ?? this.durationMin,
    stage: stage ?? this.stage,
    source: source ?? this.source,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  SleepEpoch copyWithCompanion(SleepEpochsCompanion data) {
    return SleepEpoch(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      userId: data.userId.present ? data.userId.value : this.userId,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      durationMin: data.durationMin.present
          ? data.durationMin.value
          : this.durationMin,
      stage: data.stage.present ? data.stage.value : this.stage,
      source: data.source.present ? data.source.value : this.source,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepEpoch(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('durationMin: $durationMin, ')
          ..write('stage: $stage, ')
          ..write('source: $source, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    userId,
    startedAtUtc,
    durationMin,
    stage,
    source,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepEpoch &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.userId == this.userId &&
          other.startedAtUtc == this.startedAtUtc &&
          other.durationMin == this.durationMin &&
          other.stage == this.stage &&
          other.source == this.source &&
          other.createdAtUtc == this.createdAtUtc);
}

class SleepEpochsCompanion extends UpdateCompanion<SleepEpoch> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> userId;
  final Value<int> startedAtUtc;
  final Value<int> durationMin;
  final Value<SleepStage> stage;
  final Value<DataSource> source;
  final Value<int> createdAtUtc;
  final Value<int> rowid;
  const SleepEpochsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.userId = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.durationMin = const Value.absent(),
    this.stage = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SleepEpochsCompanion.insert({
    required String id,
    required String sessionId,
    required String userId,
    required int startedAtUtc,
    required int durationMin,
    required SleepStage stage,
    required DataSource source,
    required int createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       userId = Value(userId),
       startedAtUtc = Value(startedAtUtc),
       durationMin = Value(durationMin),
       stage = Value(stage),
       source = Value(source),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<SleepEpoch> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? userId,
    Expression<int>? startedAtUtc,
    Expression<int>? durationMin,
    Expression<int>? stage,
    Expression<int>? source,
    Expression<int>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (userId != null) 'user_id': userId,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (durationMin != null) 'duration_min': durationMin,
      if (stage != null) 'stage': stage,
      if (source != null) 'source': source,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SleepEpochsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? userId,
    Value<int>? startedAtUtc,
    Value<int>? durationMin,
    Value<SleepStage>? stage,
    Value<DataSource>? source,
    Value<int>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return SleepEpochsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      durationMin: durationMin ?? this.durationMin,
      stage: stage ?? this.stage,
      source: source ?? this.source,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (durationMin.present) {
      map['duration_min'] = Variable<int>(durationMin.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(
        $SleepEpochsTable.$converterstage.toSql(stage.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $SleepEpochsTable.$convertersource.toSql(source.value),
      );
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepEpochsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('userId: $userId, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('durationMin: $durationMin, ')
          ..write('stage: $stage, ')
          ..write('source: $source, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BaselinesTable extends Baselines
    with TableInfo<$BaselinesTable, Baseline> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BaselinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES users (id)',
    ),
  );
  static const VerificationMeta _metricKeyMeta = const VerificationMeta(
    'metricKey',
  );
  @override
  late final GeneratedColumn<String> metricKey = GeneratedColumn<String>(
    'metric_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowDaysMeta = const VerificationMeta(
    'windowDays',
  );
  @override
  late final GeneratedColumn<int> windowDays = GeneratedColumn<int>(
    'window_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _computedForDateMeta = const VerificationMeta(
    'computedForDate',
  );
  @override
  late final GeneratedColumn<String> computedForDate = GeneratedColumn<String>(
    'computed_for_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meanValueMeta = const VerificationMeta(
    'meanValue',
  );
  @override
  late final GeneratedColumn<double> meanValue = GeneratedColumn<double>(
    'mean_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stddevValueMeta = const VerificationMeta(
    'stddevValue',
  );
  @override
  late final GeneratedColumn<double> stddevValue = GeneratedColumn<double>(
    'stddev_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleCountMeta = const VerificationMeta(
    'sampleCount',
  );
  @override
  late final GeneratedColumn<int> sampleCount = GeneratedColumn<int>(
    'sample_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _computedAtUtcMeta = const VerificationMeta(
    'computedAtUtc',
  );
  @override
  late final GeneratedColumn<int> computedAtUtc = GeneratedColumn<int>(
    'computed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<String> algorithmVersion = GeneratedColumn<String>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    metricKey,
    windowDays,
    computedForDate,
    meanValue,
    stddevValue,
    sampleCount,
    computedAtUtc,
    algorithmVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'baselines';
  @override
  VerificationContext validateIntegrity(
    Insertable<Baseline> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('metric_key')) {
      context.handle(
        _metricKeyMeta,
        metricKey.isAcceptableOrUnknown(data['metric_key']!, _metricKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_metricKeyMeta);
    }
    if (data.containsKey('window_days')) {
      context.handle(
        _windowDaysMeta,
        windowDays.isAcceptableOrUnknown(data['window_days']!, _windowDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_windowDaysMeta);
    }
    if (data.containsKey('computed_for_date')) {
      context.handle(
        _computedForDateMeta,
        computedForDate.isAcceptableOrUnknown(
          data['computed_for_date']!,
          _computedForDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_computedForDateMeta);
    }
    if (data.containsKey('mean_value')) {
      context.handle(
        _meanValueMeta,
        meanValue.isAcceptableOrUnknown(data['mean_value']!, _meanValueMeta),
      );
    } else if (isInserting) {
      context.missing(_meanValueMeta);
    }
    if (data.containsKey('stddev_value')) {
      context.handle(
        _stddevValueMeta,
        stddevValue.isAcceptableOrUnknown(
          data['stddev_value']!,
          _stddevValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stddevValueMeta);
    }
    if (data.containsKey('sample_count')) {
      context.handle(
        _sampleCountMeta,
        sampleCount.isAcceptableOrUnknown(
          data['sample_count']!,
          _sampleCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sampleCountMeta);
    }
    if (data.containsKey('computed_at_utc')) {
      context.handle(
        _computedAtUtcMeta,
        computedAtUtc.isAcceptableOrUnknown(
          data['computed_at_utc']!,
          _computedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_computedAtUtcMeta);
    }
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Baseline map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Baseline(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      metricKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_key'],
      )!,
      windowDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_days'],
      )!,
      computedForDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}computed_for_date'],
      )!,
      meanValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mean_value'],
      )!,
      stddevValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stddev_value'],
      )!,
      sampleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_count'],
      )!,
      computedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}computed_at_utc'],
      )!,
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}algorithm_version'],
      )!,
    );
  }

  @override
  $BaselinesTable createAlias(String alias) {
    return $BaselinesTable(attachedDatabase, alias);
  }
}

class Baseline extends DataClass implements Insertable<Baseline> {
  final String id;
  final String userId;
  final String metricKey;
  final int windowDays;
  final String computedForDate;
  final double meanValue;
  final double stddevValue;
  final int sampleCount;
  final int computedAtUtc;
  final String algorithmVersion;
  const Baseline({
    required this.id,
    required this.userId,
    required this.metricKey,
    required this.windowDays,
    required this.computedForDate,
    required this.meanValue,
    required this.stddevValue,
    required this.sampleCount,
    required this.computedAtUtc,
    required this.algorithmVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['metric_key'] = Variable<String>(metricKey);
    map['window_days'] = Variable<int>(windowDays);
    map['computed_for_date'] = Variable<String>(computedForDate);
    map['mean_value'] = Variable<double>(meanValue);
    map['stddev_value'] = Variable<double>(stddevValue);
    map['sample_count'] = Variable<int>(sampleCount);
    map['computed_at_utc'] = Variable<int>(computedAtUtc);
    map['algorithm_version'] = Variable<String>(algorithmVersion);
    return map;
  }

  BaselinesCompanion toCompanion(bool nullToAbsent) {
    return BaselinesCompanion(
      id: Value(id),
      userId: Value(userId),
      metricKey: Value(metricKey),
      windowDays: Value(windowDays),
      computedForDate: Value(computedForDate),
      meanValue: Value(meanValue),
      stddevValue: Value(stddevValue),
      sampleCount: Value(sampleCount),
      computedAtUtc: Value(computedAtUtc),
      algorithmVersion: Value(algorithmVersion),
    );
  }

  factory Baseline.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Baseline(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      metricKey: serializer.fromJson<String>(json['metricKey']),
      windowDays: serializer.fromJson<int>(json['windowDays']),
      computedForDate: serializer.fromJson<String>(json['computedForDate']),
      meanValue: serializer.fromJson<double>(json['meanValue']),
      stddevValue: serializer.fromJson<double>(json['stddevValue']),
      sampleCount: serializer.fromJson<int>(json['sampleCount']),
      computedAtUtc: serializer.fromJson<int>(json['computedAtUtc']),
      algorithmVersion: serializer.fromJson<String>(json['algorithmVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'metricKey': serializer.toJson<String>(metricKey),
      'windowDays': serializer.toJson<int>(windowDays),
      'computedForDate': serializer.toJson<String>(computedForDate),
      'meanValue': serializer.toJson<double>(meanValue),
      'stddevValue': serializer.toJson<double>(stddevValue),
      'sampleCount': serializer.toJson<int>(sampleCount),
      'computedAtUtc': serializer.toJson<int>(computedAtUtc),
      'algorithmVersion': serializer.toJson<String>(algorithmVersion),
    };
  }

  Baseline copyWith({
    String? id,
    String? userId,
    String? metricKey,
    int? windowDays,
    String? computedForDate,
    double? meanValue,
    double? stddevValue,
    int? sampleCount,
    int? computedAtUtc,
    String? algorithmVersion,
  }) => Baseline(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    metricKey: metricKey ?? this.metricKey,
    windowDays: windowDays ?? this.windowDays,
    computedForDate: computedForDate ?? this.computedForDate,
    meanValue: meanValue ?? this.meanValue,
    stddevValue: stddevValue ?? this.stddevValue,
    sampleCount: sampleCount ?? this.sampleCount,
    computedAtUtc: computedAtUtc ?? this.computedAtUtc,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
  );
  Baseline copyWithCompanion(BaselinesCompanion data) {
    return Baseline(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      metricKey: data.metricKey.present ? data.metricKey.value : this.metricKey,
      windowDays: data.windowDays.present
          ? data.windowDays.value
          : this.windowDays,
      computedForDate: data.computedForDate.present
          ? data.computedForDate.value
          : this.computedForDate,
      meanValue: data.meanValue.present ? data.meanValue.value : this.meanValue,
      stddevValue: data.stddevValue.present
          ? data.stddevValue.value
          : this.stddevValue,
      sampleCount: data.sampleCount.present
          ? data.sampleCount.value
          : this.sampleCount,
      computedAtUtc: data.computedAtUtc.present
          ? data.computedAtUtc.value
          : this.computedAtUtc,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Baseline(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('metricKey: $metricKey, ')
          ..write('windowDays: $windowDays, ')
          ..write('computedForDate: $computedForDate, ')
          ..write('meanValue: $meanValue, ')
          ..write('stddevValue: $stddevValue, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('computedAtUtc: $computedAtUtc, ')
          ..write('algorithmVersion: $algorithmVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    metricKey,
    windowDays,
    computedForDate,
    meanValue,
    stddevValue,
    sampleCount,
    computedAtUtc,
    algorithmVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Baseline &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.metricKey == this.metricKey &&
          other.windowDays == this.windowDays &&
          other.computedForDate == this.computedForDate &&
          other.meanValue == this.meanValue &&
          other.stddevValue == this.stddevValue &&
          other.sampleCount == this.sampleCount &&
          other.computedAtUtc == this.computedAtUtc &&
          other.algorithmVersion == this.algorithmVersion);
}

class BaselinesCompanion extends UpdateCompanion<Baseline> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> metricKey;
  final Value<int> windowDays;
  final Value<String> computedForDate;
  final Value<double> meanValue;
  final Value<double> stddevValue;
  final Value<int> sampleCount;
  final Value<int> computedAtUtc;
  final Value<String> algorithmVersion;
  final Value<int> rowid;
  const BaselinesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.metricKey = const Value.absent(),
    this.windowDays = const Value.absent(),
    this.computedForDate = const Value.absent(),
    this.meanValue = const Value.absent(),
    this.stddevValue = const Value.absent(),
    this.sampleCount = const Value.absent(),
    this.computedAtUtc = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BaselinesCompanion.insert({
    required String id,
    required String userId,
    required String metricKey,
    required int windowDays,
    required String computedForDate,
    required double meanValue,
    required double stddevValue,
    required int sampleCount,
    required int computedAtUtc,
    required String algorithmVersion,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       metricKey = Value(metricKey),
       windowDays = Value(windowDays),
       computedForDate = Value(computedForDate),
       meanValue = Value(meanValue),
       stddevValue = Value(stddevValue),
       sampleCount = Value(sampleCount),
       computedAtUtc = Value(computedAtUtc),
       algorithmVersion = Value(algorithmVersion);
  static Insertable<Baseline> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? metricKey,
    Expression<int>? windowDays,
    Expression<String>? computedForDate,
    Expression<double>? meanValue,
    Expression<double>? stddevValue,
    Expression<int>? sampleCount,
    Expression<int>? computedAtUtc,
    Expression<String>? algorithmVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (metricKey != null) 'metric_key': metricKey,
      if (windowDays != null) 'window_days': windowDays,
      if (computedForDate != null) 'computed_for_date': computedForDate,
      if (meanValue != null) 'mean_value': meanValue,
      if (stddevValue != null) 'stddev_value': stddevValue,
      if (sampleCount != null) 'sample_count': sampleCount,
      if (computedAtUtc != null) 'computed_at_utc': computedAtUtc,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BaselinesCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? metricKey,
    Value<int>? windowDays,
    Value<String>? computedForDate,
    Value<double>? meanValue,
    Value<double>? stddevValue,
    Value<int>? sampleCount,
    Value<int>? computedAtUtc,
    Value<String>? algorithmVersion,
    Value<int>? rowid,
  }) {
    return BaselinesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      metricKey: metricKey ?? this.metricKey,
      windowDays: windowDays ?? this.windowDays,
      computedForDate: computedForDate ?? this.computedForDate,
      meanValue: meanValue ?? this.meanValue,
      stddevValue: stddevValue ?? this.stddevValue,
      sampleCount: sampleCount ?? this.sampleCount,
      computedAtUtc: computedAtUtc ?? this.computedAtUtc,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (metricKey.present) {
      map['metric_key'] = Variable<String>(metricKey.value);
    }
    if (windowDays.present) {
      map['window_days'] = Variable<int>(windowDays.value);
    }
    if (computedForDate.present) {
      map['computed_for_date'] = Variable<String>(computedForDate.value);
    }
    if (meanValue.present) {
      map['mean_value'] = Variable<double>(meanValue.value);
    }
    if (stddevValue.present) {
      map['stddev_value'] = Variable<double>(stddevValue.value);
    }
    if (sampleCount.present) {
      map['sample_count'] = Variable<int>(sampleCount.value);
    }
    if (computedAtUtc.present) {
      map['computed_at_utc'] = Variable<int>(computedAtUtc.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<String>(algorithmVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BaselinesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('metricKey: $metricKey, ')
          ..write('windowDays: $windowDays, ')
          ..write('computedForDate: $computedForDate, ')
          ..write('meanValue: $meanValue, ')
          ..write('stddevValue: $stddevValue, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('computedAtUtc: $computedAtUtc, ')
          ..write('algorithmVersion: $algorithmVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _metricKeyMeta = const VerificationMeta(
    'metricKey',
  );
  @override
  late final GeneratedColumn<String> metricKey = GeneratedColumn<String>(
    'metric_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSuccessfulSyncUtcMeta =
      const VerificationMeta('lastSuccessfulSyncUtc');
  @override
  late final GeneratedColumn<int> lastSuccessfulSyncUtc = GeneratedColumn<int>(
    'last_successful_sync_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAttemptedSyncUtcMeta =
      const VerificationMeta('lastAttemptedSyncUtc');
  @override
  late final GeneratedColumn<int> lastAttemptedSyncUtc = GeneratedColumn<int>(
    'last_attempted_sync_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncErrorMeta = const VerificationMeta(
    'lastSyncError',
  );
  @override
  late final GeneratedColumn<String> lastSyncError = GeneratedColumn<String>(
    'last_sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedDayIndexMeta =
      const VerificationMeta('lastSyncedDayIndex');
  @override
  late final GeneratedColumn<int> lastSyncedDayIndex = GeneratedColumn<int>(
    'last_synced_day_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesSyncedLifetimeMeta =
      const VerificationMeta('bytesSyncedLifetime');
  @override
  late final GeneratedColumn<int> bytesSyncedLifetime = GeneratedColumn<int>(
    'bytes_synced_lifetime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    metricKey,
    lastSuccessfulSyncUtc,
    lastAttemptedSyncUtc,
    lastSyncError,
    lastSyncedDayIndex,
    bytesSyncedLifetime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('metric_key')) {
      context.handle(
        _metricKeyMeta,
        metricKey.isAcceptableOrUnknown(data['metric_key']!, _metricKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_metricKeyMeta);
    }
    if (data.containsKey('last_successful_sync_utc')) {
      context.handle(
        _lastSuccessfulSyncUtcMeta,
        lastSuccessfulSyncUtc.isAcceptableOrUnknown(
          data['last_successful_sync_utc']!,
          _lastSuccessfulSyncUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_attempted_sync_utc')) {
      context.handle(
        _lastAttemptedSyncUtcMeta,
        lastAttemptedSyncUtc.isAcceptableOrUnknown(
          data['last_attempted_sync_utc']!,
          _lastAttemptedSyncUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_error')) {
      context.handle(
        _lastSyncErrorMeta,
        lastSyncError.isAcceptableOrUnknown(
          data['last_sync_error']!,
          _lastSyncErrorMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_day_index')) {
      context.handle(
        _lastSyncedDayIndexMeta,
        lastSyncedDayIndex.isAcceptableOrUnknown(
          data['last_synced_day_index']!,
          _lastSyncedDayIndexMeta,
        ),
      );
    }
    if (data.containsKey('bytes_synced_lifetime')) {
      context.handle(
        _bytesSyncedLifetimeMeta,
        bytesSyncedLifetime.isAcceptableOrUnknown(
          data['bytes_synced_lifetime']!,
          _bytesSyncedLifetimeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      metricKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_key'],
      )!,
      lastSuccessfulSyncUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_successful_sync_utc'],
      ),
      lastAttemptedSyncUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_attempted_sync_utc'],
      ),
      lastSyncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_sync_error'],
      ),
      lastSyncedDayIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_day_index'],
      ),
      bytesSyncedLifetime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_synced_lifetime'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String id;
  final String deviceId;
  final String metricKey;
  final int? lastSuccessfulSyncUtc;
  final int? lastAttemptedSyncUtc;
  final String? lastSyncError;
  final int? lastSyncedDayIndex;
  final int bytesSyncedLifetime;
  const SyncStateData({
    required this.id,
    required this.deviceId,
    required this.metricKey,
    this.lastSuccessfulSyncUtc,
    this.lastAttemptedSyncUtc,
    this.lastSyncError,
    this.lastSyncedDayIndex,
    required this.bytesSyncedLifetime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['metric_key'] = Variable<String>(metricKey);
    if (!nullToAbsent || lastSuccessfulSyncUtc != null) {
      map['last_successful_sync_utc'] = Variable<int>(lastSuccessfulSyncUtc);
    }
    if (!nullToAbsent || lastAttemptedSyncUtc != null) {
      map['last_attempted_sync_utc'] = Variable<int>(lastAttemptedSyncUtc);
    }
    if (!nullToAbsent || lastSyncError != null) {
      map['last_sync_error'] = Variable<String>(lastSyncError);
    }
    if (!nullToAbsent || lastSyncedDayIndex != null) {
      map['last_synced_day_index'] = Variable<int>(lastSyncedDayIndex);
    }
    map['bytes_synced_lifetime'] = Variable<int>(bytesSyncedLifetime);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      metricKey: Value(metricKey),
      lastSuccessfulSyncUtc: lastSuccessfulSyncUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulSyncUtc),
      lastAttemptedSyncUtc: lastAttemptedSyncUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptedSyncUtc),
      lastSyncError: lastSyncError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncError),
      lastSyncedDayIndex: lastSyncedDayIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedDayIndex),
      bytesSyncedLifetime: Value(bytesSyncedLifetime),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      metricKey: serializer.fromJson<String>(json['metricKey']),
      lastSuccessfulSyncUtc: serializer.fromJson<int?>(
        json['lastSuccessfulSyncUtc'],
      ),
      lastAttemptedSyncUtc: serializer.fromJson<int?>(
        json['lastAttemptedSyncUtc'],
      ),
      lastSyncError: serializer.fromJson<String?>(json['lastSyncError']),
      lastSyncedDayIndex: serializer.fromJson<int?>(json['lastSyncedDayIndex']),
      bytesSyncedLifetime: serializer.fromJson<int>(
        json['bytesSyncedLifetime'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'metricKey': serializer.toJson<String>(metricKey),
      'lastSuccessfulSyncUtc': serializer.toJson<int?>(lastSuccessfulSyncUtc),
      'lastAttemptedSyncUtc': serializer.toJson<int?>(lastAttemptedSyncUtc),
      'lastSyncError': serializer.toJson<String?>(lastSyncError),
      'lastSyncedDayIndex': serializer.toJson<int?>(lastSyncedDayIndex),
      'bytesSyncedLifetime': serializer.toJson<int>(bytesSyncedLifetime),
    };
  }

  SyncStateData copyWith({
    String? id,
    String? deviceId,
    String? metricKey,
    Value<int?> lastSuccessfulSyncUtc = const Value.absent(),
    Value<int?> lastAttemptedSyncUtc = const Value.absent(),
    Value<String?> lastSyncError = const Value.absent(),
    Value<int?> lastSyncedDayIndex = const Value.absent(),
    int? bytesSyncedLifetime,
  }) => SyncStateData(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    metricKey: metricKey ?? this.metricKey,
    lastSuccessfulSyncUtc: lastSuccessfulSyncUtc.present
        ? lastSuccessfulSyncUtc.value
        : this.lastSuccessfulSyncUtc,
    lastAttemptedSyncUtc: lastAttemptedSyncUtc.present
        ? lastAttemptedSyncUtc.value
        : this.lastAttemptedSyncUtc,
    lastSyncError: lastSyncError.present
        ? lastSyncError.value
        : this.lastSyncError,
    lastSyncedDayIndex: lastSyncedDayIndex.present
        ? lastSyncedDayIndex.value
        : this.lastSyncedDayIndex,
    bytesSyncedLifetime: bytesSyncedLifetime ?? this.bytesSyncedLifetime,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      metricKey: data.metricKey.present ? data.metricKey.value : this.metricKey,
      lastSuccessfulSyncUtc: data.lastSuccessfulSyncUtc.present
          ? data.lastSuccessfulSyncUtc.value
          : this.lastSuccessfulSyncUtc,
      lastAttemptedSyncUtc: data.lastAttemptedSyncUtc.present
          ? data.lastAttemptedSyncUtc.value
          : this.lastAttemptedSyncUtc,
      lastSyncError: data.lastSyncError.present
          ? data.lastSyncError.value
          : this.lastSyncError,
      lastSyncedDayIndex: data.lastSyncedDayIndex.present
          ? data.lastSyncedDayIndex.value
          : this.lastSyncedDayIndex,
      bytesSyncedLifetime: data.bytesSyncedLifetime.present
          ? data.bytesSyncedLifetime.value
          : this.bytesSyncedLifetime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('metricKey: $metricKey, ')
          ..write('lastSuccessfulSyncUtc: $lastSuccessfulSyncUtc, ')
          ..write('lastAttemptedSyncUtc: $lastAttemptedSyncUtc, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('lastSyncedDayIndex: $lastSyncedDayIndex, ')
          ..write('bytesSyncedLifetime: $bytesSyncedLifetime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    metricKey,
    lastSuccessfulSyncUtc,
    lastAttemptedSyncUtc,
    lastSyncError,
    lastSyncedDayIndex,
    bytesSyncedLifetime,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.metricKey == this.metricKey &&
          other.lastSuccessfulSyncUtc == this.lastSuccessfulSyncUtc &&
          other.lastAttemptedSyncUtc == this.lastAttemptedSyncUtc &&
          other.lastSyncError == this.lastSyncError &&
          other.lastSyncedDayIndex == this.lastSyncedDayIndex &&
          other.bytesSyncedLifetime == this.bytesSyncedLifetime);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> metricKey;
  final Value<int?> lastSuccessfulSyncUtc;
  final Value<int?> lastAttemptedSyncUtc;
  final Value<String?> lastSyncError;
  final Value<int?> lastSyncedDayIndex;
  final Value<int> bytesSyncedLifetime;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.metricKey = const Value.absent(),
    this.lastSuccessfulSyncUtc = const Value.absent(),
    this.lastAttemptedSyncUtc = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.lastSyncedDayIndex = const Value.absent(),
    this.bytesSyncedLifetime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String id,
    required String deviceId,
    required String metricKey,
    this.lastSuccessfulSyncUtc = const Value.absent(),
    this.lastAttemptedSyncUtc = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.lastSyncedDayIndex = const Value.absent(),
    this.bytesSyncedLifetime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       metricKey = Value(metricKey);
  static Insertable<SyncStateData> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? metricKey,
    Expression<int>? lastSuccessfulSyncUtc,
    Expression<int>? lastAttemptedSyncUtc,
    Expression<String>? lastSyncError,
    Expression<int>? lastSyncedDayIndex,
    Expression<int>? bytesSyncedLifetime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (metricKey != null) 'metric_key': metricKey,
      if (lastSuccessfulSyncUtc != null)
        'last_successful_sync_utc': lastSuccessfulSyncUtc,
      if (lastAttemptedSyncUtc != null)
        'last_attempted_sync_utc': lastAttemptedSyncUtc,
      if (lastSyncError != null) 'last_sync_error': lastSyncError,
      if (lastSyncedDayIndex != null)
        'last_synced_day_index': lastSyncedDayIndex,
      if (bytesSyncedLifetime != null)
        'bytes_synced_lifetime': bytesSyncedLifetime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? metricKey,
    Value<int?>? lastSuccessfulSyncUtc,
    Value<int?>? lastAttemptedSyncUtc,
    Value<String?>? lastSyncError,
    Value<int?>? lastSyncedDayIndex,
    Value<int>? bytesSyncedLifetime,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      metricKey: metricKey ?? this.metricKey,
      lastSuccessfulSyncUtc:
          lastSuccessfulSyncUtc ?? this.lastSuccessfulSyncUtc,
      lastAttemptedSyncUtc: lastAttemptedSyncUtc ?? this.lastAttemptedSyncUtc,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      lastSyncedDayIndex: lastSyncedDayIndex ?? this.lastSyncedDayIndex,
      bytesSyncedLifetime: bytesSyncedLifetime ?? this.bytesSyncedLifetime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (metricKey.present) {
      map['metric_key'] = Variable<String>(metricKey.value);
    }
    if (lastSuccessfulSyncUtc.present) {
      map['last_successful_sync_utc'] = Variable<int>(
        lastSuccessfulSyncUtc.value,
      );
    }
    if (lastAttemptedSyncUtc.present) {
      map['last_attempted_sync_utc'] = Variable<int>(
        lastAttemptedSyncUtc.value,
      );
    }
    if (lastSyncError.present) {
      map['last_sync_error'] = Variable<String>(lastSyncError.value);
    }
    if (lastSyncedDayIndex.present) {
      map['last_synced_day_index'] = Variable<int>(lastSyncedDayIndex.value);
    }
    if (bytesSyncedLifetime.present) {
      map['bytes_synced_lifetime'] = Variable<int>(bytesSyncedLifetime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('metricKey: $metricKey, ')
          ..write('lastSuccessfulSyncUtc: $lastSuccessfulSyncUtc, ')
          ..write('lastAttemptedSyncUtc: $lastAttemptedSyncUtc, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('lastSyncedDayIndex: $lastSyncedDayIndex, ')
          ..write('bytesSyncedLifetime: $bytesSyncedLifetime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $HrSamplesTable hrSamples = $HrSamplesTable(this);
  late final $HrvSamplesTable hrvSamples = $HrvSamplesTable(this);
  late final $Spo2SamplesTable spo2Samples = $Spo2SamplesTable(this);
  late final $BpReadingsTable bpReadings = $BpReadingsTable(this);
  late final $StepBucketsTable stepBuckets = $StepBucketsTable(this);
  late final $DailyMetricsTable dailyMetrics = $DailyMetricsTable(this);
  late final $SleepSessionsTable sleepSessions = $SleepSessionsTable(this);
  late final $SleepEpochsTable sleepEpochs = $SleepEpochsTable(this);
  late final $BaselinesTable baselines = $BaselinesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    userProfiles,
    devices,
    hrSamples,
    hrvSamples,
    spo2Samples,
    bpReadings,
    stepBuckets,
    dailyMetrics,
    sleepSessions,
    sleepEpochs,
    baselines,
    syncState,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      required String id,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> displayName,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<String> id,
      Value<String?> email,
      Value<String?> phone,
      Value<String?> displayName,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });

final class $$UsersTableReferences
    extends BaseReferences<_$AppDatabase, $UsersTable, User> {
  $$UsersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$UserProfilesTable, List<UserProfile>>
  _userProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.userProfiles,
    aliasName: $_aliasNameGenerator(db.users.id, db.userProfiles.userId),
  );

  $$UserProfilesTableProcessedTableManager get userProfilesRefs {
    final manager = $$UserProfilesTableTableManager(
      $_db,
      $_db.userProfiles,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_userProfilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DevicesTable, List<Device>> _devicesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.devices,
    aliasName: $_aliasNameGenerator(db.users.id, db.devices.userId),
  );

  $$DevicesTableProcessedTableManager get devicesRefs {
    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_devicesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HrSamplesTable, List<HrSample>>
  _hrSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.hrSamples,
    aliasName: $_aliasNameGenerator(db.users.id, db.hrSamples.userId),
  );

  $$HrSamplesTableProcessedTableManager get hrSamplesRefs {
    final manager = $$HrSamplesTableTableManager(
      $_db,
      $_db.hrSamples,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hrSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HrvSamplesTable, List<HrvSample>>
  _hrvSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.hrvSamples,
    aliasName: $_aliasNameGenerator(db.users.id, db.hrvSamples.userId),
  );

  $$HrvSamplesTableProcessedTableManager get hrvSamplesRefs {
    final manager = $$HrvSamplesTableTableManager(
      $_db,
      $_db.hrvSamples,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hrvSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$Spo2SamplesTable, List<Spo2Sample>>
  _spo2SamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.spo2Samples,
    aliasName: $_aliasNameGenerator(db.users.id, db.spo2Samples.userId),
  );

  $$Spo2SamplesTableProcessedTableManager get spo2SamplesRefs {
    final manager = $$Spo2SamplesTableTableManager(
      $_db,
      $_db.spo2Samples,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_spo2SamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BpReadingsTable, List<BpReading>>
  _bpReadingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bpReadings,
    aliasName: $_aliasNameGenerator(db.users.id, db.bpReadings.userId),
  );

  $$BpReadingsTableProcessedTableManager get bpReadingsRefs {
    final manager = $$BpReadingsTableTableManager(
      $_db,
      $_db.bpReadings,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bpReadingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StepBucketsTable, List<StepBucket>>
  _stepBucketsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stepBuckets,
    aliasName: $_aliasNameGenerator(db.users.id, db.stepBuckets.userId),
  );

  $$StepBucketsTableProcessedTableManager get stepBucketsRefs {
    final manager = $$StepBucketsTableTableManager(
      $_db,
      $_db.stepBuckets,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stepBucketsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DailyMetricsTable, List<DailyMetric>>
  _dailyMetricsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dailyMetrics,
    aliasName: $_aliasNameGenerator(db.users.id, db.dailyMetrics.userId),
  );

  $$DailyMetricsTableProcessedTableManager get dailyMetricsRefs {
    final manager = $$DailyMetricsTableTableManager(
      $_db,
      $_db.dailyMetrics,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dailyMetricsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SleepSessionsTable, List<SleepSession>>
  _sleepSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sleepSessions,
    aliasName: $_aliasNameGenerator(db.users.id, db.sleepSessions.userId),
  );

  $$SleepSessionsTableProcessedTableManager get sleepSessionsRefs {
    final manager = $$SleepSessionsTableTableManager(
      $_db,
      $_db.sleepSessions,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sleepSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SleepEpochsTable, List<SleepEpoch>>
  _sleepEpochsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sleepEpochs,
    aliasName: $_aliasNameGenerator(db.users.id, db.sleepEpochs.userId),
  );

  $$SleepEpochsTableProcessedTableManager get sleepEpochsRefs {
    final manager = $$SleepEpochsTableTableManager(
      $_db,
      $_db.sleepEpochs,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sleepEpochsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BaselinesTable, List<Baseline>>
  _baselinesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.baselines,
    aliasName: $_aliasNameGenerator(db.users.id, db.baselines.userId),
  );

  $$BaselinesTableProcessedTableManager get baselinesRefs {
    final manager = $$BaselinesTableTableManager(
      $_db,
      $_db.baselines,
    ).filter((f) => f.userId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_baselinesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> userProfilesRefs(
    Expression<bool> Function($$UserProfilesTableFilterComposer f) f,
  ) {
    final $$UserProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableFilterComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> devicesRefs(
    Expression<bool> Function($$DevicesTableFilterComposer f) f,
  ) {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> hrSamplesRefs(
    Expression<bool> Function($$HrSamplesTableFilterComposer f) f,
  ) {
    final $$HrSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableFilterComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> hrvSamplesRefs(
    Expression<bool> Function($$HrvSamplesTableFilterComposer f) f,
  ) {
    final $$HrvSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrvSamples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrvSamplesTableFilterComposer(
            $db: $db,
            $table: $db.hrvSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> spo2SamplesRefs(
    Expression<bool> Function($$Spo2SamplesTableFilterComposer f) f,
  ) {
    final $$Spo2SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spo2Samples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$Spo2SamplesTableFilterComposer(
            $db: $db,
            $table: $db.spo2Samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bpReadingsRefs(
    Expression<bool> Function($$BpReadingsTableFilterComposer f) f,
  ) {
    final $$BpReadingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bpReadings,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BpReadingsTableFilterComposer(
            $db: $db,
            $table: $db.bpReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stepBucketsRefs(
    Expression<bool> Function($$StepBucketsTableFilterComposer f) f,
  ) {
    final $$StepBucketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stepBuckets,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepBucketsTableFilterComposer(
            $db: $db,
            $table: $db.stepBuckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailyMetricsRefs(
    Expression<bool> Function($$DailyMetricsTableFilterComposer f) f,
  ) {
    final $$DailyMetricsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailyMetrics,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyMetricsTableFilterComposer(
            $db: $db,
            $table: $db.dailyMetrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sleepSessionsRefs(
    Expression<bool> Function($$SleepSessionsTableFilterComposer f) f,
  ) {
    final $$SleepSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableFilterComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sleepEpochsRefs(
    Expression<bool> Function($$SleepEpochsTableFilterComposer f) f,
  ) {
    final $$SleepEpochsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepEpochs,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepEpochsTableFilterComposer(
            $db: $db,
            $table: $db.sleepEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> baselinesRefs(
    Expression<bool> Function($$BaselinesTableFilterComposer f) f,
  ) {
    final $$BaselinesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.baselines,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BaselinesTableFilterComposer(
            $db: $db,
            $table: $db.baselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  Expression<T> userProfilesRefs<T extends Object>(
    Expression<T> Function($$UserProfilesTableAnnotationComposer a) f,
  ) {
    final $$UserProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userProfiles,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> devicesRefs<T extends Object>(
    Expression<T> Function($$DevicesTableAnnotationComposer a) f,
  ) {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> hrSamplesRefs<T extends Object>(
    Expression<T> Function($$HrSamplesTableAnnotationComposer a) f,
  ) {
    final $$HrSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> hrvSamplesRefs<T extends Object>(
    Expression<T> Function($$HrvSamplesTableAnnotationComposer a) f,
  ) {
    final $$HrvSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrvSamples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrvSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.hrvSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> spo2SamplesRefs<T extends Object>(
    Expression<T> Function($$Spo2SamplesTableAnnotationComposer a) f,
  ) {
    final $$Spo2SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spo2Samples,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$Spo2SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.spo2Samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bpReadingsRefs<T extends Object>(
    Expression<T> Function($$BpReadingsTableAnnotationComposer a) f,
  ) {
    final $$BpReadingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bpReadings,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BpReadingsTableAnnotationComposer(
            $db: $db,
            $table: $db.bpReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stepBucketsRefs<T extends Object>(
    Expression<T> Function($$StepBucketsTableAnnotationComposer a) f,
  ) {
    final $$StepBucketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stepBuckets,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepBucketsTableAnnotationComposer(
            $db: $db,
            $table: $db.stepBuckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailyMetricsRefs<T extends Object>(
    Expression<T> Function($$DailyMetricsTableAnnotationComposer a) f,
  ) {
    final $$DailyMetricsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailyMetrics,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyMetricsTableAnnotationComposer(
            $db: $db,
            $table: $db.dailyMetrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sleepSessionsRefs<T extends Object>(
    Expression<T> Function($$SleepSessionsTableAnnotationComposer a) f,
  ) {
    final $$SleepSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sleepEpochsRefs<T extends Object>(
    Expression<T> Function($$SleepEpochsTableAnnotationComposer a) f,
  ) {
    final $$SleepEpochsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepEpochs,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepEpochsTableAnnotationComposer(
            $db: $db,
            $table: $db.sleepEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> baselinesRefs<T extends Object>(
    Expression<T> Function($$BaselinesTableAnnotationComposer a) f,
  ) {
    final $$BaselinesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.baselines,
      getReferencedColumn: (t) => t.userId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BaselinesTableAnnotationComposer(
            $db: $db,
            $table: $db.baselines,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, $$UsersTableReferences),
          User,
          PrefetchHooks Function({
            bool userProfilesRefs,
            bool devicesRefs,
            bool hrSamplesRefs,
            bool hrvSamplesRefs,
            bool spo2SamplesRefs,
            bool bpReadingsRefs,
            bool stepBucketsRefs,
            bool dailyMetricsRefs,
            bool sleepSessionsRefs,
            bool sleepEpochsRefs,
            bool baselinesRefs,
          })
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                email: email,
                phone: phone,
                displayName: displayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> email = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                email: email,
                phone: phone,
                displayName: displayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UsersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userProfilesRefs = false,
                devicesRefs = false,
                hrSamplesRefs = false,
                hrvSamplesRefs = false,
                spo2SamplesRefs = false,
                bpReadingsRefs = false,
                stepBucketsRefs = false,
                dailyMetricsRefs = false,
                sleepSessionsRefs = false,
                sleepEpochsRefs = false,
                baselinesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (userProfilesRefs) db.userProfiles,
                    if (devicesRefs) db.devices,
                    if (hrSamplesRefs) db.hrSamples,
                    if (hrvSamplesRefs) db.hrvSamples,
                    if (spo2SamplesRefs) db.spo2Samples,
                    if (bpReadingsRefs) db.bpReadings,
                    if (stepBucketsRefs) db.stepBuckets,
                    if (dailyMetricsRefs) db.dailyMetrics,
                    if (sleepSessionsRefs) db.sleepSessions,
                    if (sleepEpochsRefs) db.sleepEpochs,
                    if (baselinesRefs) db.baselines,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (userProfilesRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          UserProfile
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._userProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).userProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (devicesRefs)
                        await $_getPrefetchedData<User, $UsersTable, Device>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._devicesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(db, table, p0).devicesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (hrSamplesRefs)
                        await $_getPrefetchedData<User, $UsersTable, HrSample>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._hrSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).hrSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (hrvSamplesRefs)
                        await $_getPrefetchedData<User, $UsersTable, HrvSample>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._hrvSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).hrvSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (spo2SamplesRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          Spo2Sample
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._spo2SamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).spo2SamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bpReadingsRefs)
                        await $_getPrefetchedData<User, $UsersTable, BpReading>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._bpReadingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).bpReadingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stepBucketsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          StepBucket
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._stepBucketsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).stepBucketsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dailyMetricsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          DailyMetric
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._dailyMetricsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).dailyMetricsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sleepSessionsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          SleepSession
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._sleepSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).sleepSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sleepEpochsRefs)
                        await $_getPrefetchedData<
                          User,
                          $UsersTable,
                          SleepEpoch
                        >(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._sleepEpochsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).sleepEpochsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (baselinesRefs)
                        await $_getPrefetchedData<User, $UsersTable, Baseline>(
                          currentTable: table,
                          referencedTable: $$UsersTableReferences
                              ._baselinesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$UsersTableReferences(
                                db,
                                table,
                                p0,
                              ).baselinesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.userId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, $$UsersTableReferences),
      User,
      PrefetchHooks Function({
        bool userProfilesRefs,
        bool devicesRefs,
        bool hrSamplesRefs,
        bool hrvSamplesRefs,
        bool spo2SamplesRefs,
        bool bpReadingsRefs,
        bool stepBucketsRefs,
        bool dailyMetricsRefs,
        bool sleepSessionsRefs,
        bool sleepEpochsRefs,
        bool baselinesRefs,
      })
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      required String userId,
      Value<String?> dateOfBirth,
      Value<SexAtBirth> sexAtBirth,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<bool> usesMetric,
      Value<bool> uses24hClock,
      Value<int?> restingHrBaseline,
      Value<bool> cycleTrackingEnabled,
      Value<String?> lastPeriodStartDate,
      Value<int?> typicalCycleLength,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> userId,
      Value<String?> dateOfBirth,
      Value<SexAtBirth> sexAtBirth,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<bool> usesMetric,
      Value<bool> uses24hClock,
      Value<int?> restingHrBaseline,
      Value<bool> cycleTrackingEnabled,
      Value<String?> lastPeriodStartDate,
      Value<int?> typicalCycleLength,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

final class $$UserProfilesTableReferences
    extends BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile> {
  $$UserProfilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.userProfiles.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SexAtBirth, SexAtBirth, int> get sexAtBirth =>
      $composableBuilder(
        column: $table.sexAtBirth,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usesMetric => $composableBuilder(
    column: $table.usesMetric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get uses24hClock => $composableBuilder(
    column: $table.uses24hClock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restingHrBaseline => $composableBuilder(
    column: $table.restingHrBaseline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cycleTrackingEnabled => $composableBuilder(
    column: $table.cycleTrackingEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastPeriodStartDate => $composableBuilder(
    column: $table.lastPeriodStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typicalCycleLength => $composableBuilder(
    column: $table.typicalCycleLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sexAtBirth => $composableBuilder(
    column: $table.sexAtBirth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usesMetric => $composableBuilder(
    column: $table.usesMetric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get uses24hClock => $composableBuilder(
    column: $table.uses24hClock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restingHrBaseline => $composableBuilder(
    column: $table.restingHrBaseline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cycleTrackingEnabled => $composableBuilder(
    column: $table.cycleTrackingEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastPeriodStartDate => $composableBuilder(
    column: $table.lastPeriodStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typicalCycleLength => $composableBuilder(
    column: $table.typicalCycleLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateOfBirth => $composableBuilder(
    column: $table.dateOfBirth,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SexAtBirth, int> get sexAtBirth =>
      $composableBuilder(
        column: $table.sexAtBirth,
        builder: (column) => column,
      );

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<bool> get usesMetric => $composableBuilder(
    column: $table.usesMetric,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get uses24hClock => $composableBuilder(
    column: $table.uses24hClock,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restingHrBaseline => $composableBuilder(
    column: $table.restingHrBaseline,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cycleTrackingEnabled => $composableBuilder(
    column: $table.cycleTrackingEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastPeriodStartDate => $composableBuilder(
    column: $table.lastPeriodStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get typicalCycleLength => $composableBuilder(
    column: $table.typicalCycleLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (UserProfile, $$UserProfilesTableReferences),
          UserProfile,
          PrefetchHooks Function({bool userId})
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> dateOfBirth = const Value.absent(),
                Value<SexAtBirth> sexAtBirth = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<bool> usesMetric = const Value.absent(),
                Value<bool> uses24hClock = const Value.absent(),
                Value<int?> restingHrBaseline = const Value.absent(),
                Value<bool> cycleTrackingEnabled = const Value.absent(),
                Value<String?> lastPeriodStartDate = const Value.absent(),
                Value<int?> typicalCycleLength = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                userId: userId,
                dateOfBirth: dateOfBirth,
                sexAtBirth: sexAtBirth,
                heightCm: heightCm,
                weightKg: weightKg,
                usesMetric: usesMetric,
                uses24hClock: uses24hClock,
                restingHrBaseline: restingHrBaseline,
                cycleTrackingEnabled: cycleTrackingEnabled,
                lastPeriodStartDate: lastPeriodStartDate,
                typicalCycleLength: typicalCycleLength,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> dateOfBirth = const Value.absent(),
                Value<SexAtBirth> sexAtBirth = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<bool> usesMetric = const Value.absent(),
                Value<bool> uses24hClock = const Value.absent(),
                Value<int?> restingHrBaseline = const Value.absent(),
                Value<bool> cycleTrackingEnabled = const Value.absent(),
                Value<String?> lastPeriodStartDate = const Value.absent(),
                Value<int?> typicalCycleLength = const Value.absent(),
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                userId: userId,
                dateOfBirth: dateOfBirth,
                sexAtBirth: sexAtBirth,
                heightCm: heightCm,
                weightKg: weightKg,
                usesMetric: usesMetric,
                uses24hClock: uses24hClock,
                restingHrBaseline: restingHrBaseline,
                cycleTrackingEnabled: cycleTrackingEnabled,
                lastPeriodStartDate: lastPeriodStartDate,
                typicalCycleLength: typicalCycleLength,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$UserProfilesTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$UserProfilesTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (UserProfile, $$UserProfilesTableReferences),
      UserProfile,
      PrefetchHooks Function({bool userId})
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      required String userId,
      Value<String?> macAddress,
      Value<String?> iosPeripheralUuid,
      required String displayName,
      Value<String?> model,
      Value<String?> hardwareVersion,
      Value<String?> firmwareVersion,
      Value<String?> userIdOnBand,
      required int pairedAtUtc,
      Value<int?> lastConnectedAtUtc,
      Value<int?> lastBatteryPercent,
      Value<bool?> lastCharging,
      Value<bool> isActive,
      Value<String> capabilities,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String?> macAddress,
      Value<String?> iosPeripheralUuid,
      Value<String> displayName,
      Value<String?> model,
      Value<String?> hardwareVersion,
      Value<String?> firmwareVersion,
      Value<String?> userIdOnBand,
      Value<int> pairedAtUtc,
      Value<int?> lastConnectedAtUtc,
      Value<int?> lastBatteryPercent,
      Value<bool?> lastCharging,
      Value<bool> isActive,
      Value<String> capabilities,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });

final class $$DevicesTableReferences
    extends BaseReferences<_$AppDatabase, $DevicesTable, Device> {
  $$DevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.devices.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$HrSamplesTable, List<HrSample>>
  _hrSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.hrSamples,
    aliasName: $_aliasNameGenerator(db.devices.id, db.hrSamples.deviceId),
  );

  $$HrSamplesTableProcessedTableManager get hrSamplesRefs {
    final manager = $$HrSamplesTableTableManager(
      $_db,
      $_db.hrSamples,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hrSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$HrvSamplesTable, List<HrvSample>>
  _hrvSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.hrvSamples,
    aliasName: $_aliasNameGenerator(db.devices.id, db.hrvSamples.deviceId),
  );

  $$HrvSamplesTableProcessedTableManager get hrvSamplesRefs {
    final manager = $$HrvSamplesTableTableManager(
      $_db,
      $_db.hrvSamples,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_hrvSamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$Spo2SamplesTable, List<Spo2Sample>>
  _spo2SamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.spo2Samples,
    aliasName: $_aliasNameGenerator(db.devices.id, db.spo2Samples.deviceId),
  );

  $$Spo2SamplesTableProcessedTableManager get spo2SamplesRefs {
    final manager = $$Spo2SamplesTableTableManager(
      $_db,
      $_db.spo2Samples,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_spo2SamplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BpReadingsTable, List<BpReading>>
  _bpReadingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bpReadings,
    aliasName: $_aliasNameGenerator(db.devices.id, db.bpReadings.deviceId),
  );

  $$BpReadingsTableProcessedTableManager get bpReadingsRefs {
    final manager = $$BpReadingsTableTableManager(
      $_db,
      $_db.bpReadings,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bpReadingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StepBucketsTable, List<StepBucket>>
  _stepBucketsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stepBuckets,
    aliasName: $_aliasNameGenerator(db.devices.id, db.stepBuckets.deviceId),
  );

  $$StepBucketsTableProcessedTableManager get stepBucketsRefs {
    final manager = $$StepBucketsTableTableManager(
      $_db,
      $_db.stepBuckets,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stepBucketsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SleepSessionsTable, List<SleepSession>>
  _sleepSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sleepSessions,
    aliasName: $_aliasNameGenerator(db.devices.id, db.sleepSessions.deviceId),
  );

  $$SleepSessionsTableProcessedTableManager get sleepSessionsRefs {
    final manager = $$SleepSessionsTableTableManager(
      $_db,
      $_db.sleepSessions,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sleepSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncStateTable, List<SyncStateData>>
  _syncStateRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncState,
    aliasName: $_aliasNameGenerator(db.devices.id, db.syncState.deviceId),
  );

  $$SyncStateTableProcessedTableManager get syncStateRefs {
    final manager = $$SyncStateTableTableManager(
      $_db,
      $_db.syncState,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncStateRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iosPeripheralUuid => $composableBuilder(
    column: $table.iosPeripheralUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userIdOnBand => $composableBuilder(
    column: $table.userIdOnBand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pairedAtUtc => $composableBuilder(
    column: $table.pairedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastConnectedAtUtc => $composableBuilder(
    column: $table.lastConnectedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBatteryPercent => $composableBuilder(
    column: $table.lastBatteryPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lastCharging => $composableBuilder(
    column: $table.lastCharging,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> hrSamplesRefs(
    Expression<bool> Function($$HrSamplesTableFilterComposer f) f,
  ) {
    final $$HrSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableFilterComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> hrvSamplesRefs(
    Expression<bool> Function($$HrvSamplesTableFilterComposer f) f,
  ) {
    final $$HrvSamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrvSamples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrvSamplesTableFilterComposer(
            $db: $db,
            $table: $db.hrvSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> spo2SamplesRefs(
    Expression<bool> Function($$Spo2SamplesTableFilterComposer f) f,
  ) {
    final $$Spo2SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spo2Samples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$Spo2SamplesTableFilterComposer(
            $db: $db,
            $table: $db.spo2Samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bpReadingsRefs(
    Expression<bool> Function($$BpReadingsTableFilterComposer f) f,
  ) {
    final $$BpReadingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bpReadings,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BpReadingsTableFilterComposer(
            $db: $db,
            $table: $db.bpReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stepBucketsRefs(
    Expression<bool> Function($$StepBucketsTableFilterComposer f) f,
  ) {
    final $$StepBucketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stepBuckets,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepBucketsTableFilterComposer(
            $db: $db,
            $table: $db.stepBuckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sleepSessionsRefs(
    Expression<bool> Function($$SleepSessionsTableFilterComposer f) f,
  ) {
    final $$SleepSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableFilterComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncStateRefs(
    Expression<bool> Function($$SyncStateTableFilterComposer f) f,
  ) {
    final $$SyncStateTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncState,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStateTableFilterComposer(
            $db: $db,
            $table: $db.syncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iosPeripheralUuid => $composableBuilder(
    column: $table.iosPeripheralUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userIdOnBand => $composableBuilder(
    column: $table.userIdOnBand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pairedAtUtc => $composableBuilder(
    column: $table.pairedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastConnectedAtUtc => $composableBuilder(
    column: $table.lastConnectedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBatteryPercent => $composableBuilder(
    column: $table.lastBatteryPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lastCharging => $composableBuilder(
    column: $table.lastCharging,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get macAddress => $composableBuilder(
    column: $table.macAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iosPeripheralUuid => $composableBuilder(
    column: $table.iosPeripheralUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get hardwareVersion => $composableBuilder(
    column: $table.hardwareVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firmwareVersion => $composableBuilder(
    column: $table.firmwareVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userIdOnBand => $composableBuilder(
    column: $table.userIdOnBand,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pairedAtUtc => $composableBuilder(
    column: $table.pairedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastConnectedAtUtc => $composableBuilder(
    column: $table.lastConnectedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBatteryPercent => $composableBuilder(
    column: $table.lastBatteryPercent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lastCharging => $composableBuilder(
    column: $table.lastCharging,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get capabilities => $composableBuilder(
    column: $table.capabilities,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> hrSamplesRefs<T extends Object>(
    Expression<T> Function($$HrSamplesTableAnnotationComposer a) f,
  ) {
    final $$HrSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrSamples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.hrSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> hrvSamplesRefs<T extends Object>(
    Expression<T> Function($$HrvSamplesTableAnnotationComposer a) f,
  ) {
    final $$HrvSamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.hrvSamples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HrvSamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.hrvSamples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> spo2SamplesRefs<T extends Object>(
    Expression<T> Function($$Spo2SamplesTableAnnotationComposer a) f,
  ) {
    final $$Spo2SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.spo2Samples,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$Spo2SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.spo2Samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bpReadingsRefs<T extends Object>(
    Expression<T> Function($$BpReadingsTableAnnotationComposer a) f,
  ) {
    final $$BpReadingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bpReadings,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BpReadingsTableAnnotationComposer(
            $db: $db,
            $table: $db.bpReadings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stepBucketsRefs<T extends Object>(
    Expression<T> Function($$StepBucketsTableAnnotationComposer a) f,
  ) {
    final $$StepBucketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stepBuckets,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StepBucketsTableAnnotationComposer(
            $db: $db,
            $table: $db.stepBuckets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> sleepSessionsRefs<T extends Object>(
    Expression<T> Function($$SleepSessionsTableAnnotationComposer a) f,
  ) {
    final $$SleepSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncStateRefs<T extends Object>(
    Expression<T> Function($$SyncStateTableAnnotationComposer a) f,
  ) {
    final $$SyncStateTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncState,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncStateTableAnnotationComposer(
            $db: $db,
            $table: $db.syncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, $$DevicesTableReferences),
          Device,
          PrefetchHooks Function({
            bool userId,
            bool hrSamplesRefs,
            bool hrvSamplesRefs,
            bool spo2SamplesRefs,
            bool bpReadingsRefs,
            bool stepBucketsRefs,
            bool sleepSessionsRefs,
            bool syncStateRefs,
          })
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> macAddress = const Value.absent(),
                Value<String?> iosPeripheralUuid = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> hardwareVersion = const Value.absent(),
                Value<String?> firmwareVersion = const Value.absent(),
                Value<String?> userIdOnBand = const Value.absent(),
                Value<int> pairedAtUtc = const Value.absent(),
                Value<int?> lastConnectedAtUtc = const Value.absent(),
                Value<int?> lastBatteryPercent = const Value.absent(),
                Value<bool?> lastCharging = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                userId: userId,
                macAddress: macAddress,
                iosPeripheralUuid: iosPeripheralUuid,
                displayName: displayName,
                model: model,
                hardwareVersion: hardwareVersion,
                firmwareVersion: firmwareVersion,
                userIdOnBand: userIdOnBand,
                pairedAtUtc: pairedAtUtc,
                lastConnectedAtUtc: lastConnectedAtUtc,
                lastBatteryPercent: lastBatteryPercent,
                lastCharging: lastCharging,
                isActive: isActive,
                capabilities: capabilities,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String?> macAddress = const Value.absent(),
                Value<String?> iosPeripheralUuid = const Value.absent(),
                required String displayName,
                Value<String?> model = const Value.absent(),
                Value<String?> hardwareVersion = const Value.absent(),
                Value<String?> firmwareVersion = const Value.absent(),
                Value<String?> userIdOnBand = const Value.absent(),
                required int pairedAtUtc,
                Value<int?> lastConnectedAtUtc = const Value.absent(),
                Value<int?> lastBatteryPercent = const Value.absent(),
                Value<bool?> lastCharging = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> capabilities = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                userId: userId,
                macAddress: macAddress,
                iosPeripheralUuid: iosPeripheralUuid,
                displayName: displayName,
                model: model,
                hardwareVersion: hardwareVersion,
                firmwareVersion: firmwareVersion,
                userIdOnBand: userIdOnBand,
                pairedAtUtc: pairedAtUtc,
                lastConnectedAtUtc: lastConnectedAtUtc,
                lastBatteryPercent: lastBatteryPercent,
                lastCharging: lastCharging,
                isActive: isActive,
                capabilities: capabilities,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DevicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                userId = false,
                hrSamplesRefs = false,
                hrvSamplesRefs = false,
                spo2SamplesRefs = false,
                bpReadingsRefs = false,
                stepBucketsRefs = false,
                sleepSessionsRefs = false,
                syncStateRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (hrSamplesRefs) db.hrSamples,
                    if (hrvSamplesRefs) db.hrvSamples,
                    if (spo2SamplesRefs) db.spo2Samples,
                    if (bpReadingsRefs) db.bpReadings,
                    if (stepBucketsRefs) db.stepBuckets,
                    if (sleepSessionsRefs) db.sleepSessions,
                    if (syncStateRefs) db.syncState,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable: $$DevicesTableReferences
                                        ._userIdTable(db),
                                    referencedColumn: $$DevicesTableReferences
                                        ._userIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (hrSamplesRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          HrSample
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._hrSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).hrSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (hrvSamplesRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          HrvSample
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._hrvSamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).hrvSamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (spo2SamplesRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          Spo2Sample
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._spo2SamplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).spo2SamplesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bpReadingsRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          BpReading
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._bpReadingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).bpReadingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (stepBucketsRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          StepBucket
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._stepBucketsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).stepBucketsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (sleepSessionsRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          SleepSession
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._sleepSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).sleepSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncStateRefs)
                        await $_getPrefetchedData<
                          Device,
                          $DevicesTable,
                          SyncStateData
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._syncStateRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).syncStateRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deviceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, $$DevicesTableReferences),
      Device,
      PrefetchHooks Function({
        bool userId,
        bool hrSamplesRefs,
        bool hrvSamplesRefs,
        bool spo2SamplesRefs,
        bool bpReadingsRefs,
        bool stepBucketsRefs,
        bool sleepSessionsRefs,
        bool syncStateRefs,
      })
    >;
typedef $$HrSamplesTableCreateCompanionBuilder =
    HrSamplesCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int capturedAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required int bpm,
      required int intervalMin,
      Value<bool> isResting,
      Value<int> rowid,
    });
typedef $$HrSamplesTableUpdateCompanionBuilder =
    HrSamplesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> capturedAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> bpm,
      Value<int> intervalMin,
      Value<bool> isResting,
      Value<int> rowid,
    });

final class $$HrSamplesTableReferences
    extends BaseReferences<_$AppDatabase, $HrSamplesTable, HrSample> {
  $$HrSamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.hrSamples.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) => db.devices
      .createAlias($_aliasNameGenerator(db.hrSamples.deviceId, db.devices.id));

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HrSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalMin => $composableBuilder(
    column: $table.intervalMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isResting => $composableBuilder(
    column: $table.isResting,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalMin => $composableBuilder(
    column: $table.intervalMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isResting => $composableBuilder(
    column: $table.isResting,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HrSamplesTable> {
  $$HrSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<int> get intervalMin => $composableBuilder(
    column: $table.intervalMin,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isResting =>
      $composableBuilder(column: $table.isResting, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HrSamplesTable,
          HrSample,
          $$HrSamplesTableFilterComposer,
          $$HrSamplesTableOrderingComposer,
          $$HrSamplesTableAnnotationComposer,
          $$HrSamplesTableCreateCompanionBuilder,
          $$HrSamplesTableUpdateCompanionBuilder,
          (HrSample, $$HrSamplesTableReferences),
          HrSample,
          PrefetchHooks Function({bool userId, bool deviceId})
        > {
  $$HrSamplesTableTableManager(_$AppDatabase db, $HrSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HrSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HrSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HrSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> capturedAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<int> intervalMin = const Value.absent(),
                Value<bool> isResting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HrSamplesCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                bpm: bpm,
                intervalMin: intervalMin,
                isResting: isResting,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int capturedAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required int bpm,
                required int intervalMin,
                Value<bool> isResting = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HrSamplesCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                bpm: bpm,
                intervalMin: intervalMin,
                isResting: isResting,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HrSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$HrSamplesTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$HrSamplesTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$HrSamplesTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$HrSamplesTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HrSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HrSamplesTable,
      HrSample,
      $$HrSamplesTableFilterComposer,
      $$HrSamplesTableOrderingComposer,
      $$HrSamplesTableAnnotationComposer,
      $$HrSamplesTableCreateCompanionBuilder,
      $$HrSamplesTableUpdateCompanionBuilder,
      (HrSample, $$HrSamplesTableReferences),
      HrSample,
      PrefetchHooks Function({bool userId, bool deviceId})
    >;
typedef $$HrvSamplesTableCreateCompanionBuilder =
    HrvSamplesCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int capturedAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required double rmssdMs,
      Value<double?> sdnnMs,
      Value<double?> pnn50Pct,
      Value<int?> meanHrBpm,
      Value<int?> beatCount,
      Value<int> rowid,
    });
typedef $$HrvSamplesTableUpdateCompanionBuilder =
    HrvSamplesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> capturedAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<double> rmssdMs,
      Value<double?> sdnnMs,
      Value<double?> pnn50Pct,
      Value<int?> meanHrBpm,
      Value<int?> beatCount,
      Value<int> rowid,
    });

final class $$HrvSamplesTableReferences
    extends BaseReferences<_$AppDatabase, $HrvSamplesTable, HrvSample> {
  $$HrvSamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.hrvSamples.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) => db.devices
      .createAlias($_aliasNameGenerator(db.hrvSamples.deviceId, db.devices.id));

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HrvSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $HrvSamplesTable> {
  $$HrvSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rmssdMs => $composableBuilder(
    column: $table.rmssdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sdnnMs => $composableBuilder(
    column: $table.sdnnMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pnn50Pct => $composableBuilder(
    column: $table.pnn50Pct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meanHrBpm => $composableBuilder(
    column: $table.meanHrBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beatCount => $composableBuilder(
    column: $table.beatCount,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrvSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $HrvSamplesTable> {
  $$HrvSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rmssdMs => $composableBuilder(
    column: $table.rmssdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sdnnMs => $composableBuilder(
    column: $table.sdnnMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pnn50Pct => $composableBuilder(
    column: $table.pnn50Pct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meanHrBpm => $composableBuilder(
    column: $table.meanHrBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beatCount => $composableBuilder(
    column: $table.beatCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrvSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HrvSamplesTable> {
  $$HrvSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rmssdMs =>
      $composableBuilder(column: $table.rmssdMs, builder: (column) => column);

  GeneratedColumn<double> get sdnnMs =>
      $composableBuilder(column: $table.sdnnMs, builder: (column) => column);

  GeneratedColumn<double> get pnn50Pct =>
      $composableBuilder(column: $table.pnn50Pct, builder: (column) => column);

  GeneratedColumn<int> get meanHrBpm =>
      $composableBuilder(column: $table.meanHrBpm, builder: (column) => column);

  GeneratedColumn<int> get beatCount =>
      $composableBuilder(column: $table.beatCount, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HrvSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HrvSamplesTable,
          HrvSample,
          $$HrvSamplesTableFilterComposer,
          $$HrvSamplesTableOrderingComposer,
          $$HrvSamplesTableAnnotationComposer,
          $$HrvSamplesTableCreateCompanionBuilder,
          $$HrvSamplesTableUpdateCompanionBuilder,
          (HrvSample, $$HrvSamplesTableReferences),
          HrvSample,
          PrefetchHooks Function({bool userId, bool deviceId})
        > {
  $$HrvSamplesTableTableManager(_$AppDatabase db, $HrvSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HrvSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HrvSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HrvSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> capturedAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<double> rmssdMs = const Value.absent(),
                Value<double?> sdnnMs = const Value.absent(),
                Value<double?> pnn50Pct = const Value.absent(),
                Value<int?> meanHrBpm = const Value.absent(),
                Value<int?> beatCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HrvSamplesCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                rmssdMs: rmssdMs,
                sdnnMs: sdnnMs,
                pnn50Pct: pnn50Pct,
                meanHrBpm: meanHrBpm,
                beatCount: beatCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int capturedAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required double rmssdMs,
                Value<double?> sdnnMs = const Value.absent(),
                Value<double?> pnn50Pct = const Value.absent(),
                Value<int?> meanHrBpm = const Value.absent(),
                Value<int?> beatCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HrvSamplesCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                rmssdMs: rmssdMs,
                sdnnMs: sdnnMs,
                pnn50Pct: pnn50Pct,
                meanHrBpm: meanHrBpm,
                beatCount: beatCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HrvSamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$HrvSamplesTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$HrvSamplesTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$HrvSamplesTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$HrvSamplesTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$HrvSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HrvSamplesTable,
      HrvSample,
      $$HrvSamplesTableFilterComposer,
      $$HrvSamplesTableOrderingComposer,
      $$HrvSamplesTableAnnotationComposer,
      $$HrvSamplesTableCreateCompanionBuilder,
      $$HrvSamplesTableUpdateCompanionBuilder,
      (HrvSample, $$HrvSamplesTableReferences),
      HrvSample,
      PrefetchHooks Function({bool userId, bool deviceId})
    >;
typedef $$Spo2SamplesTableCreateCompanionBuilder =
    Spo2SamplesCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int capturedAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required int pctMin,
      required int pctMax,
      required int bucketMin,
      Value<int> rowid,
    });
typedef $$Spo2SamplesTableUpdateCompanionBuilder =
    Spo2SamplesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> capturedAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> pctMin,
      Value<int> pctMax,
      Value<int> bucketMin,
      Value<int> rowid,
    });

final class $$Spo2SamplesTableReferences
    extends BaseReferences<_$AppDatabase, $Spo2SamplesTable, Spo2Sample> {
  $$Spo2SamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.spo2Samples.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias(
        $_aliasNameGenerator(db.spo2Samples.deviceId, db.devices.id),
      );

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$Spo2SamplesTableFilterComposer
    extends Composer<_$AppDatabase, $Spo2SamplesTable> {
  $$Spo2SamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pctMin => $composableBuilder(
    column: $table.pctMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pctMax => $composableBuilder(
    column: $table.pctMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bucketMin => $composableBuilder(
    column: $table.bucketMin,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Spo2SamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $Spo2SamplesTable> {
  $$Spo2SamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pctMin => $composableBuilder(
    column: $table.pctMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pctMax => $composableBuilder(
    column: $table.pctMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bucketMin => $composableBuilder(
    column: $table.bucketMin,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Spo2SamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $Spo2SamplesTable> {
  $$Spo2SamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pctMin =>
      $composableBuilder(column: $table.pctMin, builder: (column) => column);

  GeneratedColumn<int> get pctMax =>
      $composableBuilder(column: $table.pctMax, builder: (column) => column);

  GeneratedColumn<int> get bucketMin =>
      $composableBuilder(column: $table.bucketMin, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Spo2SamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $Spo2SamplesTable,
          Spo2Sample,
          $$Spo2SamplesTableFilterComposer,
          $$Spo2SamplesTableOrderingComposer,
          $$Spo2SamplesTableAnnotationComposer,
          $$Spo2SamplesTableCreateCompanionBuilder,
          $$Spo2SamplesTableUpdateCompanionBuilder,
          (Spo2Sample, $$Spo2SamplesTableReferences),
          Spo2Sample,
          PrefetchHooks Function({bool userId, bool deviceId})
        > {
  $$Spo2SamplesTableTableManager(_$AppDatabase db, $Spo2SamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$Spo2SamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$Spo2SamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$Spo2SamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> capturedAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> pctMin = const Value.absent(),
                Value<int> pctMax = const Value.absent(),
                Value<int> bucketMin = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => Spo2SamplesCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                pctMin: pctMin,
                pctMax: pctMax,
                bucketMin: bucketMin,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int capturedAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required int pctMin,
                required int pctMax,
                required int bucketMin,
                Value<int> rowid = const Value.absent(),
              }) => Spo2SamplesCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                pctMin: pctMin,
                pctMax: pctMax,
                bucketMin: bucketMin,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$Spo2SamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$Spo2SamplesTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$Spo2SamplesTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$Spo2SamplesTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$Spo2SamplesTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$Spo2SamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $Spo2SamplesTable,
      Spo2Sample,
      $$Spo2SamplesTableFilterComposer,
      $$Spo2SamplesTableOrderingComposer,
      $$Spo2SamplesTableAnnotationComposer,
      $$Spo2SamplesTableCreateCompanionBuilder,
      $$Spo2SamplesTableUpdateCompanionBuilder,
      (Spo2Sample, $$Spo2SamplesTableReferences),
      Spo2Sample,
      PrefetchHooks Function({bool userId, bool deviceId})
    >;
typedef $$BpReadingsTableCreateCompanionBuilder =
    BpReadingsCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int capturedAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required int systolicMmhg,
      required int diastolicMmhg,
      Value<int?> pulseBpm,
      required BpDerivation derivation,
      Value<int?> position,
      Value<int> rowid,
    });
typedef $$BpReadingsTableUpdateCompanionBuilder =
    BpReadingsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> capturedAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> systolicMmhg,
      Value<int> diastolicMmhg,
      Value<int?> pulseBpm,
      Value<BpDerivation> derivation,
      Value<int?> position,
      Value<int> rowid,
    });

final class $$BpReadingsTableReferences
    extends BaseReferences<_$AppDatabase, $BpReadingsTable, BpReading> {
  $$BpReadingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.bpReadings.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) => db.devices
      .createAlias($_aliasNameGenerator(db.bpReadings.deviceId, db.devices.id));

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BpReadingsTableFilterComposer
    extends Composer<_$AppDatabase, $BpReadingsTable> {
  $$BpReadingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pulseBpm => $composableBuilder(
    column: $table.pulseBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BpDerivation, BpDerivation, int>
  get derivation => $composableBuilder(
    column: $table.derivation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BpReadingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BpReadingsTable> {
  $$BpReadingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pulseBpm => $composableBuilder(
    column: $table.pulseBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get derivation => $composableBuilder(
    column: $table.derivation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BpReadingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BpReadingsTable> {
  $$BpReadingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get capturedAtUtc => $composableBuilder(
    column: $table.capturedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pulseBpm =>
      $composableBuilder(column: $table.pulseBpm, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BpDerivation, int> get derivation =>
      $composableBuilder(
        column: $table.derivation,
        builder: (column) => column,
      );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BpReadingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BpReadingsTable,
          BpReading,
          $$BpReadingsTableFilterComposer,
          $$BpReadingsTableOrderingComposer,
          $$BpReadingsTableAnnotationComposer,
          $$BpReadingsTableCreateCompanionBuilder,
          $$BpReadingsTableUpdateCompanionBuilder,
          (BpReading, $$BpReadingsTableReferences),
          BpReading,
          PrefetchHooks Function({bool userId, bool deviceId})
        > {
  $$BpReadingsTableTableManager(_$AppDatabase db, $BpReadingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BpReadingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BpReadingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BpReadingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> capturedAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> systolicMmhg = const Value.absent(),
                Value<int> diastolicMmhg = const Value.absent(),
                Value<int?> pulseBpm = const Value.absent(),
                Value<BpDerivation> derivation = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BpReadingsCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                systolicMmhg: systolicMmhg,
                diastolicMmhg: diastolicMmhg,
                pulseBpm: pulseBpm,
                derivation: derivation,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int capturedAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required int systolicMmhg,
                required int diastolicMmhg,
                Value<int?> pulseBpm = const Value.absent(),
                required BpDerivation derivation,
                Value<int?> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BpReadingsCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                capturedAtUtc: capturedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                systolicMmhg: systolicMmhg,
                diastolicMmhg: diastolicMmhg,
                pulseBpm: pulseBpm,
                derivation: derivation,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BpReadingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$BpReadingsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$BpReadingsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$BpReadingsTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$BpReadingsTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BpReadingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BpReadingsTable,
      BpReading,
      $$BpReadingsTableFilterComposer,
      $$BpReadingsTableOrderingComposer,
      $$BpReadingsTableAnnotationComposer,
      $$BpReadingsTableCreateCompanionBuilder,
      $$BpReadingsTableUpdateCompanionBuilder,
      (BpReading, $$BpReadingsTableReferences),
      BpReading,
      PrefetchHooks Function({bool userId, bool deviceId})
    >;
typedef $$StepBucketsTableCreateCompanionBuilder =
    StepBucketsCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int bucketStartAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required int steps,
      required int distanceM,
      required double caloriesKcal,
      Value<int> runSteps,
      Value<int> rowid,
    });
typedef $$StepBucketsTableUpdateCompanionBuilder =
    StepBucketsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> bucketStartAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> steps,
      Value<int> distanceM,
      Value<double> caloriesKcal,
      Value<int> runSteps,
      Value<int> rowid,
    });

final class $$StepBucketsTableReferences
    extends BaseReferences<_$AppDatabase, $StepBucketsTable, StepBucket> {
  $$StepBucketsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.stepBuckets.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias(
        $_aliasNameGenerator(db.stepBuckets.deviceId, db.devices.id),
      );

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StepBucketsTableFilterComposer
    extends Composer<_$AppDatabase, $StepBucketsTable> {
  $$StepBucketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bucketStartAtUtc => $composableBuilder(
    column: $table.bucketStartAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runSteps => $composableBuilder(
    column: $table.runSteps,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepBucketsTableOrderingComposer
    extends Composer<_$AppDatabase, $StepBucketsTable> {
  $$StepBucketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bucketStartAtUtc => $composableBuilder(
    column: $table.bucketStartAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runSteps => $composableBuilder(
    column: $table.runSteps,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepBucketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StepBucketsTable> {
  $$StepBucketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bucketStartAtUtc => $composableBuilder(
    column: $table.bucketStartAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runSteps =>
      $composableBuilder(column: $table.runSteps, builder: (column) => column);

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StepBucketsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StepBucketsTable,
          StepBucket,
          $$StepBucketsTableFilterComposer,
          $$StepBucketsTableOrderingComposer,
          $$StepBucketsTableAnnotationComposer,
          $$StepBucketsTableCreateCompanionBuilder,
          $$StepBucketsTableUpdateCompanionBuilder,
          (StepBucket, $$StepBucketsTableReferences),
          StepBucket,
          PrefetchHooks Function({bool userId, bool deviceId})
        > {
  $$StepBucketsTableTableManager(_$AppDatabase db, $StepBucketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StepBucketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StepBucketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StepBucketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> bucketStartAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> steps = const Value.absent(),
                Value<int> distanceM = const Value.absent(),
                Value<double> caloriesKcal = const Value.absent(),
                Value<int> runSteps = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepBucketsCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                bucketStartAtUtc: bucketStartAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                steps: steps,
                distanceM: distanceM,
                caloriesKcal: caloriesKcal,
                runSteps: runSteps,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int bucketStartAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required int steps,
                required int distanceM,
                required double caloriesKcal,
                Value<int> runSteps = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StepBucketsCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                bucketStartAtUtc: bucketStartAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                steps: steps,
                distanceM: distanceM,
                caloriesKcal: caloriesKcal,
                runSteps: runSteps,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StepBucketsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false, deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$StepBucketsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$StepBucketsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$StepBucketsTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$StepBucketsTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StepBucketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StepBucketsTable,
      StepBucket,
      $$StepBucketsTableFilterComposer,
      $$StepBucketsTableOrderingComposer,
      $$StepBucketsTableAnnotationComposer,
      $$StepBucketsTableCreateCompanionBuilder,
      $$StepBucketsTableUpdateCompanionBuilder,
      (StepBucket, $$StepBucketsTableReferences),
      StepBucket,
      PrefetchHooks Function({bool userId, bool deviceId})
    >;
typedef $$DailyMetricsTableCreateCompanionBuilder =
    DailyMetricsCompanion Function({
      required String id,
      required String userId,
      required String localDate,
      required int tzOffsetMin,
      Value<int?> restingHrBpm,
      Value<double?> hrvRmssdMs,
      Value<double?> hrvSdnnMs,
      Value<double?> restingRespRateBpm,
      Value<double?> spo2OvernightAvg,
      Value<int?> spo2OvernightMin,
      Value<int?> systolicMmhg,
      Value<int?> diastolicMmhg,
      Value<int?> sleepTotalMin,
      Value<double?> sleepDeepPct,
      Value<double?> sleepRemPct,
      Value<double?> sleepLightPct,
      Value<double?> sleepEfficiencyPct,
      Value<int?> bedtimeUtc,
      Value<int?> wakeUtc,
      Value<int?> steps,
      Value<int?> distanceM,
      Value<double?> caloriesKcal,
      Value<int?> activeMinutes,
      Value<double?> stiffnessIndex,
      Value<double?> augmentationIndex,
      Value<double?> strokeVolumeIndex,
      Value<double?> breathingDisruptionsHr,
      Value<int?> recoveryScore,
      Value<int?> wellnessScore,
      Value<int?> cyclePhase,
      required int computedAtUtc,
      required String algorithmVersion,
      required DataSource source,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });
typedef $$DailyMetricsTableUpdateCompanionBuilder =
    DailyMetricsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> localDate,
      Value<int> tzOffsetMin,
      Value<int?> restingHrBpm,
      Value<double?> hrvRmssdMs,
      Value<double?> hrvSdnnMs,
      Value<double?> restingRespRateBpm,
      Value<double?> spo2OvernightAvg,
      Value<int?> spo2OvernightMin,
      Value<int?> systolicMmhg,
      Value<int?> diastolicMmhg,
      Value<int?> sleepTotalMin,
      Value<double?> sleepDeepPct,
      Value<double?> sleepRemPct,
      Value<double?> sleepLightPct,
      Value<double?> sleepEfficiencyPct,
      Value<int?> bedtimeUtc,
      Value<int?> wakeUtc,
      Value<int?> steps,
      Value<int?> distanceM,
      Value<double?> caloriesKcal,
      Value<int?> activeMinutes,
      Value<double?> stiffnessIndex,
      Value<double?> augmentationIndex,
      Value<double?> strokeVolumeIndex,
      Value<double?> breathingDisruptionsHr,
      Value<int?> recoveryScore,
      Value<int?> wellnessScore,
      Value<int?> cyclePhase,
      Value<int> computedAtUtc,
      Value<String> algorithmVersion,
      Value<DataSource> source,
      Value<int?> deletedAtUtc,
      Value<int> rowid,
    });

final class $$DailyMetricsTableReferences
    extends BaseReferences<_$AppDatabase, $DailyMetricsTable, DailyMetric> {
  $$DailyMetricsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.dailyMetrics.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyMetricsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyMetricsTable> {
  $$DailyMetricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restingHrBpm => $composableBuilder(
    column: $table.restingHrBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hrvRmssdMs => $composableBuilder(
    column: $table.hrvRmssdMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hrvSdnnMs => $composableBuilder(
    column: $table.hrvSdnnMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get restingRespRateBpm => $composableBuilder(
    column: $table.restingRespRateBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get spo2OvernightAvg => $composableBuilder(
    column: $table.spo2OvernightAvg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spo2OvernightMin => $composableBuilder(
    column: $table.spo2OvernightMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleepTotalMin => $composableBuilder(
    column: $table.sleepTotalMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepDeepPct => $composableBuilder(
    column: $table.sleepDeepPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepRemPct => $composableBuilder(
    column: $table.sleepRemPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepLightPct => $composableBuilder(
    column: $table.sleepLightPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepEfficiencyPct => $composableBuilder(
    column: $table.sleepEfficiencyPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bedtimeUtc => $composableBuilder(
    column: $table.bedtimeUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wakeUtc => $composableBuilder(
    column: $table.wakeUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeMinutes => $composableBuilder(
    column: $table.activeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stiffnessIndex => $composableBuilder(
    column: $table.stiffnessIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get augmentationIndex => $composableBuilder(
    column: $table.augmentationIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strokeVolumeIndex => $composableBuilder(
    column: $table.strokeVolumeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get breathingDisruptionsHr => $composableBuilder(
    column: $table.breathingDisruptionsHr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wellnessScore => $composableBuilder(
    column: $table.wellnessScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cyclePhase => $composableBuilder(
    column: $table.cyclePhase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyMetricsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyMetricsTable> {
  $$DailyMetricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDate => $composableBuilder(
    column: $table.localDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restingHrBpm => $composableBuilder(
    column: $table.restingHrBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hrvRmssdMs => $composableBuilder(
    column: $table.hrvRmssdMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hrvSdnnMs => $composableBuilder(
    column: $table.hrvSdnnMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get restingRespRateBpm => $composableBuilder(
    column: $table.restingRespRateBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get spo2OvernightAvg => $composableBuilder(
    column: $table.spo2OvernightAvg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spo2OvernightMin => $composableBuilder(
    column: $table.spo2OvernightMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleepTotalMin => $composableBuilder(
    column: $table.sleepTotalMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepDeepPct => $composableBuilder(
    column: $table.sleepDeepPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepRemPct => $composableBuilder(
    column: $table.sleepRemPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepLightPct => $composableBuilder(
    column: $table.sleepLightPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepEfficiencyPct => $composableBuilder(
    column: $table.sleepEfficiencyPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bedtimeUtc => $composableBuilder(
    column: $table.bedtimeUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wakeUtc => $composableBuilder(
    column: $table.wakeUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeMinutes => $composableBuilder(
    column: $table.activeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stiffnessIndex => $composableBuilder(
    column: $table.stiffnessIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get augmentationIndex => $composableBuilder(
    column: $table.augmentationIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strokeVolumeIndex => $composableBuilder(
    column: $table.strokeVolumeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get breathingDisruptionsHr => $composableBuilder(
    column: $table.breathingDisruptionsHr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wellnessScore => $composableBuilder(
    column: $table.wellnessScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cyclePhase => $composableBuilder(
    column: $table.cyclePhase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyMetricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyMetricsTable> {
  $$DailyMetricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMin => $composableBuilder(
    column: $table.tzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restingHrBpm => $composableBuilder(
    column: $table.restingHrBpm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hrvRmssdMs => $composableBuilder(
    column: $table.hrvRmssdMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hrvSdnnMs =>
      $composableBuilder(column: $table.hrvSdnnMs, builder: (column) => column);

  GeneratedColumn<double> get restingRespRateBpm => $composableBuilder(
    column: $table.restingRespRateBpm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get spo2OvernightAvg => $composableBuilder(
    column: $table.spo2OvernightAvg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get spo2OvernightMin => $composableBuilder(
    column: $table.spo2OvernightMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get systolicMmhg => $composableBuilder(
    column: $table.systolicMmhg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diastolicMmhg => $composableBuilder(
    column: $table.diastolicMmhg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sleepTotalMin => $composableBuilder(
    column: $table.sleepTotalMin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepDeepPct => $composableBuilder(
    column: $table.sleepDeepPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepRemPct => $composableBuilder(
    column: $table.sleepRemPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepLightPct => $composableBuilder(
    column: $table.sleepLightPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepEfficiencyPct => $composableBuilder(
    column: $table.sleepEfficiencyPct,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bedtimeUtc => $composableBuilder(
    column: $table.bedtimeUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wakeUtc =>
      $composableBuilder(column: $table.wakeUtc, builder: (column) => column);

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<int> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<double> get caloriesKcal => $composableBuilder(
    column: $table.caloriesKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeMinutes => $composableBuilder(
    column: $table.activeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stiffnessIndex => $composableBuilder(
    column: $table.stiffnessIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get augmentationIndex => $composableBuilder(
    column: $table.augmentationIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get strokeVolumeIndex => $composableBuilder(
    column: $table.strokeVolumeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get breathingDisruptionsHr => $composableBuilder(
    column: $table.breathingDisruptionsHr,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wellnessScore => $composableBuilder(
    column: $table.wellnessScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cyclePhase => $composableBuilder(
    column: $table.cyclePhase,
    builder: (column) => column,
  );

  GeneratedColumn<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyMetricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyMetricsTable,
          DailyMetric,
          $$DailyMetricsTableFilterComposer,
          $$DailyMetricsTableOrderingComposer,
          $$DailyMetricsTableAnnotationComposer,
          $$DailyMetricsTableCreateCompanionBuilder,
          $$DailyMetricsTableUpdateCompanionBuilder,
          (DailyMetric, $$DailyMetricsTableReferences),
          DailyMetric,
          PrefetchHooks Function({bool userId})
        > {
  $$DailyMetricsTableTableManager(_$AppDatabase db, $DailyMetricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyMetricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyMetricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyMetricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> localDate = const Value.absent(),
                Value<int> tzOffsetMin = const Value.absent(),
                Value<int?> restingHrBpm = const Value.absent(),
                Value<double?> hrvRmssdMs = const Value.absent(),
                Value<double?> hrvSdnnMs = const Value.absent(),
                Value<double?> restingRespRateBpm = const Value.absent(),
                Value<double?> spo2OvernightAvg = const Value.absent(),
                Value<int?> spo2OvernightMin = const Value.absent(),
                Value<int?> systolicMmhg = const Value.absent(),
                Value<int?> diastolicMmhg = const Value.absent(),
                Value<int?> sleepTotalMin = const Value.absent(),
                Value<double?> sleepDeepPct = const Value.absent(),
                Value<double?> sleepRemPct = const Value.absent(),
                Value<double?> sleepLightPct = const Value.absent(),
                Value<double?> sleepEfficiencyPct = const Value.absent(),
                Value<int?> bedtimeUtc = const Value.absent(),
                Value<int?> wakeUtc = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<double?> caloriesKcal = const Value.absent(),
                Value<int?> activeMinutes = const Value.absent(),
                Value<double?> stiffnessIndex = const Value.absent(),
                Value<double?> augmentationIndex = const Value.absent(),
                Value<double?> strokeVolumeIndex = const Value.absent(),
                Value<double?> breathingDisruptionsHr = const Value.absent(),
                Value<int?> recoveryScore = const Value.absent(),
                Value<int?> wellnessScore = const Value.absent(),
                Value<int?> cyclePhase = const Value.absent(),
                Value<int> computedAtUtc = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyMetricsCompanion(
                id: id,
                userId: userId,
                localDate: localDate,
                tzOffsetMin: tzOffsetMin,
                restingHrBpm: restingHrBpm,
                hrvRmssdMs: hrvRmssdMs,
                hrvSdnnMs: hrvSdnnMs,
                restingRespRateBpm: restingRespRateBpm,
                spo2OvernightAvg: spo2OvernightAvg,
                spo2OvernightMin: spo2OvernightMin,
                systolicMmhg: systolicMmhg,
                diastolicMmhg: diastolicMmhg,
                sleepTotalMin: sleepTotalMin,
                sleepDeepPct: sleepDeepPct,
                sleepRemPct: sleepRemPct,
                sleepLightPct: sleepLightPct,
                sleepEfficiencyPct: sleepEfficiencyPct,
                bedtimeUtc: bedtimeUtc,
                wakeUtc: wakeUtc,
                steps: steps,
                distanceM: distanceM,
                caloriesKcal: caloriesKcal,
                activeMinutes: activeMinutes,
                stiffnessIndex: stiffnessIndex,
                augmentationIndex: augmentationIndex,
                strokeVolumeIndex: strokeVolumeIndex,
                breathingDisruptionsHr: breathingDisruptionsHr,
                recoveryScore: recoveryScore,
                wellnessScore: wellnessScore,
                cyclePhase: cyclePhase,
                computedAtUtc: computedAtUtc,
                algorithmVersion: algorithmVersion,
                source: source,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String localDate,
                required int tzOffsetMin,
                Value<int?> restingHrBpm = const Value.absent(),
                Value<double?> hrvRmssdMs = const Value.absent(),
                Value<double?> hrvSdnnMs = const Value.absent(),
                Value<double?> restingRespRateBpm = const Value.absent(),
                Value<double?> spo2OvernightAvg = const Value.absent(),
                Value<int?> spo2OvernightMin = const Value.absent(),
                Value<int?> systolicMmhg = const Value.absent(),
                Value<int?> diastolicMmhg = const Value.absent(),
                Value<int?> sleepTotalMin = const Value.absent(),
                Value<double?> sleepDeepPct = const Value.absent(),
                Value<double?> sleepRemPct = const Value.absent(),
                Value<double?> sleepLightPct = const Value.absent(),
                Value<double?> sleepEfficiencyPct = const Value.absent(),
                Value<int?> bedtimeUtc = const Value.absent(),
                Value<int?> wakeUtc = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<double?> caloriesKcal = const Value.absent(),
                Value<int?> activeMinutes = const Value.absent(),
                Value<double?> stiffnessIndex = const Value.absent(),
                Value<double?> augmentationIndex = const Value.absent(),
                Value<double?> strokeVolumeIndex = const Value.absent(),
                Value<double?> breathingDisruptionsHr = const Value.absent(),
                Value<int?> recoveryScore = const Value.absent(),
                Value<int?> wellnessScore = const Value.absent(),
                Value<int?> cyclePhase = const Value.absent(),
                required int computedAtUtc,
                required String algorithmVersion,
                required DataSource source,
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyMetricsCompanion.insert(
                id: id,
                userId: userId,
                localDate: localDate,
                tzOffsetMin: tzOffsetMin,
                restingHrBpm: restingHrBpm,
                hrvRmssdMs: hrvRmssdMs,
                hrvSdnnMs: hrvSdnnMs,
                restingRespRateBpm: restingRespRateBpm,
                spo2OvernightAvg: spo2OvernightAvg,
                spo2OvernightMin: spo2OvernightMin,
                systolicMmhg: systolicMmhg,
                diastolicMmhg: diastolicMmhg,
                sleepTotalMin: sleepTotalMin,
                sleepDeepPct: sleepDeepPct,
                sleepRemPct: sleepRemPct,
                sleepLightPct: sleepLightPct,
                sleepEfficiencyPct: sleepEfficiencyPct,
                bedtimeUtc: bedtimeUtc,
                wakeUtc: wakeUtc,
                steps: steps,
                distanceM: distanceM,
                caloriesKcal: caloriesKcal,
                activeMinutes: activeMinutes,
                stiffnessIndex: stiffnessIndex,
                augmentationIndex: augmentationIndex,
                strokeVolumeIndex: strokeVolumeIndex,
                breathingDisruptionsHr: breathingDisruptionsHr,
                recoveryScore: recoveryScore,
                wellnessScore: wellnessScore,
                cyclePhase: cyclePhase,
                computedAtUtc: computedAtUtc,
                algorithmVersion: algorithmVersion,
                source: source,
                deletedAtUtc: deletedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DailyMetricsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$DailyMetricsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$DailyMetricsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailyMetricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyMetricsTable,
      DailyMetric,
      $$DailyMetricsTableFilterComposer,
      $$DailyMetricsTableOrderingComposer,
      $$DailyMetricsTableAnnotationComposer,
      $$DailyMetricsTableCreateCompanionBuilder,
      $$DailyMetricsTableUpdateCompanionBuilder,
      (DailyMetric, $$DailyMetricsTableReferences),
      DailyMetric,
      PrefetchHooks Function({bool userId})
    >;
typedef $$SleepSessionsTableCreateCompanionBuilder =
    SleepSessionsCompanion Function({
      required String id,
      required String userId,
      required String deviceId,
      required int startedAtUtc,
      required int capturedTzOffsetMin,
      required DataSource source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      required int createdAtUtc,
      Value<int?> deletedAtUtc,
      required int endedAtUtc,
      required SleepSessionType type,
      required int protocolVersion,
      required int totalMin,
      Value<int> deepMin,
      Value<int> lightMin,
      Value<int> remMin,
      Value<int> awakeMin,
      Value<int> coverageGapMin,
      Value<double?> efficiencyPct,
      Value<bool> hasUnweared,
      Value<int> rowid,
    });
typedef $$SleepSessionsTableUpdateCompanionBuilder =
    SleepSessionsCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> deviceId,
      Value<int> startedAtUtc,
      Value<int> capturedTzOffsetMin,
      Value<DataSource> source,
      Value<int?> quality,
      Value<String?> algorithmVersion,
      Value<int> createdAtUtc,
      Value<int?> deletedAtUtc,
      Value<int> endedAtUtc,
      Value<SleepSessionType> type,
      Value<int> protocolVersion,
      Value<int> totalMin,
      Value<int> deepMin,
      Value<int> lightMin,
      Value<int> remMin,
      Value<int> awakeMin,
      Value<int> coverageGapMin,
      Value<double?> efficiencyPct,
      Value<bool> hasUnweared,
      Value<int> rowid,
    });

final class $$SleepSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SleepSessionsTable, SleepSession> {
  $$SleepSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.sleepSessions.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias(
        $_aliasNameGenerator(db.sleepSessions.deviceId, db.devices.id),
      );

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SleepEpochsTable, List<SleepEpoch>>
  _sleepEpochsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sleepEpochs,
    aliasName: $_aliasNameGenerator(
      db.sleepSessions.id,
      db.sleepEpochs.sessionId,
    ),
  );

  $$SleepEpochsTableProcessedTableManager get sleepEpochsRefs {
    final manager = $$SleepEpochsTableTableManager(
      $_db,
      $_db.sleepEpochs,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sleepEpochsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SleepSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SleepSessionType, SleepSessionType, int>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalMin => $composableBuilder(
    column: $table.totalMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deepMin => $composableBuilder(
    column: $table.deepMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lightMin => $composableBuilder(
    column: $table.lightMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remMin => $composableBuilder(
    column: $table.remMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get awakeMin => $composableBuilder(
    column: $table.awakeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverageGapMin => $composableBuilder(
    column: $table.coverageGapMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get efficiencyPct => $composableBuilder(
    column: $table.efficiencyPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUnweared => $composableBuilder(
    column: $table.hasUnweared,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sleepEpochsRefs(
    Expression<bool> Function($$SleepEpochsTableFilterComposer f) f,
  ) {
    final $$SleepEpochsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepEpochs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepEpochsTableFilterComposer(
            $db: $db,
            $table: $db.sleepEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SleepSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalMin => $composableBuilder(
    column: $table.totalMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deepMin => $composableBuilder(
    column: $table.deepMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lightMin => $composableBuilder(
    column: $table.lightMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remMin => $composableBuilder(
    column: $table.remMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get awakeMin => $composableBuilder(
    column: $table.awakeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverageGapMin => $composableBuilder(
    column: $table.coverageGapMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get efficiencyPct => $composableBuilder(
    column: $table.efficiencyPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUnweared => $composableBuilder(
    column: $table.hasUnweared,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SleepSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SleepSessionsTable> {
  $$SleepSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedTzOffsetMin => $composableBuilder(
    column: $table.capturedTzOffsetMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endedAtUtc => $composableBuilder(
    column: $table.endedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SleepSessionType, int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get protocolVersion => $composableBuilder(
    column: $table.protocolVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalMin =>
      $composableBuilder(column: $table.totalMin, builder: (column) => column);

  GeneratedColumn<int> get deepMin =>
      $composableBuilder(column: $table.deepMin, builder: (column) => column);

  GeneratedColumn<int> get lightMin =>
      $composableBuilder(column: $table.lightMin, builder: (column) => column);

  GeneratedColumn<int> get remMin =>
      $composableBuilder(column: $table.remMin, builder: (column) => column);

  GeneratedColumn<int> get awakeMin =>
      $composableBuilder(column: $table.awakeMin, builder: (column) => column);

  GeneratedColumn<int> get coverageGapMin => $composableBuilder(
    column: $table.coverageGapMin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get efficiencyPct => $composableBuilder(
    column: $table.efficiencyPct,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasUnweared => $composableBuilder(
    column: $table.hasUnweared,
    builder: (column) => column,
  );

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sleepEpochsRefs<T extends Object>(
    Expression<T> Function($$SleepEpochsTableAnnotationComposer a) f,
  ) {
    final $$SleepEpochsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sleepEpochs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepEpochsTableAnnotationComposer(
            $db: $db,
            $table: $db.sleepEpochs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SleepSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SleepSessionsTable,
          SleepSession,
          $$SleepSessionsTableFilterComposer,
          $$SleepSessionsTableOrderingComposer,
          $$SleepSessionsTableAnnotationComposer,
          $$SleepSessionsTableCreateCompanionBuilder,
          $$SleepSessionsTableUpdateCompanionBuilder,
          (SleepSession, $$SleepSessionsTableReferences),
          SleepSession,
          PrefetchHooks Function({
            bool userId,
            bool deviceId,
            bool sleepEpochsRefs,
          })
        > {
  $$SleepSessionsTableTableManager(_$AppDatabase db, $SleepSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SleepSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SleepSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SleepSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> startedAtUtc = const Value.absent(),
                Value<int> capturedTzOffsetMin = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<int> endedAtUtc = const Value.absent(),
                Value<SleepSessionType> type = const Value.absent(),
                Value<int> protocolVersion = const Value.absent(),
                Value<int> totalMin = const Value.absent(),
                Value<int> deepMin = const Value.absent(),
                Value<int> lightMin = const Value.absent(),
                Value<int> remMin = const Value.absent(),
                Value<int> awakeMin = const Value.absent(),
                Value<int> coverageGapMin = const Value.absent(),
                Value<double?> efficiencyPct = const Value.absent(),
                Value<bool> hasUnweared = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SleepSessionsCompanion(
                id: id,
                userId: userId,
                deviceId: deviceId,
                startedAtUtc: startedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                endedAtUtc: endedAtUtc,
                type: type,
                protocolVersion: protocolVersion,
                totalMin: totalMin,
                deepMin: deepMin,
                lightMin: lightMin,
                remMin: remMin,
                awakeMin: awakeMin,
                coverageGapMin: coverageGapMin,
                efficiencyPct: efficiencyPct,
                hasUnweared: hasUnweared,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String deviceId,
                required int startedAtUtc,
                required int capturedTzOffsetMin,
                required DataSource source,
                Value<int?> quality = const Value.absent(),
                Value<String?> algorithmVersion = const Value.absent(),
                required int createdAtUtc,
                Value<int?> deletedAtUtc = const Value.absent(),
                required int endedAtUtc,
                required SleepSessionType type,
                required int protocolVersion,
                required int totalMin,
                Value<int> deepMin = const Value.absent(),
                Value<int> lightMin = const Value.absent(),
                Value<int> remMin = const Value.absent(),
                Value<int> awakeMin = const Value.absent(),
                Value<int> coverageGapMin = const Value.absent(),
                Value<double?> efficiencyPct = const Value.absent(),
                Value<bool> hasUnweared = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SleepSessionsCompanion.insert(
                id: id,
                userId: userId,
                deviceId: deviceId,
                startedAtUtc: startedAtUtc,
                capturedTzOffsetMin: capturedTzOffsetMin,
                source: source,
                quality: quality,
                algorithmVersion: algorithmVersion,
                createdAtUtc: createdAtUtc,
                deletedAtUtc: deletedAtUtc,
                endedAtUtc: endedAtUtc,
                type: type,
                protocolVersion: protocolVersion,
                totalMin: totalMin,
                deepMin: deepMin,
                lightMin: lightMin,
                remMin: remMin,
                awakeMin: awakeMin,
                coverageGapMin: coverageGapMin,
                efficiencyPct: efficiencyPct,
                hasUnweared: hasUnweared,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SleepSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({userId = false, deviceId = false, sleepEpochsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sleepEpochsRefs) db.sleepEpochs,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (userId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.userId,
                                    referencedTable:
                                        $$SleepSessionsTableReferences
                                            ._userIdTable(db),
                                    referencedColumn:
                                        $$SleepSessionsTableReferences
                                            ._userIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (deviceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.deviceId,
                                    referencedTable:
                                        $$SleepSessionsTableReferences
                                            ._deviceIdTable(db),
                                    referencedColumn:
                                        $$SleepSessionsTableReferences
                                            ._deviceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sleepEpochsRefs)
                        await $_getPrefetchedData<
                          SleepSession,
                          $SleepSessionsTable,
                          SleepEpoch
                        >(
                          currentTable: table,
                          referencedTable: $$SleepSessionsTableReferences
                              ._sleepEpochsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SleepSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).sleepEpochsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SleepSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SleepSessionsTable,
      SleepSession,
      $$SleepSessionsTableFilterComposer,
      $$SleepSessionsTableOrderingComposer,
      $$SleepSessionsTableAnnotationComposer,
      $$SleepSessionsTableCreateCompanionBuilder,
      $$SleepSessionsTableUpdateCompanionBuilder,
      (SleepSession, $$SleepSessionsTableReferences),
      SleepSession,
      PrefetchHooks Function({bool userId, bool deviceId, bool sleepEpochsRefs})
    >;
typedef $$SleepEpochsTableCreateCompanionBuilder =
    SleepEpochsCompanion Function({
      required String id,
      required String sessionId,
      required String userId,
      required int startedAtUtc,
      required int durationMin,
      required SleepStage stage,
      required DataSource source,
      required int createdAtUtc,
      Value<int> rowid,
    });
typedef $$SleepEpochsTableUpdateCompanionBuilder =
    SleepEpochsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> userId,
      Value<int> startedAtUtc,
      Value<int> durationMin,
      Value<SleepStage> stage,
      Value<DataSource> source,
      Value<int> createdAtUtc,
      Value<int> rowid,
    });

final class $$SleepEpochsTableReferences
    extends BaseReferences<_$AppDatabase, $SleepEpochsTable, SleepEpoch> {
  $$SleepEpochsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SleepSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sleepSessions.createAlias(
        $_aliasNameGenerator(db.sleepEpochs.sessionId, db.sleepSessions.id),
      );

  $$SleepSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SleepSessionsTableTableManager(
      $_db,
      $_db.sleepSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.sleepEpochs.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SleepEpochsTableFilterComposer
    extends Composer<_$AppDatabase, $SleepEpochsTable> {
  $$SleepEpochsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SleepStage, SleepStage, int> get stage =>
      $composableBuilder(
        column: $table.stage,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DataSource, DataSource, int> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$SleepSessionsTableFilterComposer get sessionId {
    final $$SleepSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableFilterComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SleepEpochsTableOrderingComposer
    extends Composer<_$AppDatabase, $SleepEpochsTable> {
  $$SleepEpochsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$SleepSessionsTableOrderingComposer get sessionId {
    final $$SleepSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SleepEpochsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SleepEpochsTable> {
  $$SleepEpochsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMin => $composableBuilder(
    column: $table.durationMin,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SleepStage, int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DataSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  $$SleepSessionsTableAnnotationComposer get sessionId {
    final $$SleepSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sleepSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SleepSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sleepSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SleepEpochsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SleepEpochsTable,
          SleepEpoch,
          $$SleepEpochsTableFilterComposer,
          $$SleepEpochsTableOrderingComposer,
          $$SleepEpochsTableAnnotationComposer,
          $$SleepEpochsTableCreateCompanionBuilder,
          $$SleepEpochsTableUpdateCompanionBuilder,
          (SleepEpoch, $$SleepEpochsTableReferences),
          SleepEpoch,
          PrefetchHooks Function({bool sessionId, bool userId})
        > {
  $$SleepEpochsTableTableManager(_$AppDatabase db, $SleepEpochsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SleepEpochsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SleepEpochsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SleepEpochsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<int> startedAtUtc = const Value.absent(),
                Value<int> durationMin = const Value.absent(),
                Value<SleepStage> stage = const Value.absent(),
                Value<DataSource> source = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SleepEpochsCompanion(
                id: id,
                sessionId: sessionId,
                userId: userId,
                startedAtUtc: startedAtUtc,
                durationMin: durationMin,
                stage: stage,
                source: source,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String userId,
                required int startedAtUtc,
                required int durationMin,
                required SleepStage stage,
                required DataSource source,
                required int createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => SleepEpochsCompanion.insert(
                id: id,
                sessionId: sessionId,
                userId: userId,
                startedAtUtc: startedAtUtc,
                durationMin: durationMin,
                stage: stage,
                source: source,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SleepEpochsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$SleepEpochsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$SleepEpochsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$SleepEpochsTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$SleepEpochsTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SleepEpochsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SleepEpochsTable,
      SleepEpoch,
      $$SleepEpochsTableFilterComposer,
      $$SleepEpochsTableOrderingComposer,
      $$SleepEpochsTableAnnotationComposer,
      $$SleepEpochsTableCreateCompanionBuilder,
      $$SleepEpochsTableUpdateCompanionBuilder,
      (SleepEpoch, $$SleepEpochsTableReferences),
      SleepEpoch,
      PrefetchHooks Function({bool sessionId, bool userId})
    >;
typedef $$BaselinesTableCreateCompanionBuilder =
    BaselinesCompanion Function({
      required String id,
      required String userId,
      required String metricKey,
      required int windowDays,
      required String computedForDate,
      required double meanValue,
      required double stddevValue,
      required int sampleCount,
      required int computedAtUtc,
      required String algorithmVersion,
      Value<int> rowid,
    });
typedef $$BaselinesTableUpdateCompanionBuilder =
    BaselinesCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> metricKey,
      Value<int> windowDays,
      Value<String> computedForDate,
      Value<double> meanValue,
      Value<double> stddevValue,
      Value<int> sampleCount,
      Value<int> computedAtUtc,
      Value<String> algorithmVersion,
      Value<int> rowid,
    });

final class $$BaselinesTableReferences
    extends BaseReferences<_$AppDatabase, $BaselinesTable, Baseline> {
  $$BaselinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UsersTable _userIdTable(_$AppDatabase db) => db.users.createAlias(
    $_aliasNameGenerator(db.baselines.userId, db.users.id),
  );

  $$UsersTableProcessedTableManager get userId {
    final $_column = $_itemColumn<String>('user_id')!;

    final manager = $$UsersTableTableManager(
      $_db,
      $_db.users,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_userIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BaselinesTableFilterComposer
    extends Composer<_$AppDatabase, $BaselinesTable> {
  $$BaselinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricKey => $composableBuilder(
    column: $table.metricKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowDays => $composableBuilder(
    column: $table.windowDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get computedForDate => $composableBuilder(
    column: $table.computedForDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meanValue => $composableBuilder(
    column: $table.meanValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stddevValue => $composableBuilder(
    column: $table.stddevValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$UsersTableFilterComposer get userId {
    final $$UsersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableFilterComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BaselinesTableOrderingComposer
    extends Composer<_$AppDatabase, $BaselinesTable> {
  $$BaselinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricKey => $composableBuilder(
    column: $table.metricKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowDays => $composableBuilder(
    column: $table.windowDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get computedForDate => $composableBuilder(
    column: $table.computedForDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meanValue => $composableBuilder(
    column: $table.meanValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stddevValue => $composableBuilder(
    column: $table.stddevValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$UsersTableOrderingComposer get userId {
    final $$UsersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableOrderingComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BaselinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BaselinesTable> {
  $$BaselinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metricKey =>
      $composableBuilder(column: $table.metricKey, builder: (column) => column);

  GeneratedColumn<int> get windowDays => $composableBuilder(
    column: $table.windowDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get computedForDate => $composableBuilder(
    column: $table.computedForDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get meanValue =>
      $composableBuilder(column: $table.meanValue, builder: (column) => column);

  GeneratedColumn<double> get stddevValue => $composableBuilder(
    column: $table.stddevValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get computedAtUtc => $composableBuilder(
    column: $table.computedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );

  $$UsersTableAnnotationComposer get userId {
    final $$UsersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.userId,
      referencedTable: $db.users,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UsersTableAnnotationComposer(
            $db: $db,
            $table: $db.users,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BaselinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BaselinesTable,
          Baseline,
          $$BaselinesTableFilterComposer,
          $$BaselinesTableOrderingComposer,
          $$BaselinesTableAnnotationComposer,
          $$BaselinesTableCreateCompanionBuilder,
          $$BaselinesTableUpdateCompanionBuilder,
          (Baseline, $$BaselinesTableReferences),
          Baseline,
          PrefetchHooks Function({bool userId})
        > {
  $$BaselinesTableTableManager(_$AppDatabase db, $BaselinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BaselinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BaselinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BaselinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> metricKey = const Value.absent(),
                Value<int> windowDays = const Value.absent(),
                Value<String> computedForDate = const Value.absent(),
                Value<double> meanValue = const Value.absent(),
                Value<double> stddevValue = const Value.absent(),
                Value<int> sampleCount = const Value.absent(),
                Value<int> computedAtUtc = const Value.absent(),
                Value<String> algorithmVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BaselinesCompanion(
                id: id,
                userId: userId,
                metricKey: metricKey,
                windowDays: windowDays,
                computedForDate: computedForDate,
                meanValue: meanValue,
                stddevValue: stddevValue,
                sampleCount: sampleCount,
                computedAtUtc: computedAtUtc,
                algorithmVersion: algorithmVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String metricKey,
                required int windowDays,
                required String computedForDate,
                required double meanValue,
                required double stddevValue,
                required int sampleCount,
                required int computedAtUtc,
                required String algorithmVersion,
                Value<int> rowid = const Value.absent(),
              }) => BaselinesCompanion.insert(
                id: id,
                userId: userId,
                metricKey: metricKey,
                windowDays: windowDays,
                computedForDate: computedForDate,
                meanValue: meanValue,
                stddevValue: stddevValue,
                sampleCount: sampleCount,
                computedAtUtc: computedAtUtc,
                algorithmVersion: algorithmVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BaselinesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({userId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (userId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.userId,
                                referencedTable: $$BaselinesTableReferences
                                    ._userIdTable(db),
                                referencedColumn: $$BaselinesTableReferences
                                    ._userIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BaselinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BaselinesTable,
      Baseline,
      $$BaselinesTableFilterComposer,
      $$BaselinesTableOrderingComposer,
      $$BaselinesTableAnnotationComposer,
      $$BaselinesTableCreateCompanionBuilder,
      $$BaselinesTableUpdateCompanionBuilder,
      (Baseline, $$BaselinesTableReferences),
      Baseline,
      PrefetchHooks Function({bool userId})
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String id,
      required String deviceId,
      required String metricKey,
      Value<int?> lastSuccessfulSyncUtc,
      Value<int?> lastAttemptedSyncUtc,
      Value<String?> lastSyncError,
      Value<int?> lastSyncedDayIndex,
      Value<int> bytesSyncedLifetime,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String> metricKey,
      Value<int?> lastSuccessfulSyncUtc,
      Value<int?> lastAttemptedSyncUtc,
      Value<String?> lastSyncError,
      Value<int?> lastSyncedDayIndex,
      Value<int> bytesSyncedLifetime,
      Value<int> rowid,
    });

final class $$SyncStateTableReferences
    extends BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData> {
  $$SyncStateTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DevicesTable _deviceIdTable(_$AppDatabase db) => db.devices
      .createAlias($_aliasNameGenerator(db.syncState.deviceId, db.devices.id));

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricKey => $composableBuilder(
    column: $table.metricKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessfulSyncUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAttemptedSyncUtc => $composableBuilder(
    column: $table.lastAttemptedSyncUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedDayIndex => $composableBuilder(
    column: $table.lastSyncedDayIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesSyncedLifetime => $composableBuilder(
    column: $table.bytesSyncedLifetime,
    builder: (column) => ColumnFilters(column),
  );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricKey => $composableBuilder(
    column: $table.metricKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessfulSyncUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptedSyncUtc => $composableBuilder(
    column: $table.lastAttemptedSyncUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedDayIndex => $composableBuilder(
    column: $table.lastSyncedDayIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesSyncedLifetime => $composableBuilder(
    column: $table.bytesSyncedLifetime,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metricKey =>
      $composableBuilder(column: $table.metricKey, builder: (column) => column);

  GeneratedColumn<int> get lastSuccessfulSyncUtc => $composableBuilder(
    column: $table.lastSuccessfulSyncUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAttemptedSyncUtc => $composableBuilder(
    column: $table.lastAttemptedSyncUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncError => $composableBuilder(
    column: $table.lastSyncError,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncedDayIndex => $composableBuilder(
    column: $table.lastSyncedDayIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesSyncedLifetime => $composableBuilder(
    column: $table.bytesSyncedLifetime,
    builder: (column) => column,
  );

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (SyncStateData, $$SyncStateTableReferences),
          SyncStateData,
          PrefetchHooks Function({bool deviceId})
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> metricKey = const Value.absent(),
                Value<int?> lastSuccessfulSyncUtc = const Value.absent(),
                Value<int?> lastAttemptedSyncUtc = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int?> lastSyncedDayIndex = const Value.absent(),
                Value<int> bytesSyncedLifetime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                deviceId: deviceId,
                metricKey: metricKey,
                lastSuccessfulSyncUtc: lastSuccessfulSyncUtc,
                lastAttemptedSyncUtc: lastAttemptedSyncUtc,
                lastSyncError: lastSyncError,
                lastSyncedDayIndex: lastSyncedDayIndex,
                bytesSyncedLifetime: bytesSyncedLifetime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String metricKey,
                Value<int?> lastSuccessfulSyncUtc = const Value.absent(),
                Value<int?> lastAttemptedSyncUtc = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int?> lastSyncedDayIndex = const Value.absent(),
                Value<int> bytesSyncedLifetime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                deviceId: deviceId,
                metricKey: metricKey,
                lastSuccessfulSyncUtc: lastSuccessfulSyncUtc,
                lastAttemptedSyncUtc: lastAttemptedSyncUtc,
                lastSyncError: lastSyncError,
                lastSyncedDayIndex: lastSyncedDayIndex,
                bytesSyncedLifetime: bytesSyncedLifetime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SyncStateTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deviceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable: $$SyncStateTableReferences
                                    ._deviceIdTable(db),
                                referencedColumn: $$SyncStateTableReferences
                                    ._deviceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (SyncStateData, $$SyncStateTableReferences),
      SyncStateData,
      PrefetchHooks Function({bool deviceId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$HrSamplesTableTableManager get hrSamples =>
      $$HrSamplesTableTableManager(_db, _db.hrSamples);
  $$HrvSamplesTableTableManager get hrvSamples =>
      $$HrvSamplesTableTableManager(_db, _db.hrvSamples);
  $$Spo2SamplesTableTableManager get spo2Samples =>
      $$Spo2SamplesTableTableManager(_db, _db.spo2Samples);
  $$BpReadingsTableTableManager get bpReadings =>
      $$BpReadingsTableTableManager(_db, _db.bpReadings);
  $$StepBucketsTableTableManager get stepBuckets =>
      $$StepBucketsTableTableManager(_db, _db.stepBuckets);
  $$DailyMetricsTableTableManager get dailyMetrics =>
      $$DailyMetricsTableTableManager(_db, _db.dailyMetrics);
  $$SleepSessionsTableTableManager get sleepSessions =>
      $$SleepSessionsTableTableManager(_db, _db.sleepSessions);
  $$SleepEpochsTableTableManager get sleepEpochs =>
      $$SleepEpochsTableTableManager(_db, _db.sleepEpochs);
  $$BaselinesTableTableManager get baselines =>
      $$BaselinesTableTableManager(_db, _db.baselines);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
