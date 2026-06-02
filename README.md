# hlth_app

HLTH Smartband Companion App — a Flutter application that pairs with a QRing-family BLE smart ring (H59), syncs continuous health metrics on the band's schedule, and computes derived metrics (HRV, resting HR, sleep efficiency, activity zones, respiratory rate) on-device.

This is a **wellness application, not a medical device.** It does not diagnose, treat, or prevent any condition.

---

## Status

**Phase 0 — Native BLE bridge.** ✅ Complete. Scan, connect, scheduled monitoring config, and the full sync command set are wired through to Dart via MethodChannel (`hlth/ble`) and EventChannel (`hlth/realtime_stream`).

**Phase 1 — Algorithms and infrastructure.** In progress. Tasks tracked as HLT-1 through HLT-12:

| Task | What | Status |
|---|---|---|
| HLT-1 | Sleep stage epoch parsing (fix `duration: 0` bug) | ✅ |
| HLT-2 | HRV monitoring + correct RMSSD ms scaling | ✅ |
| HLT-3 | Activity classification (sedentary / light / moderate / vigorous) | ✅ |
| HLT-4 | Step-bucket sync (15-min bins, 96/day) | ✅ |
| HLT-5 | Fall detection pipeline (blocked on HLT-10) | ⏳ |
| HLT-6 | HRV outlier removal + ectopic beat detection | ⏳ |
| HLT-7 | HRV frequency-domain analysis (LF/HF) | ⏳ |
| HLT-8 | Respiratory rate auto-integration into daily_metrics | ✅ |
| HLT-9 | Realtime HR 5-sec rolling-mean smoothing | ✅ |
| HLT-10 | Android foreground service for background BLE | ✅ |
| HLT-11 | Periodic sync scheduler (WorkManager) | ⏳ |
| HLT-12 | Retention sweep (90-day soft-delete) | ⏳ |

---

## Hardware

Built and verified against the **H59 smart ring** (firmware `H59_2.00.14_260107`). Key device facts that shape the architecture:

- **No on-demand measurement.** `mSupportManualHeartRate=false`. The band measures only on its own schedule (e.g. every 10 min for HR), so the app uses a *sync history* pattern, never a "tap to measure" UX.
- **No display.** Ring form factor, `deviceNoScreen=true`. All UX lives in the app.
- **Scheduled monitoring must be enabled before first sync.** Sending `HeartRateSettingReq(true, interval)` + `BloodOxygenSettingReq` + `HrvSettingReq` is mandatory — without it, sync returns empty arrays.
- **Bootstrap handshake required.** After every connection: `SimpleKeyReq(CMD_BIND_SUCCESS)` then `SetTimeReq(0)` (also returns capability bitmap). Without bind, the band silently rejects subsequent monitoring writes.
- **HRV stored under wear day, not sync day.** Wearing the band Sunday night and syncing Monday morning returns the samples at `dayOffset=1`, not 0.
- **Write-response unreliable.** `isEnable` in monitoring-write responses can return `false` even when the band is actively measuring; the *read-back* of the same setting is ground truth. Allow ~2 sec between write and read-back.

These quirks are captured in code comments next to the relevant calls in [BleManager.kt](android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt).

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter (lib/)                                              │
│                                                              │
│   features/        — Screens (home, sleep, activity, debug)  │
│       │                                                      │
│   core/services/   — DailyAggregator, ActivityClassifier,    │
│       │              BaselineService, FeatureGate            │
│       │                                                      │
│   core/repositories/ — One per metric (HR, HRV, SpO2, Sleep, │
│       │              StepBucket, BP, DailyMetrics, Baseline) │
│       │                                                      │
│   core/database/   — Drift ORM (typed SQLite + freezed)      │
│       │                                                      │
│   core/ble/        — BleService (Dart) + sync_adapters       │
│       │              (legacy SDK payload → canonical models) │
│       │                                                      │
│   core/processing/ — SignalProcessor, HrvCalculator,         │
│                      RespiratoryRateCalculator               │
└─────────────────────────┬────────────────────────────────────┘
                          │ MethodChannel  hlth/ble
                          │ EventChannel   hlth/realtime_stream
