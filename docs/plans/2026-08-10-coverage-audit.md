# Test coverage audit — `core/repositories`, `core/providers`, `core/sync`

Date: 2026-08-10. Scope: `lib/core/repositories/` (21 files, 3560 loc),
`lib/core/providers/` (4 files, 313 loc), `lib/core/sync/` (7 files, 1388 loc).
`lib/features/**` not read. `core/database`, `core/models`, `core/services`,
`core/ble`, `test/` read as supporting context only.

Every file in all three directories was read end-to-end. Every claim below cites
`file:line`.

## 0. Baseline — what is actually covered

**Corrected fact: `lib/core/sync/` has ZERO test coverage, not partial.**

`grep -rn "core/sync" test/` returns nothing. No test file imports
`band_sync_service.dart`, `periodic_sync_coordinator.dart`,
`score_refresh_service.dart`, `fall_sweep_service.dart`, `retention_gate.dart`,
`band_reconnector.dart`, or `sync_results.dart`.

The "sync decoders" line in `CLAUDE.md:96` refers to
`test/sync_adapters_bp_test.dart:2` and `test/sync_adapters_sleep_test.dart`,
which import `package:hlth_app/core/ble/sync_adapters.dart` — that file lives in
`lib/core/ble/`, **outside** the audited directory. The band-payload decoders are
well covered; the orchestration that calls them is not covered at all.

Same for the other two directories: no test imports any file under
`lib/core/providers/`. Repository *interfaces* are imported by 13 test files, but
only to hand-write fakes against (`test/cardio_load_frame_test.dart:165`,
`test/alert_rules_test.dart:397`, …) — no `*RepositoryImpl` is ever
instantiated, and `NativeDatabase` / `drift/native.dart` appear nowhere in
`lib/` or `test/`.

| Directory | Files | LOC | Test files touching it | Verdict |
|---|---|---|---|---|
| `lib/core/repositories/` | 21 | 3560 | 0 (13 import the interfaces to fake them) | 0% |
| `lib/core/providers/` | 4 | 313 | 0 | 0% |
| `lib/core/sync/` | 7 | 1388 | 0 | 0% |

House style, for reference:
- Pure-function tests calling the function directly — every file except one.
- Hand-written fakes over a `noSuchMethod`-throwing base:
  `test/cardio_load_frame_test.dart:159-163` (`class _Fake { noSuchMethod(i) =>
  throw UnimplementedError(...); }`) then `class _FakeHrRepo extends _Fake
  implements HrRepository` at `:179`. This is the idiom to follow for every
  repository/service seam below.
- Replay tests for band payloads: `test/sync_adapters_bp_test.dart:13-32`.
- `test/widget_test.dart:10` is the sole `testWidgets` — a boot smoke test. No
  widget tests are proposed here.

## 0.1 Testability blockers — read before estimating anything

| # | Blocker | Evidence | Fix cost |
|---|---|---|---|
| B1 | **`AppDatabase` cannot take an in-memory executor.** `AppDatabase() : super(_openConnection())` — no `QueryExecutor` parameter. `_openConnection()` hard-calls `driftDatabase(name: 'hlth_app')` (drift_flutter, needs platform channels). **No repository test can be written until this changes.** | `lib/core/database/app_database.dart:47`, `:259-261` | S — one line: `AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());`. `package:sqlite3` is already a transitive dep (`pubspec.lock:1064`), so `NativeDatabase.memory()` from `drift/native.dart` needs **no pubspec change**. |
| B2 | **No clock injection anywhere in the three directories.** Direct `DateTime.now()`: `score_refresh_service.dart:58,76,82`; `band_sync_service.dart:374,397,494,526`; `retention_gate.dart:35`; `health_data_providers.dart:34,108,168`; and in every repository's `_toCompanion` (`createdAtUtc: _toSec(DateTime.now())`, e.g. `hr_repository.dart:54`) and `softDeleteBefore` (`hr_repository.dart:160`). | as cited | S per site where the value is *stored* (assert a range instead). **M** where behaviour *branches* on now (`score_refresh_service.dart:58`, `band_sync_service.dart:374`) — those need a `DateTime Function() now` ctor param before any date-boundary assertion is possible. |
| B3 | **`BandReconnector` leaks timers into the test harness.** `start()` is called from `PeriodicSyncCoordinator`'s constructor (`periodic_sync_coordinator.dart:70`); it schedules a `Timer.periodic(5 min)` **and** an unconditional `Future.delayed(10s, tryNow)` (`band_reconnector.dart:33-37`). `dispose()` cancels only the periodic timer (`band_reconnector.dart:65-68`). `test/widget_test.dart:44-54` already documents having to `pump(11s)` to survive this. | as cited | S in a test (inject a `_FakeReconnector` — `reconnector` is a ctor param, `periodic_sync_coordinator.dart:51`). No production change needed. |
| B4 | **`SupabaseSyncRepository` has no fakeable seam.** Ctor takes a concrete `SupabaseClient` (`supabase_sync_repository.dart:17`); every method chains `_client.from(...).upsert(...)` (`:24`) and wraps it in the **static** `SupabaseConnectionMonitor.withRetry` (`:23`). | as cited | L. See §3 — not worth testing. |

## 1. Ranked untested seams

Ranked by risk × likelihood. "Blast radius" is stated concretely. Effort assumes
B1 is already done for any row marked `NativeDatabase.memory()`.

