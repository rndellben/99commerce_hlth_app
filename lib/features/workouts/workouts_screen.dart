import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/exercise_session.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/services/vo2max_service.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// One row in the workout picker.
class _SportType {
  const _SportType(this.label, this.icon, this.sportType);
  final String label;
  final IconData icon;
  final int sportType;
}

/// Ryan's "eight things people actually do" curated set (call 2026-06-17).
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

class _SportTile extends ConsumerWidget {
  const _SportTile({required this.sport});
  final _SportType sport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context, ref),
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

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    // Check band connection first
    final connState = ref.read(bleConnectionStateProvider).valueOrNull;
    final connected = connState == BleConnectionState.connected;
    if (!connected) {
      if (!context.mounted) return;
      final shouldConnect = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Band not connected'),
          content: const Text(
            'Your band must be connected to start a workout. '
            'Connect now from Settings?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      if (shouldConnect == true && context.mounted) {
        context.push('/settings/device');
      }
      return;
    }

    // Connected — push countdown screen
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CountdownScreen(
          sportType: sport.sportType,
          label: sport.label,
          icon: sport.icon,
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
    final hrText =
        session.avgHrBpm == null ? '' : ' · ${session.avgHrBpm} bpm avg';
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
// Countdown — 3-2-1-GO! before the workout starts.
// ──────────────────────────────────────────────────────────────────────

class _CountdownScreen extends StatefulWidget {
  const _CountdownScreen({
    required this.sportType,
    required this.label,
    required this.icon,
  });
  final int sportType;
  final String label;
  final IconData icon;

  @override
  State<_CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<_CountdownScreen> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_count <= 1) {
        _timer?.cancel();
        // Replace countdown with active workout
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActiveWorkoutScreen(
              sportType: widget.sportType,
              label: widget.label,
              icon: widget.icon,
            ),
          ),
        );
      } else {
        setState(() => _count -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '$_count',
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(
                            color: AppColors.primary,
                            fontSize: 96,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get ready…',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Active workout — runs from Start to End, shows live HR + elapsed time.
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
  DateTime? _lastHrTime;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _starting = false;
  bool _ending = false;
  String? _statusMessage;
  Timer? _hrWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hrWatchdog?.cancel();
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
    // Subscribe to HR updates during sport mode.
    _subs.add(ble.deviceNotify.listen((evt) {
      if (evt.dataType != 1 || evt.loadData.isEmpty) return;
      final hr =
          evt.loadData.length >= 3 ? evt.loadData[2] : evt.loadData.last;
      if (hr <= 0 || hr > 240) return;
      if (mounted) {
        setState(() {
          _latestHr = hr;
          _lastHrTime = DateTime.now();
        });
      }
    }));
    _subs.add(ble.realtimeHeartRate.listen((bpm) {
      if (bpm > 0 && bpm < 240 && mounted) {
        setState(() {
          _latestHr = bpm;
          _lastHrTime = DateTime.now();
        });
      }
    }));
    // HR watchdog — check every 15s if HR has gone stale (>30s since last).
    _hrWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _ending || _starting) return;
      if (_lastHrTime != null &&
          DateTime.now().difference(_lastHrTime!).inSeconds > 30) {
        _showHrDisconnectPrompt();
      }
    });
    setState(() {
      _starting = false;
      _statusMessage = null;
    });
  }

  Future<void> _showHrDisconnectPrompt() async {
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Heart rate lost'),
        content: const Text(
          'No heart rate signal detected. Make sure the band is snug '
          'on your finger.\n\nYou can continue without HR or end the workout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'end'),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.heartRate),
            child: const Text('End workout'),
          ),
        ],
      ),
    );
    if (action == 'end' && mounted) {
      _confirmEnd();
    }
    // 'continue' → dismiss, watchdog will check again in 15s
  }

  Future<bool> _onBackPressed() async {
    if (_startedAt == null) return true;
    final stop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Stop workout?'),
        content: const Text(
            'Going back will stop the current workout. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.heartRate),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (stop == true && mounted) {
      await _endAndNavigate();
    }
    return false; // we handle navigation ourselves
  }

  Future<void> _confirmEnd() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End workout?'),
        content: const Text(
            'Are you sure you want to end this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, end'),
          ),
        ],
      ),
    );
    if (shouldEnd == true && mounted) {
      await _endAndNavigate();
    }
  }

  Future<void> _endAndNavigate() async {
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
    _hrWatchdog?.cancel();
    if (!mounted) return;
    if (ack == null) {
      setState(() {
        _ending = false;
        _statusMessage = 'Band rejected the end — try again.';
      });
      return;
    }
    setState(() => _statusMessage = 'Pulling workout summary…');
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final sessions = await ble.syncSportSessions();
    if (!mounted) return;
    final endedAt = DateTime.now();
    final myStartUnixSec =
        _startedAt!.toUtc().millisecondsSinceEpoch ~/ 1000;
    SportSessionSummary? best;
    int bestDelta = 0;
    for (final s in sessions) {
      final delta = (s.startTimeUnixSec - myStartUnixSec).abs();
      if (best == null || delta < bestDelta) {
        best = s;
        bestDelta = delta;
      }
    }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.label),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onBackPressed,
          ),
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
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(fontFeatures: const []),
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
                        style: const TextStyle(
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
                    onPressed: _starting || _ending ? null : _confirmEnd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.heartRate,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Summary — shown immediately after End.
// ──────────────────────────────────────────────────────────────────────

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.label;
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename workout'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Workout name',
            hintText: 'e.g. Morning run',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.pop(ctx, name.isEmpty ? null : name);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && mounted) {
      setState(() => _displayName = newName);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete workout?'),
        content: const Text(
            'This workout will be removed from your history. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Find and soft-delete the session matching this workout's start time.
    final repo = ref.read(exerciseSessionRepositoryProvider);
    final sessions = await repo
        .watchForUser(userId: ActiveSession.defaultUserId, limit: 50)
        .first;
    final myStartSec =
        widget.startedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    for (final s in sessions) {
      final sSec = s.startedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
      if ((sSec - myStartSec).abs() <= 300) {
        await repo.softDelete(s.id);
        break;
      }
    }
    if (mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _save() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final dur =
        s != null ? Duration(seconds: s.durationSec) : widget.phoneElapsed;
    final m = dur.inMinutes;
    final sec = dur.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout complete'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Icon(widget.icon, size: 56, color: AppColors.primary),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _rename,
                      child: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ],
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
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.label, required this.value, required this.unit});
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
