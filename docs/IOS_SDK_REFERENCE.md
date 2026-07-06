# iOS SDK Reference — QCBandSDK

The vendor BLE SDK for the ring on iOS: `QCBandSDK.framework` (Objective-C,
static, arm64). Unlike the Android AAR, the framework ships **readable ObjC
headers**, so this reference is grounded directly in them, the
`QCBandSDKDemo` sample app, and the **vendor "iOS SDK Development Guide" PDF
(24 pp, read in full)**. Framework supports **iOS 9.0+**.

> Framework: [`ios/Frameworks/QCBandSDK.framework`](../ios/Frameworks/QCBandSDK.framework)
> (Headers + static binary). Demo + a second copy live under
> `Transfered Files/QCBandSDKDemo/`. Bridge usage:
> [`ios/Runner/BLE/`](../ios/Runner/BLE/) (Swift, mirrors the Android contract).

## Framework packaging & required build settings (manual §1)

- **Static** framework, **arm64 device** → linked **"Do Not Embed"** (embedding
  a static framework breaks the build). Build for a **physical device**.
- **`-ObjC`** must be added to **Other Linker Flags** — the framework uses ObjC
  categories that won't load otherwise (missing-selector crashes at runtime).
- **Excluded Architectures:** exclude the **arm64 simulator** slice
  (`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`) — the framework has no sim
  slice, so simulator builds must drop arm64.
- **Info.plist** needs **both** BLE keys:
  `NSBluetoothAlwaysUsageDescription` **and** `NSBluetoothPeripheralUsageDescription`.
- Umbrella header `QCBandSDK.h`; import `QCSDKManager.h` + `QCSDKCmdCreator.h`.
  Swift bridge does `import QCBandSDK`.
- **Service UUIDs** (from `QCSDKManager.h`): `QCBANDSDKSERVERUUID1`,
  `QCBANDSDKSERVERUUID2` (extern `NSString*`).

## The two core classes

### `QCSDKManager` — connection + live callbacks (≈ Android `BleOperateManager`)

Singleton `+[QCSDKManager shareInstance]`. Responsibilities:
- **Bind a connected peripheral:** `-addPeripheral:finished:` (Swift:
  `add(_:finished:)`) — you connect the `CBPeripheral` yourself via CoreBluetooth,
  then hand it to the SDK. `-removePeripheral:` / `-removeAllPeripheral`.
- **Live block callbacks** (set once, fire on band pushes):
  `realTimeHeartRate(NSInteger)`, `currentStepInfo(step,calorie,distance)`,
  `currentBatteryInfo(battery,charging)`, `currentSportInfo(QCSportInfoModel*)`,
  `watchDataUpdateReport(QCDeviceDataUpdateReport dataType, NSInteger value)`
  (the iOS equivalent of Android's `DeviceNotifyListener` — dataType 1=HR,
  2=BP, 3=SpO2, 4=steps, 5=temp, 7=exercise, 0x0c=charging),
  `hrMeasuring/bpMeasuring/boMeasuring`, `measuringFail`, `lowerPower`,
  `flipWristInfo`, `touchSleepInfo`, camera/find-phone hooks.
- **Active measurement:** `-startToMeasuringWithOperateType:measuringHandle:completedHandle:`
  (+ timeout variant) with `QCMeasuringType` enum; `-stopToMeasuringWithOperateType:`.
  Wear calibration: `-startToWearCalibration…`.

> **CoreBluetooth is owned by the app, not the SDK.** The bridge creates its own
> `CBCentralManager`, scans (nil services + name-prefix filter),
> `connect`s the peripheral, and only *then* calls `add(peripheral)`. The demo's
> `QCCentralManager` is a demo-only convenience wrapper and is **not** used by
> the bridge.

### `QCSDKCmdCreator` — the command factory (≈ Android `CommandHandle` + `*Req`)

**137 class/instance methods** — every command is a factory call with a success
(and often failure) block. Representative families:

| Family | Examples |
|---|---|
| Time / bind | set time, `alertBindingSuccess` |
| HR | `readBatterySuccess:failed:`, real-time HR begin/continue/end, scheduled HR (`QCSchedualHeartRateModel`) |
| BP | `beginBloodPressureMeasuring…`, `endBloodPressureMeasuringWithSbp…` |
| SpO2 | `beginBloodOxygen…`, `endBloodOxygenMeasuringWithSo2…` |
| HRV | HRV read → `QCHRVModel` |
| Stress | stress read → `QCStressModel` |
| Sleep | `QCSleepModel` (+ new-protocol) |
| Steps/sport | `getCurrentSportSucess:`, `getOneDaySportBy:`, `getSportDetailDataByDay:`, exercise via `getExerciseDataWithLastUnixSeconds:` / SportPlus (`getSportPlusSummary…`, `getSportPlusDetails…`) |
| Settings | alarms, contacts, dial index, flip-wrist, gesture, DND, brightness, drink reminders, targets |

