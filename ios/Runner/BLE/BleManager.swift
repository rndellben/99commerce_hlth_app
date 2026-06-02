//
//  BleManager.swift
//  Runner
//
//  Bridges CoreBluetooth + QCBandSDK to the Flutter MethodChannel
//  com.hlth.hlth_app/ble and EventChannels com.hlth.hlth_app/ppg_stream
//  and com.hlth.hlth_app/accel_stream.
//
//  Phase 0 scaffold — covers scan / connect / disconnect, plus stubs for
//  PPG streaming and one-shot measurements (HR, SpO2, sleep). Real PPG
//  streaming requires QCMeasuringTypeHeartRateRaw + parsing the raw
//  callback payload from QCSDKManager.
//

import Foundation
import CoreBluetooth
import Flutter
import QCBandSDK

final class BleManager: NSObject {

    static let shared = BleManager()

    // Method channel for request/response calls
    private var methodChannel: FlutterMethodChannel?
    // Event channels for streaming data to Dart
    private var ppgEventSink: FlutterEventSink?
    private var accelEventSink: FlutterEventSink?

    // CoreBluetooth
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var pendingScanResult: FlutterResult?
    private var pendingConnectResult: FlutterResult?

    // Service UUIDs the QCBandSDK uses to identify bands
    private lazy var serviceUUIDs: [CBUUID] = [
        CBUUID(string: QCBANDSDKSERVERUUID1),
        CBUUID(string: QCBANDSDKSERVERUUID2)
    ]

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        wireQCSDKCallbacks()
    }

    // MARK: - Flutter registration

    func register(with messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.hlth.hlth_app/ble",
            binaryMessenger: messenger
        )
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }

        FlutterEventChannel(name: "com.hlth.hlth_app/ppg_stream", binaryMessenger: messenger)
            .setStreamHandler(PpgStreamHandler { [weak self] sink in
                self?.ppgEventSink = sink
            })

        FlutterEventChannel(name: "com.hlth.hlth_app/accel_stream", binaryMessenger: messenger)
            .setStreamHandler(AccelStreamHandler { [weak self] sink in
                self?.accelEventSink = sink
            })
    }

    // MARK: - QCSDK callback wiring

    private func wireQCSDKCallbacks() {
        let sdk = QCSDKManager.shareInstance()
        sdk.realTimeHeartRate = { [weak self] hr in
            self?.methodChannel?.invokeMethod("onRealtimeHeartRate", arguments: ["bpm": hr])
        }
        sdk.hrMeasuring = { [weak self] hr in
            self?.methodChannel?.invokeMethod("onHeartRateMeasured", arguments: ["bpm": hr])
        }
        sdk.boMeasuring = { [weak self] so2 in
            self?.methodChannel?.invokeMethod("onSpo2Measured", arguments: ["spo2": so2])
        }
        sdk.bpMeasuring = { [weak self] sbp, dbp in
            self?.methodChannel?.invokeMethod(
                "onBloodPressureMeasured",
                arguments: ["sbp": sbp, "dbp": dbp]
            )
        }
        sdk.currentBatteryInfo = { [weak self] battery, charging in
            self?.methodChannel?.invokeMethod(
                "onBatteryUpdate",
                arguments: ["battery": battery, "charging": charging]
            )
        }
    }

    // MARK: - MethodChannel dispatch

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scan":
            startScan(result: result)
        case "stopScan":
            stopScan(result: result)
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "deviceId required", details: nil))
                return
            }
            connect(deviceId: deviceId, result: result)
        case "disconnect":
            disconnect(result: result)
        case "startPPGStream":
            startPpgStream(result: result)
        case "stopPPGStream":
            stopPpgStream(result: result)
        case "getHeartRate":
            measure(.heartRate, result: result)
        case "getSpO2":
            measure(.bloodOxygen, result: result)
        case "getSleepData":
            // Sleep data isn't a real-time measurement — placeholder until
            // we wire QCSDKCmdCreator query commands.
            result([:])
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Scan

    private func startScan(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(
                code: "BLE_OFF",
                message: "Bluetooth is not powered on (state=\(centralManager.state.rawValue))",
                details: nil
            ))
            return
        }
        discoveredPeripherals.removeAll()
        pendingScanResult = result

        // Scan with the band service filter for fast pairing; remove the filter
        // here if the band advertises with a different primary service.
        centralManager.scanForPeripherals(
            withServices: serviceUUIDs,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop after 10s and return what we found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, self.pendingScanResult != nil else { return }
            self.centralManager.stopScan()
            let devices = self.discoveredPeripherals.values.map { p in
                [
                    "id": p.identifier.uuidString,
                    "name": p.name ?? "Unknown",
                    "rssi": -100
                ]
            }
            self.pendingScanResult?(devices)
            self.pendingScanResult = nil
        }
    }

    private func stopScan(result: @escaping FlutterResult) {
        centralManager.stopScan()
        result(nil)
    }

    // MARK: - Connect

    private func connect(deviceId: String, result: @escaping FlutterResult) {
        guard let peripheral = discoveredPeripherals[deviceId] else {
            result(FlutterError(code: "UNKNOWN_DEVICE", message: "Device not in scan cache", details: nil))
            return
        }
        pendingConnectResult = result
        centralManager.connect(peripheral, options: nil)
    }

    private func disconnect(result: @escaping FlutterResult) {
        if let p = connectedPeripheral {
            QCSDKManager.shareInstance().removePeripheral(p)
            centralManager.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        result(nil)
    }

    // MARK: - Measurement

    private func measure(_ type: QCMeasuringType, result: @escaping FlutterResult) {
        QCSDKManager.shareInstance().startToMeasuring(
            withOperateType: type,
            measuringHandle: { _ in
                // Real-time tick — delivered via the wired callback blocks above
            },
            completedHandle: { isSuccess, payload, error in
                if isSuccess {
                    result(["success": true, "payload": String(describing: payload ?? "")])
                } else {
                    result(FlutterError(
                        code: "MEASURE_FAILED",
                        message: error?.localizedDescription ?? "Unknown",
                        details: nil
                    ))
                }
            }
        )
    }

    // MARK: - PPG streaming (raw heart rate channel)

    private func startPpgStream(result: @escaping FlutterResult) {
        // QCMeasuringTypeHeartRateRaw delivers PPG samples through the
        // measuringHandle block. Real implementation will parse the payload
        // (typically NSArray of UInt16 samples) and forward to ppgEventSink.
        QCSDKManager.shareInstance().startToMeasuring(
            withOperateType: .heartRateRaw,
            measuringHandle: { [weak self] payload in
                guard let sink = self?.ppgEventSink else { return }
                // TODO: parse payload into [{ts, green, red}] PpgSample maps.
                // Shape must match PpgSample.fromMap in Dart.
                sink([["ts": Int(Date().timeIntervalSince1970 * 1000), "raw": String(describing: payload ?? "")]])
            },
            completedHandle: { _, _, _ in }
        )
        result(nil)
    }

    private func stopPpgStream(result: @escaping FlutterResult) {
        QCSDKManager.shareInstance().stopToMeasuring(
            withOperateType: .heartRateRaw,
            completedHandle: { _, _ in }
        )
        result(nil)
    }
}