| Rank | Seam (file:line) | What breaks if it's wrong | Blast radius | Likelihood | Effort |
|---|---|---|---|---|---|
| 1 | `lib/core/providers/bp_calibration_providers.dart:59-63` — `_anchorFor` returns `hrAtCalibration: 0` when the calibration row has no HR | The provider passes `hr: reading.pulseBpm` (`:86`); `applyBpCalibration` branches on the **reading's** HR, not the anchor's (`lib/core/processing/bp_formula.dart:143`), so it takes the HR-coupled path and computes `delta = (hr − 0) × 0.45` (`bp_formula.dart:47`). The provider's own comment claims the value is "ignored by the offset-fallback branch" (`:63`) — that branch is only reached when `hr == null`. | Displayed systolic inflated by ≈0.45 × pulse (≈ +27…+36 mmHg at 60-80 bpm). Every BP headline, home card, and BP screen that uses `calibratedLatestBpProvider` shows hypertensive-crisis numbers for a normotensive user. Not persisted (display layer only) — but it is the number the user acts on. | Med — code path confirmed; whether `hrAtCalibration` can be null in practice depends on the feature-layer save path (out of scope, **unverified**) | S |
| 2 | `lib/core/sync/periodic_sync_coordinator.dart:262-265` — `await sleepOnset!.isProbablyAsleep(...)` is the only awaited call in `_onTick` **not** wrapped in `_bounded` | **Hang path only.** A hang never reaches the `finally` at `:294-296`, so `_inFlight` latches `true` and every subsequent tick is dropped at `:188` — precisely the failure `_bounded` was written to prevent (`:162-169`). `isProbablyAsleep` does two unbounded awaited DB reads (`sleep_onset_detector.dart:96,112`) plus `_restingReferenceBpm` (`:127`), none of them timeout-guarded. | Fall sweep (`:269`), the once-a-day PPG capture for resting respiratory + HRV (`:277`), and nightly resting BP (`:289`) stop **permanently** — the coordinator never ticks again for the process lifetime. Silent: no `Breadcrumbs.log` fires on this path. | Low-Med — a hang needs a wedged sqlite read, not just an error | M |
| 3 | `lib/core/repositories/step_bucket_repository.dart:120,137,155` — `isBetweenValues(w.from, w.to)` where `_dayWindow` returns `to = dayStart + 1 day` (`:106`) | SQL `BETWEEN` is inclusive on both ends, so the bucket starting at exactly next-day local midnight belongs to **both** days. The same class explicitly gets this right in `stepsInWindow` (`:172-173`, `isBiggerOrEqualValue` / `isSmallerThanValue`) — the two methods disagree about the same boundary. | `getForDay` feeds `daily_metrics.active_minutes` (`daily_aggregator.dart:258-264`) → persisted rollup → pushed to Supabase (`supabase_sync_repository.dart:91`). Up to +15 active minutes attributed to the wrong day, every day. `getTotalStepsForDay` double-counts the same bucket on the Activity screen. | High — the band emits 15-min slots anchored to slot starts, so a 00:00 bucket exists on essentially every day | S |
| 4 | `lib/core/repositories/hrv_repository.dart:63-70` — `insertMany` uses `InsertMode.insertOrReplace` on a **random** PK | `hrvFromNative` assigns `id: _uuid.v4()` (`lib/core/ble/sync_adapters.dart:328`) — unlike BP, which is deterministic (`sync_adapters.dart:230,271`). Dedup therefore rests **entirely** on `idx_hrv_dedup` (`app_database.dart:206`). `syncAll` re-pulls HRV three times per tick at offsets 0/1/2 (`band_sync_service.dart:106-108`), and each response self-anchors on `zeroTimeMs` (`sync_adapters.dart:306-312`), so the three pulls routinely produce the *same* `capturedAt`. | If the index is absent on any install path, HRV triples every 30-min tick: unbounded table growth, and `sleepWindowMedianRmssd` over duplicated rows (`daily_aggregator.dart:142-150`) skews `daily_metrics.hrv_rmssd_ms` → wrong Recovery **and** wrong Cardio Load (both require sleep RMSSD). | Med — the index is created in `_createIndices` (`app_database.dart:206`), but `onCreate` and the stepwise `onUpgrade` (`app_database.dart:60+`) create indices by different code paths; nothing asserts they converge | S |
| 5 | `lib/core/repositories/bp_repository.dart:176-199` — `getHourlySnapshots` buckets by `_toSec(capturedAt) ~/ 3600` (`:193`) | UTC-hour buckets, not local-hour. For UTC+5:30 / +5:45 / +8:45 users the bucket boundary sits mid-local-hour, so a 30-min cadence (`kBpSlotMinutes = 30`, `ble_service.dart:15`) puts two readings in one bucket some hours and one in others — the exact density skew the doc comment says the method exists to prevent (`:20-25`). It also inherits `getInRange`'s inclusive `to` (`:113`), so a reading at exactly `wake` is counted inside the sleep window. | This is the *only* BP path into the rollup: `daily_aggregator.dart:204` (sleep window) and `:214` (day fallback) → `daily_metrics.systolic/diastolic` → persisted, scored, and mirrored to Supabase (`supabase_sync_repository.dart:77-78`). A silently wrong median for every half-hour-offset timezone. | Med-High | S |
| 6 | `lib/core/sync/band_sync_service.dart:82-157` — `syncAll` step ordering and the `aggregated` gate | Four H59 quirks are encoded here as *ordering*, with nothing pinning them: HR must run before `syncBpTiming` because BP-for-today is derived from today's HR (`:111-121`, `:497-511`); HRV must be pulled at offsets 0, 1 **and** 2 (`:106-108`); HR must be pulled for today **and** yesterday (`:93-94`); `getBpDay` must never be called from the sweep (`:118-120`). Score refresh only runs when `aggregated == true` (`:140`). | A reorder or a dropped offset silently costs a whole day of HRV (the H59 index shift means offset 1 = today) or leaves today's BP frozen a full day behind the band buffer. Downstream: Recovery, Cardio Load, and the sleep screen's "measured during sleep" BP. | Med — this file has already been reordered twice per its own comments (`:88-92`, `:462-471`) | M |
| 7 | `lib/core/repositories/cloud_sync_outbox_repository.dart:41-45` — `enqueue` uses `getSingleOrNull()` on `(targetTable, recordId)` with **no unique index** | `_createIndices` creates no index at all for `cloud_sync_outbox` (`app_database.dart:195-256`). `getSingleOrNull()` throws `StateError` when >1 row matches. Two engines can pass the existence check concurrently — the retention gate's own doc says the UI and headless engines share state (`retention_gate.dart:16-18`), and `background_main.dart:62` builds a second `ProviderContainer`. | Once a duplicate exists, every later `enqueue` for that record throws; `enqueueRecentMetrics` aborts mid-loop; `syncAll` swallows it (`band_sync_service.dart:149-154`). The Supabase mirror silently stops receiving new rollups. Local SQLite unaffected — so the symptom is invisible on-device. | Low-Med | S |
| 8 | `lib/core/sync/score_refresh_service.dart:57-66` and `:81-88` — `today.subtract(Duration(days: d))` over a local `DateTime.now()` | `Duration(days: 1)` is 24 absolute hours; a spring-forward day is 23 local hours. Run at 00:30 local on the DST day and `d=1` lands on the **day before yesterday** — the intervening calendar date is never recomputed. Same pattern at `band_sync_service.dart:374` (`syncHrv` `forDate`) and `:397` (`syncStress` `forDate`). | Recovery and Mental Wellness silently skip a day's backfill exactly once per DST transition; because the H59 serves a night's HRV only the next day (`score_refresh_service.dart:44-47`), that day's score stays permanently HRV-less. For HRV/stress the `zeroTimeMs` anchor usually rescues it (`sync_adapters.dart:306-312`), so only pre-`zeroTimeMs` firmware is exposed. | Low-Med (twice a year, per user) | **M — needs B2 clock injection first** |
| 9 | `lib/core/repositories/hrv_repository.dart:159-174` — `getMorningResting` builds `DateTime(forDate.year, forDate.month, forDate.day, 4)` (local ctor) | This is the only date-window helper in the repository layer that is **not** tz-frame-normalised. `daily_aggregator.dart:65-73` deliberately uses `DateTime.utc(...) - tzOffsetMin` and says so ("keeps the math independent of the system clock's TZ — important for tests and CI"); `step_bucket_repository.dart:101-108` does the same. `getMorningResting` does not, and its sole caller passes a local `localMidnight` (`daily_aggregator.dart:68,159`). | It is the fallback that fills `daily_metrics.hrv_rmssd_ms` when the sleep window found no HRV (`daily_aggregator.dart:158-164`) → Recovery's primary input. A caller that ever passes a UTC-flagged date mixes frames and returns another day's sample. Also silently host-TZ dependent, so any future test of it is TZ-flaky. | Low-Med | S |
| 10 | `lib/core/sync/retention_gate.dart:32-54` — the 24h gate | `maybeSweep` reads/writes `retention_last_swept_at_utc_sec` in `SharedPreferences` and compares against `DateTime.now().toUtc()` (`:33-42`). Nothing tests the boundary, the human-readable skip string (`:44-47`), or that the timestamp is written **after** a successful sweep (`:51-52` — a throw in `sweepAll` leaves the pref unwritten, so the sweep retries every tick). | Gate stuck open → `RetentionSweepService.sweepAll` soft-deletes on every 30-min tick instead of daily (wasted work, no data loss). Gate stuck closed → 90-day raw retention never enforced; DB grows without bound. | Low-Med | S |
| 11 | `lib/core/repositories/device_repository.dart:102-107` — `getByMacAddress` uses `getSingleOrNull()`; `idx_devices_mac` is **not** unique (`app_database.dart:246`) | Throws `StateError` on a duplicate MAC row. `ActiveSession.ensureDevice` calls it on every connect and creates a fresh-UUID row when it returns null (`active_session.dart:41-66`). | If a duplicate ever lands, `ensureDevice` throws on every connect → no device row is registered → `PeriodicSyncCoordinator._onTick` returns early at `:203` and `triggerNow` returns the "no active device row" skip (`:313-318`). **The entire sync pipeline stops, permanently, with no data loss and no visible error.** | Low (needs a concurrent create) | S |
| 12 | `lib/core/sync/band_sync_service.dart:454-522` — `syncBpTiming` | Two independent sources with separate error handling: the band buffer in its own try/catch (`:472-487`) so a `-4001` timeout cannot take down the today-from-HR derivation (`:494-514`); `dayStartUtc = DateTime(now.y,m,d).toUtc()` (`:495-496`); and `getInRange(..., deviceId: deviceId)` (`:497-502`). | If the inner catch is ever removed, a buffer timeout freezes BP a full day behind (the regression the comment records at `:468-471`). The `deviceId` filter means HR synced under a *previous* device row id yields zero rows → today's BP silently disappears after a re-pair. | Med | M |
| 13 | `lib/core/repositories/bp_repository.dart:113` (+ `hr_repository.dart:101`, `hrv_repository.dart:94`, `spo2_repository.dart:91`, `stress_repository.dart:89`) — every `getInRange` uses `isBetweenValues`, inclusive on both ends | The sleep window is specified as `[bedtime, wake)` (`CLAUDE.md:78`), and every sleep-window query passes `session.endedAt` as `to` (`daily_aggregator.dart:142-146`, `cardio_load_service.dart:94-99`). A sample at exactly `wake` is included. | One boundary sample per night in each of HR/HRV/stress medians. Small numeric error, but it flows into `nightly_records` and the Cardio Load validity gate. | Med (frequency), Low (magnitude) | S |
| 14 | `lib/core/repositories/spo2_repository.dart:154-172` — `overnightStats` | Returns `null` only when **both** aggregates are null (`:170`); inclusive-end window (`:164-165`); averages `pctMin`, never `pctMax` (`:159`). | `daily_metrics.spo2_overnight_avg/min` (`daily_aggregator.dart:170-191`) → Supabase (`supabase_sync_repository.dart:74-75`) and the breathing-disruption alert. | Med | S |
| 15 | `lib/core/repositories/sleep_repository.dart:155-181` — `insertEpochs` deletes the session's epochs then batch-inserts, **not** in a transaction | `delete(...).go()` at `:160-162` and `_db.batch(...)` at `:163-180` are separate statements. `syncSleep` calls `createSession` then `insertEpochs` (`band_sync_service.dart:270-271`). A failure between them leaves a session with zero epochs. | `SleepEpochsBuilder.build` gets an empty stage timeline → `reduceSession` marks the night invalid → Cardio Load loses a banked night (`cardio_load_service.dart:100-118`), and Cardio Load needs 4 valid nights before it produces anything. | Low | S |
| 16 | `lib/core/providers/health_data_providers.dart:32-50` — `todayDailyMetricsProvider` / `dailyMetricsForDateProvider` | Both normalise to local midnight via `DateTime(y,m,d)` before calling `watchForDay`, which string-compares against `local_date` (`daily_metrics_repository.dart:55,183`). An un-normalised `DateTime.now()` would never match any row. The wall clock is captured at first build (`:26-27`); `app.dart` invalidates on resume. | Every home card and detail screen bound to today's rollup renders blank, or renders yesterday's row after a midnight rollover with no resume event. | Med | S |
| 17 | `lib/core/providers/bp_calibration_providers.dart:78-88` — `calibratedLatestBpProvider` reads `calAsync.valueOrNull` inside the stream `map` | On first build `activeBpCalibrationProvider` is `AsyncLoading`, so `valueOrNull == null` → `_anchorFor(null)` → raw values emitted with `appCalibrated: false`, then re-emitted calibrated once the calibration stream resolves. | The BP headline flashes uncalibrated numbers on every cold start of a screen that watches it. Cosmetic but user-visible on a medical number. | High (every cold build) | S |
| 18 | `lib/core/repositories/exercise_session_repository.dart:46-94` — `upsertFromBand` inserts with `InsertMode.insertOrIgnore` and a fresh UUID, then re-reads by the dedup key to resolve the id | Correctness depends entirely on `idx_exercise_dedup` (`app_database.dart:241`) matching the `where` at `:86-90`. If they diverge, the ignore silently no-ops and the re-read returns the *old* row — or the insert duplicates and `getSingleOrNull()` (`:92`) throws. | VO2 Max is computed per session and written back via `updateVo2` (`:155-166`); a wrong id writes the estimate onto the wrong workout, and the rolling fitness score is built from `getInRange` over those rows (`vo2max_service.dart:108`). | Low-Med | S |
| 19 | `lib/core/repositories/bp_calibration_repository.dart:87-104` — `upsertNewActive` single-active invariant | Deactivate-others-then-upsert inside `_db.transaction`, with an explicit `id.equals(...).not()` guard so a same-id re-save survives (`:96`). `getActiveForUser` / `watchActiveForUser` then `limit(1)` order by `capturedAtUtc DESC` (`:111-112`, `:122-123`), which masks a broken invariant rather than surfacing it. | A second active row silently wins by timestamp, so the user's *older* cuff anchor drives every displayed BP value (via rank 1's provider). | Low | S |
| 20 | `lib/core/sync/band_sync_service.dart:310-343` — `syncSteps` read-merge-write | Reads the existing `daily_metrics` row and copies only the five activity fields forward (`:326-334`), relying on `copyWith` to preserve cardiac/sleep columns. A missed field silently zeroes a persisted column. | `daily_metrics` is the source for scores and the Supabase mirror. Losing `hrv_rmssd_ms` here would zero Recovery for that day. | Low-Med | S |
| 21 | `lib/core/sync/sync_results.dart:52-57` — `totalSamples`, `failed`, `allOk` | `allOk` requires `aggregated == true` and folds retention in (`:54-57`); `totalSamples` sums counts that are explicitly "best-effort" (`:3`). These drive the debug screen and the tick breadcrumb (`periodic_sync_coordinator.dart:231-232`). | Misreported sync health only — the number an engineer reads when diagnosing a silent sync failure. | Low | S |
| 22 | `lib/core/sync/fall_sweep_service.dart:75-131` — sample-count gate, median 1 g calibration, mg conversion, `fsHz` derivation | `< 50` samples → skip (`:75`); median (not mean) magnitude as the 1 g reference (`:88-95`) with a zero guard (`:96-104`); `fsHz = accelX.length / durationS` (`:116`), which is an *average* rate — a bursty stream mis-scales every window in `FallDetector.detect`. | Missed or spurious fall events. `FallDetector` itself is well covered (`test/fall_detector_test.dart`, 257 loc); the calibration wrapper feeding it is not. | Low-Med | M |
| 23 | `lib/core/repositories/sync_state_repository.dart:77-125` — `recordSuccess` / `recordFailure` read-modify-write | Both re-read then `insertOnConflictUpdate` against `idx_sync_state_unique(device_id, metric_key)` (`app_database.dart:243`). `recordFailure` must preserve `lastSuccessfulSync` (`:115-117`) and `bytesSyncedLifetime` (`:121-122`); `recordSuccess` accumulates lifetime bytes (`:86`). | Only `latestSuccessfulSync` (`:143-151`) has a consumer — the retention/band-quiet alert. Wrong value → a "your band has gone quiet" alert that never fires or fires wrongly. | Low | S |
| 24 | `lib/core/repositories/daily_metrics_repository.dart:237-244` — `softDeleteBefore` compares `_dateOnly(cutoff)` against `local_date` | The caller passes a **UTC** cutoff (`retention_sweep_service.dart:87-90,108`), but `local_date` is a local date string (`daily_metrics_repository.dart:108`). `_dateOnly` on a UTC DateTime yields the UTC calendar day. | Off by at most one day at the 365-day retention edge. Cosmetic. | Low | S |
| 25 | `lib/core/repositories/nightly_record_repository.dart:68-84` — `getHistoryBefore` fetches **all** rows then trims in Dart (`:81-83`) | The `limit` is applied to the tail after an unbounded query, and the doc contract is "oldest first, most recent LAST" (`:12-15`) — which `computeVascularLoad` depends on. A reversed list silently inverts the whole history window. | Cardio Load reads history from here (`cardio_load_service.dart:114-118`). Order inversion produces a plausible-looking but wrong score. Unbounded fetch is a perf issue only. | Low | S |
| 26 | `lib/core/providers/device_status_providers.dart:17-24` — `isSyncingProvider` | `async*` with `await Future.delayed(5s)` inside `await for` back-pressures the tick stream; ticks arriving during the window are buffered, so the indicator can lag arbitrarily. | The "syncing" icon in the home header. | Med | S |

