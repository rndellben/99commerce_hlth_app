import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// SharedPreferences keys for the offline-immediate UI cache. The band's
// flash is still the source of truth — these just let the screen render
// the last-known settings before (or instead of) connecting.
const _kPrefBpEnabled = 'bp_scheduled_enabled';
const _kPrefBpIntervalMin = 'bp_scheduled_interval_minutes';

/// Blood Pressure detail screen.
///
/// Shows the latest stored BP reading as the headline, plus two controls:
///   • Scheduled monitoring toggle + interval picker — writes
///     `BpSettingReq.getWriteInstance(...)` to the band so it auto-measures
///     on a cadence (default every hour, all day).
///   • "Measure Now" — triggers an on-demand `manualModeBP` measurement
///     (~30s). Result is captured via the realtime BP stream and shown in
///     a snackbar.
class BloodPressureScreen extends ConsumerStatefulWidget {
  const BloodPressureScreen({super.key});

  @override
  ConsumerState<BloodPressureScreen> createState() =>
      _BloodPressureScreenState();
}

class _BloodPressureScreenState extends ConsumerState<BloodPressureScreen> {
  bool? _bpEnabled;
  int _bpIntervalMinutes = 60;
  bool _bpBusy = false;
  bool _measuring = false;

  @override
  void initState() {
    super.initState();
    _loadScheduled();
  }

  Future<void> _loadScheduled() async {
    // Step 1: paint last-known values from SharedPreferences immediately
    // so the user sees their chosen interval even before (or without) a
    // band connection.
    final prefs = await SharedPreferences.getInstance();
    final cachedEnabled = prefs.getBool(_kPrefBpEnabled);
    final cachedInterval = prefs.getInt(_kPrefBpIntervalMin);
    if (mounted && (cachedEnabled != null || cachedInterval != null)) {
      setState(() {
        _bpEnabled = cachedEnabled;
        _bpIntervalMinutes = cachedInterval ?? 60;
      });
    }

    // Step 2: if connected, fetch ground truth from the band and reconcile.
    try {
      final cfg = await ref.read(bleServiceProvider).getBpScheduled();
      if (!mounted) return;
      final bandEnabled = cfg['isEnable'] as bool?;
      final bandInterval = (cfg['intervalMinutes'] as int?) ?? 60;
      setState(() {
        _bpEnabled = bandEnabled;
        _bpIntervalMinutes = bandInterval;
      });
      // Keep the cache in sync with what the band actually reports.
      if (bandEnabled != null) {
        await prefs.setBool(_kPrefBpEnabled, bandEnabled);
      }
      await prefs.setInt(_kPrefBpIntervalMin, bandInterval);
    } catch (_) {
      // Disconnected — keep showing the cached values from step 1.
    }
  }

  Future<void> _writeCache({required bool enabled, required int intervalMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefBpEnabled, enabled);
    await prefs.setInt(_kPrefBpIntervalMin, intervalMinutes);
  }

