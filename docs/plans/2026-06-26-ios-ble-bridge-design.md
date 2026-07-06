# iOS BLE Bridge — Design

## Overview

Build out the iOS native BLE bridge (`ios/Runner/BLE/`) wrapping QCBandSDK to full
parity with the Android bridge (`BleManager.kt` wrapping the QRing SDK), so the
existing Dart code (`lib/core/ble/ble_service.dart`) runs **unchanged** on iOS.
Success = the full sync pipeline works on iOS — sleep / HR / HRV / stress history
lands in the local DB — so the Cardio Load score (and everything else) computes on
iPhone exactly as on Android.

## Governing principle

The Dart side is the frozen contract. The iOS bridge conforms to it; Dart does not
change. Concretely: **the iOS bridge must emit the exact same Dart-facing payloads
Android emits**, even though QCBandSDK returns different native shapes. Example:
Android `getSleepHistory` → `{totalSleepDuration, deepDuration, shallowDuration,
awakeDuration, rapidDuration, stages:[{sleepStart, sleepEnd, type}]}`. iOS takes
QCBandSDK's `[QCSleepModel]` and **normalizes it into that identical map**. Same
channel names, method names, payload keys, units, and callback method names.

Authoritative references:
- Android behavioral spec (every method's args, SDK calls, response payload shape,
  callbacks) — captured in the planning research; the source of truth for payloads.
- QCBandSDK iOS API reference (headers + demo) — method signatures + model props.
- `Transfered Files/Build guide/hlth-ble-platform-channel.md` — the *aspirational*
  contract. Note it diverges from reality: real channels are `hlth/ble` +
  `hlth/realtime_stream` + `hlth/realtime_stream_accel`, and the real pattern is one
  MethodChannel with native→Dart `invokeMethod` callbacks, NOT four EventChannels.

## Channels (corrected from the stale Phase-0 scaffold)

