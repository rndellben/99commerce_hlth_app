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
  // HLT-11: native scheduler fires this every 30 min while connected. A
  // top-level coordinator listens and triggers SyncService.syncAll(...).
  // Kept as a broadcast stream so debug screens can also subscribe to log
  // when each tick fires.
  final _periodicSyncTick = StreamController<void>.broadcast();

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
  Stream<int> get heartRateMeasured => _heartRateMeasured.stream;
  Stream<double> get spo2Measured => _spo2Measured.stream;
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
  /// HLT-11: native scheduler ticks. One event ~every 30 min while
  /// connected. Subscribers should be idempotent and skip if a sync is
  /// already running.
  Stream<void> get periodicSyncTick => _periodicSyncTick.stream;

  BleService() {
    _setupEventChannels();
    _setupMethodCallHandler();
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
          _periodicSyncTick.add(null);
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
  }) async {
    final r = await _channel.invokeMethod('setScheduledMonitoring', {
      'hrInterval': hrInterval,
      'startInterval': startInterval,
      'spo2Interval': spo2Interval,
      'hrvInterval': hrvInterval,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  Future<Map<String, dynamic>> getScheduledHr() async {
    final r = await _channel.invokeMethod('getScheduledHr');
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

  Future<Map<String, dynamic>> getHrHistory() async {
    final r = await _channel.invokeMethod('getHrHistory');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<List<Map<String, dynamic>>> getSpO2History() async {
    final r = await _channel.invokeMethod('getSpO2History');
    if (r is! List) return const [];
    return r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
  }
}

class BleException implements Exception {
  final String message;
  BleException(this.message);

  @override
  String toString() => 'BleException: $message';
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
