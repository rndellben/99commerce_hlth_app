import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/app_activity_tracker.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/sleep_onset_detector.dart';

/// Past-midnight "time to wind down" nudge (user request, 2026-07-08 — a
/// 03:00–04:00 sleeper who wants a prompt toward an earlier bedtime).
///
/// Fires on the first tick inside [windowStartHour]–[windowEndHour) local
/// when the wearer is demonstrably STILL AWAKE. "Demonstrably" is the key
/// safety property — this must never buzz a phone next to someone already
/// asleep, so it fires only on **positive** wake evidence, strongest first:
///
///  1. **Phone interaction** — the app was foregrounded within
///     [phoneEvidenceWindow]. A sleeping person cannot resume an app, so
///     this is irrefutable and needs no ring corroboration. It is also the
///     ONLY signal that can reach the rule's actual target: someone lying
///     motionless in bed scrolling their phone, whose HR sits inside the
///     sleeping band (that user is invisible to ring data — see below).
///  2. **Recent walking** — ≥ [minAwakeSteps] steps in the last
///     [freshHrWindow] (sleepers don't walk; the floor filters the
///     handful of phantom steps sleep movement can register). Requires
///     fresh HR (ring on wrist) like all inferential evidence.
///  3. **Clearly-elevated HR** — 45-min average above the user's *banked*
///     resting baseline + [SleepOnsetDetector.sleepMarginBpm]. With no
///     banked baseline this path is unavailable (the detector's default-70
///     fallback would put the bar at 90 bpm — unreachable while seated, so
///     using it here just silently disabled the rule for new users).
///
/// Anything less is ambiguous — quiet wakefulness and sleep are
/// indistinguishable from ring data alone — and ambiguity resolves to
/// silence (Ryan's no-false-alarm requirement). The rule deliberately does
/// NOT consult [SleepOnsetDetector]: that classifier is tuned for the
/// nightly-BP capture, where over-claiming "asleep" is cheap; negating it
/// here suppressed every quiet-wakefulness night (root cause of the
/// 2026-07 "reminder never shows" report). Each evidence path above is
/// individually sufficient proof of wakefulness, so re-checking a
/// detector biased the other way could only re-introduce that bug.
///
/// Once per night via minInterval ≈ 20 h (same latch pattern as the morning
/// report). Wellness framing only — encouragement, not a health claim.
class BedtimeReminderRule implements AlertRule {
  BedtimeReminderRule({
    required this.hrRepo,
    required this.stepRepo,
    required this.dailyRepo,
    this.lastAppActiveAt = AppActivityTracker.lastAppActiveAt,
    this.phoneInUseNow,
    this.windowStartHour = 0,
    this.windowEndHour = 4,
  });

  final HrRepository hrRepo;
  final StepBucketRepository stepRepo;
  final DailyMetricsRepository dailyRepo;

  /// Injectable for tests; production reads [AppActivityTracker].
  final Future<DateTime?> Function() lastAppActiveAt;

  /// Live "is the phone unlocked and in use RIGHT NOW?" probe
  /// (BleService.isPhoneActive — Android only, false elsewhere). This is
  /// what lets the reminder fire while the user scrolls OTHER apps past
  /// midnight, without ever opening ours: an unlocked, interactive phone at
  /// tick time is user action, and a sleeping person's phone is locked.
  /// Known accepted edge: falling asleep mid-video with the phone unlocked
  /// can draw one nudge — judged acceptable against the reminder being
  /// structurally silent for its target persona (product call, 2026-07-15).
  final Future<bool> Function()? phoneInUseNow;

  /// Local window `[windowStartHour, windowEndHour)` in which the nudge may
  /// fire. 00:00–04:00 covers the target habit (asleep before midnight)
  /// while ending before genuinely-asleep hours dominate.
  final int windowStartHour;
  final int windowEndHour;

  /// Mirrors [SleepOnsetDetector.window]: HR older than this can't prove
  /// the wearer is awake right now.
  static const freshHrWindow = Duration(minutes: 45);

  /// How recent a foreground resume must be to count as "using the phone
  /// right now". 30 min spans the gap between 30-min sync ticks.
  static const phoneEvidenceWindow = Duration(minutes: 30);

  /// Step floor for the walking evidence. The H59 can register a few
  /// phantom steps from sleep movement; a couple dozen real steps cannot
  /// happen asleep.
  static const minAwakeSteps = 10;

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
    final nowUtc = ctx.now.toUtc();

    // ── Evidence 1: phone interaction (irrefutable, no ring needed) ──────
    // 1a: our app was foregrounded recently (works on both platforms).
    final appActiveAt = await lastAppActiveAt();
    var phoneActive = appActiveAt != null &&
        nowUtc.difference(appActiveAt.toUtc()) <= phoneEvidenceWindow;
    var evidenceLabel = 'phone';
    // 1b: the phone is unlocked and in use RIGHT NOW — any app counts
    // (Android-only probe). This is the path that reaches the target
    // persona scrolling another app at 1 a.m.
    if (!phoneActive && phoneInUseNow != null) {
      phoneActive = await phoneInUseNow!();
      evidenceLabel = 'phone-unlocked';
    }

