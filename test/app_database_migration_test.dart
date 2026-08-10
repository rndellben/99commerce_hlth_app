// Migration tests — these EXECUTE `AppDatabase.migration.onUpgrade` against a
// real SQLite database instead of reading it.
//
// They settle the "Adjacent finding" recorded in
// `docs/plans/2026-08-10-coverage-audit.md` §"Adversarial verification
// 2026-08-10", which was confirmed by source reading only:
//
//   `exercise_sessions` is created by the `from < 5` step with
//   `m.createTable(exerciseSessions)` (app_database.dart:92), and drift's
//   `createTable` emits the CURRENT table definition — which already carries
//   `vo2max_ml` / `vo2_confidence` (tables.dart:475-476). The `from < 10` step
//   then `m.addColumn`s those same two columns (app_database.dart:132-133).
//   Any install at schema 1-4 runs both blocks in the same `onUpgrade`, so the
//   second issues `ALTER TABLE exercise_sessions ADD COLUMN vo2max_ml` against
//   a table that already has it -> SQLite `duplicate column name` -> the
//   migration throws and the database never opens.
//
// Shipped schema versions per git are 1, 2, 3 and 7 (`39806be` jumps 3 -> 7),
// so those four are the versions a real device can be upgrading FROM. All four
// are covered below: 1/2/3 exercise the `createTable`-then-`addColumn` collision,
// and 7 pins the other side of the fix — an install that already has
// `exercise_sessions` WITHOUT the VO2 columns must still get them added.
//
// How the fixture works: `NativeDatabase.memory(setup: ...)` hands us the raw
// sqlite3 handle after it is opened but *before* drift reads `user_version` and
// dispatches `onCreate`/`onUpgrade` (drift 2.28 `lib/src/sqlite3/database.dart`
// `_initializeDatabase`). So `setup` writes the historical schema and stamps
// `user_version`, and drift then runs the real upgrade path on top of it.
//
// The DDL constants below are drift's own emitted output, captured from a live
// `onCreate` over `NativeDatabase.memory()` and then reduced to each historical
// version by removing the tables/columns that the migration steps add. Verified
// against git: `git diff ac06c9a HEAD -- lib/core/database/tables.dart` touches
// exactly three things — `DailyMetrics` gains `rr_irregularity_pct` /
// `ectopic_beat_pct` / `rr_entropy_norm`, and five new table classes appear. No
// pre-v3 table definition changed, so the reduction is exact.

// `show` keeps drift's `isNull` from colliding with matcher's.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/app_database.dart';

// ─── Historical DDL ─────────────────────────────────────────────────────────

