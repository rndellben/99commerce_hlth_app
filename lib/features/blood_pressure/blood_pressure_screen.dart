import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/bp_calibration.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/features/blood_pressure/bp_calibration_providers.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/features/onboarding/onboarding_screen.dart';
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

  /// Opens the cuff-reading entry sheet. Captures the live HR at submit
  /// time, writes the calibration to local DB, and pushes the new BP/HR
  /// baseline to the band via `setPersonalInfo` so the band's own
  /// scheduled-BP estimator is anchored to this cuff value too.
  Future<void> _openCalibrate() async {
    final ble = ref.read(bleServiceProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    final result = await showModalBottomSheet<({int sbp, int dbp, String? notes})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => _CalibrateSheet(initialHr: ble.realtimeHeartRate),
    );
    if (result == null || !mounted) return;

    final age = _ageFrom(profile?.dateOfBirth);
    final hrNow = _latestHr();
    final calibrationId = const Uuid().v4();
    final now = DateTime.now();
    final calibration = BpCalibration(
      id: calibrationId,
      userId: ActiveSession.defaultUserId,
      capturedAt: now.toUtc(),
      cuffSystolic: result.sbp,
      cuffDiastolic: result.dbp,
      hrAtCalibration: hrNow,
      ageAtCalibration: age,
      notes: result.notes,
      isActive: true,
      createdAt: now.toUtc(),
    );
    await ref
        .read(bpCalibrationRepositoryProvider)
        .upsertNewActive(calibration);

    // Push baseline + personal info to the band so QWatch and our app
    // stay aligned. Non-fatal if disconnected — the local row already
    // captured the calibration and we'll re-write next reconnect.
    final isMale = profile?.sexAtBirth == SexAtBirth.male;
    final ok = await ble.setPersonalInfo(
      isMale: isMale,
      age: age,
      heightCm: profile?.heightCm?.round() ?? 170,
      weightKg: profile?.weightKg?.round() ?? 70,
      baselineSbp: result.sbp,
      baselineDbp: result.dbp,
      hrWarnHigh: (220 - age).clamp(120, 200),
    );
    if (ok) {
      await ref
          .read(bpCalibrationRepositoryProvider)
          .markBandWriteSucceeded(calibrationId);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Calibrated to ${result.sbp}/${result.dbp}'
            : 'Saved locally — band sync will retry on next connect'),
      ),
    );
  }

  int _ageFrom(DateTime? dob) {
    if (dob == null) return 30;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age -= 1;
    }
    return age.clamp(13, 100);
  }

  int? _latestHr() {
    return ref.read(latestHrSampleProvider).valueOrNull?.bpm;
  }

  @override
  Widget build(BuildContext context) {
    final latestPair = ref.watch(calibratedLatestBpProvider).valueOrNull;
    final latestBp = latestPair?.reading;
    final activeCal = ref.watch(activeBpCalibrationProvider).valueOrNull;
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
              latestPair == null
                  ? '--'
                  : '${latestPair.displaySbp}/${latestPair.displayDbp}',
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
                  : (latestPair!.isCalibrated
                      ? 'Calibrated · last reading ${_timeAgo(latestBp.capturedAt)} · raw ${latestBp.systolicMmhg}/${latestBp.diastolicMmhg}'
                      : 'Uncalibrated · last reading ${_timeAgo(latestBp.capturedAt)}'),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _CalibrationStatusCard(
              calibration: activeCal,
              onTap: _openCalibrate,
            ),
            const SizedBox(height: 16),
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

/// "Calibrated 132/85 · 2 days ago" status row — tap opens the Calibrate
/// sheet. When no active calibration exists, prompts the user to add one.
class _CalibrationStatusCard extends StatelessWidget {
  const _CalibrationStatusCard({
    required this.calibration,
    required this.onTap,
  });
  final BpCalibration? calibration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cal = calibration;
    final title = cal == null
        ? 'Not calibrated'
        : 'Calibrated to ${cal.cuffSystolic}/${cal.cuffDiastolic}';
    final subtitle = cal == null
        ? 'Enter a cuff reading for personalized BP estimates'
        : 'Set ${_ago(cal.capturedAt)}'
            '${cal.bandWriteSucceeded ? '' : ' · band sync pending'}';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        leading: Icon(
          cal == null
              ? Icons.tune
              : (cal.bandWriteSucceeded
                  ? Icons.check_circle_outline
                  : Icons.sync_problem_outlined),
          color: cal == null
              ? AppColors.textSecondary
              : (cal.bandWriteSucceeded
                  ? AppColors.success
                  : AppColors.warning),
        ),
        title: Text(title),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(cal == null ? 'Calibrate' : 'Re-calibrate'),
        ),
        onTap: onTap,
      ),
    );
  }

  String _ago(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inMinutes < 60) return 'just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}

/// Modal sheet that asks the user for their latest cuff reading and an
/// optional note. Shows the band's live HR so they can see what value
/// will be paired with the cuff reading as the calibration anchor.
class _CalibrateSheet extends StatefulWidget {
  const _CalibrateSheet({required this.initialHr});
  final Stream<int> initialHr;

  @override
  State<_CalibrateSheet> createState() => _CalibrateSheetState();
}

class _CalibrateSheetState extends State<_CalibrateSheet> {
  final _sbpCtrl = TextEditingController();
  final _dbpCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _sbpCtrl.dispose();
    _dbpCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validate(String? raw, {required int min, required int max}) {
    if (raw == null || raw.isEmpty) return 'Required';
    final v = int.tryParse(raw);
    if (v == null) return 'Numbers only';
    if (v < min || v > max) return '$min-$max range';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'Enter your cuff reading',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Use a recent reading from a standard arm cuff. The band '
              'will personalize BP estimates around this anchor.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sbpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Systolic',
                    suffixText: 'mmHg',
                    hintText: '120',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _dbpCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Diastolic',
                    suffixText: 'mmHg',
                    hintText: '80',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. after lunch, left arm',
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: widget.initialHr,
            builder: (context, snap) {
              final hr = snap.data;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite,
                        color: AppColors.heartRate, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hr == null
                            ? 'Waiting for HR from band…'
                            : 'Current HR: $hr bpm — used as the calibration anchor',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final sbpErr = _validate(_sbpCtrl.text,
                        min: 70, max: 200);
                    final dbpErr = _validate(_dbpCtrl.text,
                        min: 40, max: 130);
                    if (sbpErr != null || dbpErr != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(sbpErr != null
                              ? 'Systolic: $sbpErr'
                              : 'Diastolic: $dbpErr'),
                        ),
                      );
                      return;
                    }
                    final sbp = int.parse(_sbpCtrl.text);
                    final dbp = int.parse(_dbpCtrl.text);
                    if (sbp <= dbp) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Systolic must be higher than diastolic'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, (
                      sbp: sbp,
                      dbp: dbp,
                      notes: _notesCtrl.text.trim().isEmpty
                          ? null
                          : _notesCtrl.text.trim(),
                    ));
                  },
                  child: const Text('Save calibration'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
