//
//  BleManager+Sport.swift
//  Runner
//
//  Task 23: band-side sport sessions.
//
//  sendSportStatus drives the band's workout state machine
//  (QCSDKCmdCreator.operateSportModeWithType:state:finish:, §3.39 ring-only);
//  syncSportSessions pulls SportPlus V2 summaries
//  (getSportPlusSummaryFromTimestamp:, §3.27) and maps them to the Android
//  session shape (see PayloadCodec.sportSessionMap for unit conversions).
//
//  QCSportState raw values (QCDFU_Utils.h L287-294) happen to MATCH the
//  Dart/Android status bytes exactly: 1=start 2=pause 3=continue 4=stop.
//

import Flutter
import Foundation
import QCBandSDK

extension BleManager {
    /// Android parity: returns the ack map on success, `null` (not an error)
    /// when the band rejects — Dart maps null to a null SportSessionAck.
    /// The iOS finish callback's payload shape is undocumented; we echo the
    /// request (like Android echoes it) and surface gpsStatus/timestamp when
    /// a dictionary payload provides them.
    func sendSportStatus(_ status: Int, _ sportType: Int, _ result: @escaping FlutterResult) {
        guard (1...4).contains(status) else { result(nil); return }
        let state = QCSportState(rawValue: UInt32(status))
        let type = OdmSportPlusExerciseModelType(rawValue: sportType)
            ?? OdmSportPlusExerciseModelType(rawValue: 7)! // run fallback, matches Android default
        QCSDKCmdCreator.operateSportMode(with: type, state: state) { payload, error in
            guard error == nil else { result(nil); return }
            let dict = payload as? [String: Any]
            result([
                "status": status,
                "sportType": sportType,
                "gpsStatus": (dict?["gpsStatus"] as? NSNumber)?.intValue ?? 0,
                "timestamp": (dict?["timestamp"] as? NSNumber)?.intValue
                    ?? Int(Date().timeIntervalSince1970),
            ])
        }
    }

    /// Pull every stored SportPlus session (timestamp 0 = all) and wrap them
    /// under Android's {"sessions": [...]} key. Errors → {sessions: []}.
    func syncSportSessions(_ result: @escaping FlutterResult) {
        QCSDKCmdCreator.getSportPlusSummary(fromTimestamp: 0) { summaries, error in
            guard error == nil,
                  let list = summaries as? [OdmGeneralExerciseSummaryModel] else {
                result(["sessions": [[String: Any]]()])
                return
            }
            result(["sessions": list.map { PayloadCodec.sportSessionMap($0) }])
        }
    }
}
