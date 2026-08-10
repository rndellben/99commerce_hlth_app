// `BandSyncService.syncAll` — rank 6 of
// `docs/plans/2026-08-10-coverage-audit.md` §1, test #5 of §4. First test of
// `lib/core/sync/` at all.
//
// Four H59 hardware quirks are encoded in this method as *ordering*, and until
// now nothing pinned them — they existed only as prose comments
// (band_sync_service.dart:87-121):
//
//   1. HR is pulled for TODAY and YESTERDAY (:93-94). Today's pull only covers
//      00:00->now, so without the yesterday pull a gap night has HRV but no
//      hrP5 and can't bank as valid.
//   2. HRV is pulled at offsets 0, 1 AND 2 (:106-108). The H59 HRV day index is
//      shifted — 0 is always empty, 1 = today, 2 = yesterday.
//   3. HR must run BEFORE `syncBpTiming`, because today's BP is reconstructed
//      from today's HR rows in the database (:117, :494-511).
//   4. `getBpDay` must NEVER be called from the sweep — it times out (-4001,
//      ~15s) on H59 (:118-120).
//
// Plus the two structural contracts: one failing step must not abort the sweep
// (`_guarded`, :64-73), and score refresh runs only when aggregation succeeded
// (the `aggregated` gate, :140).
//
// No database. Thirteen hand-written fakes over the ctor params at :31-45, all
// on a `_Fake` `noSuchMethod` base (idiom: test/cardio_load_frame_test.dart:159-163;
// `implements BleService` precedent: test/scheduled_ppg_rest_gate_test.dart:124).
// The BLE fake returns payload maps in the shapes the adapters already parse.

import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/services/cloud_sync_service.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';
import 'package:hlth_app/core/sync/band_sync_service.dart';
import 'package:hlth_app/core/sync/score_refresh_service.dart';

const _userId = 'u1';
const _deviceId = 'd1';

/// Exactly the BLE history commands `syncAll` must issue, in order.
const _expectedBleOrder = <String>[
  'getHrHistory(0)',
  'getHrHistory(1)',
  'getSpO2History',
  'getSleepHistory',
  'getDailyTotals',
  'getStepBucketHistory',
  'getHrvHistory(0)',
  'getHrvHistory(1)',
  'getHrvHistory(2)',
  'getStressDay(0)',
  'getStressDay(1)',
  'getBpHistory',
];

