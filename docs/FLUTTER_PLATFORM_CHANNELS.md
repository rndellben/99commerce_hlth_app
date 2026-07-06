# Flutter ↔ Native Platform Channels

The complete communication contract between the Dart layer and the native BLE
bridges (Android Kotlin / iOS Swift). This is the **single most important
integration surface** in the app: every band interaction crosses it.

> Source of truth: [`lib/core/ble/ble_service.dart`](../lib/core/ble/ble_service.dart)
> (Dart contract), [`android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt`](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt)
> (Android), [`ios/Runner/BLE/`](../ios/Runner/BLE/) (iOS bridge, mirrors Android).
> **The Dart contract is frozen** — the iOS bridge was built to match Android
> so the same `BleService` runs unchanged on both platforms.

## Channel inventory

| Channel | Type | Name | Direction | Purpose |
|---|---|---|---|---|
| Method | `MethodChannel` | `hlth/ble` | Flutter → Native (+ Native → Flutter callbacks) | All commands + async callbacks |
| Event | `EventChannel` | `hlth/realtime_stream` | Native → Flutter | Raw PPG stream (green/red/IR + accel during raw capture) |
| Event | `EventChannel` | `hlth/realtime_stream_accel` | Native → Flutter | Accel-only stream (declared; fed from the raw-PPG path) |

Channel name constants live at [BleManager.kt:96-98](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L96).

## Why one MethodChannel does both directions

There is a single `MethodChannel("hlth/ble")`. Flutter calls native via
`invokeMethod('command', args)`. Native calls **back** into Flutter over the
*same* channel via `methodChannel.invokeMethod('onXxx', payload)` — Dart routes
these in a single `setMethodCallHandler` switch (`_handleCallback` in
`ble_service.dart`). This keeps one bound channel instead of many, and lets the
band's asynchronous, callback-driven SDK model (fire a command, get an answer
later on a delegate/listener) map cleanly onto Dart `Stream`s and one-shot
`Future`s.

On the native side the helper is `callDart(method, payload)` (iOS) /
`methodChannel.invokeMethod(...)` marshalled to the main thread (Android) — BLE
SDK callbacks arrive on background threads and **must** be hopped to the
platform thread before touching the channel.

---

## Flutter → Native: command methods (49)

Authoritative list = the `when(call.method)` dispatch in `BleManager.kt`.
Grouped by domain. Unless noted, each returns a `Future` that completes with a
Map or primitive, or throws a `PlatformException` (mapped to a `FlutterError`
on native).

### Connection & scan
| Method | Args | Returns | Notes |
|---|---|---|---|
| `startScan` | — | `List<{id,name,rssi}>` after ~10s window | Name-prefix filtered (H59, O_, Q_, C6x…). iOS also `retrieveConnectedPeripherals`. |
| `stopScan` | — | null | |
| `connect` | `{deviceId}` | optimistic null; real state via `onConnected` | iOS binds peripheral to `QCSDKManager` after GATT connect. |
| `disconnect` | — | null + `onDisconnect` | |
| `getBattery` | — | `{level,charging}` + `onBatteryUpdate` | |

### Scheduled monitoring config (band records nothing until these run)
| Method | Args | Returns | Notes |
|---|---|---|---|
| `setScheduledMonitoring` | `{hrInterval=10, startInterval=5, spo2Interval=60, hrvInterval=30, bpIntervalMinutes=60}` | Map | Umbrella: writes HR/HRV/SpO2/BP/stress enables. **H59 write-ack `isEnable` is unreliable — trust the read-back** ([BleManager.kt:1151](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1151)). Auto-called on connect edge ([sync_service.dart](../lib/core/services/sync_service.dart), `_onConnectionChange`). |
| `getScheduledHr` | — | Map | Read-back (ground truth). |
| `setStressScheduled` / `getStressScheduled` | on/off | Map | Stress ("pressure") monitoring. |
| `setBpScheduled` / `getBpScheduled` | on/off + cadence | Map | Scheduled BP (H59: no retrievable history — see below). |
| `enableSpO2Interval` / `getSpO2Interval` / `getSpO2Capability` | | | H59 SpO2 interval support is inconclusive (capability flag false, firmware accepts). |
| `setSyncIntervalMinutes` / `getSyncIntervalMinutes` | minutes (5–60) | `{minutes,clamped}` | Native periodic scheduler cadence (default 30 min). |
| `setPersonalInfo` | age/sex/height/weight… | Map | Pushes profile to band (affects band-side calorie/HR calcs). |

### History pulls (read what the band recorded)
`getHrHistory`, `getHrvHistory`, `getSpO2History`, `getSpO2Day`, `getSleepHistory`,
`getStepDay`, `getStepBucketHistory`, `getDailyTotals`, `getStressDay`,
`getBpHistory`, `getBpDay`. Most take `{dayOffset}` (0=today, 1=yesterday, …up
to band retention ~7 days). Return `{readings:[…]}` shapes consumed by
`sync_adapters.dart`.

> **H59 quirk — HRV day index:** overnight HRV is stored under the *wear-day*
> index, so `syncAll` pulls HRV for **both** `dayOffset=0` and `dayOffset=1`.
> **H59 quirk — BP:** `getBpDay` times out (`-4001`); no retrievable scheduled
> BP history. Only on-demand `startBpMeasurement` works. So `syncBp` is
> deliberately **not** in `syncAll`.

