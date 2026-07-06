# API Reference — `BleService` (Dart)

The public Dart surface of the native bridge. This is the **frozen contract**
every feature uses; it maps 1:1 onto the platform channels
([FLUTTER_PLATFORM_CHANNELS.md](FLUTTER_PLATFORM_CHANNELS.md)). Source:
[`lib/core/ble/ble_service.dart`](../lib/core/ble/ble_service.dart).

Access via `ref.read(bleServiceProvider)` (or `ref.watch` for streams). All
`Future`s throw `PlatformException` on native failure; connection results are
delivered asynchronously via streams, not return values.

## Streams (reactive)

| Getter | Type | Emits |
|---|---|---|
| `connectionState` | `Stream<BleConnectionState>` | connected / disconnected / connecting |
| `realtimeHeartRate` | `Stream<int>` | 5-s-smoothed HR from scheduled `dataType=1` notifies |
| `heartRateMeasured` | `Stream<int>` | active-measurement HR |
| `battery` | `Stream<BatteryStatus>` | level + charging |
| `ppgData` | `Stream<...>` (`hlth/realtime_stream`) | raw PPG packets during raw capture |
| `periodicSyncTick` | `Stream<int>` | native scheduler cadence (minutes) |
| plus | | spo2 / hrv / bp / one-key / deviceNotify streams |

## Connection & scan

```dart
Future<List<BleDevice>> startScan();      // ~10s window → [{id,name,rssi}]
Future<void> stopScan();
Future<void> connect(String deviceId);    // optimistic; watch connectionState
Future<void> disconnect();
```

## Monitoring config

```dart
Future<Map<String,dynamic>> setScheduledMonitoring({
  int hrInterval = 10, int startInterval = 5, int spo2Interval = 60,
  int hrvInterval = 30, int bpIntervalMinutes = 60,
});                                        // enable band recording (see quirk)
Future<Map<String,dynamic>> getScheduledHr();          // read-back = ground truth
Future<Map<String,dynamic>> setBpScheduled({...}) / getBpScheduled();
Future<Map<String,dynamic>> setStressScheduled({...}) / getStressScheduled();
Future<int?> getSyncIntervalMinutes();     // + setSyncIntervalMinutes(int 5..60)
Future<bool> setPersonalInfo({age, sex, heightCm, weightKg, ...});
```

> **Quirk:** `setScheduledMonitoring` write-ack is unreliable on H59; confirm
> via read-back or overnight sample count. Auto-called on connect edge.

## History pulls

```dart
Future<Map<String,dynamic>> getHrHistory({int dayOffset = 0});     // {readings:[{time,bpm,...}]}
Future<Map<String,dynamic>> getHrvHistory({int dayOffset = 0});    // pull 0 AND 1 (H59 index quirk)
Future<Map<String,dynamic>> getSpO2History(...) / getSpO2Day(...);
Future<Map<String,dynamic>> getSleepHistory({int dayOffset = 0});
Future<Map<String,dynamic>> getDailyTotals();                      // steps/cal/dist/active
Future<List<Map<String,dynamic>>> getStepDay(...) / getStepBucketHistory(...);
Future<Map<String,dynamic>> getStressDay({int dayOffset = 0});
Future<Map<String,dynamic>> getBpHistory();                        // limited on H59
Future<Map<String,dynamic>> getBpDay({int dayOffset = 0});         // TIMES OUT on H59 (-4001)
```

## Active measurements

```dart
Future<Map<String,dynamic>> startMeasureHrRaw({...});  // raw PPG+accel stream; stopMeasure()
Future<Map<String,dynamic>> startBpMeasurement();      // only working BP path on H59; stopBpMeasurement()
Future<Map<String,dynamic>> startHeartStream();        // stopHeartStream()
Future<Map<String,dynamic>> startHrvStream();          // stopHrvStream()
Future<Map<String,dynamic>> startOneKeyMeasurement();  // stopOneKeyMeasurement()
// + startMeasureSpo2Raw / stopMeasureSpo2Raw, startSpo2Stream / stopSpo2Stream
```