// MARK: - CBCentralManagerDelegate

extension BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        methodChannel?.invokeMethod(
            "onBleStateChange",
            arguments: ["state": central.state.rawValue]
        )
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        discoveredPeripherals[peripheral.identifier.uuidString] = peripheral
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        QCSDKManager.shareInstance().addPeripheral(peripheral) { [weak self] success in
            if success {
                self?.pendingConnectResult?(nil)
            } else {
                self?.pendingConnectResult?(FlutterError(
                    code: "SDK_ADD_FAILED",
                    message: "QCSDKManager failed to bind peripheral",
                    details: nil
                ))
            }
            self?.pendingConnectResult = nil
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        pendingConnectResult?(FlutterError(
            code: "CONNECT_FAILED",
            message: error?.localizedDescription ?? "Unknown",
            details: nil
        ))
        pendingConnectResult = nil
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectedPeripheral = nil
        methodChannel?.invokeMethod("onDisconnect", arguments: nil)
    }
}

// MARK: - Event stream handlers

private final class PpgStreamHandler: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void
    init(onSink: @escaping (FlutterEventSink?) -> Void) {
        self.onSink = onSink
    }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events)
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSink(nil)
        return nil
    }
}

private final class AccelStreamHandler: NSObject, FlutterStreamHandler {
    private let onSink: (FlutterEventSink?) -> Void
    init(onSink: @escaping (FlutterEventSink?) -> Void) {
        self.onSink = onSink
    }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onSink(events)
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onSink(nil)
        return nil
    }
}
