/// Reshapes legacy native BLE response shapes into canonical freezed
/// domain models (hlth-repository-api.md §3, hlth-db-schema.md §3-4).
///
/// The native side still returns SDK-shaped payloads (`{readings:[…]}`,
/// `{stages:[…]}`, etc.). Rather than rewriting Kotlin/Swift now, the
/// canonical envelope is applied at this seam — every health row gets the
/// six mandatory provenance fields here before it touches a repository.
library;

import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/processing/bp_formula.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _algoVersion = 'native-sdk-v1';

int _localTzOffsetMin() => DateTime.now().timeZoneOffset.inMinutes;

DateTime _utcFromMs(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// HR — native shape `{readings: [{timestamp_ms, bpm, slot}], size, index, utcTime}`.
List<HrSample> hrFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  required int hrIntervalMin,
  int? tzOffsetMin,
}) {
  final readings = (native['readings'] as List?) ?? const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  return readings
      .cast<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .where((m) => (m['bpm'] as num?) != null && (m['bpm'] as num) > 0)
      .map((m) => HrSample(
            id: _uuid.v4(),
            userId: userId,
            deviceId: deviceId,
            capturedAt: _utcFromMs((m['timestamp_ms'] as num).toInt()),
            tzOffsetMin: tz,
            bpm: (m['bpm'] as num).toInt(),
            intervalMin: hrIntervalMin,
            isResting: false,
            source: DataSource.bandScheduled,
            algorithmVersion: _algoVersion,
          ))
      .toList();
}

/// SpO2 — native shape: list of `{dateStr, unixTime, minArray[24], maxArray[24]}`
/// where `unixTime` is the start of the day (band-side, often TZ-shifted) and
/// each array index is an hourly bucket. Slots where `min == 0` are dropped
/// (no reading that hour).
List<Spo2Sample> spo2FromNative(
  List<Map<String, dynamic>> native, {
  required String userId,
  required String deviceId,
  int? tzOffsetMin,
}) {
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final out = <Spo2Sample>[];
  for (final day in native) {
    final unixTime = (day['unixTime'] as num?)?.toInt() ?? 0;
    final minArr = (day['minArray'] as List?)?.cast<num>() ?? const [];
    final maxArr = (day['maxArray'] as List?)?.cast<num>() ?? const [];
    if (unixTime == 0 || minArr.isEmpty) continue;
    // Band shifts unix sec by TZ; back it out to land on real UTC.
    final dayStartMs = (unixTime - tz * 60) * 1000;
    for (var i = 0; i < minArr.length; i++) {
      final mn = minArr[i].toInt();
      final mx = i < maxArr.length ? maxArr[i].toInt() : mn;
      if (mn <= 0) continue; // no measurement that hour
      out.add(Spo2Sample(
        id: _uuid.v4(),
        userId: userId,
        deviceId: deviceId,
        capturedAt: _utcFromMs(dayStartMs + i * 60 * 60 * 1000),
        tzOffsetMin: tz,
        pctMin: mn,
        pctMax: mx,
        bucketMin: 60,
        source: DataSource.bandScheduled,
        algorithmVersion: _algoVersion,
      ));
    }
  }
  return out;
}

