# BLE Sync Path — Diagnosability Audit & Instrumentation Plan

> **Audit pass only. No code changed.** Scope: `lib/core/ble/` (1,712 lines) and
> `lib/core/sync/` (1,388 lines), plus the native bridges and the Drift/Supabase
> seams they touch.

**The question this plan exists to answer:** a user's band silently stops
syncing in the field. What do we need on disk, the next morning, to know why —
without a crash backend, without logcat, and without the phone in our hands?

**Headline finding:** the app *already has* a detector for exactly this failure
(`RetentionRule` → "band hasn't synced in 3 days") and it is **permanently
silent**, because the table it reads from is never written to. Fixing that is
~30 lines and requires no new schema. Everything else in this plan is built on
top of it.

---

## 1. Define "working" first

Per the observability skill: telemetry without a question is noise. Four
questions an on-call engineer (today: you) will ask when a band goes quiet.
Every signal proposed below maps to one of them; anything that maps to none is
not in this plan.

| # | Question | Why it's the right question |
|---|---|---|
| **Q1** | **Is the engine alive?** Did a sync tick fire in the last N hours, in either engine (UI or headless)? | The #1 field failure on Android is OEM battery management killing the process. If ticks stopped, nothing downstream matters. |
| **Q2** | **Is the link up?** Was the band connected at tick time, and if not, how long has it been down and how many reconnects have been attempted? | Second-most-likely cause, and the one the 2026-07-07 overnight failure was. |
| **Q3** | **Is the band awake?** Ticks fire, link is up, sync "succeeds" — but every step returns zero rows because scheduled monitoring was never enabled. | H59 quirk #1. This is the failure mode that looks *identical to healthy* in every signal we currently emit. |
| **Q4** | **Which step broke, and for how long?** One metric failing for days while the rest succeed. | `hrv(d=1)` failing silently for a week starves Recovery *and* Cardio Load, and the UI just shows "not enough data". |

A fifth, downstream of these: **Q5 — did data land but derived scores freeze?**
(the 2026-07-22 aggregation freeze). Partly instrumented already; see §4.

---

## 2. What exists today

Not "nothing" — there are four partial mechanisms, none of which compose.

### 2.1 `Breadcrumbs` — a file-backed ring buffer (the good one)

[breadcrumbs.dart](../../lib/core/services/breadcrumbs.dart) — 800-line
self-trimming plain-text file in app support dir, synchronous appends, survives
process death and engine swaps. Born from the 2026-07-07 post-mortem, and the
reasoning in its doc comment is correct.

- **26 call sites app-wide, 8 of them in `sync/`, and `0` in `ble/`.**
- Free-form prose (`'tick: synced 41 samples, 0 step errors'`). Not parseable,
  not aggregatable, no stable event names, no correlation id, no severity.
- Read path is a debug-screen button (`_showBreadcrumbs`, tail 120). Requires
  the physical device.
- One line logs a **MAC address** — see §6.

**Verdict: keep it.** It is the right *transport* for a human-readable tail. It
is the wrong *schema*.

### 2.2 `SyncStepResult` / `SyncRunResult` — structured, and thrown away

[sync_results.dart](../../lib/core/sync/sync_results.dart) is genuinely good
structured telemetry: per-metric `metric`, `count`, `error`, `note`, `extra`,
plus the verbatim band payload. `BandSyncService._guarded` already converts
every throw into one of these instead of aborting the sweep.