void main() {
  late _Harness h;

  setUp(() => h = _Harness());

  group('syncAll step order (H59 quirks encoded as ordering)', () {
    test('issues exactly the expected BLE commands, in order', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(h.ble.log, _expectedBleOrder);
    });

    test('never calls getBpDay — it times out -4001 on H59', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(h.ble.log.where((c) => c.startsWith('getBpDay')), isEmpty);
    });

    test('pulls HR for today AND yesterday', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(
        h.ble.log.where((c) => c.startsWith('getHrHistory')).toList(),
        ['getHrHistory(0)', 'getHrHistory(1)'],
      );
    });

    test('pulls HRV at all three shifted day indices', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(
        h.ble.log.where((c) => c.startsWith('getHrvHistory')).toList(),
        ['getHrvHistory(0)', 'getHrvHistory(1)', 'getHrvHistory(2)'],
      );
    });

    test('BP-for-today reads HR only after HR has been persisted', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      // syncBpTiming reconstructs today's BP from today's HR rows, so the read
      // must come after the writes — reordering the steps would silently leave
      // today's BP a full day behind the band buffer.
      expect(h.repoLog.indexOf('hr.getInRange'),
          greaterThan(h.repoLog.lastIndexOf('hr.insertMany')));
    });

    test('the sleep pull targets yesterday, step buckets target today', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(h.ble.sleepDayOffset, 1);
      expect(h.ble.stepBucketDayOffset, 0);
    });

    test('every step reports success and each metric persists', () async {
      final result =
          await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(result.failed, isEmpty);
      expect(result.aggregated, isTrue);
      expect(h.hr.inserted, isNotEmpty);
      expect(h.spo2.inserted, isNotEmpty);
      expect(h.hrv.inserted, isNotEmpty);
      expect(h.stress.inserted, isNotEmpty);
      expect(h.stepBuckets.inserted, isNotEmpty);
      expect(h.sleep.sessions, hasLength(1));
      expect(h.bp.inserted.map((r) => r.id), everyElement(startsWith('bptiming:')),
          reason: 'the timing-monitor buffer is the only BP write path here');
    });
  });

  group('syncAll continues past a failing step', () {
    test('a throwing getSleepHistory costs exactly one step, not the sweep',
        () async {
      h.ble.throwOn.add('getSleepHistory');

      final result =
          await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(result.failed.map((s) => s.metric).toList(), ['sleep']);
      // The eight commands after sleep still fire.
      expect(h.ble.log.sublist(h.ble.log.indexOf('getSleepHistory') + 1), [
        'getDailyTotals',
        'getStepBucketHistory',
        'getHrvHistory(0)',
        'getHrvHistory(1)',
        'getHrvHistory(2)',
        'getStressDay(0)',
        'getStressDay(1)',
        'getBpHistory',
      ]);
      expect(h.ble.log, _expectedBleOrder,
          reason: 'a failed step is still a step — order is unchanged');
      expect(result.aggregated, isTrue);
    });
  });

  group('score refresh is gated on aggregation', () {
    test('runs when aggregation succeeded', () async {
      await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(h.scoreRefresh.calls, 1);
    });

    test('is skipped when aggregation threw', () async {
      h.aggregator.shouldThrow = true;

      final result =
          await h.service.syncAll(userId: _userId, deviceId: _deviceId);

      expect(result.aggregated, isFalse);
      expect(h.scoreRefresh.calls, 0,
          reason: 'refreshing scores off a stale rollup would bake in the '
              'stale numbers');
      // Aggregation failure is non-fatal for the band pulls themselves.
      expect(result.failed, isEmpty);
      expect(h.ble.log, _expectedBleOrder);
    });
  });
}

// ─── Harness ────────────────────────────────────────────────────────────────

class _Harness {
  _Harness() {
    final repoLog = this.repoLog;
    ble = _FakeBle();
    hr = _FakeHrRepo(repoLog);
    spo2 = _FakeSpo2Repo();
    sleep = _FakeSleepRepo();
    hrv = _FakeHrvRepo();
    stress = _FakeStressRepo();
    stepBuckets = _FakeStepBucketRepo();
    bp = _FakeBpRepo();
    daily = _FakeDailyRepo();
    aggregator = _FakeAggregator();
    scoreRefresh = _FakeScoreRefresh();
    service = BandSyncService(
      ble: ble,
      hrRepo: hr,
      spo2Repo: spo2,
      sleepRepo: sleep,
      hrvRepo: hrv,
      stressRepo: stress,
      stepBucketRepo: stepBuckets,
      bpRepo: bp,
      dailyRepo: daily,
      aggregator: aggregator,
      scoreRefresh: scoreRefresh,
      cloudSync: _FakeCloudSync(),
      userRepo: _FakeUserRepo(),
    );
  }

  /// Repository interactions, in call order — pins the HR-before-BP dependency
  /// that the BLE log alone can't show.
  final repoLog = <String>[];

  late final _FakeBle ble;
  late final _FakeHrRepo hr;
  late final _FakeSpo2Repo spo2;
  late final _FakeSleepRepo sleep;
  late final _FakeHrvRepo hrv;
  late final _FakeStressRepo stress;
  late final _FakeStepBucketRepo stepBuckets;
  late final _FakeBpRepo bp;
  late final _FakeDailyRepo daily;
  late final _FakeAggregator aggregator;
  late final _FakeScoreRefresh scoreRefresh;
  late final BandSyncService service;
}

/// Base that throws for any member the service is not expected to touch.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