/// BP per-day — native shape `{readings: [{time, sbp, dbp}]}` from
/// `getBpDay` (BleOperateManager.getBloodPressure / getTodayBloodPressure).
///
/// `time` is a unix timestamp the SDK has already TZ-corrected to UTC:
/// `ReadBlePressureRsp.acceptData` subtracts `Calendar.ZONE_OFFSET` from the
/// band's local-encoded value, so we treat it as a true UTC instant and do
/// NOT re-apply the tz shift (unlike the SpO2/stress day adapters, which get
/// the raw band value). Seconds vs milliseconds is auto-detected by
/// magnitude. Readings with sbp<=0 or dbp<=0 are the band's
/// non-convergence sentinel and are dropped.
///
/// **Idempotency:** `getBpDay` returns the FULL day on every call (not just
/// un-synced samples like the HR history pointer), so a fresh uuid per row
/// would duplicate every reading on the 10-minute sync cadence. Each row
/// instead gets a deterministic id `bpsync:<deviceId>:<epochSec>` so a
/// re-pull of the same reading overwrites via `insertOnConflictUpdate`.
/// Scheduled rows can't collide with manual readings (uuid v4 + a different
/// `source`).
///
/// H59 caveat: the band's BP is an HR-derived estimate; the cuff calibration
/// applied downstream (`calibratedLatestBpProvider`) is what makes the
/// displayed value meaningful. We still store the raw band pair here.
/// BP **timing-monitor** — native shape from `getBpHistory`
/// (`CMD_BP_TIMING_MONITOR_DATA`): `{year, month, day, timeDelay,
/// readings:[{timeMinute, hr}]}`. The band auto-measures once an hour and
/// buffers an HR value per hour, INCLUDING overnight — verified on-device
/// 2026-07-21 (22 hourly readings for a full day incl. 02:00–05:00).
///
/// This is the resilient sleeping-BP source: it's pulled from the band's own
/// buffer each morning (like HR/SpO2/HRV), so it does NOT depend on an
/// on-demand measurement firing mid-sleep or on the background tick timing.
/// H59 BP is an HR+age estimate regardless (even the manual "Measure Now"
/// path), so we convert each hourly HR → sbp/dbp via [BpFormula] — the same
/// `CalcBloodPressureByHeart` model the band uses — and store one reading per
/// hour. Cuff calibration is intentionally NOT applied here (stored raw, like
/// the manual band readings); the display layer calibrates.
///
/// Idempotent via a deterministic `bptiming:<deviceId>:<epochSec>` id, so
/// re-pulling the day's buffer every sync overwrites rather than duplicates.
///
/// `date + timeMinute` is the band's LOCAL wall-clock (same convention as
/// sleep). We build the local instant and convert to true UTC so it lands in
/// the sleep window correctly — NOT the raw-epoch-as-UTC mistake sleep had.
List<BpReading> bpTimingFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  required int age,
  int? tzOffsetMin,
}) {
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final year = (native['year'] as num?)?.toInt() ?? 0;
  final month = (native['month'] as num?)?.toInt() ?? 0;
  final day = (native['day'] as num?)?.toInt() ?? 0;
  final readings = (native['readings'] as List?) ?? const [];
  if (year == 0 || month == 0 || day == 0) return const [];
  final out = <BpReading>[];
  for (final raw in readings) {
    final m = Map<String, dynamic>.from(raw as Map);
    final timeMinute = (m['timeMinute'] as num?)?.toInt() ?? -1;
    final hr = (m['hr'] as num?)?.toInt() ?? 0;
    if (timeMinute < 0 || hr <= 0) continue;
    // Local wall-clock (band convention) → true UTC via the phone's zone.
    final capturedAt =
        DateTime(year, month, day).add(Duration(minutes: timeMinute)).toUtc();
    final sbp = BpFormula.calSbp(hr, age);
    final dbp = BpFormula.calDbp(sbp);
    final epochSec = capturedAt.millisecondsSinceEpoch ~/ 1000;
    out.add(BpReading(
      id: 'bptiming:$deviceId:$epochSec',
      userId: userId,
      deviceId: deviceId,
      capturedAt: capturedAt,
      tzOffsetMin: tz,
      systolicMmhg: sbp,
      diastolicMmhg: dbp,
      // Keep the source HR so cuff calibration (HR-coupled) can recompute the
      // displayed value the same way the headline does.
      pulseBpm: hr,
      derivation: BpDerivation.bandSensor,
      source: DataSource.bandScheduled,
      algorithmVersion: _algoVersion,
    ));
  }
  return out;
}

