import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// Irregular-heartbeat notification (one of Ryan's four MVP alerts).
///
/// Sensor-agnostic: reads the rhythm metrics that `PpgAnalysisService` writes
/// into `daily_metrics` on quality-gate-PASSED captures only —
/// `rrIrregularityPct` (gap-robust R-R coefficient of variation) and
/// `ectopicBeatPct` (fraction of beats outside the moving-median band).
///
/// Deliberately hard to trigger — Ryan's hard requirement is no false alarms,
/// and we learned on hardware that a single bursty-BLE capture can look
/// irregular from missed beats alone. So this fires only on a SUSTAINED
/// pattern: a capture must clear BOTH thresholds to "flag" a day, and we need
/// at least [minFlaggedDays] flagged days inside the trailing [lookback]
/// window, with at least one of them recent ([recencyWindow]). Both metrics
/// are required to be elevated together — high irregularity scatter AND a
/// high off-median beat fraction — which artifact alone doesn't produce once
/// the gap-robust CoV strips BLE drops.
///
/// Regulatory framing: this is a wellness *observation*, never a diagnosis.
/// No "AFib" / "atrial fibrillation" / arrhythmia-diagnosis language in any
/// user-facing copy.
class IrregularRhythmRule implements AlertRule {
  IrregularRhythmRule({
    required this.dailyRepo,
    this.lookback = const Duration(days: 14),
    this.recencyWindow = const Duration(days: 3),
    this.minCovPct = 20.0,
    this.minEctopicPct = 30.0,
    this.minFlaggedDays = 3,
    this.minDataDays = 4,
  });

  final DailyMetricsRepository dailyRepo;

  /// How far back to look for the pattern.
  final Duration lookback;

  /// At least one flagged day must fall within this window of now, so a
  /// resolved-and-gone pattern doesn't keep firing.
  final Duration recencyWindow;

  /// A day "flags" only when its gap-robust R-R CoV is at least this. Normal
  /// sinus rhythm sits ~5-12%; this is set well above that ceiling.
  final double minCovPct;

  /// …and its off-median beat fraction is at least this. Normal ~5-15%.
  final double minEctopicPct;

  /// Minimum flagged days in the window before we'll fire.
  final int minFlaggedDays;

  /// Minimum assessed (rhythm-bearing) days before we'll evaluate at all —
  /// guards against firing on a thin history.
  final int minDataDays;

  @override
  String get type => 'irregular_rhythm';

  @override
  Duration get minInterval => const Duration(days: 7);

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    final to = ctx.now;
    final from = to.subtract(lookback);
    final rows = await dailyRepo.getInRange(
      userId: ctx.userId,
      fromDate: from,
      toDate: to,
    );

    // Only days that actually carry a rhythm assessment (gate-passed capture).
    final assessed = [
      for (final r in rows)
        if (r.rrIrregularityPct != null && r.ectopicBeatPct != null) r
    ];
    if (assessed.length < minDataDays) return null;

    final flagged = [
      for (final r in assessed)
        if (r.rrIrregularityPct! >= minCovPct &&
            r.ectopicBeatPct! >= minEctopicPct)
          r
    ];
    if (flagged.length < minFlaggedDays) return null;

    // Require the pattern to be current — at least one flagged day recently.
    final recentCutoff = to.subtract(recencyWindow);
    final hasRecent = flagged.any((r) => !r.localDate.isBefore(recentCutoff));
    if (!hasRecent) return null;

    return AlertCandidate(
      dedupeKey: 'irregular_rhythm-${_dateKey(to)}',
      title: 'Irregular rhythm noticed',
      body: 'Several recent readings showed an irregular heart-rhythm '
          'pattern. This isn’t a diagnosis — if it continues or you feel '
          'unwell, consider checking with a healthcare professional.',
      payload: {
        'flaggedDays': flagged.length,
        'assessedDays': assessed.length,
        'lookbackDays': lookback.inDays,
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final irregularRhythmRuleProvider = Provider<IrregularRhythmRule>((ref) {
  return IrregularRhythmRule(
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});