Not ranked, considered and dismissed — see §3.

## 2. Top 10 — test double and acceptance criterion

Every double below is either `NativeDatabase.memory()`, `ProviderContainer`, or a
**hand-written fake implementing the existing interface** in the
`test/cardio_load_frame_test.dart:159-163` idiom. No new package.

### 1. `_anchorFor` HR-coupling on an HR-less calibration

- **Double:** `ProviderContainer(overrides: [bpCalibrationRepositoryProvider.overrideWithValue(_FakeCalRepo(...)), bpRepositoryProvider.overrideWithValue(_FakeBpRepo(...))])`. Both fakes are hand-written over the abstract interfaces (`bp_calibration_repository.dart:13`, `bp_repository.dart:10`) on the `_Fake` `noSuchMethod` base. `_anchorFor` is a private top-level function (`bp_calibration_providers.dart:45`) so the provider is the only reachable entry point. Precedent for faking `BpCalibrationRepository` this way: `test/alert_rules_test.dart:418`.
- **Acceptance criterion:** Given an active `BpCalibration` with `cuffSystolic: 130`, `cuffDiastolic: 85`, `hrAtCalibration: null`, and a latest `BpReading` of `118/76` with `pulseBpm: 70`, `calibratedLatestBpProvider` emits `displaySbp == 128` (raw 118 + the 130−120 constant offset), **not** `161` (`130 + 70 × 0.45`).