### Active / on-demand measurements
| Method | Purpose |
|---|---|
| `startOneKeyMeasurement` / `stopOneKeyMeasurement` | Band's "one key" combined HR+SpO2+BP+HRV sweep → `onOneKeyMeasurementStream`. |
| `startHeartStream` / `stopHeartStream` | Live HR ticks (~30s active) → `onHeartStream`. |
| `startBpMeasurement` / `stopBpMeasurement` | On-demand BP (the only working BP path on H59) → `onBloodPressureMeasured`. |
| `startHrvStream` / `stopHrvStream` | Live HRV stream → `onHrvStream`. |
| `startSpo2Stream` / `stopSpo2Stream` | Live SpO2 → `onSpo2Stream`. |
| `startMeasureHrRaw` / `stopMeasure` | **Raw PPG capture** — the only mode that emits accel + raw green/red/IR on `hlth/realtime_stream`. Battery-heavy; used for fall sweep, respiratory/HRV PPG capture. |
| `startMeasureSpo2Raw` / `stopMeasureSpo2Raw` | Raw SpO2 PPG capture. |

### Sport mode (workouts → VO2 Max)
`startSportMode`, `pauseSportMode`, `resumeSportMode`, `endSportMode`
(`{sportType}` SDK byte: 4=Walk, 7=Run, 9=Cycle, 8=Hike, 26=Elliptical,
27=Row, 22=Yoga, 88=Strength) → `SportSessionAck`. `syncSportSessions` → pulls
`SportSessionSummary` list (avg/min/max HR, distance, speed, calories, steps).

---

## Native → Flutter: callbacks (14)

Handled in the `_handleCallback` switch in `ble_service.dart`; each fans out to
a Dart `Stream` or completes a pending `Future`.

| Callback | Payload | Dart surface |
|---|---|---|
| `onConnected` | `{deviceName}` | `connectionState` stream → `connected` |
| `onDisconnect` | `{deviceName}` | `connectionState` → `disconnected` |
| `onBleStateChange` | `{state}` (CBManager/adapter state) | Bluetooth power state |
| `onBatteryUpdate` | `{battery,charging}` | battery stream |
| `onRealtimeHeartRate` | `{bpm}` | 5s-smoothed realtime HR (from scheduled `dataType=1` notifies) |
| `onHeartRateMeasured` | `{bpm}` | active-measurement HR |
| `onHeartStream` | `{bpm}` | `startHeartStream` ticks |
| `onSpo2Measured` / `onSpo2Stream` | `{spo2}` | SpO2 |
| `onHrvStream` | `{hrv,…}` | HRV stream |
| `onBloodPressureMeasured` | `{sbp,dbp}` | BP result |
| `onOneKeyMeasurementStream` | combined | One-key sweep progress |
| `onDeviceNotify` | `{dataType}` | Band push notifications: 1=HR updated, 2=BP, 3=SpO2, 4=steps, 5=temp, **7=new exercise record**, 0x0c=charging |
| `onPeriodicSyncTick` | `{intervalMin}` | HLT-11 native scheduler heartbeat → drives `PeriodicSyncCoordinator` |

---

## EventChannels (streaming)

`hlth/realtime_stream` emits one map per raw-PPG packet during
`startMeasureHrRaw`/`startMeasureSpo2Raw`:

```
{ timestamp_ms, ppg_count, green, red, ir, accel_x, accel_y, accel_z }
```

- PPG values are reassembled uint16 (`high<<8 | low`) in native — the transport
  byte-split never leaks to Dart.
- Accel are **signed int16, raw counts** — divide by a per-chip `oneGRaw`
  scale (median magnitude during capture) then ×1000 for milli-g. The fall
  detector does this in `sync_service.dart`.
- **H59 hard constraint:** accelerometer data is emitted **only** while raw PPG
  capture is running. There is no free-running accel feed → continuous activity
  detection is impractical (drives the VO2 "sport-mode + auto-prompt" design).

`hlth/realtime_stream_accel` is declared/wired but fed from the same raw path;
consumers read accel out of the PPG stream today.

---

## Threading & lifecycle rules

1. **Marshal callbacks to the platform/main thread** before calling the channel
   — SDK callbacks arrive on BLE background threads.
2. **Optimistic returns:** `connect` returns null immediately; the true result
   arrives via `onConnected`/`onDisconnect`. UI must be state-driven, not
   return-value-driven, for connection.
3. **One in-flight sync:** `PeriodicSyncCoordinator` drops overlapping ticks
   (`_inFlight` guard) rather than queuing.
4. **Never overlap raw captures:** fall sweep, scheduled PPG capture, and
   nightly BP are sequenced so two `startMeasureHrRaw`/active measurements never
   race the single BLE link.

## End-to-end example: a periodic sync

```
native scheduler → onPeriodicSyncTick{intervalMin}
  → PeriodicSyncCoordinator._onTick
    → SyncService.syncAll(userId, deviceId)
      → invokeMethod getHrHistory / getHrvHistory(0 & 1) / getSleepHistory / …
        → BleManager → QRing/QCBand SDK → BLE reads → returns {readings}
      → sync_adapters.* normalize → repositories.insertMany (Drift/SQLite)
      → DailyAggregator.aggregateRecent → daily_metrics rollup
      → recoveryScore / cardioLoad / vo2Max compute → scores table
    → alertEvaluator, fall sweep, scheduled PPG, nightly BP, activity detector
  → Drift watch streams push → Riverpod providers → UI cards rebuild
```

See [BLUETOOTH_FLOW.md](BLUETOOTH_FLOW.md) for the full lifecycle and
[API_REFERENCE.md](API_REFERENCE.md) for the Dart method signatures.
