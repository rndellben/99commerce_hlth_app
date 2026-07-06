//
//  BleManager+Events.swift
//  Runner
//
//  Task 11: device-initiated events → Dart callbacks.
//
//  The band proactively reports data updates (HR/BP/SpO2/steps/…) and battery
//  changes via QCSDKManager block properties, and pushes realtime heart-rate
//  values through an OdmBandNotifyCenter notification. We translate each into
//  the exact Android-facing payload the frozen Dart contract expects:
//    - onDeviceNotify       {dataType: Int, loadData: [Int]}
//    - onBatteryUpdate      {battery: Int, charging: Bool}
//    - onRealtimeHeartRate  {bpm: Int}
//

import Foundation
import QCBandSDK

extension BleManager {
    func registerDeviceEventObservers() {
        let sdk = QCSDKManager.shareInstance()

        // Proactive data-update reports → onDeviceNotify.
        // watchDataUpdateReport: void(^)(QCDeviceDataUpdateReport dataType, NSInteger dataValue)
        sdk.watchDataUpdateReport = { [weak self] type, value in
            self?.callDart("onDeviceNotify", [
                "dataType": Self.mapUpdateType(type),
                "loadData": [value],
            ])
        }

        // Battery telemetry → onBatteryUpdate.
        // currentBatteryInfo: void(^)(NSInteger battery, BOOL charging)
        sdk.currentBatteryInfo = { [weak self] battery, charging in
            self?.callDart("onBatteryUpdate", [
                "battery": Int(battery),
                "charging": charging,
            ])
        }

        // Realtime heart rate → onRealtimeHeartRate.
        //
        // NOTE: The OdmBandRealTimeHeartRate userInfo key carrying the bpm is
        // not documented in OdmBandNotifyCenter.h. The header exposes both
        // `OdmValueKey` and `OdmHeartRateValueKey` as plausible carriers, and
        // some firmwares attach the value to `notification.object` instead.
        // We try each defensively and skip bpm <= 0. This extraction needs
        // runtime confirmation on the H59.
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(OdmBandRealTimeHeartRate),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let info = note.userInfo
            let bpm = (info?[OdmHeartRateValueKey] as? NSNumber)?.intValue
                ?? (info?[OdmValueKey] as? NSNumber)?.intValue
                ?? (info?["value"] as? NSNumber)?.intValue
                ?? (note.object as? NSNumber)?.intValue
                ?? 0
            if bpm > 0 {
                self?.callDart("onRealtimeHeartRate", ["bpm": bpm])
            }
        }
    }

    /// Map the SDK's QCDeviceDataUpdateReport enum to Android's dataType Int
    /// codes (1=HR, 2=BP, 3=SpO2, 4=steps, 5=temp, 7=exercise, 0x0c=charging).
    static func mapUpdateType(_ t: QCDeviceDataUpdateReport) -> Int {
        switch t {
        case .heartRate: return 1
        case .bloodPressure: return 2
        case .bloodOxygen: return 3
        case .step, .stepInfo: return 4
        case .temperature: return 5
        case .sportRecord: return 7
        case .power, .lowPower: return 0x0c
        default: return 0
        }
    }
}
