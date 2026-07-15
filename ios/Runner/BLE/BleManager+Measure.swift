//
//  BleManager+Measure.swift
//  Runner
//
//  Tasks 19–21: active measurements — the manual streams (HR / SpO2 / HRV),
//  the on-demand BP measurement, and the one-key measurement.
//
//  All flow through QCSDKManager's unified measurement API:
//    startToMeasuring(withOperateType:timeout:measuringHandle:completedHandle:)
//    stopToMeasuring(withOperateType:completedHandle:)
//  Live values additionally surface via the manager's block properties
//  (hrMeasuring / boMeasuring / bpMeasuring), wired once in
//  wireMeasurementCallbacks() and routed to the frozen Dart callback names:
//    onHeartStream {hr} · onSpo2Stream {spo2,hr} · onHrvStream {hrv,hr,stress}
//    onOneKeyMeasurementStream {hr,spo2,sbp,dbp,fatigue,score}
//
//  QCMeasuringType raw values (QCSDKManager.h L24-39) are used via
//  rawValue-init so the SDK's spelling quirks (BloodPressue, Unkown) never
//  leak into Swift case-name guessing:
//    0=HR 1=BP 2=SpO2 3=oneKey 6=HRV 9=oneKeyHR 10=HR-raw 11=SpO2-raw
//

import Flutter
import Foundation
import QCBandSDK

extension BleManager {
    private var sdk: QCSDKManager { QCSDKManager.shareInstance() }

    private func measuringType(_ raw: Int) -> QCMeasuringType {
        return QCMeasuringType(rawValue: raw) ?? QCMeasuringType(rawValue: -1)!
    }

    // MARK: - Callback wiring (called once from init)

    /// Route the manager's live measurement blocks to the Dart stream
    /// callbacks. Blocks are global on the SDK singleton, so each handler
    /// checks its own *Streaming flag — a stray tick after stop is dropped.
    /// Pre-converge values (<= 0) are dropped, mirroring Android.
    func wireMeasurementCallbacks() {
        sdk.hrMeasuring = { [weak self] hr in
            guard let self = self, self.hrStreaming, hr > 0 else { return }
            self.callDart("onHeartStream", ["hr": Int(hr)])
        }
        sdk.boMeasuring = { [weak self] so2 in
            guard let self = self, self.spo2Streaming, so2 > 0 else { return }
            // Android sends {spo2, hr}; the iOS SpO2 block has no HR → 0
            // (Dart requires the key but tolerates 0).
            self.callDart("onSpo2Stream", ["spo2": Int(so2), "hr": 0])
        }
        sdk.measuringFail = {
            NSLog("HlthBLE measure: measuringFail block fired")
        }
    }

    // MARK: - Manual HR stream (Android startHeartStream/stopHeartStream)

    func startHeartStream(_ result: @escaping FlutterResult) {
        guard !hrStreaming else {
            result(["started": false, "reason": "already streaming"]); return
        }
        hrStreaming = true
        sdk.startToMeasuring(
            withOperateType: measuringType(0),
            measuringHandle: { [weak self] value in
                guard let self = self, self.hrStreaming else { return }
                if let bpm = (value as? NSNumber)?.intValue, bpm > 0 {
                    self.callDart("onHeartStream", ["hr": bpm])
                }
            },
            completedHandle: { [weak self] _, value, _ in
                guard let self = self else { return }
                if let bpm = (value as? NSNumber)?.intValue, bpm > 0, self.hrStreaming {
                    self.callDart("onHeartStream", ["hr": bpm])
                }
                self.hrStreaming = false
            })
        result(["started": true])
    }

    func stopHeartStream(_ result: @escaping FlutterResult) {
        guard hrStreaming else {
            result(["stopped": false, "reason": "not streaming"]); return
        }
        hrStreaming = false
        sdk.stopToMeasuring(withOperateType: measuringType(0)) { _, _ in }
        result(["stopped": true])
    }

    // MARK: - Manual SpO2 stream

    func startSpo2Stream(_ result: @escaping FlutterResult) {
        guard !spo2Streaming else {
            result(["started": false, "reason": "already streaming"]); return
        }
        spo2Streaming = true
        sdk.startToMeasuring(
            withOperateType: measuringType(2),
            measuringHandle: { [weak self] value in
                guard let self = self, self.spo2Streaming else { return }
                if let so2 = (value as? NSNumber)?.intValue, so2 > 0 {
                    self.callDart("onSpo2Stream", ["spo2": so2, "hr": 0])
                }
            },
            completedHandle: { [weak self] _, value, _ in
                guard let self = self else { return }
                if let so2 = (value as? NSNumber)?.intValue, so2 > 0, self.spo2Streaming {
                    self.callDart("onSpo2Stream", ["spo2": so2, "hr": 0])
                }
                self.spo2Streaming = false
            })
        result(["started": true])
    }

