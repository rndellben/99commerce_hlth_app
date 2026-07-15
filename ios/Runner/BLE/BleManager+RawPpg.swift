//
//  BleManager+RawPpg.swift
//  Runner
//
//  Task 22: raw PPG + accelerometer capture.
//
//  H59 constraint: raw accel is emitted ONLY during an active raw-PPG window.
//  Android streams per-packet onto the `hlth/realtime_stream` EventChannel;
//  the iOS SDK instead delivers the whole burst (~25 Hz × window) in the
//  completion callback of startToMeasuring(type: HeartRateRaw=10 /
//  BloodOxygenRaw=11). We convert every frame with PayloadCodec.ppgSampleMaps
//  and emit them onto the SAME EventChannel as one list, so the Dart-side
//  consumers (fall sweep, scheduled PPG capture, PPG analysis) see identical
//  content.
//
//  Timing caveat (documented, needs on-ring confirmation): the burst lands at
//  window end rather than continuously. FallSweepService waits durationSec+1s
//  before cancelling its listener, which the completion normally beats — but
//  a slow BLE flush could exceed the grace second and drop that sweep. If
//  observed on hardware, bump the Dart-side grace, not this file.
//

import Flutter
import Foundation
import QCBandSDK

extension BleManager {
    private var manager: QCSDKManager { QCSDKManager.shareInstance() }

    private func rawType(_ raw: Int) -> QCMeasuringType {
        return QCMeasuringType(rawValue: raw) ?? QCMeasuringType(rawValue: -1)!
    }

    /// Green-LED raw PPG (Android startMeasureHrRaw). Returns
    /// {started: true, seconds} immediately; frames arrive on the
    /// hlth/realtime_stream EventChannel when the burst completes.
    func startMeasureHrRaw(_ duration: Int, _ result: @escaping FlutterResult) {
        manager.startToMeasuring(
            withOperateType: rawType(10),
            timeout: duration,
            measuringHandle: { _ in /* demo: unused for raw */ },
            completedHandle: { [weak self] _, value, _ in
                self?.emitRawBurst(value)
            })
        result(["started": true, "seconds": duration])
    }

    /// Android `stopMeasure` returns null on success.
    func stopMeasureRaw(_ result: @escaping FlutterResult) {
        manager.stopToMeasuring(withOperateType: rawType(10)) { _, _ in }
        result(nil)
    }

    /// Red+IR raw PPG (Android startMeasureSpo2Raw).
    func startMeasureSpo2Raw(_ duration: Int, _ result: @escaping FlutterResult) {
        manager.startToMeasuring(
            withOperateType: rawType(11),
            timeout: duration,
            measuringHandle: { _ in },
            completedHandle: { [weak self] _, value, _ in
                self?.emitRawBurst(value)
            })
        result(["started": true, "seconds": duration])
    }

    func stopMeasureSpo2Raw(_ result: @escaping FlutterResult) {
        manager.stopToMeasuring(withOperateType: rawType(11)) { _, _ in }
        result(nil)
    }

    /// Completion `result` is NSArray<QCBloodGlucoseHeartRateRawModel *> per
    /// the vendor demo (PPGViewController.m L346/L410). Anything else is
    /// dropped with a breadcrumb so hardware surprises are diagnosable.
    private func emitRawBurst(_ value: Any?) {
        guard let frames = value as? [QCBloodGlucoseHeartRateRawModel], !frames.isEmpty else {
            NSLog("HlthBLE ppg-raw: completion carried no frames (%@)",
                  String(describing: type(of: value)))
            return
        }
        let samples = PayloadCodec.ppgSampleMaps(frames)
        callDartSink { [weak self] in
            self?.ppgEventSink?(samples)
        }
    }

    /// EventChannel sinks must be touched on the main thread, same rule as
    /// method-channel callbacks.
    private func callDartSink(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() }
        else { DispatchQueue.main.async(execute: block) }
    }
}
