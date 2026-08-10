import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/processing/fall_detector.dart';
import 'package:hlth_app/core/repositories/battery_telemetry_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/activity_detector_service.dart';
import 'package:hlth_app/core/services/alerts/alert_evaluator.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/services/cloud_sync_service.dart';
import 'package:hlth_app/core/services/nightly_bp_capture_service.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';
import 'package:hlth_app/core/sync/band_reconnector.dart';
import 'package:hlth_app/core/sync/band_sync_service.dart';
import 'package:hlth_app/core/sync/fall_sweep_service.dart';
import 'package:hlth_app/core/sync/retention_gate.dart';
import 'package:hlth_app/core/sync/sync_results.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HLT-11: bridges the native scheduler's tick stream
/// (`BleService.periodicSyncTick`) to `BandSyncService.syncAll`. Lives in
/// Dart because the active user/device IDs are Dart-side state.
///
/// Resolves the active device on each tick by querying
/// `DeviceRepository.getActiveForUser(...)` — so the coordinator works
/// regardless of which screen is foregrounded.
///
/// Concurrency: an in-flight sync flag drops overlapping ticks rather
/// than queuing them. If a 30-min sync takes >30 min for some reason,
/// the next tick is skipped, not stacked.
///
/// The coordinator is pure sequencing: capture pipelines, the retention
/// gate, and reconnect ownership each live in their own service
/// (`FallSweepService`, `DailyRetentionGate`, `BandReconnector`).
class PeriodicSyncCoordinator {
  PeriodicSyncCoordinator({
    required this.sync,
    required this.deviceRepo,
    required this.retentionGate,
    required this.ble,
    required this.cloudSync,
    required this.alertEvaluator,
    required this.scheduledPpgCapture,
    required this.nightlyBpCapture,
    required this.authUserIdReader,
    required this.fallSweep,
    required this.reconnector,
    required Stream<int> tickStream,
    this.onTickIntervalMinutes,
    this.activityDetector,
    this.onActivityDetected,
    this.sleepOnset,
  }) {
    _tickSub = tickStream.listen((mins) {
      lastTickIntervalMin = mins;
      onTickIntervalMinutes?.call(mins);
      _onTick();
    });
    // Auto-sync on connect: every time the band transitions into
    // `connected`, kick off a one-shot sync so the home cards populate
    // without the user having to open the debug screen first. Guarded by
    // `_inFlight` so it composes cleanly with the periodic tick.
    _connSub = ble.connectionState.listen(_onConnectionChange);
    // Reconnect ownership lives in BandReconnector (immediate boot attempt
    // + every 5 min while disconnected).
    reconnector.start();
  }

  final BandSyncService sync;
  final DeviceRepository deviceRepo;
  final DailyRetentionGate retentionGate;
  final BleService ble;
  final CloudSyncService cloudSync;
  final AlertEvaluator alertEvaluator;
  final ScheduledPpgCaptureService scheduledPpgCapture;
  final NightlyBpCaptureService nightlyBpCapture;
  final String? Function() authUserIdReader;
  final FallSweepService fallSweep;
  final BandReconnector reconnector;
  StreamSubscription<int>? _tickSub;
  StreamSubscription<BleConnectionState>? _connSub;

  /// Most-recent native-tick cadence (minutes). Null until the first tick
  /// fires. Public for debug UIs that want to show "currently syncing
  /// every N min" without re-reading the native side.
  int? lastTickIntervalMin;

  /// Hook fired on every tick with the active interval in minutes. Used by
  /// the battery telemetry path so each row is tagged with the cadence
  /// that triggered it. Optional — null means "don't log telemetry".
  final void Function(int intervalMin)? onTickIntervalMinutes;

  /// Optional: detects sustained activity and, when found, calls
  /// [onActivityDetected] so the UI can prompt the user to start a workout.
  final ActivityDetectorService? activityDetector;
  final void Function(DateTime detectedAt)? onActivityDetected;

