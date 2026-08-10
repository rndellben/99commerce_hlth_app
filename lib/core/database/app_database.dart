import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/database/tables.dart';

part 'app_database.g.dart';

/// HLTH local SQLite database — schema v1.
///
/// Specification: hlth-db-schema.md
///
/// All tables follow the universal provenance contract (UUID PKs,
/// Unix-sec timestamps, soft-delete via `deleted_at_utc`, composite
/// uniqueness on (user_id, device_id, captured_at_utc, source) for
/// idempotent sync). See the spec doc and `tables.dart` for the
/// per-table column listings.
///
/// To regenerate the inspection .db file in `hlth_app/db/`, see
/// `hlth_app/db/build_schema_db.py`.
@DriftDatabase(
  tables: [
    Users,
    UserProfiles,
    Devices,
    HrSamples,
    HrvSamples,
    StressSamples,
    Spo2Samples,
    BpReadings,
    StepBuckets,
    DailyMetrics,
    SleepSessions,
    SleepEpochs,
    Baselines,
    Scores,
    BpCalibrations,
    BatteryTelemetry,
    ExerciseSessions,
    SyncState,
    CloudSyncOutbox,
    NotificationLog,
    NightlyRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump on every schema change. Add a migration step in
  /// `migration` below. See hlth-db-schema.md §"Schema versioning".
  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndices();
        },
        onUpgrade: (m, from, to) async {
          // v1 → v2: add stress_samples table (HLT-13, Phase 4)
          if (from < 2) {
            await m.createTable(stressSamples);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_stress_user_time ON stress_samples(user_id, captured_at_utc DESC)',
            );
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_stress_dedup ON stress_samples(user_id, device_id, captured_at_utc, source)',
            );
          }
          // v2 → v3: add bp_calibrations table (HLT-16, Phase 4)
          //          and cloud_sync_outbox table for Supabase sync
          if (from < 3) {
            await m.createTable(bpCalibrations);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bpcal_user_time ON bp_calibrations(user_id, captured_at_utc DESC)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bpcal_user_active ON bp_calibrations(user_id, is_active, captured_at_utc DESC)',
            );
            await m.createTable(cloudSyncOutbox);
          }
          // v3 → v4: add battery_telemetry for the 24h drain test
          if (from < 4) {
            await m.createTable(batteryTelemetry);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_battery_time ON battery_telemetry(captured_at_utc DESC)',
            );
          }
          // v4 → v5: add exercise_sessions for band-side sport mode
          if (from < 5) {
            await m.createTable(exerciseSessions);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_exercise_user_time ON exercise_sessions(user_id, started_at_utc DESC)',
            );
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_dedup ON exercise_sessions(user_id, device_id, started_at_utc, source)',
            );
          }
          // v5 → v6: add notification_log for alert rate-limiting + history
          if (from < 6) {
            await m.createTable(notificationLog);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_notiflog_user_type_time ON notification_log(user_id, type, fired_at_utc_sec DESC)',
            );
          }
          // v6 → v7: add rhythm-irregularity columns to daily_metrics
          // (irregular-heartbeat alert, sensor-agnostic R-R analysis)
          if (from < 7) {
            await m.addColumn(dailyMetrics, dailyMetrics.rrIrregularityPct);
            await m.addColumn(dailyMetrics, dailyMetrics.ectopicBeatPct);
          }
          // v7 → v8: add scores table (recovery / cardio load / …)
          if (from < 8) {
            await m.createTable(scores);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_scores_user_type_date ON scores(user_id, score_type, computed_for_date)',
            );
          }
          // v8 → v9: add nightly_records for Vascular Load (Cardio Load)
          if (from < 9) {
            await m.createTable(nightlyRecords);
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_nightly_records_user_date '
              'ON nightly_records(user_id, local_date)',
            );
          }
          // v9 → v10: add VO2 max estimate columns to exercise_sessions
          // (aerobic-fitness feature, Åstrand-Ryhming Algorithm A). Nullable
          // addColumn is non-destructive; existing rows compute lazily.
          if (from < 10) {
            await m.addColumn(exerciseSessions, exerciseSessions.vo2maxMl);
            await m.addColumn(exerciseSessions, exerciseSessions.vo2Confidence);
          }
          // v10 → v11: de-duplicate sleep sessions. Until now sleepFromNative
          // minted a fresh uuid.v4() per sync, so createSession's upsert-by-id
          // never collided and each night re-inserted forever (observed: 64
          // rows for ~6 nights). The adapter now uses a deterministic id
          // ('sleepsync:<deviceId>:<sleepSec>' where sleepSec == started_at_utc)
          // so future syncs upsert in place. This one-time cleanup collapses the
          // existing duplicates and re-ids the survivors + their epochs to the
          // new scheme (grouped by device_id+started_at_utc so the re-id is
          // guaranteed unique).
          if (from < 11) {
            // 1. Keep the earliest-inserted row per (device, start); drop dups.
            await customStatement(
              'DELETE FROM sleep_sessions WHERE rowid NOT IN '
              '(SELECT MIN(rowid) FROM sleep_sessions '
              'GROUP BY device_id, started_at_utc)',
            );
            // 2. Drop epochs orphaned by the deleted duplicate sessions.
            await customStatement(
              'DELETE FROM sleep_epochs WHERE session_id NOT IN '
              '(SELECT id FROM sleep_sessions)',
            );
            // 3. Re-point surviving epochs to the deterministic session id
            //    (uses the still-current session.id for the lookup) …
            await customStatement(
              "UPDATE sleep_epochs SET session_id = "
              "(SELECT 'sleepsync:' || s.device_id || ':' || s.started_at_utc "
              " FROM sleep_sessions s WHERE s.id = sleep_epochs.session_id) "
              "WHERE session_id IN (SELECT id FROM sleep_sessions)",
            );
            // 4. … then re-id the sessions themselves so they match.
            await customStatement(
              "UPDATE sleep_sessions SET id = "
              "'sleepsync:' || device_id || ':' || started_at_utc",
            );
          }
          // v11 → v12: clear the HRV rollup in daily_metrics. A briefly-shipped
          // (dev-only) sleep-window "frame bridge" wrote NON-sleep (awake)
          // HRV into hrv_rmssd_ms/hrv_sdnn_ms, and the aggregator's merge
          // preserves an existing value when a fresh computation is null
          // (`hrvRmssd ?? existing`) — so that bad value would stick forever on
          // nights that have no real sleep HRV. Null it once; the corrected
          // aggregator (which queries the sleep window with the session bounds
          // directly) repopulates the trailing days on the next sync, and days
          // with genuinely no sleep HRV correctly stay null (redistributed).
          if (from < 12) {
            await customStatement(
              'UPDATE daily_metrics SET hrv_rmssd_ms = NULL, hrv_sdnn_ms = NULL',
            );
          }
          // v12 → v13: add R-R Shannon entropy column to daily_metrics — the
          // AFib guide's third irregularity axis, alongside CoV + ectopic%.
          // Nullable addColumn is non-destructive; the next passing PPG
          // capture backfills it.
          if (from < 13) {
            await m.addColumn(dailyMetrics, dailyMetrics.rrEntropyNorm);
          }
        },
      );

  /// Indices that drift doesn't generate automatically. Per
  /// hlth-db-schema.md §9, the universal pattern is:
  ///   idx_<table>_user_time(user_id, captured_at_utc DESC)
  ///   UNIQUE idx_<table>_dedup(user_id, device_id, captured_at_utc, source)
  /// Plus a few table-specific ones.
  Future<void> _createIndices() async {
    final stmts = <String>[
      // hr_samples
      'CREATE INDEX IF NOT EXISTS idx_hr_user_time ON hr_samples(user_id, captured_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_dedup ON hr_samples(user_id, device_id, captured_at_utc, source)',
      'CREATE INDEX IF NOT EXISTS idx_hr_user_resting ON hr_samples(user_id, captured_at_utc DESC) WHERE is_resting = 1',
      // hrv_samples
      'CREATE INDEX IF NOT EXISTS idx_hrv_user_time ON hrv_samples(user_id, captured_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_hrv_dedup ON hrv_samples(user_id, device_id, captured_at_utc, source)',
      // stress_samples
      'CREATE INDEX IF NOT EXISTS idx_stress_user_time ON stress_samples(user_id, captured_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_stress_dedup ON stress_samples(user_id, device_id, captured_at_utc, source)',
      // spo2_samples
      'CREATE INDEX IF NOT EXISTS idx_spo2_user_time ON spo2_samples(user_id, captured_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_spo2_dedup ON spo2_samples(user_id, device_id, captured_at_utc, source)',
      // bp_readings
      'CREATE INDEX IF NOT EXISTS idx_bp_user_time ON bp_readings(user_id, captured_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_bp_dedup ON bp_readings(user_id, device_id, captured_at_utc, source)',
      'CREATE INDEX IF NOT EXISTS idx_bp_user_derivation ON bp_readings(user_id, derivation, captured_at_utc DESC)',
      // step_buckets
      'CREATE INDEX IF NOT EXISTS idx_step_user_day ON step_buckets(user_id, captured_tz_offset_min, bucket_start_at_utc)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_step_dedup ON step_buckets(user_id, device_id, bucket_start_at_utc, source)',
      // daily_metrics
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_user_date ON daily_metrics(user_id, local_date)',
      // sleep_sessions
      'CREATE INDEX IF NOT EXISTS idx_sleep_user_time ON sleep_sessions(user_id, started_at_utc DESC)',
      // sleep_epochs
      'CREATE INDEX IF NOT EXISTS idx_epoch_session ON sleep_epochs(session_id, started_at_utc)',
      // baselines
      'CREATE INDEX IF NOT EXISTS idx_baseline_user_metric ON baselines(user_id, metric_key, window_days, computed_for_date DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_baseline_dedup ON baselines(user_id, metric_key, window_days, computed_for_date)',
      // scores
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_scores_user_type_date ON scores(user_id, score_type, computed_for_date)',
      // bp_calibrations
      'CREATE INDEX IF NOT EXISTS idx_bpcal_user_time ON bp_calibrations(user_id, captured_at_utc DESC)',
      'CREATE INDEX IF NOT EXISTS idx_bpcal_user_active ON bp_calibrations(user_id, is_active, captured_at_utc DESC)',
      // battery_telemetry
      'CREATE INDEX IF NOT EXISTS idx_battery_time ON battery_telemetry(captured_at_utc DESC)',
      // exercise_sessions
      'CREATE INDEX IF NOT EXISTS idx_exercise_user_time ON exercise_sessions(user_id, started_at_utc DESC)',
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercise_dedup ON exercise_sessions(user_id, device_id, started_at_utc, source)',
      // sync_state
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_unique ON sync_state(device_id, metric_key)',
      // notification_log
      'CREATE INDEX IF NOT EXISTS idx_notiflog_user_type_time ON notification_log(user_id, type, fired_at_utc_sec DESC)',
      // nightly_records
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_nightly_records_user_date ON nightly_records(user_id, local_date)',
      // devices
      'CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_devices_mac ON devices(mac_address) WHERE mac_address IS NOT NULL',
      // users
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL',
      'CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone) WHERE phone IS NOT NULL',
    ];
    for (final s in stmts) {
      await customStatement(s);
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'hlth_app');
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