/// Derive TODAY's hourly BP from live HR samples.
///
/// On H59 the autonomous BP buffer (`CMD_BP_TIMING_MONITOR_DATA`, see
/// [bpTimingFromNative]) only ever serves the last *completed* calendar day —
/// today's in-progress hours never appear until midnight rollover (verified
/// on-device 2026-07-21: a 19:28 sync still returned 07-20's finished day). But
/// H59 BP is just `BpFormula(hr, age)`, and HR history IS live (synced hourly
/// like SpO2/HRV). So we reconstruct today's hourly BP straight from today's
/// HR — giving BP the same freshness as every other metric.
///
/// One reading per LOCAL time-slot (median HR in the slot), stamped at the slot
/// boundary with the SAME `bptiming:<device>:<epoch>` id/source as the buffer
/// path — so when the band's buffer catches up tomorrow it upserts the aligned
/// rows (identical value, no duplicates) rather than doubling them.
///
/// [slotMinutes] is the cadence of the derived points (default 60 = hourly).
/// Set it to 30 to derive a reading every half-hour; the on-the-hour points
/// still align with the band's hourly buffer, the extra :30 points are net-new.
List<BpReading> bpHourlyFromHrSamples(
  List<HrSample> samples, {
  required String userId,
  required String deviceId,
  required int age,
  int? tzOffsetMin,
  int slotMinutes = 60,
}) {
  if (samples.isEmpty) return const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final tzMs = tz * 60 * 1000;
  final slotMs = slotMinutes * 60 * 1000;
  // Bucket HR bpm by the local-clock slot it falls in.
  final buckets = <int, List<int>>{};
  for (final s in samples) {
    if (s.bpm <= 0) continue;
    final localMs = s.capturedAt.millisecondsSinceEpoch + tzMs;
    final slotStartLocalMs = (localMs ~/ slotMs) * slotMs;
    (buckets[slotStartLocalMs] ??= <int>[]).add(s.bpm);
  }
  final out = <BpReading>[];
  final slots = buckets.keys.toList()..sort();
  for (final slotStartLocalMs in slots) {
    final hr = _medianInt(buckets[slotStartLocalMs]!);
    if (hr <= 0) continue;
    // Local slot boundary → true UTC (mirrors bpTimingFromNative's toUtc()).
    final capturedAt = _utcFromMs(slotStartLocalMs - tzMs);
    final sbp = BpFormula.calSbp(hr, age);
    final dbp = BpFormula.calDbp(sbp);
    final epochSec = capturedAt.millisecondsSinceEpoch ~/ 1000;
    out.add(BpReading(
      id: 'bptiming:$deviceId:$epochSec',
      userId: userId,
      deviceId: deviceId,
      capturedAt: capturedAt,
      tzOffsetMin: tz,
      systolicMmhg: sbp,
      diastolicMmhg: dbp,
      pulseBpm: hr,
      derivation: BpDerivation.bandSensor,
      source: DataSource.bandScheduled,
      algorithmVersion: _algoVersion,
    ));
  }
  return out;
}

int _medianInt(List<int> xs) {
  if (xs.isEmpty) return 0;
  final s = [...xs]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) ~/ 2);
}

List<BpReading> bpFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  int? tzOffsetMin,
}) {
  final readings = (native['readings'] as List?) ?? const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final out = <BpReading>[];
  for (final raw in readings) {
    final m = Map<String, dynamic>.from(raw as Map);
    final t = (m['time'] as num?)?.toInt() ?? 0;
    final sbp = (m['sbp'] as num?)?.toInt() ?? 0;
    final dbp = (m['dbp'] as num?)?.toInt() ?? 0;
    if (t <= 0 || sbp <= 0 || dbp <= 0) continue;
    final ms = t > 1000000000000 ? t : t * 1000;
    final epochSec = ms ~/ 1000;
    out.add(BpReading(
      id: 'bpsync:$deviceId:$epochSec',
      userId: userId,
      deviceId: deviceId,
      capturedAt: _utcFromMs(ms),
      tzOffsetMin: tz,
      systolicMmhg: sbp,
      diastolicMmhg: dbp,
      derivation: BpDerivation.bandSensor,
      source: DataSource.bandScheduled,
      algorithmVersion: _algoVersion,
    ));
  }
  return out;
}