    String? evidence;
    if (phoneActive) {
      evidence = evidenceLabel;
    } else {
      // Ring-inferred paths require the ring on-wrist and reporting —
      // a charging or disconnected ring yields silence, not a guess.
      final recentHr = await hrRepo.averageInRange(
        userId: ctx.userId,
        from: nowUtc.subtract(freshHrWindow),
        to: nowUtc,
      );
      if (recentHr == null) {
        _crumb(localNow, 'silent: no fresh HR, no phone evidence');
        return null;
      }

      // ── Evidence 2: recent walking ──────────────────────────────────
      final steps = await stepRepo.stepsInWindow(
        userId: ctx.userId,
        from: nowUtc.subtract(freshHrWindow),
        to: nowUtc,
      );
      if (steps >= minAwakeSteps) {
        evidence = 'steps=$steps';
      } else {
        // ── Evidence 3: HR clearly above the sleeping band ────────────
        final bankedRest = await _bankedRestingBpm(ctx.userId, localNow);
        if (bankedRest != null &&
            recentHr > bankedRest + SleepOnsetDetector.sleepMarginBpm) {
          evidence = 'hr=${recentHr.toStringAsFixed(0)}>'
              '${bankedRest.toStringAsFixed(0)}'
              '+${SleepOnsetDetector.sleepMarginBpm.toStringAsFixed(0)}';
        }
      }

      if (evidence == null) {
        _crumb(localNow, 'silent: ambiguous (still + calm HR)');
        return null;
      }
    }

    // ── Post-sleep guard ─────────────────────────────────────────────────
    // Waking up INSIDE the window (bathroom trip, interrupted night, very
    // early riser) produces the same evidence as never-went-to-bed: an
    // unlocked phone, steps, elevated HR. But "time to wind down" at someone
    // who already slept tonight is noise — so if tonight's synced data shows
    // a completed sleep-like stretch, stay silent.
    if (await _sleptTonight(ctx.userId, localNow, nowUtc)) {
      _crumb(localNow, 'silent: already slept tonight (evidence [$evidence])');
      return null;
    }

    _crumb(localNow, 'candidate: awake via [$evidence]');
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
      payload: {'localHour': localNow.hour, 'evidence': evidence},
    );
  }

  /// Minimum contiguous sleep-like span that counts as "already slept
  /// tonight". A quiet hour on the couch can look the same — but someone
  /// motionless for a full hour was at minimum winding down, and nudging
  /// them post-hoc is exactly the noise this guard exists to avoid.
  static const sleptStretch = Duration(minutes: 60);

  /// True when tonight's ALREADY-SYNCED data (since 21:00 yesterday — the
  /// night-span start) contains a contiguous [sleptStretch] where every HR
  /// sample sat inside the sleeping band (≤ banked rest + margin) AND zero
  /// steps were recorded. Conservative in the firing direction: sparse or
  /// missing data (band disconnected, <3 samples per candidate hour, no
  /// banked baseline) can never *suppress* — it just fails to prove sleep,
  /// leaving the fire decision to the positive-evidence paths above.
  Future<bool> _sleptTonight(
    String userId,
    DateTime localNow,
    DateTime nowUtc,
  ) async {
    final bankedRest = await _bankedRestingBpm(userId, localNow);
    if (bankedRest == null) return false; // can't judge the HR band
    final ceiling = bankedRest + SleepOnsetDetector.sleepMarginBpm;

    // Night span opened yesterday 21:00 local (window hours are 0-3, so
    // "today minus 3h" is always yesterday evening).
    final eveningStart =
        DateTime(localNow.year, localNow.month, localNow.day)
            .subtract(const Duration(hours: 3));

    final hrs = await hrRepo.getInRange(
      userId: userId,
      from: eveningStart,
      to: nowUtc,
    );
    if (hrs.length < 3) return false; // not enough data to claim sleep

    // Slide a 1h window in 15-min increments across the night.
    var windowStart = eveningStart;
    final lastStart = localNow.subtract(sleptStretch);
    while (!windowStart.isAfter(lastStart)) {
      final windowEnd = windowStart.add(sleptStretch);
      final inWin = hrs.where((s) =>
          !s.capturedAt.isBefore(windowStart.toUtc()) &&
          s.capturedAt.isBefore(windowEnd.toUtc()));
      if (inWin.length >= 3 && inWin.every((s) => s.bpm <= ceiling)) {
        final steps = await stepRepo.stepsInWindow(
          userId: userId,
          from: windowStart.toUtc(),
          to: windowEnd.toUtc(),
        );
        if (steps == 0) return true; // a full sleep-like hour exists
      }
      windowStart = windowStart.add(const Duration(minutes: 15));
    }
    return false;
  }

  /// Most recent *banked* resting HR within 14 days (same walk-back as
  /// [SleepOnsetDetector]), or null when none exists — this rule never
  /// substitutes a population default.
  Future<double?> _bankedRestingBpm(String userId, DateTime localNow) async {
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: today.subtract(const Duration(days: 14)),
      toDate: today,
    );
    for (final m in rows.reversed) {
      final r = m.restingHrBpm;
      if (r != null && r > 0) return r.toDouble();
    }
    return null;
  }

  /// Bounded trail (≤ ~8 ticks/night inside the window) so "why didn't it
  /// fire last night?" is answerable from the breadcrumb file.
  void _crumb(DateTime localNow, String msg) {
    Breadcrumbs.log('bedtime(h=${localNow.hour}): $msg');
  }
}

final bedtimeReminderRuleProvider = Provider<BedtimeReminderRule>((ref) {
  final ble = ref.watch(bleServiceProvider);
  return BedtimeReminderRule(
    hrRepo: ref.watch(hrRepositoryProvider),
    stepRepo: ref.watch(stepBucketRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    phoneInUseNow: ble.isPhoneActive,
  );
});
