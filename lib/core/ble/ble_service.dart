import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/models/ppg_sample.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({required this.id, required this.name, required this.rssi});
}

class BleService {
  // Channel names match hlth-ble-platform-channel.md §1.
  static const _channel = MethodChannel('hlth/ble');
  static const _ppgStream = EventChannel('hlth/realtime_stream');
  // ignore: unused_field
  static const _accelStream = EventChannel('hlth/realtime_stream_accel');

  final _connectionState =
      StreamController<BleConnectionState>.broadcast();
  final _discoveredDevices = StreamController<List<BleDevice>>.broadcast();
  final _ppgData = StreamController<List<PpgSample>>.broadcast();
  final _accelData = StreamController<List<AccelerometerSample>>.broadcast();

  // Cached "latest values" for latched streams. Broadcast streams don't
  // replay history, so a widget that subscribes after navigation would
  // see `disconnected` / `null` until the next event. We seed new
  // subscribers with the current value via the getters below.
  BleConnectionState _currentConnectionState = BleConnectionState.disconnected;
  int? _currentBatteryLevel;
  bool? _currentCharging;
  int? _currentNativeBleState;

  // Latch for the last smoothed realtime HR push. Broadcast streams don't
  // replay, so a screen opened BETWEEN band pushes would miss the live value
  // its sibling screen is showing (home card "97" vs HR screen "89 · 4h ago")
  // and fall back to the stored sample. [realtimeHeartRateSeeded] replays
  // this to new subscribers while fresh.
  int? _lastRealtimeHr;
  DateTime? _lastRealtimeHrAt;

  /// How long a latched realtime HR may be replayed to a new subscriber as
  /// "live". Band pushes arrive every ~10s while monitoring; past 2 min the
  /// stored-sample fallback is the honest display.
  static const _realtimeHrFreshness = Duration(minutes: 2);

  // Raw native callbacks (one-shot measurements + telemetry). Debug screen
  // observes these directly; production features will consume them via the
  // health engine.
  final _realtimeHeartRate = StreamController<int>.broadcast();

  // 5-second time-windowed rolling-average buffer for realtime HR. Band
  // emits HR updates at varying cadences (every ~10s during scheduled
  // monitoring, ~10/sec during active raw-PPG capture). The home screen
  // card and the debug screen both flickered uncomfortably without
  // smoothing because the band's instantaneous estimates can swing
  // ±5 bpm between successive packets.
  //
  // Window is time-based, not count-based, so:
  //   - Slow stream (1 sample / 10 sec) → window holds 1 sample → smoothed
  //     output equals raw (degenerate but correct)
  //   - Fast stream (10 samples / sec)  → window holds ~50 samples → mean
  //
  // Pipeline equivalent: `np.convolve(hr, np.ones(N)/N, mode='valid')`
  // (see hlth_pipeline/notebooks/01_resting_hr.ipynb). Pipeline uses a
  // 10-min window for resting-HR derivation; here we use 5 sec because
  // this is display-only.
  //
  // Display-only — persisted samples in daily_metrics keep raw values.
  static const _hrSmoothingWindow = Duration(seconds: 5);
  final List<({DateTime ts, int bpm})> _hrBuffer = [];
  final _heartRateMeasured = StreamController<int>.broadcast();
  final _spo2Measured = StreamController<double>.broadcast();
  final _bloodPressureMeasured =
      StreamController<({int sbp, int dbp})>.broadcast();
  final _batteryUpdate = StreamController<({int level, bool charging})>.broadcast();
  final _nativeBleState = StreamController<int>.broadcast();
  // Raw PPG payloads as they arrive — schema isn't locked until we inspect
  // a real band's output, so debug consumers see the untyped map.
  final _rawPpgEvent = StreamController<List<Map<String, dynamic>>>.broadcast();
  // Proactive notifications from the band. dataType per SDK section 2.3.9:
  //   1=HR, 2=BP, 3=SpO2, 4=steps, 5=temp, 7=exercise record, 0x0c=charging
  final _deviceNotify =
      StreamController<({int dataType, List<int> loadData})>.broadcast();
  // HLT-11: native scheduler fires this every [syncIntervalMinutes] while
  // connected. A top-level coordinator listens and triggers
  // SyncService.syncAll(...). Each event carries the cadence in minutes so
  // telemetry can attribute drain to a specific interval setting.
  final _periodicSyncTick = StreamController<int>.broadcast();

  // Realtime manualMode* measurement streams. Each tick emits an
  // intermediate value during the band-side active measurement (~30s).
  // See [BleManager.kt] startSpo2Stream / startHrvStream — and the
  // documented list of NOT-streamable metrics there (sleep, steps,
  // temperature, ECG).
  /// Active-measurement HR stream (manualModeHeart). Distinct from
  /// [realtimeHeartRate] which is passive (DeviceNotifyListener).
  final _hrStream = StreamController<int>.broadcast();
  final _spo2Stream =
      StreamController<({int spo2, int hr})>.broadcast();
  final _hrvStream =
      StreamController<({int hrv, int hr, int stress})>.broadcast();