/// The 13 tables present at schema 1 (`git show 018a9e0:…/app_database.dart`).
const _v1Tables = <String>[
  'CREATE TABLE "users" ("id" TEXT NOT NULL, "email" TEXT NULL UNIQUE, "phone" TEXT NULL UNIQUE, "display_name" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "updated_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "user_profiles" ("user_id" TEXT NOT NULL REFERENCES users (id), "date_of_birth" TEXT NULL, "sex_at_birth" INTEGER NOT NULL DEFAULT 2, "height_cm" REAL NULL, "weight_kg" REAL NULL, "uses_metric" INTEGER NOT NULL DEFAULT 1 CHECK ("uses_metric" IN (0, 1)), "uses24h_clock" INTEGER NOT NULL DEFAULT 1 CHECK ("uses24h_clock" IN (0, 1)), "resting_hr_baseline" INTEGER NULL, "cycle_tracking_enabled" INTEGER NOT NULL DEFAULT 0 CHECK ("cycle_tracking_enabled" IN (0, 1)), "last_period_start_date" TEXT NULL, "typical_cycle_length" INTEGER NULL, "updated_at_utc" INTEGER NOT NULL, PRIMARY KEY ("user_id"))',
  'CREATE TABLE "devices" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "mac_address" TEXT NULL UNIQUE, "ios_peripheral_uuid" TEXT NULL, "display_name" TEXT NOT NULL, "model" TEXT NULL, "hardware_version" TEXT NULL, "firmware_version" TEXT NULL, "user_id_on_band" TEXT NULL, "paired_at_utc" INTEGER NOT NULL, "last_connected_at_utc" INTEGER NULL, "last_battery_percent" INTEGER NULL, "last_charging" INTEGER NULL CHECK ("last_charging" IN (0, 1)), "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "capabilities" TEXT NOT NULL DEFAULT \'{}\', "deleted_at_utc" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "hr_samples" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "captured_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "bpm" INTEGER NOT NULL, "interval_min" INTEGER NOT NULL, "is_resting" INTEGER NOT NULL DEFAULT 0 CHECK ("is_resting" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "hrv_samples" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "captured_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "rmssd_ms" REAL NOT NULL, "sdnn_ms" REAL NULL, "pnn50_pct" REAL NULL, "mean_hr_bpm" INTEGER NULL, "beat_count" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "spo2_samples" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "captured_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "pct_min" INTEGER NOT NULL, "pct_max" INTEGER NOT NULL, "bucket_min" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "bp_readings" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "captured_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "systolic_mmhg" INTEGER NOT NULL, "diastolic_mmhg" INTEGER NOT NULL, "pulse_bpm" INTEGER NULL, "derivation" INTEGER NOT NULL, "position" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "step_buckets" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "bucket_start_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "steps" INTEGER NOT NULL, "distance_m" INTEGER NOT NULL, "calories_kcal" REAL NOT NULL, "run_steps" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
  // daily_metrics WITHOUT rr_irregularity_pct / ectopic_beat_pct (v7) and
  // rr_entropy_norm (v13) — those arrive via addColumn.
  'CREATE TABLE "daily_metrics" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "local_date" TEXT NOT NULL, "tz_offset_min" INTEGER NOT NULL, "resting_hr_bpm" INTEGER NULL, "hrv_rmssd_ms" REAL NULL, "hrv_sdnn_ms" REAL NULL, "resting_resp_rate_bpm" REAL NULL, "spo2_overnight_avg" REAL NULL, "spo2_overnight_min" INTEGER NULL, "systolic_mmhg" INTEGER NULL, "diastolic_mmhg" INTEGER NULL, "sleep_total_min" INTEGER NULL, "sleep_deep_pct" REAL NULL, "sleep_rem_pct" REAL NULL, "sleep_light_pct" REAL NULL, "sleep_efficiency_pct" REAL NULL, "bedtime_utc" INTEGER NULL, "wake_utc" INTEGER NULL, "steps" INTEGER NULL, "distance_m" INTEGER NULL, "calories_kcal" REAL NULL, "active_minutes" INTEGER NULL, "stiffness_index" REAL NULL, "augmentation_index" REAL NULL, "stroke_volume_index" REAL NULL, "breathing_disruptions_hr" REAL NULL, "recovery_score" INTEGER NULL, "wellness_score" INTEGER NULL, "cycle_phase" INTEGER NULL, "computed_at_utc" INTEGER NOT NULL, "algorithm_version" TEXT NOT NULL, "source" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "sleep_sessions" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "started_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "ended_at_utc" INTEGER NOT NULL, "type" INTEGER NOT NULL, "protocol_version" INTEGER NOT NULL, "total_min" INTEGER NOT NULL, "deep_min" INTEGER NOT NULL DEFAULT 0, "light_min" INTEGER NOT NULL DEFAULT 0, "rem_min" INTEGER NOT NULL DEFAULT 0, "awake_min" INTEGER NOT NULL DEFAULT 0, "coverage_gap_min" INTEGER NOT NULL DEFAULT 0, "efficiency_pct" REAL NULL, "has_unweared" INTEGER NOT NULL DEFAULT 0 CHECK ("has_unweared" IN (0, 1)), PRIMARY KEY ("id"))',
  'CREATE TABLE "sleep_epochs" ("id" TEXT NOT NULL, "session_id" TEXT NOT NULL REFERENCES sleep_sessions (id), "user_id" TEXT NOT NULL REFERENCES users (id), "started_at_utc" INTEGER NOT NULL, "duration_min" INTEGER NOT NULL, "stage" INTEGER NOT NULL, "source" INTEGER NOT NULL, "created_at_utc" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "baselines" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "metric_key" TEXT NOT NULL, "window_days" INTEGER NOT NULL, "computed_for_date" TEXT NOT NULL, "mean_value" REAL NOT NULL, "stddev_value" REAL NOT NULL, "sample_count" INTEGER NOT NULL, "computed_at_utc" INTEGER NOT NULL, "algorithm_version" TEXT NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "sync_state" ("id" TEXT NOT NULL, "device_id" TEXT NOT NULL REFERENCES devices (id), "metric_key" TEXT NOT NULL, "last_successful_sync_utc" INTEGER NULL, "last_attempted_sync_utc" INTEGER NULL, "last_sync_error" TEXT NULL, "last_synced_day_index" INTEGER NULL, "bytes_synced_lifetime" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
];

