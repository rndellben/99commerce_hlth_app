import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/ble/sync_adapters.dart' as adapters;
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';

/// Per-step result. `error` is non-null on failure; counts are best-effort.
///
/// `rawMap` / `rawList` carry the underlying BLE response so the debug
/// screen can dump the band's payload verbatim without making a second
/// (slower, expensive) BLE round-trip. Periodic scheduler ignores them.
class SyncStepResult {
  const SyncStepResult({
    required this.metric,
    required this.count,
    this.error,
    this.note,
    this.rawMap,
    this.rawList,
    this.extra,
  });

  final String metric;
  final int count;
  final String? error;
  final String? note;
  final Map<String, dynamic>? rawMap;
  final List<dynamic>? rawList;
  // Per-metric ancillary values (e.g. HR's resolved intervalMin, sleep's
  // session id) for callers that need more than count + raw payload.
  final Map<String, dynamic>? extra;

  bool get ok => error == null;
}

/// Aggregate of a `syncAll` run. Order matches execution order.
class SyncRunResult {
  const SyncRunResult({required this.steps, required this.aggregated});

  final List<SyncStepResult> steps;
  final bool aggregated;

  int get totalSamples => steps.fold(0, (a, s) => a + s.count);
  Iterable<SyncStepResult> get failed => steps.where((s) => !s.ok);
  bool get allOk => failed.isEmpty && aggregated;
}

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
class SyncService {
  SyncService({
    required this.ble,
    required this.hrRepo,
    required this.spo2Repo,
    required this.sleepRepo,
    required this.hrvRepo,
    required this.stepBucketRepo,
    required this.dailyRepo,
    required this.aggregator,
  });

  final BleService ble;
  final HrRepository hrRepo;
  final Spo2Repository spo2Repo;
  final SleepRepository sleepRepo;
  final HrvRepository hrvRepo;
  final StepBucketRepository stepBucketRepo;
  final DailyMetricsRepository dailyRepo;
  final DailyAggregator aggregator;

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
    steps.add(await syncHr(userId: userId, deviceId: deviceId));
    steps.add(await syncSpo2(userId: userId, deviceId: deviceId));
    steps.add(await syncSleep(userId: userId, deviceId: deviceId));
    steps.add(await syncSteps(userId: userId));
    steps.add(await syncStepBuckets(userId: userId, deviceId: deviceId));
    steps.add(await syncHrv(userId: userId, deviceId: deviceId, dayOffset: 0));
    steps.add(await syncHrv(userId: userId, deviceId: deviceId, dayOffset: 1));

