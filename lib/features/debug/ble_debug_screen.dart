import 'dart:async';

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/processing/hrv_calculator.dart';
import 'package:hlth_app/core/processing/respiratory_rate.dart';
import 'package:hlth_app/core/processing/signal_processor.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/activity_classifier.dart';
import 'package:hlth_app/core/repositories/baseline_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/services/baseline_service.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Phase 0 debug screen — exercises the native BLE bridge end-to-end so we
/// can confirm:
///   1. Permissions are granted
///   2. CoreBluetooth / Android BLE scan finds the band
///   3. QCBandSDK / QRing SDK binds the peripheral
///   4. One-shot measurements return real values
///   5. PPG event channel delivers samples
///
/// This screen is not part of the production UI — it's the deliverable from
/// the plan's Phase 0 ("just a debug screen showing raw numbers").
class BleDebugScreen extends ConsumerStatefulWidget {
  const BleDebugScreen({super.key});

  @override
  ConsumerState<BleDebugScreen> createState() => _BleDebugScreenState();
}

class _BleDebugScreenState extends ConsumerState<BleDebugScreen> {
  final List<_LogEntry> _log = [];
  List<BleDevice> _devices = [];
  String? _selectedDeviceId;
  bool _scanning = false;
  bool _connected = false;

  int? _lastRealtimeHr;
  int? _lastMeasuredHr;
  double? _lastSpo2;
  int? _battery;
  int? _nativeBleState;
  int _ppgPacketCount = 0;

  // Bootstrapped on successful connect — required for every health-row insert
  // because (user_id, device_id) are FK provenance columns per hlth-db-schema §3.0.
  String? _activeUserId;
  String? _activeDeviceId;

  // Buffer of green-channel PPG samples accumulated during a capture
  // session. Cleared on each Capture PPG tap. The Analyze button reads
  // this buffer and runs the signal-processing pipeline.
  final List<double> _ppgGreenBuffer = [];
  int? _captureStartMs;
  int? _captureEndMs; // frozen when capture stops — used to compute true fs
  bool _capturing = false;

  final List<StreamSubscription<dynamic>> _subs = [];

  // Debug-screen UI state — collapse controls when you want the log to
  // breathe, or maximize the log to read long raw dumps.
  bool _logMaximized = false;
  bool _statusExpanded = true;
  bool _actionsExpanded = true;

  @override
  void initState() {
    super.initState();
    // Subscribe in the next frame so we have access to the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListeners());
  }

