# iOS BLE Bridge — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use flutter-craft:flutter-executing to implement this plan task-by-task.

**Goal:** Build the iOS native BLE bridge (`ios/Runner/BLE/`, Swift wrapping QCBandSDK) to full parity with the Android `BleManager.kt`, so `lib/core/ble/ble_service.dart` runs unchanged on iOS — culminating in Cardio Load computing on iPhone.

**Architecture:** Native iOS (Swift) platform-channel layer. Not Dart Clean Architecture — the Dart contract is frozen. "Layers" here are: Foundation/wiring → critical-subset features → background → remaining features → verification.

**Design doc:** `docs/plans/2026-06-26-ios-ble-bridge-design.md`

**Governing rule:** the bridge emits the *exact Dart-facing payloads Android emits*. Every history method normalizes its QCBandSDK model into Android's map shape. Channel names: `hlth/ble` (method + callbacks), `hlth/realtime_stream` (raw PPG), `hlth/realtime_stream_accel`.

**Reference:** QCBandSDK iOS API (`scratchpad/qcbandsdk_ios_reference.md`); Android payload spec (in this session's research). The demo (`Transfered Files/QCBandSDKDemo/`) is the working usage reference.

**Dependencies:** No Dart packages. iOS: link/embed `QCBandSDK.framework`; Info.plist `UIBackgroundModes:[bluetooth-central]` + `BGTaskSchedulerPermittedIdentifiers`; `NSBluetoothAlwaysUsageDescription`.

---

## Sequencing

- **Phase 0 (Tasks 1–3):** make it compile + link + the channel/dispatch/codec skeleton.
- **Phase 1 (Tasks 4–11):** the Cardio Load critical subset — testable end-to-end on device.
- **Phase 2 (Tasks 12–14):** full background parity.
- **Phase 3 (Tasks 15–23):** remaining ~30 methods for full parity.
- **Phase 4 (Tasks 24–25):** native codec unit tests + on-device acceptance.

Checkpoint after Phase 1: build, run codec tests, smoke-test Cardio Load on iPhone. Don't start Phase 3 until that passes (per "sequence work, don't bundle").

---

## Phase 0 — Foundation & Wiring

### Task 1: Link & embed QCBandSDK.framework into the Runner target

**Layer:** Foundation

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (link + embed)
- Verify: `ios/Runner/Runner-Bridging-Header.h`

**Context:** `ios/Frameworks/QCBandSDK.framework` is physically present but `project.pbxproj` has zero references to it, so `import QCBandSDK` will not link. This must be fixed first or nothing builds.

**Implementation:**
1. Open `ios/Runner.xcworkspace` in Xcode → Runner target → **General → Frameworks, Libraries, and Embedded Content** → `+` → Add Other → `ios/Frameworks/QCBandSDK.framework` → set to **Embed & Sign**.
2. Build Settings → **Framework Search Paths** → add `$(PROJECT_DIR)/Frameworks` (recursive non-needed).
3. The framework is a Swift-importable module (`import QCBandSDK`). If it exposes only Obj-C headers, ensure `Runner-Bridging-Header.h` has `#import <QCBandSDK/QCBandSDK.h>` AND the module map resolves; prefer the Swift `import QCBandSDK` if `Modules/module.modulemap` exists in the framework (it does per the demo).
4. Confirm `ENABLE_BITCODE = NO` (QCBandSDK is a binary framework).

**Verification:**
```bash
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
# Expected: BUILD SUCCEEDED (after Task 2's BleManager compiles; for now expect the import to resolve)
```
> Note: a physical-device build is needed later for BLE; the simulator build here only proves the framework links + Swift compiles.

**Commit:** `chore(ios): link and embed QCBandSDK.framework into Runner target`

---

### Task 2: Rewrite BleManager.swift core (channels, dispatch, callback helper)

**Layer:** Foundation

**Files:**
- Rewrite: `ios/Runner/BLE/BleManager.swift`

**Context:** Replace the Phase-0 scaffold. Correct channel names (`hlth/ble`, `hlth/realtime_stream`, `hlth/realtime_stream_accel`), add a full method-dispatch `switch`, and a `callDart(_:_:)` helper that always invokes on the main thread. Feature method bodies live in extensions (later tasks); here they're routed to stubs returning `FlutterMethodNotImplemented` until implemented, so the project always compiles.

**Implementation:**
```swift
import Foundation
import CoreBluetooth
import Flutter
import QCBandSDK

final class BleManager: NSObject {
    static let shared = BleManager()

    var methodChannel: FlutterMethodChannel?
    var ppgEventSink: FlutterEventSink?
    var accelEventSink: FlutterEventSink?

    // CoreBluetooth
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [String: CBPeripheral] = [:]
    var connectedPeripheral: CBPeripheral?
    var connectedDeviceName: String = ""
    var pendingConnectResult: FlutterResult?

    // Active-stream guards (mirror Android's flags)
    var hrStreaming = false
    var spo2Streaming = false
    var hrvStreaming = false
    var okmStreaming = false

    // Periodic sync (Task 10 / 14)
    var syncIntervalMinutes = 30
    var periodicTimer: Timer?

    lazy var serviceUUIDs: [CBUUID] = [
        CBUUID(string: QCBANDSDKSERVERUUID1),
        CBUUID(string: QCBANDSDKSERVERUUID2),
    ]

    private override init() {
        super.init()
        // Restoration options added in Task 12.
        centralManager = CBCentralManager(delegate: self, queue: .main)
        wireMeasurementCallbacks() // Task 19/20/21
        registerDeviceEventObservers() // Task 11
    }

    func register(with messenger: FlutterBinaryMessenger) {
        let mc = FlutterMethodChannel(name: "hlth/ble", binaryMessenger: messenger)
        mc.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        methodChannel = mc

        FlutterEventChannel(name: "hlth/realtime_stream", binaryMessenger: messenger)
            .setStreamHandler(SinkStreamHandler { [weak self] in self?.ppgEventSink = $0 })
        FlutterEventChannel(name: "hlth/realtime_stream_accel", binaryMessenger: messenger)
            .setStreamHandler(SinkStreamHandler { [weak self] in self?.accelEventSink = $0 })
    }

    /// Always call Dart on the main thread (Android posts to main looper).
    func callDart(_ method: String, _ args: Any? = nil) {
        if Thread.isMainThread {
            methodChannel?.invokeMethod(method, arguments: args)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.methodChannel?.invokeMethod(method, arguments: args)
            }
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        // Connection (Task 4)
        case "startScan": startScan(result)
        case "stopScan": stopScan(result)
        case "connect": connect(a["deviceId"] as? String, result)
        case "disconnect": disconnect(result)
        case "getBattery": getBattery(result)
        // Config (Task 5, 15)
        case "setPersonalInfo": setPersonalInfo(a, result)
        case "setScheduledMonitoring": setScheduledMonitoring(a, result)
        case "getScheduledHr": getScheduledHr(result)
        case "setBpScheduled": setBpScheduled(a, result)
        case "getBpScheduled": getBpScheduled(result)
        case "setStressScheduled": setStressScheduled(a, result)
        case "getStressScheduled": getStressScheduled(result)
        case "setSyncIntervalMinutes": setSyncIntervalMinutes(a, result)
        case "getSyncIntervalMinutes": result(["minutes": syncIntervalMinutes])
        // History (Task 6–9, 16–18)
        case "getSleepHistory": getSleepHistory(a["dayOffset"] as? Int ?? 0, result)
        case "getHrHistory": getHrHistory(a["dayOffset"] as? Int ?? 0, result)
        case "getHrvHistory": getHrvHistory(a["dayOffset"] as? Int ?? 0, result)
        case "getStressDay": getStressDay(a["dayOffset"] as? Int ?? 0, result)
        case "getSpO2Day": getSpO2Day(a["dayOffset"] as? Int ?? 0, result)
        case "getSpO2History": getSpO2History(result)
        case "getSpO2Interval": getSpO2Interval(a["dayOffset"] as? Int ?? 0, result)
        case "getSpO2Capability": getSpO2Capability(result)
        case "enableSpO2Interval": enableSpO2Interval(a, result)
        case "getBpDay": getBpDay(a["dayOffset"] as? Int ?? 0, result)
        case "getBpHistory": getBpHistory(result)
        case "getDailyTotals": getDailyTotals(result)
        case "getStepBucketHistory": getStepBucketHistory(a["dayOffset"] as? Int ?? 0, result)
        case "getStepDay": getStepDay(a["dayOffset"] as? Int ?? 0, result)
        // Measurement (Task 19–21)
        case "startHeartStream": startHeartStream(result)
        case "stopHeartStream": stopHeartStream(result)
        case "startSpo2Stream": startSpo2Stream(result)
        case "stopSpo2Stream": stopSpo2Stream(result)
        case "startHrvStream": startHrvStream(result)
        case "stopHrvStream": stopHrvStream(result)
        case "startBpMeasurement": startBpMeasurement(result)
        case "stopBpMeasurement": stopBpMeasurement(result)
        case "startOneKeyMeasurement": startOneKeyMeasurement(result)
        case "stopOneKeyMeasurement": stopOneKeyMeasurement(result)
        // Raw PPG (Task 22)
        case "startMeasureHrRaw": startMeasureHrRaw(a["duration_sec"] as? Int ?? 30, result)
        case "stopMeasure": stopMeasureRaw(result)
        case "startMeasureSpo2Raw": startMeasureSpo2Raw(a["duration_sec"] as? Int ?? 30, result)
        case "stopMeasureSpo2Raw": stopMeasureSpo2Raw(result)
        // Sport (Task 23)
        case "startSportMode": sendSportStatus(1, a["sportType"] as? Int ?? 0, result)
        case "pauseSportMode": sendSportStatus(2, a["sportType"] as? Int ?? 0, result)
        case "resumeSportMode": sendSportStatus(3, a["sportType"] as? Int ?? 0, result)
        case "endSportMode": sendSportStatus(4, a["sportType"] as? Int ?? 0, result)
        case "syncSportSessions": syncSportSessions(result)
        default: result(FlutterMethodNotImplemented)
        }
    }
}

/// Reusable EventChannel stream handler that just hands the sink back.
final class SinkStreamHandler: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void
    init(onSink: @escaping (FlutterEventSink?) -> Void) { self.onSink = onSink }
    func onListen(withArguments _: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events); return nil
    }
    func onCancel(withArguments _: Any?) -> FlutterError? { onSink(nil); return nil }
}
```
> During Phase 0, add temporary `extension BleManager { func <name>(...) { result(FlutterMethodNotImplemented) } }` stubs for every routed method so it compiles. Each later task replaces one stub with the real body.

**Verification:** `cd ios && xcodebuild ... build CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED.

**Commit:** `feat(ios-ble): channel registration + full method dispatch skeleton`

---

### Task 3: PayloadCodec.swift — normalization helpers

**Layer:** Foundation

**Files:**
- Create: `ios/Runner/BLE/PayloadCodec.swift`

**Context:** Central place for every QCModel→Android-map conversion + shared numeric/time helpers. Keeping them here (pure functions) makes them unit-testable without a band (Task 24).

**Implementation:**
```swift
import Foundation
import QCBandSDK

enum PayloadCodec {
    /// Android's unixSecondsWithTzOffset(): now + local tz offset, in seconds.
    static func unixSecondsWithTzOffset(_ date: Date = Date()) -> Int {
        let now = Int(date.timeIntervalSince1970)
        let tz = TimeZone.current.secondsFromGMT(for: date)
        return now + tz
    }

    /// Combine two unsigned bytes into a signed Int16 (Android signedInt16()).
    static func signedInt16(high: Int, low: Int) -> Int {
        let combined = ((high & 0xFF) << 8) | (low & 0xFF)
        return combined > 32767 ? combined - 65536 : combined
    }

    /// "yyyy-MM-dd HH:mm:ss" → epoch ms (QCSleepModel.happenDate uses this).
    static func epochMs(from str: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = .current
        return Int((f.date(from: str)?.timeIntervalSince1970 ?? 0) * 1000)
    }

    /// QCSleepModel.type (SLEEPTYPE) → Android type code:
    /// Android: 1=deep, 2=light, 3=wake, 4=rem, 5=no_sleep/no_wear.
    static func sleepTypeCode(_ t: SLEEPTYPE) -> Int {
        switch t {
        case SLEEPTYPEDEEP: return 1
        case SLEEPTYPELIGHT: return 2
        case SLEEPTYPESOBER: return 3
        case SLEEPTYPEREM: return 4
        case SLEEPTYPEUNWEARED: return 5
        default: return 5
        }
    }
}
```

**Verification:** `cd ios && xcodebuild ... build CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED.

**Commit:** `feat(ios-ble): PayloadCodec normalization + time/byte helpers`

---

## Phase 1 — Cardio Load Critical Subset

### Task 4: Connection + CBCentralManagerDelegate

**Layer:** Feature (connection)

**Files:**
- Create: `ios/Runner/BLE/BleManager+Connection.swift`

**Behavior to match (Android):**
- `startScan` → returns `[{id, name, rssi}]` after a 10s scan window.
- `stopScan` → `null`.
- `connect{deviceId}` → optimistic `null`; real state via `onConnected{deviceName}`.
- `disconnect` → `null` + `onDisconnect{deviceName}`.
- `getBattery` → `{level:Int, charging:Bool}` and also fire `onBatteryUpdate{battery, charging}`.
- CB delegate fires `onBleStateChange{state:Int}` (use `central.state.rawValue` to match the int the Dart side already stores), `onConnected`, `onDisconnect`.

**Implementation:**
```swift
import CoreBluetooth
import Flutter
import QCBandSDK

extension BleManager: CBCentralManagerDelegate {
    func startScan(_ result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "ble.bluetooth.off",
                                message: "state=\(centralManager.state.rawValue)", details: nil)); return
        }
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: serviceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            self.centralManager.stopScan()
            let devices = self.discoveredPeripherals.map { (id, p) -> [String: Any] in
                ["id": id, "name": p.name ?? "Unknown", "rssi": -100]
            }
            result(devices)
        }
    }

    func stopScan(_ result: @escaping FlutterResult) { centralManager.stopScan(); result(nil) }

    func connect(_ deviceId: String?, _ result: @escaping FlutterResult) {
        guard let deviceId, let p = discoveredPeripherals[deviceId] else {
            result(FlutterError(code: "ble.connect.not_found", message: "not in scan cache", details: nil)); return
        }
        pendingConnectResult = result
        QCCentralManager.shared().connect(p, timeout: 15, deviceType: .ring)
    }

    func disconnect(_ result: @escaping FlutterResult) {
        QCCentralManager.shared().remove()
        connectedPeripheral = nil
        result(nil)
        callDart("onDisconnect", ["deviceName": connectedDeviceName])
        connectedDeviceName = ""
    }

    func getBattery(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.readBatterySuccess({ [weak self] battery, charging in
            let payload: [String: Any] = ["level": Int(battery), "charging": charging]
            result(payload)
            self?.callDart("onBatteryUpdate", ["battery": Int(battery), "charging": charging])
        }, failed: { result(FlutterError(code: "sdk.error.unknown", message: "battery read failed", details: nil)) })
    }

    // MARK: CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        callDart("onBleStateChange", ["state": central.state.rawValue])
    }
    public func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                               advertisementData: [String: Any], rssi: NSNumber) {
        discoveredPeripherals[p.identifier.uuidString] = p
    }
    public func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        connectedPeripheral = p
        connectedDeviceName = p.name ?? "HLTH"
        QCSDKManager.shareInstance().add(p) { [weak self] success in
            guard let self else { return }
            if success {
                self.pendingConnectResult?(nil)
                self.runConnectBootstrap()         // Task 5
                self.callDart("onConnected", ["deviceName": self.connectedDeviceName])
                self.startPeriodicTimer()           // Task 10
            } else {
                self.pendingConnectResult?(FlutterError(code: "SDK_ADD_FAILED", message: "bind failed", details: nil))
            }
            self.pendingConnectResult = nil
        }
    }
    public func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        pendingConnectResult?(FlutterError(code: "ble.connect.timeout", message: error?.localizedDescription ?? "", details: nil))
        pendingConnectResult = nil
    }
    public func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        stopPeriodicTimer()
        callDart("onDisconnect", ["deviceName": connectedDeviceName])
    }
    public func centralManager(_ c: CBCentralManager, willRestoreState dict: [String: Any]) {
        // Implemented in Task 12.
    }
}
```
> Adjust `QCCentralManager`/`QCSDKManager.add` to the exact demo API (`QCCentralManager.m` shows `connect:timeout:deviceType:` and `QCSDKManager.shareInstance().addPeripheral`). Verify the binding method name against the framework header before finalizing.

**Verification:** simulator build SUCCEEDED. On-device: scan finds the H59, `connect` → `onConnected` fires, battery returns a number.

**Commit:** `feat(ios-ble): scan/connect/disconnect/battery + CB delegate callbacks`

---

### Task 5: Connect bootstrap + setPersonalInfo + setScheduledMonitoring + getScheduledHr

**Layer:** Feature (config — the data enablers)

**Files:**
- Create: `ios/Runner/BLE/BleManager+Config.swift`

**Context:** The H59 is dormant until scheduled monitoring is enabled and time/profile are set. `runConnectBootstrap()` mirrors Android's post-connect sequence (setTime → it returns the feature list). Cardio Load needs HR+HRV+stress+sleep recording on.

**Behavior to match (Android):**
- `setPersonalInfo{is24h, metric, isMale, age, heightCm, weightKg, baselineSbp, baselineDbp, hrWarnHigh}` → `{set:Bool}`. iOS: `setTimeFormatTwentyfourHourFormat:metricSystem:gender:age:height:weight:sbpBase:dbpBase:hrAlarmValue:` (gender 0=male,1=female → `isMale ? 0 : 1`).
- `setScheduledMonitoring{hrInterval, spo2Interval, hrvInterval, bpIntervalMinutes, startInterval}` → echo the intervals back. iOS calls: `setSchedualHeartRateStatus:timeInterval:`, `setSchedualBOInfoOn:timeInterval:`, `setSchedualHRVStatus:`, `setSchedualBPInfoOn:beginTime:endTime:minuteInterval:` (00:00–23:59), `setSchedualStressStatus:`.
- `getScheduledHr` → `{isEnable, heartInterval, startInterval, mainSwitch, tooLowReminder, tooHighReminder}` via `getSchedualHeartRateInfoWithSuccess:` (enable, interval, minInterval, minHrTip, maxHrTip → map to the keys; fill missing with 0).

**Implementation (key parts):**
```swift
import Flutter
import QCBandSDK

extension BleManager {
    func runConnectBootstrap() {
        QCSDKCmdCreator.setTime(Date(), success: { _ in /* feature list available if needed */ },
                                failed: {})
    }

    func setPersonalInfo(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let isMale = a["isMale"] as? Bool ?? true
        QCSDKCmdCreator.setTimeFormatTwentyfourHourFormat(
            a["is24h"] as? Bool ?? true,
            metricSystem: a["metric"] as? Bool ?? true,
            gender: isMale ? 0 : 1,
            age: a["age"] as? Int ?? 30,
            height: a["heightCm"] as? Int ?? 170,
            weight: a["weightKg"] as? Int ?? 70,
            sbpBase: a["baselineSbp"] as? Int ?? 0,
            dbpBase: a["baselineDbp"] as? Int ?? 0,
            hrAlarmValue: a["hrWarnHigh"] as? Int ?? 0,
            success: { _,_,_,_,_,_,_,_,_ in result(["set": true]) },
            fail: { result(["set": false]) })
    }

    func setScheduledMonitoring(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let hr = a["hrInterval"] as? Int ?? 10
        let spo2 = a["spo2Interval"] as? Int ?? 60
        let hrv = a["hrvInterval"] as? Int ?? 30
        let bp = a["bpIntervalMinutes"] as? Int ?? 60
        QCSDKCmdCreator.setSchedualHeartRateStatus(true, timeInterval: hr, success: {}, fail: {})
        QCSDKCmdCreator.setSchedualBOInfoOn(true, timeInterval: spo2, success: {}, fail: {})
        QCSDKCmdCreator.setSchedualHRVStatus(true, finshed: { _ in })
        QCSDKCmdCreator.setSchedualBPInfoOn(true, beginTime: "00:00", endTime: "23:59",
                                            minuteInterval: bp, success: { _,_,_,_ in }, fail: {})
        QCSDKCmdCreator.setSchedualStressStatus(true, finshed: { _ in })
        // Echo intervals back like Android (read-backs optional on iOS — SDK acks are reliable here).
        result(["hrInterval": hr, "startInterval": a["startInterval"] as? Int ?? 5,
                "spo2Interval": spo2, "hrvInterval": hrv, "bpIntervalMinutes": bp])
    }

    func getScheduledHr(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualHeartRateInfo(success: { enable, interval, minInterval, minTip, maxTip in
            result(["isEnable": enable, "heartInterval": interval, "startInterval": minInterval,
                    "mainSwitch": enable ? 1 : 0, "tooLowReminder": minTip, "tooHighReminder": maxTip])
        }, fail: { result(["isEnable": false, "heartInterval": 0, "startInterval": 0,
                           "mainSwitch": 0, "tooLowReminder": 0, "tooHighReminder": 0]) })
    }
}
```
> Verify exact Swift-bridged selector names (`getSchedualHeartRateInfo(success:fail:)`) against the framework; the reference lists the Obj-C signatures.

**Verification:** simulator build SUCCEEDED. On-device: `setScheduledMonitoring` returns intervals; wearing the ring 30+ min then syncing yields non-empty history (Tasks 6–9).

**Commit:** `feat(ios-ble): connect bootstrap + personal info + scheduled monitoring`

---

### Task 6: getSleepHistory (QCSleepModel → Android shape) — the linchpin

**Layer:** Feature (history)

**Files:**
- Create: `ios/Runner/BLE/BleManager+History.swift`
- Modify: `ios/Runner/BLE/PayloadCodec.swift` (add `sleepPayload`)

**Android target payload:**
```
{ totalSleepDuration:Int(sec), deepDuration, shallowDuration, awakeDuration,
  rapidDuration, sleepTime:Int, wakeTime:Int, wakingCount:Int,
  stages:[ {sleepStart:Int(ms), sleepEnd:Int(ms), type:Int} ] }
```
iOS source: `getSleepDetailDataByDay:` → `[QCSleepModel]` (`type`, `happenDate`, `endTime`, `total` minutes). Build stages from each model; aggregate the duration buckets by `sleepTypeCode`.

**Implementation:**
```swift
extension PayloadCodec {
    static func sleepPayload(_ models: [QCSleepModel]) -> [String: Any] {
        var stages: [[String: Any]] = []
        var deep = 0, light = 0, rem = 0, awake = 0
        var minStart = Int.max, maxEnd = 0, wakingCount = 0
        for m in models {
            let start = epochMs(from: m.happenDate)
            let end = epochMs(from: m.endTime)
            let code = sleepTypeCode(m.type)
            stages.append(["sleepStart": start, "sleepEnd": end, "type": code])
            let sec = Int(m.total) * 60
            switch code { case 1: deep += sec; case 2: light += sec
                          case 4: rem += sec; case 3: awake += sec; wakingCount += 1; default: break }
            minStart = min(minStart, start); maxEnd = max(maxEnd, end)
        }
        let total = deep + light + rem // asleep only, matching Android's totalSleepDuration intent
        return ["totalSleepDuration": total, "deepDuration": deep, "shallowDuration": light,
                "awakeDuration": awake, "rapidDuration": rem,
                "sleepTime": minStart == Int.max ? 0 : minStart / 1000,
                "wakeTime": maxEnd / 1000, "wakingCount": wakingCount, "stages": stages]
    }
}

extension BleManager {
    func getSleepHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSleepDetailData(byDay: dayOffset, sleepDatas: { models in
            result(PayloadCodec.sleepPayload(models ?? []))
        }, fail: { result(PayloadCodec.sleepPayload([])) })
    }
}
```
> **Validation owed:** confirm the Dart `sync_adapters` sleep parser consumes these exact keys (it was written against the Android shape). Cross-check `lib/core/ble/sync_adapters.dart` sleep mapping before claiming done.

**Verification:** `flutter test test/sync_adapters*` still green (proves shape parity if such a test exists). On-device: a synced night yields stages + durations.

**Commit:** `feat(ios-ble): getSleepHistory with QCSleepModel→Android normalization`

---

### Task 7: getHrHistory (QCSchedualHeartRateModel → readings/rawArray)

**Layer:** Feature (history)

**Files:** Modify `BleManager+History.swift`, `PayloadCodec.swift`.

**Android target payload:**
```
{ endFlag:Bool, index:Int, size:Int, utcTime:Int,
  readings:[ {timestamp_ms:Int, bpm:Int, slot:Int} ],   // zero slots filtered out
  rawArray:[Int] }
```
iOS source: `getSchedualHeartRateDataWithDayIndexs:[@(dayOffset)]` → `[QCSchedualHeartRateModel]` (`.heartRates:[NSNumber]`, `.secondInterval`, `.date`). Slot i → `timestamp_ms = dayStartMs + i*secondInterval*1000`; drop bpm==0.

**Implementation sketch:**
```swift
func getHrHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
    QCSDKCmdCreator.getSchedualHeartRateData(withDayIndexs: [NSNumber(value: dayOffset)], success: { models in
        guard let m = models?.first else { result(PayloadCodec.emptyHr()); return }
        result(PayloadCodec.hrPayload(m)); }, fail: { result(PayloadCodec.emptyHr()) })
}
```
`PayloadCodec.hrPayload`: compute day-start epoch from `m.date` (yyyy-MM-dd, local), iterate `m.heartRates`, emit `readings` (non-zero) + `rawArray` (all, as Int 0-255), `utcTime`=dayStart, `size`=count, `index`=0, `endFlag`=true.

**Verification:** simulator build; on-device non-empty `readings` after wear.

**Commit:** `feat(ios-ble): getHrHistory normalization`

---

### Task 8: getHrvHistory (QCHRVModel → values/rawArray, NO ÷10)

**Layer:** Feature (history)

**Files:** Modify `BleManager+History.swift`, `PayloadCodec.swift`.

**Android target payload:** `{ values:[Double], intervalMinutes:Int, rawArray:[Int] }` — raw bytes **are** RMSSD ms; do **NOT** divide by 10.

iOS source: `getSchedualHRVDataWithDates:` → `[QCHRVModel]` (`.hrv:[NSNumber]`, `.secondInterval`). Convert dayOffset→NSDate. `intervalMinutes = secondInterval/60`. `values` = hrv as Double, `rawArray` = same as Int.

**Implementation sketch:**
```swift
func getHrvHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
    let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
    QCSDKCmdCreator.getSchedualHRVData(withDates: [date], finished: { models, _ in
        let m = (models as? [QCHRVModel])?.first
        let raw = (m?.hrv ?? []).map { $0.intValue }
        result(["values": raw.map { Double($0) },
                "intervalMinutes": (m?.secondInterval ?? 1800) / 60,
                "rawArray": raw]) })
}
```
> The `withDates:` arg type per header is `NSArray<NSNumber*>` (day indexes) despite the name — verify whether it wants day-index numbers or NSDate, and match. Document which the H59 accepts.

**Verification:** on-device values look like 20–80 (ms), not 2–8.

**Commit:** `feat(ios-ble): getHrvHistory normalization (no /10)`

---

### Task 9: getStressDay (QCStressModel → values/rawArray)

**Layer:** Feature (history)

**Files:** Modify `BleManager+History.swift`.

**Android target payload:** `{ values:[Int 0-100], intervalMinutes:Int, offset:Int, zeroTimeMs:Int?, rawArray:[Int] }`.

iOS source: `getSchedualStressDataWithDates:` → `[QCStressModel]` (`.stresses`, `.secondInterval`).

**Implementation sketch:** map `stresses`→Int values + rawArray; `intervalMinutes = secondInterval/60`; `offset:0`; `zeroTimeMs`: day-start epoch ms.

**Verification:** on-device non-empty after stress monitoring on + wear.

**Commit:** `feat(ios-ble): getStressDay normalization`

---

### Task 10: Periodic sync tick (foreground Timer) + setSyncIntervalMinutes/get

**Layer:** Feature (sync scheduling)

**Files:** Create `ios/Runner/BLE/BleManager+Background.swift` (timer part; BG parts in Phase 2).

**Behavior to match (Android):** first tick `interval` after connect, then every interval; clamp 5–60; `onPeriodicSyncTick{intervalMin}`. `setSyncIntervalMinutes{minutes}` → `{minutes(clamped), clamped:Bool}`; reschedule if connected.

**Implementation:**
```swift
extension BleManager {
    func startPeriodicTimer() {
        stopPeriodicTimer()
        let interval = TimeInterval(syncIntervalMinutes * 60)
        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.callDart("onPeriodicSyncTick", ["intervalMin": self.syncIntervalMinutes])
        }
    }
    func stopPeriodicTimer() { periodicTimer?.invalidate(); periodicTimer = nil }

    func setSyncIntervalMinutes(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let req = a["minutes"] as? Int ?? 30
        let clamped = min(60, max(5, req))
        syncIntervalMinutes = clamped
        if connectedPeripheral != nil { startPeriodicTimer() }
        result(["minutes": clamped, "clamped": clamped != req])
    }
}
```

**Verification:** on-device, leave app open → tick fires every interval → `SyncService.syncAll` runs (watch logs).

**Commit:** `feat(ios-ble): foreground periodic-sync tick + interval control`

---

### Task 11: Device-initiated events → onDeviceNotify / onRealtimeHeartRate

**Layer:** Feature (events)

**Files:** Create `ios/Runner/BLE/BleManager+Events.swift`.

**Behavior to match (Android):** `onDeviceNotify{dataType:Int, loadData:[Int]}` with codes 1=HR,2=BP,3=SpO2,4=steps,5=temp,7=exercise,0x0c=charging; plus `onRealtimeHeartRate{bpm}`. iOS source: `QCSDKManager.shareInstance().watchDataUpdateReport` (`QCDeviceDataUpdateReport` enum → map to Android dataType codes) and `OdmBandNotifyCenter` notifications (`OdmBandRealTimeHeartRate`, `QCBandBatteryNotification`, etc.).

**Implementation sketch:**
```swift
extension BleManager {
    func registerDeviceEventObservers() {
        let sdk = QCSDKManager.shareInstance()
        sdk.watchDataUpdateReport = { [weak self] type, value in
            self?.callDart("onDeviceNotify", ["dataType": Self.mapUpdateType(type), "loadData": [value]])
        }
        sdk.currentBatteryInfo = { [weak self] battery, charging in
            self?.callDart("onBatteryUpdate", ["battery": Int(battery), "charging": charging])
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name(OdmBandRealTimeHeartRate),
            object: nil, queue: .main) { [weak self] note in
            if let hr = (note.userInfo?["value"] as? NSNumber)?.intValue, hr > 0 {
                self?.callDart("onRealtimeHeartRate", ["bpm": hr])
            }
        }
    }
    static func mapUpdateType(_ t: QCDeviceDataUpdateReport) -> Int {
        switch t { case .heartRate: return 1; case .bloodPressure: return 2; case .bloodOxygen: return 3
                   case .step, .stepInfo: return 4; case .temperature: return 5; case .sportRecord: return 7
                   case .power, .lowPower: return 0x0c; default: return 0 }
    }
}
```
> Confirm the exact userInfo key for HR notifications from `OdmBandNotifyCenter.h` (the reference lists keys but not the HR value key — inspect at runtime if unclear).

**Verification:** on-device, band HR notifications surface as `onRealtimeHeartRate`; the home HR card updates.

**Commit:** `feat(ios-ble): device-initiated events (onDeviceNotify/onRealtimeHeartRate)`

---

### ✅ Phase 1 Checkpoint

```bash
cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
cd .. && flutter test                # Dart unchanged → still green
```
Then **on the iPhone** (Task 25 mini-run): pair → `setScheduledMonitoring` → wear → BLE Debug "Scores" → confirm a `nightly_records` row writes with sane `hrP5`. **Do not start Phase 3 until this passes.**

---

## Phase 2 — Background Parity

### Task 12: CoreBluetooth state restoration

**Files:** Modify `BleManager.swift` (init options + `willRestoreState`), `ios/Runner/AppDelegate.swift`.

**Implementation:**
- Init central with `[CBCentralManagerOptionRestoreIdentifierKey: "HLTHBluetoothRestore", CBCentralManagerOptionShowPowerAlertKey: true]`.
- Implement `centralManager(_:willRestoreState:)` → re-grab `[CBPeripheral]` from `dict[CBCentralManagerRestoredStatePeripheralsKey]`, set `connectedPeripheral`, re-`add` to QCSDKManager.
- In `AppDelegate.application(_:didFinishLaunchingWithOptions:)` handle the `.bluetoothCentrals` launch option key (touch `BleManager.shared` early so the singleton exists before restoration).

**Commit:** `feat(ios-ble): CoreBluetooth state restoration`

### Task 13: Background mode + Info.plist + entitlements

**Files:** Modify `ios/Runner/Info.plist`, add/modify `ios/Runner/Runner.entitlements`.

**Implementation:**
- Info.plist: `UIBackgroundModes = [bluetooth-central, processing]`; `NSBluetoothAlwaysUsageDescription`; `BGTaskSchedulerPermittedIdentifiers = [com.hlth.hlthApp.sync]`.
- Verify the Runner target references the entitlements file.

**Commit:** `chore(ios): background BLE modes + bluetooth usage description`

### Task 14: BGTaskScheduler-driven tick when suspended

**Files:** Modify `BleManager+Background.swift`, `AppDelegate.swift`.

**Implementation:**
- Register `BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.hlth.hlthApp.sync", ...)` in `didFinishLaunchingWithOptions`.
- On `applicationDidEnterBackground`, submit a `BGProcessingTaskRequest` with `earliestBeginDate = now + interval`.
- Task handler: fire `onPeriodicSyncTick`, then reschedule. Foreground `Timer` (Task 10) covers active use.

> Caveat to document in code: iOS dictates timing; this is best-effort, validated only by multi-night runs.

**Commit:** `feat(ios-ble): BGTaskScheduler background sync tick`

---

## Phase 3 — Remaining Methods (Full Parity)

Each follows the Task 6–9 pattern: SDK call → `PayloadCodec` normalizer → exact Android map. Where the iOS SDK can't match, return the same shape with empty/zero data (never throw) so Dart is untouched.

### Task 15: setBpScheduled/getBpScheduled, setStressScheduled/getStressScheduled
- `setBpScheduled{enabled,intervalMinutes,startHour,startMinute,endHour,endMinute}` → `{isEnable, intervalMinutes}` via `setSchedualBPInfoOn:beginTime:endTime:minuteInterval:` (format "HH:mm").
- `getBpScheduled` → `{isEnable, intervalMinutes, startHour, startMinute, endHour, endMinute}` via `getSchedualBPInfo:` (parse begin/end "HH:mm").
- `setStressScheduled{enabled}`→`{isEnable}`; `getStressScheduled`→`{isEnable}` via `setSchedualStressStatus:`/`getSchedualStressStatusWithFinshed:`.
**Commit:** `feat(ios-ble): BP + stress scheduled config`

### Task 16: SpO2 history suite
- `getSpO2Day{dayOffset}` → `[{dateStr, unixTime, minArray[24], maxArray[24]}]` via `getBloodOxygenDataByDayIndex:` (`QCBloodOxygenModel` → hourly min/max).
- `getSpO2History` → all days (loop or range API).
- `getSpO2Interval{dayOffset}` → `{samples, total, nonZero, min, max, timedOut}` via `getBloodOxygenDataWithIntervalByDayIndex:` (8s timeout → `timedOut:true`).
- `getSpO2Capability` → `{ok, supportIntervalBloodOxygen, supportIntervalHeartRate, supportIntervalTemperature, timedOut}` from the `setTime` feature list (`QCBandFeature*Interval`).
- `enableSpO2Interval{enable,intervalMinutes}` → `{ok, isEnable, interval, timedOut}` via `setSchedualBOInfoOn:timeInterval:` + read-back.
**Commit:** `feat(ios-ble): SpO2 day/history/interval/capability`

### Task 17: BP history
- `getBpDay{dayOffset}` → `{readings:[{time:Int(minOfDay), sbp, dbp}]}` via `getSchedualBPHistoryDataWithUserAge:` / manual (`QCBloodPressureModel`).
- `getBpHistory` → `{year, month, day, timeDelay, readings:[{timeMinute, hr}]}` (legacy; can return empty `readings` on iOS — document as a known no-op, same as H59 Android).
**Commit:** `feat(ios-ble): BP day + legacy history`

### Task 18: Steps
- `getDailyTotals` → `{year, month, day, daysAgo, totalSteps, runningSteps, calorie, walkDistance, sportDurationSec, sleepDurationSec}` via `getCurrentSportSucess:`/`getOneDaySportBy:` (`QCSportModel`).
- `getStepBucketHistory{dayOffset}` / `getStepDay{dayOffset}` → 96×`{year,month,day,timeIndex,walkSteps,runSteps,calorie,distance}` via `getSportDetailDataByDay:minuteInterval:beginIndex:endIndex:` (15-min bins).
**Commit:** `feat(ios-ble): step totals + detail buckets`

### Task 19: Manual streams (HR/SpO2/HRV)
- `wireMeasurementCallbacks()`: set `hrMeasuring`/`boMeasuring`/`bpMeasuring` blocks + `OdmBandRealTimeHRV`/`OdmBandRealTimeSO2`/`OdmBandRealTimeStress` observers → `onHeartStream{hr}`, `onSpo2Stream{spo2,hr}`, `onHrvStream{hrv,hr,stress}`, plus `onHeartRateMeasured`/`onSpo2Measured`/`onBloodPressureMeasured`.
- `startHeartStream`→`startToMeasuringWithOperateType:QCMeasuringTypeHeartRate` (+guard flag) → `{started:Bool}`; stop → `stopToMeasuring...` → `{stopped:Bool}`. Same for SpO2 (`QCMeasuringTypeBloodOxygen`) and HRV (`QCMeasuringTypeHRV`).
**Commit:** `feat(ios-ble): manual HR/SpO2/HRV measurement streams`

### Task 20: BP measurement
- `startBpMeasurement`→`QCMeasuringTypeBloodPressue`; `completedHandle` result → `{sbp, dbp, hr, errCode}`; stop → `{stopped}`.
**Commit:** `feat(ios-ble): on-demand BP measurement`

### Task 21: One Key Measurement (real, iOS may beat Android)
- `startOneKeyMeasurement`→`QCMeasuringTypeOneKeyMeasure`; observe `OdmBandRealOneKeyMeasureHeartRate` (`QCRealOneKeyMeasureHeartRateModel`) → `onOneKeyMeasurementStream{hr, spo2, sbp, dbp, fatigue, score}` (map `heartRateValue/bloodPressureSbp/Dbp`; `spo2` may be 0 if not in model, `fatigue/score`→0 unless available); `{started}`/`{stopped}`.
**Commit:** `feat(ios-ble): one-key measurement stream`

### Task 22: Raw PPG (HR + SpO2) → realtime_stream
- `startMeasureHrRaw{duration_sec}`→`QCMeasuringTypeHeartRateRaw`; in the `OdmBandRealTimePPGNotification` observer, build per-sample maps `{timestamp_ms, ppg_count, green, red, infrared, heart, rri, hrv, accel_x, accel_y, accel_z}` using `PayloadCodec.signedInt16` for accel (Odm*L/H keys) and emit on `ppgEventSink` as a single-element list. `{started, seconds}`; stop → `null`. SpO2 raw = `QCMeasuringTypeBloodOxygenRaw`.
> `green` may be absent in iOS keys (reference lists red/IR + accel only) — emit `green:0` if so and document. Raw morphology is sensor-blocked regardless.
**Commit:** `feat(ios-ble): raw PPG/SpO2 streaming`

### Task 23: Sport mode
- `sendSportStatus(status, sportType)` → there is no direct `PhoneSportReq` equivalent in the iOS header set; use the nearest exercise-control API or, if genuinely absent, return `{status, sportType, gpsStatus:0, timestamp:0}` as a no-op ack and log the gap. `syncSportSessions`→`getSportRecordsFromLastTimeStamp:`/`getExerciseDataWithLastUnixSeconds:` (`QCExerciseModel`) → `{sessions:[...]}` mapped to the Android summary keys.
> **Known SDK gap:** sport-mode start/stop control may not exist on iOS QCBandSDK. Flag to Ryan; the no-op ack keeps Dart unchanged.
**Commit:** `feat(ios-ble): sport mode + session sync (with documented gaps)`

---

## Phase 4 — Verification

### Task 24: PayloadCodec native unit tests

**Layer:** Test (Priority 1 — most correctness lives here, no hardware needed)

**Files:** Create `ios/RunnerTests/PayloadCodecTests.swift`.

**Implementation:** Feed canned `QCSleepModel`/`QCHRVModel`/`QCStressModel`/`QCSchedualHeartRateModel` fixtures + raw-PPG byte pairs; assert emitted maps equal the Android shape (keys, types, units) — e.g. `sleepTypeCode(SLEEPTYPEDEEP)==1`, HRV not divided by 10, `signedInt16(high:0xFF,low:0xFE)==-2`.

**Verification:**
```bash
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
# Expected: Test Suite 'PayloadCodecTests' passed
```
**Commit:** `test(ios-ble): PayloadCodec shape-parity unit tests`

### Task 25: On-device acceptance

**Layer:** Test (Priority 3 — hardware)

Run on the iPhone + H59:
1. Pair → `setPersonalInfo` + `setScheduledMonitoring` → wear ≥30 min.
2. BLE Debug "Scores" → confirm `nightly_records` row + sane `hrP5` < daytime resting HR (Cardio Load parity with Android).
3. Multi-night: confirm background tick fires overnight (Task 14) and Cardio Load accumulates.
4. Spot-check the remaining methods via the BLE Debug buttons (BP, SpO2, steps, sport).

No commit (manual). Record results in this file's notes.

---

## Notes / open items for Ryan
- iOS sport-mode start/stop control may be absent in QCBandSDK (Task 23) — confirm whether iOS workout sessions are required for V1.
- HRV `withDates:` arg semantics (day index vs NSDate) — verify on H59.
- Raw PPG `green` channel availability on iOS (Task 22) — likely moot (sensor-blocked).
