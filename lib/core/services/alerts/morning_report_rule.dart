import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/services/notification_service.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// Morning "your metrics are ready" notification — Ryan's retention push made
/// concrete: once the overnight data has synced and scored, tell the user so
/// they open the app and see last night's results.
///
/// Fires only when there is genuinely something to show:
///  * local time is inside the window ([morningStartHour], [morningEndHour])
///    — an evening first sync stays silent,
///  * TODAY's Recovery score exists (i.e. last night synced + scored; the
///    trailing-day recompute upgrades it later, the push just opens the door),
///  * the wake-day rollup exists for the sleep line.
///
/// The window ends at 16:00, not noon: today's Recovery score can only exist
/// AFTER the sleep ends and syncs, and real users sleep late — verified
/// 2026-07-07, a 03:37–12:52 sleeper's score lands ~13:00, which a 12:00 cap
/// silenced *every single day* (the push could structurally never fire for
/// them). 16:00 still reads as "your morning report" for any plausible wake
/// time while keeping dinner-time pushes impossible.
///
/// One per day via minInterval ≈ 20 h (a second same-day sync can't re-fire).
class MorningReportRule implements AlertRule {
  MorningReportRule({
    required this.scoreRepo,
    required this.dailyRepo,
    this.morningStartHour = 5,
    this.morningEndHour = 16,
  });

  final ScoreRepository scoreRepo;
  final DailyMetricsRepository dailyRepo;

  /// Local-time window the push may fire in: [start, end).
  final int morningStartHour;
  final int morningEndHour;

  @override
  String get type => 'morning_report';

  @override
  Duration get minInterval => const Duration(hours: 20);

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final localNow = ctx.now.toLocal();
    if (localNow.hour < morningStartHour || localNow.hour >= morningEndHour) {
      return null;
    }
    final today = DateTime(localNow.year, localNow.month, localNow.day);

    // Today's Recovery — getCurrent returns the latest ON OR BEFORE today, so
    // require it to actually be today's (yesterday's score ≠ fresh morning).
    final recovery = await scoreRepo.getCurrent(
      userId: ctx.userId,
      scoreType: ScoreType.recovery,
      forDate: today,
    );
    if (recovery == null) return null;
    final d = recovery.computedForDate;
    if (DateTime(d.year, d.month, d.day) != today) return null;

    final metrics = await dailyRepo.getForDay(
      userId: ctx.userId,
      localDate: today,
    );

    final parts = <String>[
      'Recovery ${recovery.score.round()}'
          '${recovery.label != null ? " — ${recovery.label}" : ""}',
    ];
    final sleepMin = metrics?.sleepTotalMin;
    if (sleepMin != null && sleepMin > 0) {
      parts.add('Sleep ${sleepMin ~/ 60}h ${sleepMin % 60}m');
    }
    final rhr = metrics?.restingHrBpm;
    if (rhr != null) parts.add('Resting HR $rhr bpm');

    return AlertCandidate(
      dedupeKey: 'morning_report-${_dateKey(today)}',
      title: 'Your morning metrics are ready',
      body: parts.join(' · '),
      channel: AlertChannel.retention,
      payload: {
        'recovery': recovery.score,
        'sleepTotalMin': sleepMin,
        'restingHrBpm': rhr,
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final morningReportRuleProvider = Provider<MorningReportRule>((ref) {
  return MorningReportRule(
    scoreRepo: ref.watch(scoreRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});
