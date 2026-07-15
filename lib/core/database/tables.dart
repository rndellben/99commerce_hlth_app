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

/// Stress samples — band-side "pressure" feature, mirrors HRV shape.
/// Each sample is one slot in the band's scheduled pressureArray (typically
/// 30-min slot resolution, value 0-100). Source PressureRsp via
/// BleOperateManager.getPressure(dayIdx, ...).
class StressSamples extends Table {
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
  IntColumn get stressScore => integer()(); // 0-100
  IntColumn get rangeMin => integer()(); // slot duration (typically 30)

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
  // Rhythm — irregular-heartbeat screen (raw R-R, pre-ectopic-cleaning)
  RealColumn get rrIrregularityPct => real().nullable()();
  RealColumn get ectopicBeatPct => real().nullable()();
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

/// hlth-db-schema.md §6.2 — user-entered cuff readings used to personalize
/// BP estimates. Each row is one calibration event; `is_active = 1` flags
/// the currently-applied calibration. Historical rows are retained so
/// past `bp_readings.calibrated_against_id` references stay valid.
class BpCalibrations extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get capturedAtUtc => integer()();
  IntColumn get cuffSystolic => integer()(); // 70-200 mmHg
  IntColumn get cuffDiastolic => integer()(); // 40-130 mmHg
  // Band's reading at the same moment, if available. Lets us compute the
  // offset retroactively or evaluate calibration drift.
  IntColumn get bandSystolic => integer().nullable()();
  IntColumn get bandDiastolic => integer().nullable()();
  // HR at the moment the cuff reading was taken — needed to reapply the
  // band's `cal_sbp(hr, age) → sbp` formula in reverse when computing
  // future calibrated readings.
  IntColumn get hrAtCalibration => integer().nullable()();
  // User's age at calibration time, captured here so the formula stays
  // stable even if the profile age changes later.
  IntColumn get ageAtCalibration => integer().nullable()();
  // Whether this calibration was successfully written to the band via
  // TimeFormatReq (the SDK's "set personal info" path). False means we
  // have the row locally but the band still has its old anchor.
  BoolColumn get bandWriteSucceeded =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAtUtc => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

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

/// hlth-db-schema.md §6.3 — computed daily scores (recovery, wellness,
/// cardio load, …). One row per (user, score_type, day). `components` holds the
/// per-input breakdown as a JSON string for debug/telemetry.
class Scores extends Table {
  TextColumn get id => text()(); // deterministic: "$userId:$scoreType:$date"
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get scoreType => intEnum<ScoreType>()();
  TextColumn get computedForDate => text()(); // YYYY-MM-DD
  RealColumn get score => real()(); // 0..100 (one decimal)
  RealColumn get rawScore => real().nullable()();
  TextColumn get label => text().nullable()();
  RealColumn get confidence => real().nullable()();
  BoolColumn get provisional => boolean().withDefault(const Constant(false))();
  TextColumn get components => text().nullable()(); // JSON breakdown
  IntColumn get computedAtUtc => integer()();
  TextColumn get algorithmVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Ryan's Vascular Load NightlyRecord (NIGHTLY_RECORD_SCHEMA.md §1) —
/// the tiny per-session struct the score reads. Persisted because the
/// retention sweep deletes the raw hr/hrv/stress samples it's reduced
/// from, so old nights can't be re-reduced. `localDate` is the sleep
/// (wake) date as YYYY-MM-DD text, same convention as daily_metrics.
class NightlyRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get localDate => text()(); // YYYY-MM-DD (wake date)
  RealColumn get hrP5 => real().nullable()();
  RealColumn get rmssdMedian => real().nullable()();
  RealColumn get stressMean => real().nullable()();
  RealColumn get coverage => real().withDefault(const Constant(0))();
  BoolColumn get valid => boolean().withDefault(const Constant(false))();
  IntColumn get computedAtUtc => integer()();
  TextColumn get algorithmVersion => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Section 8 — Operational ────────────────────────────────────────────────

/// Cloud sync outbox — queued upserts waiting to be pushed to Supabase.
/// Processed FIFO by CloudSyncService; deleted on successful push.
class CloudSyncOutbox extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get targetTable => text()(); // 'daily_metrics', 'baselines', etc.
  TextColumn get recordId => text()(); // PK of the record to push
  IntColumn get createdAtUtc => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptAtUtc => integer().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Exercise sessions — one row per completed workout pulled from the
/// band via `SportPlusHandle.syncSportPlus`. Source-of-truth is the band's
/// internal workout state machine (sdk_ring.pdf §2.3.10) — the app starts
/// the session with `PhoneSportReq.getSportStatus(1, sportType)` and the
/// band records HR/distance/calories until the app sends status=4 (End).
///
/// Cardinality: 1 row per workout. Band keeps the ~10 most-recent sessions
/// on-device; we sync them down on session end and store indefinitely.
///
/// Note: `sportType` is the raw SDK byte (4=Walking, 7=Running, 9=Cycling,
/// etc. — see SportTypes constants (core/ble/ble_types.dart)). Display label resolution
/// lives in the feature layer.
class ExerciseSessions extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  IntColumn get sportType => integer()();
  IntColumn get startedAtUtc => integer()();
  IntColumn get endedAtUtc => integer().nullable()();
  IntColumn get durationSec => integer()();
  IntColumn get distanceM => integer().withDefault(const Constant(0))();
  RealColumn get calories => real().withDefault(const Constant(0))();
  // Speed in cm/s per SDK spec. Convert to m/s in the display layer.
  IntColumn get avgSpeedCmS => integer().nullable()();
  IntColumn get maxSpeedCmS => integer().nullable()();
  IntColumn get avgHrBpm => integer().nullable()();
  IntColumn get minHrBpm => integer().nullable()();
  IntColumn get maxHrBpm => integer().nullable()();
  IntColumn get steps => integer().nullable()();
  IntColumn get stepRate => integer().nullable()();
  // Vertical movement in cm — only populated for outdoor GPS workouts.
  IntColumn get elevationCm => integer().nullable()();
  IntColumn get uphillCm => integer().nullable()();
  IntColumn get downhillCm => integer().nullable()();
  // Estimated VO2 max for this session (mL/kg/min) + its 0..1 confidence.
  // Computed by Vo2MaxService (Åstrand-Ryhming, Algorithm A) after sync; null
  // when the session didn't qualify or lacked the inputs to estimate.
  RealColumn get vo2maxMl => real().nullable()();
  RealColumn get vo2Confidence => real().nullable()();
  IntColumn get source => intEnum<DataSource>()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get deletedAtUtc => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Battery telemetry — one row per periodic sync tick logging the band's
/// battery %. Used by the BLE Debug "Battery Drain Test" panel to compute
/// %/hr drain at the active cadence and project to 24h. Lightweight:
/// ~144 rows/day at 10-min cadence, ~48/day at 30-min. Not part of the
/// cloud-sync footprint — debug-only data, lives only in local SQLite.
class BatteryTelemetry extends Table {
  TextColumn get id => text()(); // UUID v4
  IntColumn get capturedAtUtc => integer()();
  IntColumn get bandBatteryPercent => integer().nullable()();
  BoolColumn get bandCharging => boolean().nullable()();
  IntColumn get syncIntervalMin => integer()();
  // 'tick' | 'connect' | 'manual'
  TextColumn get eventType => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Log of fired local notifications. Powers rate-limiting / dedup
/// (Ryan: "only show once every 7 days") and an in-app history. One row
/// per *fired* notification. The rate-limit is checked per (userId, type)
/// using the most recent firedAtUtcSec.
class NotificationLog extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get userId => text()();
  /// Stable rule id, e.g. 'hypertension' | 'afib' | 'sleep_apnea' | 'retention'.
  TextColumn get type => text()();
  /// Per-occurrence key for dedup, e.g. 'afib-2026-06-22'.
  TextColumn get dedupeKey => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  /// JSON string for tap-routing payload (nullable).
  TextColumn get payload => text().nullable()();
  /// 'alert' (high importance) | 'retention' (default importance).
  TextColumn get channel => text()();
  IntColumn get firedAtUtcSec => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

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
