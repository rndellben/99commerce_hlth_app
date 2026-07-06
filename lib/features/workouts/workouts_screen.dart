import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/exercise_session.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/services/vo2max_service.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// One row in the workout picker. `sportType` is the raw SDK byte we
/// hand to `PhoneSportReq.getSportStatus(...)` — see sdk_ring.pdf §2.3.10
/// for the full enum.
class _SportType {
  const _SportType(this.label, this.icon, this.sportType);
  final String label;
  final IconData icon;
  final int sportType;
}

/// Ryan's "eight things people actually do" curated set (call 2026-06-17).
/// Order is intentional — most-used at the top.
const List<_SportType> _kSports = [
  _SportType('Run', Icons.directions_run, BleService.sportTypeRunning),
  _SportType('Walk', Icons.directions_walk, BleService.sportTypeWalking),
  _SportType('Cycle', Icons.directions_bike, BleService.sportTypeCycling),
  _SportType('Hike', Icons.terrain, BleService.sportTypeHiking),
  _SportType('Strength', Icons.fitness_center, BleService.sportTypeStrength),
  _SportType('Yoga', Icons.self_improvement, BleService.sportTypeYoga),
  _SportType('Rowing', Icons.rowing, BleService.sportTypeRowing),
  _SportType('Elliptical', Icons.directions_run, BleService.sportTypeElliptical),
];

/// Resolve a sport-type byte to a display label + icon. Falls back to a
/// generic "Workout" tile for any SDK byte not in our curated set (the
/// band can record workouts from external apps too).
({String label, IconData icon}) _resolveSport(int sportType) {
  for (final s in _kSports) {
    if (s.sportType == sportType) return (label: s.label, icon: s.icon);
  }
  return (label: 'Workout', icon: Icons.timer);
}

// ──────────────────────────────────────────────────────────────────────
// Picker — list of supported sport types + history of past workouts
// ──────────────────────────────────────────────────────────────────────

class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref
        .watch(_workoutHistoryProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <ExerciseSession>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Start a workout',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: _kSports
                .map((s) => _SportTile(sport: s))
                .toList(growable: false),
          ),
          const SizedBox(height: 28),
          Text(
            'Recent workouts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No workouts recorded yet. Start one above — the band will '
                'track HR, distance, and calories until you tap End.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            )
          else
            ...history.map((s) => _HistoryRow(session: s)),
        ],
      ),
    );
  }
}

final _workoutHistoryProvider = StreamProvider<List<ExerciseSession>>((ref) {
  final repo = ref.watch(exerciseSessionRepositoryProvider);
  return repo.watchForUser(userId: ActiveSession.defaultUserId, limit: 25);
});

class _SportTile extends StatelessWidget {
  const _SportTile({required this.sport});
  final _SportType sport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(
                sportType: sport.sportType,
                label: sport.label,
                icon: sport.icon,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(sport.icon, color: AppColors.primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sport.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.session});
  final ExerciseSession session;

  @override
  Widget build(BuildContext context) {
    final (:label, :icon) = _resolveSport(session.sportType);
    final dur = Duration(seconds: session.durationSec);
    final m = dur.inMinutes;
    final s = dur.inSeconds % 60;
    final hrText = session.avgHrBpm == null ? '' : ' · ${session.avgHrBpm} bpm avg';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(
        '${m}m ${s}s · ${(session.distanceM / 1000).toStringAsFixed(2)} km'
        '$hrText',
      ),
      trailing: Text(
        _shortDate(session.startedAt.toLocal()),
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
      ),
    );
  }
}

String _shortDate(DateTime dt) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day);
  final t = DateTime(dt.year, dt.month, dt.day);
  if (t == d) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return '${dt.month}/${dt.day}';
}

