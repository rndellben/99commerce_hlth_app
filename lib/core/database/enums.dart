/// All drift `intEnum` types live here so they're easy to keep in sync
/// with the schema spec at hlth-db-schema.md Section 10.
///
/// Integer values are POSITIONAL — adding a new value at the end is safe,
/// reordering is NOT (would corrupt every existing row). Treat the order
/// as a permanent contract.
library;

/// hlth-db-schema.md §3.0 — provenance on every health row.
enum DataSource {
  bandScheduled,        // 0 — band collected on its schedule
  bandManual,           // 1 — user-initiated band-side measurement
  bandRealtime,         // 2 — continuous streaming from band
  bandDerivedFromHr,    // 3 — band computed it from HR (e.g. estimated BP)
  appRecomputed,        // 4 — our algorithms recomputed from raw PPG
  userEntered,          // 5 — typed in by user (e.g. cuff BP)
  imported,             // 6 — migrated from QWatch Pro or another app
}

/// hlth-db-schema.md §4.4 — sleep_epochs.stage
enum SleepStage {
  awake,                // 0
  light,                // 1
  deep,                 // 2
  rem,                  // 3
  noSleep,              // 4
  unweared,             // 5
}

/// hlth-db-schema.md §4.3 — sleep_sessions.type
enum SleepSessionType {
  night,                // 0
  nap,                  // 1
}

/// hlth-db-schema.md §3.5 — bp_readings.derivation
enum BpDerivation {
  hrEstimate,           // 0 — band derived from HR (low accuracy)
  bandSensor,           // 1 — band measured via its own algorithm
  appCalibrated,        // 2 — band reading adjusted by our calibration model
  cuff,                 // 3 — user-typed cuff measurement
}

/// hlth-db-schema.md §1.2 — user_profiles.sex_at_birth
enum SexAtBirth {
  female,               // 0
  male,                 // 1
  unknown,              // 2 — default; required for HR/HRV/BP norms
}

/// hlth-db-schema.md §6.4 — alerts.alert_type (v1 subset)
enum AlertType {
  fallDetected,         // 0
  hrIrregularRhythm,    // 1 — "irregular rhythm" per regulatory guide
  breathingDisruption,  // 2 — "breathing disruption" per regulatory guide
  illnessWarning,       // 3 — NightSignal multi-signal anomaly
  mentalWellnessDrop,   // 4
  hrThresholdLow,       // 5
  hrThresholdHigh,      // 6
  lowBattery,           // 7
  bandUnwornTooLong,    // 8
}

/// hlth-db-schema.md §6.4 — alerts.status
enum AlertStatus {
  pending,              // 0 — created but not yet shown
  shown,                // 1
  acknowledged,         // 2
  dismissed,            // 3
  cancelled,            // 4
  superseded,           // 5
}

/// hlth-db-schema.md §6.3 — scores.score_type
enum ScoreType {
  recovery,             // 0
  wellness,             // 1
  longevity,            // 2 — body age
  stress,               // 3 — daily composite (distinct from per-sample stress)
  fitness,              // 4 — VO2-max-derived
}