/// HRV — native shape `{values: [N samples], intervalMinutes, rawArray}`.
/// Values are placed every `intervalMinutes` from the start of `forDate`.
List<HrvSample> hrvFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  required DateTime forDate,
  int? tzOffsetMin,
}) {
  final values = (native['values'] as List?)?.cast<num>() ?? const [];
  final intervalMin = (native['intervalMinutes'] as num?)?.toInt() ?? 30;
  if (values.isEmpty) return const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();

  // Prefer the band's own day-anchor (HRVRsp.today → getZeroTime()), same
  // semantics as the stress path: unix SECONDS at the band's local midnight
  // (misnamed key kept for symmetry with stress). The band files HRV slots
  // under ITS day, which doesn't always match `now() - dayOffset` — trust it
  // when present (2026-07-08: day-0 sync fixed to the direct HRVReq form,
  // which supplies this anchor).
  final zeroTimeSec = (native['zeroTimeMs'] as num?)?.toInt();
  final DateTime dayStartUtc;
  if (zeroTimeSec != null && zeroTimeSec > 0) {
    dayStartUtc = DateTime.fromMillisecondsSinceEpoch(
      zeroTimeSec * 1000,
      isUtc: true,
    );
  } else {
    // Fallback: anchor on the local midnight of forDate, translated to UTC.
    // Same pattern as DailyAggregator: use DateTime.utc(y,m,d) and subtract
    // tzOffsetMin once. (Using DateTime(y,m,d).toUtc() AND subtracting would
    // shift the window 2× tz_offset backwards — see the aggregator's fix.)
    final localMidnightAsUtc =
        DateTime.utc(forDate.year, forDate.month, forDate.day);
    dayStartUtc = localMidnightAsUtc.subtract(Duration(minutes: tz));
  }

  final out = <HrvSample>[];
  for (var i = 0; i < values.length; i++) {
    final v = values[i].toDouble();
    if (v <= 0) continue; // 0 = no measurement that slot
    out.add(HrvSample(
      id: _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      capturedAt: dayStartUtc.add(Duration(minutes: i * intervalMin)),
      tzOffsetMin: tz,
      rmssdMs: v,
      source: DataSource.bandScheduled,
      algorithmVersion: _algoVersion,
    ));
  }
  return out;
}

/// Stress ("pressure") — native shape:
/// `{values: [N slots 0-100], intervalMinutes, offset, zeroTimeMs, rawArray}`.
///
/// Slot timestamping prefers `zeroTimeMs` from the band's `PressureRsp.today`
/// field — that's the band's own midnight-of-the-day anchor for this batch.
/// Using it correctly handles the H59 wear-day quirk where day 0 (today)
/// is empty and day 1 returns 65+ slots spanning yesterday + today: the
/// band tells us what date the first slot belongs to and we just trust it.
/// Falls back to `now() - dayOffset days` if zeroTimeMs is null (older fw).
List<StressSample> stressFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  required DateTime forDate,
  int? tzOffsetMin,
}) {
  final values = (native['values'] as List?)?.cast<num>() ?? const [];
  final intervalMin = (native['intervalMinutes'] as num?)?.toInt() ?? 30;
  if (values.isEmpty) return const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();

  // Prefer band-supplied anchor. SDK's `DateUtil.getZeroTime()` returns
  // unix SECONDS at the band's local midnight (despite the name, it's
  // not ms — verified 2026-06-12 with bandDay=2026-6-11 zeroTime=1781107200
  // which is 2026-06-10 16:00 UTC, i.e. 2026-06-11 00:00 in UTC+8 local).
  // Multiply by 1000 to get a UTC instant; that IS dayStartUtc for slots.
  final zeroTimeSec = (native['zeroTimeMs'] as num?)?.toInt();
  final DateTime dayStartUtc;
  if (zeroTimeSec != null && zeroTimeSec > 0) {
    dayStartUtc = DateTime.fromMillisecondsSinceEpoch(
      zeroTimeSec * 1000,
      isUtc: true,
    );
  } else {
    final localMidnightAsUtc =
        DateTime.utc(forDate.year, forDate.month, forDate.day);
    dayStartUtc = localMidnightAsUtc.subtract(Duration(minutes: tz));
  }

  final out = <StressSample>[];
  for (var i = 0; i < values.length; i++) {
    final v = values[i].toInt();
    if (v <= 0) continue; // 0 = no measurement that slot
    if (v > 100) continue; // out of range — band protocol caps at 100
    out.add(StressSample(
      id: _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      capturedAt: dayStartUtc.add(Duration(minutes: i * intervalMin)),
      tzOffsetMin: tz,
      stressScore: v,
      rangeMin: intervalMin,
      source: DataSource.bandScheduled,
      algorithmVersion: _algoVersion,
    ));
  }
  return out;
}

