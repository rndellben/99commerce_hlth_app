import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/services/retention_sweep_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outcome of one gate evaluation: either the sweep ran (`result` set) or
/// the 24h gate blocked it (`skipReason` set, e.g. "last ran 4h ago").
class RetentionGateOutcome {
  const RetentionGateOutcome({this.result, this.skipReason});

  final RetentionSweepResult? result;
  final String? skipReason;
}

/// HLT-12: the once-a-day gate in front of the retention sweep.
///
/// Persists the last-swept timestamp in `shared_preferences` so the 24h
/// gate survives app restarts (both the UI and headless engines share the
/// same prefs file, so whichever engine sweeps first wins the day).
class DailyRetentionGate {
  DailyRetentionGate({required this.retentionSweep});

  final RetentionSweepService retentionSweep;

  /// shared_preferences key for the last-swept timestamp (unix sec).
  static const _kLastSweptAtKey = 'retention_last_swept_at_utc_sec';
  static const _sweepIntervalHours = 24;

  /// Evaluates the 24h gate and, if elapsed, runs the sweep and records
  /// the new timestamp. Callers should invoke this AFTER a sync — the
  /// aggregator inside the sync may have just created new daily_metrics
  /// rows, and the sweep must not clip rows the same run just wrote.
  Future<RetentionGateOutcome> maybeSweep() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSec = prefs.getInt(_kLastSweptAtKey);
    final now = DateTime.now().toUtc();
    final nowSec = now.millisecondsSinceEpoch ~/ 1000;

    if (lastSec != null) {
      final lastRunAt =
          DateTime.fromMillisecondsSinceEpoch(lastSec * 1000, isUtc: true);
      final elapsed = now.difference(lastRunAt);
      if (elapsed < const Duration(hours: _sweepIntervalHours)) {
        final hoursAgo = elapsed.inHours;
        final humanAgo = hoursAgo < 1
            ? '${elapsed.inMinutes}m ago'
            : '${hoursAgo}h ago';
        return RetentionGateOutcome(skipReason: 'last ran $humanAgo');
      }
    }

    final retention = await retentionSweep.sweepAll(now: now);
    await prefs.setInt(_kLastSweptAtKey, nowSec);
    return RetentionGateOutcome(result: retention);
  }
}

final dailyRetentionGateProvider = Provider<DailyRetentionGate>((ref) {
  return DailyRetentionGate(
    retentionSweep: ref.watch(retentionSweepServiceProvider),
  );
});
