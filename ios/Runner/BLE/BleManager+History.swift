//
//  BleManager+History.swift
//  Runner
//
//  Tasks 6–9: the four history-sync normalizers.
//
//  Each method calls the QCBandSDK fetch API, hands the model(s) to a pure
//  PayloadCodec normalizer, and returns the EXACT Dart-facing payload that the
//  Android bridge emits (sync_adapters.dart is the frozen contract). On failure
//  every method returns the empty-shape payload — it never throws or returns a
//  FlutterError — so the Dart sync loop is unaffected.
//

import Flutter
import QCBandSDK

extension BleManager {
    // MARK: - Task 6: getSleepHistory
    //
    // Header: + (void)getSleepDetailDataByDay:(NSInteger)dayIndex
    //           sleepDatas:(nullable void (^)(NSArray<QCSleepModel *> *sleeps))items
    //           fail:(nullable void (^)(void))fail;
    func getSleepHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSleepDetailData(byDay: dayOffset, sleepDatas: { sleeps in
            result(PayloadCodec.sleepPayload(sleeps ?? []))
        }, fail: {
            result(PayloadCodec.sleepPayload([]))
        })
    }

    // MARK: - Task 7: getHrHistory
    //
    // Header: + (void)getSchedualHeartRateDataWithDayIndexs:(NSArray<NSNumber*> *)dayIndexs
    //           success:(void (^)(NSArray<QCSchedualHeartRateModel *> *_Nonnull))success
    //           fail:(void (^)(void))fail;
    func getHrHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualHeartRateData(withDayIndexs: [NSNumber(value: dayOffset)], success: { models in
            guard let m = models.first else { result(PayloadCodec.emptyHr()); return }
            result(PayloadCodec.hrPayload(m))
        }, fail: {
            result(PayloadCodec.emptyHr())
        })
    }

    // MARK: - Task 8: getHrvHistory
    //
    // Header: + (void)getSchedualHRVDataWithDates:(NSArray<NSNumber*> *)dates
    //           finished:(void (^)(NSArray * _Nullable, NSError * _Nullable))finished;
    //
    // NOTE on the `dates:` argument — the selector is named "WithDates" but the
    // arg is typed NSArray<NSNumber*>. The header doc resolves the ambiguity:
    //   "@param dates 0-6,0:today,1:yesterday...."
    // i.e. these are DAY-INDEX numbers, not NSDate. We pass [@(dayOffset)].
    // (Flag for hardware verification on the H59, but the header is explicit.)
    //
    // CRITICAL: the raw bytes ARE RMSSD in ms — PayloadCodec.hrvPayload does
    // NOT divide by 10.
    func getHrvHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualHRVData(withDates: [NSNumber(value: dayOffset)], finished: { models, _ in
            let m = (models as? [QCHRVModel])?.first
            result(PayloadCodec.hrvPayload(m))
        })
    }

    // MARK: - Task 9: getStressDay
    //
    // Header: + (void)getSchedualStressDataWithDates:(NSArray<NSNumber*> *)dates
    //           finished:(void (^)(NSArray * _Nullable, NSError * _Nullable))finished;
    //
    // Same day-index semantics as HRV: "@param dates 0-6,0:today,1:yesterday....".
    func getStressDay(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualStressData(withDates: [NSNumber(value: dayOffset)], finished: { models, _ in
            let m = (models as? [QCStressModel])?.first
            result(PayloadCodec.stressPayload(m, dayOffset: dayOffset))
        })
    }

    // MARK: - Task 16: SpO2 history
    //
    // Header (L835): + (void)getBloodOxygenDataByDayIndex:(NSInteger)dayIndex
    //           finished:(void (^)(NSArray * _Nullable, NSError * _Nullable))finished;
    //
    // Android returns a LIST of per-day {dateStr, unixTime, minArray, maxArray}
    // entries; empty list on no data.

    /// One day (Android getSpO2Day) — single-element list, or [] when empty.
    func getSpO2Day(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getBloodOxygenData(byDayIndex: dayOffset) { models, _ in
            let day = PayloadCodec.spo2DayEntry(
                (models as? [QCBloodOxygenModel]) ?? [], dayOffset: dayOffset)
            result(day == nil ? [[String: Any]]() : [day!])
        }
    }

    /// Full stored window (Android getSpO2History). The iOS SDK only offers
    /// per-day reads, so we chain day-indexes 0…6 (the band's retention
    /// ballpark) and collect non-empty days. Sequential — one BLE round-trip
    /// at a time — mirroring how every other multi-day pull behaves.
    func getSpO2History(_ result: @escaping FlutterResult) {
        var entries: [[String: Any]] = []
        func fetch(_ day: Int) {
            if day > 6 { result(entries); return }
            QCSDKCmdCreator.getBloodOxygenData(byDayIndex: day) { models, _ in
                if let e = PayloadCodec.spo2DayEntry(
                    (models as? [QCBloodOxygenModel]) ?? [], dayOffset: day) {
                    entries.append(e)
                }
                fetch(day + 1)
            }
        }
        fetch(0)
    }

    /// Interval-based SpO2 read (Android getSpO2Interval).
    // Header (L1225): + (void)getBloodOxygenDataWithIntervalByDayIndex:(NSInteger)dayIndex
    //           finished:(void (^)(NSInteger, NSArray * _Nullable, NSError * _Nullable))finished;
    // First block arg is the interval in MINUTES (per demo usage; the header
    // doc-comment saying "number of entries" is contradicted by the demo).
    // Android's timeout branch returns ONLY {samples:[], total:0, timedOut:true}.
    func getSpO2Interval(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getBloodOxygenDataWithInterval(byDayIndex: dayOffset) { _, models, err in
            guard err == nil, let list = models as? [QCBloodOxygenModel] else {
                result(["samples": [Int](), "total": 0, "timedOut": true])
                return
            }
            let samples = list.map { Int($0.soa2) }
            let nonZero = samples.filter { $0 > 0 }
            result([
                "samples": samples,
                "total": samples.count,
                "nonZero": nonZero.count,
                "min": nonZero.min() ?? 0,
                "max": nonZero.max() ?? 0,
                "timedOut": false,
            ])
        }
    }

    /// Capability probe (Android getSpO2Capability). The iOS SDK has no
    /// capability selector; we probe the interval-SpO2 setting read — if the
    /// band answers, interval SpO2 is supported. HR/temperature interval
    /// support is unknowable from iOS → reported false (nothing Dart-side
    /// consumes them off this platform).
    func getSpO2Capability(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualBOInfo(intervalSuccess: { _, _ in
            result([
                "ok": true,
                "supportIntervalBloodOxygen": true,
                "supportIntervalHeartRate": false,
                "supportIntervalTemperature": false,
                "timedOut": false,
            ])
        }, fail: {
            result(["ok": false, "timedOut": true])
        })
    }

    /// Enable interval SpO2 + read back (Android enableSpO2Interval).
    // Set (L1200): setSchedualBOInfoOn:timeInterval:success:fail: (success takes NO args)
    // Get (L1213): getSchedualBOInfoWithIntervalSuccess:(BOOL,NSInteger)fail:
    // The write-ack lies on H59 — the 1.5s-later read-back is ground truth
    // (same pattern as Android BleManager.kt).
    func enableSpO2Interval(_ a: [String: Any], _ result: @escaping FlutterResult) {
        let enable = a["enable"] as? Bool ?? true
        let interval = a["intervalMinutes"] as? Int ?? 1
        QCSDKCmdCreator.setSchedualBOInfoOn(enable, timeInterval: interval, success: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                QCSDKCmdCreator.getSchedualBOInfo(intervalSuccess: { isOn, mins in
                    result([
                        "ok": true,
                        "isEnable": isOn,
                        "interval": mins,
                        "timedOut": false,
                    ])
                }, fail: {
                    result(["ok": false, "timedOut": true])
                })
            }
        }, fail: {
            result(["ok": false, "timedOut": true])
        })
    }

    // MARK: - Task 17: BP history
    //
    // The iOS SDK has no per-day scheduled-BP read — only full history
    // (L541): + (void)getSchedualBPHistoryDataWithSuccess:
    //           (nullable void (^)(NSArray<QCBloodPressureModel *> *data))success
    //           fail:(nullable void (^)(void))fail;
    // We pull the full history and filter to the requested local day.
    // (On H59 scheduled-BP history is empty anyway — the only real BP path is
    // startBpMeasurement — but the method must behave for future hardware.)
    // Android returns {} (empty map, no `readings` key) on no data.
    func getBpDay(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSchedualBPHistoryData(success: { models in
            let payload = PayloadCodec.bpDayPayload(models ?? [], dayOffset: dayOffset)
            let readings = payload["readings"] as? [[String: Any]] ?? []
            result(readings.isEmpty ? [String: Any]() : payload)
        }, fail: {
            result([String: Any]())
        })
    }

    /// Legacy BP-history path. On Android (CMD_BP_TIMING_MONITOR_DATA) the H59
    /// returns hourly HR values disguised as BP — a diagnostic curiosity used
    /// only by the debug screen. iOS has no equivalent legacy command, so we
    /// return the documented empty shape.
    func getBpHistory(_ result: @escaping FlutterResult) {
        result([String: Any]())
    }

    // MARK: - Task 18: Steps
    //
    // Daily totals (L197): + (void)getCurrentSportSucess:(void (^)(QCSportModel *sport))suc
    //           failed:(void (^)(void))fail;   [SDK typo "Sucess" is real]
    func getDailyTotals(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getCurrentSportSucess({ sport in
            result(PayloadCodec.dailyTotalsPayload(sport))
        }, failed: {
            result([String: Any]())
        })
    }

    // 15-min buckets (L222): + (void)getSportDetailDataByDay:minuteInterval:
    //           beginIndex:endIndex:sportDatas:fail:
    // minuteInterval 15 / indexes 0…95 mirror Android's
    // ReadDetailSportDataReq(dayOffset, 0, 95).
    func getStepBucketHistory(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSportDetailData(
            byDay: dayOffset, minuteInterval: 15, begin: 0, end: 95,
            sportDatas: { sports in
                result(PayloadCodec.stepBucketList(sports ?? []))
            }, fail: {
                result([[String: Any]]())
            })
    }

    // Android's getStepDay differs from getStepBucketHistory only in the
    // underlying command; both return the same bin shape. iOS has a single
    // detail API, so they share the implementation.
    func getStepDay(_ dayOffset: Int, _ result: @escaping FlutterResult) {
        getStepBucketHistory(dayOffset, result)
    }
}