  /// Optional: live "asleep right now" estimate computed once per tick and
  /// handed to the nightly BP + PPG captures so they fire inside sleep
  /// instead of on wall-clock guesses.
  final SleepOnsetDetector? sleepOnset;

  BleConnectionState? _lastConnState;
  bool _inFlight = false;
  final _runs = StreamController<SyncRunResult>.broadcast();
  final _fallSweeps = StreamController<FallSweepResult>.broadcast();

  /// Most recent periodic-sync results. Debug screens subscribe to see
  /// when each tick fires and what it persisted.
  Stream<SyncRunResult> get runs => _runs.stream;

  /// HLT-5: results from the background fall sweep that runs after each
  /// periodic sync. Emits one event per scheduled tick (or per
  /// `triggerNow(fallSweep: true)`). See [FallSweepService].
  Stream<FallSweepResult> get fallSweeps => _fallSweeps.stream;

  /// Populated when `_onTick` / `triggerNow` return null. Cleared on
  /// successful runs.
  String? lastSkipReason;

  /// Fires `triggerNow()` once per `disconnected → connected` edge so
  /// data populates without the user having to open the debug screen.
  /// The band sometimes emits redundant `connected` events; we only act
  /// on the transition, not every duplicate.
  ///
  /// A 1.5s settle delay lets the band finish its post-connect time
  /// handshake before we start pulling — without it, the first sync can
  /// race the band's clock-set and land samples with stale timestamps.
  void _onConnectionChange(BleConnectionState state) {
    final prev = _lastConnState;
    _lastConnState = state;
    if (state != BleConnectionState.connected) return;
    if (prev == BleConnectionState.connected) return; // dedup
    Future<void>.delayed(const Duration(milliseconds: 1500), () async {
      try {
        await triggerNow();
      } catch (_) {
        // triggerNow already swallows per-step errors and surfaces via
        // `_runs`. Anything reaching here is unexpected — let it die
        // quietly so we don't kill the listener.
      }
      // The H59 is dormant until scheduled monitoring is enabled. The native
      // connect bootstrap binds + sets time but does NOT enable monitoring,
      // and nothing else does outside the debug screen — so HRV (and the
      // other scheduled metrics) never record for a normal user. That
      // starves Recovery of confidence and blocks Cardio Load entirely
      // (it needs sleep RMSSD). Enable it AFTER the first sync, which proves
      // the band is past its (sometimes ~1 min) bind/time-set handshake and
      // responsive. Idempotent + self-healing on every connect edge.
      try {
        // BP interval driven by the shared test knob (kBpSlotMinutes) so the
        // band's schedule matches the today-from-HR derivation cadence.
        await ble.setScheduledMonitoring(bpIntervalMinutes: kBpSlotMinutes);
      } catch (_) {}
    });
  }

  /// Runs [op] with a hard [limit] so a stalled BLE call can never hang the
  /// tick. The active-measurement steps (`startBpMeasurement`,
  /// `startMeasureHrRaw`, history pulls) complete via a native callback that
  /// simply never arrives if the link drops mid-op — without a ceiling that
  /// await hangs forever, `_onTick` never reaches its `finally`, `_inFlight`
  /// latches `true`, and EVERY later tick is silently dropped (root cause of
  /// overnight sync dying after one bad capture on a flaky link). On timeout
  /// or error we crumb and move on — the next tick retries.
  Future<T?> _bounded<T>(
    String label,
    Duration limit,
    Future<T> Function() op,
  ) async {
    try {
      return await op().timeout(limit);
    } on TimeoutException {
      Breadcrumbs.log('tick: $label timed out after ${limit.inSeconds}s — '
          'skipped (link likely stalled mid-op)');
      return null;
    } catch (e) {
      Breadcrumbs.log('tick: $label errored ($e)');
      return null;
    }
  }

