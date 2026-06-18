import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/metric_tile.dart';

/// Standalone "Pair another device" screen — opened from Settings →
/// Device when the user gets a new ring or wants to switch bands.
///
/// Mirrors the scan/connect/ensureDevice path from the BLE debug screen
/// so the persisted device row is consistent across entry points.
///
/// Three states driven by [_PairingPhase]:
///   1. scanning — pulsing indicator + discovered devices list
///   2. connecting — spinner with device name
///   3. paired — checkmark + battery tile + Done button
class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

enum _PairingPhase { scanning, connecting, finalizing, paired }

class _PairingScreenState extends ConsumerState<PairingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _scanTimeout = Duration(seconds: 30);
  static const Duration _connectTimeout = Duration(seconds: 15);

  _PairingPhase _phase = _PairingPhase.scanning;
  List<BleDevice> _devices = [];
  BleDevice? _target; // device the user tapped to connect/pair
  bool _scanInFlight = false;
  bool _scanTimedOut = false;
  String? _connectError;

  Timer? _scanTimer;
  Timer? _connectTimer;
  StreamSubscription<List<BleDevice>>? _devicesSub;
  StreamSubscription<BleConnectionState>? _connSub;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachStreams();
      _startScan();
    });
  }

  void _attachStreams() {
    final ble = ref.read(bleServiceProvider);
    _devicesSub = ble.discoveredDevices.listen((list) {
      if (!mounted) return;
      setState(() => _devices = list);
    });
  }

  Future<void> _startScan() async {
    if (_scanInFlight) return;
    setState(() {
      _phase = _PairingPhase.scanning;
      _scanInFlight = true;
      _scanTimedOut = false;
      _connectError = null;
    });
    _scanTimer?.cancel();
    _scanTimer = Timer(_scanTimeout, _onScanTimeout);
    final ble = ref.read(bleServiceProvider);
    try {
      final discovered = await ble.startScan();
      if (!mounted) return;
      setState(() {
        _devices = discovered;
        _scanInFlight = false;
      });
    } on BleException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanInFlight = false;
      });
      _scanTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanInFlight = false);
      _scanTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  void _onScanTimeout() {
    if (!mounted) return;
    if (_phase != _PairingPhase.scanning) return;
    setState(() {
      _scanTimedOut = _devices.isEmpty;
      _scanInFlight = false;
    });
    // Best-effort: ask native side to stop the scan. Errors are non-fatal.
    ref.read(bleServiceProvider).stopScan().catchError((_) {});
  }

  Future<void> _stopScan() async {
    _scanTimer?.cancel();
    try {
      await ref.read(bleServiceProvider).stopScan();
    } catch (_) {/* swallow — UI should still update */}
    if (!mounted) return;
    setState(() {
      _scanInFlight = false;
      _scanTimedOut = _devices.isEmpty;
    });
  }

  Future<void> _connectTo(BleDevice device) async {
    _scanTimer?.cancel();
    // Make sure scan is halted before we attempt to bind.
    try {
      await ref.read(bleServiceProvider).stopScan();
    } catch (_) {/* non-fatal */}

    setState(() {
      _target = device;
      _phase = _PairingPhase.connecting;
      _connectError = null;
    });

    final ble = ref.read(bleServiceProvider);
    final completer = Completer<void>();

    // Listen for the connected state from the native side. The connect()
    // future itself resolves on success, but observing the stream lets us
    // catch a late `connected` event if `connect()` returned before the
    // native confirmation arrives.
    _connSub?.cancel();
    _connSub = ble.connectionState.listen((state) {
      if (state == BleConnectionState.connected && !completer.isCompleted) {
        completer.complete();
      }
    });

    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Connection timed out', _connectTimeout),
        );
      }
    });

    try {
      // Race the explicit connect() call against the stream-observed
      // connected event. Whichever resolves first wins.
      await Future.any<void>([
        ble.connect(device.id).then((_) {
          if (!completer.isCompleted &&
              ble.currentConnectionState == BleConnectionState.connected) {
            completer.complete();
          }
        }),
        completer.future,
      ]);
      if (!completer.isCompleted) {
        await completer.future;
      }

      // Persist the device row so it shows up as the active bound device.
      await ref.read(activeSessionProvider).ensureDevice(
            bandId: device.id,
            displayName: device.name,
            model: 'H59',
          );

      // The native side waits 1500ms after `onConnected` before sending
      // `CMD_BIND_SUCCESS` (the bind handshake the band confirms with a
      // vibration), then another ~800ms before `SetTimeReq`. Show a
      // "Finalizing" state until that bootstrap settles so the user's
      // perception of "Paired" matches the band's vibration.
      if (!mounted) return;
      setState(() => _phase = _PairingPhase.finalizing);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      setState(() => _phase = _PairingPhase.paired);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PairingPhase.scanning;
        _target = null;
        _connectError = e is TimeoutException
            ? 'Connection timed out. Try again.'
            : 'Connection failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_connectError!)),
      );
      // Re-arm scanning so the user has options to retry.
      _startScan();
    } finally {
      _connectTimer?.cancel();
      _connSub?.cancel();
      _connSub = null;
    }
  }

  void _done() {
    if (context.canPop()) {
      context.pop();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _connectTimer?.cancel();
    _devicesSub?.cancel();
    _connSub?.cancel();
    _pulse.dispose();
    // Best-effort stop in case the user backed out mid-scan.
    ref.read(bleServiceProvider).stopScan().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Pair Device'),
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: switch (_phase) {
          _PairingPhase.scanning => _ScanningBody(
              devices: _devices,
              scanning: _scanInFlight,
              timedOut: _scanTimedOut,
              pulse: _pulse,
              onDeviceTap: _connectTo,
              onStopScan: _stopScan,
              onRetry: _startScan,
            ),
          _PairingPhase.connecting => _ConnectingBody(deviceName: _target?.name ?? ''),
          _PairingPhase.finalizing => _FinalizingBody(deviceName: _target?.name ?? ''),
          _PairingPhase.paired => _PairedBody(
              device: _target!,
              onDone: _done,
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// State 1 — Scanning
// ─────────────────────────────────────────────────────────────────────────

class _ScanningBody extends StatelessWidget {
  const _ScanningBody({
    required this.devices,
    required this.scanning,
    required this.timedOut,
    required this.pulse,
    required this.onDeviceTap,
    required this.onStopScan,
    required this.onRetry,
  });

  final List<BleDevice> devices;
  final bool scanning;
  final bool timedOut;
  final AnimationController pulse;
  final ValueChanged<BleDevice> onDeviceTap;
  final VoidCallback onStopScan;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Hold your band close to your phone',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: _PulsingScanIndicator(controller: pulse, active: scanning),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              scanning
                  ? 'Scanning…'
                  : timedOut
                      ? 'No devices found'
                      : 'Tap a device to pair',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Text(
                      timedOut
                          ? 'Make sure the band is awake and nearby, then scan again.'
                          : 'Looking for nearby bands…',
                      style: const TextStyle(color: AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _DeviceTile(
                      device: devices[i],
                      onTap: () => onDeviceTap(devices[i]),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: scanning
                  ? onStopScan
                  : onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    scanning ? AppColors.surfaceLight : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(scanning ? 'Stop scan' : 'Scan again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingScanIndicator extends StatelessWidget {
  const _PulsingScanIndicator({required this.controller, required this.active});
  final AnimationController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = active ? controller.value : 0.0;
        final outerSize = 96.0 + t * 32.0;
        final outerAlpha = active ? (0.35 - 0.25 * t).clamp(0.0, 1.0) : 0.10;
        return SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: outerAlpha),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onTap});
  final BleDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.watch, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.id} · ${device.rssi} dBm',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// State 2 — Connecting
// ─────────────────────────────────────────────────────────────────────────

class _ConnectingBody extends StatelessWidget {
  const _ConnectingBody({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connecting to ${deviceName.isEmpty ? 'device' : deviceName}…',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep the band close to your phone.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// State 2.5 — Finalizing (band-bootstrap settle period)
// ─────────────────────────────────────────────────────────────────────────

class _FinalizingBody extends StatelessWidget {
  const _FinalizingBody({required this.deviceName});
  final String deviceName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Finalizing pairing…',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            deviceName.isEmpty
                ? 'Your band will vibrate when ready.'
                : '$deviceName will vibrate when ready.',
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// State 3 — Paired
// ─────────────────────────────────────────────────────────────────────────

class _PairedBody extends ConsumerWidget {
  const _PairedBody({required this.device, required this.onDone});
  final BleDevice device;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.watch(bleServiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Paired with ${device.name}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your band is connected and ready.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          StreamBuilder<({int level, bool charging})>(
            stream: ble.batteryUpdate,
            builder: (context, snap) {
              final level = snap.data?.level;
              final charging = snap.data?.charging ?? false;
              return MetricGrid(tiles: [
                MetricTile(
                  label: 'Battery',
                  value: level == null ? '—' : '$level',
                  valueUnit: level == null ? null : '%',
                  reference: charging ? 'Charging' : '',
                ),
                MetricTile(
                  label: 'Model',
                  value: device.name,
                ),
              ]);
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}
