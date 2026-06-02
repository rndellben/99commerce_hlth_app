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
  // Anchor on the local midnight of forDate, then translate to UTC.
  // Same pattern as DailyAggregator: use DateTime.utc(y,m,d) and subtract
  // tzOffsetMin once. (Using DateTime(y,m,d).toUtc() AND subtracting would
  // shift the window 2× tz_offset backwards — see the aggregator's fix.)
  final localMidnightAsUtc =
      DateTime.utc(forDate.year, forDate.month, forDate.day);
  final dayStartUtc = localMidnightAsUtc.subtract(Duration(minutes: tz));

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

  final startedAt = _utcFromMs(sleepSec * 1000);
  final endedAt = _utcFromMs(wakeSec * 1000);

  int secToMin(num? v) => ((v ?? 0).toInt() / 60).round();
  final totalMin = secToMin(native['totalSleepDuration']);
  final deepMin = secToMin(native['deepDuration']);
  final lightMin = secToMin(native['shallowDuration']);
  final remMin = secToMin(native['rapidDuration']);
  final awakeMin = secToMin(native['awakeDuration']);

  final sessionId = _uuid.v4();
  final epochs = <SleepEpoch>[];
  for (final raw in stagesRaw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final start = (m['sleepStart'] as num?)?.toInt() ?? 0;
    final end = (m['sleepEnd'] as num?)?.toInt() ?? 0;
    final type = (m['type'] as num?)?.toInt() ?? 0;
    if (start <= 0 || end <= start) continue;
    // Auto-detect ms vs sec by magnitude.
    final inMs = start > 1e12;
    final startMs = inMs ? start : start * 1000;
    final endMs = inMs ? end : end * 1000;
    final durMin = ((endMs - startMs) / 60000).round();
    if (durMin <= 0) continue;
    epochs.add(SleepEpoch(
      id: _uuid.v4(),
      sessionId: sessionId,
      userId: userId,
      startedAt: _utcFromMs(startMs),
      durationMin: durMin,
      stage: _sleepStage(type),
      source: DataSource.bandScheduled,
    ));
  }

  final session = SleepSession(
    id: sessionId,
    userId: userId,
    deviceId: deviceId,
    startedAt: startedAt,
    endedAt: endedAt,
    tzOffsetMin: tz,
    type: SleepSessionType.night,
    protocolVersion: 1,
    totalMin: totalMin,
    deepMin: deepMin,
    lightMin: lightMin,
    remMin: remMin,
    awakeMin: awakeMin,
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
