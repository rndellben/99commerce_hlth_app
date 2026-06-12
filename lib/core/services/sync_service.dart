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
import 'package:hlth_app/core/processing/fall_detector.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';
import 'package:hlth_app/core/services/retention_sweep_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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
///
/// `retention` is populated by `PeriodicSyncCoordinator` when the daily
/// gate elapsed and a sweep ran; null otherwise. `retentionSkipReason`
/// is a short string ("last ran 4h ago") for visibility when the gate
/// blocked the sweep — only set when retention is null AND the gate is
/// the reason (not the case when the sweep ran successfully).
class SyncRunResult {
  const SyncRunResult({
    required this.steps,
    required this.aggregated,
    this.retention,
    this.retentionSkipReason,
  });

  final List<SyncStepResult> steps;
  final bool aggregated;
  final RetentionSweepResult? retention;
  final String? retentionSkipReason;

  int get totalSamples => steps.fold(0, (a, s) => a + s.count);
  Iterable<SyncStepResult> get failed => steps.where((s) => !s.ok);
  bool get allOk =>
      failed.isEmpty &&
      aggregated &&
      (retention == null || retention!.allOk);
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
    int dayOffset = 0,
  }) async {
    try {
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

  /// Sync a single day's SpO2 via the SDK's public per-day API. Same shape
  /// as [syncSpo2] but only fetches one day instead of the band's full
  /// stored window. Use for "Specific Day Data" debug parity with the
  /// QRing demo.
  Future<SyncStepResult> syncSpo2Day({
    required String userId,
    required String deviceId,
    int dayOffset = 0,
  }) async {
    try {
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
    } catch (e) {
      return SyncStepResult(metric: 'spo2(d=$dayOffset)', count: 0, error: e.toString());
    }
  }

  /// Sync the most recent completed sleep session (dayOffset=1).
  ///
  /// Matches the QRing demo's "Specific Day Data" behavior with
  /// dayIndex=1 — one BLE round-trip returning yesterday's stored
  /// session. Per-day backfill (looping 1..7) was tried 2026-06-05 but
  /// each call streams multi-frame `ReadSleepDetailsRsp` data; 7×
  /// of that takes too long over BLE. Single-call keeps Sync Sleep
  /// responsive; the periodic scheduler running each morning catches
  /// each night as it's completed.
  ///
  /// Idempotent via `insertOnConflictUpdate` — safe to re-call.
  Future<SyncStepResult> syncSleep({
    required String userId,
    required String deviceId,
  }) async {
    try {
      final r = await ble.getSleepHistory(dayOffset: 1);
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
    required this.retentionSweep,
    required this.ble,
    required Stream<void> tickStream,
    this.fallSweepDuration = const Duration(seconds: 30),
    FallDetector? fallDetector,
  }) : _fallDetector = fallDetector ?? const FallDetector() {
    _tickSub = tickStream.listen((_) => _onTick());
  }

  final SyncService sync;
  final DeviceRepository deviceRepo;
  final RetentionSweepService retentionSweep;
  final BleService ble;
  final Duration fallSweepDuration;
  final FallDetector _fallDetector;
  StreamSubscription<void>? _tickSub;
  bool _inFlight = false;
  final _runs = StreamController<SyncRunResult>.broadcast();
  final _fallSweeps = StreamController<FallSweepResult>.broadcast();

  /// HLT-12: shared_preferences key for the last-swept timestamp (unix
  /// sec). Persisted so the 24h gate survives app restarts.
  static const _kLastSweptAtKey = 'retention_last_swept_at_utc_sec';
  static const _sweepIntervalHours = 24;

  /// Most recent periodic-sync results. Debug screens subscribe to see
  /// when each tick fires and what it persisted.
  Stream<SyncRunResult> get runs => _runs.stream;

  /// HLT-5: results from the background fall sweep that runs after each
  /// periodic sync. Emits one event per scheduled tick (or per
  /// `triggerNow(fallSweep: true)`). The H59 only emits accelerometer
  /// data during active PPG capture, so each sweep starts a short
  /// `startMeasureHrRaw` window, buffers the accel triples, then runs
  /// the three-window state machine across that buffer.
  Stream<FallSweepResult> get fallSweeps => _fallSweeps.stream;

  Future<void> _onTick() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final device = await deviceRepo.getActiveForUser(
        ActiveSession.defaultUserId,
      );
      if (device == null) return;
      final result = await _runSyncWithRetention(device.id);
      _runs.add(result);
      // HLT-5: run the background fall sweep once data sync is done.
      // Sequenced after sync so we never have two `startMeasureHrRaw`
      // sessions racing for the same BLE link.
      final fallResult = await _runFallSweep();
      _fallSweeps.add(fallResult);
    } finally {
      _inFlight = false;
    }
  }

  /// For debug screens / tests: trigger the same flow as a native tick.
  /// Returns `null` on skip; callers can read `lastSkipReason` for why.
  /// Pass `fallSweep: true` to also run the HLT-5 background fall sweep
  /// (off by default for fast manual debug runs).
  Future<SyncRunResult?> triggerNow({bool fallSweep = false}) async {
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
      final result = await _runSyncWithRetention(device.id);
      _runs.add(result);
      if (fallSweep) {
        final sweepResult = await _runFallSweep();
        _fallSweeps.add(sweepResult);
      }
      return result;
    } finally {
      _inFlight = false;
    }
  }

  /// HLT-5: open a short PPG capture window, collect accel triples from
  /// the realtime stream, then evaluate the three-window state machine
  /// across the buffered samples.
  ///
  /// **H59 constraint:** raw accelerometer data is only emitted while
  /// `startMeasureHrRaw` is running. We open the smallest window we can
  /// (default 30 s) to keep battery impact low — that's ~1.7% duty
  /// cycle when the periodic scheduler fires every 30 minutes.
  Future<FallSweepResult> _runFallSweep() async {
    final startedAt = DateTime.now().toUtc();
    final durationS = fallSweepDuration.inSeconds;
    final accelX = <int>[];
    final accelY = <int>[];
    final accelZ = <int>[];

    StreamSubscription<List<Map<String, dynamic>>>? sub;
    try {
      sub = ble.rawPpgEvent.listen((samples) {
        for (final s in samples) {
          final ax = s['accel_x'];
          final ay = s['accel_y'];
          final az = s['accel_z'];
          if (ax is num && ay is num && az is num) {
            accelX.add(ax.toInt());
            accelY.add(ay.toInt());
            accelZ.add(az.toInt());
          }
        }
      });

      await ble.startMeasureHrRaw(durationSec: durationS);
      // Add a small grace period so the band's final packets land in our
      // buffer before we cancel the listener.
      await Future<void>.delayed(Duration(seconds: durationS + 1));
    } catch (e) {
      await sub?.cancel();
      try {
        await ble.stopMeasure();
      } catch (_) {}
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'capture failed: $e',
      );
    }
    await sub.cancel();
    try {
      await ble.stopMeasure();
    } catch (_) {}

    if (accelX.length < 50) {
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'too few accel samples (${accelX.length})',
      );
    }

    // Calibrate the local "1 g" reference from the median magnitude of
    // the captured window. Using median (not mean) so a real impact
    // doesn't pull the reference up and dilute the freefall threshold.
    final magsRaw = List<double>.generate(accelX.length, (i) {
      final x = accelX[i].toDouble();
      final y = accelY[i].toDouble();
      final z = accelZ[i].toDouble();
      return math.sqrt(x * x + y * y + z * z);
    });
    final sortedMags = List<double>.from(magsRaw)..sort();
    final oneGRaw = sortedMags[sortedMags.length ~/ 2];
    if (oneGRaw <= 0) {
      return FallSweepResult(
        sweptAt: startedAt,
        captureDurationS: durationS,
        sampleCount: accelX.length,
        events: const [],
        skipReason: 'calibration returned zero — accel stream was flat',
      );
    }

    final xMg = accelX
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);
    final yMg = accelY
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);
    final zMg = accelZ
        .map((v) => (v / oneGRaw * 1000).round())
        .toList(growable: false);

    final fsHz = accelX.length / durationS;
    final events = _fallDetector.detect(
      accelXMilliG: xMg,
      accelYMilliG: yMg,
      accelZMilliG: zMg,
      samplingRateHz: fsHz,
    );

    return FallSweepResult(
      sweptAt: startedAt,
      captureDurationS: durationS,
      sampleCount: accelX.length,
      events: events,
      calibratedOneGRaw: oneGRaw,
    );
  }

  /// Runs `sync.syncAll`, then evaluates the 24h gate for the retention
  /// sweep. Either runs the sweep and attaches its result, or sets
  /// `retentionSkipReason` on the returned `SyncRunResult`.
  Future<SyncRunResult> _runSyncWithRetention(String deviceId) async {
    final syncResult = await sync.syncAll(
      userId: ActiveSession.defaultUserId,
      deviceId: deviceId,
    );

    // Evaluate the retention gate after sync — order matters because the
    // aggregator inside syncAll may have just created new daily_metrics
    // rows. We don't want the sweep to clip rows the same run just wrote.
    final prefs = await SharedPreferences.getInstance();
    final lastSec = prefs.getInt(_kLastSweptAtKey);
    final now = DateTime.now().toUtc();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;

    if (lastSec != null) {
      final lastRunAt =
          DateTime.fromMillisecondsSinceEpoch(lastSec * 1000, isUtc: true);
      final elapsed = now.difference(lastRunAt);
      if (elapsed < const Duration(hours: _sweepIntervalHours)) {
        final hoursAgo = elapsed.inHours;
        final humanAgo = hoursAgo < 1
            ? '${elapsed.inMinutes}m ago'
            : '${hoursAgo}h ago';
        return SyncRunResult(
          steps: syncResult.steps,
          aggregated: syncResult.aggregated,
          retentionSkipReason: 'last ran $humanAgo',
        );
      }
    }

    final retention = await retentionSweep.sweepAll(now: now);
    await prefs.setInt(_kLastSweptAtKey, nowSec);
    return SyncRunResult(
      steps: syncResult.steps,
      aggregated: syncResult.aggregated,
      retention: retention,
    );
  }

  /// Populated when `_onTick` / `triggerNow` return null. Cleared on
  /// successful runs.
  String? lastSkipReason;

  void dispose() {
    _tickSub?.cancel();
    _runs.close();
    _fallSweeps.close();
  }
}

final periodicSyncCoordinatorProvider =
    Provider<PeriodicSyncCoordinator>((ref) {
  final ble = ref.watch(bleServiceProvider);
  final coord = PeriodicSyncCoordinator(
    sync: ref.watch(syncServiceProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
    retentionSweep: ref.watch(retentionSweepServiceProvider),
    ble: ble,
    tickStream: ble.periodicSyncTick,
  );
  ref.onDispose(coord.dispose);
  return coord;
});
