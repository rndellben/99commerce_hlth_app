import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/ble/sync_adapters.dart' as adapters;
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/processing/bp_formula.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/services/cloud_sync_service.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';
import 'package:hlth_app/core/sync/score_refresh_service.dart';
import 'package:hlth_app/core/sync/sync_results.dart';

/// Centralized band-sync orchestration. Wraps each BLE history command,
/// runs it through the canonical adapter, and persists the result. Used
/// by both the debug screen (manual button taps) and the periodic
/// scheduler (HLT-11). Behavior is intentionally identical to the
/// per-metric handlers that previously lived inline in
/// `ble_debug_screen.dart`.
///
/// Errors are caught and returned as `SyncStepResult.error` rather than
/// thrown — so a single metric failure (e.g. band returned malformed
/// payload) doesn't abort the entire sync sweep.
class BandSyncService {
  BandSyncService({
    required this.ble,
    required this.hrRepo,
    required this.spo2Repo,
    required this.sleepRepo,
    required this.hrvRepo,
    required this.stressRepo,
    required this.stepBucketRepo,
    required this.bpRepo,
    required this.dailyRepo,
    required this.aggregator,
    required this.scoreRefresh,
    required this.cloudSync,
    required this.userRepo,
  });

  final BleService ble;
  final HrRepository hrRepo;
  final Spo2Repository spo2Repo;
  final SleepRepository sleepRepo;
  final HrvRepository hrvRepo;
  final StressRepository stressRepo;
  final StepBucketRepository stepBucketRepo;
  final BpRepository bpRepo;
  final DailyMetricsRepository dailyRepo;
  final DailyAggregator aggregator;
  final ScoreRefreshService scoreRefresh;
  final CloudSyncService cloudSync;
  final UserRepository userRepo;

  /// Shared frame for every per-metric step: run the fetch→adapt→persist
  /// body, and convert any throw into a failed `SyncStepResult` so one
  /// malformed band payload never aborts the rest of the sweep.
  Future<SyncStepResult> _guarded(
    String metric,
    Future<SyncStepResult> Function() body,
  ) async {
    try {
      return await body();
    } catch (e) {
      return SyncStepResult(metric: metric, count: 0, error: e.toString());
    }
  }