┌─────────────────────────┴────────────────────────────────────┐
│  Native BLE bridge                                           │
│                                                              │
│   Android — Kotlin: BleManager.kt, BleForegroundService.kt,  │
│             HlthBluetoothReceiver.kt                         │
│             → QRing SDK (Oudmon BLE library, .aar)           │
│                                                              │
│   iOS     — Swift: BleManager.swift                          │
│             → QCBandSDK                                      │
└──────────────────────────────────────────────────────────────┘
```

### Data flow

1. **Scan + connect** via the native bridge. Connection state propagates back to Dart through `MethodChannel.onConnected` / `onDisconnect`.
2. **Bootstrap** the band on connect: bind handshake → set time → log capability bitmap.
3. **Enable scheduled monitoring** (HR, SpO2, HRV interval writes) on first pair.
4. **Sync** is user-triggered today (via the debug screen) and will become periodic via WorkManager in HLT-11. Each sync writes raw samples to the metric-specific Drift table.
5. **Aggregate** rolls per-day samples into a single `daily_metrics` row (resting HR, HRV RMSSD/SDNN, SpO2 overnight, sleep totals, activity zones, …). The aggregator is idempotent and preserves columns it doesn't recompute.
6. **Baselines** maintain a 14-day rolling window per metric, used by downstream illness-warning + recovery-score features (Phase 4+).

### Provenance contract

Every raw-sample row carries a fixed 6-column provenance envelope:
`user_id`, `device_id`, `captured_at_utc`, `captured_tz_offset_min`, `source`, plus a soft-delete tombstone column. This makes multi-device, multi-user, retention, and audit work straightforward downstream.

---

## Health metrics

### Working today

| Metric | Source | Storage | Notes |
|---|---|---|---|
| Heart rate (sync) | `ReadHeartRateReq` — 288 slots × 5-min | `hr_samples` | One BPM byte per slot; 0 = no measurement |
| Heart rate (realtime) | `DeviceNotifyListener` dataType=1 → trigger-then-sync | stream | 5-sec rolling-mean smoothing in Dart |
| SpO2 | `LargeDataHandler.syncBloodOxygenWithCallback` | `spo2_samples` | Hourly min/max |
| Sleep | `LargeDataHandler.syncSleepListIndianDemand` | `sleep_sessions` + `sleep_epochs` | Deep/light/REM/awake; SDK reports seconds, we convert to minutes |
| Steps (totals) | `CMD_GET_STEP_TODAY` | `daily_metrics.steps` | Works without scheduled-monitoring enable |
| Steps (15-min) | `ReadDetailSportDataReq` — 96 bins/day | `step_buckets` | Each bin: walk/run/calorie/distance |
| HRV (RMSSD) | `HRVReq(dayOffset)` | `hrv_samples` | Raw byte = RMSSD ms (NOT /10 despite SDK doc) |
| Blood pressure | `CMD_BP_TIMING_MONITOR_DATA` | `bp_samples` | Hourly auto-measurement |
| Respiratory rate | `RespiratoryRateCalculator` on PPG capture | `daily_metrics.resting_resp_rate_bpm` | 0.1-0.5 Hz bandpass + peak detection |
| Activity zones | `ActivityClassifier` over step_buckets | `daily_metrics.active_minutes` | Tudor-Locke cadence thresholds |

### Coming in Phase 1+

Fall detection (HLT-5), HRV ectopic detection (HLT-6), HRV LF/HF frequency analysis (HLT-7), periodic background sync (HLT-11), 90-day retention sweep (HLT-12).

### Phase 4 (composite scores)

Recovery score, illness warning, body age, wellness score, menstrual cycle tracking. All gate on a 14-day baseline being established (see `core/services/feature_gate.dart`).

---

## Project structure

```
hlth_app/
├── android/
│   └── app/
│       ├── libs/qring_sdk_1.0.0.17.aar       — QRing Android SDK
│       └── src/main/kotlin/com/hlth/hlth_app/
│           ├── HlthApplication.kt             — SDK init + receiver register
│           ├── MainActivity.kt                — Flutter entry + perms
│           └── ble/
│               ├── BleManager.kt              — MethodChannel handler
│               ├── BleForegroundService.kt    — Background BLE keepalive
│               └── HlthBluetoothReceiver.kt   — SDK connection events
├── ios/
│   └── Runner/BLE/BleManager.swift            — QCBandSDK bridge
├── lib/
│   ├── core/
│   │   ├── ble/                               — Dart BLE service + adapters
│   │   ├── bootstrap/                         — Session + DB init
│   │   ├── database/                          — Drift schema + codegen
│   │   ├── models/                            — Freezed domain models
│   │   ├── processing/                        — Signal processing (HRV, RR)
│   │   ├── repositories/                      — Per-metric DB access
│   │   ├── routing/                           — go_router config
│   │   └── services/                          — Aggregator, classifier, baselines
│   ├── features/                              — Per-screen UI
│   ├── ui/                                    — Shared widgets + theme
│   ├── app.dart
│   └── main.dart
├── db/schema.sql                              — Reference schema (Drift is source of truth)
└── pubspec.yaml
```

---

## Setup

### Prerequisites

- Flutter 3.x with Dart SDK ^3.8.1
- Android Studio + Android SDK (API 26+ / Android 8.0+)
- Xcode (for iOS builds)
- A physical Android or iOS device — BLE doesn't work in emulators

### First-time setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

The `build_runner` step generates Drift's `.g.dart` files and freezed's `.freezed.dart` files. Re-run after any schema or model change.

### Run on Android

```bash
flutter run
```

The build script bundles the QRing SDK (`android/app/libs/qring_sdk_1.0.0.17.aar`) automatically.

### Run on iOS

```bash
cd ios && pod install && cd ..
flutter run
```

### Required permissions at runtime

- `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` (Android 12+)
- `ACCESS_FINE_LOCATION` (Android ≤11 only, with `neverForLocation` flag)
- `POST_NOTIFICATIONS` (Android 13+, for the foreground service notification)
- `FOREGROUND_SERVICE_CONNECTED_DEVICE`

`MainActivity.onCreate` requests `POST_NOTIFICATIONS` on launch. BLE permissions are requested via `permission_handler` on first scan.

---

## Development

### Stack

- **State management**: Riverpod 2 (`ConsumerWidget` / `ConsumerStatefulWidget`)
- **Navigation**: go_router
- **Database**: Drift (typed SQLite ORM) with composite unique constraints, soft delete, and UTC unix-second timestamps
- **Domain models**: freezed (immutable, with codegen)
- **Charts**: fl_chart

### Code generation

Anything under `core/database/` and `core/models/` uses codegen. After edits:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Debug screen

`features/debug/ble_debug_screen.dart` is the primary developer entry point. From there you can:
- Scan + connect to the band
- Enable scheduled monitoring (with a settable HR interval — useful for verifying realtime HR push within ~1 min instead of waiting 10)
- Trigger every sync command individually (HR, SpO2, sleep, steps, step-buckets, HRV with day-offset picker, BP)
- Capture raw PPG (~10 packets/sec for 30 sec) and run the Analyze pipeline (HR, HRV, respiratory rate)
- Run `Aggregate Day` to roll the day's samples into `daily_metrics` and recompute baselines
- Inspect raw DB counts

The verbose log surface shows raw SDK payloads alongside the parsed values, which makes diagnosing the band's quirks a lot faster.

### Hot reload caveats

- **Dart-only changes** → `r` (hot reload) works.
- **Kotlin / Swift / AndroidManifest changes** → full `flutter run` is required. Hot reload doesn't touch the native APK.
- **Debug builds + force-close**: relaunching the installed APK from the launcher loads the *last full-build's* Dart snapshot, not the live code in your `flutter run` session. Re-run `flutter run` to push current Dart, or `flutter run --release` to bake it in.

---

## Regulatory positioning

This is a **wellness application**, not a medical device. The codebase enforces this in a few ways:

- No disease names. Use "pattern" or "trend" instead of e.g. "AFib" or "sleep apnea".
- No "abnormal" framing. Use "different from your baseline".
- All score screens carry a disclaimer footer: *"Not intended to diagnose, treat, or prevent any condition. Consult your healthcare provider for medical advice."*
- Raw PPG is processed on-device and discarded. Upload of raw signals is opt-in only.
- No PHI in logs or telemetry.

When adding new features, run the same checks: no disease vocabulary in UI strings, no "abnormal" in user-facing text, disclaimer present on any screen that surfaces a derived score.

---

## License

TBD.