  // QWatch's hero "One Key Measurement" — single ~30s call via the SDK's
  // `startOneKey(0, 0, cb)` API. Returns HR + SpO2 + BP + fatigue + score
  // in a single StartCalcDataRsp.
  final _okmStream = StreamController<({
    int hr,
    int spo2,
    int sbp,
    int dbp,
    int fatigue,
    int score,
  })>.broadcast();

  // Seed new subscribers with the current latched value so a widget that
  // subscribes after navigation reflects reality instead of `disconnected`.
  Stream<BleConnectionState> get connectionState async* {
    yield _currentConnectionState;
    yield* _connectionState.stream;
  }

  BleConnectionState get currentConnectionState => _currentConnectionState;

  Stream<List<BleDevice>> get discoveredDevices => _discoveredDevices.stream;
  Stream<List<PpgSample>> get ppgData => _ppgData.stream;
  Stream<List<AccelerometerSample>> get accelData => _accelData.stream;
  Stream<int> get realtimeHeartRate => _realtimeHeartRate.stream;

  /// [realtimeHeartRate] plus an immediate replay of the last live value when
  /// it's still fresh (< [_realtimeHrFreshness]). UI screens use THIS so a
  /// screen opened between band pushes shows the same live bpm as its
  /// siblings. The raw [realtimeHeartRate] stays replay-free on purpose: the
  /// PPG quality-gate cross-check must only see HR the band reported DURING
  /// the capture window, never a stale replay.
  Stream<int> get realtimeHeartRateSeeded async* {
    final hr = _lastRealtimeHr;
    final at = _lastRealtimeHrAt;
    if (hr != null &&
        at != null &&
        DateTime.now().difference(at) < _realtimeHrFreshness) {
      yield hr;
    }
    yield* _realtimeHeartRate.stream;
  }

  Stream<int> get heartRateMeasured => _heartRateMeasured.stream;
  Stream<double> get spo2Measured => _spo2Measured.stream;
  Stream<int> get hrActiveStream => _hrStream.stream;
  Stream<({int spo2, int hr})> get spo2Stream => _spo2Stream.stream;
  Stream<({int hrv, int hr, int stress})> get hrvStream =>
      _hrvStream.stream;
  Stream<({int hr, int spo2, int sbp, int dbp, int fatigue, int score})>
      get oneKeyMeasurementStream => _okmStream.stream;
  Stream<({int sbp, int dbp})> get bloodPressureMeasured =>
      _bloodPressureMeasured.stream;

  Stream<({int level, bool charging})> get batteryUpdate async* {
    if (_currentBatteryLevel != null) {
      yield (level: _currentBatteryLevel!, charging: _currentCharging ?? false);
    }
    yield* _batteryUpdate.stream;
  }

  Stream<int> get nativeBleState async* {
    if (_currentNativeBleState != null) yield _currentNativeBleState!;
    yield* _nativeBleState.stream;
  }
  Stream<List<Map<String, dynamic>>> get rawPpgEvent => _rawPpgEvent.stream;
  Stream<({int dataType, List<int> loadData})> get deviceNotify =>
      _deviceNotify.stream;
  /// HLT-11: native scheduler ticks. One event each cadence interval while
  /// connected. Payload is the active interval in minutes (default 30, can
  /// be 10/15 during battery-drain testing). Subscribers should be
  /// idempotent and skip if a sync is already running.
  Stream<int> get periodicSyncTick => _periodicSyncTick.stream;

  BleService() {
    _setupEventChannels();
    _setupMethodCallHandler();
    _seedConnectionStateFromNative();
  }

  /// The native SDK's BLE link outlives Flutter engines: after a swipe-away →
  /// reopen, THIS is a brand-new engine attaching to a process whose band is
  /// often still connected — but we'd never know, because onConnected only
  /// fires on state CHANGES. Without this seed the UI shows a phantom
  /// "Disconnected" and users re-pair a band that was never disconnected.
  /// Fire-and-forget: on any failure we keep the `disconnected` default.
  Future<void> _seedConnectionStateFromNative() async {
    try {
      final res = await _channel.invokeMethod<Map>('getConnectionState');
      final connected = res?['connected'] == true;
      if (connected &&
          _currentConnectionState == BleConnectionState.disconnected) {
        _currentConnectionState = BleConnectionState.connected;
        _connectionState.add(BleConnectionState.connected);
      }
    } catch (_) {
      // Native side not ready / method missing — the default (disconnected)
      // stands until a real onConnected event arrives.
    }
  }