  /// Runs every band sync in sequence, then re-aggregates the last 14
  /// days into `daily_metrics`. Continues past individual failures.
  ///
  /// HRV is synced for BOTH `dayOffset=0` (today) AND `dayOffset=1`
  /// (yesterday) because H59 stores overnight HRV samples under the
  /// wear-day index, not the sync-day index (documented in the band
  /// capabilities memory after the 2026-06-01 empirical verification).
  Future<SyncRunResult> syncAll({
    required String userId,
    required String deviceId,
  }) async {
    final steps = <SyncStepResult>[];
    // HR is pulled for today AND yesterday (mirroring HRV below). Today's pull
    // only covers 00:00→now, so after a day with no sync the evening/morning
    // HR of the gap night is never backfilled — the night then has HRV but no
    // hrP5 and can't bank as valid (observed 2026-07-06: "7/5 wake: 12 HRV,
    // rmssd=42, valid=false"). The band retains ~7 days of HR; re-pulls are
    // idempotent via the dedup index.
    steps.add(await syncHr(userId: userId, deviceId: deviceId));
    steps.add(await syncHr(userId: userId, deviceId: deviceId, dayOffset: 1));
    steps.add(await syncSpo2(userId: userId, deviceId: deviceId));
    steps.add(await syncSleep(userId: userId, deviceId: deviceId));
    steps.add(await syncSteps(userId: userId));
    steps.add(await syncStepBuckets(userId: userId, deviceId: deviceId));
    // H59 HRV day-indexing is SHIFTED (verified 2026-07-08 vs QWatch
    // side-by-side + direct HRVReq): index 0 → always empty, index 1 →
    // TODAY, index 2 → yesterday. Each response self-anchors via the band's
    // zeroTime date-stamp (honored in hrvFromNative), so the pulls below
    // file correctly no matter which day each index actually returns.
    // 0 is kept as a cheap probe in case firmware fixes it; 1+2 blanket
    // today + yesterday so a missed day self-heals.
    steps.add(await syncHrv(userId: userId, deviceId: deviceId, dayOffset: 0));
    steps.add(await syncHrv(userId: userId, deviceId: deviceId, dayOffset: 1));
    steps.add(await syncHrv(userId: userId, deviceId: deviceId, dayOffset: 2));
    steps.add(await syncStress(userId: userId, deviceId: deviceId, dayOffset: 0));
    steps.add(await syncStress(userId: userId, deviceId: deviceId, dayOffset: 1));
    // BP (two sources, both hourly, HR-derived — see syncBpTiming):
    //   1. the band's autonomous buffer, which only serves the last COMPLETED
    //      day on H59 (backfills yesterday + earlier), and
    //   2. TODAY's hours reconstructed from today's live HR (step above), so
    //      the headline reads "an hour ago" like SpO2/HRV instead of lagging a
    //      full day behind the buffer.
    // Must run AFTER syncHr so today's HR is in the DB. The per-DAY API
    // `syncBp`/`getBpDay` (BleOperateManager.getBloodPressure) is deliberately
    // NOT called — it times out (-4001, ~15s) on H59. On-demand
    // `startBpMeasurement` ("Measure Now") remains for instant readings.
    steps.add(await syncBpTiming(userId: userId, deviceId: deviceId));

    var aggregated = false;
    try {
      await aggregator.aggregateRecent(userId: userId);
      aggregated = true;
    } catch (e) {
      // Non-fatal; the next run retries. But it MUST be logged — a silent
      // catch here hid a real freeze (2026-07-22: rollups + scores stopped
      // updating at 06:32 while data kept syncing, so today's sleep never
      // merged and Recovery/morning-report never materialized). A breadcrumb
      // makes the next occurrence diagnosable instead of invisible.
      Breadcrumbs.log('aggregate: FAILED — $e');
    }

    // Refresh the derived scores (Recovery / Cardio Load / VO2 Max) off the
    // freshly-aggregated rollup. Each recompute is non-fatal inside the
    // service; see ScoreRefreshService for the backfill-window rationale.
    // Guarded + logged for the same reason as aggregation above.
    if (aggregated) {
      try {
        await scoreRefresh.refreshAfterAggregation(userId: userId);
      } catch (e) {
        Breadcrumbs.log('scoreRefresh: FAILED — $e');
      }
    }

    // Enqueue recent metrics for cloud sync (non-fatal).
    try {
      await cloudSync.enqueueRecentMetrics(userId: userId);
      await cloudSync.enqueueIdentity(userId: userId);
    } catch (_) {
      // Cloud enqueue failure shouldn't break band sync.
    }

    return SyncRunResult(steps: steps, aggregated: aggregated);
  }

