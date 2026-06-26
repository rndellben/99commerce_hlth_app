import 'dart:async';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/processing/fall_detector.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_evaluator.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/ppg_analysis_service.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/activity_classifier.dart';
import 'package:hlth_app/core/repositories/baseline_repository.dart';
import 'package:hlth_app/core/repositories/battery_telemetry_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/services/baseline_service.dart';
import 'package:hlth_app/core/services/cloud_sync_service.dart';
import 'package:hlth_app/core/services/daily_aggregator.dart';
import 'package:hlth_app/core/services/nightly_bp_capture_service.dart';
import 'package:hlth_app/core/services/recovery_score_service.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/core/services/sync_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  /// MAC address → friendly displayName for previously-paired devices.
  /// Populated from the `devices` table so the scan list can show
  /// "My Ring" instead of "H59_6C00".
  Map<String, String> _deviceAliases = {};
  /// MAC of the user's currently bound (active) device, if any. Used to
  /// show a "★ Paired" badge in the scan list and to hard-reject Connect
  /// attempts against any other band.
  String? _boundMac;
  bool _scanning = false;
  bool _connected = false;

  int? _lastRealtimeHr;
  int? _lastMeasuredHr;
  double? _lastSpo2;
  int? _battery;
  int? _nativeBleState;
  int _ppgPacketCount = 0;
  // Live stream state for the new manualMode* realtime buttons. Live
  // values are pushed to the log feed via the spo2Stream/hrvStream
  // listeners in [_attachListeners] — no separate chip; the log
  // line-per-tick is the visible "value updating in-app" output.
  bool _spo2Streaming = false;
  bool _hrvStreaming = false;

  // Bootstrapped on successful connect — required for every health-row insert
  // because (user_id, device_id) are FK provenance columns per hlth-db-schema §3.0.
  String? _activeUserId;
  String? _activeDeviceId;

  // Buffer of green-channel PPG samples accumulated during a capture
  // session. Cleared on each Capture PPG tap. The Analyze button reads
  // this buffer and runs the signal-processing pipeline.
  final List<double> _ppgGreenBuffer = [];
  // Step 1 capture-quality diagnostics. The band stamps every raw sample
  // with a monotonic 0-255 `ppg_count`. Recording every received count
  // (before the green>0 filter) lets Analyze separate two failure modes:
  //   * gaps in the count   → samples lost in transit (BLE packet loss)
  //   * green=0 received     → sensor blanked (poor fit / not seeing blood)
  // Both collapse the effective sample rate; the fix differs per cause.
  final List<int> _ppgCountSeq = [];
  // Green value for every counted sample, aligned 1:1 with _ppgCountSeq
  // (green=0 stored as 0.0 so it reads as a gap). Step 2 feeds this pair
  // into counter-based timing reconstruction.
  final List<double> _ppgGreenAll = [];
  int _greenZeroCount = 0;
  // Raw multi-channel buffers, each aligned 1:1 with [_ppgCountSeq], for the
  // morphology / cardio-load export Ryan asked for. The band emits all of
  // these on every packet (green/red/IR + accel XYZ); we keep them only while
  // a capture is running. [_ppgEpochMsAll] is the wall-clock arrival time of
  // the packet each sample came in on — ppg_count is the precise relative
  // timing signal, this just anchors the series to real time.
  final List<double> _ppgRedAll = [];
  final List<double> _ppgIrAll = [];
  final List<int> _ppgAccelXAll = [];
  final List<int> _ppgAccelYAll = [];
  final List<int> _ppgAccelZAll = [];
  final List<int> _ppgEpochMsAll = [];
  // The complete per-packet sample maps, exactly as received from the band
  // (every field: green/red/IR + heart/rri/hrv + accel). Kept so the export
  // can reproduce the per-packet log lines verbatim.
  final List<Map<String, dynamic>> _ppgRawSamples = [];
  int? _captureStartMs;
  int? _captureEndMs; // frozen when capture stops — used to compute true fs
  bool _capturing = false;
  // The pending auto-stop timer for the active capture. Held so a new capture
  // (or a manual stop) can cancel it — otherwise a stale timer from a previous
  // capture fires later and stops the wrong measurement.
  Timer? _captureStopTimer;
  // Raw-capture window. The same value is passed to the band AND used for the
  // Dart auto-stop timer, so the capture stops itself when the window is up.
  static const int _rawCaptureSeconds = 90;
  // Last Analyze result — kept so we can export its derived R-R series for
  // off-device cleaner tuning (Ryan's request).
  PpgAnalysisResult? _lastPpgResult;

  // HLT-5 Fall Watch state. Toggled by the Fall Watch debug button.
  // While active, we hold `startMeasureHrRaw` open (the H59 only emits
  // accel during PPG capture) and feed every incoming accel sample into
  // a rolling 20 s window. A 1 Hz timer runs FallDetector across the
  // window and logs any detected events. The native PPG capture has a
  // hard timeout per call (~10 min); we restart it on a timer so the
  // stream stays continuous until the user toggles it off.
  bool _fallWatchActive = false;
  static const int _fallWindowSeconds = 20;
  static const double _fallWatchFsHz = 24; // H59 native accel rate
  final List<int> _fallAccelX = [];
  final List<int> _fallAccelY = [];
  final List<int> _fallAccelZ = [];
  Timer? _fallEvalTimer;
  Timer? _fallRestartTimer;
  int _fallEventCount = 0;
  double? _fallLastMagG;
  // Latest per-axis accel readings, raw sensor units (signed int16 from
  // the SDK's `StopHeartRateRsp` — match the values shown in the
  // per-packet log). The button label shows these alongside the
  // calibrated magnitude so the user can cross-check against the
  // packet stream.
  int? _fallLastXRaw;
  int? _fallLastYRaw;
  int? _fallLastZRaw;
  // Runtime calibration: the H59's raw accel units don't match standard
  // milli-g (resting magnitude observed at ~235 raw vs 1000 mg expected).
  // We sample the first few seconds of resting magnitude and treat that
  // as the local "1 g" so the freefall/impact thresholds are physically
  // meaningful regardless of sensor scale.
  double? _fallOneGRaw;
  int _fallCalibSampleCount = 0;
  double _fallCalibSumRawMag = 0;
  static const int _fallCalibTargetSamples = 24 * 5; // ~5 s
  final FallDetector _fallDetector = const FallDetector();

  final List<StreamSubscription<dynamic>> _subs = [];

  // Debug-screen UI state — collapse controls when you want the log to
  // breathe, or maximize the log to read long raw dumps.
  bool _logMaximized = false;
  bool _statusExpanded = true;
  bool _actionsExpanded = true;
  bool _batteryTestExpanded = true;

  // Battery drain test — the panel maintains a "test started at" marker
  // (persisted to SharedPreferences) so closing/reopening the app keeps
  // the same 24h window. Reset via "Start new test".
  static const _kBatteryTestStartKey = 'battery_test_started_at_utc_sec';
  static const _kBatteryTestIntervalKey = 'battery_test_interval_min';
  DateTime? _batteryTestStartedAt;
  int _selectedSyncIntervalMin = 30;

  @override
  void initState() {
    super.initState();
    // Subscribe in the next frame so we have access to the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachListeners();
      _refreshAliases();
      _refreshBound();
      _loadBatteryTestState();
    });
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
        setState(() {
          _connected = state == BleConnectionState.connected;
          // Disconnect kills any in-flight manualMode stream on the
          // native side, so clear the UI flags to match.
          if (state == BleConnectionState.disconnected) {
            _spo2Streaming = false;
            _hrvStreaming = false;
          }
        });
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
      ble.spo2Stream.listen((t) {
        _push('  spo2 stream: ${t.spo2}%  hr=${t.hr}');
      }),
      ble.hrvStream.listen((t) {
        _push('  hrv stream: ${t.hrv} ms  hr=${t.hr}  stress=${t.stress}');
      }),
      ble.rawPpgEvent.listen((samples) {
        setState(() => _ppgPacketCount += samples.length);
        // Only buffer while a capture is actively running. Filter out
        // green=0 packets — these are SDK status/empty packets that
        // contaminate the buffer and cause huge spikes in the bandpass.
        if (_capturing) {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          for (final s in samples) {
            // Record the band's sample counter for every received sample,
            // regardless of green value — gaps here are BLE loss. Keep a
            // green value aligned 1:1 with the counter (0 = blank/gap).
            final c = s['ppg_count'];
            final g = s['green'];
            final gv = (g is num) ? g.toDouble() : 0.0;
            if (c is num) {
              _ppgCountSeq.add(c.toInt());
              _ppgGreenAll.add(gv);
              // Keep the remaining channels aligned 1:1 with the counter for
              // the raw multi-channel export (morphology / cardio-load).
              final r = s['red'];
              final ir = s['infrared'];
              final ax = s['accel_x'];
              final ay = s['accel_y'];
              final az = s['accel_z'];
              _ppgRedAll.add(r is num ? r.toDouble() : 0.0);
              _ppgIrAll.add(ir is num ? ir.toDouble() : 0.0);
              _ppgAccelXAll.add(ax is num ? ax.toInt() : 0);
              _ppgAccelYAll.add(ay is num ? ay.toInt() : 0);
              _ppgAccelZAll.add(az is num ? az.toInt() : 0);
              _ppgEpochMsAll.add(nowMs);
              // Full packet map, verbatim, for the per-packet export lines.
              _ppgRawSamples.add(Map<String, dynamic>.from(s));
            }
            if (gv > 0) {
              _ppgGreenBuffer.add(gv);
            } else {
              _greenZeroCount++;
            }
          }
        }
        // HLT-5: feed every accel triple into the Fall Watch buffer.
        // Independent of `_capturing` because Fall Watch runs its own
        // `startMeasureHrRaw` session.
        if (_fallWatchActive) {
          for (final s in samples) {
            final ax = s['accel_x'];
            final ay = s['accel_y'];
            final az = s['accel_z'];
            if (ax is num && ay is num && az is num) {
              _onFallAccelSample(ax.toInt(), ay.toInt(), az.toInt());
            }
          }
        }
        // Suppress the per-packet log dump while Fall Watch is on — the
        // button label already shows live (x, y, z, mag) so the log
        // would just bury any FALL DETECTED line in noise.
        if (samples.isNotEmpty && !_fallWatchActive) {
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
        // HLT-12: retention sweep — runs only when 24h gate has elapsed.
        final retention = result.retention;
        if (retention != null) {
          _push('★ retention sweep: ${retention.totalSoftDeleted} '
              'soft-deleted across ${retention.steps.length} tables');
          for (final s in retention.steps) {
            if (s.ok) {
              if (s.softDeletedCount > 0) {
                _push('  ↳ ${s.table}: ${s.softDeletedCount}');
              }
            } else {
              _push('  ↳ ${s.table}: ERROR — ${s.error}');
            }
          }
        } else if (result.retentionSkipReason != null) {
          _push('  (retention sweep skipped — ${result.retentionSkipReason})');
        }
      }),
      // HLT-5: background fall sweep emits one event per periodic tick.
      ref.read(periodicSyncCoordinatorProvider).fallSweeps.listen((sweep) {
        if (!sweep.ok) {
          _push('★ fall sweep skipped — ${sweep.skipReason} '
              '(samples=${sweep.sampleCount})');
          return;
        }
        final calib = sweep.calibratedOneGRaw?.toStringAsFixed(0) ?? '—';
        _push('★ fall sweep: ${sweep.captureDurationS}s capture, '
            '${sweep.sampleCount} accel samples, 1g=$calib raw, '
            '${sweep.events.length} event(s)');
        for (final e in sweep.events) {
          _push('────────────────────────────────────');
          _push('★★ FALL DETECTED (background) — severity=${e.severity.name} '
              'peak=${e.peakImpactG.toStringAsFixed(2)}g '
              'postImpactStd=${e.postImpactVariabilityG.toStringAsFixed(3)}g');
          _push('   ↳ Are you okay?  (tap Fall Watch to dismiss / log next event)');
          _push('────────────────────────────────────');
        }
      }),
    ]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    // If a raw capture is still running, stop it so the band's LEDs don't stay
    // lit (and keep draining battery) after we leave the screen. Fire the stop
    // commands directly — `_stopActiveCapture` touches state/UI we can't use
    // post-dispose.
    _captureStopTimer?.cancel();
    if (_capturing) {
      final ble = ref.read(bleServiceProvider);
      ble.stopMeasure().catchError((_) {});
      ble.stopMeasureSpo2Raw().catchError((_) {});
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
      await _refreshAliases();
      await _refreshBound();
      if (mounted) setState(() => _devices = devices);
      _push('scan complete: ${devices.length} device(s)');
      for (final d in devices) {
        final alias = _deviceAliases[d.id];
        final label = alias != null ? '$alias [${d.name}]' : d.name;
        _push('  → $label (${d.id}) rssi=${d.rssi}');
      }
    } catch (e) {
      _push('scan error: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Reload the current user's bound device MAC. Drives the "★ Paired"
  /// badge in the scan list and the MAC-mismatch reject in `_connect`.
  Future<void> _refreshBound() async {
    try {
      final bound = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (!mounted) return;
      setState(() => _boundMac = bound?.macAddress);
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Reload the (mac → displayName) alias map from the devices table so the
  /// scan list shows the user-chosen nickname instead of the raw BLE name.
  Future<void> _refreshAliases() async {
    final userId = _activeUserId ?? ActiveSession.defaultUserId;
    try {
      final all = await ref
          .read(deviceRepositoryProvider)
          .getAllForUser(userId, includeInactive: true);
      if (!mounted) return;
      setState(() {
        _deviceAliases = {
          for (final d in all)
            if (d.macAddress != null) d.macAddress!: d.displayName,
        };
      });
    } catch (_) {
      // Non-fatal — scan list will just show raw BLE names.
    }
  }

  /// Rename a previously-paired device. Updates the `devices.displayName`
  /// column in Drift; the BLE advertised name on the band itself is
  /// firmware-baked and cannot be changed (verified — no SDK API exists).
  Future<void> _renameDevice(BleDevice d) async {
    final alias = _deviceAliases[d.id];
    if (alias == null && _activeUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Connect to this device first to give it a nickname.'),
        ),
      );
      return;
    }
    final controller = TextEditingController(text: alias ?? d.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BLE name: ${d.name}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Friendly name',
                hintText: 'My Ring',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;

    final repo = ref.read(deviceRepositoryProvider);
    final existing = await repo.getByMacAddress(d.id);
    if (existing == null) {
      // Device hasn't been connected yet — create the row now so the
      // alias persists even if the user never taps Connect.
      await ref.read(activeSessionProvider).ensureDevice(
            bandId: d.id,
            displayName: newName,
            model: 'H59',
          );
    } else {
      await repo.rename(deviceId: existing.id, displayName: newName);
    }
    await _refreshAliases();
    _push('renamed ${d.id} → "$newName"');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed to "$newName"')),
      );
    }
  }

  Future<void> _connect() async {
    final id = _selectedDeviceId;
    if (id == null) {
      _push('connect: no device selected');
      return;
    }
    // HLTH device-binding spec: each band is bound to a user_id at first
    // pair. On subsequent connects we hard-reject any MAC that doesn't
    // match the currently bound device — prevents the "two H59s in the
    // same room, app connects to the wrong one and corrupts the DB" bug.
    // Use the Forget flow in /settings/device to break the binding.
    final repo = ref.read(deviceRepositoryProvider);
    final bound =
        await repo.getActiveForUser(ActiveSession.defaultUserId);
    final selected = _devices.firstWhere(
      (d) => d.id == id,
      orElse: () => BleDevice(id: id, name: id, rssi: -100),
    );

    if (bound != null && bound.macAddress != id) {
      _push('connect rejected: $id is not the paired band '
          '(${bound.macAddress}). Use Settings → My Device → Forget '
          'to re-pair.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Not your paired band. Bound to ${bound.macAddress}. '
                'Forget the current device first.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // First-pair flow: confirm with the user before binding a new band.
    if (bound == null) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pair with this band?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(selected.name,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('MAC: $id',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text(
                'The band will be bound to this user account. To pair '
                'a different band later, use Settings → My Device → '
                'Forget device.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pair'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        _push('connect: user cancelled first-pair confirmation');
        return;
      }
    }

    _push('connect: $id');
    try {
      await ref.read(bleServiceProvider).connect(id);
      setState(() => _connected = true);
      _push('connect: OK');

      // Bootstrap active user/device so every persisted health row has
      // valid FK targets.
      final session = ref.read(activeSessionProvider);
      final deviceRowId = await session.ensureDevice(
        bandId: id,
        displayName: selected.name,
        model: 'H59',
      );
      _activeUserId = ActiveSession.defaultUserId;
      _activeDeviceId = deviceRowId;
      _push('session: user=$_activeUserId device=$deviceRowId');
      await _refreshAliases();
      await _refreshBound();
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

  Future<void> _getHeartRate({int dayOffset = 0}) async {
    if (!_requireSession()) return;
    final label = dayOffset == 0 ? 'today' : 'day-$dayOffset';
    _push('getHrHistory ($label): requesting...');
    final res = await ref.read(syncServiceProvider).syncHr(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          dayOffset: dayOffset,
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

  Future<void> _getHeartRateSpecificDay() async {
    if (!_requireSession()) return;
    final dayOffset = await _promptDayIndex(title: 'HR Specific Day');
    if (dayOffset == null) return;
    await _getHeartRate(dayOffset: dayOffset);
  }

  Future<void> _getSpo2SpecificDay() async {
    if (!_requireSession()) return;
    final dayOffset = await _promptDayIndex(title: 'SpO2 Specific Day');
    if (dayOffset == null) return;
    final label = dayOffset == 0 ? 'today' : 'day-$dayOffset';
    _push('getSpO2Day ($label): requesting...');
    final res = await ref.read(syncServiceProvider).syncSpo2Day(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          dayOffset: dayOffset,
        );
    if (!res.ok) {
      _push('getSpO2Day error: ${res.error}');
      return;
    }
    final entries = res.rawList ?? const [];
    if (entries.isEmpty) {
      _push('  no SpO2 data for $label');
      return;
    }
    for (final entry in entries) {
      _push('  dateStr=${entry['dateStr']} unixTime=${entry['unixTime']}');
      _push('    maxArray[24]=${entry['maxArray']}');
      _push('    minArray[24]=${entry['minArray']}');
    }
    _push('  persisted ${res.count} SpO2 hourly sample(s)');
  }

  /// Shared dialog matching the QRing demo's "Specific Day Data" prompt:
  /// integer day index, 0 = today, 1..29 = N days ago.
  Future<int?> _promptDayIndex({required String title}) async {
    final controller = TextEditingController(text: '1');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'dayIndex (0=today, 1..29=N days ago)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n < 0 || n > 29) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('dayIndex must be 0..29')),
                );
                return;
              }
              Navigator.of(ctx).pop(n);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
    _push('getSleepHistory: requesting latest sleep session...');
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
    _push('  stages (${stages.length}):');
    for (var i = 0; i < stages.length && i < 12; i++) {
      _push('    [$i] ${stages[i]}');
    }
    if (stages.length > 12) _push('    ... +${stages.length - 12} more');
    final startedAt = (res.extra?['startedAt'] as String?) ?? '';
    final shortStarted = startedAt.length >= 16
        ? startedAt.substring(0, 16).replaceFirst('T', ' ')
        : startedAt;
    if (shortStarted.isNotEmpty) {
      _push('  persisted: $shortStarted, '
          '${res.extra?['totalMin']}min, ${res.extra?['epochCount']} epochs');
    } else {
      _push('  ${res.note ?? 'nothing persisted'}');
    }

    // Update today's daily_metrics so the Home screen Sleep card picks up
    // the newly-synced session. `syncAll` does this at the end of its run,
    // but standalone Sync Sleep never touched the aggregator before — so
    // tapping back to Home showed "--" until the user remembered to run
    // Aggregate Day manually.
    try {
      await ref.read(dailyAggregatorProvider).aggregateRecent(
            userId: _activeUserId!,
            days: 2,
          );
      _push('  aggregated today + yesterday');
    } catch (e) {
      _push('  aggregate failed: $e');
    }
  }

  /// Re-aggregate the recent window then compute the daily scores on demand,
  /// so the Recovery card can be verified without waiting for a sync tick.
  /// Tries today first, falls back to yesterday, and logs the result/reason.
  Future<void> _computeScores() async {
    if (!_requireSession()) return;
    _push('Compute Scores: aggregating last 20 days...');
    try {
      await ref
          .read(dailyAggregatorProvider)
          .aggregateRecent(userId: _activeUserId!, days: 20);
    } catch (e) {
      _push('  aggregate failed: $e');
    }
    // Annotated re-aggregation of today so the HRV sleep-window gating is
    // visible: window bounds, in-window sample count, sleep vs morning HRV.
    try {
      final now = DateTime.now();
      await ref.read(dailyAggregatorProvider).aggregateDay(
            userId: _activeUserId!,
            localDate: DateTime(now.year, now.month, now.day),
            tzOffsetMin: now.timeZoneOffset.inMinutes,
            log: _push,
          );
    } catch (e) {
      _push('  HRV window check failed: $e');
    }
    final svc = ref.read(recoveryScoreServiceProvider);
    final today = DateTime.now();
    for (final d in [today, today.subtract(const Duration(days: 1))]) {
      final dk = d.toIso8601String().substring(0, 10);
      final score = await svc.computeForDay(userId: _activeUserId!, localDate: d);
      if (score != null) {
        _push('Recovery ($dk): ${score.score.toStringAsFixed(1)}/100 — '
            '${score.label ?? "?"}'
            '${score.provisional ? " (provisional)" : ""} '
            'conf=${score.confidence?.toStringAsFixed(2) ?? "?"}');
        _push('  → open Home; the Recovery card now shows this.');
        return;
      }
      _push('Recovery ($dk): no score — no valid sleep night / not enough data');
    }
    _push('  → run Sync All Sleep first, then Compute Scores again.');
  }

  /// Pull every sleep session the band still has buffered (it retains ~7
  /// days) in one go, persist them all, then re-aggregate the window so
  /// daily_metrics + the Home/Sleep screens reflect the full history.
  Future<void> _syncAllSleep() async {
    if (!_requireSession()) return;
    const maxDayOffset = 7; // H59 retains ~7 days of sleep history
    final offsets = [for (var d = 0; d <= maxDayOffset; d++) d];
    _push('Sync All Sleep: pulling day offsets 0–$maxDayOffset '
        '(${offsets.length} BLE round-trips)...');
    final results = await ref.read(syncServiceProvider).syncSleepRange(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          offsets: offsets,
        );
    var sessions = 0;
    var epochs = 0;
    for (var i = 0; i < results.length; i++) {
      final res = results[i];
      final label = i == 0 ? 'today' : '$i d ago';
      if (!res.ok) {
        _push('  offset $i ($label): error ${res.error}');
        continue;
      }
      if (res.count == 0) {
        _push('  offset $i ($label): ${res.note ?? "no sleep"}');
        continue;
      }
      sessions++;
      epochs += res.count;
      final startedAt = (res.extra?['startedAt'] as String?) ?? '';
      final shortStarted = startedAt.length >= 16
          ? startedAt.substring(0, 16).replaceFirst('T', ' ')
          : startedAt;
      _push('  offset $i ($label): $shortStarted, '
          '${res.extra?['totalMin']}min, ${res.count} epochs');
    }
    _push('Sync All Sleep: $sessions session(s), $epochs epoch(s) persisted');
    try {
      await ref.read(dailyAggregatorProvider).aggregateRecent(
            userId: _activeUserId!,
            days: maxDayOffset + 1,
          );
      _push('  aggregated last ${maxDayOffset + 1} days');
    } catch (e) {
      _push('  aggregate failed: $e');
    }
    // Build a clean, paste-ready export of everything now stored and put it on
    // the clipboard so it can be sent straight to Ryan.
    await _exportAllSleepToClipboard();
  }

  /// Read every stored sleep session (trailing 30 days) + its epochs and copy
  /// a clean JSON blob to the clipboard. This is the canonical model shape
  /// (parsed, not raw band payload): `DateTime`s as ISO-8601, stages as enum
  /// names — exactly what drop-in Dart would consume.
  Future<void> _exportAllSleepToClipboard() async {
    if (!_requireSession()) return;
    final repo = ref.read(sleepRepositoryProvider);
    final now = DateTime.now().toUtc();
    final sessions = await repo.getInRange(
      userId: _activeUserId!,
      from: now.subtract(const Duration(days: 30)),
      to: now.add(const Duration(days: 1)),
      type: SleepSessionType.night,
    );
    final out = <String, dynamic>{
      'exported_at': now.toIso8601String(),
      'user_id': _activeUserId,
      'session_count': sessions.length,
      'stage_enum': 'awake, light, deep, rem, noSleep, unweared',
      'sessions': <dynamic>[],
    };
    for (final s in sessions) {
      final eps = await repo.getEpochsForSession(s.id);
      (out['sessions'] as List).add({
        'id': s.id,
        'started_at': s.startedAt.toIso8601String(),
        'ended_at': s.endedAt.toIso8601String(),
        'tz_offset_min': s.tzOffsetMin,
        'protocol_version': s.protocolVersion, // 2 = REM-capable
        'total_min': s.totalMin,
        'deep_min': s.deepMin,
        'light_min': s.lightMin,
        'rem_min': s.remMin,
        'awake_min': s.awakeMin,
        'coverage_gap_min': s.coverageGapMin,
        'efficiency_pct': s.efficiencyPct,
        'has_unweared': s.hasUnweared,
        'epochs': [
          for (final e in eps)
            {
              'started_at': e.startedAt.toIso8601String(),
              'duration_min': e.durationMin,
              'stage': e.stage.name,
            }
        ],
      });
    }
    final json = const JsonEncoder.withIndent('  ').convert(out);
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:
          Text('Sleep export copied (${sessions.length} sessions)')),
    );
    _push('📋 Sleep export copied to clipboard — ${sessions.length} '
        'session(s) as JSON (paste & send to Ryan)');
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

  /// Demo-parity: specific-day step buckets via BleOperateManager.getStepDetail.
  /// Matches the QRing demo's "Specific Day Data" button on the Activity Step tab.
  Future<void> _getStepSpecificDay() async {
    if (!_requireSession()) return;
    final dayOffset = await _promptDayIndex(title: 'Step Specific Day');
    if (dayOffset == null) return;
    final label = dayOffset == 0 ? 'today' : 'day-$dayOffset';
    _push('getStepDay ($label): requesting...');
    try {
      final bins =
          await ref.read(bleServiceProvider).getStepDay(dayOffset: dayOffset);
      _push('  ${bins.length} bucket(s) returned');
      var shown = 0;
      for (final raw in bins) {
        final walk = (raw['walkSteps'] as num?)?.toInt() ?? 0;
        final run = (raw['runSteps'] as num?)?.toInt() ?? 0;
        if (walk + run == 0) continue;
        if (shown < 12) {
          _push('    $raw');
          shown++;
        }
      }
      if (shown == 0) {
        _push('  (no non-empty buckets for $label)');
      } else if (bins.length > 12) {
        _push('    ... showed first 12 non-empty');
      }
    } catch (e) {
      _push('getStepDay error: $e');
    }
  }

  Future<void> _getHrv() async {
    if (!_requireSession()) return;
    // SDK supports dayOffset 0..29 via BleOperateManager.getHrv. HRV has a
    // wear-day storage quirk on H59: samples often appear under
    // yesterday's date after overnight wear, so the prompt helps chase
    // them down. The periodic sync calls syncHrv(0) AND syncHrv(1)
    // automatically to cover this.
    final dayOffset = await _promptDayIndex(title: 'HRV Specific Day');
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

  Future<void> _getStress() async {
    if (!_requireSession()) return;
    // SDK supports dayOffset 0..29 via BleOperateManager.getPressure.
    // Mirror of HRV: same wear-day quirk likely applies, so the prompt
    // lets us walk through offsets to find where the band actually
    // filed today's slots.
    final dayOffset = await _promptDayIndex(title: 'Stress Specific Day');
    if (dayOffset == null) return;
    _push('getStressDay: requesting (dayOffset=$dayOffset)...');
    final res = await ref.read(syncServiceProvider).syncStress(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          dayOffset: dayOffset,
        );
    if (!res.ok) {
      _push('getStressDay error: ${res.error}');
      return;
    }
    final r = res.rawMap ?? const {};
    final values = (r['values'] as List?) ?? const [];
    final intervalMin = r['intervalMinutes'];
    final offset = r['offset'];
    final rawArr = (r['rawArray'] as List?) ?? const [];
    _push(
        'getStressDay: ${values.length} value(s), intervalMinutes=$intervalMin offset=$offset');
    _push('  rawArray[${rawArr.length}]: ${_preview(rawArr, 24)}');
    _push('  values: ${_preview(values, 16)}');
    _push('  persisted ${res.count} stress sample(s)');
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

  Future<void> _getBpSpecificDay() async {
    if (!_requireSession()) return;
    final dayOffset = await _promptDayIndex(title: 'BP Specific Day');
    if (dayOffset == null) return;
    final label = dayOffset == 0 ? 'today' : 'day-$dayOffset';
    _push('syncBp ($label): requesting + persisting...');
    final res = await ref.read(syncServiceProvider).syncBp(
          userId: _activeUserId!,
          deviceId: _activeDeviceId!,
          dayOffset: dayOffset,
        );
    if (!res.ok) {
      _push('syncBp error: ${res.error}');
      return;
    }
    final readings = (res.rawMap?['readings'] as List?) ?? const [];
    if (readings.isEmpty) {
      _push('  no BP readings for $label');
      return;
    }
    _push('  ${readings.length} BP reading(s) (sbp/dbp pairs):');
    for (var i = 0; i < readings.length && i < 12; i++) {
      final m = readings[i] as Map;
      _push('    [$i] time=${m['time']} sbp=${m['sbp']} dbp=${m['dbp']}');
    }
    if (readings.length > 12) _push('    ... +${readings.length - 12} more');
    _push('  persisted ${res.count} BP reading(s) as bp_readings');
  }

  Future<void> _startBpMeasurement() async {
    if (!_requireSession()) return;
    _push('nightly BP: firing active measurement (~30s) + persisting...');
    try {
      final res = await ref
          .read(nightlyBpCaptureServiceProvider)
          .captureAndPersist(userId: _activeUserId!);
      if (res == null) {
        _push('  no reading — band did not converge (ring snug?) '
            'or not connected');
        return;
      }
      _push('  persisted ${res.sbp}/${res.dbp} mmHg as bp_reading');
      _push('  (run Scores / next sync to roll it into daily_metrics)');
    } catch (e) {
      _push('nightly BP error: $e');
    }
  }

  Future<void> _stopBpMeasurement() async {
    if (!_requireSession()) return;
    _push('stopBpMeasurement: aborting...');
    try {
      final r = await ref.read(bleServiceProvider).stopBpMeasurement();
      _push('  stopped=${r['stopped']}');
    } catch (e) {
      _push('stopBpMeasurement error: $e');
    }
  }

  // ── Realtime measurement streams (manualMode*) ──────────────────────────
  // Each Start opens a band-side ~30s active measurement. Intermediate
  // values stream into the log and the live chips up top via
  // bleService.spo2Stream / hrvStream. Stop sends `manualMode*(..., true)`
  // which terminates the band-side measurement.

  Future<void> _startSpo2Stream() async {
    if (!_requireSession()) return;
    setState(() => _spo2Streaming = true);
    _push('startSpo2Stream: subscribing...');
    try {
      final r = await ref.read(bleServiceProvider).startSpo2Stream();
      _push('  started=${r['started']}');
    } catch (e) {
      setState(() => _spo2Streaming = false);
      _push('startSpo2Stream error: $e');
    }
  }

  Future<void> _stopSpo2Stream() async {
    _push('stopSpo2Stream: stopping...');
    try {
      final r = await ref.read(bleServiceProvider).stopSpo2Stream();
      _push('  stopped=${r['stopped']}');
    } catch (e) {
      _push('stopSpo2Stream error: $e');
    } finally {
      setState(() => _spo2Streaming = false);
    }
  }

  Future<void> _startHrvStream() async {
    if (!_requireSession()) return;
    setState(() => _hrvStreaming = true);
    _push('startHrvStream: subscribing...');
    try {
      final r = await ref.read(bleServiceProvider).startHrvStream();
      _push('  started=${r['started']}');
    } catch (e) {
      setState(() => _hrvStreaming = false);
      _push('startHrvStream error: $e');
    }
  }

  Future<void> _stopHrvStream() async {
    _push('stopHrvStream: stopping...');
    try {
      final r = await ref.read(bleServiceProvider).stopHrvStream();
      _push('  stopped=${r['stopped']}');
    } catch (e) {
      _push('stopHrvStream error: $e');
    } finally {
      setState(() => _hrvStreaming = false);
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

  /// Manual cloud sync: enqueue recent local rows + drain the outbox to
  /// Supabase. Used to smoke-test the cloud path without waiting for the
  /// 30-min periodic tick.
  Future<void> _pushToCloud() async {
    final authUid = ref.read(currentUserIdProvider);
    if (authUid == null) {
      _push('cloud push: no auth UID — sign in via Settings → Account first');
      return;
    }
    final localUserId = _activeUserId ?? ActiveSession.defaultUserId;
    final cloudSync = ref.read(cloudSyncServiceProvider);
    _push('cloud push: enqueueing recent metrics + identity for $localUserId...');
    try {
      await cloudSync.enqueueRecentMetrics(userId: localUserId);
      await cloudSync.enqueueIdentity(userId: localUserId);
    } catch (e) {
      _push('  enqueue error: $e');
      return;
    }
    _push('cloud push: draining outbox to Supabase (auth=$authUid)...');
    try {
      final result = await cloudSync.processOutbox(authUserId: authUid);
      _push('  pushed=${result.pushed} failed=${result.failed}');
      for (final err in result.errors) {
        _push('  ✗ $err');
      }
    } catch (e) {
      _push('  processOutbox error: $e');
    }
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

  /// Toggle the HLT-5 Fall Watch mode. Each tap flips between live
  /// streaming + sliding-window fall detection and idle.
  Future<void> _toggleFallWatch() async {
    if (_fallWatchActive) {
      await _stopFallWatch();
    } else {
      await _startFallWatch();
    }
  }

  Future<void> _startFallWatch() async {
    if (!_connected) {
      _push('Fall Watch: not connected');
      return;
    }
    setState(() {
      _fallWatchActive = true;
      _fallAccelX.clear();
      _fallAccelY.clear();
      _fallAccelZ.clear();
      _fallEventCount = 0;
      _fallLastMagG = null;
      _fallLastXRaw = null;
      _fallLastYRaw = null;
      _fallLastZRaw = null;
      _fallOneGRaw = null;
      _fallCalibSampleCount = 0;
      _fallCalibSumRawMag = 0;
    });
    _push('★ Fall Watch: starting — calibrating 1g reference (5 s)…');
    await _startFallWatchCapture();
    // The native PPG capture stops on its own after `durationSec`. We
    // restart it on a timer so the accel stream stays continuous until
    // the user toggles Fall Watch off.
    _fallRestartTimer?.cancel();
    _fallRestartTimer =
        Timer.periodic(const Duration(seconds: 540), (_) async {
      if (!_fallWatchActive) return;
      _push('  Fall Watch: restarting capture window');
      await _startFallWatchCapture();
    });
    // Evaluate the sliding window once per second.
    _fallEvalTimer?.cancel();
    _fallEvalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_fallWatchActive) return;
      _evalFallWindow();
    });
  }

  Future<void> _startFallWatchCapture() async {
    try {
      await ref
          .read(bleServiceProvider)
          .startMeasureHrRaw(durationSec: 600);
    } catch (e) {
      _push('Fall Watch capture error: $e');
    }
  }

  Future<void> _stopFallWatch() async {
    setState(() => _fallWatchActive = false);
    _fallRestartTimer?.cancel();
    _fallRestartTimer = null;
    _fallEvalTimer?.cancel();
    _fallEvalTimer = null;
    try {
      await ref.read(bleServiceProvider).stopMeasure();
    } catch (e) {
      _push('Fall Watch stop error: $e');
    }
    _push('★ Fall Watch: stopped — $_fallEventCount fall event(s) this session');
  }

  /// Append an incoming accel sample to the rolling window. Called from
  /// the `rawPpgEvent` listener whenever Fall Watch is active.
  void _onFallAccelSample(int xRaw, int yRaw, int zRaw) {
    final magRaw = math.sqrt(
      xRaw * xRaw + yRaw * yRaw + zRaw * zRaw.toDouble(),
    );

    // Calibration phase: accumulate resting magnitude.
    if (_fallOneGRaw == null) {
      _fallCalibSumRawMag += magRaw;
      _fallCalibSampleCount++;
      if (_fallCalibSampleCount >= _fallCalibTargetSamples) {
        _fallOneGRaw = _fallCalibSumRawMag / _fallCalibSampleCount;
        _push('  Fall Watch: calibrated 1g = '
            '${_fallOneGRaw!.toStringAsFixed(1)} raw');
      }
    }

    _fallAccelX.add(xRaw);
    _fallAccelY.add(yRaw);
    _fallAccelZ.add(zRaw);

    // Cap the buffer at `_fallWindowSeconds` of samples.
    final maxSamples = (_fallWindowSeconds * _fallWatchFsHz).round();
    while (_fallAccelX.length > maxSamples) {
      _fallAccelX.removeAt(0);
      _fallAccelY.removeAt(0);
      _fallAccelZ.removeAt(0);
    }

    _fallLastXRaw = xRaw;
    _fallLastYRaw = yRaw;
    _fallLastZRaw = zRaw;
    if (_fallOneGRaw != null && _fallOneGRaw! > 0) {
      _fallLastMagG = magRaw / _fallOneGRaw!;
    }
  }

  /// Run the FallDetector across the current sliding window. Re-scales
  /// raw accel samples by the calibrated 1g reference and converts to
  /// milli-g so it matches the detector's documented input units.
  void _evalFallWindow() {
    if (!_fallWatchActive) return;
    final oneG = _fallOneGRaw;
    if (oneG == null || oneG <= 0) return;
    final minSamples =
        ((10 + 1 + 0.3) * _fallWatchFsHz).round() + 10;
    if (_fallAccelX.length < minSamples) return;

    // Rescale raw accel → milli-g using the calibrated reference.
    final xMg = _fallAccelX
        .map((v) => (v / oneG * 1000).round())
        .toList(growable: false);
    final yMg = _fallAccelY
        .map((v) => (v / oneG * 1000).round())
        .toList(growable: false);
    final zMg = _fallAccelZ
        .map((v) => (v / oneG * 1000).round())
        .toList(growable: false);

    final events = _fallDetector.detect(
      accelXMilliG: xMg,
      accelYMilliG: yMg,
      accelZMilliG: zMg,
      samplingRateHz: _fallWatchFsHz,
    );

    if (events.isNotEmpty) {
      for (final e in events) {
        _push('────────────────────────────────────');
        _push('★★ FALL DETECTED — severity=${e.severity.name} '
            'peak=${e.peakImpactG.toStringAsFixed(2)}g '
            'postImpactStd=${e.postImpactVariabilityG.toStringAsFixed(3)}g');
        // Stand-in for the production alert UI ("Are you okay?"
        // countdown prompt). Lets the user verify the state-machine
        // fired correctly until the alerts table + push notification
        // infrastructure lands.
        _push('   ↳ Are you okay?  (tap Fall Watch to dismiss / log next event)');
        _push('────────────────────────────────────');
      }
      setState(() => _fallEventCount += events.length);
      // Clear the buffer so the same event doesn't fire again on the
      // next eval tick.
      _fallAccelX.clear();
      _fallAccelY.clear();
      _fallAccelZ.clear();
    }
    setState(() {});
  }

  /// Clear every capture buffer + counter so a fresh capture starts clean.
  /// Shared by the green-only HR raw capture and the red/IR SpO2 raw capture.
  void _resetCaptureBuffers() {
    setState(() => _ppgPacketCount = 0);
    _ppgGreenBuffer.clear();
    _ppgCountSeq.clear();
    _ppgGreenAll.clear();
    _ppgRedAll.clear();
    _ppgIrAll.clear();
    _ppgAccelXAll.clear();
    _ppgAccelYAll.clear();
    _ppgAccelZAll.clear();
    _ppgEpochMsAll.clear();
    _ppgRawSamples.clear();
    _greenZeroCount = 0;
    _captureStartMs = DateTime.now().millisecondsSinceEpoch;
    _captureEndMs = null;
    _capturing = true;
  }

  /// Stop whatever raw capture is running and turn the LEDs off. Sends BOTH
  /// the HR-mode and SpO2-mode stop commands — the band may be in either raw
  /// mode, and an extra stop for the inactive mode is a harmless no-op, so
  /// this guarantees the green and red/IR LEDs both go dark. The band calls
  /// run regardless of widget lifecycle (ref captured up front) so leaving the
  /// screen still kills the measurement; only the log lines are mounted-gated.
  Future<void> _stopActiveCapture({bool announce = true}) async {
    _captureStopTimer?.cancel();
    _captureStopTimer = null;
    final ble = ref.read(bleServiceProvider);
    final wasCapturing = _capturing;
    try {
      await ble.stopMeasure();
    } catch (e) {
      if (mounted) _push('HR-mode stop error: $e');
    }
    try {
      await ble.stopMeasureSpo2Raw();
    } catch (e) {
      if (mounted) _push('SpO2-mode stop error: $e');
    }
    if (wasCapturing) {
      _captureEndMs = DateTime.now().millisecondsSinceEpoch;
    }
    _capturing = false;
    if (announce && mounted) {
      _push('Capture stopped — LEDs off (packets=$_ppgPacketCount)');
    }
  }

  Future<void> _capturePpg() async {
    if (!_connected) {
      _push('PPG capture: not connected');
      return;
    }
    // Stop any in-flight capture first so we never stack two measurements on
    // the band (the cause of LEDs staying lit).
    await _stopActiveCapture(announce: false);
    _resetCaptureBuffers();
    _push('PPG capture: starting ${_rawCaptureSeconds}s measurement...');
    try {
      // HLT-7 needs ≥60s of clean tachogram for stable LF/HF; 90s
      // gives ~60s after the bandpass ±2s trim, matching the
      // wearable-industry standard for frequency-domain HRV.
      final r = await ref
          .read(bleServiceProvider)
          .startMeasureHrRaw(durationSec: _rawCaptureSeconds);
      _push('PPG capture: started $r');
      // Auto-stop when the window is up — the single source of truth for
      // ending the capture and turning the LED off.
      _captureStopTimer =
          Timer(const Duration(seconds: _rawCaptureSeconds), () async {
        await _stopActiveCapture(announce: false);
        if (mounted) {
          _push('PPG capture: auto-stopped after ${_rawCaptureSeconds}s — '
              'total packets=$_ppgPacketCount');
        }
      });
    } catch (e) {
      _push('PPG capture error: $e');
    }
  }

  /// Blood-oxygen raw capture — drives the red + IR LEDs. Buffers into the
  /// same channels as [_capturePpg] so Analyze / Export Raw work unchanged;
  /// the point of this capture is to see whether the red/IR columns come back
  /// nonzero (HR raw mode is green-only).
  Future<void> _captureSpo2Raw() async {
    if (!_connected) {
      _push('SpO2 raw capture: not connected');
      return;
    }
    await _stopActiveCapture(announce: false);
    _resetCaptureBuffers();
    _push('SpO2 raw capture: starting ${_rawCaptureSeconds}s measurement '
        '(red + IR LEDs)...');
    try {
      final r = await ref
          .read(bleServiceProvider)
          .startMeasureSpo2Raw(durationSec: _rawCaptureSeconds);
      _push('SpO2 raw capture: started $r');
      _captureStopTimer =
          Timer(const Duration(seconds: _rawCaptureSeconds), () async {
        await _stopActiveCapture(announce: false);
        if (mounted) {
          _push('SpO2 raw capture: auto-stopped after ${_rawCaptureSeconds}s — '
              'total packets=$_ppgPacketCount. '
              'Tap Export Raw to check the red/infrared columns.');
        }
      });
    } catch (e) {
      _push('SpO2 raw capture error: $e');
    }
  }

  Future<void> _analyzePpg() async {
    if (_ppgGreenBuffer.length < 100) {
      _push('Analyze: need more samples — buffer has ${_ppgGreenBuffer.length}. Tap Capture PPG first.');
      return;
    }

    final endMs = _captureEndMs ?? DateTime.now().millisecondsSinceEpoch;
    final startMs = _captureStartMs ?? endMs;
    final durationS = ((endMs - startMs) / 1000.0).clamp(1.0, 9999.0);

    // The capture → metrics pipeline lives in PpgAnalysisService so the
    // headless scheduled-capture path (Step 3) and this debug screen share
    // one implementation. The service returns the same step-by-step log
    // lines we used to build inline, plus a structured result + quality
    // verdict. Pass the band's own HR so the gate's HR cross-check runs.
    final result = ref.read(ppgAnalysisServiceProvider).analyze(
          counts: _ppgCountSeq,
          greens: _ppgGreenAll,
          greenZeroCount: _greenZeroCount,
          durationSec: durationS,
          bandHr: _lastRealtimeHr,
        );
    for (final line in result.log) {
      _push(line);
    }
    _lastPpgResult = result;
    _push('  → R-R series ready (${result.rrIntervalsMs.length} intervals) — '
        'tap the R-R export button to copy for tuning');

    // HLT-8: persist resting respiratory into today's daily_metrics, but
    // only when the capture cleared the quality gate — a rejected capture
    // writes nothing rather than poisoning the day's metric.
    if (result.passedQualityGate &&
        result.respRateBpm != null &&
        _activeUserId != null) {
      await _persistRespRateForToday(result);
      // Refresh the home "today" provider in case it was built on an earlier
      // calendar day (app left open) and is still watching the wrong date —
      // otherwise this fresh write lands on a day nothing is observing.
      ref.invalidate(todayDailyMetricsProvider);
    }
  }

  /// HLT-8: upsert today's `restingRespRateBpm` + rhythm-irregularity metrics
  /// without clobbering other daily_metrics columns. Mirrors the merge
  /// pattern in `_aggregate` and the step-sync persistence path.
  Future<void> _persistRespRateForToday(PpgAnalysisResult result) async {
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
      restingRespRateBpm: result.respRateBpm,
      rrIrregularityPct: result.rrIrregularityPct ?? existing?.rrIrregularityPct,
      ectopicBeatPct: result.ectopicBeatPct ?? existing?.ectopicBeatPct,
      computedAt: nowUtc,
    );
    await repo.upsert(merged);
    _push('  persisted resp=${result.respRateBpm?.toStringAsFixed(1)} '
        'irregularity=${result.rrIrregularityPct?.toStringAsFixed(1) ?? "—"}% '
        'ectopic=${result.ectopicBeatPct?.toStringAsFixed(1) ?? "—"}% for today');
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

  /// Smoke-test the local-notification pipe end-to-end: init → request
  /// permission → fire one notification. Proves `flutter_local_notifications`
  /// works on this device before the alert rules engine is built on top.
  Future<void> _sendTestNotification() async {
    final notifications = ref.read(notificationServiceProvider);
    _push('Test notification: initializing…');
    try {
      await notifications.init();
      final granted = await notifications.requestPermission();
      _push('  permission granted: $granted');
      if (!granted) {
        _push('  ⚠️ denied — enable notifications for HLTH in system settings');
        return;
      }
      await notifications.show(
        id: 9001,
        title: 'HLTH test alert',
        body: 'If you can see this, local notifications work. 🎉',
        channel: AlertChannel.alert,
      );
      _push('  ✅ fired — check your notification shade');
    } catch (e) {
      _push('  ❌ test notification error: $e');
    }
  }

  /// Run the alert rules engine once and log each rule's outcome. Lets us
  /// verify the evaluator → notification → log pipeline on-device without
  /// waiting for a real trigger condition (e.g. 3-day retention staleness).
  Future<void> _evaluateAlerts() async {
    final evaluator = ref.read(alertEvaluatorProvider);
    final userId = _activeUserId ?? ActiveSession.defaultUserId;
    _push('Evaluate alerts: running rules…');
    try {
      final results = await evaluator.evaluateAll(userId: userId);
      for (final r in results) {
        _push('  ${r.type}: ${r.fired ? "🔔 FIRED" : r.reason}');
      }
    } catch (e) {
      _push('  ❌ evaluate error: $e');
    }
  }

  /// Run the headless scheduled-capture pipeline on demand (bypasses the
  /// once-daily gate) so we can verify Step 3 without waiting for the tick.
  /// Blocks for the full capture window (~3 min) then logs the outcome.
  Future<void> _scheduledCaptureNow() async {
    final svc = ref.read(scheduledPpgCaptureServiceProvider);
    final userId = _activeUserId ?? ActiveSession.defaultUserId;
    _push('Scheduled capture: starting ~3-min PPG capture… (sit still)');
    final result = await svc.captureAndPersist(userId: userId);
    if (result == null) {
      _push('  ⚠️ skipped — band not connected, capture in flight, or too few samples');
      return;
    }
    for (final line in result.log) {
      _push(line);
    }
    if (result.passedQualityGate) {
      _push('  ✅ persisted to today — resp=${result.respRateBpm ?? "—"} bpm, '
          'rmssd=${result.hrvRmssdMs?.toStringAsFixed(1) ?? "—"}ms');
    } else {
      _push('  ⚠️ not persisted — quality gate rejected');
    }
  }

  /// Probe whether the H59 supports per-minute (interval) SpO2 — the
  /// granularity a breathing-disruption alert needs. Proper sequence:
  ///   1. read the capability bitmap (authoritative yes/no),
  ///   2. if supported, ENABLE per-minute interval monitoring (this is the
  ///      step that was missing before — interval SpO2 is off by default,
  ///      so an un-enabled read just times out and looks "unsupported"),
  ///   3. read back the setting to confirm it stuck,
  ///   4. attempt an immediate read (likely sparse until worn overnight).
  Future<void> _probeSpo2Interval() async {
    final ble = ref.read(bleServiceProvider);
    _push('SpO2 interval probe — step 1: reading device capability…');
    try {
      final cap = await ble.getSpO2Capability();
      if (cap['ok'] != true) {
        _push('  ⚠️ capability read failed/timed out — retry while connected');
        return;
      }
      final supported = cap['supportIntervalBloodOxygen'] == true;
      _push('  supportIntervalBloodOxygen=$supported '
          '(hr=${cap['supportIntervalHeartRate']}, temp=${cap['supportIntervalTemperature']})');
      if (!supported) {
        _push('  ⚠️ capability reports false — trying enable anyway (bitmap may under-report)');
      }

      _push('SpO2 interval probe — step 2: enabling interval monitoring (interval=2)…');
      final en = await ble.enableSpO2Interval(enable: true, intervalMinutes: 2);
      _push('  read-back: isEnable=${en['isEnable']} interval=${en['interval']}min');
      if (en['isEnable'] != true) {
        _push('  ⚠️ enable did not stick — band may need re-bind/reconnect');
      }

      _push('SpO2 interval probe — step 3: reading today\'s buffer…');
      final r = await ble.getSpO2Interval(dayOffset: 0);
      final total = r['total'] ?? 0;
      final nonZero = r['nonZero'] ?? 0;
      if (r['timedOut'] == true) {
        _push('  (empty buffer — expected right after enabling)');
      } else {
        _push('  total=$total samples, nonZero=$nonZero, '
            'min=${r['min']}%, max=${r['max']}%');
      }
      if (nonZero > 0) {
        _push('  ✅ per-minute SpO2 flowing — breathing-disruption alert is feasible');
      } else {
        _push('  ✅ supported + enabled. WEAR OVERNIGHT, then re-tap to read the buffer.');
      }
    } catch (e) {
      _push('  ❌ probe error: $e');
    }
  }

  /// One labelled icon in the scrollable debug toolbar.
  Widget _toolBtn(IconData icon, String label, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Debug'),
        // The action icons outgrew the toolbar and got cramped. Move them into
        // a full-width, horizontally-scrollable strip under the title, each
        // labelled, so they're easy to find and tap during debugging.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _toolBtn(Icons.bloodtype_outlined, 'SpO2', _probeSpo2Interval),
                _toolBtn(Icons.timelapse, 'Capture', _scheduledCaptureNow),
                _toolBtn(Icons.notifications_active_outlined, 'Notify',
                    _sendTestNotification),
                _toolBtn(Icons.fact_check_outlined, 'Alerts', _evaluateAlerts),
                _toolBtn(Icons.battery_charging_full, 'Scores', _computeScores),
                _toolBtn(Icons.monitor_heart_outlined, 'R-R',
                    _exportRrToClipboard),
                _toolBtn(
                  _logMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                  _logMaximized ? 'Min' : 'Max',
                  () => setState(() => _logMaximized = !_logMaximized),
                ),
                _toolBtn(Icons.copy_all, 'Copy', _copyLogToClipboard),
                _toolBtn(Icons.delete_outline, 'Clear',
                    () => setState(_log.clear)),
              ],
            ),
          ),
        ),
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
                title: 'Battery drain test (24h)',
                expanded: _batteryTestExpanded,
                onToggle: () => setState(
                    () => _batteryTestExpanded = !_batteryTestExpanded),
                child: _BatteryTestPanel(
                  startedAt: _batteryTestStartedAt,
                  selectedIntervalMin: _selectedSyncIntervalMin,
                  onSelectInterval: _setSyncInterval,
                  onStartNewTest: _startBatteryTest,
                  onExportCsv: _exportBatteryTestCsv,
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
                  onHrDay: _getHeartRateSpecificDay,
                  onSpo2Day: _getSpo2SpecificDay,
                  onSpo2: _getSpo2,
                  onSleep: _getSleep,
                  onSyncAllSleep: _syncAllSleep,
                  onSteps: _getSteps,
                  onCapturePpg: _capturePpg,
                  onCaptureSpo2Raw: _captureSpo2Raw,
                  onStopCapture: () => _stopActiveCapture(),
                  onAnalyzePpg: _analyzePpg,
                  onExportRaw: _exportRawCaptureToClipboard,
                  onDbCounts: _showDbCounts,
                  onAggregate: _aggregate,
                  onHrv: _getHrv,
                  onStress: _getStress,
                  onBp: _getBp,
                  onBpDay: _getBpSpecificDay,
                  onBpStart: _startBpMeasurement,
                  onBpStop: _stopBpMeasurement,
                  onSpo2StreamStart: _startSpo2Stream,
                  onSpo2StreamStop: _stopSpo2Stream,
                  onHrvStreamStart: _startHrvStream,
                  onHrvStreamStop: _stopHrvStream,
                  spo2Streaming: _spo2Streaming,
                  hrvStreaming: _hrvStreaming,
                  onStepBuckets: _getStepBuckets,
                  onStepDay: _getStepSpecificDay,
                  onRunAll: _runAllSyncs,
                  onPushCloud: _pushToCloud,
                  onToggleFallWatch: _toggleFallWatch,
                  fallWatchActive: _fallWatchActive,
                  fallWatchLastMagG: _fallLastMagG,
                  fallWatchLastXRaw: _fallLastXRaw,
                  fallWatchLastYRaw: _fallLastYRaw,
                  fallWatchLastZRaw: _fallLastZRaw,
                  fallWatchEventCount: _fallEventCount,
                  fallWatchCalibrated: _fallOneGRaw != null,
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
                      final alias = _deviceAliases[d.id];
                      final title = alias ?? d.name;
                      final subtitleSuffix =
                          alias != null ? '  •  ${d.name}' : '';
                      final isBound = _boundMac == d.id;
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        selected: selected,
                        leading: Icon(
                          Icons.bluetooth,
                          size: 18,
                          color: selected ? Colors.blue : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(title,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            if (isBound) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.green, width: 0.5),
                                ),
                                child: const Text(
                                  '★ Paired',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                            '${d.id}  rssi=${d.rssi}$subtitleSuffix',
                            style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Rename',
                          onPressed: () => _renameDevice(d),
                        ),
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

  // ──────────────────────────────────────────────────────────────────────
  // Battery drain test — Ryan's "Priority 2" from the 2026-06-17 sync.
  // Toggles native sync cadence (10/15/30 min) and tracks band+phone
  // battery deltas in the `battery_telemetry` table. Lives here (not in
  // Settings) because it's a debug-only diagnostic — production users
  // should never see this control.
  // ──────────────────────────────────────────────────────────────────────

  Future<void> _loadBatteryTestState() async {
    final prefs = await SharedPreferences.getInstance();
    final startSec = prefs.getInt(_kBatteryTestStartKey);
    final interval = prefs.getInt(_kBatteryTestIntervalKey) ?? 30;
    // Re-apply the persisted cadence on the native side (the native default
    // is 30 — if the user previously selected 10 we need to push it back
    // every cold start).
    final ble = ref.read(bleServiceProvider);
    final applied = await ble.setSyncIntervalMinutes(interval);
    if (!mounted) return;
    setState(() {
      _selectedSyncIntervalMin = applied?.minutes ?? interval;
      _batteryTestStartedAt = startSec == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startSec * 1000, isUtc: true);
    });
  }

  Future<void> _setSyncInterval(int minutes) async {
    final ble = ref.read(bleServiceProvider);
    final applied = await ble.setSyncIntervalMinutes(minutes);
    if (applied == null) {
      _push('Sync interval: failed (band not bound?)');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBatteryTestIntervalKey, applied.minutes);
    if (!mounted) return;
    setState(() => _selectedSyncIntervalMin = applied.minutes);
    _push('Sync cadence → ${applied.minutes} min'
        '${applied.clamped ? " (clamped)" : ""}');
  }

  Future<void> _startBatteryTest() async {
    // Reset the test marker AND log a baseline sample so the panel has
    // start values immediately (don't make the user wait for the first
    // periodic tick to see meaningful numbers).
    final now = DateTime.now().toUtc();
    final ble = ref.read(bleServiceProvider);
    final repo = ref.read(batteryTelemetryRepositoryProvider);
    final band = await ble.requestBattery();
    await repo.insert(
      bandBatteryPercent: band?.level,
      bandCharging: band?.charging,
      syncIntervalMin: _selectedSyncIntervalMin,
      eventType: 'manual',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kBatteryTestStartKey,
      now.millisecondsSinceEpoch ~/ 1000,
    );
    if (!mounted) return;
    setState(() => _batteryTestStartedAt = now);
    _push('Battery test started — band=${band?.level ?? "?"}% '
        '@ $_selectedSyncIntervalMin min cadence');
  }

  Future<void> _exportBatteryTestCsv() async {
    final since = _batteryTestStartedAt ??
        DateTime.now().toUtc().subtract(const Duration(days: 1));
    final repo = ref.read(batteryTelemetryRepositoryProvider);
    final csv = await repo.exportCsv(since);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Battery telemetry CSV copied to clipboard')),
    );
    _push('Exported ${csv.split('\n').length - 2} telemetry rows to clipboard');
  }

  /// Export the last Analyze's derived R-R series for off-device cleaner
  /// tuning (Ryan's request). Copies a small JSON blob: the raw R-R array the
  /// cleaner operates on, the post-cleaning array, plus the context he needs
  /// (HR, loss, gate verdict) to set alpha/window against real data.
  Future<void> _exportRrToClipboard() async {
    final r = _lastPpgResult;
    if (r == null || r.rrIntervalsMs.isEmpty) {
      _push('No R-R series yet — Capture PPG then Analyze first.');
      return;
    }
    String arr(List<double> xs) =>
        '[${xs.map((v) => v.toStringAsFixed(1)).join(', ')}]';
    final blob = StringBuffer()
      ..writeln('{')
      ..writeln('  "captured_at": "${DateTime.now().toIso8601String()}",')
      ..writeln('  "hr_bpm": ${r.hrBpm?.toStringAsFixed(1) ?? "null"},')
      ..writeln('  "fs_band_hz": ${r.fsNativeHz},')
      ..writeln('  "ble_loss_pct": ${r.blePacketLossPct.toStringAsFixed(1)},')
      ..writeln('  "passed_quality_gate": ${r.passedQualityGate},')
      ..writeln('  "ectopic_dropped": ${r.ectopicDropped},')
      ..writeln('  "rr_irregularity_pct": '
          '${r.rrIrregularityPct?.toStringAsFixed(1) ?? "null"},')
      ..writeln('  "ectopic_beat_pct": '
          '${r.ectopicBeatPct?.toStringAsFixed(1) ?? "null"},')
      ..writeln('  "rr_raw_ms": ${arr(r.rrIntervalsMs)},')
      ..writeln('  "rr_cleaned_ms": ${arr(r.cleanedRrMs)}')
      ..writeln('}');
    await Clipboard.setData(ClipboardData(text: blob.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('R-R series copied '
          '(${r.rrIntervalsMs.length} raw, ${r.cleanedRrMs.length} cleaned)')),
    );
    _push('Exported R-R series to clipboard — '
        '${r.rrIntervalsMs.length} raw / ${r.cleanedRrMs.length} cleaned '
        'intervals (paste into a message/file for Ryan)');
  }

  /// Export the full raw multi-channel capture for Ryan's morphology /
  /// cardio-load work — one line per packet in the same map format as the
  /// live log: every field the band emits (timestamp_ms, ppg_count,
  /// green/red/IR, heart/rri/hrv, accel XYZ). A header carries the sample
  /// count, fs, and a per-channel activity summary so it's obvious at a
  /// glance which LEDs were driven.
  Future<void> _exportRawCaptureToClipboard() async {
    final n = _ppgCountSeq.length;
    if (n == 0) {
      _push('No raw capture buffered — tap Capture PPG first.');
      return;
    }
    final fsHz = (_captureStartMs != null &&
            _captureEndMs != null &&
            _captureEndMs! > _captureStartMs!)
        ? n / ((_captureEndMs! - _captureStartMs!) / 1000.0)
        : null;

    // Channel-activity check — the decisive test for whether the firmware
    // actually streams red/IR in this manual-HR mode, or green only. A "dark"
    // channel (0 nonzero) means the LED isn't driven in this mode regardless
    // of the SDK exposing the field.
    String channelSummary(String name, List<num> xs) {
      var nonZero = 0;
      num lo = 0, hi = 0;
      var seen = false;
      for (final v in xs) {
        if (v != 0) {
          nonZero++;
          if (!seen) {
            lo = v;
            hi = v;
            seen = true;
          } else {
            if (v < lo) lo = v;
            if (v > hi) hi = v;
          }
        }
      }
      return nonZero == 0
          ? '$name: DARK (0 nonzero of ${xs.length})'
          : '$name: $nonZero nonzero, range $lo..$hi';
    }

    _push('── raw channel activity (n=$n) ──');
    _push('  ${channelSummary("green", _ppgGreenAll)}');
    _push('  ${channelSummary("red", _ppgRedAll)}');
    _push('  ${channelSummary("infrared", _ppgIrAll)}');
    _push('  ${channelSummary("accel_x", _ppgAccelXAll)}');

    // Body: one line per packet, in the exact same map format as the live
    // per-packet log (every field: green/red/IR + heart/rri/hrv + accel).
    final buf = StringBuffer()
      ..writeln('# hlth raw PPG capture')
      ..writeln('# samples=$n '
          'fs_hz=${fsHz?.toStringAsFixed(1) ?? "?"} '
          'green_zero=$_greenZeroCount')
      ..writeln('# ${channelSummary("green", _ppgGreenAll)}')
      ..writeln('# ${channelSummary("red", _ppgRedAll)}')
      ..writeln('# ${channelSummary("infrared", _ppgIrAll)}')
      ..writeln('# ${channelSummary("accel_x", _ppgAccelXAll)}');
    for (final s in _ppgRawSamples) {
      buf.writeln(s);
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:
          Text('Raw capture copied (${_ppgRawSamples.length} packets)')),
    );
    _push('Exported raw multi-channel capture — ${_ppgRawSamples.length} packets '
        '(full per-packet format: green/red/IR + heart/rri/hrv + accel) '
        'to clipboard');
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

/// Battery drain test panel — Ryan's "Priority 2" deliverable.
///
/// The panel does three things:
///   1. Lets the user pick the periodic-sync cadence (10/15/30 min) at
///      runtime — written to native via `BleService.setSyncIntervalMinutes`.
///   2. Shows the start/now battery snapshot for band + phone with computed
///      drain rates (%/hr) and 24h projections.
///   3. Provides "Start new test" (resets the start marker + logs a baseline
///      sample) and "Export CSV" (copies raw telemetry rows to clipboard).
class _BatteryTestPanel extends ConsumerWidget {
  const _BatteryTestPanel({
    required this.startedAt,
    required this.selectedIntervalMin,
    required this.onSelectInterval,
    required this.onStartNewTest,
    required this.onExportCsv,
  });

  final DateTime? startedAt;
  final int selectedIntervalMin;
  final void Function(int) onSelectInterval;
  final VoidCallback onStartNewTest;
  final VoidCallback onExportCsv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = startedAt ??
        DateTime.now().toUtc().subtract(const Duration(hours: 24));
    final summaryStream =
        ref.watch(batteryTelemetryRepositoryProvider).watchSummary(since);
    return StreamBuilder<BatteryDrainSummary>(
      stream: summaryStream,
      builder: (context, snap) {
        final s = snap.data;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cadence selector
              const Text('Sync cadence', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [10, 15, 30].map((m) {
                  final selected = m == selectedIntervalMin;
                  return ChoiceChip(
                    label: Text('$m min'),
                    selected: selected,
                    onSelected: (_) => onSelectInterval(m),
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 11),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              // Test status
              if (startedAt == null) ...[
                const Text(
                  'No test running. Pick a cadence above, then tap "Start new test" '
                  'to log a baseline. Leave the app + band running for 24h.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ] else ...[
                Text(
                  'Test started ${_fmtElapsed(s?.elapsed)} ago '
                  '· ${s?.sampleCount ?? 0} samples logged',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(height: 8),
                _row(
                  'Band',
                  start: s?.firstBandPercent,
                  now: s?.lastBandPercent,
                  ratePerHr: s?.bandDrainPctPerHour,
                  projected24h: s?.bandProjected24h,
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 14),
                    label: Text(
                      startedAt == null ? 'Start new test' : 'Restart test',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: onStartNewTest,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 14),
                    label: const Text('Export CSV',
                        style: TextStyle(fontSize: 11)),
                    onPressed: onExportCsv,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(
    String label, {
    required int? start,
    required int? now,
    required double? ratePerHr,
    required double? projected24h,
  }) {
    final rateText = ratePerHr == null
        ? '…'
        : '${ratePerHr.toStringAsFixed(2)}%/hr';
    final projText = projected24h == null
        ? '…'
        : '${projected24h.toStringAsFixed(1)}% over 24h';
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(
            'start ${start ?? "?"}% → now ${now ?? "?"}%',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Text(rateText,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        const SizedBox(width: 8),
        Text(projText,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ],
    );
  }

  String _fmtElapsed(Duration? d) {
    if (d == null || d == Duration.zero) return '0m';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
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
  final VoidCallback onHrDay;
  final VoidCallback onSpo2;
  final VoidCallback onSpo2Day;
  final VoidCallback onSleep;
  final VoidCallback onSyncAllSleep;
  final VoidCallback onSteps;
  final VoidCallback onCapturePpg;
  final VoidCallback onCaptureSpo2Raw;
  final VoidCallback onStopCapture;
  final VoidCallback onAnalyzePpg;
  final VoidCallback onExportRaw;
  final VoidCallback onDbCounts;
  final VoidCallback onAggregate;
  final VoidCallback onHrv;
  final VoidCallback onStress;
  final VoidCallback onBp;
  final VoidCallback onBpDay;
  final VoidCallback onBpStart;
  final VoidCallback onBpStop;
  final VoidCallback onSpo2StreamStart;
  final VoidCallback onSpo2StreamStop;
  final VoidCallback onHrvStreamStart;
  final VoidCallback onHrvStreamStop;
  final bool spo2Streaming;
  final bool hrvStreaming;
  final VoidCallback onStepBuckets;
  final VoidCallback onStepDay;
  final VoidCallback onRunAll;
  final VoidCallback onPushCloud;
  // HLT-5 Fall Watch debug toggle + live status.
  final VoidCallback onToggleFallWatch;
  final bool fallWatchActive;
  final bool fallWatchCalibrated;
  final double? fallWatchLastMagG;
  final int? fallWatchLastXRaw;
  final int? fallWatchLastYRaw;
  final int? fallWatchLastZRaw;
  final int fallWatchEventCount;

  const _ActionBar({
    required this.scanning,
    required this.connected,
    required this.hasSelection,
    required this.onScan,
    required this.onConnect,
    required this.onDisconnect,
    required this.onEnableMonitoring,
    required this.onHr,
    required this.onHrDay,
    required this.onSpo2,
    required this.onSpo2Day,
    required this.onSleep,
    required this.onSyncAllSleep,
    required this.onSteps,
    required this.onCapturePpg,
    required this.onCaptureSpo2Raw,
    required this.onStopCapture,
    required this.onAnalyzePpg,
    required this.onExportRaw,
    required this.onDbCounts,
    required this.onAggregate,
    required this.onHrv,
    required this.onStress,
    required this.onBp,
    required this.onBpDay,
    required this.onBpStart,
    required this.onBpStop,
    required this.onSpo2StreamStart,
    required this.onSpo2StreamStop,
    required this.onHrvStreamStart,
    required this.onHrvStreamStop,
    required this.spo2Streaming,
    required this.hrvStreaming,
    required this.onStepBuckets,
    required this.onStepDay,
    required this.onRunAll,
    required this.onPushCloud,
    required this.onToggleFallWatch,
    required this.fallWatchActive,
    required this.fallWatchCalibrated,
    required this.fallWatchLastMagG,
    required this.fallWatchLastXRaw,
    required this.fallWatchLastYRaw,
    required this.fallWatchLastZRaw,
    required this.fallWatchEventCount,
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
            onPressed: connected ? onHrDay : null,
            style: compactStyle,
            child: const Text('HR Day'),
          ),
          OutlinedButton(
            onPressed: connected ? onSpo2 : null,
            style: compactStyle,
            child: const Text('Sync SpO2'),
          ),
          OutlinedButton(
            onPressed: connected ? onSpo2Day : null,
            style: compactStyle,
            child: const Text('SpO2 Day'),
          ),
          OutlinedButton(
            onPressed: connected ? onSleep : null,
            style: compactStyle,
            child: const Text('Sync Sleep'),
          ),
          FilledButton.icon(
            onPressed: connected ? onSyncAllSleep : null,
            icon: const Icon(Icons.bedtime, size: 14),
            label: const Text('Sync All Sleep'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.indigo),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
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
            onPressed: connected ? onStepDay : null,
            style: compactStyle,
            child: const Text('Steps Day'),
          ),
          OutlinedButton(
            onPressed: connected ? onHrv : null,
            style: compactStyle,
            child: const Text('Sync HRV'),
          ),
          OutlinedButton(
            onPressed: connected ? onStress : null,
            style: compactStyle,
            child: const Text('Stress Day'),
          ),
          OutlinedButton(
            onPressed: connected ? onBp : null,
            style: compactStyle,
            child: const Text('Sync BP'),
          ),
          OutlinedButton(
            onPressed: connected ? onBpDay : null,
            style: compactStyle,
            child: const Text('BP Day'),
          ),
          OutlinedButton(
            onPressed: connected ? onBpStart : null,
            style: compactStyle,
            child: const Text('Start BP'),
          ),
          OutlinedButton(
            onPressed: connected ? onBpStop : null,
            style: compactStyle,
            child: const Text('Stop BP'),
          ),
          OutlinedButton(
            onPressed: connected && !spo2Streaming ? onSpo2StreamStart : null,
            style: compactStyle,
            child: const Text('Stream SpO2'),
          ),
          OutlinedButton(
            onPressed: spo2Streaming ? onSpo2StreamStop : null,
            style: compactStyle,
            child: const Text('Stop SpO2'),
          ),
          OutlinedButton(
            onPressed: connected && !hrvStreaming ? onHrvStreamStart : null,
            style: compactStyle,
            child: const Text('Stream HRV'),
          ),
          OutlinedButton(
            onPressed: hrvStreaming ? onHrvStreamStop : null,
            style: compactStyle,
            child: const Text('Stop HRV'),
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
          FilledButton.icon(
            onPressed: connected ? onCaptureSpo2Raw : null,
            icon: const Icon(Icons.bloodtype, size: 14),
            label: const Text('SpO2 Raw'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.redAccent),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          OutlinedButton.icon(
            onPressed: connected ? onStopCapture : null,
            icon: const Icon(Icons.stop_circle_outlined, size: 14),
            label: const Text('Stop Capture'),
            style: compactStyle,
          ),
          OutlinedButton.icon(
            onPressed: onAnalyzePpg,
            icon: const Icon(Icons.analytics, size: 14),
            label: const Text('Analyze'),
            style: compactStyle,
          ),
          OutlinedButton.icon(
            onPressed: onExportRaw,
            icon: const Icon(Icons.science_outlined, size: 14),
            label: const Text('Export Raw'),
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
          FilledButton.icon(
            onPressed: onPushCloud,
            icon: const Icon(Icons.cloud_upload, size: 14),
            label: const Text('Push Cloud'),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.deepPurple),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
          // HLT-5 Fall Watch toggle. Active = red+pulse-ish style so the
          // user always knows the live stream is on.
          FilledButton.icon(
            onPressed: connected ? onToggleFallWatch : null,
            icon: Icon(
              fallWatchActive ? Icons.stop_circle : Icons.shield_outlined,
              size: 14,
            ),
            label: Text(_fallWatchLabel()),
            style: compactStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(
                fallWatchActive ? Colors.redAccent : Colors.blueGrey,
              ),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _fallWatchLabel() {
    if (!fallWatchActive) return 'Fall Watch';
    if (!fallWatchCalibrated) return 'Fall Watch • calibrating…';
    final mag = fallWatchLastMagG;
    final magStr = mag != null ? '${mag.toStringAsFixed(2)}g' : '—';
    final x = fallWatchLastXRaw;
    final y = fallWatchLastYRaw;
    final z = fallWatchLastZRaw;
    final axisStr = (x != null && y != null && z != null)
        ? 'x:$x y:$y z:$z'
        : '—';
    return 'Fall Watch ON • $axisStr • mag $magStr • $fallWatchEventCount fall(s)';
  }
}