  void _setupEventChannels() {
    _ppgStream.receiveBroadcastStream().listen((data) {
      if (data is List) {
        final maps = data
            .cast<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _rawPpgEvent.add(maps);
        // Only deserialize into typed PpgSample once we know the band's
        // payload shape. Until then, keep typed stream empty.
        if (maps.isNotEmpty &&
            maps.first.containsKey('timestamp_ms') &&
            maps.first.containsKey('green')) {
          _ppgData.add(maps.map(PpgSample.fromMap).toList());
        }
      }
    });
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      switch (call.method) {
        case 'onRealtimeHeartRate':
          _onRealtimeHr((args as Map)['bpm'] as int);
          break;
        case 'onHeartRateMeasured':
          _heartRateMeasured.add((args as Map)['bpm'] as int);
          break;
        case 'onSpo2Measured':
          final raw = (args as Map)['spo2'];
          _spo2Measured.add(raw is int ? raw.toDouble() : raw as double);
          break;
        case 'onBloodPressureMeasured':
          final m = args as Map;
          _bloodPressureMeasured
              .add((sbp: m['sbp'] as int, dbp: m['dbp'] as int));
          break;
        case 'onBatteryUpdate':
          final m = args as Map;
          final lvl = m['battery'] as int;
          final chg = m['charging'] as bool;
          _currentBatteryLevel = lvl;
          _currentCharging = chg;
          _batteryUpdate.add((level: lvl, charging: chg));
          break;
        case 'onBleStateChange':
          final s = (args as Map)['state'] as int;
          _currentNativeBleState = s;
          _nativeBleState.add(s);
          break;
        case 'onConnected':
          _currentConnectionState = BleConnectionState.connected;
          _connectionState.add(BleConnectionState.connected);
          break;
        case 'onDisconnect':
          _currentConnectionState = BleConnectionState.disconnected;
          _connectionState.add(BleConnectionState.disconnected);
          // Drop any HR samples buffered from the previous session so
          // a reconnect doesn't average stale values into fresh ones.
          _hrBuffer.clear();
          break;
        case 'onDeviceNotify':
          final m = args as Map;
          final loadRaw = (m['loadData'] as List?) ?? const [];
          _deviceNotify.add((
            dataType: m['dataType'] as int,
            loadData: loadRaw.cast<int>(),
          ));
          break;
        case 'onPeriodicSyncTick':
          final m = args as Map?;
          final intervalMin = (m?['intervalMin'] as int?) ?? 30;
          _periodicSyncTick.add(intervalMin);
          break;
        case 'onHeartStream':
          _hrStream.add((args as Map)['hr'] as int);
          break;
        case 'onSpo2Stream':
          final m = args as Map;
          _spo2Stream
              .add((spo2: m['spo2'] as int, hr: m['hr'] as int));
          break;
        case 'onHrvStream':
          final m = args as Map;
          _hrvStream.add((
            hrv: m['hrv'] as int,
            hr: m['hr'] as int,
            stress: m['stress'] as int,
          ));
          break;
        case 'onOneKeyMeasurementStream':
          final m = args as Map;
          _okmStream.add((
            hr: m['hr'] as int,
            spo2: m['spo2'] as int,
            sbp: m['sbp'] as int,
            dbp: m['dbp'] as int,
            fatigue: (m['fatigue'] as int?) ?? 0,
            score: (m['score'] as int?) ?? 0,
          ));
          break;
      }
      return null;
    });
  }

  /// HLT-9: 5-sec rolling mean on the realtime HR stream. See the
  /// `_hrBuffer` doc comment for rationale.
  void _onRealtimeHr(int bpm) {
    final now = DateTime.now();
    _hrBuffer.add((ts: now, bpm: bpm));
    final cutoff = now.subtract(_hrSmoothingWindow);
    _hrBuffer.removeWhere((s) => s.ts.isBefore(cutoff));
    final sum = _hrBuffer.fold<int>(0, (a, s) => a + s.bpm);
    final smoothed = (sum / _hrBuffer.length).round();
    _lastRealtimeHr = smoothed;
    _lastRealtimeHrAt = now;
    _realtimeHeartRate.add(smoothed);
  }

  /// Triggers a BLE scan and returns the discovered devices directly.
  /// Also emits them on the `discoveredDevices` stream for any listeners.
  Future<List<BleDevice>> startScan() async {
    // Don't clobber a real connection state with `scanning` — if we're
    // already connected, keep showing connected. The native side will
    // emit onDisconnect if the scan actually drops us.
    if (_currentConnectionState != BleConnectionState.connected) {
      _currentConnectionState = BleConnectionState.scanning;
      _connectionState.add(BleConnectionState.scanning);
    }
    try {
      final result = await _channel.invokeMethod('startScan');
      if (result is! List) {
        _discoveredDevices.add(const []);
        return const [];
      }
      final devices = result.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return BleDevice(
          id: map['id'] as String,
          name: (map['name'] as String?) ?? 'Unknown',
          rssi: (map['rssi'] as num?)?.toInt() ?? -100,
        );
      }).toList();
      _discoveredDevices.add(devices);
      // Don't force a state — the native side emits onConnected/onDisconnect
      // via the receiver, and `scanning` was just transient. If we were
      // already connected, we still are.
      return devices;
    } on PlatformException catch (e) {
      _currentConnectionState = BleConnectionState.disconnected;
      _connectionState.add(BleConnectionState.disconnected);
      throw BleException('Scan failed: ${e.message}');
    }
  }

  Future<void> stopScan() async {
    await _channel.invokeMethod('stopScan');
  }

  Future<void> connect(String deviceId) async {
    _currentConnectionState = BleConnectionState.connecting;
    _connectionState.add(BleConnectionState.connecting);
    try {
      await _channel.invokeMethod('connect', {'deviceId': deviceId});
      _currentConnectionState = BleConnectionState.connected;
      _connectionState.add(BleConnectionState.connected);
    } on PlatformException catch (e) {
      _currentConnectionState = BleConnectionState.disconnected;
      _connectionState.add(BleConnectionState.disconnected);
      throw BleException('Connection failed: ${e.message}');
    }
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
    _currentConnectionState = BleConnectionState.disconnected;
    _connectionState.add(BleConnectionState.disconnected);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Manual measurement — hlth-ble-platform-channel.md §3.6
  // ──────────────────────────────────────────────────────────────────────

  /// Starts an active raw-PPG measurement (canonical
  /// `startMeasureHrRaw`). Band streams per-packet samples
  /// (green/red/IR + per-pulse HR/RRI/HRV + accel) on the
  /// `hlth/realtime_stream` EventChannel.
  Future<Map<String, dynamic>> startMeasureHrRaw({int durationSec = 30}) async {
    final r = await _channel
        .invokeMethod('startMeasureHrRaw', {'duration_sec': durationSec});
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  /// Canonical `stopMeasure`. `type` param selects which measurement to
  /// abort (`hr_raw` for the raw PPG capture).
  Future<void> stopMeasure({String type = 'hr_raw'}) async {
    await _channel.invokeMethod('stopMeasure', {'type': type});
  }

  /// Starts a blood-oxygen raw measurement. Same per-packet stream as
  /// [startMeasureHrRaw] (on `hlth/realtime_stream`), but this mode drives
  /// the red + IR LEDs, so `red`/`infrared` should carry data (the HR raw
  /// mode is green-only). Used to test whether the H59 firmware actually
  /// delivers red/IR for morphology work.
  Future<Map<String, dynamic>> startMeasureSpo2Raw({int durationSec = 30}) async {
    final r = await _channel
        .invokeMethod('startMeasureSpo2Raw', {'duration_sec': durationSec});
    return r is Map ? Map<String, dynamic>.from(r) : const {};
  }

  /// Stops the blood-oxygen raw measurement started by [startMeasureSpo2Raw].
  Future<void> stopMeasureSpo2Raw() async {
    await _channel.invokeMethod('stopMeasureSpo2Raw');
  }

  // ──────────────────────────────────────────────────────────────────────
  // Scheduled monitoring config — hlth-ble-platform-channel.md §3.5
  //
  // The H59 ring is dormant until scheduled monitoring is enabled. v1
  // exposes the multi-metric `setScheduledMonitoring` umbrella that the
  // SDK accepts in one call; step 5+ will split into the per-metric
  // setScheduledHr / setScheduledHrv / setScheduledSpO2 / setScheduledBp.
  // ──────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> setScheduledMonitoring({
    int hrInterval = 10,
    int startInterval = 5,
    int spo2Interval = 60,
    int hrvInterval = 30,
    int bpIntervalMinutes = 60,
  }) async {
    final r = await _channel.invokeMethod('setScheduledMonitoring', {
      'hrInterval': hrInterval,
      'startInterval': startInterval,
      'spo2Interval': spo2Interval,
      'hrvInterval': hrvInterval,
      'bpIntervalMinutes': bpIntervalMinutes,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> getScheduledHr() async {
    final r = await _channel.invokeMethod('getScheduledHr');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Whether the app is exempt from Android battery optimizations. Overnight
  /// background sync (foreground service + headless engine) is killed on
  /// battery-optimized devices — especially MIUI-style OEMs — so settings
  /// surfaces this. Android-only; returns false where unsupported.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final r =
          await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return (Map<String, dynamic>.from(r as Map)['ignoring'] as bool?) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS "let this app ignore battery optimizations" dialog.
  /// Android-only; no-op elsewhere.
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// Toggle the band's scheduled BP monitoring on/off and pick the cadence.
  /// Defaults: enabled, all-day window (00:00 → 23:59), every 60 minutes.
  Future<Map<String, dynamic>> setBpScheduled({
    required bool enabled,
    int intervalMinutes = 60,
    int startHour = 0,
    int startMinute = 0,
    int endHour = 23,
    int endMinute = 59,
  }) async {
    final r = await _channel.invokeMethod('setBpScheduled', {
      'enabled': enabled,
      'intervalMinutes': intervalMinutes,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// Read the band's current scheduled BP monitoring config. Returns
  /// `{isEnable, intervalMinutes, startHour, startMinute, endHour, endMinute}`.
  Future<Map<String, dynamic>> getBpScheduled() async {
    final r = await _channel.invokeMethod('getBpScheduled');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Toggle the band's scheduled stress ("pressure") monitoring on/off.
  /// The band picks its own cadence (~30 min slot per QWatch behavior).
  /// Returns `{isEnable: bool}`. H59 ack quirk: trust [getStressScheduled]
  /// for ground truth.
  Future<Map<String, dynamic>> setStressScheduled({
    required bool enabled,
  }) async {
    final r = await _channel.invokeMethod('setStressScheduled', {
      'enabled': enabled,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  /// Read the band's current scheduled stress monitoring state.
  /// Returns `{isEnable: bool}`.
  Future<Map<String, dynamic>> getStressScheduled() async {
    final r = await _channel.invokeMethod('getStressScheduled');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Per-day stress sync. Returns
  /// `{values: List<int> 0-100, intervalMinutes: int, offset: int, rawArray: List<int>}`.
  /// Shape mirrors HRV — each value is one slot of length `intervalMinutes`.
  Future<Map<String, dynamic>> getStressDay({int dayOffset = 0}) async {
    final r = await _channel.invokeMethod('getStressDay', {
      'dayOffset': dayOffset,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  // ──────────────────────────────────────────────────────────────────────
  // History fetch — hlth-ble-platform-channel.md §3.7
  //
  // Native responses are still in legacy shape (e.g. `{readings: [...]}`
  // with `timestamp_ms`); the canonical envelope (`{samples: [...]}` with
  // `captured_at_utc` + `tz_offset_min`) is applied at the repository
  // adapter layer in step 5.
  // ──────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHrHistory({int dayOffset = 0}) async {
    final r = await _channel.invokeMethod(
      'getHrHistory',
      {'dayOffset': dayOffset},
    );
    return Map<String, dynamic>.from(r as Map);
  }

  Future<List<Map<String, dynamic>>> getSpO2History() async {
    final r = await _channel.invokeMethod('getSpO2History');
    if (r is! List) return const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// SpO2 for a specific day (0=today, 1..29=N days ago) via the SDK's
  /// public per-day API. Returns the same shape as [getSpO2History] but
  /// always wraps a single-day entry in a one-element list.
  Future<List<Map<String, dynamic>>> getSpO2Day({int dayOffset = 0}) async {
    final r = await _channel.invokeMethod(
      'getSpO2Day',
      {'dayOffset': dayOffset},
    );
    if (r is! List) return const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// SpO2 per-minute interval samples for a day (probe for whether the H59
  /// exposes the fine-grained stream a breathing-disruption alert needs).
  /// Returns `{samples, total, nonZero, min, max, timedOut}`; `timedOut`
  /// true means the band never answered — i.e. interval SpO2 isn't supported.
  Future<Map<String, dynamic>> getSpO2Interval({int dayOffset = 0}) async {
    final r = await _channel
        .invokeMethod('getSpO2Interval', {'dayOffset': dayOffset});
    return Map<String, dynamic>.from(r as Map);
  }

  /// Read the device capability bitmap. The authoritative answer to whether
  /// the firmware supports per-minute interval SpO2 (separate from the
  /// SetTimeRsp bitmap read at bootstrap). Returns
  /// `{ok, supportIntervalBloodOxygen, supportIntervalHeartRate,
  /// supportIntervalTemperature, timedOut}`.
  Future<Map<String, dynamic>> getSpO2Capability() async {
    final r = await _channel.invokeMethod('getSpO2Capability');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Enable (or disable) periodic interval SpO2 monitoring at
  /// [intervalMinutes] cadence (1 = per-minute, the resolution a breathing-
  /// disruption alert needs). Returns the read-back `{ok, isEnable, interval,
  /// timedOut}` — ground truth on H59, whose write-ack is unreliable.
  Future<Map<String, dynamic>> enableSpO2Interval({
    bool enable = true,
    int intervalMinutes = 1,
  }) async {
    final r = await _channel.invokeMethod('enableSpO2Interval', {
      'enable': enable,
      'intervalMinutes': intervalMinutes,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> getHrvHistory({int dayOffset = 0}) async {
    final r = await _channel
        .invokeMethod('getHrvHistory', {'dayOffset': dayOffset});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> getBpHistory() async {
    final r = await _channel.invokeMethod('getBpHistory');
    return Map<String, dynamic>.from(r as Map);
  }

  /// BP per-day via the SDK's public API. Returns `{readings: [{time, sbp, dbp}]}` —
  /// real systolic/diastolic pairs (unlike [getBpHistory] which on H59 returns
  /// HR values dressed as BP).
  Future<Map<String, dynamic>> getBpDay({int dayOffset = 0}) async {
    final r = await _channel.invokeMethod(
      'getBpDay',
      {'dayOffset': dayOffset},
    );
    return Map<String, dynamic>.from(r as Map);
  }

  /// Trigger an on-demand BP measurement (~30s round-trip). Returns
  /// `{sbp, dbp, hr, errCode}` once the band completes the reading. Same
  /// path as the QRing demo's "Start Blood Pressure Measurement" button.
  Future<Map<String, dynamic>> startBpMeasurement() async {
    final r = await _channel.invokeMethod('startBpMeasurement');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Abort an in-flight BP measurement. Returns `{stopped: bool}`.
  Future<Map<String, dynamic>> stopBpMeasurement() async {
    final r = await _channel.invokeMethod('stopBpMeasurement');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Start an active-measurement HR stream (manualModeHeart). Subscribe
  /// to [hrActiveStream] for live bpm updates.
  Future<Map<String, dynamic>> startHeartStream() async {
    final r = await _channel.invokeMethod('startHeartStream');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> stopHeartStream() async {
    final r = await _channel.invokeMethod('stopHeartStream');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Start a realtime SpO2 stream (manualModeSpO2). Subscribe to
  /// [spo2Stream] to receive live `(spo2, hr)` updates during the ~30s
  /// active measurement. Returns `{started: bool}`.
  Future<Map<String, dynamic>> startSpo2Stream() async {
    final r = await _channel.invokeMethod('startSpo2Stream');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> stopSpo2Stream() async {
    final r = await _channel.invokeMethod('stopSpo2Stream');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Start a realtime HRV stream (manualModeHrv). Subscribe to [hrvStream]
  /// to receive live `(hrv, hr, stress)` updates during the measurement.
  Future<Map<String, dynamic>> startHrvStream() async {
    final r = await _channel.invokeMethod('startHrvStream');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> stopHrvStream() async {
    final r = await _channel.invokeMethod('stopHrvStream');
    return Map<String, dynamic>.from(r as Map);
  }

  /// QWatch's "One Key Measurement". Starts a ~30s band-side active
  /// measurement that streams HR + SpO2 + BP + HRV + Stress all at once
  /// via [oneKeyMeasurementStream]. The first ticks often have placeholder
  /// zeros while the band converges; the final tick has the full result.
  Future<Map<String, dynamic>> startOneKeyMeasurement() async {
    final r = await _channel.invokeMethod('startOneKeyMeasurement');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> stopOneKeyMeasurement() async {
    final r = await _channel.invokeMethod('stopOneKeyMeasurement');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Write the user's personal info + BP/HR baseline to the band.
  ///
  /// Wraps the SDK's `TimeFormatReq` "set personal info" call (sdk_ring.pdf
  /// "Setting Ring user Id" section). The trailing `baselineSbp / baselineDbp
  /// / hrWarnHigh` values double as the BP-calibration anchor — they become
  /// the reference points the band's scheduled-BP estimator drifts away
  /// from based on measured HR. Without this call the band falls back to
  /// the SDK helper's age-bracket defaults (random SBP in 100-120 + offset),
  /// which is why uncalibrated BP feels arbitrary.
  ///
  /// Returns `true` on success, `false` if the band rejected or the call
  /// failed before reaching it. Idempotent — safe to write on every
  /// calibration update; the band overwrites its stored copy.
  Future<bool> setPersonalInfo({
    required bool isMale,
    required int age,
    required int heightCm,
    required int weightKg,
    required int baselineSbp,
    required int baselineDbp,
    required int hrWarnHigh,
    bool is24h = true,
    bool metric = true,
  }) async {
    try {
      final r = await _channel.invokeMethod('setPersonalInfo', {
        'is24h': is24h,
        'metric': metric,
        'isMale': isMale,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'baselineSbp': baselineSbp,
        'baselineDbp': baselineDbp,
        'hrWarnHigh': hrWarnHigh,
      });
      if (r == null) return false;
      final m = Map<String, dynamic>.from(r as Map);
      return (m['set'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// One-shot poll of the band's battery level via the SDK's
  /// `CMD_GET_DEVICE_ELECTRICITY_VALUE` request. The same value is pushed
  /// to [batteryUpdate] subscribers automatically by the native side, so
  /// listeners don't need to await this — but awaiting it gives a
  /// "fetch on screen entry" surface for UIs that want a fresh number
  /// without waiting for the next bootstrap or periodic tick.
  ///
  /// Returns `null` if the band rejected the request (e.g. not bound) or
  /// the call failed before reaching the band.
  Future<({int level, bool charging})?> requestBattery() async {
    try {
      final r = await _channel.invokeMethod('getBattery');
      if (r == null) return null;
      final m = Map<String, dynamic>.from(r as Map);
      final level = (m['level'] as num?)?.toInt();
      if (level == null) return null;
      return (level: level, charging: (m['charging'] as bool?) ?? false);
    } catch (_) {
      return null;
    }
  }

  /// Set the periodic-sync cadence at runtime. Native side clamps to
  /// 5..60 min; returns the actually-applied cadence (and whether the
  /// request was clamped). Used by the BLE Debug "Battery Drain Test"
  /// panel to A/B 10 / 15 / 30 min intervals.
  Future<({int minutes, bool clamped})?> setSyncIntervalMinutes(int minutes) async {
    try {
      final r = await _channel.invokeMethod(
        'setSyncIntervalMinutes',
        {'minutes': minutes},
      );
      if (r == null) return null;
      final m = Map<String, dynamic>.from(r as Map);
      return (
        minutes: (m['minutes'] as num).toInt(),
        clamped: (m['clamped'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Sport mode (sdk_ring.pdf §2.3.10 "APP opens exercise type")
  //
  // The band has a dedicated workout state machine. While in sport mode
  // the band records HR much more densely than the scheduled-HR floor
  // (5 min) — readings are pushed via the existing DeviceNotifyListener
  // dataType=1 channel. After end, a summary is synced back via
  // SportPlusHandle.
  // ──────────────────────────────────────────────────────────────────────

  /// SDK byte values for the 8 curated exercise types per Ryan's
  /// 2026-06-17 call ("eight things people actually do"). Mapping comes
  /// from sdk_ring.pdf §2.3.10 / OdmSportPlusExerciseModelType.
  static const sportTypeRunning = 7;
  static const sportTypeWalking = 4;
  static const sportTypeCycling = 9;
  static const sportTypeHiking = 8;
  static const sportTypeRowing = 27;
  static const sportTypeElliptical = 26;
  static const sportTypeYoga = 22;
  static const sportTypeStrength = 88; // Indoor sports - strength training

  /// Start a band-side sport session. Returns `null` if the band rejected
  /// the request (e.g. not connected). On success, the band begins
  /// recording HR + distance + calories for this session, and emits HR
  /// change notifications via the existing `deviceNotify` stream
  /// (dataType=1) at firmware-driven cadence.
  Future<SportSessionAck?> startSportMode({required int sportType}) async {
    return _sendSportStatus('startSportMode', sportType);
  }

  Future<SportSessionAck?> pauseSportMode({required int sportType}) async {
    return _sendSportStatus('pauseSportMode', sportType);
  }

  Future<SportSessionAck?> resumeSportMode({required int sportType}) async {
    return _sendSportStatus('resumeSportMode', sportType);
  }

  /// End the active sport session. Caller should follow up with
  /// [syncSportSessions] to retrieve the workout summary.
  Future<SportSessionAck?> endSportMode({required int sportType}) async {
    return _sendSportStatus('endSportMode', sportType);
  }

  Future<SportSessionAck?> _sendSportStatus(String method, int sportType) async {
    try {
      final r = await _channel.invokeMethod(method, {'sportType': sportType});
      if (r == null) return null;
      final m = Map<String, dynamic>.from(r as Map);
      return SportSessionAck(
        status: (m['status'] as num).toInt(),
        sportType: (m['sportType'] as num).toInt(),
        gpsStatus: (m['gpsStatus'] as num?)?.toInt() ?? 0,
        timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Pull the most recent ~10 sport sessions the band has stored. Returns
  /// empty list on failure. The band evicts its oldest session each time
  /// a new one is recorded beyond the 10-session cap, so this should be
  /// called shortly after each workout ends.
  Future<List<SportSessionSummary>> syncSportSessions() async {
    try {
      final r = await _channel.invokeMethod('syncSportSessions');
      if (r == null) return const [];
      final m = Map<String, dynamic>.from(r as Map);
      final raw = (m['sessions'] as List?) ?? const [];
      return raw
          .map((e) => SportSessionSummary.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Read the currently-active periodic-sync cadence (minutes).
  Future<int?> getSyncIntervalMinutes() async {
    try {
      final r = await _channel.invokeMethod('getSyncIntervalMinutes');
      if (r == null) return null;
      final m = Map<String, dynamic>.from(r as Map);
      return (m['minutes'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getSleepHistory({int dayOffset = 0}) async {
    final r = await _channel
        .invokeMethod('getSleepHistory', {'dayOffset': dayOffset});
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> getDailyTotals() async {
    final r = await _channel.invokeMethod('getDailyTotals');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<List<Map<String, dynamic>>> getStepBucketHistory({
    int dayOffset = 0,
  }) async {
    final r = await _channel
        .invokeMethod('getStepBucketHistory', {'dayOffset': dayOffset});
    if (r is! List) return const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Demo-parity step buckets via public API (StepsActivity.kt:38-46).
  /// dayOffset 0 → getTodayStepDetail, 1..29 → getStepDetail(dayIndex).
  Future<List<Map<String, dynamic>>> getStepDay({int dayOffset = 0}) async {
    final r =
        await _channel.invokeMethod('getStepDay', {'dayOffset': dayOffset});
    if (r is! List) return const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void dispose() {
    _connectionState.close();
    _discoveredDevices.close();
    _ppgData.close();
    _accelData.close();
    _realtimeHeartRate.close();
    _heartRateMeasured.close();
    _spo2Measured.close();
    _bloodPressureMeasured.close();
    _batteryUpdate.close();
    _nativeBleState.close();
    _rawPpgEvent.close();
    _deviceNotify.close();
    _periodicSyncTick.close();
    _hrStream.close();
    _spo2Stream.close();
    _hrvStream.close();
    _okmStream.close();
  }
}

class BleException implements Exception {
  final String message;
  BleException(this.message);

  @override
  String toString() => 'BleException: $message';
}

/// Native ack for a `PhoneSportReq.getSportStatus(...)` call. The band
/// returns its current GPS status (0=closed, 6=ready, etc.) and the
/// timestamp it actually applied — useful for reconciling drift between
/// the phone's clock and the band's.
class SportSessionAck {
  const SportSessionAck({
    required this.status,
    required this.sportType,
    required this.gpsStatus,
    required this.timestamp,
  });

  /// 1=Start, 2=Pause, 3=Continue, 4=End — echo of the request status.
  final int status;
  final int sportType;
  final int gpsStatus;
  final int timestamp;
}

/// Workout summary returned by `SportPlusHandle.syncSportPlus(...)`.
/// Field semantics from sdk_ring.pdf "Synchronous training records" —
/// distance is meters, speed is cm/s, calories are "small calories" (the
/// SDK's term; treat as kcal for display, divide by 1000 if values look
/// inflated on real hardware).
class SportSessionSummary {
  const SportSessionSummary({
    required this.sportType,
    required this.startTimeUnixSec,
    required this.trainingStartTime,
    required this.durationSec,
    required this.distanceM,
    required this.calories,
    required this.avgSpeedCmS,
    required this.maxSpeedCmS,
    required this.avgHr,
    required this.minHr,
    required this.maxHr,
    required this.elevationCm,
    required this.uphillCm,
    required this.downhillCm,
    required this.stepRate,
    required this.steps,
    required this.locationCount,
  });

  factory SportSessionSummary.fromMap(Map<String, dynamic> m) =>
      SportSessionSummary(
        sportType: (m['sportType'] as num).toInt(),
        startTimeUnixSec: (m['startTime'] as num).toInt(),
        trainingStartTime: m['trainingStartTime'] as String? ?? '',
        durationSec: (m['duration'] as num).toInt(),
        distanceM: (m['distance'] as num).toInt(),
        calories: (m['calories'] as num).toDouble(),
        avgSpeedCmS: (m['speedAvg'] as num).toInt(),
        maxSpeedCmS: (m['speedMax'] as num).toInt(),
        avgHr: (m['rateAvg'] as num).toInt(),
        minHr: (m['rateMin'] as num).toInt(),
        maxHr: (m['rateMax'] as num).toInt(),
        elevationCm: (m['elevation'] as num).toInt(),
        uphillCm: (m['uphill'] as num).toInt(),
        downhillCm: (m['downhill'] as num).toInt(),
        stepRate: (m['stepRate'] as num).toInt(),
        steps: (m['steps'] as num).toInt(),
        locationCount: (m['locationCount'] as num).toInt(),
      );

  final int sportType;
  final int startTimeUnixSec;
  final String trainingStartTime;
  final int durationSec;
  final int distanceM;
  final double calories;
  final int avgSpeedCmS;
  final int maxSpeedCmS;
  final int avgHr;
  final int minHr;
  final int maxHr;
  final int elevationCm;
  final int uphillCm;
  final int downhillCm;
  final int stepRate;
  final int steps;
  final int locationCount;
}

// --- Riverpod Providers ---

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

final bleConnectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  return ref.watch(bleServiceProvider).connectionState;
});

final discoveredDevicesProvider = StreamProvider<List<BleDevice>>((ref) {
  return ref.watch(bleServiceProvider).discoveredDevices;
});
