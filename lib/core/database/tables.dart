import 'package:drift/drift.dart';
import 'package:hlth_app/core/database/enums.dart';

// ============================================================================
// HLTH local SQLite schema — drift table definitions.
//
// Specification: hlth-db-schema.md (the canonical column-level contract).
// Every table below cites the section it implements.
//
// Universal rules (hlth-db-schema.md §"Design principles"):
//   • UUID v4 TEXT primary keys.
//   • Unix-seconds INTEGER for all timestamps (never DATETIME).
//   • Every health row has 8+ provenance columns (see the HealthRow mixin
//     below). Soft delete via nullable `deleted_at_utc`.
//   • Composite UNIQUE on (user_id, device_id, captured_at_utc, source)
//     for idempotent re-syncs.
//   • SQL table names: snake_case plural.  Dart classes: PascalCase
//     singular (drift handles the mapping automatically).
// ============================================================================

// ─── Universal mixin ────────────────────────────────────────────────────────
// hlth-db-schema.md §3.0 — every health metric table has these columns.
// We can't share columns across tables via dart inheritance with drift, so
// the mixin is plain Dart we paste into each table. (Drift 2.x doesn't yet
// support reusable column sets via mixins; spec acknowledges this.)
//
// Convention used below: declare the 8 universal columns FIRST in every
// metric table, in the same order, so diffs are clean.

// ─── Section 1 — Identity ───────────────────────────────────────────────────

/// hlth-db-schema.md §1.1
class Users extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get email => text().nullable().unique()();
  TextColumn get phone => text().nullable().unique()();
  TextColumn get displayName => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get updatedAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §1.2
class UserProfiles extends Table {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get dateOfBirth => text().nullable()(); // YYYY-MM-DD
  IntColumn get sexAtBirth =>
      intEnum<SexAtBirth>().withDefault(const Constant(2))(); // unknown
  RealColumn get heightCm => real().nullable()();
  RealColumn get weightKg => real().nullable()();
  BoolColumn get usesMetric => boolean().withDefault(const Constant(true))();
  BoolColumn get uses24hClock => boolean().withDefault(const Constant(true))();
  IntColumn get restingHrBaseline => integer().nullable()();
  BoolColumn get cycleTrackingEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get lastPeriodStartDate => text().nullable()(); // YYYY-MM-DD
  IntColumn get typicalCycleLength => integer().nullable()();
  IntColumn get updatedAtUtc => integer()();

  @override
  Set<Column> get primaryKey => {userId};
}

// ─── Section 2 — Devices ────────────────────────────────────────────────────

/// hlth-db-schema.md §2.1
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get macAddress => text().nullable().unique()();
  TextColumn get iosPeripheralUuid => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get model => text().nullable()();
  TextColumn get hardwareVersion => text().nullable()();
  TextColumn get firmwareVersion => text().nullable()();
  TextColumn get userIdOnBand => text().nullable()();
  IntColumn get pairedAtUtc => integer()();
  IntColumn get lastConnectedAtUtc => integer().nullable()();
  IntColumn get lastBatteryPercent => integer().nullable()();
  BoolColumn get lastCharging => boolean().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get capabilities =>
      text().withDefault(const Constant('{}'))(); // JSON, §2.2
  IntColumn get deletedAtUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Section 3 — Time-series health metrics ─────────────────────────────────