    func stopSpo2Stream(_ result: @escaping FlutterResult) {
        guard spo2Streaming else {
            result(["stopped": false, "reason": "not streaming"]); return
        }
        spo2Streaming = false
        sdk.stopToMeasuring(withOperateType: measuringType(2)) { _, _ in }
        result(["stopped": true])
    }

    // MARK: - Manual HRV stream

    func startHrvStream(_ result: @escaping FlutterResult) {
        guard !hrvStreaming else {
            result(["started": false, "reason": "already streaming"]); return
        }
        hrvStreaming = true
        sdk.startToMeasuring(
            withOperateType: measuringType(6),
            measuringHandle: { [weak self] value in
                guard let self = self, self.hrvStreaming else { return }
                if let hrv = (value as? NSNumber)?.intValue, hrv > 0 {
                    self.callDart("onHrvStream", ["hrv": hrv, "hr": 0, "stress": 0])
                }
            },
            completedHandle: { [weak self] _, value, _ in
                guard let self = self else { return }
                if let hrv = (value as? NSNumber)?.intValue, hrv > 0, self.hrvStreaming {
                    self.callDart("onHrvStream", ["hrv": hrv, "hr": 0, "stress": 0])
                }
                self.hrvStreaming = false
            })
        result(["started": true])
    }

    func stopHrvStream(_ result: @escaping FlutterResult) {
        guard hrvStreaming else {
            result(["stopped": false, "reason": "not streaming"]); return
        }
        hrvStreaming = false
        sdk.stopToMeasuring(withOperateType: measuringType(6)) { _, _ in }
        result(["stopped": true])
    }

    // MARK: - On-demand BP measurement (Android startBpMeasurement)
    //
    // The ONLY real BP path on H59. Awaits convergence and answers the Future
    // with {sbp, dbp, hr, errCode} — Dart's BP screen persists it directly.
    // ~30s typical; 60s timeout gives slow converges headroom.

    func startBpMeasurement(_ result: @escaping FlutterResult) {
        var lastSbp = 0, lastDbp = 0
        sdk.bpMeasuring = { sbp, dbp in
            lastSbp = Int(sbp); lastDbp = Int(dbp)
        }
        sdk.startToMeasuring(
            withOperateType: measuringType(1),
            timeout: 60,
            measuringHandle: { _ in },
            completedHandle: { isSuccess, value, error in
                guard isSuccess else {
                    result(FlutterError(
                        code: "BP_MEASURE_FAILED",
                        message: "status=\(error.map { String(describing: $0) } ?? "unknown")",
                        details: nil))
                    return
                }
                // Final result may arrive as a model/dictionary or only via the
                // bpMeasuring ticks — take whichever converged.
                var sbp = lastSbp, dbp = lastDbp
                if let dict = value as? [String: Any] {
                    sbp = (dict["sbp"] as? NSNumber)?.intValue ?? sbp
                    dbp = (dict["dbp"] as? NSNumber)?.intValue ?? dbp
                }
                result(["sbp": sbp, "dbp": dbp, "hr": 0, "errCode": 0])
            })
    }

    func stopBpMeasurement(_ result: @escaping FlutterResult) {
        sdk.stopToMeasuring(withOperateType: measuringType(1)) { isSuccess, _ in
            result(["stopped": isSuccess])
        }
    }

    // MARK: - One-key measurement (Android startOneKeyMeasurement)
    //
    // QCMeasuringTypeOneKeyMeasureHeartRate(9) streams
    // QCRealOneKeyMeasureHeartRateModel ticks: hr / hrv / stress / rri /
    // temp / sbp / dbp. Android hard-codes spo2=0 and drops ticks until BP
    // converges (sbp>0 && dbp>0); we mirror that gate.

    func startOneKeyMeasurement(_ result: @escaping FlutterResult) {
        guard !okmStreaming else {
            result(["started": false, "reason": "already running"]); return
        }
        okmStreaming = true
        let emit: (Any?) -> Void = { [weak self] value in
            guard let self = self, self.okmStreaming,
                  let m = value as? QCRealOneKeyMeasureHeartRateModel,
                  m.bloodPressureSbp > 0, m.bloodPressureDbp > 0 else { return }
            self.callDart("onOneKeyMeasurementStream", [
                "hr": m.heartRateValue,
                "spo2": 0,
                "sbp": m.bloodPressureSbp,
                "dbp": m.bloodPressureDbp,
                "fatigue": m.stress,
                "score": 0,
            ])
        }
        sdk.startToMeasuring(
            withOperateType: measuringType(9),
            measuringHandle: emit,
            completedHandle: { [weak self] _, value, _ in
                emit(value)
                self?.okmStreaming = false
            })
        result(["started": true])
    }

    func stopOneKeyMeasurement(_ result: @escaping FlutterResult) {
        guard okmStreaming else {
            result(["stopped": false, "reason": "not running"]); return
        }
        okmStreaming = false
        sdk.stopToMeasuring(withOperateType: measuringType(9)) { _, _ in }
        result(["stopped": true])
    }
}
