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

    // MARK: - SpO2 history (getSpO2Day / getSpO2History)

    /// QCBloodOxygenModel[] → ONE per-day entry of Android's SpO2 list shape:
    /// {dateStr, unixTime, minArray[24], maxArray[24]}.
    ///
    /// Android's CMD returns hourly min/max arrays; the iOS SDK returns
    /// individual timestamped measurements — so we bucket them into 24 hourly
    /// slots ourselves. Dart (spo2FromNative) skips days where unixTime==0 or
    /// minArray is empty, and files one sample per non-zero hour slot.
    /// Returns nil when the day has no usable measurements.
    static func spo2DayEntry(_ models: [QCBloodOxygenModel], dayOffset: Int) -> [String: Any]? {
        guard !models.isEmpty else { return nil }
        var minArr = [Int](repeating: 0, count: 24)
        var maxArr = [Int](repeating: 0, count: 24)
        let cal = Calendar.current
        var any = false
        for m in models {
            guard let d = m.date else { continue }
            let hour = cal.component(.hour, from: d)
            guard (0..<24).contains(hour) else { continue }
            let lo = Int(m.minSoa2 > 0 ? m.minSoa2 : m.soa2)
            let hi = Int(m.maxSoa2 > 0 ? m.maxSoa2 : m.soa2)
            guard hi > 0 else { continue }
            any = true
            minArr[hour] = minArr[hour] == 0 ? lo : min(minArr[hour], lo)
            maxArr[hour] = max(maxArr[hour], hi)
        }
        guard any else { return nil }
        let dayStart = localMidnight(dayOffset: dayOffset)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return [
            "dateStr": f.string(from: dayStart),
            "unixTime": Int(dayStart.timeIntervalSince1970),
            "minArray": minArr,
            "maxArray": maxArr,
        ]
    }

    // MARK: - BP day (getBpDay)

    /// QCBloodPressureModel[] filtered to the requested local day →
    /// Android's {readings:[{time,sbp,dbp}]} shape. `time` is unix SECONDS
    /// (Dart bpFromNative multiplies by 1000). Callers pass ALL history and
    /// we filter here because the iOS SDK has no per-day scheduled-BP read.
    static func bpDayPayload(_ models: [QCBloodPressureModel], dayOffset: Int) -> [String: Any] {
        let dayStart = localMidnight(dayOffset: dayOffset)
        let dayEnd = dayStart.addingTimeInterval(24 * 3600)
        var readings: [[String: Any]] = []
        for m in models {
            guard let d = m.date, d >= dayStart, d < dayEnd else { continue }
            guard m.systolicPressure > 0, m.diastolicPressure > 0 else { continue }
            readings.append([
                "time": Int(d.timeIntervalSince1970),
                "sbp": m.systolicPressure,
                "dbp": m.diastolicPressure,
            ])
        }
        return ["readings": readings]
    }

    // MARK: - Daily totals (getDailyTotals)

    /// QCSportModel (current-day totals) → Android's getDailyTotals map.
    /// Android fields sourced from CMD_GET_STEP_TODAY; iOS equivalents:
    ///   totalSteps=totalStepCount, runningSteps=runStepCount,
    ///   calorie=kcal (adapter passes daily calorie through unscaled),
    ///   walkDistance=meters, sportDurationSec=activeTime(min)*60.
    /// sleepDurationSec has no iOS source here → 0 (adapter doesn't read it).
    static func dailyTotalsPayload(_ sport: QCSportModel) -> [String: Any] {
        let now = Date()
        let cal = Calendar.current
        return [
            "year": cal.component(.year, from: now),
            "month": cal.component(.month, from: now),
            "day": cal.component(.day, from: now),
            "daysAgo": 0,
            "totalSteps": sport.totalStepCount,
            "runningSteps": sport.runStepCount,
            "calorie": Int(sport.calories),
            "walkDistance": sport.distance,
            "sportDurationSec": sport.activeTime * 60,
            "sleepDurationSec": 0,
        ]
    }

    // MARK: - Step buckets (getStepBucketHistory / getStepDay)

    /// Per-bucket QCSportModel[] → Android's 15-min bin list:
    /// [{year,month,day,timeIndex,walkSteps,runSteps,calorie,distance}].
    /// timeIndex = minutes-since-midnight / 15 (0-95), derived from
    /// happenDate "yyyy-MM-dd HH:mm:ss".
    /// calorie: Dart (stepBucketsFromNative) divides by 1000 → we emit
    /// milli-kcal (QCSportModel.calories is kcal → ×1000).
    static func stepBucketList(_ sports: [QCSportModel]) -> [[String: Any]] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = .current
        let cal = Calendar.current
        var out: [[String: Any]] = []
        for s in sports {
            guard s.totalStepCount > 0 else { continue } // Android skips empty bins
            guard let d = f.date(from: s.happenDate ?? "") else { continue }
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
            let timeIndex = ((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) / 15
            let run = min(s.runStepCount, s.totalStepCount)
            out.append([
                "year": comps.year ?? 0,
                "month": comps.month ?? 0,
                "day": comps.day ?? 0,
                "timeIndex": timeIndex,
                "walkSteps": s.totalStepCount - run,
                "runSteps": run,
                "calorie": Int(s.calories * 1000),
                "distance": s.distance,
            ])
        }
        return out
    }

    // MARK: - Sport sessions (syncSportSessions)

    /// OdmGeneralExerciseSummaryModel → Android's per-session map. Unit
    /// conversions: speeds m/s → cm/s (×100), altitude/hill m → cm (×100).
    static func sportSessionMap(_ s: OdmGeneralExerciseSummaryModel) -> [String: Any] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        let start = Date(timeIntervalSince1970: s.startTime)
        return [
            "sportType": s.exerciseType,
            "startTime": Int(s.startTime),
            "trainingStartTime": f.string(from: start),
            "duration": s.duration,
            "distance": s.distance,
            "calories": Double(s.calorie),
            "speedAvg": Int(s.averageSpeed * 100),
            "speedMax": Int(s.fastestSpeed * 100),
            "rateAvg": s.averageHR,
            "rateMin": s.lowestHR,
            "rateMax": s.highestHR,
            "elevation": Int(s.averageAltitude * 100),
            "uphill": Int(s.upHillDistance * 100),
            "downhill": Int(s.downHillDistance * 100),
            "stepRate": s.averageStepFrequency,
            "steps": s.steps,
            "sportCount": 0,
            "locationCount": s.detail?.gpsLocations?.count ?? 0,
        ]
    }

    // MARK: - Raw PPG frames (startMeasureHrRaw / startMeasureSpo2Raw)

    /// QCBloodGlucoseHeartRateRawModel[] → per-sample maps matching Android's
    /// hlth/realtime_stream payload. The iOS SDK delivers the whole burst in
    /// the completion callback (Android streams per-packet), so timestamps
    /// are synthesized backwards from "now" at 25 Hz (40 ms spacing) — the
    /// fall detector only uses count/duration, and PpgSample only needs
    /// monotonic timestamp_ms.
    /// PPG + accel arrive as split hi/lo bytes → reassemble; accel is a
    /// signed int16 (raw counts).
    static func ppgSampleMaps(_ frames: [QCBloodGlucoseHeartRateRawModel]) -> [[String: Any]] {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let startMs = nowMs - frames.count * 40
        var out: [[String: Any]] = []
        out.reserveCapacity(frames.count)
        for (i, r) in frames.enumerated() {
            out.append([
                "timestamp_ms": startMs + i * 40,
                "ppg_count": r.ppgCount,
                "green": ((r.greenLightPpgH & 0xFF) << 8) | (r.greenLightPpgL & 0xFF),
                "red": 0,
                "infrared": 0,
                "heart": r.value,
                "rri": 0,
                "hrv": 0,
                "accel_x": signedInt16(high: r.xAxisH, low: r.xAxisL),
                "accel_y": signedInt16(high: r.yAxisH, low: r.yAxisL),
                "accel_z": signedInt16(high: r.zAxisH, low: r.zAxisL),
            ])
        }
        return out
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