/// The 22 indices `_createIndices` produced at schema 1.
const _v1Indices = <String>[
  'CREATE INDEX idx_hr_user_time ON hr_samples(user_id, captured_at_utc DESC)',
  'CREATE UNIQUE INDEX idx_hr_dedup ON hr_samples(user_id, device_id, captured_at_utc, source)',
  'CREATE INDEX idx_hr_user_resting ON hr_samples(user_id, captured_at_utc DESC) WHERE is_resting = 1',
  'CREATE INDEX idx_hrv_user_time ON hrv_samples(user_id, captured_at_utc DESC)',
  'CREATE UNIQUE INDEX idx_hrv_dedup ON hrv_samples(user_id, device_id, captured_at_utc, source)',
  'CREATE INDEX idx_spo2_user_time ON spo2_samples(user_id, captured_at_utc DESC)',
  'CREATE UNIQUE INDEX idx_spo2_dedup ON spo2_samples(user_id, device_id, captured_at_utc, source)',
  'CREATE INDEX idx_bp_user_time ON bp_readings(user_id, captured_at_utc DESC)',
  'CREATE UNIQUE INDEX idx_bp_dedup ON bp_readings(user_id, device_id, captured_at_utc, source)',
  'CREATE INDEX idx_bp_user_derivation ON bp_readings(user_id, derivation, captured_at_utc DESC)',
  'CREATE INDEX idx_step_user_day ON step_buckets(user_id, captured_tz_offset_min, bucket_start_at_utc)',
  'CREATE UNIQUE INDEX idx_step_dedup ON step_buckets(user_id, device_id, bucket_start_at_utc, source)',
  'CREATE UNIQUE INDEX idx_daily_user_date ON daily_metrics(user_id, local_date)',
  'CREATE INDEX idx_sleep_user_time ON sleep_sessions(user_id, started_at_utc DESC)',
  'CREATE INDEX idx_epoch_session ON sleep_epochs(session_id, started_at_utc)',
  'CREATE INDEX idx_baseline_user_metric ON baselines(user_id, metric_key, window_days, computed_for_date DESC)',
  'CREATE UNIQUE INDEX idx_baseline_dedup ON baselines(user_id, metric_key, window_days, computed_for_date)',
  'CREATE UNIQUE INDEX idx_sync_state_unique ON sync_state(device_id, metric_key)',
  'CREATE INDEX idx_devices_user_id ON devices(user_id)',
  'CREATE INDEX idx_devices_mac ON devices(mac_address) WHERE mac_address IS NOT NULL',
  'CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL',
  'CREATE INDEX idx_users_phone ON users(phone) WHERE phone IS NOT NULL',
];

