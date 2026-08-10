import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/models/device.dart';
import 'package:hlth_app/core/processing/fall_detector.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_evaluator.dart';
import 'package:hlth_app/core/services/cloud_sync_service.dart';
import 'package:hlth_app/core/services/nightly_bp_capture_service.dart';
import 'package:hlth_app/core/services/ppg_analysis_service.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';
import 'package:hlth_app/core/sync/band_reconnector.dart';
import 'package:hlth_app/core/sync/band_sync_service.dart';
import 'package:hlth_app/core/sync/fall_sweep_service.dart';
import 'package:hlth_app/core/sync/periodic_sync_coordinator.dart';
import 'package:hlth_app/core/sync/retention_gate.dart';
import 'package:hlth_app/core/sync/sync_results.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The `_inFlight` latch: every awaited call in the coordinator must sit under
/// a `_bounded` ceiling, because a hang never reaches the `finally` that clears
/// the flag — and once it latches, EVERY later tick is dropped for the process
/// lifetime (no crumb, no state change; the 2026-07-07 "alive but deaf"
/// failure). See `_bounded`'s own doc comment.
///
/// `testWidgets` is used purely for its fake clock: the ceilings are 30 s–3 min
/// of wall time, and `tester.pump(duration)` elapses them instantly. No widget
/// is ever pumped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<int> ticks;
  late _FakeSync sync;
  late _FakeFallSweep fallSweep;
  late _FakePpgCapture ppgCapture;
  late _FakeNightlyBp nightlyBp;
  late PeriodicSyncCoordinator coord;

  /// Builds a coordinator whose every collaborator is a hand-written fake.
  /// `BandReconnector` is faked deliberately: the real one is started from the
  /// constructor and schedules a `Timer.periodic(5 min)` plus an unconditional
  /// `Future.delayed(10 s)` that `dispose()` does not cancel, which leaks
  /// timers into the harness (coverage-audit blocker B3).
  void build({
    required Future<bool> Function() asleep,
    bool stallFirstSyncAll = false,
  }) {
    ticks = StreamController<int>();
    sync = _FakeSync(stallFirstCall: stallFirstSyncAll);
    fallSweep = _FakeFallSweep();
    ppgCapture = _FakePpgCapture();
    nightlyBp = _FakeNightlyBp();
    coord = PeriodicSyncCoordinator(
      sync: sync,
      deviceRepo: _FakeDeviceRepo(),
      retentionGate: _FakeRetentionGate(),
      ble: _FakeBle(),
      cloudSync: _FakeCloudSync(),
      alertEvaluator: _FakeAlertEvaluator(),
      scheduledPpgCapture: ppgCapture,
      nightlyBpCapture: nightlyBp,
      authUserIdReader: () => null,
      fallSweep: fallSweep,
      reconnector: _FakeReconnector(),
      tickStream: ticks.stream,
      sleepOnset: _FakeSleepOnset(asleep),
    );
  }

  setUp(() {
    // The coordinator mirrors band-paired state into plain prefs on every
    // tick. The plugin's own in-package test hook, not a mocking library.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    coord.dispose();
    ticks.close();
  });

  /// Elapses more than the longest ceiling in the pipeline (`syncAll`, 3 min)
  /// on the fake clock, then drains whatever the expiry unblocked.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(minutes: 4));
    await tester.pump();
  }

  testWidgets('triggerNow: a stalled syncAll must not latch _inFlight',
      (tester) async {
    // The connect-edge path. `triggerNow` is fired on every
    // disconnected → connected transition, and a link drop mid-op means the
    // native history callback never arrives.
    build(asleep: () async => false, stallFirstSyncAll: true);

    var settled = false;
    SyncRunResult? result;
    unawaited(coord.triggerNow().then((r) {
      settled = true;
      result = r;
    }));
    await settle(tester);

    expect(settled, isTrue,
        reason: 'triggerNow must return once its ceiling expires, not hang '
            'forever on an unbounded _runSyncWithRetention');
    expect(result, isNull, reason: 'a stalled run reports a skip, not a result');
    expect(coord.lastSkipReason, isNotNull,
        reason: 'the stall must be visible to the debug screen');

    // The real damage is what happens NEXT: a latched flag drops every
    // subsequent tick at `if (_inFlight) return;`.
    ticks.add(30);
    await settle(tester);
    expect(fallSweep.runCount, 1,
        reason: 'the tick after a stalled triggerNow must still be processed');
  });

  testWidgets('_onTick: a hung sleep-onset detector must not latch _inFlight',
      (tester) async {
    // `isProbablyAsleep` does three unbounded awaited sqlite reads. Its own
    // try/catch defends the THROW path but cannot rescue a read that never
    // completes.
    build(asleep: () => Completer<bool>().future);

    ticks.add(30);
    await settle(tester);
    ticks.add(30);
    await settle(tester);

    expect(fallSweep.runCount, 2,
        reason: 'both ticks must reach the fall sweep — a hung '
            'isProbablyAsleep must not latch _inFlight and silently drop '
            'every later tick');
    expect(ppgCapture.asleepSeen, isFalse,
        reason: 'an expired sleep verdict resolves to awake, the conservative '
            'answer — never a fabricated ASLEEP');
    expect(nightlyBp.asleepSeen, isFalse);
  });

  testWidgets('_onTick: a throwing sleep-onset detector completes the tick',
      (tester) async {
    // Boundary contract guard. The callee already resolves its own errors to
    // `false`, so this pins the coordinator side of the seam rather than a
    // live defect.
    build(asleep: () async => throw StateError('sqlite read failed'));

    ticks.add(30);
    await settle(tester);

    expect(fallSweep.runCount, 1,
        reason: 'a throwing sleep verdict must not abort the captures that '
            'follow it');
    expect(ppgCapture.asleepSeen, isFalse);
  });

  testWidgets('_onTick: healthy pipeline runs every step, tick after tick',
      (tester) async {
    build(asleep: () async => true);

    ticks.add(30);
    await settle(tester);
    ticks.add(30);
    await settle(tester);

    expect(sync.calls, 2);
    expect(fallSweep.runCount, 2);
    expect(ppgCapture.calls, 2);
    expect(nightlyBp.calls, 2);
    expect(ppgCapture.asleepSeen, isTrue,
        reason: 'the live sleep verdict is computed once per tick and handed '
            'to both captures');
    expect(nightlyBp.asleepSeen, isTrue);
  });
}