  Future<void> _onTick() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final device = await deviceRepo.getActiveForUser(
        ActiveSession.defaultUserId,
      );
      // Mirror band-paired state into a plain pref the native
      // SyncWatchdogWorker can read ("flutter." prefix is added by the
      // plugin): with no band ever paired it skips reviving the headless
      // engine, so non-ring users never pay the background cost.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_bonded_band', device != null);
      } catch (_) {}
      if (device == null) return;
      // Self-healing tick: the native alarm chain keeps firing while the
      // band is disconnected (Doze fix, 2026-07-08), so an overnight BLE
      // drop is repaired HERE — reconnect, then let the connect-edge
      // trigger run the sync once the link is up. Skipping the sync now
      // avoids a burst of guaranteed-failure steps against a dead link.
      if (ble.currentConnectionState != BleConnectionState.connected) {
        Breadcrumbs.log('tick: band disconnected — attempting reconnect');
        await _bounded('reconnect', const Duration(seconds: 45), () async {
          await reconnector.tryNow();
          return true;
        });
        // Alert rules read only the local DB — a dropped BLE link must not
        // silence them (2026-07-14: the bedtime/morning reminders live in
        // exactly the hours overnight drops happen, and this early return
        // used to mute the whole alert engine all night). Every rule is
        // internally data-gated + rate-limited, so evaluating on stale-data
        // ticks is safe: rules that need fresh samples go quiet on their
        // own once their freshness windows lapse.
        try {
          await alertEvaluator
              .evaluateAll(userId: ActiveSession.defaultUserId);
        } catch (_) {}
        return;
      }
      final result = await _bounded('syncAll', const Duration(minutes: 3),
          () => _runSyncWithRetention(device.id));
      if (result == null) return; // stalled/errored — _inFlight resets, retry next tick
      _runs.add(result);
      Breadcrumbs.log('tick: synced ${result.totalSamples} samples, '
          '${result.failed.length} step errors');
      // Drain cloud outbox after band sync (non-fatal).
      try {
        final authUid = authUserIdReader();
        if (authUid != null) {
          await cloudSync.processOutbox(authUserId: authUid);
        }
      } catch (_) {}
      // Evaluate alert rules against the freshly-synced data (non-fatal).
      // Rate-limiting lives in the evaluator, so this is safe to run every
      // tick.
      try {
        await alertEvaluator.evaluateAll(userId: ActiveSession.defaultUserId);
      } catch (_) {}
      // VO2 max: detect a sustained activity bout and (debounced) prompt the
      // user to start a workout so the band records it. Read-only over the
      // just-synced HR + step data. Non-fatal.
      try {
        final detector = activityDetector;
        if (detector != null) {
          final detectedAt =
              await detector.evaluate(userId: ActiveSession.defaultUserId);
          if (detectedAt != null) onActivityDetected?.call(detectedAt);
        }
      } catch (_) {}
      // Live sleep estimate for the capture gates below — computed ONCE per
      // tick, right after sync, so both captures act on the same fresh HR +
      // step evidence. Ryan 2026-06-23: "when sleep is triggered, we trigger
      // these things to run" — the H59 has no realtime sleep event, so the
      // detector approximates it. Never throws (resolves to awake).
      final asleep = sleepOnset == null
          ? false
          : await sleepOnset!
              .isProbablyAsleep(userId: ActiveSession.defaultUserId);
      // HLT-5: run the background fall sweep once data sync is done.
      // Sequenced after sync so we never have two `startMeasureHrRaw`
      // sessions racing for the same BLE link.
      final fallResult = await _bounded(
          'fallSweep', const Duration(seconds: 90), () => fallSweep.run());
      if (fallResult != null) _fallSweeps.add(fallResult);
      // Step 3: once-a-day PPG capture for resting respiratory + HRV.
      // Sequenced last (after the fall sweep's raw window) so the two raw
      // captures never overlap. Daily-gated internally + non-fatal. The
      // asleep verdict bypasses the awake rest gate — sleep IS rest, and the
      // strongest RSA (respiratory) signal of the day.
      await _bounded('ppgCapture', const Duration(seconds: 120),
          () => scheduledPpgCapture.maybeRunDaily(
                userId: ActiveSession.defaultUserId,
                asleep: asleep,
              ));
      // Nightly resting BP: H59 has no retrievable scheduled-BP history, so
      // we fire our own on-demand measurement once per HOUR of sleep (Ryan
      // 2026-06-23: hourly BP cadence; sleep screen shows the sleep-window
      // average) — only on ticks where the user is actually ASLEEP (awake
      // ticks used to burn the attempt cap on motion readings).
      // Sequenced last (after the raw-PPG captures) so the band-side active
      // measurements never overlap. Gated + non-fatal.
      await _bounded('nightlyBp', const Duration(seconds: 120),
          () => nightlyBpCapture.maybeRunNightly(
                userId: ActiveSession.defaultUserId,
                asleep: asleep,
              ));
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
        final sweepResult = await this.fallSweep.run();
        _fallSweeps.add(sweepResult);
      }
      return result;
    } finally {
      _inFlight = false;
    }
  }

  /// Runs `sync.syncAll`, then evaluates the 24h retention gate. Either
  /// attaches the sweep result or the gate's skip reason to the returned
  /// `SyncRunResult`.
  Future<SyncRunResult> _runSyncWithRetention(String deviceId) async {
    final syncResult = await sync.syncAll(
      userId: ActiveSession.defaultUserId,
      deviceId: deviceId,
    );

    // Evaluate the retention gate after sync — order matters because the
    // aggregator inside syncAll may have just created new daily_metrics
    // rows. We don't want the sweep to clip rows the same run just wrote.
    final outcome = await retentionGate.maybeSweep();
    return SyncRunResult(
      steps: syncResult.steps,
      aggregated: syncResult.aggregated,
      retention: outcome.result,
      retentionSkipReason: outcome.skipReason,
    );
  }

  void dispose() {
    _tickSub?.cancel();
    _connSub?.cancel();
    _runs.close();
    _fallSweeps.close();
  }
}

