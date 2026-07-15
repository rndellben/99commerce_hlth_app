//
//  BleManager+Config.swift
//  Runner
//
//  Task 5: connect bootstrap + the data-enabler config methods.
//
//  The H59 ring is dormant until scheduled monitoring is enabled and time +
//  profile are set. `runConnectBootstrap()` mirrors Android's post-connect
//  sequence (setTime, which also returns the device feature list). Cardio Load
//  needs HR + SpO2 + HRV + BP + stress scheduled recording turned on.
//
//  All selectors here were verified against
//  ios/Frameworks/QCBandSDK.framework/Headers/QCSDKCmdCreator.h.
//

import Foundation
import Flutter
import QCBandSDK

extension BleManager {
    /// Post-connect bootstrap. Sets the band clock (the success callback also
    /// hands back the feature list, kept for later capability checks).
    /// Header: `+ (void)setTime:(NSDate *)date success:(void (^)(NSDictionary *featureList))suc failed:(void (^)(void))fail;`
    func runConnectBootstrap() {
        QCSDKCmdCreator.setTime(Date(), success: { _ in
            // featureList available here if needed by later capability tasks.
        }, failed: {})
    }

    /// Write the user's time format + personal profile to the band.
    /// Dart contract: `{set: Bool}`. Gender is 0=Male, 1=Female per the header,
    /// so we pass `isMale ? 0 : 1`.
    /// Header:
    /// `+ (void)setTimeFormatTwentyfourHourFormat:(BOOL)twentyfourHourFormat
    ///        metricSystem:(BOOL)metricSystem gender:(NSInteger)gender age:(NSInteger)age
    ///        height:(NSInteger)height weight:(NSInteger)weight sbpBase:(NSInteger)sbpBase
    ///        dbpBase:(NSInteger)dbpBase hrAlarmValue:(NSInteger)hrAlarmValue
    ///        success:(void (^)(BOOL, BOOL, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger, NSInteger))success
    ///        fail:(void (^)(void))fail;`
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
            success: { _, _, _, _, _, _, _, _, _ in result(["set": true]) },
            fail: { result(["set": false]) })
    }

    /// Enable HR + SpO2 + HRV + BP + stress scheduled monitoring on the band,
    /// then immediately echo the requested intervals back to Dart.
    ///
    /// Fire-and-forget: the H59's write-acks are unreliable, so we don't await
    /// or read back the scheduled-set calls on iOS in this task — we issue them
    /// and reply with the echo Dart expects.
    func setScheduledMonitoring(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let hr = a["hrInterval"] as? Int ?? 10
        let startInterval = a["startInterval"] as? Int ?? 5
        let spo2 = a["spo2Interval"] as? Int ?? 60
        let hrv = a["hrvInterval"] as? Int ?? 30
        let bp = a["bpIntervalMinutes"] as? Int ?? 60

        // HR: `+ (void)setSchedualHeartRateStatus:(BOOL)enable timeInterval:(NSInteger)interval
        //        success:(nullable void (^)(void))success fail:(nullable void (^)(void))fail;`
        QCSDKCmdCreator.setSchedualHeartRateStatus(true, timeInterval: hr, success: {}, fail: {})

        // SpO2: `+ (void)setSchedualBOInfoOn:(BOOL)featureOn timeInterval:(NSInteger)timeInterval
        //        success:(void (^)(void))success fail:(void (^)(void))fail;`
        QCSDKCmdCreator.setSchedualBOInfoOn(true, timeInterval: spo2, success: {}, fail: {})

        // HRV: `+ (void)setSchedualHRVStatus:(BOOL)enable finshed:(nullable void (^)(NSError *_Nullable error))finished;`
        QCSDKCmdCreator.setSchedualHRVStatus(true, finshed: { _ in })

        // BP: `+ (void)setSchedualBPInfoOn:(BOOL)featureOn beginTime:(NSString *)beginTime
        //        endTime:(NSString *)endTime minuteInterval:(NSInteger)minuteInterval
        //        success:(nullable void (^)(BOOL, NSString *, NSString *, NSInteger))success fail:(void (^)(void))fail;`
        QCSDKCmdCreator.setSchedualBPInfoOn(true, beginTime: "00:00", endTime: "23:59",
                                            minuteInterval: bp,
                                            success: { _, _, _, _ in }, fail: {})

        // Stress: `+ (void)setSchedualStressStatus:(BOOL)enable finshed:(nullable void (^)(NSError *_Nullable error))finished;`
        QCSDKCmdCreator.setSchedualStressStatus(true, finshed: { _ in })

        result([
            "hrInterval": hr,
            "startInterval": startInterval,
            "spo2Interval": spo2,
            "hrvInterval": hrv,
            "bpIntervalMinutes": bp,
        ])
    }

    /// Read the band's scheduled-HR config and map it to the Dart keys.
    /// Header:
    /// `+ (void)getSchedualHeartRateInfoWithSuccess:(nullable void (^)(BOOL enable, NSInteger interval,
    ///        NSInteger minInterval, NSInteger minHrTip, NSInteger maxHrTip))success
    ///        fail:(nullable void (^)(void))fail;`
    /// Mapping: mainSwitch = enable ? 1 : 0; startInterval = minInterval;
    /// tooLowReminder = minHrTip; tooHighReminder = maxHrTip.
    func getScheduledHr(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualHeartRateInfo(success: { enable, interval, minInterval, minHrTip, maxHrTip in
            result([
                "isEnable": enable,
                "heartInterval": interval,
                "startInterval": minInterval,
                "mainSwitch": enable ? 1 : 0,
                "tooLowReminder": minHrTip,
                "tooHighReminder": maxHrTip,
            ])
        }, fail: {
            result([
                "isEnable": false,
                "heartInterval": 0,
                "startInterval": 0,
                "mainSwitch": 0,
                "tooLowReminder": 0,
                "tooHighReminder": 0,
            ])
        })
    }

    // MARK: - Task 15: scheduled BP get/set (Android BP_SCHED_*)

    /// Write the scheduled-BP window + interval, ack with Android's
    /// {isEnable, intervalMinutes} write-ack shape. NOTE: on H59 the write-ack
    /// lies — Dart always follows with getBpScheduled for ground truth.
    func setBpScheduled(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let enabled = a["enabled"] as? Bool ?? true
        let interval = a["intervalMinutes"] as? Int ?? 60
        let begin = String(format: "%02d:%02d",
                           a["startHour"] as? Int ?? 0, a["startMinute"] as? Int ?? 0)
        let end = String(format: "%02d:%02d",
                         a["endHour"] as? Int ?? 23, a["endMinute"] as? Int ?? 59)
        QCSDKCmdCreator.setSchedualBPInfoOn(
            enabled, beginTime: begin, endTime: end, minuteInterval: interval,
            success: { featureOn, _, _, minuteInterval in
                result(["isEnable": featureOn, "intervalMinutes": minuteInterval])
            }, fail: {
                result(FlutterError(code: "BP_SCHED_FAILED",
                                    message: "setSchedualBPInfo failed", details: nil))
            })
    }

    /// Read back the scheduled-BP config (the ground truth on H59).
    /// Header (L492): getSchedualBPInfo:(BOOL,NSString* "HH:mm",NSString*,NSInteger)fail:
    func getBpScheduled(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualBPInfo({ featureOn, beginTime, endTime, minuteInterval in
            func parse(_ s: String?) -> (h: Int, m: Int)? {
                let parts = (s ?? "").split(separator: ":")
                guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1])
                else { return nil }
                return (h, m)
            }
            let b = parse(beginTime)
            let e = parse(endTime)
            result([
                "isEnable": featureOn,
                "intervalMinutes": minuteInterval,
                "startHour": b?.h ?? 0,
                "startMinute": b?.m ?? 0,
                "endHour": e?.h ?? 23,
                "endMinute": e?.m ?? 59,
            ])
        }, fail: {
            result(FlutterError(code: "BP_SCHED_READ_FAILED",
                                message: "getSchedualBPInfo failed", details: nil))
        })
    }

    // MARK: - Task 15: scheduled stress get/set (Android STRESS_SCHED_*)

    /// Pure on/off — the band picks its own cadence (~30 min). The iOS set
    /// callback carries only an error, no echo, so we ack with the requested
    /// state (Android echoes the SDK ack, equally untrustworthy on H59 —
    /// Dart's read-back is the ground truth either way).
    func setStressScheduled(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let enabled = a["enabled"] as? Bool ?? true
        QCSDKCmdCreator.setSchedualStressStatus(enabled, finshed: { err in
            if err != nil {
                result(FlutterError(code: "STRESS_SCHED_FAILED",
                                    message: "setSchedualStressStatus failed", details: nil))
            } else {
                result(["isEnable": enabled])
            }
        })
    }

    /// Header (L1071): getSchedualStressStatusWithFinshed:(BOOL,NSError*)
    /// [SDK typo "Finshed" is real.]
    func getStressScheduled(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualStressStatus(finshed: { isOn, err in
            if err != nil {
                result(FlutterError(code: "STRESS_SCHED_READ_FAILED",
                                    message: "getSchedualStressStatus failed", details: nil))
            } else {
                result(["isEnable": isOn])
            }
        })
    }
}