### 2. `_onTick` must not latch `_inFlight` when the sleep-onset detector stalls

> **Corrected after verification.** An earlier draft of this row claimed a *throw*
> from `isProbablyAsleep` escapes `_onTick`. It does not: the method wraps its
> entire body in `try { … } catch (e) { return false; }`
> (`sleep_onset_detector.dart:91,135-138`) and its doc-comment states the contract
> — "Never throws — any repo error resolves to awake" (`:88-89`). The throw half of
> this finding is **already defended by the callee**. What survives is the **hang**
> half: the callee's try/catch cannot rescue a read that never completes, and this
> is the one await in `_onTick` outside `_bounded`. Test the stall, not the throw.
> (A throw-path test is still cheap to add in the same file as a contract guard on
> the boundary, but it does not prove a live defect.)

- **Double:** construct `PeriodicSyncCoordinator` directly — every collaborator is a ctor param (`periodic_sync_coordinator.dart:40-56`), including `tickStream`, so drive it with a `StreamController<int>()`. Hand-written fakes for `BandSyncService`, `DeviceRepository` (returns one active `Device`), `DailyRetentionGate`, `BleService` (`currentConnectionState => connected`), `CloudSyncService`, `AlertEvaluator`, `ScheduledPpgCaptureService`, `NightlyBpCaptureService`, `FallSweepService`, `BandReconnector` (**required** — see B3), and a `SleepOnsetDetector` whose `isProbablyAsleep` throws. `class _FakeBle implements BleService` is already proven at `test/scheduled_ppg_rest_gate_test.dart:124`.
- **Acceptance criterion:** With a `SleepOnsetDetector` whose `isProbablyAsleep` returns a `Completer<bool>().future` that never completes, pushing tick #1 and then tick #2 results in tick #2 still being *processed* (not dropped at `:188` by a latched `_inFlight`) — i.e. `fallSweep.run()` is reached at least once. This test **fails today** and stays failing until `isProbablyAsleep` is moved inside `_bounded` (`:162-169`); land the wrap as part of the same change.

### 3. Step-bucket day window must be half-open

- **Double:** `AppDatabase(NativeDatabase.memory())` (needs B1) wired into `StepBucketRepositoryImpl(db)` directly — no `ProviderContainer` needed, the impl ctor takes the db (`step_bucket_repository.dart:46`).
- **Acceptance criterion:** For `tzOffsetMin: 480` (UTC+8) and `localDate: 2026-08-10`, given buckets at local `2026-08-10 23:45` (steps 100) and local `2026-08-11 00:00` (steps 100), `getTotalStepsForDay` returns `100`, not `200`, and `getForDay` returns exactly 1 row — matching what `stepsInWindow(from: local 08-10 00:00, to: local 08-11 00:00)` returns for the same data.

### 4. HRV re-pull is idempotent