// ─── BLE ────────────────────────────────────────────────────────────────────

/// Records every history command `syncAll` issues and returns payloads in the
/// shapes `sync_adapters.dart` already parses.
///
/// `getScheduledHr` is a settings read inside `syncHr`, not one of the history
/// commands whose order is the contract here, so it is counted separately.
class _FakeBle extends _Fake implements BleService {
  final log = <String>[];
  final throwOn = <String>{};
  int scheduledHrReads = 0;
  int? sleepDayOffset;
  int? stepBucketDayOffset;

  T _record<T>(String call, T value) {
    log.add(call);
    if (throwOn.contains(call.split('(').first)) {
      throw StateError('band returned -4001 for $call');
    }
    return value;
  }

  @override
  Future<Map<String, dynamic>> getHrHistory({int dayOffset = 0}) async =>
      _record('getHrHistory($dayOffset)', {
        'readings': [
          {'timestamp_ms': 1786060800000, 'bpm': 61, 'slot': 0},
          {'timestamp_ms': 1786064400000, 'bpm': 68, 'slot': 1},
        ],
        'size': 2,
        'index': dayOffset,
      });

  @override
  Future<Map<String, dynamic>> getScheduledHr() async {
    scheduledHrReads++;
    return {'heartInterval': 10, 'isEnable': true};
  }

  @override
  Future<List<Map<String, dynamic>>> getSpO2History() async =>
      _record('getSpO2History', [
        {
          'dateStr': '2026-08-10',
          'unixTime': 1786060800,
          'minArray': [0, 95, 96],
          'maxArray': [0, 98, 99],
        },
      ]);

  @override
  Future<Map<String, dynamic>> getSleepHistory({int dayOffset = 0}) async {
    sleepDayOffset = dayOffset;
    return _record('getSleepHistory', {
      'totalSleepDuration': 28800,
      'deepDuration': 5400,
      'shallowDuration': 18840,
      'rapidDuration': 0,
      'awakeDuration': 4560,
      'sleepTime': 1786003200,
      'wakeTime': 1786032000,
      'wakingCount': 2,
      'stages': [
        {'sleepStart': 1786003200, 'sleepEnd': 1786006800, 'type': 2},
        {'sleepStart': 1786006800, 'sleepEnd': 1786012200, 'type': 1},
      ],
    });
  }

  @override
  Future<Map<String, dynamic>> getDailyTotals() async =>
      _record('getDailyTotals', {
        'year': 2026,
        'month': 8,
        'day': 10,
        'daysAgo': 0,
        'totalSteps': 5200,
        'runningSteps': 140,
        'calorie': 64021,
        'walkDistance': 3900,
        'sportDurationSec': 1800,
      });

  @override
  Future<List<Map<String, dynamic>>> getStepBucketHistory({
    int dayOffset = 0,
  }) async {
    stepBucketDayOffset = dayOffset;
    return _record('getStepBucketHistory', [
      {
        'year': 2026,
        'month': 8,
        'day': 10,
        'timeIndex': 40,
        'walkSteps': 320,
        'runSteps': 0,
        'calorie': 12000,
        'distance': 240,
      },
    ]);
  }

  @override
  Future<Map<String, dynamic>> getHrvHistory({int dayOffset = 0}) async =>
      _record('getHrvHistory($dayOffset)', {
        'values': [0, 42.0, 38.5],
        'intervalMinutes': 30,
        'zeroTimeMs': 1786003200,
      });

  @override
  Future<Map<String, dynamic>> getStressDay({int dayOffset = 0}) async =>
      _record('getStressDay($dayOffset)', {
        'values': [0, 35, 41],
        'intervalMinutes': 30,
        'offset': 0,
        'zeroTimeMs': 1786003200,
      });

  @override
  Future<Map<String, dynamic>> getBpHistory() async =>
      _record('getBpHistory', {
        'year': 2026,
        'month': 8,
        'day': 9,
        'timeDelay': 0,
        'readings': [
          {'timeMinute': 480, 'hr': 64},
          {'timeMinute': 540, 'hr': 71},
        ],
      });

