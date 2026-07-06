import Foundation
import QCBandSDK

enum PayloadCodec {
    /// Android's unixSecondsWithTzOffset(): now + local tz offset, in seconds.
    static func unixSecondsWithTzOffset(_ date: Date = Date()) -> Int {
        let now = Int(date.timeIntervalSince1970)
        let tz = TimeZone.current.secondsFromGMT(for: date)
        return now + tz
    }

    /// Combine two unsigned bytes into a signed Int16 (Android signedInt16()).
    static func signedInt16(high: Int, low: Int) -> Int {
        let combined = ((high & 0xFF) << 8) | (low & 0xFF)
        return combined > 32767 ? combined - 65536 : combined
    }

    /// "yyyy-MM-dd HH:mm:ss" → epoch ms (QCSleepModel.happenDate uses this).
    static func epochMs(from str: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = .current
        return Int((f.date(from: str)?.timeIntervalSince1970 ?? 0) * 1000)
    }

    /// QCSleepModel.type (SLEEPTYPE) → Android type code:
    /// Android: 1=deep, 2=light, 3=wake, 4=rem, 5=no_sleep/no_wear.
    ///
    /// Switch on the raw NSInteger value rather than the Swift-imported case
    /// names: SLEEPTYPE is an NS_ENUM with common prefix "SLEEPTYPE", so the
    /// importer renames the cases (.deep/.light/…) — matching on rawValue is
    /// stable regardless of that renaming.
    /// Raw values (QCSleepModel.h): NONE=0, SOBER=1, LIGHT=2, DEEP=3, REM=4, UNWEARED=5.
    static func sleepTypeCode(_ t: SLEEPTYPE) -> Int {
        switch t.rawValue {
        case 3: return 1  // DEEP  → deep
        case 2: return 2  // LIGHT → light
        case 1: return 3  // SOBER → wake
        case 4: return 4  // REM   → rem
        case 5: return 5  // UNWEARED → no-wear
        default: return 5 // NONE / unknown → no-wear
        }
    }