  void _attachListeners() {
    final ble = ref.read(bleServiceProvider);
    // Seed from the service's cached state so re-entry to this screen
    // reflects reality (native side may already be connected).
    setState(() {
      _connected = ble.currentConnectionState == BleConnectionState.connected;
    });
    _subs.addAll([
      ble.connectionState.listen((state) {
        setState(() => _connected = state == BleConnectionState.connected);
        _push('connectionState: $state');
      }),
      ble.realtimeHeartRate.listen((hr) {
        setState(() => _lastRealtimeHr = hr);
        _push('realtime HR: $hr bpm');
      }),
      ble.heartRateMeasured.listen((hr) {
        setState(() => _lastMeasuredHr = hr);
        _push('measured HR: $hr bpm');
      }),
      ble.spo2Measured.listen((v) {
        setState(() => _lastSpo2 = v);
        _push('SpO2: ${v.toStringAsFixed(1)}%');
      }),
      ble.bloodPressureMeasured.listen((bp) {
        _push('BP: ${bp.sbp}/${bp.dbp} mmHg');
      }),
      ble.batteryUpdate.listen((b) {
        setState(() => _battery = b.level);
        _push('battery: ${b.level}% (charging=${b.charging})');
      }),
      ble.nativeBleState.listen((s) {
        setState(() => _nativeBleState = s);
        _push('native BLE state: $s');
      }),
      ble.rawPpgEvent.listen((samples) {
        setState(() => _ppgPacketCount += samples.length);
        // Only buffer while a capture is actively running. Filter out
        // green=0 packets — these are SDK status/empty packets that
        // contaminate the buffer and cause huge spikes in the bandpass.
        if (_capturing) {
          for (final s in samples) {
            final g = s['green'];
            if (g is num && g > 0) _ppgGreenBuffer.add(g.toDouble());
          }
        }
        if (samples.isNotEmpty) {
          _push('PPG packet (${samples.length} samples): ${samples.first}');
        }
      }),
      // HLT-11: log when the native scheduler fires + what each run did.
      ble.periodicSyncTick.listen((_) {
        _push('★ periodic sync tick fired (every 30 min while connected)');
      }),
      ref.read(periodicSyncCoordinatorProvider).runs.listen((result) {
        final ok = result.allOk ? 'OK' : 'partial';
        _push('★ periodic syncAll: $ok '
            '(${result.totalSamples} samples, '
            'aggregate=${result.aggregated ? "OK" : "skip"})');
        for (final step in result.steps.where((s) => !s.ok)) {
          _push('  ↳ ${step.metric}: ${step.error}');
        }
      }),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Compact preview of a List for raw-payload dumps. Truncates at `max`
  /// entries and appends "+N more" if the list is longer.
  String _preview(Object? list, int max) {
    if (list is! List) return '$list';
    if (list.length <= max) return list.toString();
    final head = list.take(max).toList();
    return '${head.toString().substring(0, head.toString().length - 1)}, +${list.length - max} more]';
  }

  void _push(String message) {
    setState(() {
      _log.insert(0, _LogEntry(DateTime.now(), message));
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<bool> _ensurePermissions() async {
    // On Android 12+ we declared `BLUETOOTH_SCAN` with `neverForLocation`
    // flag in the manifest, so location is NOT required for BLE scanning.
    // Only block on the BLE permissions. We still REQUEST location (for
    // older Android) but don't fail if denied.
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final bleOk =
        (statuses[Permission.bluetoothScan]?.isGranted ?? false) &&
            (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

    if (!bleOk) {
      _push('BLE permissions denied: $statuses');
      return false;
    }
    if (!(statuses[Permission.locationWhenInUse]?.isGranted ?? false)) {
      _push('note: location denied (ok on Android 12+, may matter on older)');
    }
    return true;
  }

  Future<void> _scan() async {
    if (!await _ensurePermissions()) return;
    setState(() {
      _scanning = true;
      _devices = [];
    });
    _push('scan: requesting (10s)...');
    try {
      final ble = ref.read(bleServiceProvider);
      final devices = await ble.startScan();
      if (mounted) setState(() => _devices = devices);
      _push('scan complete: ${devices.length} device(s)');
      for (final d in devices) {
        _push('  → ${d.name} (${d.id}) rssi=${d.rssi}');
      }
    } catch (e) {
      _push('scan error: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    final id = _selectedDeviceId;
    if (id == null) {
      _push('connect: no device selected');
      return;
    }
    _push('connect: $id');
    try {
      await ref.read(bleServiceProvider).connect(id);
      setState(() => _connected = true);
      _push('connect: OK');

      // Bootstrap active user/device so every persisted health row has
      // valid FK targets.
      final selected = _devices.firstWhere(
        (d) => d.id == id,
        orElse: () => BleDevice(id: id, name: id, rssi: -100),
      );
      final session = ref.read(activeSessionProvider);
      final deviceRowId = await session.ensureDevice(
        bandId: id,
        displayName: selected.name,
        model: 'H59',
      );
      _activeUserId = ActiveSession.defaultUserId;
      _activeDeviceId = deviceRowId;
      _push('session: user=$_activeUserId device=$deviceRowId');
    } catch (e) {
      _push('connect error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await ref.read(bleServiceProvider).disconnect();
      setState(() => _connected = false);
      _push('disconnect: OK');
    } catch (e) {
      _push('disconnect error: $e');
    }
  }

  Future<void> _enableMonitoring() async {
    // Ask which hrInterval to write. 10 = production default; 1 = HLT-9
    // realtime-HR test mode (dataType=1 fires within ~1 min). Per H59
    // capabilities memory the band may silently coerce unsupported values
    // — the read-back log line shows what actually stuck.
    final hrMin = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('HR sampling interval'),
        children: [
          for (final m in [1, 5, 10, 15, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(
                m == 10
                    ? '$m min  (production default)'
                    : m == 1
                        ? '$m min  (HLT-9 realtime test)'
                        : '$m min',
              ),
            ),
        ],
      ),
    );
    if (hrMin == null) return;
    _push('setScheduledMonitoring: hr=${hrMin}min, start=5min...');
    try {
      final r = await ref
          .read(bleServiceProvider)
          .setScheduledMonitoring(hrInterval: hrMin);
      _push('setScheduledMonitoring: OK $r');
      // Give the band a moment to commit the write before reading back.
      // Without this delay the read fires too fast and returns stale state
      // (we've seen isEnable=false even when monitoring is in fact starting).
      await Future.delayed(const Duration(seconds: 2));
      final settings = await ref.read(bleServiceProvider).getScheduledHr();
      _push('settings now: $settings');
    } catch (e) {
      _push('setScheduledMonitoring error: $e');
    }
  }

  bool _requireSession() {
    if (_activeUserId == null || _activeDeviceId == null) {
      _push('no session — connect a band first');
      return false;
    }
    return true;
  }

  Future<void> _getHeartRate() async {
    if (!_requireSession()) return;
    _push('getHrHistory: requesting...');
    final res = await ref.read(syncServiceProvider).syncHr(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
        );
    if (!res.ok) {
      _push('getHrHistory error: ${res.error}');
      return;
    }
    final r = res.rawMap ?? const {};
    final readings = (r['readings'] as List?) ?? const [];
    final size = r['size'];
    _push('getHrHistory: size=$size, ${readings.length} non-zero readings');
    if (res.note != null) {
      _push('  (${res.note})');
      return;
    }
    _push('  raw: endFlag=${r['endFlag']} index=${r['index']} size=${r['size']} utcTime=${r['utcTime']}');
    final rawArr = (r['rawArray'] as List?) ?? const [];
    _push('  rawArray[${rawArr.length}]: ${_preview(rawArr, 24)}');
    for (final reading in readings.take(8)) {
      _push('    $reading');
    }
    if (readings.length > 8) _push('    ... +${readings.length - 8} more');
    final intervalMin = res.extra?['hrIntervalMin'] ?? 10;
    _push('  persisted ${res.count} HR sample(s) (intervalMin=$intervalMin)');
  }

  Future<void> _getSpo2() async {
    if (!_requireSession()) return;
    _push('getSpO2History: requesting...');
    final res = await ref.read(syncServiceProvider).syncSpo2(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
        );
    if (!res.ok) {
      _push('getSpO2History error: ${res.error}');
      return;
    }
    final entries = res.rawList ?? const [];
    _push('getSpO2History: ${entries.length} day(s) of data');
    for (final day in entries) {
      if (day is Map) {
        _push('  day=${day['dateStr']} unixTime=${day['unixTime']}');
        _push('    minArray[24]=${_preview(day['minArray'], 24)}');
        _push('    maxArray[24]=${_preview(day['maxArray'], 24)}');
      }
    }
    _push('  persisted ${res.count} SpO2 hourly sample(s)');
  }

  Future<void> _getSleep() async {
    if (!_requireSession()) return;
    _push('getSleepHistory: requesting...');
    final res = await ref.read(syncServiceProvider).syncSleep(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
        );
    if (!res.ok) {
      _push('getSleepHistory error: ${res.error}');
      return;
    }
    final r = res.rawMap ?? const {};
    final stages = (r['stages'] as List?) ?? const [];
    _push('  raw totals:');
    _push('    totalSleepDuration=${r['totalSleepDuration']}');
    _push('    deepDuration=${r['deepDuration']}  shallowDuration=${r['shallowDuration']}');
    _push('    rapidDuration=${r['rapidDuration']}  awakeDuration=${r['awakeDuration']}');
    _push('    sleepTime=${r['sleepTime']}  wakeTime=${r['wakeTime']}  wakingCount=${r['wakingCount']}');
    _push('  raw stages (${stages.length}):');
    for (var i = 0; i < stages.length && i < 12; i++) {
      _push('    [$i] ${stages[i]}');
    }
    if (stages.length > 12) _push('    ... +${stages.length - 12} more');
    if (res.note != null) {
      _push('  (${res.note})');
      return;
    }
    final sessionId = res.extra?['sessionId'] as String? ?? '';
    final totalMin = res.extra?['totalMin'];
    _push('  persisted session ${sessionId.length >= 8 ? sessionId.substring(0, 8) : sessionId}…, ${res.count} epochs '
        '(total=${totalMin}min)');
  }

  Future<void> _getSteps() async {
    if (!_requireSession()) return;
    _push('getDailyTotals: requesting...');
    final res = await ref.read(syncServiceProvider).syncSteps(
          userId: _activeUserId!,
        );
    if (!res.ok) {
      _push('getDailyTotals error: ${res.error}');
      return;
    }
    final r = res.rawMap ?? const {};
    _push('  raw: date=${r['year']}-${r['month']}-${r['day']}  daysAgo=${r['daysAgo']}');
    _push('  totalSteps=${r['totalSteps']}  runningSteps=${r['runningSteps']}');
    _push('  walkDistance=${r['walkDistance']}m  calorie=${r['calorie']}');
    _push('  sportDurationSec=${r['sportDurationSec']}  sleepDurationSec=${r['sleepDurationSec']}');
    if (res.note != null) {
      _push('  (${res.note})');
      return;
    }
    final localDate = res.extra?['localDate'] ?? '';
    _push('  persisted daily_metrics for $localDate');
  }

  Future<void> _getStepBuckets() async {
    if (!_requireSession()) return;
    _push('getStepBucketHistory: requesting (today)...');
    final res = await ref.read(syncServiceProvider).syncStepBuckets(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
        );
    if (!res.ok) {
      _push('getStepBucketHistory error: ${res.error}');
      return;
    }
    final native = res.rawList ?? const [];
    _push('getStepBucketHistory: ${native.length} bucket(s) returned');
    var shown = 0;
    for (final raw in native) {
      if (raw is! Map) continue;
      final walk = (raw['walkSteps'] as num?)?.toInt() ?? 0;
      final run = (raw['runSteps'] as num?)?.toInt() ?? 0;
      if (walk + run == 0) continue; // skip empty 15-min slots
      if (shown < 12) {
        _push('    $raw');
        shown++;
      }
    }
    if (shown == 0) {
      _push('  (all 96 buckets are empty — band may not have step data yet)');
    }
    _push('  persisted ${res.count} non-empty bucket(s)');
  }

  Future<void> _getHrv() async {
    if (!_requireSession()) return;
    // SDK supports dayOffset 0..6 (today through 6 days ago). Lets us
    // chase down HRV samples that may be stored under yesterday's date
    // after an overnight wear.
    final dayOffset = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('HRV day offset'),
        children: [
          for (final d in [0, 1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text(
                d == 0
                    ? '$d  (today)'
                    : d == 1
                        ? '$d  (yesterday)'
                        : '$d  ($d days ago)',
              ),
            ),
        ],
      ),
    );
    if (dayOffset == null) return;
    _push('getHrvHistory: requesting (dayOffset=$dayOffset)...');
    final res = await ref.read(syncServiceProvider).syncHrv(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          dayOffset: dayOffset,
        );
    if (!res.ok) {
      _push('getHrvHistory error: ${res.error}');
      return;
    }
    final r = res.rawMap ?? const {};
    final values = (r['values'] as List?) ?? const [];
    final intervalMin = r['intervalMinutes'];
    final rawArr = (r['rawArray'] as List?) ?? const [];
    _push('getHrvHistory: ${values.length} value(s), intervalMinutes=$intervalMin');
    _push('  rawArray[${rawArr.length}]: ${_preview(rawArr, 24)}');
    _push('  values: ${_preview(values, 16)}');
    _push('  persisted ${res.count} HRV sample(s)');
  }

  Future<void> _getBp() async {
    if (!_requireSession()) return;
    _push('getBpHistory: requesting...');
    try {
      final r = await ref.read(bleServiceProvider).getBpHistory();
      // Raw native payload. NOTE: on H59 the "BP timing monitor" returns
      // hourly HR readings, NOT true BP. We log them but do not persist
      // as bp_readings — that would mislead downstream consumers.
      _push('  raw: date=${r['year']}-${r['month']}-${r['day']}  timeDelay=${r['timeDelay']}');
      final readings = (r['readings'] as List?) ?? const [];
      _push('  readings (${readings.length}):');
      for (var i = 0; i < readings.length && i < 12; i++) {
        _push('    [$i] ${readings[i]}');
      }
      if (readings.length > 12) _push('    ... +${readings.length - 12} more');
      _push('  (NOT persisted — H59 BP timing monitor returns hourly HR, not real BP)');
      // Touch the BP repo so the analyzer doesn't drop the unused import.
      ref.read(bpRepositoryProvider);
    } catch (e) {
      _push('getBpHistory error: $e');
    }
  }

  /// HLT-11: triggers SyncService.syncAll via the coordinator. Same flow
  /// the native 30-min tick uses, just on-demand for testing.
  Future<void> _runAllSyncs() async {
    if (!_requireSession()) return;
    _push('runAll: triggering full sync sweep...');
    final coord = ref.read(periodicSyncCoordinatorProvider);
    final result = await coord.triggerNow();
    if (result == null) {
      _push('runAll: skipped — ${coord.lastSkipReason ?? "unknown reason"}');
      return;
    }
    for (final step in result.steps) {
      if (step.ok) {
        final note = step.note != null ? '  (${step.note})' : '';
        _push('  ${step.metric}: ${step.count} sample(s)$note');
      } else {
        _push('  ${step.metric}: ERROR — ${step.error}');
      }
    }
    _push('  aggregate: ${result.aggregated ? "OK" : "skipped/failed"}');
    _push('runAll: ${result.allOk ? "OK" : "completed with errors"} '
        '(${result.totalSamples} total samples)');
  }

  Future<void> _aggregate() async {
    final userId = _activeUserId ?? ActiveSession.defaultUserId;
    _push('aggregate: rebuilding last 14 days of daily_metrics...');
    try {
      await ref.read(dailyAggregatorProvider).aggregateRecent(
            userId: userId,
            days: 14,
          );
      _push('aggregate: done');
      final written = await ref
          .read(baselineServiceProvider)
          .recomputeAll(userId: userId);
      _push('baselines: $written row(s) recomputed');

      // Verbose dump — what actually landed in today's row.
      final today = DateTime.now();
      final todayLocal = DateTime(today.year, today.month, today.day);
      final dm = await ref
          .read(dailyMetricsRepositoryProvider)
          .getForDay(userId: userId, localDate: todayLocal);
      if (dm == null) {
        _push('today daily_metrics: (no row)');
      } else {
        _push('today (${dm.localDate.toIso8601String().substring(0, 10)}):');
        _push('  resting_hr_bpm:        ${dm.restingHrBpm ?? "—"}');
        _push('  hrv_rmssd_ms:          ${dm.hrvRmssdMs?.toStringAsFixed(1) ?? "—"}');
        _push('  hrv_sdnn_ms:           ${dm.hrvSdnnMs?.toStringAsFixed(1) ?? "—"}');
        _push('  spo2_overnight_avg:    ${dm.spo2OvernightAvg?.toStringAsFixed(1) ?? "—"}');
        _push('  spo2_overnight_min:    ${dm.spo2OvernightMin ?? "—"}');
        _push('  sleep_total_min:       ${dm.sleepTotalMin ?? "—"}');
        _push('  sleep_efficiency_pct:  ${dm.sleepEfficiencyPct?.toStringAsFixed(2) ?? "—"}');
        _push('  steps:                 ${dm.steps ?? "—"}');
        _push('  distance_m:            ${dm.distanceM ?? "—"}');
        _push('  calories_kcal:         ${dm.caloriesKcal?.toStringAsFixed(0) ?? "—"}');
        _push('  resp_rate_bpm:         ${dm.restingRespRateBpm?.toStringAsFixed(1) ?? "—"}');
        _push('  active_minutes:        ${dm.activeMinutes ?? "—"}');
      }

      // Activity-zone breakdown — runs ActivityClassifier over today's
      // step buckets so we can see exactly where the active_minutes came
      // from. Sedentary / light excluded from active_minutes total per
      // Apple's "Exercise Ring" convention.
      final todayBuckets = await ref
          .read(stepBucketRepositoryProvider)
          .getForDay(
            userId: userId,
            localDate: todayLocal,
            tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
          );
      if (todayBuckets.isEmpty) {
        _push('activity zones: (no step_buckets — tap Sync StepBkts first)');
      } else {
        final classifier = ActivityClassifier();
        final zones = classifier.minutesByZone(todayBuckets);
        _push('activity zones (today, ${todayBuckets.length} bucket(s)):');
        for (final z in ActivityZone.values) {
          final m = zones[z] ?? 0;
          if (m > 0) _push('  ${z.label.padRight(10)} ${m}min');
        }
      }

      // Show every 14-day baseline that has data.
      final baselineRepo = ref.read(baselineRepositoryProvider);
      _push('baselines (14d):');
      for (final m in BaselineMetric.all) {
        final b = await baselineRepo.getCurrent(
          userId: userId,
          metricKey: m,
          windowDays: 14,
          forDate: todayLocal,
        );
        if (b == null) {
          _push('  $m: (no data)');
        } else {
          _push(
              '  $m: mean=${b.meanValue.toStringAsFixed(1)} σ=${b.stddevValue.toStringAsFixed(1)} n=${b.sampleCount}');
        }
      }
    } catch (e) {
      _push('aggregate error: $e');
    }
  }

  Future<void> _capturePpg() async {
    if (!_connected) {
      _push('PPG capture: not connected');
      return;
    }
    setState(() => _ppgPacketCount = 0);
    _ppgGreenBuffer.clear();
    _captureStartMs = DateTime.now().millisecondsSinceEpoch;
    _captureEndMs = null;
    _capturing = true;
    _push('PPG capture: starting 30s measurement...');
    try {
      final r = await ref.read(bleServiceProvider).startMeasureHrRaw(durationSec: 30);
      _push('PPG capture: started $r');
      // Auto-stop after 31s in case the band keeps streaming.
      Future.delayed(const Duration(seconds: 31), () async {
        if (!mounted) return;
        try {
          await ref.read(bleServiceProvider).stopMeasure();
          _captureEndMs = DateTime.now().millisecondsSinceEpoch;
          _capturing = false;
          _push('PPG capture: stopped — total packets=$_ppgPacketCount');
        } catch (e) {
          _push('PPG stop error: $e');
        }
      });
    } catch (e) {
      _push('PPG capture error: $e');
    }
  }

  Future<void> _analyzePpg() async {
    final samples = _ppgGreenBuffer;
    if (samples.length < 100) {
      _push('Analyze: need more samples — buffer has ${samples.length}. Tap Capture PPG first.');
      return;
    }

    final endMs = _captureEndMs ?? DateTime.now().millisecondsSinceEpoch;
    final startMs = _captureStartMs ?? endMs;
    final durationS = ((endMs - startMs) / 1000.0).clamp(1.0, 9999.0);
    final fsNative = (samples.length / durationS).round().clamp(5, 200);
    _push('Analyze: ${samples.length} samples over ${durationS.toStringAsFixed(1)}s → fs_native ≈ $fsNative Hz');

    // Diagnostic: raw signal stats (helps see if band actually captured PPG).
    final raw = Float64List.fromList(samples);
    final rawStats = _stats(raw);
    _push('  raw: min=${rawStats.min.toStringAsFixed(0)} max=${rawStats.max.toStringAsFixed(0)} mean=${rawStats.mean.toStringAsFixed(0)} std=${rawStats.std.toStringAsFixed(1)}');

    // Outlier clipping: PPG outliers (motion, band transition, sensor
    // glitches) are 10-100x larger than real cardiac modulation and they
    // dominate the bandpass response. Clip to mean ± 2.5σ — keeps real
    // peaks (~1-2% modulation = well within 2σ) but kills spikes.
    final clipLo = rawStats.mean - 2.5 * rawStats.std;
    final clipHi = rawStats.mean + 2.5 * rawStats.std;
    var clippedCount = 0;
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] < clipLo) {
        raw[i] = clipLo;
        clippedCount++;
      } else if (raw[i] > clipHi) {
        raw[i] = clipHi;
        clippedCount++;
      }
    }
    if (clippedCount > 0) {
      final clippedStats = _stats(raw);
      _push('  clipped $clippedCount outliers → new std=${clippedStats.std.toStringAsFixed(1)}');
    }

    // Try BOTH polarities: inverted (per primer line 53) and as-is. Pick
    // whichever gives more peaks. This way we don't have to guess which
    // direction H59 reports.
    const fsTarget = 75;
    final upsampledPos = _linearResample(raw, fsNative, fsTarget);
    final upsampledNeg = Float64List.fromList(upsampledPos.map((v) => -v).toList());
    _push('  resampled ${samples.length} → ${upsampledPos.length} samples @ ${fsTarget}Hz');

    final sp = SignalProcessor(samplingRate: fsTarget);

    // Run cardiac bandpass on both polarities.
    final cardiacPos = sp.bandpassFilter(upsampledPos, 0.5, 5.0);
    final cardiacNeg = sp.bandpassFilter(upsampledNeg, 0.5, 5.0);
    final cpStats = _stats(cardiacPos);
    _push('  bandpassed (0.5-5Hz): min=${cpStats.min.toStringAsFixed(1)} max=${cpStats.max.toStringAsFixed(1)} std=${cpStats.std.toStringAsFixed(2)}');

    final peaksPos = sp.detectPeaks(cardiacPos);
    final peaksNeg = sp.detectPeaks(cardiacNeg);
    _push('  peaks: as-is=${peaksPos.length}, inverted=${peaksNeg.length}');

    // Pick the polarity with more peaks.
    final useInverted = peaksNeg.length > peaksPos.length;
    final cardiac = useInverted ? cardiacNeg : cardiacPos;
    final peaks = useInverted ? peaksNeg : peaksPos;
    final upsampled = useInverted ? upsampledNeg : upsampledPos;
    _push('  using polarity: ${useInverted ? "inverted" : "as-is"}');

    if (peaks.isEmpty) {
      _push('  ❌ no peaks detected at all — signal may be flat or too noisy');
      return;
    }

    // Cardiac pipeline
    try {
      final rrIntervals = sp.extractRRIntervals(peaks);
      _push('  cardiac: ${peaks.length} peaks, ${rrIntervals.length} valid R-R intervals (300-2000ms)');
      if (rrIntervals.isNotEmpty) {
        final hr = sp.calculateHeartRate(rrIntervals);
        _push('  HR: ${hr ?? "—"} bpm');
        final hrv = HrvCalculator().calculate(rrIntervals);
        if (hrv != null) {
          _push('  HRV: rmssd=${hrv.rmssd.toStringAsFixed(1)}ms sdnn=${hrv.sdnn.toStringAsFixed(1)}ms pnn50=${hrv.pnn50.toStringAsFixed(1)}%');
        } else {
          _push('  HRV: need ≥10 beats (have ${rrIntervals.length})');
        }
      } else {
        _push('  no valid R-R intervals — peaks may be too irregular');
      }
    } catch (e) {
      _push('  cardiac pipeline error: $e');
    }

    // Respiratory pipeline
    try {
      final rr = RespiratoryRateCalculator(samplingRate: fsTarget).calculate(upsampled);
      _push('  respiratory rate: ${rr ?? "—"} breaths/min');
      // HLT-8: persist into today's daily_metrics so the morning aggregator
      // and 14-day baseline pick it up. On H59 the band doesn't stream PPG
      // continuously — the only RR signal we have is what Analyze derives
      // from a user-triggered PPG capture, so this is the canonical write
      // path. daily_aggregator does not touch restingRespRateBpm, so the
      // value survives subsequent Aggregate Day runs.
      if (rr != null && _activeUserId != null) {
        await _persistRespRateForToday(rr);
      }
    } catch (e) {
      _push('  respiratory pipeline error: $e');
    }
  }

  /// HLT-8: upsert today's `restingRespRateBpm` without clobbering other
  /// daily_metrics columns. Mirrors the merge pattern in `_aggregate` and
  /// the step-sync persistence path.
  Future<void> _persistRespRateForToday(double respRateBpm) async {
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    final tzOffsetMin = now.timeZoneOffset.inMinutes;
    final repo = ref.read(dailyMetricsRepositoryProvider);
    final existing = await repo.getForDay(
      userId: _activeUserId!,
      localDate: localDate,
    );
    final nowUtc = DateTime.now().toUtc();
    final merged = (existing ??
            DailyMetrics(
              id: _uuid.v4(),
              userId: _activeUserId!,
              localDate: localDate,
              tzOffsetMin: tzOffsetMin,
              computedAt: nowUtc,
              algorithmVersion: 'analyze-ppg-v1',
              source: DataSource.appRecomputed,
            ))
        .copyWith(
      restingRespRateBpm: respRateBpm,
      computedAt: nowUtc,
    );
    await repo.upsert(merged);
    _push('  persisted resting_resp_rate_bpm=${respRateBpm.toStringAsFixed(1)} for today');
  }

  ({double min, double max, double mean, double std}) _stats(Float64List s) {
    if (s.isEmpty) return (min: 0, max: 0, mean: 0, std: 0);
    double mn = s[0], mx = s[0], sum = 0;
    for (final v in s) {
      if (v < mn) mn = v;
      if (v > mx) mx = v;
      sum += v;
    }
    final mean = sum / s.length;
    double sq = 0;
    for (final v in s) {
      final d = v - mean;
      sq += d * d;
    }
    final variance = sq / s.length;
    return (min: mn, max: mx, mean: mean, std: math.sqrt(variance));
  }

  /// Linear interpolation resampler. Native fs → target fs. Good enough
  /// for cardiac (0.5-5 Hz) and respiratory (0.1-0.5 Hz) bands.
  Float64List _linearResample(Float64List signal, int fsIn, int fsOut) {
    if (fsIn == fsOut) return signal;
    final newLength = (signal.length * fsOut / fsIn).round();
    final out = Float64List(newLength);
    final ratio = (signal.length - 1) / (newLength - 1);
    for (int i = 0; i < newLength; i++) {
      final src = i * ratio;
      final lo = src.floor();
      final hi = (lo + 1).clamp(0, signal.length - 1);
      final frac = src - lo;
      out[i] = signal[lo] * (1 - frac) + signal[hi] * frac;
    }
    return out;
  }

  Future<void> _showDbCounts() async {
    final userId = _activeUserId ?? ActiveSession.defaultUserId;
    // Wide window: last 90 days through end of today.
    final to = DateTime.now().toUtc().add(const Duration(days: 1));
    final from = to.subtract(const Duration(days: 90));
    try {
      final hr =
          await ref.read(hrRepositoryProvider).countInRange(userId: userId, from: from, to: to);
      final spo2 =
          await ref.read(spo2RepositoryProvider).countInRange(userId: userId, from: from, to: to);
      final daily = await ref
          .read(dailyMetricsRepositoryProvider)
          .getInRange(userId: userId, fromDate: from, toDate: to);
      final sleep = await ref
          .read(sleepRepositoryProvider)
          .getInRange(userId: userId, from: from, to: to);
      _push('DB counts (90d, user=$userId):');
      _push('  hr_samples: $hr');
      _push('  spo2_samples: $spo2');
      _push('  daily_metrics: ${daily.length}');
      _push('  sleep_sessions: ${sleep.length}');
    } catch (e) {
      _push('DB count error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Debug'),
        actions: [
          IconButton(
            icon: Icon(_logMaximized ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () =>
                setState(() => _logMaximized = !_logMaximized),
            tooltip: _logMaximized ? 'Show controls' : 'Maximize log',
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            onPressed: _copyLogToClipboard,
            tooltip: 'Copy log',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(_log.clear),
            tooltip: 'Clear log',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_logMaximized) ...[
              _CollapsibleSection(
                title: 'Status',
                expanded: _statusExpanded,
                onToggle: () =>
                    setState(() => _statusExpanded = !_statusExpanded),
                child: _StatusPanel(
                  connected: _connected,
                  nativeBleState: _nativeBleState,
                  battery: _battery,
                  realtimeHr: _lastRealtimeHr,
                  measuredHr: _lastMeasuredHr,
                  spo2: _lastSpo2,
                  ppgPackets: _ppgPacketCount,
                ),
              ),
              const Divider(height: 1),
              _CollapsibleSection(
                title: 'Actions',
                expanded: _actionsExpanded,
                onToggle: () =>
                    setState(() => _actionsExpanded = !_actionsExpanded),
                child: _ActionBar(
                  scanning: _scanning,
                  connected: _connected,
                  hasSelection: _selectedDeviceId != null,
                  onScan: _scan,
                  onConnect: _connect,
                  onDisconnect: _disconnect,
                  onEnableMonitoring: _enableMonitoring,
                  onHr: _getHeartRate,
                  onSpo2: _getSpo2,
                  onSleep: _getSleep,
                  onSteps: _getSteps,
                  onCapturePpg: _capturePpg,
                  onAnalyzePpg: _analyzePpg,
                  onDbCounts: _showDbCounts,
                  onAggregate: _aggregate,
                  onHrv: _getHrv,
                  onBp: _getBp,
                  onStepBuckets: _getStepBuckets,
                  onRunAll: _runAllSyncs,
                ),
              ),
              const Divider(height: 1),
              if (_devices.isNotEmpty) ...[
                SizedBox(
                  height: 96,
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, i) {
                      final d = _devices[i];
                      final selected = d.id == _selectedDeviceId;
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected: selected,
                        leading: Icon(
                          Icons.bluetooth,
                          size: 18,
                          color: selected ? Colors.blue : null,
                        ),
                        title: Text(d.name,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${d.id}  rssi=${d.rssi}',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () =>
                            setState(() => _selectedDeviceId = d.id),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
            Expanded(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: SelectionArea(
                  child: ListView.builder(
                    reverse: false,
                    itemCount: _log.length,
                    itemBuilder: (context, i) {
                      final e = _log[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${e.timestamp.toIso8601String().substring(11, 19)}  ${e.message}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLogToClipboard() async {
    final text = _log
        .map((e) =>
            '${e.timestamp.toIso8601String().substring(11, 19)}  ${e.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${_log.length} log line(s)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Header row with expand/collapse arrow that hides its child. Used to
/// give the log area as much vertical space as the user wants.
class _CollapsibleSection extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded) child,
      ],
    );
  }
}

class _LogEntry {
  final DateTime timestamp;
  final String message;
  _LogEntry(this.timestamp, this.message);
}

class _StatusPanel extends StatelessWidget {
  final bool connected;
  final int? nativeBleState;
  final int? battery;
  final int? realtimeHr;
  final int? measuredHr;
  final double? spo2;
  final int ppgPackets;

  const _StatusPanel({
    required this.connected,
    required this.nativeBleState,
    required this.battery,
    required this.realtimeHr,
    required this.measuredHr,
    required this.spo2,
    required this.ppgPackets,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _chip('Conn',
              connected ? 'CONNECTED' : 'disconnected',
              connected ? Colors.green : Colors.grey),
          _chip('Native', nativeBleState?.toString() ?? '—', Colors.blue),
          _chip('Battery',
              battery != null ? '$battery%' : '—', Colors.orange),
          _chip('RT HR',
              realtimeHr != null ? '$realtimeHr bpm' : '—', Colors.red),
          _chip('Meas HR',
              measuredHr != null ? '$measuredHr bpm' : '—', Colors.redAccent),
          _chip('SpO2',
              spo2 != null ? '${spo2!.toStringAsFixed(1)}%' : '—',
              Colors.lightBlue),
          _chip('PPG pkts', '$ppgPackets', Colors.purple),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool scanning;
  final bool connected;
  final bool hasSelection;
  final VoidCallback onScan;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onEnableMonitoring;
  final VoidCallback onHr;
  final VoidCallback onSpo2;
  final VoidCallback onSleep;
  final VoidCallback onSteps;
  final VoidCallback onCapturePpg;
  final VoidCallback onAnalyzePpg;
  final VoidCallback onDbCounts;
  final VoidCallback onAggregate;
  final VoidCallback onHrv;
  final VoidCallback onBp;
  final VoidCallback onStepBuckets;
  final VoidCallback onRunAll;

  const _ActionBar({
    required this.scanning,
    required this.connected,
    required this.hasSelection,
    required this.onScan,
    required this.onConnect,
    required this.onDisconnect,
    required this.onEnableMonitoring,
    required this.onHr,
    required this.onSpo2,
    required this.onSleep,
    required this.onSteps,
    required this.onCapturePpg,
    required this.onAnalyzePpg,
    required this.onDbCounts,
    required this.onAggregate,
    required this.onHrv,
    required this.onBp,
    required this.onStepBuckets,
    required this.onRunAll,
  });

  @override
  Widget build(BuildContext context) {
    // Compact button style — smaller padding so all 15 actions fit in
    // 2-3 rows instead of 5+ and the log gets more vertical space.
    final compactStyle = ButtonStyle(
      padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      minimumSize: WidgetStateProperty.all(const Size(0, 32)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          FilledButton.icon(
            onPressed: scanning ? null : onScan,
            icon: scanning
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search, size: 14),
            label: Text(scanning ? 'Scanning…' : 'Scan'),
            style: compactStyle,
          ),
          FilledButton.tonal(
            onPressed: !hasSelection || connected ? null : onConnect,
            style: compactStyle,
            child: const Text('Connect'),
          ),
          FilledButton.tonal(
            onPressed: connected ? onDisconnect : null,
            style: compactStyle,
            child: const Text('Disconnect'),
          ),
          FilledButton.icon(
            onPressed: connected ? onEnableMonitoring : null,
            icon: const Icon(Icons.power_settings_new, size: 14),
            label: const Text('Enable Mon'),
            style: compactStyle.copyWith(
              backgroundColor:
                  WidgetStateProperty.all(Colors.deepOrange),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          OutlinedButton(
            onPressed: connected ? onHr : null,
            style: compactStyle,
            child: const Text('Sync HR'),
          ),
          OutlinedButton(
            onPressed: connected ? onSpo2 : null,
            style: compactStyle,
            child: const Text('Sync SpO2'),
          ),
          OutlinedButton(
            onPressed: connected ? onSleep : null,
            style: compactStyle,
            child: const Text('Sync Sleep'),
          ),
          OutlinedButton(
            onPressed: connected ? onSteps : null,
            style: compactStyle,
            child: const Text('Sync Steps'),
          ),
          OutlinedButton(
            onPressed: connected ? onStepBuckets : null,
            style: compactStyle,
            child: const Text('Sync StepBkts'),
          ),
          OutlinedButton(
            onPressed: connected ? onHrv : null,
            style: compactStyle,
            child: const Text('Sync HRV'),
          ),
          OutlinedButton(
            onPressed: connected ? onBp : null,
            style: compactStyle,
            child: const Text('Sync BP'),
          ),
          FilledButton.icon(
            onPressed: connected ? onCapturePpg : null,
            icon: const Icon(Icons.show_chart, size: 14),
            label: const Text('Capture PPG'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.purple),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAnalyzePpg,
            icon: const Icon(Icons.analytics, size: 14),
            label: const Text('Analyze'),
            style: compactStyle,
          ),
          OutlinedButton.icon(
            onPressed: onDbCounts,
            icon: const Icon(Icons.storage, size: 14),
            label: const Text('DB'),
            style: compactStyle,
          ),
          FilledButton.icon(
            onPressed: onAggregate,
            icon: const Icon(Icons.calculate, size: 14),
            label: const Text('Aggregate'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.teal),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          FilledButton.icon(
            onPressed: connected ? onRunAll : null,
            icon: const Icon(Icons.sync, size: 14),
            label: const Text('Run All'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.indigo),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