/// What each schema bump added on disk, mirroring the corresponding `onUpgrade`
/// step. Keyed by the version the delta produces. Git only ever committed
/// `schemaVersion` 1, 2, 3, 7 and 13, but git is not a distribution record, so
/// every intermediate version is modelled — any of them could have reached a
/// device via an internal build.
const _deltas = <int, List<String>>{
  // v2: stress_samples (`app_database.dart:63-69`).
  2: [
    'CREATE TABLE "stress_samples" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "captured_at_utc" INTEGER NOT NULL, "captured_tz_offset_min" INTEGER NOT NULL, "source" INTEGER NOT NULL, "quality" INTEGER NULL, "algorithm_version" TEXT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, "stress_score" INTEGER NOT NULL, "range_min" INTEGER NOT NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX idx_stress_user_time ON stress_samples(user_id, captured_at_utc DESC)',
    'CREATE UNIQUE INDEX idx_stress_dedup ON stress_samples(user_id, device_id, captured_at_utc, source)',
  ],
  // v3: bp_calibrations + cloud_sync_outbox (`app_database.dart:73-82`).
  3: [
    'CREATE TABLE "bp_calibrations" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "captured_at_utc" INTEGER NOT NULL, "cuff_systolic" INTEGER NOT NULL, "cuff_diastolic" INTEGER NOT NULL, "band_systolic" INTEGER NULL, "band_diastolic" INTEGER NULL, "hr_at_calibration" INTEGER NULL, "age_at_calibration" INTEGER NULL, "band_write_succeeded" INTEGER NOT NULL DEFAULT 0 CHECK ("band_write_succeeded" IN (0, 1)), "notes" TEXT NULL, "is_active" INTEGER NOT NULL DEFAULT 1 CHECK ("is_active" IN (0, 1)), "created_at_utc" INTEGER NOT NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX idx_bpcal_user_time ON bp_calibrations(user_id, captured_at_utc DESC)',
    'CREATE INDEX idx_bpcal_user_active ON bp_calibrations(user_id, is_active, captured_at_utc DESC)',
    'CREATE TABLE "cloud_sync_outbox" ("id" TEXT NOT NULL, "target_table" TEXT NOT NULL, "record_id" TEXT NOT NULL, "created_at_utc" INTEGER NOT NULL, "attempts" INTEGER NOT NULL DEFAULT 0, "last_attempt_at_utc" INTEGER NULL, "last_error" TEXT NULL, PRIMARY KEY ("id"))',
  ],
  // v4: battery_telemetry (`app_database.dart:84-89`).
  4: [
    'CREATE TABLE "battery_telemetry" ("id" TEXT NOT NULL, "captured_at_utc" INTEGER NOT NULL, "band_battery_percent" INTEGER NULL, "band_charging" INTEGER NULL CHECK ("band_charging" IN (0, 1)), "sync_interval_min" INTEGER NOT NULL, "event_type" TEXT NOT NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX idx_battery_time ON battery_telemetry(captured_at_utc DESC)',
  ],
  // v5: exercise_sessions (`app_database.dart:91-99`) — WITHOUT vo2max_ml /
  // vo2_confidence. That is the whole point: at v5 the table had 22 columns,
  // and drift's createTable today emits 24.
  5: [
    'CREATE TABLE "exercise_sessions" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "device_id" TEXT NOT NULL REFERENCES devices (id), "sport_type" INTEGER NOT NULL, "started_at_utc" INTEGER NOT NULL, "ended_at_utc" INTEGER NULL, "duration_sec" INTEGER NOT NULL, "distance_m" INTEGER NOT NULL DEFAULT 0, "calories" REAL NOT NULL DEFAULT 0.0, "avg_speed_cm_s" INTEGER NULL, "max_speed_cm_s" INTEGER NULL, "avg_hr_bpm" INTEGER NULL, "min_hr_bpm" INTEGER NULL, "max_hr_bpm" INTEGER NULL, "steps" INTEGER NULL, "step_rate" INTEGER NULL, "elevation_cm" INTEGER NULL, "uphill_cm" INTEGER NULL, "downhill_cm" INTEGER NULL, "source" INTEGER NOT NULL, "created_at_utc" INTEGER NOT NULL, "deleted_at_utc" INTEGER NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX idx_exercise_user_time ON exercise_sessions(user_id, started_at_utc DESC)',
    'CREATE UNIQUE INDEX idx_exercise_dedup ON exercise_sessions(user_id, device_id, started_at_utc, source)',
  ],
  // v6: notification_log (`app_database.dart:101-106`).
  6: [
    'CREATE TABLE "notification_log" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "type" TEXT NOT NULL, "dedupe_key" TEXT NOT NULL, "title" TEXT NOT NULL, "body" TEXT NOT NULL, "payload" TEXT NULL, "channel" TEXT NOT NULL, "fired_at_utc_sec" INTEGER NOT NULL, PRIMARY KEY ("id"))',
    'CREATE INDEX idx_notiflog_user_type_time ON notification_log(user_id, type, fired_at_utc_sec DESC)',
  ],
  // v7: rhythm columns on daily_metrics (`app_database.dart:109-112`).
  // Appended, which is where addColumn puts them; column order is irrelevant
  // to both the migration and drift's generated (always-named) queries.
  7: [
    'ALTER TABLE daily_metrics ADD COLUMN "rr_irregularity_pct" REAL NULL',
    'ALTER TABLE daily_metrics ADD COLUMN "ectopic_beat_pct" REAL NULL',
  ],
  // v8: scores (`app_database.dart:114-119`).
  8: [
    'CREATE TABLE "scores" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL REFERENCES users (id), "score_type" INTEGER NOT NULL, "computed_for_date" TEXT NOT NULL, "score" REAL NOT NULL, "raw_score" REAL NULL, "label" TEXT NULL, "confidence" REAL NULL, "provisional" INTEGER NOT NULL DEFAULT 0 CHECK ("provisional" IN (0, 1)), "components" TEXT NULL, "computed_at_utc" INTEGER NOT NULL, "algorithm_version" TEXT NOT NULL, PRIMARY KEY ("id"))',
    'CREATE UNIQUE INDEX idx_scores_user_type_date ON scores(user_id, score_type, computed_for_date)',
  ],
  // v9: nightly_records (`app_database.dart:121-127`).
  9: [
    'CREATE TABLE "nightly_records" ("id" TEXT NOT NULL, "user_id" TEXT NOT NULL, "local_date" TEXT NOT NULL, "hr_p5" REAL NULL, "rmssd_median" REAL NULL, "stress_mean" REAL NULL, "coverage" REAL NOT NULL DEFAULT 0.0, "valid" INTEGER NOT NULL DEFAULT 0 CHECK ("valid" IN (0, 1)), "computed_at_utc" INTEGER NOT NULL, "algorithm_version" TEXT NOT NULL, PRIMARY KEY ("id"))',
    'CREATE UNIQUE INDEX idx_nightly_records_user_date ON nightly_records(user_id, local_date)',
  ],
  // v10: the VO2 columns (`app_database.dart:141-144`).
  10: [
    'ALTER TABLE exercise_sessions ADD COLUMN "vo2max_ml" REAL NULL',
    'ALTER TABLE exercise_sessions ADD COLUMN "vo2_confidence" REAL NULL',
  ],
  // v11 and v12 are data-only migrations (sleep dedup/re-id, HRV rollup
  // clear) — the schema at 10, 11 and 12 is identical.
  11: [],
  12: [],
};

