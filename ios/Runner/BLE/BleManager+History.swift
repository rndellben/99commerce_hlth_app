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
}
