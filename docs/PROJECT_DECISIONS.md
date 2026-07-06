# Project Decisions

Why the project is built the way it is — architecture choices, trade-offs, and
hardware-forced constraints. Sourced from the build guides, session history, and
Ryan's design calls.

## Architecture

**Local-first (SQLite is the app's truth; cloud is a mirror).**
The ring is the data source; the app syncs into Drift/SQLite and the UI reads
*only* SQLite via repositories→providers. → Works fully offline, scoring is
deterministic/testable, no network on the render path. *Trade-off:* cloud sync
is push-only, so a fresh install has no history (known data-loss gap).

**Repository boundary (only repos touch Drift).**
Services take repo *interfaces*, so the whole app is testable with in-memory
fakes (the actual test strategy). *Trade-off:* more boilerplate per entity.

**Hand-written Riverpod (no `riverpod_generator`).**
`Provider`/`StreamProvider`/`StateNotifierProvider` by hand. UI providers stream
off Drift `watch*`, so a repo upsert anywhere auto-refreshes every watching
card with no manual invalidation. *Trade-off:* slightly more verbose than codegen.

**Frozen `BleService` contract.**
The Dart platform-channel API is fixed; the iOS bridge was built to *match*
Android so nothing above the channel changes per platform. → One Dart codebase,
two native bridges. *Trade-off:* the iOS bridge must chase Android's shape even
where the QCBandSDK would prefer a different idiom.

**Pure scoring engines, vendored verbatim + thin adapters.**
`core/scoring/*` (Recovery, Cardio Load, VO2) are pure Dart, no I/O, integrated
**byte-for-byte** as delivered (only an `ignore_for_file` header added); a
`*_service.dart` adapter reduces DB rows → engine input → persisted `Score`.
→ Vendor algorithms drop in unchanged and unit-test without a device/DB; a
recompute never diverges from the validated logic. *Trade-off:* engine input
must be reconstructed from stored rollups (e.g. per-epoch sleep rebuilt from
stage %s × totals).

## Scoring design (Ryan)

- **Sleep-window metrics, not daytime** (2026-06-23): RHR/HRV/SpO2 are taken
  over `[bedtime, wake)` because *daytime HRV is motion-contaminated*. Morning
  window is fallback only.
- **Never fabricate missing signals** — absent HRV/resp are marked unavailable
  and their weight is **redistributed**, never invented. Keeps scores honest at
  the cost of lower confidence on thin nights.
- **Cold-start locks + baselines** — scores stay provisional until enough valid
  nights bank (Recovery <4, Cardio Load ~5); baselines are the user's own
  rolling history (robust-z), so scores are personalized, not population norms.
- **VO2 Max = Algorithm A only** (Åstrand-Ryhming): Algorithm B (Cole
  HR-recovery) was dropped because the H59 rarely provides the post-workout 60s
  recovery HR it needs. METs derived from the band workout summary (ACSM speed →
  caloric fallback) since there's no usable accelerometer feed.

## Hardware-forced constraints (H59)

| Constraint | Decision |
|---|---|
| Dormant until monitoring enabled | Auto-enable `setScheduledMonitoring` on every connect edge (after first sync) |
| Write-ack unreliable | Trust the 2s read-back / overnight sample count, never the ack |
| No scheduled-BP history | Fire our own nightly on-demand BP measurement inside the night window |
| HRV under wear-day index | Sync HRV for dayOffset 0 and 1 |
| Accel only during raw PPG (battery-heavy) | VO2 detection = **sport-mode + auto-prompt**, not continuous accel |
| Sleep retrospective, no realtime event | Post-sleep triggers run on the sync tick; can't recompute from past raw PPG |
| minSdk 26 required by QRing | Android 8.0 floor + core-library desugaring |
| Sensor can't do PPG-morphology BP at 25 Hz | BP is HR+age estimate; true PPG BP deferred to the new sensor |

## Platform & infra

- **Supabase** backend (Frankfurt region), lightweight — V1 needs a backend
  (reversed from an earlier local-only plan). Auth is opt-in.
- **Env via `--dart-define-from-file`** (not `.env` runtime file) → compile-time
  constants, no secrets bundled as assets.
- **Local notifications** (not server push) for alerts, rate-limited via
  `notification_log`.
- **AI Insights** (planned): cloud via OpenRouter, no on-device model, no
  user-data training.

## Known open items

1. Android production signing not configured (debug-key fallback).
2. Cloud restore / down-sync missing (push-only).
3. Background-execution reliability for nightly captures (Doze).
4. Health Score / Longevity composite engine not yet delivered by Ryan.
5. PPG-morphology features (stiffness/augmentation, true BP) blocked on the new
   lower-noise sensor.

See [PROJECT_MASTER_GUIDE.md](PROJECT_MASTER_GUIDE.md) for the overview and the
other docs for specifics.