## Sport mode (workouts)

```dart
Future<SportSessionAck?> startSportMode({required int sportType});   // 4=Walk 7=Run 9=Cycle 8=Hike 26=Elliptical 27=Row 22=Yoga 88=Strength
Future<SportSessionAck?> pauseSportMode / resumeSportMode / endSportMode({required int sportType});
Future<List<SportSessionSummary>> syncSportSessions();               // avg/min/max HR, distance, speed, calories, steps, stepRate
```

## Key domain models

| Model | Fields (essentials) | Source |
|---|---|---|
| `BleDevice` | id, name, rssi | scan result |
| `SportSessionSummary` | sportType, startTimeUnixSec, durationSec, distanceM, calories, avgSpeedCmS, maxSpeedCmS, avgHr, minHr, maxHr, steps, stepRate, elevation | workout pull |
| `Score` | id, userId, scoreType, computedForDate, score, rawScore, label, confidence, provisional, components(map), computedAt, algorithmVersion | [score.dart](../lib/core/models/score.dart) |
| `DailyMetrics` | restingHrBpm, hrvRmssdMs/SdnnMs, restingRespRateBpm, spo2Overnight*, sleep* (total/deep/rem/light pct, bedtime/wake, efficiency), steps/activeMinutes/calories, systolic/diastolic | [daily_metrics.dart](../lib/core/models/daily_metrics.dart) |
| `ExerciseSession` | sportType, started/endedAt, durationSec, distanceM, calories, avg/min/maxHrBpm, avgSpeedCmS, steps, **vo2maxMl, vo2Confidence** | [exercise_session.dart](../lib/core/models/exercise_session.dart) |
| `UserProfile` | dateOfBirth, sexAtBirth, heightCm, weightKg, restingHrBaseline, cycle fields | [user.dart](../lib/core/models/user.dart) |

## `ScoreType` enum (scores table)

`recovery`(0), `wellness`(1), `longevity`(2), `stress`(3), `fitness`(4 — VO2),
`cardioLoad`(5). Deterministic id: `ScoreRepository.idFor(userId, type, date)`
= `"$userId:${type.index}:$yyyy-MM-dd"`.

## Repository quick map

Each repo is `Provider`-exposed (`xRepositoryProvider`) and is the **only** code
touching Drift. Common shape: `getInRange`, `insertMany`, `watch*`, `upsert`.
Notables: `ScoreRepository` (getCurrent/getPrevious/watchLatest/getHistory/
upsert/idFor), `ExerciseSessionRepository` (upsertFromBand returns id,
getInRange, updateVo2, watchForUser), `DailyMetricsRepository`
(getForDay/getInRange/watchForDay), `UserRepository` (getProfile/watchProfile).

## Service entry points (orchestration)

| Service | Entry | Effect |
|---|---|---|
| `SyncService` | `syncAll(userId, deviceId)` | pull → aggregate → score → enqueue cloud |
| `PeriodicSyncCoordinator` | tick / `triggerNow()` | drives syncAll + captures + detector |
| `DailyAggregator` | `aggregateRecent(userId)` | write `daily_metrics` (sleep-window medians) |
| `RecoveryScoreService` | `computeForDay(userId, localDate)` | persist recovery `Score` |
| `CardioLoadService` | `computeForLatestNight(userId)` | persist cardioLoad `Score` + nightly record |
| `Vo2MaxService` | `computeForSession(...)` / `computeForDay(...)` | per-session VO2 + rolling fitness `Score` |
| `ActivityDetectorService` | `evaluate(userId)` | flag workout prompt (debounced) |

See [FLUTTER_ARCHITECTURE.md](FLUTTER_ARCHITECTURE.md) for how these compose.