/// hlth-db-schema.md §3.1
class HrSamples extends Table {
  // Universal §3.0
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get capturedAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()(); // 0-100
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  // Metric-specific
  IntColumn get bpm => integer()(); // 30-220 valid range
  IntColumn get intervalMin => integer()(); // 1, 5, 10, 15, 30, 60
  BoolColumn get isResting => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §3.2
class HrvSamples extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get capturedAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()();
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  RealColumn get rmssdMs => real()(); // primary metric
  RealColumn get sdnnMs => real().nullable()();
  RealColumn get pnn50Pct => real().nullable()();
  IntColumn get meanHrBpm => integer().nullable()();
  IntColumn get beatCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §3.4
class Spo2Samples extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get capturedAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()();
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  IntColumn get pctMin => integer()(); // 70-100
  IntColumn get pctMax => integer()();
  IntColumn get bucketMin => integer()(); // 1 (interval) or 60 (hourly)

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §3.5
class BpReadings extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get capturedAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()();
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  IntColumn get systolicMmhg => integer()(); // 70-200
  IntColumn get diastolicMmhg => integer()(); // 40-130
  IntColumn get pulseBpm => integer().nullable()();
  IntColumn get derivation => intEnum<BpDerivation>()();
  IntColumn get position => integer().nullable()(); // 0=sit, 1=lie, 2=stand

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Section 4 — Activity, sleep ────────────────────────────────────────────

/// hlth-db-schema.md §4.1 — 15-minute step buckets.
class StepBuckets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get bucketStartAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()();
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  IntColumn get steps => integer()();
  IntColumn get distanceM => integer()();
  RealColumn get caloriesKcal => real()();
  IntColumn get runSteps => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §4.2 — derived daily rollups.
class DailyMetrics extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get localDate => text()(); // YYYY-MM-DD
  IntColumn get tzOffsetMin => integer()();
  // Cardiac
  IntColumn get restingHrBpm => integer().nullable()();
  RealColumn get hrvRmssdMs => real().nullable()();
  RealColumn get hrvSdnnMs => real().nullable()();
  RealColumn get restingRespRateBpm => real().nullable()();
  // SpO2
  RealColumn get spo2OvernightAvg => real().nullable()();
  IntColumn get spo2OvernightMin => integer().nullable()();
  // BP
  IntColumn get systolicMmhg => integer().nullable()();
  IntColumn get diastolicMmhg => integer().nullable()();
  // Sleep
  IntColumn get sleepTotalMin => integer().nullable()();
  RealColumn get sleepDeepPct => real().nullable()();
  RealColumn get sleepRemPct => real().nullable()();
  RealColumn get sleepLightPct => real().nullable()();
  RealColumn get sleepEfficiencyPct => real().nullable()();
  IntColumn get bedtimeUtc => integer().nullable()();
  IntColumn get wakeUtc => integer().nullable()();
  // Activity
  IntColumn get steps => integer().nullable()();
  IntColumn get distanceM => integer().nullable()();
  RealColumn get caloriesKcal => real().nullable()();
  IntColumn get activeMinutes => integer().nullable()();
  // Vascular / cardiac advanced
  RealColumn get stiffnessIndex => real().nullable()();
  RealColumn get augmentationIndex => real().nullable()();
  RealColumn get strokeVolumeIndex => real().nullable()();
  RealColumn get breathingDisruptionsHr => real().nullable()();
  // Scores (snapshot only — full history lives in `scores`)
  IntColumn get recoveryScore => integer().nullable()();
  IntColumn get wellnessScore => integer().nullable()();
  // Cycle
  IntColumn get cyclePhase => integer().nullable()();
  // Provenance
  IntColumn get computedAtUtc => integer()();
  TextColumn get algorithmVersion => text()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get deletedAtUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §4.3
class SleepSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get startedAtUtc => integer()();
  IntColumn get capturedTzOffsetMin => integer()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get quality => integer().nullable()();
  TextColumn get algorithmVersion => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();
  IntColumn get endedAtUtc => integer()();
  IntColumn get type => intEnum<SleepSessionType>()();
  IntColumn get protocolVersion => integer()(); // 1=old (no REM), 2=new
  IntColumn get totalMin => integer()();
  IntColumn get deepMin => integer().withDefault(const Constant(0))();
  IntColumn get lightMin => integer().withDefault(const Constant(0))();
  IntColumn get remMin => integer().withDefault(const Constant(0))();
  IntColumn get awakeMin => integer().withDefault(const Constant(0))();
  IntColumn get coverageGapMin => integer().withDefault(const Constant(0))();
  RealColumn get efficiencyPct => real().nullable()();
  BoolColumn get hasUnweared => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// hlth-db-schema.md §4.4 — per-epoch stages (hypnogram).
class SleepEpochs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SleepSessions, #id)();
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get startedAtUtc => integer()();
  IntColumn get durationMin => integer()();
  IntColumn get stage => intEnum<SleepStage>()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get createdAtUtc => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Section 6 — Derived ────────────────────────────────────────────────────

/// hlth-db-schema.md §6.1 — rolling baselines (14/30/90-day).
class Baselines extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get metricKey => text()(); // 'resting_hr_bpm', etc.
  IntColumn get windowDays => integer()(); // 14, 30, 90
  TextColumn get computedForDate => text()(); // YYYY-MM-DD
  RealColumn get meanValue => real()();
  RealColumn get stddevValue => real()();
  IntColumn get sampleCount => integer()();
  IntColumn get computedAtUtc => integer()();
  TextColumn get algorithmVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Section 8 — Operational ────────────────────────────────────────────────

/// hlth-db-schema.md §8.1 — per-device per-metric sync watermark.
class SyncState extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text().references(Devices, #id)();
  TextColumn get metricKey => text()(); // 'hr', 'hrv', 'spo2', 'bp', etc.
  IntColumn get lastSuccessfulSyncUtc => integer().nullable()();
  IntColumn get lastAttemptedSyncUtc => integer().nullable()();
  TextColumn get lastSyncError => text().nullable()();
  IntColumn get lastSyncedDayIndex => integer().nullable()();
  IntColumn get bytesSyncedLifetime =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
