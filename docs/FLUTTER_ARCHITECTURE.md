# Flutter Architecture

`hlth_app` (bundle `com.hlth.hlthApp`) — a smart-ring companion app: a native
BLE bridge feeds a local-first health database, sensor-agnostic scoring engines
compute daily scores, and Riverpod-driven screens render them. ~31k LOC across
129 hand-written Dart files.

## Layered design (local-first)

```
UI (features/**, ui/widgets)               Flutter widgets + Riverpod consumers
      ↑ watch providers            ↓ read services
Providers (feature *_providers.dart)       StreamProvider / Provider (hand-written)
      ↑                            ↓
Services (core/services)                   orchestration: sync, aggregate, score, alert
      ↑                            ↓
Repositories (core/repositories)           Drift queries + domain mapping; the DB boundary
      ↑                            ↓
Drift/SQLite (core/database)   ← Supabase (cloud, push-only)   BleService (native bridge)
```

Data is **local-first**: the band syncs into SQLite; the UI only ever reads
SQLite (via repositories → providers). Cloud sync is a **push-only** mirror
(`SupabaseSyncRepository` upserts up; there is no down-restore path yet — a
known data-loss gap on fresh install).

## Folder map (`lib/`)

| Path | Responsibility |
|---|---|
| `core/ble/` | `BleService` (frozen platform-channel contract), `sync_adapters.dart` (native payload → domain samples) |
| `core/database/` | Drift `AppDatabase`, `tables.dart` (20 tables), `enums.dart`, migrations |
| `core/models/` | Freezed domain models (`Score`, `DailyMetrics`, `ExerciseSession`, `UserProfile`, health samples) |
| `core/repositories/` | 20 repos — the only code that touches Drift. Abstract + `Impl` + Riverpod `Provider`. |
| `core/services/` | Orchestration (sync, aggregation, scoring adapters, alerts, cloud, capture) |
| `core/scoring/` | **Pure** engines vendored from Ryan: `recovery_stability.dart`, `vascular_load.dart`, `vo2max_estimation.dart`, `sleep_epochs_builder.dart` |
| `core/processing/` | Signal processing (`fall_detector`, PPG/HRV/respiratory math) |
| `core/auth/`, `core/bootstrap/`, `core/config/`, `core/routing/` | Auth controller, `ActiveSession` (pre-onboarding user), env config, go_router |
| `features/**` | One folder per screen (home, activity, sleep, recovery, hrv, spo2, heart_rate, blood_pressure, stress, workouts, one_key, onboarding, pairing, settings, debug). Each may carry `*_providers.dart` + `widgets/`. |
| `ui/theme/`, `ui/widgets/` | `AppColors`, shared widgets (`ScoreGauge`, `TrendChartCard`, `HealthMetricCard`, `MetricTile`) |

## State management — Riverpod (hand-written, no codegen)

The app uses **plain `Provider` / `StreamProvider` / `StateNotifierProvider`**,
not `riverpod_generator`. Three conventions:

- **Repository providers:** `final xRepositoryProvider = Provider((ref) => XRepositoryImpl(ref.watch(appDatabaseProvider)));`
- **Service providers:** wire repos together, e.g. `vo2MaxServiceProvider`, `recoveryScoreServiceProvider`, `syncServiceProvider`.
- **UI providers:** `StreamProvider` off a repository `watch*` so screens rebuild reactively when Drift rows change — e.g. `latestRecoveryScoreProvider`, `dailyMetricsForDateProvider(date)` (family), `fitnessScoreProvider`, `vo2TrendProvider`.

Widgets `ref.watch(...).when(loading/error/data)` or `.valueOrNull`. Because
providers stream off Drift, a repository upsert anywhere (e.g. after a sync)
propagates to every watching card with no manual invalidation.

`ActiveSession.defaultUserId` is the single-user id used pre-onboarding so
health rows always have a valid FK target.

## Persistence — Drift/SQLite

20 tables (`tables.dart`). Conventions:
- **Table per metric** (HR/HRV/SpO2/BP/stress/steps) — different retention,
  types, indices. Universal columns: `id` (UUID), `user_id`, `device_id`,
  `captured_at_utc` (Unix sec), `source` (enum), `quality`, `created_at_utc`,
  `deleted_at_utc` (soft delete).
- **Idempotent writes:** `UNIQUE(user_id, device_id, captured_at_utc, source)`
  → re-syncing a day never duplicates.
- **Rollups:** `daily_metrics` (one row/day), `scores` (composite scores),
  `nightly_records` (Cardio Load per-night struct), `baselines` (rolling means).
- **Migrations:** `schemaVersion` (currently **10**) + a stepwise `onUpgrade`
  (`addColumn`/`createTable` + index creation). See
  [app_database.dart](../lib/core/database/app_database.dart).

## Scoring engines (pure, vendored)

`core/scoring/*` are **pure Dart, no I/O**, treated as source of truth and
integrated **verbatim** — only a service adapter wraps them:
- **Recovery/Stability** (`recovery_stability.dart`): sleep + HRV + RHR + resp +
  activity modifier; 4-night weighted window, ≤14-night baseline, robust-z,
  cold-start lock, decline override. Never fabricates missing signals.
- **Cardio Load / Vascular Load** (`vascular_load.dart`): sleeping HR trough +
  median RMSSD + stress, normalized to the user's baseline. Requires sleep HRV.
- **VO2 Max** (`vo2max_estimation.dart`): Åstrand-Ryhming Algorithm A; METs from
  band workout summary (ACSM speed → caloric fallback); rolling 7-day average.

Adapters (`*_service.dart`) reduce `daily_metrics`/sessions → engine input →
run engine → persist a `Score` (`ScoreRepository.upsert`, deterministic id
`userId:scoreTypeIndex:date`). Triggered post-aggregation in `syncAll`.

## Build system

- **pubspec:** Drift (SQLite), Riverpod, Freezed + `json_serializable`,
  `go_router`, `shared_preferences`, `flutter_local_notifications`,
  `fl_chart` (present; custom canvas charts used in practice), Supabase.
- **Codegen:** `dart run build_runner build --delete-conflicting-outputs`
  regenerates Drift (`*.g.dart`) + Freezed (`*.freezed.dart`) after schema/model
  edits.
- **Env:** Supabase URL/anon key injected via `--dart-define-from-file=hlth.env.json`.

## Design rationale

- **Local-first** keeps the app fully functional offline (the ring itself is
  the source; cloud is a mirror), and makes scoring deterministic/testable.
- **Pure engines + thin adapters** let vendor-delivered algorithms drop in
  unchanged and be unit-tested without a device or DB.
- **Repository boundary** means the entire app is testable with in-memory fakes
  (services take repo interfaces), which is how the test suite works.
- **Frozen `BleService` contract** decouples all Dart from platform specifics —
  the iOS bridge was built to match Android so nothing above the channel changes.

See [FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md),
[BLUETOOTH_FLOW.md](BLUETOOTH_FLOW.md), and [API_REFERENCE.md](API_REFERENCE.md).
