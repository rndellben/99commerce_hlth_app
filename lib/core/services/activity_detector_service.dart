import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/exercise_session_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Watches the always-on signals (scheduled HR + 15-min step buckets) for a
/// sustained activity bout and, when one is seen with no workout active,
/// surfaces a one-time "start a workout?" prompt so the band records it (the
/// clean input for the VO2 max estimate).
///
/// This is the battery-safe alternative to continuous accelerometer detection:
/// the H59 only streams accel during heavy raw-PPG capture, so instead we read
/// data the periodic sync already pulled. Debounced via shared_preferences so
/// it never nags (≥ [_minHoursBetweenPrompts] apart, ≤ [_maxPromptsPerDay]).
class ActivityDetectorService {
  ActivityDetectorService({
    required this.hrRepo,
    required this.stepRepo,
    required this.userRepo,
    required this.exerciseRepo,
    required this.dailyRepo,
    DateTime Function()? now,
    Future<SharedPreferences> Function()? prefs,
  })  : _now = now ?? DateTime.now,
        _prefs = prefs ?? SharedPreferences.getInstance;

  final HrRepository hrRepo;
  final StepBucketRepository stepRepo;
  final UserRepository userRepo;
  final ExerciseSessionRepository exerciseRepo;
  final DailyMetricsRepository dailyRepo;
  final DateTime Function() _now;
  final Future<SharedPreferences> Function() _prefs;

  // Detection window + thresholds.
  static const _windowMinutes = 30;
  static const _minHrSamples = 5;
  static const _hrrFraction = 0.5; // HR > resting + 50% HRR (spec STEP 1)
  static const _minFractionElevated = 0.6;
  static const _minRecentSteps = 1500; // sustained cadence over the window

  // Debounce.
  static const _minHoursBetweenPrompts = 3;
  static const _maxPromptsPerDay = 2;
  static const _kLastPromptKey = 'vo2_activity_last_prompt_utc_sec';
  static const _kPromptDayKey = 'vo2_activity_prompt_day';
  static const _kPromptDayCountKey = 'vo2_activity_prompt_day_count';

  /// Returns the detection time when a fresh prompt should be shown (and
  /// records it for debounce), or null otherwise. Never throws on bad data —
  /// returns null instead, so callers can fire-and-forget.
  Future<DateTime?> evaluate({required String userId}) async {
    final now = _now();
    final windowStart = now.subtract(const Duration(minutes: _windowMinutes));

    // Debounce gate.
    final prefs = await _prefs();
    final lastSec = prefs.getInt(_kLastPromptKey);
    if (lastSec != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastSec * 1000, isUtc: true);
      if (now.toUtc().difference(last).inHours < _minHoursBetweenPrompts) {
        return null;
      }
    }
    final today = _dayKey(now);
    if (prefs.getString(_kPromptDayKey) == today &&
        (prefs.getInt(_kPromptDayCountKey) ?? 0) >= _maxPromptsPerDay) {
      return null;
    }

    // No active / just-finished workout. (BleService exposes no live sport
    // state, so gate on recent sessions instead — plan-approved fallback.)
    final recent = await exerciseRepo.getInRange(
      userId: userId,
      from: now.subtract(const Duration(hours: 2)),
      to: now,
    );
    for (final s in recent) {
      final ended = s.endedAt;
      final active = ended == null ||
          ended.isAfter(windowStart) ||
          s.startedAt.isAfter(windowStart);
      if (active) return null;
    }

    // Need age + resting HR to compute the elevation threshold. Resting HR
    // falls back to today's daily_metrics (profile baseline is rarely set),
    // mirroring Vo2MaxService.
    final profile = await userRepo.getProfile(userId);
    final dob = profile?.dateOfBirth;
    final restingHr = profile?.restingHrBaseline ??
        (await dailyRepo.getForDay(userId: userId, localDate: now))
            ?.restingHrBpm;
    if (dob == null || restingHr == null) return null;
    final age = _ageAt(dob, now);
    final hrMax = 220 - age;
    final hrReserve = hrMax - restingHr;
    if (hrReserve <= 0) return null;
    final threshold = restingHr + _hrrFraction * hrReserve;

    // Sustained HR elevation across the window.
    final hr = await hrRepo.getInRange(userId: userId, from: windowStart, to: now);
    if (hr.length < _minHrSamples) return null;
    final elevated = hr.where((s) => s.bpm >= threshold).length;
    if (elevated / hr.length < _minFractionElevated) return null;

    // Elevated cadence: steps logged across the window's 15-min buckets.
    final buckets = await stepRepo.getForDay(
      userId: userId,
      localDate: now,
      tzOffsetMin: now.timeZoneOffset.inMinutes,
    );
    final recentSteps = buckets
        .where((b) => !b.bucketStartAt.isBefore(windowStart))
        .fold<int>(0, (sum, b) => sum + b.steps);
    if (recentSteps < _minRecentSteps) return null;

    // Candidate confirmed — record for debounce and signal.
    final isNewDay = prefs.getString(_kPromptDayKey) != today;
    await prefs.setInt(
        _kLastPromptKey, now.toUtc().millisecondsSinceEpoch ~/ 1000);
    await prefs.setString(_kPromptDayKey, today);
    await prefs.setInt(_kPromptDayCountKey,
        isNewDay ? 1 : (prefs.getInt(_kPromptDayCountKey) ?? 0) + 1);
    return now;
  }

  String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

  int _ageAt(DateTime dob, DateTime at) {
    var age = at.year - dob.year;
    final had = (at.month > dob.month) ||
        (at.month == dob.month && at.day >= dob.day);
    if (!had) age -= 1;
    return age;
  }
}

final activityDetectorServiceProvider = Provider<ActivityDetectorService>((ref) {
  return ActivityDetectorService(
    hrRepo: ref.watch(hrRepositoryProvider),
    stepRepo: ref.watch(stepBucketRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
    exerciseRepo: ref.watch(exerciseSessionRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});

/// Holds the timestamp of a detected-but-unacknowledged activity bout. The
/// Activity/Home banner watches this; null means "nothing pending".
class PendingWorkoutPrompt extends StateNotifier<DateTime?> {
  PendingWorkoutPrompt() : super(null);
  void flag(DateTime at) => state = at;
  void clear() => state = null;
}

final pendingWorkoutPromptProvider =
    StateNotifierProvider<PendingWorkoutPrompt, DateTime?>((ref) {
  return PendingWorkoutPrompt();
});