    var aggregated = false;
    try {
      await aggregator.aggregateRecent(userId: userId);
      aggregated = true;
    } catch (_) {
      // Aggregation failures are logged as a non-fatal step result
      // rather than thrown; the next run will retry.
    }
    return SyncRunResult(steps: steps, aggregated: aggregated);
  }

  Future<SyncStepResult> syncHr({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final r = await ble.getHrHistory();
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
    } catch (e) {
      return SyncStepResult(metric: 'hr', count: 0, error: e.toString());
    }
  }

  Future<SyncStepResult> syncSpo2({
    required String userId,
    required String deviceId,
  }) async {
    try {
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
    } catch (e) {
      return SyncStepResult(metric: 'spo2', count: 0, error: e.toString());
    }
  }

  Future<SyncStepResult> syncSleep({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final r = await ble.getSleepHistory();
      final parsed = adapters.sleepFromNative(
        r,
        userId: userId,
        deviceId: deviceId,
      );
      if (parsed == null) {
        return SyncStepResult(
          metric: 'sleep',
          count: 0,
          note: 'no usable sleep data — sleepTime/wakeTime missing or stages empty',
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
          'totalMin': parsed.session.totalMin,
        },
      );
    } catch (e) {
      return SyncStepResult(metric: 'sleep', count: 0, error: e.toString());
    }
  }

  /// Persists today's running totals into `daily_metrics`, merging into
  /// any existing row so cardiac/sleep columns from other syncs survive.
  Future<SyncStepResult> syncSteps({required String userId}) async {
    try {
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
    } catch (e) {
      return SyncStepResult(metric: 'steps', count: 0, error: e.toString());
    }
  }

  Future<SyncStepResult> syncStepBuckets({
    required String userId,
    required String deviceId,
  }) async {
    try {
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
    } catch (e) {
      return SyncStepResult(
        metric: 'step_buckets',
        count: 0,
        error: e.toString(),
      );
    }
  }

  Future<SyncStepResult> syncHrv({
    required String userId,
    required String deviceId,
    required int dayOffset,
  }) async {
    try {
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
    } catch (e) {
      return SyncStepResult(
        metric: 'hrv(d=$dayOffset)',
        count: 0,
        error: e.toString(),
      );
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ble: ref.watch(bleServiceProvider),
    hrRepo: ref.watch(hrRepositoryProvider),
    spo2Repo: ref.watch(spo2RepositoryProvider),
    sleepRepo: ref.watch(sleepRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    stepBucketRepo: ref.watch(stepBucketRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    aggregator: ref.watch(dailyAggregatorProvider),
  );
});

/// HLT-11: bridges the native scheduler's tick stream
/// (`BleService.periodicSyncTick`) to `SyncService.syncAll`. Lives in
/// Dart because the active user/device IDs are Dart-side state.
///
/// Resolves the active device on each tick by querying
/// `DeviceRepository.getActiveForUser(...)` — so the coordinator works
/// regardless of which screen is foregrounded.
///
/// Concurrency: an in-flight sync flag drops overlapping ticks rather
/// than queuing them. If a 30-min sync takes >30 min for some reason,
/// the next tick is skipped, not stacked.
class PeriodicSyncCoordinator {
  PeriodicSyncCoordinator({
    required this.sync,
    required this.deviceRepo,
    required Stream<void> tickStream,
  }) {
    _tickSub = tickStream.listen((_) => _onTick());
  }

  final SyncService sync;
  final DeviceRepository deviceRepo;
  StreamSubscription<void>? _tickSub;
  bool _inFlight = false;
  final _runs = StreamController<SyncRunResult>.broadcast();

  /// Most recent periodic-sync results. Debug screens subscribe to see
  /// when each tick fires and what it persisted.
  Stream<SyncRunResult> get runs => _runs.stream;

  Future<void> _onTick() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final device = await deviceRepo.getActiveForUser(
        ActiveSession.defaultUserId,
      );
      if (device == null) return;
      final result = await sync.syncAll(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
      );
      _runs.add(result);
    } finally {
      _inFlight = false;
    }
  }

  /// For debug screens / tests: trigger the same flow as a native tick.
  /// Returns `null` on skip; callers can read `lastSkipReason` for why.
  Future<SyncRunResult?> triggerNow() async {
    if (_inFlight) {
      lastSkipReason = 'sync already in flight';
      return null;
    }
    _inFlight = true;
    try {
      final device = await deviceRepo.getActiveForUser(
        ActiveSession.defaultUserId,
      );
      if (device == null) {
        lastSkipReason =
            'no active device row in DB for user=${ActiveSession.defaultUserId} '
            '(did you tap Connect since app launch? auto-reconnect alone doesn\'t register)';
        return null;
      }
      lastSkipReason = null;
      final result = await sync.syncAll(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
      );
      _runs.add(result);
      return result;
    } finally {
      _inFlight = false;
    }
  }

  /// Populated when `_onTick` / `triggerNow` return null. Cleared on
  /// successful runs.
  String? lastSkipReason;

  void dispose() {
    _tickSub?.cancel();
    _runs.close();
  }
}

final periodicSyncCoordinatorProvider =
    Provider<PeriodicSyncCoordinator>((ref) {
  final coord = PeriodicSyncCoordinator(
    sync: ref.watch(syncServiceProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
    tickStream: ref.watch(bleServiceProvider).periodicSyncTick,
  );
  ref.onDispose(coord.dispose);
  return coord;
});
