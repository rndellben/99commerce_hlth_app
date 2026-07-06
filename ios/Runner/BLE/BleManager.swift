//
//  BleManager.swift
//  Runner
//
//  Bridges CoreBluetooth + QCBandSDK to the Flutter platform channels:
//    - MethodChannel  "hlth/ble"                  (method calls + Dart callbacks)
//    - EventChannel   "hlth/realtime_stream"       (raw PPG)
//    - EventChannel   "hlth/realtime_stream_accel" (raw accelerometer)
//
//  This is the Phase 0 core (Task 2): singleton, channel registration, the full
//  method-dispatch switch, the main-thread callDart helper, and SinkStreamHandler.
//
//  Feature method bodies live in extensions implemented by later tasks. Until
//  those land, every routed method has a temporary stub below (see the
//  "// MARK: - Temporary stubs" section) so the project always compiles.
//

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
    // {id: {id,name,rssi}} for the scan result returned to Dart. Built in
    // didDiscover (name resolved from advertisement local name) so we return
    // real names/RSSI instead of placeholders.
    var scanResults: [String: [String: Any]] = [:]
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

// MARK: - Temporary stubs (replaced by later tasks)
//
// Every method routed by the dispatch switch above is implemented in a later
// task as an `extension BleManager` method in a dedicated file. Until then,
// these stubs keep the project compiling. As each real implementation lands,
// delete the matching stub here.

extension BleManager {
    // --- Connection (Task 4) ---
    // startScan/stopScan/connect/disconnect/getBattery now live in
    // BleManager+Connection.swift.

    // --- Config (Task 5, 15) ---
    // setPersonalInfo/setScheduledMonitoring/getScheduledHr now live in
    // BleManager+Config.swift (Task 5).
    func setBpScheduled(_ a: [String: Any], _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getBpScheduled(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func setStressScheduled(_ a: [String: Any], _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getStressScheduled(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    // setSyncIntervalMinutes now lives in BleManager+Background.swift (Task 10).

    // --- History (Task 6–9, 16–18) ---
    // getSleepHistory/getHrHistory/getHrvHistory/getStressDay now live in
    // BleManager+History.swift (Tasks 6–9).
    func getSpO2Day(_ dayOffset: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getSpO2History(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getSpO2Interval(_ dayOffset: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getSpO2Capability(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func enableSpO2Interval(_ a: [String: Any], _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getBpDay(_ dayOffset: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getBpHistory(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getDailyTotals(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getStepBucketHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func getStepDay(_ dayOffset: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }

    // --- Measurement (Task 19–21) ---
    func startHeartStream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopHeartStream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func startSpo2Stream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopSpo2Stream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func startHrvStream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopHrvStream(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func startBpMeasurement(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopBpMeasurement(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func startOneKeyMeasurement(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopOneKeyMeasurement(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }

    // --- Raw PPG (Task 22) ---
    func startMeasureHrRaw(_ duration: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopMeasureRaw(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func startMeasureSpo2Raw(_ duration: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func stopMeasureSpo2Raw(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }

    // --- Sport (Task 23) ---
    func sendSportStatus(_ status: Int, _ sportType: Int, _ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }
    func syncSportSessions(_ result: @escaping FlutterResult) { result(FlutterMethodNotImplemented) }

    // --- Void callback-wiring / lifecycle no-ops ---
    func wireMeasurementCallbacks() {}      // Task 19/20/21
    // registerDeviceEventObservers() now lives in BleManager+Events.swift (Task 11).
    // startPeriodicTimer()/stopPeriodicTimer() now live in BleManager+Background.swift (Task 10).
    // runConnectBootstrap() now lives in BleManager+Config.swift (Task 5).
}

// MARK: - CBCentralManagerDelegate
//
// The init passes `self` as the central's delegate, so the class must conform.
// The full delegate + scan/connect/disconnect/battery live in
// BleManager+Connection.swift (Task 4).