/// The highest schema a database can be at and still need an upgrade to 13.
const _maxUpgradeFrom = 12;

/// DDL for a database as a device at schema [version] would have it on disk.
List<String> _schemaAt(int version) {
  assert(version >= 1 && version <= _maxUpgradeFrom);
  final ddl = <String>[..._v1Tables, ..._v1Indices];
  for (var v = 2; v <= version; v++) {
    ddl.addAll(_deltas[v]!);
  }
  return ddl;
}

// ─── Fixture ────────────────────────────────────────────────────────────────

/// An `AppDatabase` whose underlying file is already at schema [from], so
/// opening it runs the real `onUpgrade(m, from, 13)`.
///
/// [seed] runs after the historical DDL, before `user_version` is stamped —
/// use it to plant rows the migration has to preserve.
AppDatabase _databaseAt(int from, {List<String> seed = const []}) {
  return AppDatabase(NativeDatabase.memory(setup: (db) {
    for (final stmt in [..._schemaAt(from), ...seed]) {
      db.execute(stmt);
    }
    db.userVersion = from;
  }));
}

/// Forces the executor open, which is what runs the migration.
Future<int> _open(AppDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<List<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toList();
}

Future<Map<String, String>> _indices(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
        'AND sql IS NOT NULL',
      )
      .get();
  return {
    for (final r in rows)
      r.read<String>('name'):
          r.read<String>('sql').replaceAll(RegExp(r'\s+'), ' ').trim(),
  };
}