/// Base that throws for any collaborator method the coordinator does not
/// touch, so an unnoticed new dependency fails loudly instead of silently.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeSync extends _Fake implements BandSyncService {
  _FakeSync({this.stallFirstCall = false});

  final bool stallFirstCall;
  int calls = 0;

  @override
  Future<SyncRunResult> syncAll({
    required String userId,
    required String deviceId,
  }) {
    calls++;
    if (stallFirstCall && calls == 1) {
      // A native history callback that never arrives.
      return Completer<SyncRunResult>().future;
    }
    return Future<SyncRunResult>.value(
      const SyncRunResult(steps: [], aggregated: true),
    );
  }
}

class _FakeDeviceRepo extends _Fake implements DeviceRepository {
  @override
  Future<Device?> getActiveForUser(String userId) async => Device(
        id: 'dev-1',
        userId: userId,
        displayName: 'H59',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        pairedAt: DateTime.utc(2026, 8, 1),
      );
}

class _FakeRetentionGate extends _Fake implements DailyRetentionGate {
  @override
  Future<RetentionGateOutcome> maybeSweep() async =>
      const RetentionGateOutcome(skipReason: 'last ran 1h ago');
}

class _FakeBle extends _Fake implements BleService {
  // Empty, so the constructor's connect-edge listener never fires and the
  // 1.5 s settle delay never schedules a triggerNow behind the test's back.
  @override
  Stream<BleConnectionState> get connectionState =>
      Stream<BleConnectionState>.empty();

  @override
  BleConnectionState get currentConnectionState => BleConnectionState.connected;
}

class _FakeCloudSync extends _Fake implements CloudSyncService {}

class _FakeAlertEvaluator extends _Fake implements AlertEvaluator {
  @override
  Future<List<AlertFireResult>> evaluateAll({
    required String userId,
    DateTime? now,
  }) async =>
      const [];
}

class _FakePpgCapture extends _Fake implements ScheduledPpgCaptureService {
  int calls = 0;
  bool? asleepSeen;

  @override
  Future<PpgAnalysisResult?> maybeRunDaily({
    required String userId,
    bool asleep = false,
  }) async {
    calls++;
    asleepSeen = asleep;
    return null;
  }
}

class _FakeNightlyBp extends _Fake implements NightlyBpCaptureService {
  int calls = 0;
  bool? asleepSeen;

  @override
  Future<({int sbp, int dbp})?> maybeRunNightly({
    required String userId,
    bool asleep = false,
  }) async {
    calls++;
    asleepSeen = asleep;
    return null;
  }
}

class _FakeFallSweep extends _Fake implements FallSweepService {
  int runCount = 0;

  @override
  Future<FallSweepResult> run() async {
    runCount++;
    return FallSweepResult(
      sweptAt: DateTime.utc(2026, 8, 10),
      captureDurationS: 30,
      sampleCount: 0,
      events: const [],
      skipReason: 'test: no accel captured',
    );
  }
}

/// Blocker B3: the real reconnector leaks a periodic timer and an
/// uncancellable delayed `tryNow` into the harness.
class _FakeReconnector extends _Fake implements BandReconnector {
  @override
  void start() {}

  @override
  Future<void> tryNow() async {}

  @override
  void dispose() {}
}

class _FakeSleepOnset extends _Fake implements SleepOnsetDetector {
  _FakeSleepOnset(this._verdict);

  final Future<bool> Function() _verdict;

  @override
  Future<bool> isProbablyAsleep({required String userId}) => _verdict();
}
