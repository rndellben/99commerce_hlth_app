# Android SDK Reference — QRing (`qring_sdk_1.0.0.17.aar`)

The vendor BLE SDK for the ring on Android, package root `com.oudmon.ble.*`
(a.k.a. "Oudmon"/QRing). Shipped as a **compiled AAR** — no Java source; this
reference is built from the class inventory, the `proguard.txt` keep rules, the
imports the bridge actually uses, the **vendor manual `sdk_ring.pdf` (36 pp,
read in full)**, and the 93-file demo app under
`Transfered Files/QRing_Android_SDK_1.0.0.17/`.

> **Min OS:** the manual states **Android 5.0 / Bluetooth 4.0**. The app,
> however, sets **minSdk 26** in `build.gradle.kts` (with core-library
> desugaring) — a project choice above the SDK's stated floor, so treat 26 as
> the effective minimum for this app.

> Integrated at [`android/app/libs/qring_sdk_1.0.0.17.aar`](../android/app/libs/qring_sdk_1.0.0.17.aar),
> declared in [`build.gradle.kts:47`](../android/app/build.gradle.kts#L47)
> (`implementation(files("libs/qring_sdk_1.0.0.17.aar"))`). All usage lives in
> [`BleManager.kt`](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt).

## AAR contents

| Item | Purpose |
|---|---|
| `classes.jar` | The SDK (~900 KB, `com.oudmon.ble.*`) |
| `libs/rtk-*.jar` | Realtek audio/bbpro/core — Bluetooth transport internals (unused by us) |
| `jni/{arm64-v8a,armeabi-v7a}/libDspConfig.so` | Native DSP config lib (bundled automatically) |
| `proguard.txt` | Consumer keep rules (35 KB) — auto-applied; preserves the SDK's public/serialized classes |
| `AndroidManifest.xml` | Minimal (no components) |

## Package map (`com.oudmon.ble`)

| Package | Role |
|---|---|
| `base.bluetooth` | **Connection layer** — `BleOperateManager` (connect/disconnect/bond), `ListenerKey`, GATT queue, SPP |
| `base.scan` | **Discovery** — `BleScannerHelper`, `ScanRecord`, `ScanWrapperCallback` |
| `base.communication` | **Command layer** — `CommandHandle`, `LargeDataHandler`, `ICommandResponse`, `Constants`, `EnableNotifyRequest` |
| `base.communication.req` | **Request commands** (write) — ~70 `*Req` classes |
| `base.communication.rsp` | **Response payloads** (read/notify) — ~70 `*Rsp` classes |
| `base.communication.sport` | **Workouts** — `SportPlusHandle`, `SportPlusEntity`, `SportLocation`, `BaseCallback` |
| `base.communication.entity` | Data entities — `BlePressure`, `BleStepDetails`, `StartEndTimeEntity` |
| `base.communication.bigData` | Bulk callbacks — `BloodOxygenEntity`, `IBloodOxygenCallback`, `IntervalBloodOxygenEntity` |
| `base.communication.responseImpl` | Listeners — `DeviceNotifyListener` (band push) |
| `base.bean` | View beans — `SleepDisplay` |
| `sync`, `sync.flow` | Higher-level sync-flow orchestration (not used; the bridge orchestrates itself) |

## Architecture — how a command works

The SDK is **asynchronous and callback-driven**:

```
CommandHandle.getInstance().executeReqCmd(SomeReq(...), ICommandResponse<SomeRsp>{ rsp -> ... })
        │                                     │
        │ queues + writes the GATT frame      └─ parsed response / notify delivered here (bg thread)
        ▼
BleOperateManager  ──GATT──▶  ring  ──notify──▶  back up through the queue
```

- **`BleOperateManager`** — the singleton owning the GATT connection: `connect`,
  `disconnect`, bonding, connection-state listeners (`ListenerKey`). The bridge
  wraps it for `connect`/`disconnect` and observes `onConnectionChange`.
- **`CommandHandle`** — `getInstance().executeReqCmd(req, ICommandResponse)`. The
  canonical path for short commands (settings writes, small reads, time-set).
- **`LargeDataHandler`** — bulk/paged history (sleep details, SpO2 intervals,
  HRV series). Uses `ILargeDataResponse` / `ILargeDataSleepResponse` callbacks.
- **`SportPlusHandle`** — workout sync: `syncSportPlus(BaseCallback<List<SportPlusEntity>>)`
  + `cmdSummary(0)`.
- **`DeviceNotifyListener`** — registered via
  `BleOperateManager.addOutDeviceListener(ListenerKey.X, listener)` for
  unsolicited band pushes. `ListenerKey`: `Heart=1, BloodPressure=2,
  BloodOxygen=3, Temperature=5, SportRecord=7, All=7`. **Must `removeNotifyListener`
  after use** or callbacks stack. `DeviceNotifyRsp.dataType` (manual §2.3.9):

  | dataType | Meaning |
  |---|---|
  | `1` | HR test changed |
  | `2` | BP test changed |
  | `3` | SpO2 test changed |
  | `4` | step-detail changed |
  | `5` | body-temp changed (H59: n/a) |
  | `7` | **new exercise record** generated |
  | `0x0c` | charging/battery (loadData[2]=charging, [1]=level) |
  | `0x12` | live step/calorie/distance push |
  | `0x2d` | custom button (1=decline, 2=slide-up, 3=single, 4=long-press) |
  | `0x3A` | HR too-low/high reminder (type 1=low, 2=high, + value) |

- **`BleScannerHelper`** — `scanDevice(context, uuid, ScanWrapperCallback)` /
  `stopScan` / `scanTheDevice(mac, …)`; `ScanRecord` carries name/RSSI.
- **`BleOperateManager`** — `connectDirectly(addr)` / `connectWithScan(addr)` /
  `unBindDevice()` / `disconnect()` / `setNeedConnect(bool)` (auto-reconnect) /
  `setBluetoothTurnOff(bool)`.

## Request/response catalog (selected)

Full inventory is ~70 `*Req` + ~70 `*Rsp`. The ones the app relies on:

| Feature | Request | Response | Notes |
|---|---|---|---|
| Bind + time + capabilities | `SetTimeReq(0)` | `SetTimeRsp` | Exposes `mSupportHrv/BloodOxygen/BloodPressure/Temperature`, `mNewSleepProtocol` |
| Device support | `DeviceSupportReq` | `DeviceSupportFunctionRsp` | Feature flags |
| HR monitoring | `HeartRateSettingReq(getWriteInstance / getReadInstance)` | `HeartRateSettingRsp` | interval + mainSwitch |
| HR history | `ReadHeartRateReq` | `ReadHeartRateRsp` | hourly HR slots |
| HR realtime notify | — | `RealTimeHeartRateRsp` | via `dataType=1` push |
| HRV monitoring | `HrvSettingReq(true, interval)` | `HRVSettingRsp` | **write-ack `isEnable` unreliable** |
| HRV data | `HRVReq` | `HRVRsp` | |
| SpO2 monitoring | `BloodOxygenSettingReq` | `BloodOxygenSettingRsp` | + `IntervalBloodOxygenEntity` via bigData |
| Stress | `PressureSettingReq(getWriteInstance)` / `PressureReq` | `PressureSettingRsp` / `PressureRsp` | "pressure" = stress |
| BP monitoring | `BpSettingReq(getWriteInstance)` | `BpSettingRsp` | scheduled BP (no retrievable history on H59) |
| BP read | `ReadBlePressureRsp` | | `time` already TZ-corrected to UTC by SDK |
| Steps today | `SimpleKeyReq(CMD_GET_STEP_TODAY)` | `TodaySportDataRsp` | totals |
| Step buckets | `ReadDetailSportDataReq` | `ReadDetailSportDataRsp` | 15-min buckets |
| Sleep | (new-protocol large data) | `SleepNewProtoResp` / `ReadSleepDetailsRsp` | retrospective sessions |
| Personal info | `SetTimeReq` family / profile req | `UserProfileRsp` | age/sex/height/weight |
| Workouts | `PhoneSportReq.getSportStatus(status, type)` + `SportPlusHandle` | `AppSportRsp` / `SportPlusEntity` | start/end + summary |
| Raw PPG | (enable notify + `PpgDataRspCmd`) | `PpgDataRspCmd` | green/red/IR + accel; only during active raw capture |

`Constants` holds command opcodes (e.g. `CMD_GET_STEP_TODAY`,
`CMD_BP_TIMING_MONITOR_DATA`, `CMD_BIND_SUCCESS`,
`CMD_GET_DEVICE_ELECTRICITY_VALUE`).

### Monitoring-setting write signatures (manual §2.3.2, exact)

```java
HeartRateSettingReq.getWriteInstance(isEnable, hrInterval[,startInterval,tooLow,tooHigh])
    // hrInterval ∈ {10,15,20,30,60}; startInterval ∈ {5,10,30};
    // tooLowReminder ∈ {0,40,45,50}; tooHighReminder ∈ {0,110,120,130,140,150}; 0=off
BloodOxygenSettingReq.getWriteInstance(isEnable[, intervalMin])
BpSettingReq.getWriteInstance(isEnable, StartEndTimeEntity(0,0,23,59), multiple=60)
PressureSettingReq.getWriteInstance(isEnable)   // "pressure" = stress
HrvSettingReq(true[, intervalMin])              // write-ack unreliable on H59
```
Each has a matching `getReadInstance()` whose `*Rsp` is the trustworthy state.

### Exercise types — `PhoneSportReq.getSportStatus(status, sportType)` (manual §2.3.10)

`status`: `1`=start, `2`=pause, `3`=continue, `4`=end, `6`=start-timestamp.
`sportType` (band "open exercise" enum — distinct from the ~225 SportPlus space):

| # | Type | # | Type | # | Type |
|---|---|---|---|---|---|
| 4 | Walking | 20 | Hiking | 30 | Golf |
| 5 | Jump rope | 21 | Badminton | 31 | Basketball |
| 7 | Running | 22 | Yoga | 32 | Football |
| 8 | Hiking | 23 | Aerobics | 33 | Volleyball |
| 9 | Cycling | 24 | Spinning | 34 | Rock climbing |
| 10 | Other | 25 | Kayaking | 35 | Dance |
| | | 26 | Elliptical | 36 | Roller skating |
| | | 27 | Rowing | 60 | Outdoor hiking |
| | | 28 | Table tennis | | |
| | | 29 | Tennis | | |

Response `AppSportRsp.gpsStatus`: 6=start time (sec), 2=pause, 3=continue, 4=end.
> The app's `sportTypeStrength = 88` is **not** in this "open exercise" list —
> 88 comes from the SportPlus/`OdmSportPlusExerciseModelType` space used by
> `SportPlusHandle` summaries. Two type-spaces coexist; don't conflate them.

## Permissions & manifest (host app)

The **host app** declares the runtime BLE permissions (the AAR manifest is
minimal): `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` (Android 12+),
`ACCESS_FINE_LOCATION` (legacy scan), `FOREGROUND_SERVICE` if backgrounded. The
`libDspConfig.so` JNI libs are packaged automatically from the AAR.

## Build / ProGuard / R8

- The AAR carries **consumer ProGuard rules** (`proguard.txt`) that R8 applies
  automatically — they keep the SDK's public API + reflective/serialized model
  classes. **Do not** add aggressive `-dontwarn`/strip rules over `com.oudmon.**`
  or `com.realtek.**` or release builds will crash on missing SDK classes.
- Native libs are `arm64-v8a` + `armeabi-v7a` only — no x86; fine for physical
  devices, relevant if targeting an x86 emulator.

## Known H59 quirks (validated in this project)

1. **Dormant until monitoring enabled** — nothing records until
   `HeartRateSettingReq`/`HrvSettingReq`/etc. are written.
2. **Write-ack lies** — settings `*Rsp.isEnable` returns false even when active;
   a **read-back ~2s later is ground truth** ([BleManager.kt:1151](../android/app/src/main/kotlin/com/hlth/hlth_app/ble/BleManager.kt#L1151)).
3. **BP has no scheduled history** — `getBpDay`/timing-monitor times out
   (`-4001`); only on-demand `startBpMeasurement` works.
4. **HRV stored under wear-day index** — pull dayOffset 0 *and* 1.
5. **Accel only during raw PPG** — no free-running accelerometer feed.
6. **Slow bootstrap** — `SetTimeReq` can take ~1 min to ack on a cold connect.
7. **Latest ~10 exercise records only** — sync after each workout or lose it.

## Reference material in-repo

- `Transfered Files/QRing_Android_SDK_1.0.0.17/sdk_ring.pdf` — the vendor SDK
  manual (command opcodes, byte layouts, `§2.3.x` sections cited throughout
  `BleManager.kt`).
- `Transfered Files/QRing_Android_SDK_1.0.0.17/app/src/` — 93-file demo
  (Activities per feature: HR, SpO2, BP, Sleep, Sport, Settings) — the canonical
  usage examples the bridge was modeled on.
- `Transfered Files/Build guide/hlth-sdk-data-inventory.md` — our normalized map
  of every SDK data source → canonical entity.

See [IOS_SDK_REFERENCE.md](IOS_SDK_REFERENCE.md) for the iOS counterpart and
[FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md) for how these map to Dart.