  /// Implemented purely so that calling it is *visible* in the log — the
  /// contract is that `syncAll` never reaches it.
  @override
  Future<Map<String, dynamic>> getBpDay({int dayOffset = 0}) async =>
      _record('getBpDay($dayOffset)', const {'readings': []});
}

// ─── Repositories ───────────────────────────────────────────────────────────

class _FakeHrRepo extends _Fake implements HrRepository {
  _FakeHrRepo(this._log);
  final List<String> _log;
  final inserted = <HrSample>[];

  @override
  Future<void> insertMany(List<HrSample> samples) async {
    _log.add('hr.insertMany');
    inserted.addAll(samples);
  }

  @override
  Future<List<HrSample>> getInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
    String? deviceId,
    int? limit,
  }) async {
    _log.add('hr.getInRange');
    return inserted
        .where((s) =>
            !s.capturedAt.isBefore(from) && s.capturedAt.isBefore(to))
        .toList();
  }
}

class _FakeSpo2Repo extends _Fake implements Spo2Repository {
  final inserted = <Spo2Sample>[];
  @override
  Future<void> insertMany(List<Spo2Sample> samples) async =>
      inserted.addAll(samples);
}

class _FakeHrvRepo extends _Fake implements HrvRepository {
  final inserted = <HrvSample>[];
  @override
  Future<void> insertMany(List<HrvSample> samples) async =>
      inserted.addAll(samples);
}

class _FakeStressRepo extends _Fake implements StressRepository {
  final inserted = <StressSample>[];
  @override
  Future<void> insertMany(List<StressSample> samples) async =>
      inserted.addAll(samples);
}

class _FakeStepBucketRepo extends _Fake implements StepBucketRepository {
  final inserted = <StepBucket>[];
  @override
  Future<void> insertMany(List<StepBucket> buckets) async =>
      inserted.addAll(buckets);
}

class _FakeBpRepo extends _Fake implements BpRepository {
  final inserted = <BpReading>[];
  @override
  Future<void> insertMany(List<BpReading> samples) async =>
      inserted.addAll(samples);
}

class _FakeSleepRepo extends _Fake implements SleepRepository {
  final sessions = <SleepSession>[];
  final epochs = <String, List<SleepEpoch>>{};

  @override
  Future<String> createSession(SleepSession session) async {
    sessions.add(session);
    return session.id;
  }

  @override
  Future<void> insertEpochs(String sessionId, List<SleepEpoch> rows) async {
    epochs[sessionId] = rows;
  }
}

class _FakeDailyRepo extends _Fake implements DailyMetricsRepository {
  final upserted = <DailyMetrics>[];

  @override
  Future<DailyMetrics?> getForDay({
    required String userId,
    required DateTime localDate,
  }) async =>
      null;

  @override
  Future<void> upsert(DailyMetrics row) async => upserted.add(row);
}

class _FakeUserRepo extends _Fake implements UserRepository {
  @override
  Future<UserProfile?> getProfile(String userId) async => null;
}

// ─── Services ───────────────────────────────────────────────────────────────

class _FakeAggregator extends _Fake implements DailyAggregator {
  bool shouldThrow = false;
  int calls = 0;

  @override
  Future<void> aggregateRecent({
    required String userId,
    int days = 14,
    int? tzOffsetMin,
  }) async {
    calls++;
    if (shouldThrow) throw StateError('aggregation wedged');
  }
}

class _FakeScoreRefresh extends _Fake implements ScoreRefreshService {
  int calls = 0;

  @override
  Future<void> refreshAfterAggregation({required String userId}) async {
    calls++;
  }
}

class _FakeCloudSync extends _Fake implements CloudSyncService {
  @override
  Future<void> enqueueRecentMetrics({
    required String userId,
    int days = 14,
  }) async {}

  @override
  Future<void> enqueueIdentity({required String userId}) async {}
}