  Future<void> _toggleScheduled(bool enabled) async {
    final ble = ref.read(bleServiceProvider);
    final requestedInterval = _bpIntervalMinutes;
    setState(() {
      _bpBusy = true;
      // Optimistic — H59 firmware's WRITE ack is unreliable (returns
      // isEnable=false / multiple=0 even when the write succeeds, same
      // quirk documented for HR/SpO2/HRV in BleManager.kt). Reflect the
      // user's intent immediately and reconcile via a READ below.
      _bpEnabled = enabled;
    });
    try {
      await ble.setBpScheduled(
        enabled: enabled,
        intervalMinutes: requestedInterval,
      );
      // Give the band a moment to commit, then read ground truth.
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      try {
        final cfg = await ble.getBpScheduled();
        if (!mounted) return;
        final trueEnabled = cfg['isEnable'] as bool? ?? enabled;
        final trueInterval =
            (cfg['intervalMinutes'] as int?) ?? requestedInterval;
        setState(() {
          _bpEnabled = trueEnabled;
          // Don't downgrade a non-zero interval to 0 — the band sometimes
          // omits multiple in the read-back if disabled; keep the user's
          // last picked value so the picker stays meaningful.
          if (trueInterval > 0) _bpIntervalMinutes = trueInterval;
        });
        await _writeCache(
          enabled: trueEnabled,
          intervalMinutes: trueInterval > 0 ? trueInterval : requestedInterval,
        );
      } catch (_) {
        // Read-back failed — keep optimistic state and cache.
        await _writeCache(
          enabled: enabled,
          intervalMinutes: requestedInterval,
        );
      }
    } catch (e) {
      if (mounted) {
        // Hard failure — revert the optimistic flip.
        setState(() => _bpEnabled = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _bpBusy = false);
    }
  }

  Future<void> _pickInterval() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Measurement interval',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final mins in const [15, 30, 60])
              ListTile(
                leading: Icon(
                  mins == _bpIntervalMinutes
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text(_intervalLabel(mins)),
                onTap: () => Navigator.pop(ctx, mins),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == _bpIntervalMinutes) return;
    setState(() => _bpIntervalMinutes = picked);
    if (_bpEnabled == true) {
      await _toggleScheduled(true);
    }
  }

  String _intervalLabel(int mins) {
    if (mins % 60 == 0) {
      final h = mins ~/ 60;
      return h == 1 ? 'Every hour' : 'Every $h hours';
    }
    return 'Every $mins minutes';
  }

  Future<void> _measureNow() async {
    final ble = ref.read(bleServiceProvider);
    setState(() => _measuring = true);
    try {
      // startBpMeasurement returns the converged reading via its Future
      // (see BleManager.kt startBpMeasurement → result.success(...)).
      // No need to subscribe to bloodPressureMeasured — that stream is
      // for passive notifications, not user-triggered measurements.
      final r = await ble.startBpMeasurement();
      final sbp = (r['sbp'] as int?) ?? 0;
      final dbp = (r['dbp'] as int?) ?? 0;
      if (!mounted) return;
      if (sbp <= 0 || dbp <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Band did not converge — try again with the ring snug'),
          ),
        );
        return;
      }
      // Persist so the home card + headline pick it up via
      // latestBpReadingProvider's StreamProvider on bpRepository.watchLatest.
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device != null) {
        final now = DateTime.now();
        await ref.read(bpRepositoryProvider).insert(BpReading(
              id: const Uuid().v4(),
              userId: ActiveSession.defaultUserId,
              deviceId: device.id,
              capturedAt: now.toUtc(),
              tzOffsetMin: now.timeZoneOffset.inMinutes,
              systolicMmhg: sbp,
              diastolicMmhg: dbp,
              derivation: BpDerivation.bandSensor,
              source: DataSource.bandManual,
            ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Measured: $sbp/$dbp mmHg')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Measure failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestBp = ref.watch(latestBpReadingProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Pressure'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.monitor_heart_outlined,
                color: AppColors.bloodPressure, size: 48),
            const SizedBox(height: 16),
            Text(
              latestBp == null
                  ? '--'
                  : '${latestBp.systolicMmhg}/${latestBp.diastolicMmhg}',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(color: AppColors.bloodPressure),
            ),
            Text(
              'mmHg',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              latestBp == null
                  ? (connected
                      ? 'No reading yet — measure or wait for scheduled run'
                      : 'Connect your band to see readings')
                  : 'Last reading ${_timeAgo(latestBp.capturedAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),
            _ScheduledCard(
              enabled: _bpEnabled,
              intervalLabel: _intervalLabel(_bpIntervalMinutes),
              busy: _bpBusy,
              onToggle: _toggleScheduled,
              onPickInterval: _pickInterval,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: !connected || _measuring ? null : _measureNow,
                icon: _measuring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.bolt),
                label: Text(_measuring ? 'Measuring (~30s)...' : 'Measure Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bloodPressure,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!connected)
              Text(
                'Connect your band from the Settings tab to enable scheduling and Measure.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({
    required this.enabled,
    required this.intervalLabel,
    required this.busy,
    required this.onToggle,
    required this.onPickInterval,
  });
  final bool? enabled;
  final String intervalLabel;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickInterval;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.schedule,
                color: AppColors.bloodPressure),
            title: const Text('Scheduled monitoring'),
            subtitle: Text(
              enabled == null
                  ? 'Connect the band to view status'
                  : enabled!
                      ? 'Auto-measures ${intervalLabel.toLowerCase()}, all day'
                      : 'Off — only manual readings will be saved',
            ),
            value: enabled ?? false,
            onChanged:
                (busy || enabled == null) ? null : (v) => onToggle(v),
          ),
          if (enabled != null)
            ListTile(
              leading: const SizedBox(width: 24),
              title: const Text('Interval'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(intervalLabel,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                ],
              ),
              onTap: busy ? null : onPickInterval,
            ),
        ],
      ),
    );
  }
}