It is emitted on `PeriodicSyncCoordinator.runs`, a **broadcast stream whose only
subscriber is the debug screen.** Nothing persists it. The moment the tick
returns, the answer to Q4 is gone. The coordinator compresses a 13-step result
into one lossy prose line
([periodic_sync_coordinator.dart:231](../../lib/core/sync/periodic_sync_coordinator.dart#L231))
and drops the rest.

**This is the single biggest waste in the codebase: the data model for the
answer already exists and is discarded microseconds after it's built.**

### 2.3 `sync_state` — a dead table wired to a dead alert

[tables.dart:526](../../lib/core/database/tables.dart#L526) defines
`sync_state`: per (device, metric) watermarks — `lastSuccessfulSyncUtc`,
`lastAttemptedSyncUtc`, `lastSyncError`, `lastSyncedDayIndex`.
[sync_state_repository.dart](../../lib/core/repositories/sync_state_repository.dart)
implements `recordSuccess`, `recordFailure`, `getStaleMetrics`,
`latestSuccessfulSync` — with a unique index on `(device_id, metric_key)`.

**Callers of `recordSuccess` / `recordFailure` / `getStaleMetrics` in `lib/`:
zero.** The table is empty on every device in the field.

The one reader is
[retention_rule.dart:39](../../lib/core/services/alerts/retention_rule.dart#L39):

```
final lastSync = await syncStateRepo.latestSuccessfulSync(deviceId: device.id);
if (lastSync == null) return null; // never synced — don't nag a new user
```

`latestSuccessfulSync` returns `null` for every user, forever. The guard meant
to spare fresh installs swallows **all** users. So:

> The app ships a "your band stopped syncing" notification that can never fire,
> for the exact failure this audit is about.

This is finding #1 and the cheapest fix in the document.

### 2.4 `battery_telemetry` — the accidental heartbeat

[tables.dart:489](../../lib/core/database/tables.dart#L489) — one row per tick,
written fire-and-forget from the coordinator provider's `onTickIntervalMinutes`
hook. It *is* populated. It records battery %, cadence, and event type — and
nothing about whether the sync that followed worked.

Its real value today is unintentional: **it is currently the only durable
per-tick record that a tick happened at all**, which makes it a partial Q1
answer that nobody queries. It also proves the "one row per tick into Drift"
pattern is affordable (~48 rows/day at 30-min cadence).

### 2.5 Native bridges — asymmetric and ephemeral

| Side | Logging | Reachable in the field? |
|---|---|---|
| Android `BleManager.kt` | **149** `Log.*` calls | No — logcat only, rotates in hours on MIUI, needs `adb` and a tethered device |
| Android others (`SyncWatchdogWorker`, `BleForegroundService`, `HeadlessSyncEngine`, `SyncTickAlarm`, receivers) | 20 total | Same |
| iOS `ios/Runner/BLE/*.swift` (11 files) | **2** `NSLog` calls | Effectively dark |

`docs/TROUBLESHOOTING.md` §Diagnostic toolkit lists `adb logcat -s HlthBLE` as a
primary tool. That is a *developer-at-a-desk* tool, not a field tool, and it has
no iOS counterpart at all.

### 2.6 Debug screen in-memory log

[ble_debug_screen.dart:67](../../lib/features/debug/ble_debug_screen.dart#L67) —
200-entry `List<_LogEntry>`, dies with the process. Fine for what it is.

---

## 3. Gap analysis — can we answer the four questions today?

| Question | Answerable now? | Why not |
|---|---|---|
| **Q1** engine alive | ⚠️ Indirectly | `boot [engine]` crumbs + `battery_telemetry` row gaps. Requires eyeballing a text file on the device and inferring from absence. No "last tick at" value anywhere in the UI or DB. |
| **Q2** link up | ⚠️ Partially | `tick: band disconnected — attempting reconnect` crumb exists. But reconnect *outcome* isn't logged — only the attempt and the throw. A band that fails to reconnect 300 times overnight produces 300 identical lines and no summary. |
| **Q3** band awake | ❌ **No** | `setScheduledMonitoring` on the connect edge is wrapped in a bare `catch (_) {}` ([coordinator:157-158](../../lib/core/sync/periodic_sync_coordinator.dart#L157)). If it fails, the band records nothing, every sync step returns 0 rows, and the breadcrumb reads `tick: synced 0 samples, 0 step errors` — **indistinguishable from a healthy tick on a day the user didn't wear the ring.** |
| **Q4** which step, how long | ❌ **No** | `SyncRunResult.steps` is discarded (§2.2); `sync_state` is empty (§2.3). Only `failed.length` survives, as a number in a prose string, for one tick. |
| **Q5** scores frozen | ✅ Aggregation only | `aggregate: FAILED` and `scoreRefresh: FAILED` crumbs exist ([band_sync_service.dart:133,144](../../lib/core/sync/band_sync_service.dart#L133)). But the four `catch (_) {}` blocks *inside* `ScoreRefreshService` mean an individual engine throwing every single run is invisible — `refreshAfterAggregation` returns normally. |

---

## 4. Silent-failure inventory

**27 bare `catch (_)` blocks across `lib/core/ble/` + `lib/core/sync/`**, against
8 breadcrumb calls. Not all deserve logging — several are correctly silent. These
are the ones that can cause or mask "band silently stopped syncing", ranked:

| Rank | Site | What it hides |
|---|---|---|
| **1** | [coordinator:158](../../lib/core/sync/periodic_sync_coordinator.dart#L158) `setScheduledMonitoring` | **The dormancy fix failing.** H59 quirk #1: the band records *nothing* until this runs. Silent failure here = permanent zero-data, looking exactly like an unworn ring. Direct answer to Q3. |
| **2** | [coordinator:201](../../lib/core/sync/periodic_sync_coordinator.dart#L201) `prefs.setBool('has_bonded_band')` | The native `SyncWatchdogWorker` reads this to decide whether to revive the headless engine. If the write fails, the watchdog concludes "no band ever paired" and **stops reviving the process** — a permanent, self-inflicted Q1 failure. |
| **3** | [band_sync_service:179](../../lib/core/sync/band_sync_service.dart#L179) `getScheduledHr` | Falls back to `hrIntervalMin = 10`. If the band is actually on a different cadence, every HR sample gets **wrong timestamps** — silently corrupt data rather than missing data, which then poisons the BP-from-HR derivation and the sleep-window search. |
| **4** | [score_refresh_service:65,73,77,87](../../lib/core/sync/score_refresh_service.dart#L65) ×4 | Every score engine failure. A consistently-throwing engine is indistinguishable from "not enough data yet" — which is the *expected* state for a new user, so nobody investigates. |
| **5** | [coordinator:239](../../lib/core/sync/periodic_sync_coordinator.dart#L239) `cloudSync.processOutbox` | Cloud push failing. `cloud_sync_outbox` has `attempts` and `lastError` columns already; nothing reads them. Outbox grows unbounded, invisibly. |
| **6** | [coordinator:141](../../lib/core/sync/periodic_sync_coordinator.dart#L141) connect-edge `triggerNow` | See §4.1 — this is a latch, not just a lost error. |
| 7 | [band_sync_service:485](../../lib/core/sync/band_sync_service.dart#L485) BP buffer | Correctly non-fatal (documented decoupling), but the `-4001` timeout rate is a useful health signal and is currently unmeasurable. |
| 8 | [coordinator:224,245](../../lib/core/sync/periodic_sync_coordinator.dart#L224) `alertEvaluator.evaluateAll` ×2 | The whole alert engine failing, on both the connected and disconnected paths. |
| 9 | [ble_service:204](../../lib/core/ble/ble_service.dart#L204) `_seedConnectionStateFromNative` | Phantom "Disconnected" after engine restart — the bug the seed was written to fix, silently regressing. |

Beyond the catches: **`lib/core/ble/sync_adapters.dart` (638 lines of band
payload decoders) drops malformed and out-of-range values with `continue` at
~14 sites and emits nothing.** A firmware change that shifts a field by one byte
would present as "band returned no readings", not as a decode failure. The
adapters are the best-tested part of the codebase (replay tests) and the least
observable in production.

### 4.1 A latent permanent-stall bug found during the audit

`_bounded()`'s doc comment
([coordinator:163-169](../../lib/core/sync/periodic_sync_coordinator.dart#L163))
diagnoses this precisely:

> "without a ceiling that await hangs forever, `_onTick` never reaches its
> `finally`, `_inFlight` latches `true`, and EVERY later tick is silently
> dropped (root cause of overnight sync dying after one bad capture on a flaky
> link)."

The fix was applied to `_onTick` — `syncAll` runs under a 3-minute ceiling. It
was **not** applied to `triggerNow()`
([coordinator:320](../../lib/core/sync/periodic_sync_coordinator.dart#L320)),
which awaits `_runSyncWithRetention` unbounded. `triggerNow` is called on every
`disconnected → connected` edge. `MethodChannel.invokeMethod` has no timeout, and
the H59's history pulls complete via a native callback that never arrives if the
link drops mid-op.

So: a link drop during the post-connect sync latches `_inFlight = true` forever,
and every subsequent tick returns at `if (_inFlight) return;` — **with no log
line, no crumb, and no state change.** The app stays "alive but deaf" exactly as
described in the 2026-07-07 post-mortem, and the reconnector keeps happily
reconnecting a band nothing will ever read from.

This is a strong candidate for *the* bug behind the reported symptom. It is a
code fix, not an instrumentation fix, so it's out of scope for this pass — but
§7 Phase 0 includes the one-line telemetry that would have made it obvious, and
it should be filed separately.

---

## 5. Where telemetry should land

**Recommendation: a Drift `sync_events` table as the primary sink, breadcrumbs
retained as the human tail, and no external sink in this phase.**

### Why Drift and not the ring buffer

The ring buffer is a flat file readable only by tapping a button on the physical
handset. It cannot be queried ("show me every tick where the link was up and the
row count was zero"), cannot be aggregated ("HRV has failed 14 consecutive
runs"), cannot drive an alert rule, and cannot be exported without shipping the
whole file — including whatever prose someone interpolated into it.

Drift is already the source of truth, already migrates (`schemaVersion` 13 → 14),
already has a proven one-row-per-tick precedent in `battery_telemetry`, and its
rows are already queryable by the alert engine — which is what turns telemetry
from forensics into a *notification the user acts on*. `RetentionRule` proves the
pattern is one query away from working.

### Why not an external sink yet

Sentry/Crashlytics answers "did it crash". **The reported failure is silence, not
a crash** — the process is alive, the pager stays quiet, and the crash reporter
shows a clean dashboard. It would cost a dependency (CLAUDE.md is deliberately
strict here), a consent flow for health-adjacent data, and a redaction review —
to answer a question that isn't being asked.

**But build for it.** The Supabase path already exists and is push-only: enqueue
to `cloud_sync_outbox` with `targetTable: 'sync_events'` and
`SupabaseSyncRepository` drains it like any other rollup. When a real fleet
exists, the sink is a config flag and a table on the server, not a rewrite.
Sequencing matters here: **local diagnostics table → export-on-demand →
opt-in continuous upload**, and nothing crosses the network until §6's redaction
rules are enforced in code and tested.

### The three tiers, and what each owns

| Tier | Mechanism | Owns | Retention |
|---|---|---|---|
| **1. Watermarks** | existing `sync_state` (no new schema) | "when did metric X last succeed / fail, and with what error" — Q4, and it wakes `RetentionRule` | one row per (device, metric), overwritten |
| **2. Events** | new `sync_events` Drift table | one row per tick: outcome, phase, counts, error class — Q1–Q4 | 14 days, swept by the existing `DailyRetentionGate` |
| **3. Narrative** | existing `Breadcrumbs` | ordering and boot/engine-transition context; the thing a human reads | 800 lines, self-trimming |

Tier 3 stays, but its call sites get **stable event names instead of prose**, so
the same string is both greppable and human-readable.

---

## 6. What must never be logged

This app holds continuous HR, HRV, SpO2, BP, sleep staging, stress, steps, raw
PPG waveforms, date of birth, and a Supabase auth email. Under any reasonable
reading (HIPAA-adjacent, GDPR Art. 9 special category), **the measurement values
are the sensitive payload and the diagnostic metadata is not.** The whole design
below rests on that split.

### Never — hard rules

| Never log | Why | Log instead |
|---|---|---|
| Any measurement **value** — bpm, RMSSD, SpO2 %, mmHg, stress score | The health data itself | `count`, `min`/`max` bucket, `nonNullCount` |
| Individual sample **timestamps** | A timestamp series is a behavioral fingerprint (when you sleep, wake, exercise) | UTC day bucket, or `firstTs..lastTs` span in whole hours |
| `bedtime` / `waketime` / sleep-stage sequences | Directly reconstructs a sleep diary | `sessionFound: bool`, `epochCount: int` |
| Date of birth / derived age | Identifier + health attribute; used at [band_sync_service:461](../../lib/core/sync/band_sync_service.dart#L461) | `ageResolved: bool` (did the profile lookup work) |
| Email, Supabase JWT, refresh token | Credentials | nothing |
| **Full band MAC address** | Persistent hardware identifier; cross-app trackable | last 2 octets, or a salted hash |
| **Raw PPG frames** (`green`/`red`/`infrared`) | Raw biometric — arguably more sensitive than the derived values | `frameCount`, `sampleRateHz` |
| `SyncStepResult.rawMap` / `rawList` | Verbatim band payload — a night of BP tuples or a full HR array | never persist; keep debug-screen-only |
| Raw `e.toString()` from Supabase / auth / PostgREST | Routinely embeds the email, the row payload, or a token fragment | mapped error **class** + code |

### Two live violations to fix in Phase 0

1. **MAC in the breadcrumb file.**
   [band_reconnector.dart:56](../../lib/core/sync/band_reconnector.dart#L56)
   writes `'reconnect: band disconnected — trying $mac'` to a plaintext file
   that persists across reinstalls. Truncate to the last two octets.
2. **Auth exception text.**
   [auth_controller.dart:36,57](../../lib/core/auth/auth_controller.dart#L36)
   `debugPrint`s the raw `$e` from Supabase sign-up/sign-in, which carries the
   submitted email. Debug-only today, but it is the exact string someone will
   copy into a crumb the first time a login bug is reported.

### The structural rule that makes this enforceable

**Allowlist, never blocklist.** The `sync_events` table gets **typed columns
only** — no free-text `details` blob, because a blob is where a night of BP
readings ends up the first time someone is debugging at 2am. Free text is
confined to a single `errorClass` column populated from a **closed enum**:

```
ok · timeout · bandDisconnected · decodeFailed · emptyPayload ·
permissionDenied · dbWriteFailed · nativeChannelError · unknown
```

`unknown` is deliberately lossy. That is the price of a schema that can never
leak, and it is the right trade: the *class* of failure plus the step name plus
the count is enough to answer Q1–Q4. The verbatim exception stays in
`sync_state.lastSyncError` (local-only, never enqueued to the outbox) and in the
breadcrumb tail.

**Redaction belongs at the sink, not the call site.** One `SyncEvent` constructor
that only accepts typed fields means a caller *cannot* pass a bpm value, rather
than being trusted not to.

---

## 7. Minimum instrumentation

Deliberately small. Each item names its question and its call site.

### Phase 0 — wake the dead detector (no new schema, no new table)

The highest value-per-line work in this document.

| # | Change | Site | Answers |
|---|---|---|---|
| 0.1 | Call `syncStateRepo.recordSuccess` / `recordFailure` once per step inside `BandSyncService._guarded` — it already has `metric`, the error, and the outcome in one place | [band_sync_service.dart:64](../../lib/core/sync/band_sync_service.dart#L64) | **Q4**, and makes `RetentionRule` fire for the first time |
| 0.2 | Truncate the MAC in the reconnect crumb | [band_reconnector.dart:56](../../lib/core/sync/band_reconnector.dart#L56) | §6 violation 1 |
| 0.3 | Crumb the `setScheduledMonitoring` failure — replace `catch (_) {}` with a named event | [coordinator:158](../../lib/core/sync/periodic_sync_coordinator.dart#L158) | **Q3** |
| 0.4 | Crumb the `has_bonded_band` prefs write failure | [coordinator:201](../../lib/core/sync/periodic_sync_coordinator.dart#L201) | **Q1** (watchdog starvation) |
| 0.5 | Crumb `_inFlight` drops — every `if (_inFlight) return;` becomes a counted, logged skip | [coordinator:188,304](../../lib/core/sync/periodic_sync_coordinator.dart#L188) | The §4.1 latch, which is otherwise invisible |
| 0.6 | Crumb each of the four `ScoreRefreshService` engine failures with the engine name | [score_refresh_service.dart:65-87](../../lib/core/sync/score_refresh_service.dart#L65) | **Q5** |

`_guarded` is the ideal seam for 0.1: every step already funnels through it, so
one change instruments all 13 sync steps with no per-metric edits. This is the
same "one wrapper, total coverage" property the skill wants from middleware.

**After Phase 0 alone**, a user whose band went quiet gets a push notification
after 3 days, and the developer gets a per-metric watermark table showing which
step broke and when.

### Phase 1 — `sync_events` (schema 13 → 14)

One row per tick. Typed columns only (§6). ~48 rows/day at 30-min cadence —
the same order as `battery_telemetry`, which is already proven affordable.

| Column | Type | Notes |
|---|---|---|
| `id` | text | UUID v4, house convention |
| `startedAtUtc` / `durationMs` | int | Q1 heartbeat + duration percentiles |
| `engine` | text | `ui` \| `headless` — which engine ran it. Currently unanswerable and central to every Android background failure |
| `trigger` | text | `tick` \| `connectEdge` \| `manual` |
| `tickIntervalMin` | int | cadence attribution, mirrors `battery_telemetry` |
| `linkState` | text | `connected` \| `disconnected` \| `connecting` at tick start — **Q2** |
| `outcome` | text | `ok` \| `partial` \| `skipped` \| `stalled` |
| `skipReason` | text? | closed enum, reuses the existing `lastSkipReason` vocabulary |
| `stepsOk` / `stepsFailed` | int | **Q4** rollup |
| `totalSamples` | int | **Q3** — `linkState=connected AND totalSamples=0` sustained is the dormant-band signature that is currently invisible |
| `monitoringEnableOk` | bool? | **Q3** direct — did the connect-edge `setScheduledMonitoring` land |
| `aggregated` / `scoresRefreshed` | bool | **Q5** |
| `outboxDepth` | int | cloud backlog, from a table that already tracks `attempts` |
| `errorClass` | text? | the closed enum from §6 |

Plus: **failed steps get one child row each** (or a compact per-step summary
column) so "which metric, how long" is a `GROUP BY` rather than an inference.

**Retention:** 14 days, swept by the existing `DailyRetentionGate` — no new
sweep machinery. Never enqueued to `cloud_sync_outbox` in this phase.

### Phase 2 — surfacing (no new collection)

Collection without a read path is a diary nobody opens.

1. **Sync Health panel** in the debug screen: last tick, last success per metric
   (straight off `sync_state`), consecutive failures, dormant-band warning
   (`connected` + zero samples for > 6 consecutive ticks).
2. **`getStaleMetrics` alert rule** — the repository method already exists and
   has no callers. Per-metric staleness is a sharper user-facing signal than the
   all-or-nothing `RetentionRule`.
3. **"Export diagnostics"** — a share-sheet dump of `sync_events` + `sync_state`
   + the crumb tail, so a field user can send a support bundle. This is what
   replaces the external sink for now, and it is the natural place to prove the
   redaction rules hold before anything is uploaded automatically.

### Explicitly not in this plan

- **No OpenTelemetry / distributed tracing.** One process, one device, no
  cross-service hops. The `sync_events` row *is* the trace.
- **No new logging package** (`logger`, `logging`). `Breadcrumbs` + typed Drift
  rows cover both signals; a third mechanism would fragment further.
- **No metrics backend / percentile histograms.** With one user's device you
  need the individual rows, not aggregates. `durationMs` per row supports
  percentiles later, for free.
- **No native-side changes.** iOS's 2 log calls vs Android's 149 is a real
  asymmetry, but the Dart layer sees every outcome that matters through the
  frozen channel, and CLAUDE.md is right that native changes cost three
  synchronized edits. Revisit only if a failure proves to be invisible from Dart.

---

## 8. Verifying the telemetry itself

Instrumentation is code and can be wrong. Per the skill's verification gate —
and per the house rule that band-data bugs get replay tests:

| Check | How | Existing seam |
|---|---|---|
| `sync_state` actually populates | Repository test over `NativeDatabase.memory()`; run a fake sweep, assert one row per metric with correct watermarks | house pattern, `drift/native.dart` |
| `RetentionRule` fires once `sync_state` is populated | It already has a test seam; assert non-null candidate at `staleAfter + 1h`. **This test would fail today**, which is the proof the detector is dead | `ProviderContainer(overrides:)` |
| Redaction holds | Assert the `SyncEvent` field set is closed, and that a full `SyncStepResult` (with `rawMap` of band payload) round-trips into a row containing **no** value from that payload — a real leak test, not an inspection | plain unit test |
| Dormant-band signature detected | Feed a run of ticks with `linkState=connected, totalSamples=0`; assert the panel/rule flags it | pure logic |
| Timeout path emits | `TestDefaultBinaryMessengerBinding` + `setMockMethodCallHandler` returning a never-completing future; assert `outcome=stalled`, `errorClass=timeout`, and that `_inFlight` cleared | house pattern for channels |
| End-to-end, on-device | Airplane-mode the phone overnight with the band charging outside range. Next morning, answer Q1–Q4 **from the diagnostics export alone, without reading source or attaching a cable.** | this is the actual acceptance test |

That last row is the bar. If the export can't answer all four questions after an
induced failure, the plan didn't land.

---

## 9. Sequencing

| Phase | Scope | Unblocks |
|-------|-------|----------|
| **0** | 6 changes, no schema | `RetentionRule` fires; Q3/Q4/Q5 stop being invisible. Ship first, alone. |
| **0.5** | *Separate bug*: bound `triggerNow` like `_onTick` (§4.1) | Likely fixes the reported symptom outright |
| **1** | `sync_events`, schema 14 | Q1/Q2 become queryable; per-tick history |
| **2** | Debug panel, `getStaleMetrics` rule, export | Turns collection into diagnosis |
| **later** | Outbox → Supabase `sync_events`, behind consent | Fleet-wide visibility |

Phase 0 is deliberately shippable on its own and touches no schema, so it can go
out ahead of the current working-tree changes without a migration.

---

## 10. Open questions

1. **Retention on `sync_events` — 14 days, or longer?** 14 aligns with the
   existing rollup window and the `DailyRetentionGate`. A month of tick history
   is ~1,500 rows and would cover "it worked fine until the OS update."
2. **`RetentionRule.staleAfter` is 3 days.** Once `sync_state` is populated for
   the first time, that threshold becomes live for every existing user
   simultaneously. Should the first populated write suppress the rule for one
   cycle so nobody gets nagged for a gap that predates the fix?
3. **Is `flutter_secure_storage` (already a dependency) worth using for the
   crumb file?** Probably not — the redaction rules mean it holds nothing
   sensitive by construction, which is the stronger guarantee. Flagging it only
   because §6 violation 1 shows the file has drifted sensitive once already.

---

## Adversarial verification 2026-08-10

Second pass by a different model under `metric-validation` rule 6: the brief was
to **refute** §4.1, defaulting to "not a defect" when uncertain. The asymmetry
(`_onTick` bounded, `triggerNow` not) was already established; the open question
was **reachability** — can `MethodChannel.invokeMethod` on a history pull
actually hang forever, or does a native bridge time out and reply? Read: the
Dart `BleService`, the Android Kotlin bridge, and the iOS Swift bridge. No code
changed; no build or test run.

### §4.1 — the `triggerNow` latch — **CONFIRMED** (reachable on Android; iOS STILL-UNKNOWN)

**Dart layer bounds nothing.** `ble_service.dart` contains zero `.timeout(`
calls across all 49 channel methods. `BandSyncService._guarded`
([band_sync_service.dart:64-72](../../lib/core/sync/band_sync_service.dart#L64))
converts a *throw* into a `SyncStepResult` but has no ceiling, so a step that
never returns hangs `syncAll` itself. `triggerNow` awaits
`_runSyncWithRetention` bare at
[coordinator:320](../../lib/core/sync/periodic_sync_coordinator.dart#L320); the
`finally` that clears `_inFlight` is at
[:327-329](../../lib/core/sync/periodic_sync_coordinator.dart#L327) and is
reached only if that await completes. Confirmed as written.

**Android — three classes of history handler, and one of them cannot reply.**

| Class | Methods | Reply guaranteed? |
|---|---|---|
| **A — locally guarded** | `syncHRV` → `getHrvHistory` | ✅ 10 s `mainHandler.postDelayed` + `AtomicBoolean`, replies empty on timeout ([BleManager.kt:1818-1826](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1818)) |
| **B — SDK callback with an error path** | `syncHeartRate` ([:1461](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1461)), `syncStressDay` ([:1376](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1376)), `syncSleep` ([:2342](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L2342)), `syncSpO2`, `syncStepsDay` | ⚠️ Only if the vendor `BleOperateManager.HealthDataCallback` fires. No local timer. There *is* evidence the SDK times out on this path — `getBpDay` "hangs ~15 s then `-4001`" (`docs/TROUBLESHOOTING.md:47-49`) is an `onError` arriving — but nothing in this repo proves it fires on every disconnect. |
| **C — success-only lambda, no timer, no error channel at all** | **`syncBloodPressure` → `getBpHistory`** ([:2295-2324](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L2295)), **`syncSteps` → `getDailyTotals`** ([:2402-2430](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L2402)), **`syncStepsDetail` → `getStepBucketHistory`** ([:2443-2469](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L2443)) | ❌ **No.** `CommandHandle.executeReqCmd(req, ICommandResponse{ … })` registers a success-only lambda. There is no `onError` override, no `AtomicBoolean`, no `postDelayed`. The outer `try/catch` only covers the synchronous enqueue. If the notify never comes back up the queue, `result` is never fulfilled and the Dart future never completes. |

All three class-C methods are in `syncAll`'s step list
([band_sync_service.dart:82-157](../../lib/core/sync/band_sync_service.dart#L82)),
so the connect-edge sync routes through them on every run.

The repo already states this in its own words. The guard added to `syncHRV` —
also a `CommandHandle` path — is commented: *"A command the band never answers
must not hang the Dart await forever (mirrors the BP measure safety net)"*
([BleManager.kt:1819-1820](../../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1819)).
That is an on-device-derived statement that `CommandHandle.executeReqCmd` does
not guarantee a reply, written by whoever hit it. `docs/ANDROID_SDK_REFERENCE.md:45-62`
describes the SDK as asynchronous and callback-driven and documents no timeout
contract for `CommandHandle`. **Reachability: confirmed on Android.**

**iOS — no local guard anywhere on the history path; SDK behaviour undetermined.**
Every method in
[BleManager+History.swift](../../ios/Runner/BLE/BleManager+History.swift) calls
`result(...)` only from inside a `QCSDKCmdCreator` completion block. There is no
`asyncAfter` fallback on `getSleepHistory` (:23), `getHrHistory` (:36),
`getHrvHistory` (:58), `getStressDay` (:71), `getDailyTotals` (:216) or
`getStepBucketHistory` (:228). The two `timedOut` branches that do exist
(`getSpO2Interval` :123, `getSpO2Capability` :154) are SDK-reported flags, not a
local ceiling. `getSpO2History` (:99-112) is worse in shape — it chains seven
sequential per-day SDK calls and calls `result` only when the recursion reaches
day 7, so one non-firing completion strands the whole chain. The file header
claims *"On failure every method returns the empty-shape payload — it never
throws"* (:9-11), but that holds only if the SDK invokes `fail:` / `finished:`;
nothing in this repo establishes that it does. One narrowing: iOS
`getBpHistory` is a stub that replies immediately (:208-210), so the single
worst Android offender has no iOS counterpart. **Verdict for iOS:
STILL-UNKNOWN** — plausible, unproven, and not determinable without either the
QCBandSDK sources or an on-device link-drop test.

**Severity: as stated, and the "forever" wording is defensible.** `_inFlight` is
an instance field ([:108](../../lib/core/sync/periodic_sync_coordinator.dart#L108))
on a coordinator built by a plain, non-`autoDispose` `Provider`
([:361-365](../../lib/core/sync/periodic_sync_coordinator.dart#L361)), so it
lives as long as the container — the engine's process. The refutation I expected
to work was "the watchdog restarts the engine and clears it": it does not.
`SyncWatchdogWorker.doWork` returns early when `MainActivity.uiEngineAlive` or
`HeadlessSyncEngine.isRunning`
([SyncWatchdogWorker.kt:36-42](../../android/app/src/main/kotlin/com/hlth/hlth_app/SyncWatchdogWorker.kt#L36)) —
a latched engine is a *live* engine, so the watchdog explicitly declines to
intervene. Meanwhile `BandReconnector.start()`'s own `Timer.periodic(5 min)`
([band_reconnector.dart:33-37](../../lib/core/sync/band_reconnector.dart#L33))
is independent of the coordinator and keeps reconnecting, and each reconnect
edge calls `triggerNow` again ([:140](../../lib/core/sync/periodic_sync_coordinator.dart#L140))
only to bounce off `if (_inFlight)` at
[:304](../../lib/core/sync/periodic_sync_coordinator.dart#L304). The plan's
"alive but deaf, and the reconnector keeps happily reconnecting a band nothing
will ever read from" is accurate. One precision edit worth making: the latch
clears on process death, so the field signature is *silent until the app or
engine is restarted*, not literally permanent — which matters, because it predicts
"the user force-quits the app and sync works again for a while", a testable
claim against the reported symptom.

**Sequencing implication:** phase 0.5 is not merely "likely fixes the reported
symptom" — the three class-C Kotlin handlers mean the Dart-side ceiling on
`triggerNow` is the *only* thing that can bound them. A Kotlin-side guard
mirroring `syncHRV`'s `AtomicBoolean` + `postDelayed` on those three would be
the durable fix, but that is three synchronized edits under the frozen-channel
rule (`CLAUDE.md`), so the Dart ceiling is correctly the first move.

### Rule 6 — what the next pass should attack

This pass is one model refuting another and does not settle it. A third model
should try to refute, specifically:

1. **That `CommandHandle.executeReqCmd` never times out.** The strongest counter
   would be decompiled evidence from `classes.jar` of an internal timeout in the
   command queue that surfaces as a `null` response to the same
   `ICommandResponse` lambda — which would make class C reply (with `rsp == null`,
   which `syncBloodPressure:2300` and `syncSteps:2407` already handle) and
   collapse this finding to iOS-only.
2. **That the connect-edge path can actually reach a class-C step before the
   link drops** — `syncAll` runs HR/SpO2/sleep/steps *before* `getBpHistory`, so
   a refuter should check whether an earlier class-B step would fail first and
   short-circuit the sweep.
3. **The iOS half**, which this pass could not decide either way.