final periodicSyncCoordinatorProvider =
    Provider<PeriodicSyncCoordinator>((ref) {
  final ble = ref.watch(bleServiceProvider);
  final telemetryRepo = ref.watch(batteryTelemetryRepositoryProvider);
  final coord = PeriodicSyncCoordinator(
    sync: ref.watch(bandSyncServiceProvider),
    deviceRepo: ref.watch(deviceRepositoryProvider),
    retentionGate: ref.watch(dailyRetentionGateProvider),
    ble: ble,
    cloudSync: ref.watch(cloudSyncServiceProvider),
    alertEvaluator: ref.watch(alertEvaluatorProvider),
    scheduledPpgCapture: ref.watch(scheduledPpgCaptureServiceProvider),
    nightlyBpCapture: ref.watch(nightlyBpCaptureServiceProvider),
    authUserIdReader: () => ref.read(currentUserIdProvider),
    fallSweep: ref.watch(fallSweepServiceProvider),
    reconnector: ref.watch(bandReconnectorProvider),
    tickStream: ble.periodicSyncTick,
    // VO2 max: surface a "start a workout?" prompt when sustained activity is
    // detected (debounced inside the detector).
    activityDetector: ref.watch(activityDetectorServiceProvider),
    // Live "asleep now" estimate — gates the nightly BP + sleep-window PPG
    // captures so they fire inside actual sleep.
    sleepOnset: ref.watch(sleepOnsetDetectorProvider),
    onActivityDetected: (detectedAt) =>
        ref.read(pendingWorkoutPromptProvider.notifier).flag(detectedAt),
    // Battery-drain telemetry — one row per tick. Fire-and-forget; we
    // never want a telemetry write to block the actual sync work.
    onTickIntervalMinutes: (intervalMin) async {
      try {
        final band = await ble.requestBattery();
        await telemetryRepo.insert(
          bandBatteryPercent: band?.level,
          bandCharging: band?.charging,
          syncIntervalMin: intervalMin,
          eventType: 'tick',
        );
      } catch (_) {
        // Swallow — telemetry must never break the actual sync.
      }
    },
  );
  ref.onDispose(coord.dispose);
  return coord;
});