    /// Local midnight (00:00) of (today - dayOffset) as a Date.
    /// dayOffset 0 = today, 1 = yesterday, etc. Mirrors the SDK's day-index
    /// semantics used by the history fetch APIs.
    static func localMidnight(dayOffset: Int, now: Date = Date()) -> Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: -dayOffset, to: startOfToday) ?? startOfToday
    }

    /// "yyyy-MM-dd" (local) → start-of-day epoch milliseconds.
    /// QCSchedualHeartRateModel.date / QCHRVModel.date / QCStressModel.date.
    static func dayStartMs(fromDateString str: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        guard let d = f.date(from: str) else { return 0 }
        // f.date(from:) already lands on local 00:00 for a date-only string.
        return Int(d.timeIntervalSince1970 * 1000)
    }

    // MARK: - Task 6: Sleep

    /// QCSleepModel[] → Android getSleepHistory payload.
    /// Durations in SECONDS (QCSleepModel.total is minutes → ×60).
    /// stages carry epoch-ms start/end; sleepTime/wakeTime are unix SECONDS.
    /// Dart (sync_adapters.sleepFromNative) returns null when
    /// sleepTime==0 || wakeTime==0, and auto-detects ms-vs-sec on stage bounds.
    static func sleepPayload(_ models: [QCSleepModel]) -> [String: Any] {
        var stages: [[String: Any]] = []
        var deep = 0, light = 0, rem = 0, awake = 0
        var minStart = Int.max, maxEnd = 0, wakingCount = 0
        for m in models {
            let start = epochMs(from: m.happenDate)
            let end = epochMs(from: m.endTime)
            let code = sleepTypeCode(m.type)
            stages.append(["sleepStart": start, "sleepEnd": end, "type": code])
            let sec = Int(m.total) * 60
            switch code {
            case 1: deep += sec
            case 2: light += sec
            case 4: rem += sec
            case 3: awake += sec; wakingCount += 1
            default: break
            }
            if start > 0 { minStart = min(minStart, start) }
            maxEnd = max(maxEnd, end)
        }
        // totalSleepDuration = asleep time only (deep + light + rem), matching
        // Android's intent; Dart converts seconds → minutes downstream.
        let total = deep + light + rem
        return [
            "totalSleepDuration": total,
            "deepDuration": deep,
            "shallowDuration": light,
            "awakeDuration": awake,
            "rapidDuration": rem,
            "sleepTime": minStart == Int.max ? 0 : minStart / 1000,
            "wakeTime": maxEnd / 1000,
            "wakingCount": wakingCount,
            "stages": stages,
        ]
    }

    // MARK: - Task 7: Scheduled HR

    /// Empty getHrHistory shape (returned on fail / no model).
    static func emptyHr() -> [String: Any] {
        return [
            "endFlag": true,
            "index": 0,
            "size": 0,
            "utcTime": 0,
            "readings": [[String: Any]](),
            "rawArray": [Int](),
        ]
    }

    /// QCSchedualHeartRateModel → Android getHrHistory payload.
    /// slot i → timestamp_ms = dayStartMs + i*secondInterval*1000.
    /// readings drop zero-bpm slots; rawArray keeps every byte (clamped 0-255).
    /// Dart (sync_adapters.hrFromNative) reads readings[].timestamp_ms/bpm only.
    static func hrPayload(_ model: QCSchedualHeartRateModel) -> [String: Any] {
        let dayStartMs = dayStartMs(fromDateString: model.date ?? "")
        let interval = max(1, model.secondInterval)
        let rates = model.heartRates ?? []
        var readings: [[String: Any]] = []
        var rawArray: [Int] = []
        for (i, n) in rates.enumerated() {
            let bpm = n.intValue
            rawArray.append(max(0, min(255, bpm)))
            if bpm > 0 {
                readings.append([
                    "timestamp_ms": dayStartMs + i * interval * 1000,
                    "bpm": bpm,
                    "slot": i,
                ])
            }
        }
        return [
            "endFlag": true,
            "index": 0,
            "size": rates.count,
            "utcTime": dayStartMs / 1000,
            "readings": readings,
            "rawArray": rawArray,
        ]
    }

    // MARK: - Task 8: HRV

    /// QCHRVModel? → Android getHrvHistory payload.
    /// CRITICAL: raw bytes ARE RMSSD in ms — do NOT divide by 10.
    /// Dart (sync_adapters.hrvFromNative) reads values:[num] + intervalMinutes,
    /// filters v<=0, and anchors slots on local midnight of forDate.
    static func hrvPayload(_ model: QCHRVModel?) -> [String: Any] {
        let raw = (model?.hrv ?? []).map { $0.intValue }
        let interval = model?.secondInterval ?? 0
        let intervalMinutes = interval > 0 ? interval / 60 : 30
        return [
            "values": raw.map { Double($0) }, // NO /10 — bytes are already RMSSD ms.
            "intervalMinutes": intervalMinutes,
            "rawArray": raw,
        ]
    }

    // MARK: - Task 9: Stress

    /// QCStressModel? → Android getStressDay payload.
    /// `zeroTimeMs` is consumed by Dart (stressFromNative) as unix SECONDS
    /// (it multiplies by 1000), despite the key name — so we emit SECONDS here.
    /// `dayOffset` lets us anchor zeroTimeMs on the day's local midnight even
    /// when the model omits a usable date string.
    static func stressPayload(_ model: QCStressModel?, dayOffset: Int) -> [String: Any] {
        let raw = (model?.stresses ?? []).map { $0.intValue }
        let interval = model?.secondInterval ?? 0
        let intervalMinutes = interval > 0 ? interval / 60 : 30
        // Prefer the model's own date string; fall back to today-dayOffset.
        var zeroTimeSec = 0
        if let ds = model?.date, !ds.isEmpty {
            zeroTimeSec = dayStartMs(fromDateString: ds) / 1000
        }
        if zeroTimeSec == 0 {
            zeroTimeSec = Int(localMidnight(dayOffset: dayOffset).timeIntervalSince1970)
        }
        return [
            "values": raw,
            "intervalMinutes": intervalMinutes,
            "offset": 0,
            "zeroTimeMs": zeroTimeSec, // unix SECONDS (Dart re-multiplies by 1000)
            "rawArray": raw,
        ]
    }
}