| Channel | Type | Purpose |
|---|---|---|
| `hlth/ble` | MethodChannel | ~50 request/response methods + native→Dart callbacks (`onConnected`, `onDeviceNotify`, `onPeriodicSyncTick`, …) |
| `hlth/realtime_stream` | EventChannel | raw PPG samples during raw capture |
| `hlth/realtime_stream_accel` | EventChannel | reserved (Android doesn't populate it either) |

The current `BleManager.swift` registers `com.hlth.hlth_app/…` — wrong; must be renamed.

## Architecture (file layout)

Split `BleManager` into feature extensions rather than one monolith (Android is a
single 2,556-line file; Swift will be more maintainable split). Same external surface.

```
ios/Runner/BLE/
├── BleManager.swift              // singleton, channel registration, method dispatch, connection lifecycle
├── BleManager+Connection.swift   // scan/connect/disconnect/battery + CBCentralManagerDelegate
├── BleManager+Config.swift       // setScheduledMonitoring, get/set HR/BP/stress, setPersonalInfo, setTime, sync-interval
├── BleManager+History.swift      // sleep/HR/HRV/stress/SpO2/BP/steps sync
├── BleManager+Measure.swift      // manual streams (HR/SpO2/HRV), OneKey, BP measure
├── BleManager+RawPPG.swift       // HrRaw/Spo2Raw capture → realtime_stream
├── BleManager+Sport.swift        // sport mode + syncSportSessions
├── BleManager+Events.swift       // OdmBandNotifyCenter observers → onDeviceNotify/onRealtimeHeartRate/etc.
├── BleManager+Background.swift   // CB state restoration + BGTaskScheduler + periodic-sync timer
└── PayloadCodec.swift            // QCModel → Android-shape map helpers; tz + byte normalization
```

## Method surface (must reach parity — ~50)

Connection/lifecycle: `startScan`, `stopScan`, `connect`, `disconnect`, `getBattery`.
Config: `setScheduledMonitoring`, `getScheduledHr`, `setBpScheduled`, `getBpScheduled`,
`setStressScheduled`, `getStressScheduled`, `setPersonalInfo`, `setSyncIntervalMinutes`,
`getSyncIntervalMinutes`.
History: `getHrHistory`, `getHrvHistory`, `getStressDay`, `getSleepHistory`,
`getSpO2Day`, `getSpO2History`, `getSpO2Interval`, `getSpO2Capability`,
`enableSpO2Interval`, `getBpDay`, `getBpHistory`, `getDailyTotals`,
`getStepBucketHistory`, `getStepDay`.
Measurement: `startBpMeasurement`/`stop`, `startHeartStream`/`stop`,
`startSpo2Stream`/`stop`, `startHrvStream`/`stop`, `startOneKeyMeasurement`/`stop`.
Raw PPG: `startMeasureHrRaw`/`stopMeasure`, `startMeasureSpo2Raw`/`stopMeasureSpo2Raw`.
Sport: `startSportMode`, `pauseSportMode`, `resumeSportMode`, `endSportMode`,
`syncSportSessions`.

Native→Dart callbacks (exact method names + payloads): `onConnected{deviceName}`,
`onDisconnect{deviceName}`, `onBleStateChange{state}`, `onBatteryUpdate{battery,charging}`,
`onDeviceNotify{dataType,loadData}`, `onRealtimeHeartRate{bpm}`,
`onPeriodicSyncTick{intervalMin}`, `onHeartStream{hr}`, `onSpo2Stream{spo2,hr}`,
`onHrvStream{hrv,hr,stress}`, `onOneKeyMeasurementStream{hr,spo2,sbp,dbp,fatigue,score}`,
`onHeartRateMeasured{bpm}`, `onSpo2Measured{spo2}`, `onBloodPressureMeasured{sbp,dbp}`.

The per-method payload shapes are specified in the implementation plan (verbatim from
the Android spec). Cardio Load's critical subset: `getSleepHistory`, `getHrHistory`,
`getHrvHistory`, `getStressDay`, the connection callbacks, `setScheduledMonitoring`,
`setPersonalInfo`, and `onPeriodicSyncTick`.

## The hard parts

### 1. Background parity (full, per decision)
Android = foreground service + `Handler` firing the tick every 5–60 min. iOS assembles
parity from: **CB state restoration** (`CBCentralManagerOptionRestoreIdentifierKey` +
relaunch rewiring), **`bluetooth-central` background mode** (Info.plist + entitlements),
and **`BGTaskScheduler`** (`BGProcessingTask`) to fire the tick when suspended; an in-app
`Timer` covers foreground. Tick still calls `invokeMethod('onPeriodicSyncTick',
{intervalMin})` so the Dart `PeriodicSyncCoordinator` is untouched.
**Caveat:** iOS background BLE is best-effort by OS design; less deterministic than
Android's foreground service, and only truly validated over real overnight runs.

### 2. Payload normalization (the bulk of the work)
Each history method needs a `QCModel → Android-shape map` translator in `PayloadCodec`.
Known traps:
- **HRV**: emit raw bytes as RMSSD-ms; do **NOT** divide by 10 (Android verified this on
  H59 despite the SDK doc comment). Shape `{values, intervalMinutes, rawArray}`.
- **Sleep**: map `QCSleepModel` stage enum → Android `type` codes (1=deep, 2=light,
  3=wake, 4=rem, 5=no-wear) + the duration fields.
- **Timestamps**: apply the same band-local→Unix-sec tz correction Android does, so the
  Dart adapters and the `bpsync:<deviceId>:<epochSec>` dedup ids line up.
- **Raw PPG**: emit exact `{timestamp_ms, ppg_count, green, red, infrared, heart, rri,
  hrv, accel_x, accel_y, accel_z}`; reproduce the signed-int16 accel byte combination.

### 3. SDK-gap risks
QCBandSDK areas thinner than Android — flag each in the plan, and where iOS genuinely
can't match, **return the same payload shape with empty data rather than throw** (so
Dart still doesn't change):
- **Sport mode** granularity may differ (verify `QCSportModel`/exercise APIs).
- **OneKey**: iOS has a real `QCRealOneKeyMeasureHeartRateModel` — iOS may be *better*
  than Android (which fakes it via the BP leg). Emit the same `{hr,spo2,sbp,dbp,
  fatigue,score}` shape.
- **ECG**: not in our method set — ignore.

## Testing strategy

1. **Native unit tests** (`ios/RunnerTests/`): `PayloadCodec` normalizers — feed canned
   `QCSleepModel`/`QCHRVModel`/`QCStressModel`/raw-PPG fixtures, assert the emitted map
   equals the Android payload shape byte-for-byte (keys/types/units). This is where most
   correctness lives and needs no hardware.
2. **Dart side unchanged** — existing `test/sync_adapters_*` already assert the Dart
   decode of these payloads; if iOS emits Android's shape, those pass as-is. No new Dart
   tests; their continued green is the parity proof.
3. **On-device acceptance** (iPhone + H59): pair → `setScheduledMonitoring` → wear →
   BLE Debug "Scores" → confirm a `nightly_records` row writes with sane `hrP5`. Then a
   multi-night overnight run to validate background tick + Cardio Load accumulation.

## Dependencies

No new Dart packages. iOS: Info.plist `UIBackgroundModes: [bluetooth-central]`,
`BGTaskSchedulerPermittedIdentifiers`; entitlements for background BLE. CocoaPods
already wires QCBandSDK (verify the Podfile references the framework used by the demo).

## Out of scope

- No Dart changes (contract frozen).
- No new scoring logic (Cardio Load engine is platform-agnostic Dart, already done).
- Raw-PPG-morphology / BP-algorithm work remains sensor-blocked regardless of platform.