  Future<SyncStepResult> syncHr({
    required String userId,
    required String deviceId,
    int dayOffset = 0,
  }) {
    return _guarded('hr', () async {
      final r = await ble.getHrHistory(dayOffset: dayOffset);
      final readings = (r['readings'] as List?) ?? const [];
      if (readings.isEmpty) {
        return SyncStepResult(
          metric: 'hr',
          count: 0,
          note: 'band returned no HR readings yet',
          rawMap: r,
        );
      }
      var hrIntervalMin = 10;
      try {
        final settings = await ble.getScheduledHr();
        hrIntervalMin = (settings['heartInterval'] as num?)?.toInt() ?? 10;
      } catch (_) {}
      final samples = adapters.hrFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
        hrIntervalMin: hrIntervalMin,
      );
      await hrRepo.insertMany(samples);
      return SyncStepResult(
        metric: 'hr',
        count: samples.length,
        rawMap: r,
        extra: {'hrIntervalMin': hrIntervalMin},
      );
    });
  }

  Future<SyncStepResult> syncSpo2({
    required String userId,
    required String deviceId,
  }) {
    return _guarded('spo2', () async {
      final entries = await ble.getSpO2History();
      final samples = adapters.spo2FromNative(
        entries,
        userId: userId,
        deviceId: deviceId,
      );
      await spo2Repo.insertMany(samples);
      return SyncStepResult(
        metric: 'spo2',
        count: samples.length,
        rawList: entries,
      );
    });
  }

  /// Sync a single day's SpO2 via the SDK's public per-day API. Same shape
  /// as [syncSpo2] but only fetches one day instead of the band's full
  /// stored window. Use for "Specific Day Data" debug parity with the
  /// QRing demo.
  Future<SyncStepResult> syncSpo2Day({
    required String userId,
    required String deviceId,
    int dayOffset = 0,
  }) {
    return _guarded('spo2(d=$dayOffset)', () async {
      final entries = await ble.getSpO2Day(dayOffset: dayOffset);
      final samples = adapters.spo2FromNative(
        entries,
        userId: userId,
        deviceId: deviceId,
      );
      await spo2Repo.insertMany(samples);
      return SyncStepResult(
        metric: 'spo2(d=$dayOffset)',
        count: samples.length,
        rawList: entries,
      );
    });
  }

  /// Sync a single sleep session by day-offset (0 = today, 1 = yesterday,
  /// up to 7 per SDK §2.3.3 "Synchronize the details of new sleep data").
  ///
  /// Default dayOffset=1 matches the periodic scheduler's "pull last
  /// night every morning" behavior. Pass an explicit offset (or call
  /// `syncSleepRange`) when a UI surface needs a specific historical
  /// day — e.g. the Sleep detail screen's date picker.
  ///
  /// Idempotent via `insertOnConflictUpdate` — safe to re-call.
  Future<SyncStepResult> syncSleep({
    required String userId,
    required String deviceId,
    int dayOffset = 1,
  }) {
    return _guarded('sleep', () async {
      final r = await ble.getSleepHistory(dayOffset: dayOffset);
      final parsed = adapters.sleepFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
      );
      if (parsed == null) {
        return SyncStepResult(
          metric: 'sleep',
          count: 0,
          note: 'no sleep buffered on band',
          rawMap: r,
        );
      }
      await sleepRepo.createSession(parsed.session);
      await sleepRepo.insertEpochs(parsed.session.id, parsed.epochs);
      return SyncStepResult(
        metric: 'sleep',
        count: parsed.epochs.length,
        rawMap: r,
        extra: {
          'sessionId': parsed.session.id,
          'startedAt': parsed.session.startedAt.toIso8601String(),
          'totalMin': parsed.session.totalMin,
          'epochCount': parsed.epochs.length,
        },
      );
    });
  }

  /// Sync sleep sessions for a contiguous run of day-offsets.
  ///
  /// `offsets` is the list of day-offsets to pull (0=today through 7).
  /// Each offset becomes one BLE round-trip via `syncSleep`. Errors on
  /// individual offsets are captured in the returned step results — the
  /// loop never throws.
  Future<List<SyncStepResult>> syncSleepRange({
    required String userId,
    required String deviceId,
    required Iterable<int> offsets,
  }) async {
    final out = <SyncStepResult>[];
    for (final offset in offsets) {
      out.add(await syncSleep(
        userId: userId,
        deviceId: deviceId,
        dayOffset: offset,
      ));
    }
    return out;
  }

  /// Persists today's running totals into `daily_metrics`, merging into
  /// any existing row so cardiac/sleep columns from other syncs survive.
  Future<SyncStepResult> syncSteps({required String userId}) {
    return _guarded('steps', () async {
      final r = await ble.getDailyTotals();
      final metrics = adapters.dailyStepsFromNative(r, userId: userId);
      if (metrics == null) {
        return SyncStepResult(
          metric: 'steps',
          count: 0,
          note: 'no usable steps data — date fields missing',
          rawMap: r,
        );
      }
      final existing = await dailyRepo.getForDay(
        userId: userId,
        localDate: metrics.localDate,
      );
      final merged = existing == null
          ? metrics
          : existing.copyWith(
              steps: metrics.steps,
              distanceM: metrics.distanceM,
              caloriesKcal: metrics.caloriesKcal,
              activeMinutes: metrics.activeMinutes,
              computedAt: metrics.computedAt,
            );
      await dailyRepo.upsert(merged);
      return SyncStepResult(
        metric: 'steps',
        count: metrics.steps ?? 0,
        rawMap: r,
        extra: {'localDate': merged.localDate.toIso8601String().substring(0, 10)},
      );
    });
  }

  Future<SyncStepResult> syncStepBuckets({
    required String userId,
    required String deviceId,
  }) {
    return _guarded('step_buckets', () async {
      final native = await ble.getStepBucketHistory(dayOffset: 0);
      final buckets = adapters.stepBucketsFromNative(
        native,
        userId: userId,
        deviceId: deviceId,
      );
      await stepBucketRepo.insertMany(buckets);
      return SyncStepResult(
        metric: 'step_buckets',
        count: buckets.length,
        rawList: native,
      );
    });
  }

  Future<SyncStepResult> syncHrv({
    required String userId,
    required String deviceId,
    required int dayOffset,
  }) {
    return _guarded('hrv(d=$dayOffset)', () async {
      final r = await ble.getHrvHistory(dayOffset: dayOffset);
      // `forDate` anchors per-slot timestamps. dayOffset=0 → today,
      // dayOffset=1 → yesterday, etc.
      final forDate = DateTime.now().subtract(Duration(days: dayOffset));
      final samples = adapters.hrvFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
        forDate: forDate,
      );
      await hrvRepo.insertMany(samples);
      return SyncStepResult(
        metric: 'hrv(d=$dayOffset)',
        count: samples.length,
        rawMap: r,
      );
    });
  }

  Future<SyncStepResult> syncStress({
    required String userId,
    required String deviceId,
    required int dayOffset,
  }) {
    return _guarded('stress(d=$dayOffset)', () async {
      final r = await ble.getStressDay(dayOffset: dayOffset);
      final forDate = DateTime.now().subtract(Duration(days: dayOffset));
      final samples = adapters.stressFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
        forDate: forDate,
      );
      await stressRepo.insertMany(samples);
      return SyncStepResult(
        metric: 'stress(d=$dayOffset)',
        count: samples.length,
        rawMap: r,
      );
    });
  }

  /// Pulls the band's stored BP readings for a day-offset via the SDK's
  /// per-day API and persists them as `bp_readings` (source bandScheduled).
  ///
  /// Synced for both `dayOffset=0` (today) and `dayOffset=1` (yesterday)
  /// from `syncAll`, mirroring HRV — overnight scheduled readings are pulled
  /// the next morning under the wear-day index.
  ///
  /// Idempotent: `bpFromNative` assigns each reading a deterministic id, so
  /// re-pulling the full day every sync tick overwrites rather than
  /// duplicates.
  Future<SyncStepResult> syncBp({
    required String userId,
    required String deviceId,
    int dayOffset = 0,
  }) {
    return _guarded('bp(d=$dayOffset)', () async {
      final r = await ble.getBpDay(dayOffset: dayOffset);
      final samples = adapters.bpFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
      );
      if (samples.isNotEmpty) {
        await bpRepo.insertMany(samples);
      }
      return SyncStepResult(
        metric: 'bp(d=$dayOffset)',
        count: samples.length,
        rawMap: r,
      );
    });
  }

  /// Pull the band's autonomous hourly BP buffer (`CMD_BP_TIMING_MONITOR_DATA`
  /// via `getBpHistory`) and persist one BP reading per hour. Unlike
  /// [syncBp] (`getBpDay`, which times out `-4001` on H59), this path WORKS —
  /// the band records HR hourly all day incl. overnight and returns it in one
  /// pull, so sleeping BP no longer depends on an on-demand measurement firing
  /// mid-sleep. HR→BP conversion happens in `bpTimingFromNative` using the
  /// user's age (H59 BP is an HR+age estimate regardless). Idempotent via the
  /// adapter's deterministic id, so re-pulling the day's buffer upserts.
  Future<SyncStepResult> syncBpTiming({
    required String userId,
    required String deviceId,
  }) {
    return _guarded('bpTiming', () async {
      final profile = await userRepo.getProfile(userId);
      final dob = profile?.dateOfBirth;
      final age = dob == null ? BpFormula.ageDefault : _ageFrom(dob);
      // (1) Band's autonomous BP buffer — this serves the last COMPLETED
      // calendar day only (H59 never exposes today's in-progress hours here;
      // verified 2026-07-21). So it backfills yesterday + earlier.
      //
      // Wrapped in its OWN try/catch: `getBpHistory` can time out (-4001), and
      // it must NOT take down step (2) below, which needs no band call at all.
      // Before this decoupling a buffer timeout skipped the whole step, so a
      // sync would refresh HR but leave BP stale (observed 2026-07-21: HR
      // synced at 22:06 but BP frozen at the 20:11 run).
      Map<String, dynamic> r = const {};
      var bufferedCount = 0;
      try {
        r = await ble.getBpHistory();
        final buffered = adapters.bpTimingFromNative(
          r,
          userId: userId,
          deviceId: deviceId,
          age: age,
        );
        if (buffered.isNotEmpty) {
          await bpRepo.insertMany(buffered);
          bufferedCount = buffered.length;
        }
      } catch (_) {
        // Buffer (completed-day) pull failed — non-fatal; step (2) still runs.
      }

      // (2) TODAY's hourly BP, derived from today's live HR (synced in the
      // step just before this one). H59 BP == BpFormula(hr, age), and HR
      // history IS current — so this gives BP the same freshness as SpO2/HRV
      // instead of waiting a full day for the buffer. Same id scheme as (1),
      // so tomorrow's buffer upserts these rows rather than duplicating them.
      final now = DateTime.now();
      final dayStartUtc =
          DateTime(now.year, now.month, now.day).toUtc();
      final todayHr = await hrRepo.getInRange(
        userId: userId,
        from: dayStartUtc,
        to: now.toUtc(),
        deviceId: deviceId,
      );
      final derived = adapters.bpHourlyFromHrSamples(
        todayHr,
        userId: userId,
        deviceId: deviceId,
        age: age,
        // TEST (2026-07-21): 30-min cadence to match the band's 30-min BP
        // schedule. Revert to 60 (or drop the arg) to go back to hourly.
        slotMinutes: kBpSlotMinutes,
      );
      if (derived.isNotEmpty) {
        await bpRepo.insertMany(derived);
      }

      return SyncStepResult(
        metric: 'bpTiming',
        count: bufferedCount + derived.length,
        rawMap: r,
      );
    });
  }

  /// Whole years elapsed since [dob] (band/formula want an integer age).
  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 0 ? BpFormula.ageDefault : age;
  }
}

final bandSyncServiceProvider = Provider<BandSyncService>((ref) {
  return BandSyncService(
    ble: ref.watch(bleServiceProvider),
    hrRepo: ref.watch(hrRepositoryProvider),
    spo2Repo: ref.watch(spo2RepositoryProvider),
    sleepRepo: ref.watch(sleepRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    stressRepo: ref.watch(stressRepositoryProvider),
    stepBucketRepo: ref.watch(stepBucketRepositoryProvider),
    bpRepo: ref.watch(bpRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    aggregator: ref.watch(dailyAggregatorProvider),
    scoreRefresh: ref.watch(scoreRefreshServiceProvider),
    cloudSync: ref.watch(cloudSyncServiceProvider),
    userRepo: ref.watch(userRepositoryProvider),
  );
});