/// 15-minute step buckets — native shape: list of
///   `{year, month, day, timeIndex (0-95), walkSteps, runSteps, calorie, distance}`.
///
/// Each bucket represents 15 minutes anchored at `timeIndex * 15` minutes
/// past local midnight of (year, month, day). H59 firmware uses meters for
/// `distance`. `calorie` units are not documented in the SDK — empirically
/// the value is much larger than kcal for the same period (the daily-total
/// path returned 64021 for ~640 active kcal), so we treat it as
/// milli-kcal (kcal × 1000) and divide accordingly. Adjust if cross-check
/// against the band's own UI shows a different unit.
List<StepBucket> stepBucketsFromNative(
  List<Map<String, dynamic>> native, {
  required String userId,
  required String deviceId,
  int? tzOffsetMin,
}) {
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final out = <StepBucket>[];
  for (final raw in native) {
    final year = (raw['year'] as num?)?.toInt() ?? 0;
    final month = (raw['month'] as num?)?.toInt() ?? 0;
    final day = (raw['day'] as num?)?.toInt() ?? 0;
    final timeIndex = (raw['timeIndex'] as num?)?.toInt() ?? -1;
    if (year == 0 || month == 0 || day == 0 || timeIndex < 0) continue;
    final walkSteps = (raw['walkSteps'] as num?)?.toInt() ?? 0;
    final runSteps = (raw['runSteps'] as num?)?.toInt() ?? 0;
    final totalSteps = walkSteps + runSteps;
    if (totalSteps <= 0) continue; // skip empty buckets to keep DB tidy
    // Convert local (Y/M/D + timeIndex × 15min) to a UTC instant.
    final localBucketAsUtc = DateTime.utc(year, month, day)
        .add(Duration(minutes: timeIndex * 15));
    final bucketStartUtc =
        localBucketAsUtc.subtract(Duration(minutes: tz));
    out.add(StepBucket(
      id: _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      bucketStartAt: bucketStartUtc,
      tzOffsetMin: tz,
      steps: totalSteps,
      distanceM: (raw['distance'] as num?)?.toInt() ?? 0,
      caloriesKcal: ((raw['calorie'] as num?)?.toDouble() ?? 0) / 1000.0,
      runSteps: runSteps,
      source: DataSource.bandScheduled,
    ));
  }
  return out;
}

/// Steps daily total — native shape includes `{year, month, day, daysAgo,
/// totalSteps, runningSteps, calorie, walkDistance, sportDurationSec}`.
/// Returns a DailyMetrics row keyed by (userId, localDate).
DailyMetrics? dailyStepsFromNative(
  Map<String, dynamic> native, {
  required String userId,
  int? tzOffsetMin,
}) {
  final year = (native['year'] as num?)?.toInt() ?? 0;
  final month = (native['month'] as num?)?.toInt() ?? 0;
  final day = (native['day'] as num?)?.toInt() ?? 0;
  if (year == 0 || month == 0 || day == 0) return null;
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final now = DateTime.now().toUtc();
  return DailyMetrics(
    id: _uuid.v4(),
    userId: userId,
    localDate: DateTime(year, month, day),
    tzOffsetMin: tz,
    steps: (native['totalSteps'] as num?)?.toInt(),
    distanceM: (native['walkDistance'] as num?)?.toInt(),
    caloriesKcal: (native['calorie'] as num?)?.toDouble(),
    activeMinutes: ((native['sportDurationSec'] as num?)?.toInt() ?? 0) ~/ 60,
    computedAt: now,
    algorithmVersion: _algoVersion,
    source: DataSource.bandScheduled,
  );
}

