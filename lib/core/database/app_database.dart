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
    Spo2Samples,
    BpReadings,
    StepBuckets,
    DailyMetrics,
    SleepSessions,
    SleepEpochs,
    Baselines,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump on every schema change. Add a migration step in
  /// `migration` below. See hlth-db-schema.md §"Schema versioning".
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndices();
        },
        onUpgrade: (m, from, to) async {
          // No migrations yet — first release is v1.
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
      // sync_state
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_unique ON sync_state(device_id, metric_key)',
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
