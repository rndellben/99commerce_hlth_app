-- ============================================================================
-- HLTH app SQLite schema (drift v1)
--
-- HUMAN-READABLE MIRROR of the drift schema defined in:
--   lib/core/database/tables.dart
--   lib/core/database/app_database.dart  (indices in _createIndices)
--
-- The DART CODE IS THE SOURCE OF TRUTH. Drift codegen produces the runtime
-- DDL; this file exists so engineers, designers, and backend folks can read
-- the schema without scanning Dart and can build an empty .db file to open
-- in DB Browser for SQLite.
--
-- To regenerate the inspection .db from this file:
--   python build_schema_db.py
--
-- If you change the schema, update BOTH:
--   1. lib/core/database/tables.dart  (runtime)
--   2. db/schema.sql                  (this file)
--   3. bump `schemaVersion` in app_database.dart and add an onUpgrade step
--
-- Specification: hlth-db-schema.md (column-level contract).
--
-- Universal rules (hlth-db-schema.md §"Design principles"):
--   * UUID v4 TEXT primary keys.
--   * Unix-seconds INTEGER for all timestamps (never DATETIME).
--   * Every health row has 8+ provenance columns. Soft delete via nullable
--     `deleted_at_utc`.
--   * Composite UNIQUE on (user_id, device_id, captured_at_utc, source) for
--     idempotent re-syncs.
--   * `intEnum<X>` columns store the enum index (0-based) per `enums.dart`.
-- ============================================================================

-- ─── Section 1 — Identity ──────────────────────────────────────────────────

CREATE TABLE users (
  id                              TEXT NOT NULL PRIMARY KEY,         -- UUID v4
  email                           TEXT UNIQUE,
  phone                           TEXT UNIQUE,
  display_name                    TEXT,
  created_at_utc                  INTEGER NOT NULL,
  updated_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER
);

CREATE TABLE user_profiles (
  user_id                         TEXT NOT NULL PRIMARY KEY REFERENCES users(id),
  date_of_birth                   TEXT,                              -- YYYY-MM-DD
  sex_at_birth                    INTEGER NOT NULL DEFAULT 2,        -- 0=female, 1=male, 2=unknown
  height_cm                       REAL,
  weight_kg                       REAL,
  uses_metric                     INTEGER NOT NULL DEFAULT 1,        -- bool
  uses24h_clock                   INTEGER NOT NULL DEFAULT 1,        -- bool
  resting_hr_baseline             INTEGER,
  cycle_tracking_enabled          INTEGER NOT NULL DEFAULT 0,        -- bool
  last_period_start_date          TEXT,                              -- YYYY-MM-DD
  typical_cycle_length            INTEGER,
  updated_at_utc                  INTEGER NOT NULL
);

-- ─── Section 2 — Devices ───────────────────────────────────────────────────

CREATE TABLE devices (
  id                              TEXT NOT NULL PRIMARY KEY,         -- UUID v4
  user_id                         TEXT NOT NULL REFERENCES users(id),
  mac_address                     TEXT UNIQUE,
  ios_peripheral_uuid             TEXT,
  display_name                    TEXT NOT NULL,
  model                           TEXT,
  hardware_version                TEXT,
  firmware_version                TEXT,
  user_id_on_band                 TEXT,
  paired_at_utc                   INTEGER NOT NULL,
  last_connected_at_utc           INTEGER,
  last_battery_percent            INTEGER,
  last_charging                   INTEGER,                           -- bool
  is_active                       INTEGER NOT NULL DEFAULT 1,        -- bool
  capabilities                    TEXT NOT NULL DEFAULT '{}',        -- JSON
  deleted_at_utc                  INTEGER
);

-- ─── Section 3 — Time-series health metrics ────────────────────────────────

CREATE TABLE hr_samples (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  captured_at_utc                 INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,                  -- DataSource enum
  quality                         INTEGER,                           -- 0-100
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  bpm                             INTEGER NOT NULL,                  -- 30-220 valid
  interval_min                    INTEGER NOT NULL,                  -- 1, 5, 10, 15, 30, 60
  is_resting                      INTEGER NOT NULL DEFAULT 0         -- bool
);

CREATE TABLE hrv_samples (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  captured_at_utc                 INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,
  quality                         INTEGER,
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  rmssd_ms                        REAL NOT NULL,
  sdnn_ms                         REAL,
  pnn50_pct                       REAL,
  mean_hr_bpm                     INTEGER,
  beat_count                      INTEGER
);