Reads return typed models; measurements stream via the `QCSDKManager` blocks.

## Data models (`QC*Model` / `Odm*`)

| Model | Carries |
|---|---|
| `QCHeartRateModel` / `QCSchedualHeartRateModel` / `QCManualHeartRateModel` / `QCRealOneKeyMeasureHeartRateModel` | HR (scheduled / manual / one-key) |
| `QCHRVModel` | HRV (RMSSD/SDNN) |
| `QCStressModel` | stress ("pressure") |
| `QCBloodOxygenModel` | SpO2 |
| `QCBloodPressureModel` | BP |
| `QCSleepModel` | sleep sessions + stages (SLEEPTYPE: NONE0/SOBER1/LIGHT2/DEEP3/REM4/UNWEARED5) |
| `QCSportModel` / `QCSportInfoModel` / `QCExerciseModel` / `OdmSportPlusModels` | daily sport totals / live sport tick / basic exercise (4 types: Run/Bike/Lift/Walk) / SportPlus (~225 types) |
| `QCTemperatureModel` / `QCThreeValueTemperatureModel` | temperature (H59: unsupported) |
| `OdmBandNotifyCenter`, `OdmBleConstants` | notify routing, constants |

> **iOS↔Android type-space mismatch:** iOS basic `QCExerciseModel` has only 4
> sport types; Android SportPlus has ~225. The adapter normalizes iOS's 4 into
> the canonical 225-ID space (Run=7, Bike=51, Lift=88, Walk=8 numbering).

## Mapping to the frozen Dart contract

The Swift bridge implements the same `hlth/ble` MethodChannel handlers and
`hlth/realtime_stream[_accel]` EventChannels as Android, translating each
`invokeMethod` case into `QCSDKCmdCreator`/`QCSDKManager` calls and each block
callback into `callDart("onXxx", …)`. See
[FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md). Bridge files:
`BleManager.swift` (+`+Connection`, `+Config`, `+History`, `+Background`,
`+Events`), `PayloadCodec.swift`.

## Command index (manual §3, 48 commands)

The guide enumerates every `QCSDKCmdCreator`/`QCSDKManager` command. Notable
ones beyond the basics: §3.27–3.28 **SportPlus V2** summary + detail
(`getSportPlusSummaryFromTimestamp:` → `getSportPlusDetailsWithSummary:`),
§3.39 **Set Sport Mode State** (ring-only), §3.40 **Scheduled Stress**
(`QCStressModel`, ring-only), §3.42 **Scheduled HRV** (`QCHRVModel`, ring-only),
§3.45 **Scheduled SpO2 with time interval**, §3.24–3.26 timed HR
(history/get/set), §3.18–3.20 timed BP (get/set/history), §3.36 measurement
commands encapsulated in `QCSDKManager`. Read the PDF for exact selectors +
callback block shapes.

## Xcode / linking recap

- Framework at `ios/Frameworks/QCBandSDK.framework`; in the Runner target's
  **Frameworks, Libraries, and Embedded Content** as **Do Not Embed** + BLE
  Swift files in **Compile Sources**. `-ObjC` linker flag + arm64-sim exclusion
  (see build settings above).
- iOS uses **CoreBluetooth state** as the real permission gate — the Android-only
  `Permission.bluetoothScan/Connect` do not apply.
- Supabase env injected via `--dart-define-from-file=hlth.env.json`, baked into
  `Generated.xcconfig` (`flutter build ios --config-only`).

## Demo app (`QCBandSDKDemo`) — reference usage

13 ObjC files: `ViewController` (feature grid), `QCScanViewController` +
`QCCentralManager` (scan/connect), `PPGViewController` (raw PPG),
`CollectionViewFeatureCell`. Open `QCBandSDKDemo.xcworkspace` to run the vendor's
canonical examples — the bridge's connection/measurement patterns were modeled
on these.

See [ANDROID_SDK_REFERENCE.md](ANDROID_SDK_REFERENCE.md) for the Android
counterpart and [BLUETOOTH_FLOW.md](BLUETOOTH_FLOW.md) for the shared lifecycle.