/// Sleep — native shape (BleManager.syncSleep, post-2026-05-29):
///   `{totalSleepDuration, deepDuration, shallowDuration, awakeDuration,
///     rapidDuration, sleepTime, wakeTime, wakingCount,
///     stages: [{sleepStart, sleepEnd, type}]}`
///
/// SDK stage code (`type`) per `SleepDisplay.SleepDataBean`:
///   1=deep, 2=light/shallow, 3=awake/wake, 4=rem, 5=no_sleep/no_wear.
///
/// **Units**: H59 firmware returns durations in SECONDS despite SDK naming.
/// Verified: `totalSleepDuration=31860` for a session of length
/// `wakeTime − sleepTime = 31860 s`, and the four parts (deep 5400 + shallow
/// 18840 + rapid 6720 + awake 900) sum exactly to 31860 — only consistent
/// with seconds. Convert to minutes for the canonical schema.
///
/// `sleepTime` / `wakeTime` are unix seconds. Per-stage `sleepStart` /
/// `sleepEnd` are long; we auto-detect seconds vs milliseconds by magnitude
/// (a unix timestamp in seconds is ~1.7e9; in ms it's ~1.7e12).
({SleepSession session, List<SleepEpoch> epochs})? sleepFromNative(
  Map<String, dynamic> native, {
  required String userId,
  required String deviceId,
  int? tzOffsetMin,
}) {
  final stagesRaw = (native['stages'] as List?) ?? const [];
  final tz = tzOffsetMin ?? _localTzOffsetMin();
  final sleepSec = (native['sleepTime'] as num?)?.toInt() ?? 0;
  final wakeSec = (native['wakeTime'] as num?)?.toInt() ?? 0;
  if (sleepSec == 0 || wakeSec == 0) return null;

  // TZ frame fix (2026-07-21): the band encodes sleepTime/wakeTime as LOCAL
  // wall-clock stuffed into a unix field — the SAME encoding the SpO2/stress
  // day adapters already back out (`unixTime - tz*60`), and which the HRV/
  // stress `zeroTime` anchor resolves to true-UTC local midnight. Sleep alone
  // used to store the raw value AS-IS, leaving the session window tz-shifted
  // (+8h in Asia/Manila — verified via logcat: sleepTime=1784581440 rendered
  // as a bogus 05:04 bedtime; HRV zeroTimeMs=1784563200 = true-UTC local
  // midnight). That shift made the Sleep screen's "Measured during sleep"
  // query a window that never overlapped the correctly-placed SpO2/HRV
  // samples, so those tiles read `--` even though the raw samples existed.
  // Back the tz out here so the window is true-UTC and aligns with every
  // other metric.
  final tzSec = tz * 60;
  final startedAt = _utcFromMs((sleepSec - tzSec) * 1000);
  final endedAt = _utcFromMs((wakeSec - tzSec) * 1000);

  int secToMin(num? v) => ((v ?? 0).toInt() / 60).round();
  final totalMin = secToMin(native['totalSleepDuration']);
  final deepMin = secToMin(native['deepDuration']);
  final lightMin = secToMin(native['shallowDuration']);
  final remMin = secToMin(native['rapidDuration']);
  final awakeMin = secToMin(native['awakeDuration']);

  // Deterministic id keyed on the band's RAW sleep-start epoch (pre-tz-shift)
  // so the SAME night upserts in place instead of inserting a fresh row on
  // every sync. "Sync All Sleep" pulls 8 day-offsets that can return the same
  // night, and each periodic sync re-pulls it — with a uuid.v4() id
  // createSession's upsert-by-id never collided, which is what bloated the
  // table (observed: 64 rows for ~6 nights). Mirrors the BP sync's
  // `bpsync:<deviceId>:<epochSec>` idempotency pattern. NOTE: since the
  // 2026-07-21 tz fix, `started_at_utc == sleepSec - tz*60`, so the id
  // intentionally NO LONGER equals `sleepsync:<device>:<started_at_utc>`.
  // Keeping the id on the raw band `sleepSec` is deliberate: it stays stable
  // across the fix, so re-syncing the last ~7 days (band retention) upserts in
  // place and HEALS the previously tz-shifted timestamps. The historical v11
  // dedup migration assumed id==started_at_utc; it ran once and is unaffected.
  // Do NOT reconstruct sleepSec from started_at_utc going forward.
  final sessionId = 'sleepsync:$deviceId:$sleepSec';
  final epochs = <SleepEpoch>[];
  // Accumulators used to derive session-level fields the schema reserves
  // (`coverageGapMin`, `hasUnweared`, `protocolVersion`) but the band
  // doesn't return directly. We walk the epoch list once here instead of
  // re-iterating downstream.
  var coverageGapMin = 0;
  var hasUnweared = false;
  var sawRemEpoch = false;
  for (final raw in stagesRaw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final start = (m['sleepStart'] as num?)?.toInt() ?? 0;
    final end = (m['sleepEnd'] as num?)?.toInt() ?? 0;
    final type = (m['type'] as num?)?.toInt() ?? 0;
    if (start <= 0 || end <= start) continue;
    // Auto-detect ms vs sec by magnitude, then back out the SAME tz shift as
    // the session bounds above so epochs stay in the session's (true-UTC)
    // frame. If only the session were shifted, each epoch would sit tz*60 off
    // its true position and the hypnogram would render skewed against the
    // bedtime~wake header.
    final inMs = start > 1e12;
    final startMs = (inMs ? start : start * 1000) - tzSec * 1000;
    final endMs = (inMs ? end : end * 1000) - tzSec * 1000;
    final durMin = ((endMs - startMs) / 60000).round();
    if (durMin <= 0) continue;
    final stage = _sleepStage(type);
    if (stage == SleepStage.unweared || stage == SleepStage.noSleep) {
      // Per hlth-db-schema.md §4.3: coverageGapMin is the unweared time
      // *within* the sleep window. Type 5 (no_sleep/no_wear) is the
      // canonical signal for that. Type 4 (REM) only fires on
      // protocol v2 firmware, so its presence tells us the band is on
      // the new protocol.
      coverageGapMin += durMin;
      hasUnweared = true;
    }
    if (stage == SleepStage.rem) sawRemEpoch = true;
    epochs.add(SleepEpoch(
      // Deterministic per (session, epoch-start) so re-syncing the same night
      // overwrites its epochs in place rather than accumulating (paired with
      // the deterministic sessionId + insertEpochs' delete-then-insert).
      id: '$sessionId:$startMs',
      sessionId: sessionId,
      userId: userId,
      startedAt: _utcFromMs(startMs),
      durationMin: durMin,
      stage: stage,
      source: DataSource.bandScheduled,
    ));
  }

  // Protocol detection: H59 firmware exposes REM only on v2 ("new sleep
  // protocol", per sdk_ring.pdf §4 `SetTimeRsp.mNewSleepProtocol`).
  // Rather than thread the bootstrap flag through the platform channel,
  // we infer from the payload — if either the rolled-up REM minutes are
  // non-zero or any epoch is type=4 (REM), the band is on v2.
  final isNewProtocol = remMin > 0 || sawRemEpoch;
  final protocolVersion = isNewProtocol ? 2 : 1;

  final session = SleepSession(
    id: sessionId,
    userId: userId,
    deviceId: deviceId,
    startedAt: startedAt,
    endedAt: endedAt,
    tzOffsetMin: tz,
    type: SleepSessionType.night,
    protocolVersion: protocolVersion,
    totalMin: totalMin,
    deepMin: deepMin,
    lightMin: lightMin,
    remMin: remMin,
    awakeMin: awakeMin,
    coverageGapMin: coverageGapMin,
    hasUnweared: hasUnweared,
    source: DataSource.bandScheduled,
  );
  return (session: session, epochs: epochs);
}

SleepStage _sleepStage(int code) {
  switch (code) {
    case 1:
      return SleepStage.deep;
    case 2:
      return SleepStage.light;
    case 3:
      return SleepStage.awake;
    case 4:
      return SleepStage.rem;
    case 5:
      return SleepStage.noSleep;
    default:
      return SleepStage.noSleep;
  }
}