void main() {
  // Each fixture is its own database over its own private in-memory executor,
  // so drift's shared-executor race warning does not apply here.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('onUpgrade to schema 13', () {
    // The finding, plus its mirror image, in one assertion per origin version.
    //
    // from 1-4: exercise_sessions does not exist yet, so the `from < 5` step
    //   createTable's it — and drift emits the CURRENT definition, VO2 columns
    //   included. An unguarded `from < 10` addColumn then duplicates them and
    //   the migration throws before the database ever opens.
    // from 5-9: the table exists WITHOUT the VO2 columns, so the addColumn is
    //   exactly what has to run. Skipping it would leave the columns missing.
    // from 10-12: the table already has them and the step must not re-run.
    //
    // "Exactly one" catches all three failure modes: a throw (no database), a
    // duplicate, or an omission.
    for (var from = 1; from <= _maxUpgradeFrom; from++) {
      test('schema $from -> 13 opens with exactly one vo2max_ml / '
          'vo2_confidence on exercise_sessions', () async {
        final db = _databaseAt(from);
        addTearDown(db.close);

        expect(await _open(db), 13);

        final cols = await _columns(db, 'exercise_sessions');
        expect(cols.where((c) => c == 'vo2max_ml'), hasLength(1));
        expect(cols.where((c) => c == 'vo2_confidence'), hasLength(1));
      });
    }

    // v5-v9 installs have exercise_sessions WITHOUT the VO2 columns, so the
    // addColumn must still run — and must not cost the user their workouts.
    // v7 is the only such version git shows shipped (39806be).
    test('schema 7 -> 13 adds the VO2 columns and keeps existing rows',
        () async {
      final db = _databaseAt(7, seed: [
        "INSERT INTO users (id, created_at_utc, updated_at_utc) "
            "VALUES ('u1', 0, 0)",
        "INSERT INTO devices (id, user_id, display_name, paired_at_utc) "
            "VALUES ('d1', 'u1', 'H59', 0)",
        "INSERT INTO exercise_sessions "
            "(id, user_id, device_id, sport_type, started_at_utc, "
            " duration_sec, source, created_at_utc) "
            "VALUES ('e1', 'u1', 'd1', 7, 1000, 600, 0, 0)",
      ]);
      addTearDown(db.close);

      expect(await _open(db), 13);

      final cols = await _columns(db, 'exercise_sessions');
      expect(cols, containsAll(['vo2max_ml', 'vo2_confidence']));

      // addColumn is non-destructive: the pre-existing workout survives with
      // the new columns null (app_database.dart:128-130).
      final row = await db
          .customSelect(
            'SELECT id, duration_sec, vo2max_ml, vo2_confidence '
            "FROM exercise_sessions WHERE id = 'e1'",
          )
          .getSingle();
      expect(row.read<int>('duration_sec'), 600);
      expect(row.readNullable<double>('vo2max_ml'), isNull);
      expect(row.readNullable<double>('vo2_confidence'), isNull);
    });

    // The executed form of Rank 4's "do onCreate and onUpgrade converge?"
    // question, and a general guard: any future addColumn on a table that a
    // migration step also createTable's breaks the low origin versions, and
    // any index added to _createIndices without a migration step breaks the
    // high ones. Either way, this test fails.
    test('every version reaches the same schema as a fresh onCreate', () async {
      final fresh = AppDatabase(NativeDatabase.memory());
      addTearDown(fresh.close);
      expect(await _open(fresh), 13);

      final wantTables = await _tables(fresh);
      final wantIndices = await _indices(fresh);
      final wantColumns = <String, Set<String>>{
        for (final t in wantTables) t: (await _columns(fresh, t)).toSet(),
      };

      for (var from = 1; from <= _maxUpgradeFrom; from++) {
        final db = _databaseAt(from);
        addTearDown(db.close);
        expect(await _open(db), 13, reason: 'from $from');

        expect(await _tables(db), wantTables, reason: 'tables, from $from');
        // Index name AND definition — a dedup index that lost its UNIQUE on
        // one path would let sync_adapters' uuid.v4() ids duplicate silently.
        expect(await _indices(db), wantIndices, reason: 'indices, from $from');
        for (final t in wantTables) {
          expect((await _columns(db, t)).toSet(), wantColumns[t],
              reason: '$t columns, from $from');
        }
      }
    });

    test('the later steps still run after the VO2 columns (v13 column, '
        'v11 sleep re-id)', () async {
      final db = _databaseAt(3, seed: [
        "INSERT INTO users (id, created_at_utc, updated_at_utc) "
            "VALUES ('u1', 0, 0)",
        "INSERT INTO devices (id, user_id, display_name, paired_at_utc) "
            "VALUES ('d1', 'u1', 'H59', 0)",
        // Two rows for the same night with random ids — the v11 duplicate
        // collapse + deterministic re-id (app_database.dart:144-168).
        for (final id in ['rand-a', 'rand-b'])
          "INSERT INTO sleep_sessions (id, user_id, device_id, started_at_utc, "
              " captured_tz_offset_min, source, created_at_utc, ended_at_utc, "
              " type, protocol_version, total_min) "
              "VALUES ('$id', 'u1', 'd1', 5000, 0, 0, 0, 9000, 0, 1, 400)",
        "INSERT INTO sleep_epochs (id, session_id, user_id, started_at_utc, "
            " duration_min, stage, source, created_at_utc) "
            "VALUES ('ep1', 'rand-a', 'u1', 5000, 30, 1, 0, 0)",
      ]);
      addTearDown(db.close);

      expect(await _open(db), 13);

      // from < 13
      expect(await _columns(db, 'daily_metrics'), contains('rr_entropy_norm'));

      // from < 11 — one session left, re-id'd deterministically, epoch repointed.
      final sessions = await db
          .customSelect('SELECT id FROM sleep_sessions ORDER BY id')
          .get();
      expect(sessions.map((r) => r.read<String>('id')).toList(),
          ['sleepsync:d1:5000']);
      final epoch = await db
          .customSelect("SELECT session_id FROM sleep_epochs WHERE id = 'ep1'")
          .getSingle();
      expect(epoch.read<String>('session_id'), 'sleepsync:d1:5000');
    });
  });
}