CREATE TABLE spo2_samples (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  captured_at_utc                 INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,
  quality                         INTEGER,
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  pct_min                         INTEGER NOT NULL,                  -- 70-100
  pct_max                         INTEGER NOT NULL,
  bucket_min                      INTEGER NOT NULL                   -- 1 (interval) or 60 (hourly)
);

CREATE TABLE bp_readings (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  captured_at_utc                 INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,
  quality                         INTEGER,
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  systolic_mmhg                   INTEGER NOT NULL,                  -- 70-200
  diastolic_mmhg                  INTEGER NOT NULL,                  -- 40-130
  pulse_bpm                       INTEGER,
  derivation                      INTEGER NOT NULL,                  -- BpDerivation enum
  position                        INTEGER                            -- 0=sit, 1=lie, 2=stand
);

-- ─── Section 4 — Activity, sleep ───────────────────────────────────────────

CREATE TABLE step_buckets (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  bucket_start_at_utc             INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,
  quality                         INTEGER,
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  steps                           INTEGER NOT NULL,
  distance_m                      INTEGER NOT NULL,
  calories_kcal                   REAL NOT NULL,
  run_steps                       INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE daily_metrics (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  local_date                      TEXT NOT NULL,                     -- YYYY-MM-DD
  tz_offset_min                   INTEGER NOT NULL,
  -- Cardiac
  resting_hr_bpm                  INTEGER,
  hrv_rmssd_ms                    REAL,
  hrv_sdnn_ms                     REAL,
  resting_resp_rate_bpm           REAL,
  -- SpO2
  spo2_overnight_avg              REAL,
  spo2_overnight_min              INTEGER,
  -- BP
  systolic_mmhg                   INTEGER,
  diastolic_mmhg                  INTEGER,
  -- Sleep
  sleep_total_min                 INTEGER,
  sleep_deep_pct                  REAL,
  sleep_rem_pct                   REAL,
  sleep_light_pct                 REAL,
  sleep_efficiency_pct            REAL,
  bedtime_utc                     INTEGER,
  wake_utc                        INTEGER,
  -- Activity
  steps                           INTEGER,
  distance_m                      INTEGER,
  calories_kcal                   REAL,
  active_minutes                  INTEGER,
  -- Vascular / cardiac advanced
  stiffness_index                 REAL,
  augmentation_index              REAL,
  stroke_volume_index             REAL,
  breathing_disruptions_hr        REAL,
  -- Scores (snapshots — full history lives in `scores`)
  recovery_score                  INTEGER,
  wellness_score                  INTEGER,
  -- Cycle
  cycle_phase                     INTEGER,
  -- Provenance
  computed_at_utc                 INTEGER NOT NULL,
  algorithm_version               TEXT NOT NULL,
  source                          INTEGER NOT NULL,
  deleted_at_utc                  INTEGER
);

CREATE TABLE sleep_sessions (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  started_at_utc                  INTEGER NOT NULL,
  captured_tz_offset_min          INTEGER NOT NULL,
  source                          INTEGER NOT NULL,
  quality                         INTEGER,
  algorithm_version               TEXT,
  created_at_utc                  INTEGER NOT NULL,
  deleted_at_utc                  INTEGER,
  ended_at_utc                    INTEGER NOT NULL,
  type                            INTEGER NOT NULL,                  -- 0=night, 1=nap
  protocol_version                INTEGER NOT NULL,                  -- 1=old, 2=new
  total_min                       INTEGER NOT NULL,
  deep_min                        INTEGER NOT NULL DEFAULT 0,
  light_min                       INTEGER NOT NULL DEFAULT 0,
  rem_min                         INTEGER NOT NULL DEFAULT 0,
  awake_min                       INTEGER NOT NULL DEFAULT 0,
  coverage_gap_min                INTEGER NOT NULL DEFAULT 0,
  efficiency_pct                  REAL,
  has_unweared                    INTEGER NOT NULL DEFAULT 0         -- bool
);

CREATE TABLE sleep_epochs (
  id                              TEXT NOT NULL PRIMARY KEY,
  session_id                      TEXT NOT NULL REFERENCES sleep_sessions(id),
  user_id                         TEXT NOT NULL REFERENCES users(id),
  started_at_utc                  INTEGER NOT NULL,
  duration_min                    INTEGER NOT NULL,
  stage                           INTEGER NOT NULL,                  -- SleepStage enum
  source                          INTEGER NOT NULL,
  created_at_utc                  INTEGER NOT NULL
);

-- ─── Section 6 — Derived ───────────────────────────────────────────────────

CREATE TABLE baselines (
  id                              TEXT NOT NULL PRIMARY KEY,
  user_id                         TEXT NOT NULL REFERENCES users(id),
  metric_key                      TEXT NOT NULL,                     -- 'resting_hr_bpm', etc.
  window_days                     INTEGER NOT NULL,                  -- 14, 30, 90
  computed_for_date               TEXT NOT NULL,                     -- YYYY-MM-DD
  mean_value                      REAL NOT NULL,
  stddev_value                    REAL NOT NULL,
  sample_count                    INTEGER NOT NULL,
  computed_at_utc                 INTEGER NOT NULL,
  algorithm_version               TEXT NOT NULL
);

-- ─── Section 8 — Operational ───────────────────────────────────────────────

CREATE TABLE sync_state (
  id                              TEXT NOT NULL PRIMARY KEY,
  device_id                       TEXT NOT NULL REFERENCES devices(id),
  metric_key                      TEXT NOT NULL,                     -- 'hr', 'hrv', 'spo2', ...
  last_successful_sync_utc        INTEGER,
  last_attempted_sync_utc         INTEGER,
  last_sync_error                 TEXT,
  last_synced_day_index           INTEGER,
  bytes_synced_lifetime           INTEGER NOT NULL DEFAULT 0
);

-- ─── Indices (from app_database.dart::_createIndices) ──────────────────────

-- hr_samples
CREATE INDEX        idx_hr_user_time      ON hr_samples(user_id, captured_at_utc DESC);
CREATE UNIQUE INDEX idx_hr_dedup          ON hr_samples(user_id, device_id, captured_at_utc, source);
CREATE INDEX        idx_hr_user_resting   ON hr_samples(user_id, captured_at_utc DESC) WHERE is_resting = 1;

-- hrv_samples
CREATE INDEX        idx_hrv_user_time     ON hrv_samples(user_id, captured_at_utc DESC);
CREATE UNIQUE INDEX idx_hrv_dedup         ON hrv_samples(user_id, device_id, captured_at_utc, source);

-- spo2_samples
CREATE INDEX        idx_spo2_user_time    ON spo2_samples(user_id, captured_at_utc DESC);
CREATE UNIQUE INDEX idx_spo2_dedup        ON spo2_samples(user_id, device_id, captured_at_utc, source);

-- bp_readings
CREATE INDEX        idx_bp_user_time         ON bp_readings(user_id, captured_at_utc DESC);
CREATE UNIQUE INDEX idx_bp_dedup             ON bp_readings(user_id, device_id, captured_at_utc, source);
CREATE INDEX        idx_bp_user_derivation   ON bp_readings(user_id, derivation, captured_at_utc DESC);

-- step_buckets
CREATE INDEX        idx_step_user_day     ON step_buckets(user_id, captured_tz_offset_min, bucket_start_at_utc);
CREATE UNIQUE INDEX idx_step_dedup        ON step_buckets(user_id, device_id, bucket_start_at_utc, source);

-- daily_metrics
CREATE UNIQUE INDEX idx_daily_user_date   ON daily_metrics(user_id, local_date);

-- sleep_sessions
CREATE INDEX        idx_sleep_user_time   ON sleep_sessions(user_id, started_at_utc DESC);

-- sleep_epochs
CREATE INDEX        idx_epoch_session     ON sleep_epochs(session_id, started_at_utc);

-- baselines
CREATE INDEX        idx_baseline_user_metric ON baselines(user_id, metric_key, window_days, computed_for_date DESC);
CREATE UNIQUE INDEX idx_baseline_dedup       ON baselines(user_id, metric_key, window_days, computed_for_date);

-- sync_state
CREATE UNIQUE INDEX idx_sync_state_unique ON sync_state(device_id, metric_key);

-- devices
CREATE INDEX        idx_devices_user_id   ON devices(user_id);
CREATE INDEX        idx_devices_mac       ON devices(mac_address) WHERE mac_address IS NOT NULL;

-- users
CREATE INDEX        idx_users_email       ON users(email) WHERE email IS NOT NULL;
CREATE INDEX        idx_users_phone       ON users(phone) WHERE phone IS NOT NULL;