- **Double:** `AppDatabase(NativeDatabase.memory())` → `HrvRepositoryImpl(db)`.
- **Acceptance criterion:** Calling `insertMany` twice with two `HrvSample`s that share `(userId, deviceId, capturedAt, source)` but carry **different** `id`s (mirroring `sync_adapters.dart:328`'s `_uuid.v4()`) and different `rmssdMs` leaves `countInRange` at `1`, and `getLatest` returns the **second** call's `rmssdMs`.

### 5. `getHourlySnapshots` buckets on local clock hours and excludes `to`

- **Double:** `AppDatabase(NativeDatabase.memory())` → `BpRepositoryImpl(db)`.
- **Acceptance criterion:** For a UTC+5:30 user with readings at local `01:15`, `01:45`, `02:15` and `from`/`to` spanning `01:00`–`03:00` local, `getHourlySnapshots` returns 2 rows (one per **local** hour: the `01:15` and the `02:15`), not 3; and a reading stamped at exactly `to` is excluded.

### 6. `syncAll` step order and continue-past-failure

- **Double:** hand-written fakes for all 13 `BandSyncService` ctor collaborators (`band_sync_service.dart:31-45`), each recording its calls into a shared `List<String> log`. The `BleService` fake returns canned maps in the same shape the adapters already parse in `test/sync_adapters_bp_test.dart:13`.
- **Acceptance criterion:** One `syncAll` call produces a BLE call log whose order is exactly `getHrHistory(0), getHrHistory(1), getSpO2History, getSleepHistory, getDailyTotals, getStepBucketHistory, getHrvHistory(0), getHrvHistory(1), getHrvHistory(2), getStressDay(0), getStressDay(1), getBpHistory`, `getBpDay` is **never** called, and when `getSleepHistory` throws, the remaining 8 calls still happen and the returned `SyncRunResult.failed` has exactly one entry with `metric == 'sleep'`.

### 7. Outbox `enqueue` must survive a duplicate row

- **Double:** `AppDatabase(NativeDatabase.memory())` → `CloudSyncOutboxRepository(db)`. Insert the duplicate directly through `db.into(db.cloudSyncOutbox).insert(...)` to simulate the two-engine race.
- **Acceptance criterion:** With two pre-existing `cloud_sync_outbox` rows sharing `targetTable: 'daily_metrics'` and `recordId: 'x'`, `enqueue(tableName: 'daily_metrics', recordId: 'x')` completes without throwing and leaves `getPending()` returning at most the rows that already existed (no third row).

### 8. Score backfill must not skip a calendar day across DST

- **Double:** none available today — `refreshAfterAggregation` reads `DateTime.now()` at `score_refresh_service.dart:58`. **Refactor first (B2):** add `ScoreRefreshService({..., DateTime Function()? now})` defaulting to `DateTime.now`. Then hand-written fakes for `RecoveryScoreService`, `CardioLoadService`, `Vo2MaxService`, `MentalWellnessService`, each recording the `localDate` it was called with.
- **Acceptance criterion:** With the injected clock at `2026-03-08 00:30` local in a zone that springs forward at `02:00` that morning, `recoveryScore.computeForDay` is called with the calendar dates `2026-03-06`, `2026-03-07`, `2026-03-08` in that order — i.e. three distinct dates, none skipped.

### 9. `getMorningResting` window is frame-stable

- **Double:** `AppDatabase(NativeDatabase.memory())` → `HrvRepositoryImpl(db)`.
- **Acceptance criterion:** Given samples at local `03:59`, `04:01` and `08:59` on 2026-08-10 and one at local `09:01`, `getMorningResting(forDate: DateTime(2026,8,10))` returns the `04:01` sample; calling it with the *same instant* expressed as a UTC-flagged `DateTime` returns the same sample (today it does not — the local ctor at `:163` reads the UTC calendar fields).

### 10. Retention gate 24h boundary

- **Double:** `SharedPreferences.setMockInitialValues({...})` — `shared_preferences` is already a direct dependency (`pubspec.yaml`, resolved 2.5.3 at `pubspec.lock:970`) and this is the plugin's own in-package test hook, not a mocking library. Requires `TestWidgetsFlutterBinding.ensureInitialized()`. Plus a hand-written `_FakeRetentionSweep implements RetentionSweepService` recording `sweepAll` calls. Note `RetentionSweepService` already accepts an injectable `now` (`retention_sweep_service.dart:86`) — the gate does not.
- **Acceptance criterion:** With `retention_last_swept_at_utc_sec` preset to `now − 23h`, `maybeSweep()` returns `skipReason == 'last ran 23h ago'` and `result == null` and the fake's `sweepAll` was not called; preset to `now − 25h`, it returns a non-null `result`, calls `sweepAll` exactly once, and the pref is updated to within 5 s of now.

## 3. Considered and not worth testing

| Seam | Why not |
|---|---|
| `SupabaseSyncRepository` — all four push methods + all four map builders (`supabase_sync_repository.dart:22-157`) | No seam. The ctor takes a concrete `SupabaseClient` (`:17`), each method chains `.from(...).upsert(...)` (`:24`), and the retry wrapper is **static** (`SupabaseConnectionMonitor.withRetry`, `:23`). A hand-written fake would have to implement `SupabaseClient` + `SupabaseQueryBuilder`, and mocking libraries are banned (`CLAUDE.md:107`). The map builders could be extracted to pure top-level functions and tested — worth doing **if** a Supabase column mismatch ever bites, but it is a schema-drift problem, not a logic problem, and PostgREST fails loudly. Skip. |
| `firmwareUpdateAvailableProvider` (`device_status_providers.dart:28`) | `Provider<bool>((_) => false)`. A hard-coded constant. |
| `userProfileProvider` (`user_profile_provider.dart:12-15`) | Three-line pass-through to `UserRepository.getProfile`. Its only interesting property (router redirect behaviour) is reachable only through the router/UI, which is out of scope. |
| The five sparkline providers (`health_data_providers.dart:110-163`) | Identical five-line `watchInRange(...).map((rows) => rows.map(...).toList())` shapes over one field each. The only non-trivial part is `_last24hCutoff()` (`:107-108`), and its failure mode is a visibly empty chart. Test the repository `watchInRange` (rank 13) instead. |
| The five `latest*Provider` and three `latest*ScoreProvider` (`health_data_providers.dart:54-103`) | One-line delegations to `repo.watchLatest`. Failure is loud (empty card). Test `watchLatest` at the repository. |
| Every repository `_rowToDomain` / `_toCompanion` field mapping (e.g. `bp_repository.dart:42-74`, `daily_metrics_repository.dart:65-142`) | Mechanical 1:1 column↔field copies. A wrong mapping either fails to compile or produces an obviously wrong number in the UI. Covered incidentally by any round-trip test written against `NativeDatabase.memory()` — don't write dedicated ones. |
| `TimeSeriesRepository` (`time_series_repository.dart`, 41 loc) | Pure abstract; no behaviour. |
| `SyncStepResult` / `RetentionGateOutcome` value classes (`sync_results.dart:8-30`, `retention_gate.dart:7-12`) | Data holders. `SyncRunResult`'s three getters are ranked at 21; the rest is `final` fields. |
| `BatteryTelemetryRepository` (`battery_telemetry_repository.dart`) — insert/getSince/exportCsv | Debug-only data that "lives only in local SQLite" and is explicitly "not part of the cloud-sync footprint" (`tables.dart:485-489`). `BatteryDrainSummary.bandDrainPctPerHour` (`:54-60`) has real arithmetic (the `<0.01h` guard, the negative-delta case the doc-comment at `:52-53` says should surface as zero but which the code does **not** clamp) — a 15-minute pure test if someone is already in the file, but the blast radius is one debug panel. |
| `NotificationLogRepository` (`notification_log_repository.dart`) | `insert` + two ordered `limit`ed selects. The rate-limit *policy* that depends on `lastFiredFor` is already covered at the evaluator (`test/alert_evaluator_test.dart:197` fakes this repo). |
| `DeviceRepository` mutators — `updateFirmwareInfo`, `updateCapabilities`, `deactivate`, `reactivate`, `rename` (`device_repository.dart:158-210`) | Single-column `update ... where id = ?`. Failure is immediate and visible in Settings. `getByMacAddress` is the one method here with a real hazard (rank 11). |
| `UserRepository.create` / `getById` / `deleteProfile` (`user_repository.dart:33-59`, `:62-66`, `:113-117`) | Trivial CRUD. `getByEmail` (`:69-74`) shares rank 11's `getSingleOrNull`-over-a-non-unique-index hazard (`app_database.dart:250`), but nothing in `lib/core` calls it — dead weight until a real auth flow lands. |
| `*.g.dart` (`app_database.g.dart`, all `*.freezed.dart`) | Generated. |
| `BandReconnector.tryNow` guard ladder (`band_reconnector.dart:43-57`) | Worth 20 minutes eventually (the `_reconnecting` re-entrancy guard and the connected/connecting early-return are real), but B3 makes it awkward and its failure mode — a redundant `ble.connect` call — is harmless and self-correcting. Not in the first tranche. |

## 4. First five tests — hand this to `/execute`

Flat `test/<name>_test.dart`, matching the existing convention (`ls test/` is
flat, 28 files, no subdirectories, no shared helper file — each test file builds
its own fixtures inline).

---

**#1 — `test/bp_calibration_providers_test.dart`**
Target: `lib/core/providers/bp_calibration_providers.dart:45-94`.
Setup: `ProviderContainer(overrides: [bpCalibrationRepositoryProvider.overrideWithValue(_FakeCalRepo(cal)), bpRepositoryProvider.overrideWithValue(_FakeBpRepo(reading))])`, both fakes hand-written over the abstract interfaces on a `_Fake` `noSuchMethod` base copied from `test/cardio_load_frame_test.dart:159-163`. `_FakeCalRepo.watchActiveForUser` returns `Stream.value(cal)`; `_FakeBpRepo.watchLatest` returns `Stream.value(reading)`. Await the first non-loading value from `container.read(calibratedLatestBpProvider.future)`.
Assertion: §2 criterion 1 — `displaySbp == 128` for a `130/85` cuff with `hrAtCalibration: null` and a `118/76 @ 70 bpm` reading.
Why #1: zero prerequisites — no schema change, no clock injection, no timers. Highest severity-per-hour in the whole audit: a wrong number on a medical readout, reachable from three screens, provable in one `expect`. Also lands the `ProviderContainer` pattern in the repo for the first time.

---

**#2 — `test/step_bucket_repository_test.dart`** *(fixture step)*
Target: `lib/core/repositories/step_bucket_repository.dart:101-159`.
Setup: **Step 1 is the fixture** — change `lib/core/database/app_database.dart:47` to `AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());`. Verify with `flutter analyze` (must stay "No issues found!", `CLAUDE.md:19`). Then in the test: `import 'package:drift/native.dart';`, `final db = AppDatabase(NativeDatabase.memory());`, `addTearDown(db.close);`, `final repo = StepBucketRepositoryImpl(db);`. Insert a `users` row and a `devices` row first — `StepBuckets.userId`/`deviceId` are FK-referenced (`tables.dart`), and drift's memory DB enforces them.
Assertion: §2 criterion 3 — 100 steps, not 200, for the two buckets straddling local midnight at `tzOffsetMin: 480`.
Why #2: it carries the one-line schema-ctor change that unblocks tests #3 and #4 and every future repository test, and it pays for itself immediately with the highest-likelihood persisted-data defect in the audit.

---

**#3 — `test/hrv_repository_test.dart`**
Target: `lib/core/repositories/hrv_repository.dart:63-70` (and `:159-174` as a second `group`).
Setup: same `AppDatabase(NativeDatabase.memory())` fixture as #2 (independently constructed in this file — no shared helper). `HrvRepositoryImpl(db)`.
Assertion: §2 criterion 4 — double `insertMany` with different random ids but identical `(userId, deviceId, capturedAt, source)` leaves `countInRange == 1` and the later value wins.
Why #3: it is the direct proof that `syncAll`'s three-times-per-tick HRV pull (`band_sync_service.dart:106-108`) cannot duplicate — the single riskiest write-path assumption in the app, because HRV is the input both Recovery and Cardio Load are gated on. Depends only on #2's ctor change.

---

**#4 — `test/bp_repository_hourly_test.dart`**
Target: `lib/core/repositories/bp_repository.dart:176-199`.
Setup: same memory-DB fixture. `BpRepositoryImpl(db)`. Insert readings at fixed UTC instants chosen so they land at local `01:15`, `01:45`, `02:15` for a +5:30 offset.
Assertion: §2 criterion 5 — 2 rows (one per local hour), and a reading stamped exactly at `to` is excluded.
Why #4: `getHourlySnapshots` is the sole BP path into `daily_metrics` (`daily_aggregator.dart:204,214`) and thence into Supabase. It is the last of the three "silently corrupts a persisted rollup" repository seams, and it reuses #2's fixture verbatim.

---

**#5 — `test/band_sync_service_test.dart`**
Target: `lib/core/sync/band_sync_service.dart:82-157`.
Setup: no database. Thirteen hand-written fakes for the ctor params at `:31-45`, all on the `_Fake` `noSuchMethod` base. `_FakeBle implements BleService` (precedent: `test/scheduled_ppg_rest_gate_test.dart:124`) appends each method name + `dayOffset` to a shared `List<String>` and returns payload maps in the shape the adapters already accept (`test/sync_adapters_bp_test.dart:13`). Repository fakes record `insertMany` calls and return void.
Assertion: §2 criterion 6 — exact BLE call order, `getBpDay` never called, and one throwing step yields exactly one `SyncRunResult.failed` entry while the other 8 calls still fire.
Why #5: it is the first test of `lib/core/sync/` at all, and it pins four H59 quirks (HRV offsets 0/1/2, HR today+yesterday, HR-before-BP, never `getBpDay`) that currently exist only as prose comments. Independently landable — no fixture, no refactor, no dependency on #1-#4.

## Unverified

1. **Reachability of the rank-1 BP calibration defect.** The code path is
   confirmed (`bp_calibration_providers.dart:59-63` → `bp_formula.dart:143` →
   `:47`). Whether a `BpCalibration` row can actually be persisted with
   `hrAtCalibration == null` depends on the save path in
   `lib/features/blood_pressure/` — out of scope, not read. To check: read the
   calibration-save call site and confirm whether `hrAtCalibration` is always
   captured. If it is always non-null, rank 1 drops to a latent-defect guard and
   rank 2 becomes #1.
2. **`test/zz_probe_a4f2_test.dart` — deleted during this audit, cause unknown.**
   Present at the start (43 lines, listed by `wc -l test/*.dart` and by an `ls
   test/` taken before the audit began), absent at the end. It was **untracked in
   git** (`git log -- test/zz_probe_a4f2_test.dart` returns nothing), so it is not
   recoverable from the repo and it is not in `~/.Trash`. Never read, so its
   contents are unknown. `test/` now holds 28 `*_test.dart` files; `CLAUDE.md:20`
   says 28 files / 243 tests, so the tree now matches the documented count and this
   file was a 29th stray probe. Not counted in the coverage baseline above. If it
   mattered, recreate it from memory — nothing here can restore it.
3. **Whether `onUpgrade` and `onCreate` produce the same index set.** Rank 4's
   likelihood rests on this. `onCreate` calls `_createIndices()`
   (`app_database.dart:58`); `onUpgrade` creates indices inline per migration
   step (`app_database.dart:64-69` and following). Verifying convergence means
   reading all 12 migration steps and diffing them against the 40-odd statements
   in `_createIndices` — `core/database` is supporting context, not audited. The
   proposed test #3 catches the divergence on the `onCreate` path only.
4. **`SharedPreferences.setMockInitialValues` on 2.5.3.** Confirmed present in
   the package's own test suite
   (`~/.pub-cache/.../shared_preferences-2.5.3/test/shared_preferences_devtools_extension_data_test.dart:41`)
   but not exercised against this app's binding setup. If it needs
   `TestWidgetsFlutterBinding.ensureInitialized()` in a non-widget test, add that
   line; no package change either way.
5. **`flutter test` was not run** during this audit. Test counts come from
   `grep`, not from a run. No test file was created or modified.

## Adversarial verification 2026-08-10

Second pass by a different model, run under `metric-validation` rule 6: the brief
was to **refute** each finding, defaulting to "not a defect" when uncertain.
Scope: **Unverified §1** (rank 1 reachability) and **Unverified §3** (rank 4
index convergence). Source + `git` history only — `flutter test` and
`flutter analyze` still not run, no file outside this section changed.

### Rank 1 — BP calibration HR-coupling — **CONFIRMED** (live defect, not a latent guard)

Refutation attempted: prove `hrAtCalibration` is always captured, which would
demote this to a latent guard. **It is not.** The write path admits null on two
independent routes and has no guard against it.

| # | Link in the chain | Evidence |
|---|---|---|
| 1 | There is exactly **one** write path for a `BpCalibration` row: `BpController.saveCalibration` → `upsertNewActive`. No other construction site exists in `lib/` (`grep "BpCalibration("` returns only the freezed factory, the repository's `_rowToDomain`, and this call). | `bp_controller.dart:118-132` |
| 2 | It sets `hrAtCalibration: hrNow` where `hrNow = _ref.read(latestHrSampleProvider).valueOrNull?.bpm` — an `int?` with no fallback, no guard, no retry. | `bp_controller.dart:115`, `:124` |
| 3 | The field is nullable end-to-end: freezed model, drift column, companion. Nothing coerces it. | `bp_calibration.dart:21`, `tables.dart:345`, `bp_calibration_repository.dart:71` |
| 4 | The save flow validates SBP/DBP ranges and `sbp > dbp` only. HR is never mentioned, and the flow cannot fail on a missing HR. | `blood_pressure_screen.dart:1241-1268` |

**Null route A — empty `hr_samples` (the likely one).** `latestHrSampleProvider`
is `repo.watchLatest(...)` (`health_data_providers.dart:54-57`); with no HR rows
it emits `AsyncData(null)` and `?.bpm` yields null. A user who pairs a ring and
calibrates before the first HR history sync lands hits this — and the app
actively steers them there ("Calibrating now takes about 2 minutes and
significantly improves accuracy", `blood_pressure_screen.dart:1054`, on a card
shown when no calibration exists).

**Null route B — provider not yet resolved.** Nothing in `features/blood_pressure/`
watches `latestHrSampleProvider`; its only watchers are
`home_screen.dart:72` and `heart_rate_screen.dart:236`. A `read` of a
never-listened `StreamProvider` returns `AsyncLoading`, so `valueOrNull` is null
on any entry path that has not built the home screen — and `/blood-pressure` is
a top-level route, not a child of the home shell (`router.dart:93` vs `:81`).

**The reading side does supply HR, so the HR-coupled branch really fires.** Both
band BP decoders stamp `pulseBpm` (`sync_adapters.dart:172` timing-monitor,
`:237` today-from-HR), which is what `watchLatest` returns for a normal user.
`applyBpCalibration` then branches on `hr != null` (`bp_formula.dart:143`) and
computes `cuff.systolic + (hr − 0) × 0.45` (`:47`). Confirmed as the audit
describes.

**Severity: rank 1 is still rank 1**, and its "Likelihood: Med — unverified" cell
should now read confirmed-reachable. Two corrections to the row, though:

**(a) The inflation is a *constant*, not `≈0.45 × pulse`.** For a band-derived
reading the raw value already carries the same `0.45 × hr` term, so it cancels:

```
raw            = 80.75 + ageCoef + 0.45·hr        (bp_formula.dart:60-65 expanded)
buggy display  = cuffSbp + 0.45·hr                (:47, anchor HR = 0)
intended       = raw + (cuffSbp − 120)            (:150)
buggy − intended = 39.25 − ageCoef                ← no hr term
```

With `_ageBpCoefficient` (`bp_formula.dart:37`) that is **+49 mmHg under 20,
+34 at 20-29, +24 at 30-39, +19 at 40-49, +14 at 50-59, +9 at 60+** — dependent
on age bracket and independent of pulse. The audit's "+27…+36 mmHg at 60-80 bpm"
lands in the right bucket for a young user by coincidence, not by mechanism. The
error *does* scale with the reading's HR for a user-entered cuff row
(`storeManualReading`, `bp_controller.dart:77-98`), where the raw value is not a
`BpFormula` output — but those are not what `watchLatest` normally returns.

**(b) The acceptance criterion's counter-value is off by one.**
`130 + 70 × 0.45 = 161.5`, and `(161.5).round()` is **162** in Dart, not 161.
The expected value (`128`) is correct. Displayed pair for that fixture is
**162/117** (`calDbp` preserves the 45 mmHg cuff gap, `bp_formula.dart:73-77`).

**(c) A second instance of the same defect, outside the audited scope.**
`_bpAnchorFor` in the BP screen does `hrAtCalibration: cal.hrAtCalibration ?? 0`
(`blood_pressure_screen.dart:488`) and then passes `hr: r.pulseBpm`
(`:499`) — identical bug, applied to **every point of the BP trend chart**, not
just the headline. Whatever fix lands in `bp_calibration_providers.dart:45-70`
has to land here too, or the chart and the headline will disagree. The
hypertension alert is **not** affected: it passes `hr: null` explicitly, so its
`hrAtCalibration: 0` is genuinely inert (`hypertension_risk_rule.dart:91-100`).

**Severity caveat that belongs in the row** (CLAUDE.md "Blood pressure" standing
warning): the "correct" branch is not clinically better than the buggy one. Both
are arithmetic over HR and age with no pressure sensor and no pulse-transit-time
term. This is a **display-magnitude defect** — the app shows a number ~10-49 mmHg
higher than its own model intends, on a readout users read as medical — not a
measurement-accuracy defect. Test #1 remains the right first test; the
justification is "the app contradicts its own model on a medical-looking
readout", not "the calibrated value is accurate".

### Rank 4 — HRV dedup: do `onCreate` and `onUpgrade` converge? — **REFUTED**

**Answer: yes, they converge. Zero divergences in the index set**, and
`idx_hrv_dedup` specifically is present on every reachable install path.

`onUpgrade` never needs to create an index for a table that already existed at
the user's install version, because `onCreate` runs `_createIndices()` in full
(`app_database.dart:56-59`). So convergence fails only if an index was added to
`_createIndices` *after* v1 without a matching migration step. Diffing all 12
migration steps against the 32 statements in `_createIndices`
(`app_database.dart:199-256`):

| Index group | Created by | Convergent? |
|---|---|---|
| 22 indices present at **v1** — `idx_hr_*` ×3, **`idx_hrv_user_time`, `idx_hrv_dedup`**, `idx_spo2_*` ×2, `idx_bp_*` ×3, `idx_step_*` ×2, `idx_daily_user_date`, `idx_sleep_user_time`, `idx_epoch_session`, `idx_baseline_*` ×2, `idx_sync_state_unique`, `idx_devices_*` ×2, `idx_users_*` ×2 | `onCreate` only — their tables are all v1 tables, never re-created by a migration step | ✅ every install path runs `_createIndices` |
| `idx_stress_user_time`, `idx_stress_dedup` | `from < 2` (`:64-69`) — identical DDL to `:209-210` | ✅ |
| `idx_bpcal_user_time`, `idx_bpcal_user_active` | `from < 3` (`:75-80`) ≡ `:233-234` | ✅ |
| `idx_battery_time` | `from < 4` (`:86-88`) ≡ `:236` | ✅ |
| `idx_exercise_user_time`, `idx_exercise_dedup` | `from < 5` (`:93-98`) ≡ `:238-239` | ✅ |
| `idx_notiflog_user_type_time` | `from < 6` (`:103-105`) ≡ `:243` | ✅ |
| `idx_scores_user_type_date` | `from < 8` (`:116-118`) ≡ `:231` | ✅ |
| `idx_nightly_records_user_date` | `from < 9` (`:123-126`) ≡ `:245` | ✅ |
| `cloud_sync_outbox` | no index in either path | ✅ convergent (and that is exactly rank 7's hazard — a real defect, but not a *divergence*) |

Git history closes it. `_createIndices` at the initial commit
(`018a9e0`, `schemaVersion => 1`) already contained `idx_hrv_dedup` and
`idx_hrv_user_time`, and the hrv statements are byte-identical in all nine
commits that touched the file. `HrvSamples` is in the v1 table set
(`git show 018a9e0:lib/core/database/tables.dart` — 13 tables, `HrvSamples`
among them) and no migration step ever drops or re-creates it. **There is no
install path that reaches v13 without `idx_hrv_dedup`.**

Consequence for the ranking: rank 4's likelihood cell ("Med — nothing asserts
they converge") should read **Low**. The test itself is still worth writing —
it pins the dedup contract against a future adapter change, and `sync_adapters.dart:328`'s
`_uuid.v4()` means the index is the *only* thing standing between three pulls
per tick and triplicated HRV — but it is a regression guard, not a live-defect
proof. Test #3's "single riskiest write-path assumption" framing overstates it.

### Adjacent finding, surfaced by the migration diff — **CONFIRMED BY EXECUTION**, fixed 2026-08-10

Not part of the three findings under review, but it falls out of reading all 12
steps and is a harder failure than anything in §1:

`exercise_sessions` is created at `from < 5` with `m.createTable(exerciseSessions)`
(`app_database.dart:92`), and drift's `createTable` emits the **current** table
definition — which already includes `vo2max_ml` and `vo2_confidence`
(`tables.dart:475-476`). The `from < 10` step then runs
`m.addColumn(exerciseSessions, exerciseSessions.vo2maxMl)` unconditionally
(`app_database.dart:132-133`). For any device upgrading from **schema 1-4**
straight to ≥10, both blocks execute in the same `onUpgrade`, so the second
issues `ALTER TABLE exercise_sessions ADD COLUMN vo2max_ml` against a table that
already has it → SQLite `duplicate column name` → the migration throws and the
database fails to open.

Shipped versions per git are 1, 2, 3, then 7 (`39806be` jumps 3 → 7), so the
exposed set is any install still at v1-v3. `exercise_sessions` is the only table
with both a `createTable` step and a later `addColumn` step — `daily_metrics`
takes `addColumn` at v7/v13 but is a v1 table, so its `createTable` never
re-runs.

**Executed 2026-08-10. It reproduces.** `test/app_database_migration_test.dart`
stamps a real in-memory SQLite database with each historical schema and lets
drift dispatch the actual `onUpgrade`. Pre-fix, 1 of 6 tests passed:

```
00:00 +0 -1: schema 1 -> 13 opens … [E]
  SqliteException(1): while executing, duplicate column name: vo2max_ml, SQL logic error (code 1)
    Causing statement: ALTER TABLE "exercise_sessions" ADD COLUMN "vo2max_ml" REAL NULL;
  package:drift/src/runtime/query_builder/migration.dart 465:12  Migrator.addColumn
  package:hlth_app/core/database/app_database.dart 132:21        AppDatabase.migration.<fn>
00:00 +1 -5: Some tests failed.
```

`from` = 1, 2 and 3 all threw at `app_database.dart:132` — the predicted line —
and the throw happens inside `DelegatedDatabase._runMigrations`, so the
executor never opens: **not a degraded database, an unopenable one.** `from` = 7
was the single pre-fix pass, which is the control: it already had
`exercise_sessions` without the VO2 columns, so there was nothing to collide
with. The prediction was right in both directions.

**Fix** (`app_database.dart:141`): guard the step on the versions that actually
need it — `if (from >= 5 && from < 10)`. Installs at 1-4 get both columns from
the `from < 5` `createTable`; only 5-9 have the table without them. Removing
the guard again fails 5 of the 6 tests, so the test is a live regression guard,
not a vacuous one. Post-fix: 6/6, `flutter analyze` clean, full suite green.

Coverage is all twelve origin versions, not just the four git committed — git is
not a distribution record, and an internal build could have put any intermediate
version on a device. 15 tests: one per `from` ∈ 1..12 asserting the database
opens with **exactly one** `vo2max_ml` / `vo2_confidence` (which catches a throw,
a duplicate, and an omission alike), plus data preservation across the
`addColumn` at `from` = 7, plus one case asserting every origin converges on the
same schema as a fresh `onCreate` (table set, per-table column sets, and index
name → normalised DDL).

That convergence case is the executed form of Rank 4's question, and it
generalises past this bug: a future `addColumn` on a table some migration step
also `createTable`s breaks the low origins, and an index added to
`_createIndices` without a matching migration step breaks the high ones. Either
way this test goes red. The pre-fix failure split is the evidence it discriminates
— 6 failures at origins 1-4 (plus the two cross-cutting cases), 9 passes at 5-12.

Note the fixture technique, since drift's documented `SchemaVerifier` helpers
need per-version schema dumps this repo never generated:
`NativeDatabase.memory(setup: …)` hands over the raw sqlite3 handle after open
but *before* drift reads `user_version` (drift 2.28
`lib/src/sqlite3/database.dart` `_initializeDatabase`), so `setup` writes the
historical DDL and stamps the version, and the real `onUpgrade` runs on top.
The historical DDL is drift's own emitted output, reduced per version; `git diff
ac06c9a HEAD -- lib/core/database/tables.dart` is three hunks (`DailyMetrics`
+3 columns, five new table classes) so no pre-v3 table definition changed and
the reduction is exact.

### Rule 6 — what the next pass should attack

This pass is one model refuting another and does **not** settle these. A third
model should try to refute, specifically:

1. That `latestHrSampleProvider` can be unresolved or empty at
   `bp_controller.dart:115` — the strongest counter would be evidence that some
   bootstrap path eagerly warms it, or that `hr_samples` is never empty once a
   band is paired.
2. That `_createIndices` has run on every real device — i.e. that no device in
   the field was ever created by `db/build_schema_db.py` or a hand-restored
   `.db` file that bypassed `onCreate`. The git diff proves the *code* converges;
   it does not prove every on-disk file came from that code.
3. ~~The `duplicate column name` claim above, by actually running the 3 → 13
   migration rather than reading drift's `createTable` semantics.~~
   **Settled 2026-08-10 — executed, reproduced, fixed.** See the adjacent-finding
   section above and `test/app_database_migration_test.dart`.

   What a third model should attack next is the **fixture**, not the claim. The
   historical DDL is reconstructed (drift's emitted v13 output, reduced per
   version) rather than dumped from the shipped binaries, because this repo
   never generated the per-version schema dumps drift's `SchemaVerifier` wants.
   The reduction is argued from a three-hunk `git diff` on `tables.dart`, and
   that argument is the load-bearing part: if a v1-v3 table definition ever
   changed *without* a migration step, the fixture would encode the same drift
   as the production code and both would agree on something wrong. The strongest
   refutation is a real on-disk `.db` from a v1-v3 device compared against
   `_schemaAt(n)`. That is also the residue of item 2 — the code path is now
   proven, the population of on-disk files still isn't.
