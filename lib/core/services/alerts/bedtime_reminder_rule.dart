import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';

/// Past-midnight "time to wind down" nudge (user request, 2026-07-08 — a
/// 03:00–04:00 sleeper who wants a prompt toward an earlier bedtime).
///
/// Fires on the first tick inside [windowStartHour]–[windowEndHour) local
/// when the wearer is demonstrably STILL AWAKE. "Demonstrably" is the key
/// safety property — this must never buzz a phone next to someone already
/// asleep, so it requires positive evidence on both sides:
///
///  * fresh HR in the last 45 min (ring on wrist and reporting — a charging
///    or disconnected ring yields silence, not a guess), AND
///  * the sleep-onset detector judging AWAKE from that same data.
///
/// Once per night via minInterval ≈ 20 h (same latch pattern as the morning
/// report). Wellness framing only — encouragement, not a health claim.
class BedtimeReminderRule implements AlertRule {
  BedtimeReminderRule({
    required this.sleepOnset,
    required this.hrRepo,
    this.windowStartHour = 0,
    this.windowEndHour = 4,
  });

  final SleepOnsetDetector sleepOnset;
  final HrRepository hrRepo;

  /// Local window `[windowStartHour, windowEndHour)` in which the nudge may
  /// fire. 00:00–04:00 covers the target habit (asleep before midnight)
  /// while ending before genuinely-asleep hours dominate.
  final int windowStartHour;
  final int windowEndHour;

  /// Mirrors [SleepOnsetDetector.window]: HR older than this can't prove
  /// the wearer is awake right now.
  static const freshHrWindow = Duration(minutes: 45);

  @override
  String get type => 'bedtime_reminder';

  @override
  Duration get minInterval => const Duration(hours: 20);

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final localNow = ctx.now.toLocal();
    if (localNow.hour < windowStartHour || localNow.hour >= windowEndHour) {
      return null;
    }

    // Positive evidence the ring is on and reporting — silence otherwise.
    final recentHr = await hrRepo.averageInRange(
      userId: ctx.userId,
      from: ctx.now.toUtc().subtract(freshHrWindow),
      to: ctx.now.toUtc(),
    );
    if (recentHr == null) return null;

    // Already asleep (or ambiguous) → never fire.
    final asleep = await sleepOnset.isProbablyAsleep(userId: ctx.userId);
    if (asleep) return null;

    final dateKey = '${localNow.year}-'
        '${localNow.month.toString().padLeft(2, '0')}-'
        '${localNow.day.toString().padLeft(2, '0')}';
    return AlertCandidate(
      dedupeKey: 'bedtime-$dateKey',
      title: 'Time to wind down',
      body: "It's past midnight. Heading to bed now supports overnight "
          'recovery and tomorrow’s readiness — your body does its '
          'best repair work during consistent, earlier sleep.',
      channel: AlertChannel.retention,
      payload: {'localHour': localNow.hour, 'recentHr': recentHr},
    );
  }
}

final bedtimeReminderRuleProvider = Provider<BedtimeReminderRule>((ref) {
  return BedtimeReminderRule(
    sleepOnset: ref.watch(sleepOnsetDetectorProvider),
    hrRepo: ref.watch(hrRepositoryProvider),
  );
});
