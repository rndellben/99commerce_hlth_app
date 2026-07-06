//
//  BleManager+Connection.swift
//  Runner
//
//  Task 4: scan / connect / disconnect / battery + the full
//  CBCentralManagerDelegate. Uses raw CoreBluetooth (the centralManager created
//  in BleManager.init) for scan/connect/disconnect, and binds the connected
//  peripheral to QCBandSDK via QCSDKManager.shareInstance().addPeripheral /
//  removePeripheral. `QCCentralManager` is demo-only and is NOT used here.
//
//  Matches the Android BleManager.kt Dart-facing contract:
//    - startScan  -> [{id, name, rssi}] after a ~10s scan window
//    - stopScan   -> null
//    - connect    -> optimistic null; real state via onConnected{deviceName}
//    - disconnect -> null + onDisconnect{deviceName}
//    - getBattery -> {level, charging} + onBatteryUpdate{battery, charging}
//

import CoreBluetooth
import Flutter
import QCBandSDK

extension BleManager: CBCentralManagerDelegate {

    // MARK: - Scan

    func startScan(_ result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(
                code: "ble.bluetooth.off",
                message: "state=\(centralManager.state.rawValue)",
                details: nil
            ))
            return
        }
        discoveredPeripherals.removeAll()
        scanResults.removeAll()

        // A peripheral already connected at the iOS system level (paired in
        // Settings → Bluetooth) STOPS advertising, so scanForPeripherals can't
        // see it. retrieveConnectedPeripherals(withServices:) returns those by
        // their GATT service UUID — same as the QCBandSDK demo's
        // retrieveConnectedPeripheralsWithServices:. Include them immediately.
        for p in centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs) {
            let id = p.identifier.uuidString
            discoveredPeripherals[id] = p
            scanResults[id] = ["id": id, "name": p.name ?? "HLTH Band", "rssi": 0]
        }

        // Scan with NO service filter (the H59 doesn't advertise the QCBandSDK
        // service UUIDs), then filter by name prefix in didDiscover — mirrors
        // Android BleManager.kt and the QCBandSDK demo (scanForPeripheralsWithServices:nil).
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            self.centralManager.stopScan()
            result(Array(self.scanResults.values))
        }
    }

    func stopScan(_ result: @escaping FlutterResult) {
        centralManager.stopScan()
        result(nil)
    }

    // MARK: - Connect / Disconnect

    func connect(_ deviceId: String?, _ result: @escaping FlutterResult) {
        guard let deviceId = deviceId, let p = discoveredPeripherals[deviceId] else {
            result(FlutterError(
                code: "ble.connect.not_found",
                message: "not in scan cache",
                details: nil
            ))
            return
        }
        pendingConnectResult = result
        centralManager.connect(p, options: nil)
    }

    func disconnect(_ result: @escaping FlutterResult) {
        if let p = connectedPeripheral {
            QCSDKManager.shareInstance().remove(p)
            centralManager.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        result(nil)
        callDart("onDisconnect", ["deviceName": connectedDeviceName])
        connectedDeviceName = ""
    }

    // MARK: - Battery

    func getBattery(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.readBatterySuccess({ [weak self] battery, charging in
            let payload: [String: Any] = ["level": Int(battery), "charging": charging]
            result(payload)
            self?.callDart("onBatteryUpdate", ["battery": Int(battery), "charging": charging])
        }, failed: {
            result(FlutterError(
                code: "sdk.error.unknown",
                message: "battery read failed",
                details: nil
            ))
        })
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        callDart("onBleStateChange", ["state": central.state.rawValue])
    }

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        // Resolve the advertised name (CBAdvertisementDataLocalNameKey is more
        // reliable during scan than peripheral.name), then keep only HLTH band
        // names — same prefix allowlist as Android's isHlthBandName().
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advName ?? peripheral.name ?? ""
        guard isHlthBandName(name) else { return }
        let id = peripheral.identifier.uuidString
        discoveredPeripherals[id] = peripheral
        scanResults[id] = ["id": id, "name": name.isEmpty ? "Unknown" : name, "rssi": RSSI.intValue]
    }

    /// Name-prefix allowlist mirroring Android BleManager.kt BAND_NAME_PREFIXES.
    func isHlthBandName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let prefixes = [
            "H59",
            "O_", "Q_", "R3L", "QC", "Wa",
            "T80", "T90", "T91", "T93", "T95", "TW68",
            "S9",
            "C60", "C66", "C67", "C68", "C80", "C86", "C88", "C96",
            "wxb_w4",
        ]
        return prefixes.contains { name.lowercased().hasPrefix($0.lowercased()) }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        connectedDeviceName = peripheral.name ?? "HLTH"
        QCSDKManager.shareInstance().add(peripheral) { [weak self] success in
            guard let self = self else { return }
            if success {
                self.pendingConnectResult?(nil)
                self.runConnectBootstrap()          // Task 5
                self.callDart("onConnected", ["deviceName": self.connectedDeviceName])
                self.startPeriodicTimer()           // Task 10
            } else {
                self.pendingConnectResult?(FlutterError(
                    code: "SDK_ADD_FAILED",
                    message: "QCSDKManager failed to bind peripheral",
                    details: nil
                ))
            }
            self.pendingConnectResult = nil
        }
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral,
                               error: Error?) {
        pendingConnectResult?(FlutterError(
            code: "ble.connect.timeout",
            message: error?.localizedDescription ?? "",
            details: nil
        ))
        pendingConnectResult = nil
    }

    public func centralManager(_ central: CBCentralManager,
                               didDisconnectPeripheral peripheral: CBPeripheral,
                               error: Error?) {
        connectedPeripheral = nil
        stopPeriodicTimer()
        callDart("onDisconnect", ["deviceName": connectedDeviceName])
    }

    public func centralManager(_ central: CBCentralManager,
                               willRestoreState dict: [String: Any]) {
        // Implemented in Task 12 (CoreBluetooth state restoration).
    }
}