// ──────────────────────────────────────────────────────────────────────
// Active workout — runs from Start to End, shows live HR + elapsed time.
//
// HR source: the band's existing DeviceNotifyListener (dataType=1) which
// fires whenever HR changes during an active sport session. We surface
// that via `ble.deviceNotify` already exposed in BleService.
// ──────────────────────────────────────────────────────────────────────

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({
    super.key,
    required this.sportType,
    required this.label,
    required this.icon,
  });

  final int sportType;
  final String label;
  final IconData icon;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;
  int? _latestHr;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _starting = false;
  bool _ending = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _statusMessage = 'Starting workout on band…';
    });
    final ble = ref.read(bleServiceProvider);
    final ack = await ble.startSportMode(sportType: widget.sportType);
    if (!mounted) return;
    if (ack == null) {
      setState(() {
        _starting = false;
        _statusMessage = 'Band rejected the start — check connection.';
      });
      return;
    }
    _startedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
    // Subscribe to band push notifications. dataType=1 is "watch heart
    // rate test changes" per sdk_ring.pdf §2.3.9. During sport mode this
    // fires at sub-minute cadence (firmware-driven) so we keep the live
    // HR card fresh without polling.
    _subs.add(ble.deviceNotify.listen((evt) {
      if (evt.dataType != 1 || evt.loadData.isEmpty) return;
      // Heart rate value is in the load array. Layout per the sample
      // listener in §2.3.9: `loadData[2]` after the type byte.
      final hr = evt.loadData.length >= 3 ? evt.loadData[2] : evt.loadData.last;
      if (hr <= 0 || hr > 240) return;
      if (mounted) setState(() => _latestHr = hr);
    }));
    // Also forward realtime-HR pushes if the band emits them as a separate
    // stream (some firmware variants do).
    _subs.add(ble.realtimeHeartRate.listen((bpm) {
      if (bpm > 0 && bpm < 240 && mounted) setState(() => _latestHr = bpm);
    }));
    setState(() {
      _starting = false;
      _statusMessage = null;
    });
  }

  Future<void> _end() async {
    if (_startedAt == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _ending = true;
      _statusMessage = 'Ending workout…';
    });
    final ble = ref.read(bleServiceProvider);
    final ack = await ble.endSportMode(sportType: widget.sportType);
    _ticker?.cancel();
    if (!mounted) return;
    if (ack == null) {
      setState(() {
        _ending = false;
        _statusMessage = 'Band rejected the end — try again.';
      });
      return;
    }
    setState(() => _statusMessage = 'Pulling workout summary…');
    // Give the band a beat to finalize the recording before sync.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final sessions = await ble.syncSportSessions();
    if (!mounted) return;
    final endedAt = DateTime.now();
    final myStartUnixSec = _startedAt!.toUtc().millisecondsSinceEpoch ~/ 1000;
    // Pick the band-side session whose start timestamp is closest to ours.
    // The band uses its own clock which can drift slightly from the phone.
    SportSessionSummary? best;
    int bestDelta = 0;
    for (final s in sessions) {
      final delta = (s.startTimeUnixSec - myStartUnixSec).abs();
      if (best == null || delta < bestDelta) {
        best = s;
        bestDelta = delta;
      }
    }
    // Allow 5 min of clock drift before we trust the match.
    if (best != null && bestDelta <= 300) {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device != null) {
        final sessionId =
            await ref.read(exerciseSessionRepositoryProvider).upsertFromBand(
                  userId: ActiveSession.defaultUserId,
                  deviceId: device.id,
                  summary: best,
                );
        // Estimate aerobic fitness (VO2 max) for this workout. Non-fatal:
        // a scoring failure must not block the summary screen.
        if (sessionId != null) {
          try {
            await ref.read(vo2MaxServiceProvider).computeForSession(
                  userId: ActiveSession.defaultUserId,
                  sessionId: sessionId,
                  log: (m) => debugPrint('[VO2] $m'),
                );
          } catch (e) {
            debugPrint('[VO2] computeForSession threw: $e');
          }
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          label: widget.label,
          icon: widget.icon,
          startedAt: _startedAt!,
          endedAt: endedAt,
          phoneElapsed: _elapsed,
          summary: best,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.label),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 24),
                  Icon(widget.icon, size: 64, color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    '$m:$s',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontFeatures: const [],
                        ),
                  ),
                  Text(
                    'Elapsed',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite,
                            color: AppColors.heartRate),
                        const SizedBox(width: 12),
                        Text(
                          _latestHr == null ? '--' : _latestHr.toString(),
                          style:
                              Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'bpm',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_statusMessage != null)
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12),
                    ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(_ending ? 'Ending…' : 'End workout'),
                  onPressed: _starting || _ending ? null : _end,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.heartRate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Summary — shown immediately after End. Displays whatever the band
// returned (avg/min/max HR, distance, calories) plus our phone-side
// elapsed time for cross-check.
// ──────────────────────────────────────────────────────────────────────

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.label,
    required this.icon,
    required this.startedAt,
    required this.endedAt,
    required this.phoneElapsed,
    required this.summary,
  });

  final String label;
  final IconData icon;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration phoneElapsed;
  final SportSessionSummary? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final dur = s != null ? Duration(seconds: s.durationSec) : phoneElapsed;
    final m = dur.inMinutes;
    final sec = dur.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout complete'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Icon(icon, size: 56, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${m}m ${sec}s',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (s == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Workout ended, but the band hasn\'t returned a summary yet. '
                'Pull-to-refresh on the Workouts screen in a minute to retry.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ),
          ] else ...[
            _Stat(
              label: 'Avg heart rate',
              value: s.avgHr > 0 ? s.avgHr.toString() : '--',
              unit: 'bpm',
            ),
            _Stat(
              label: 'Max heart rate',
              value: s.maxHr > 0 ? s.maxHr.toString() : '--',
              unit: 'bpm',
            ),
            _Stat(
              label: 'Distance',
              value: (s.distanceM / 1000).toStringAsFixed(2),
              unit: 'km',
            ),
            _Stat(
              label: 'Calories',
              value: s.calories.toStringAsFixed(0),
              unit: 'kcal',
            ),
            if (s.steps > 0)
              _Stat(label: 'Steps', value: s.steps.toString(), unit: ''),
            if (s.avgSpeedCmS > 0)
              _Stat(
                label: 'Avg speed',
                value: (s.avgSpeedCmS / 100).toStringAsFixed(2),
                unit: 'm/s',
              ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(unit,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}
