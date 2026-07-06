import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/processing/bp_formula.dart';
import 'package:hlth_app/core/repositories/bp_calibration_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';

/// Hypertension-risk notification (one of Ryan's four MVP alerts, June 17
/// call): fire when today's blood-pressure rollup is well above the user's
/// OWN recent average AND above the population-normal range.
///
/// Two-part condition, per the call ("above the population average, and 15
/// points above their last 7 days"):
///  1. **Relative** — today's systolic ≥ [minDeltaSbp] over the mean of the
///     prior [lookbackDays]. Computed on RAW rollups: the cuff calibration is
///     the same offset on every reading, so it cancels in the delta.
///  2. **Absolute** — today's CALIBRATED systolic ≥ [minAbsoluteSbp]. The H59
///     band value is an HR-derived estimate; absolute claims are meaningless
///     without a cuff anchor, so **no active calibration → never fires**
///     (Ryan's hard no-false-alarm requirement).
///
/// Regulatory framing: wellness observation, not a diagnosis — copy points to
/// a validated cuff, never says "hypertension diagnosis".
class HypertensionRiskRule implements AlertRule {
  HypertensionRiskRule({
    required this.dailyRepo,
    required this.calibrationRepo,
    this.lookbackDays = 7,
    this.minPriorDays = 4,
    this.minDeltaSbp = 15.0,
    this.minAbsoluteSbp = 130,
  });

  final DailyMetricsRepository dailyRepo;
  final BpCalibrationRepository calibrationRepo;

  /// Days of history the average is computed over (excluding today).
  final int lookbackDays;

  /// Minimum prior days that must carry a BP rollup before we'll compare —
  /// an average of 1–2 readings is noise, not a baseline.
  final int minPriorDays;

  /// Today must exceed the prior average by at least this many mmHg systolic.
  final double minDeltaSbp;

  /// …and today's calibrated systolic must be at least this (population
  /// guard, ~stage-1 threshold).
  final int minAbsoluteSbp;

  @override
  String get type => 'hypertension_risk';

  @override
  Duration get minInterval => const Duration(days: 7);

  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async {
    // Absolute gate first: no cuff anchor → the band's absolute BP can't be
    // trusted → fire nothing, ever.
    final cal = await calibrationRepo.getActiveForUser(ctx.userId);
    if (cal == null) return null;

    final localNow = ctx.now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final rows = await dailyRepo.getInRange(
      userId: ctx.userId,
      fromDate: today.subtract(Duration(days: lookbackDays)),
      toDate: today,
    );

    int? todaySbp;
    final priorSbp = <int>[];
    for (final r in rows) {
      final sbp = r.systolicMmhg;
      if (sbp == null) continue;
      final d = DateTime(r.localDate.year, r.localDate.month, r.localDate.day);
      if (d == today) {
        todaySbp = sbp;
      } else {
        priorSbp.add(sbp);
      }
    }
    if (todaySbp == null || priorSbp.length < minPriorDays) return null;

    // 1. Relative: raw delta vs own average (calibration offset cancels).
    final priorAvg = priorSbp.reduce((a, b) => a + b) / priorSbp.length;
    if (todaySbp - priorAvg < minDeltaSbp) return null;

    // 2. Absolute: calibrated today-value above the population guard. The
    // daily rollup carries no HR, so this takes the constant-offset branch.
    final calibrated = applyBpCalibration(
      rawSbp: todaySbp,
      rawDbp: 80, // dbp unused by the systolic guard
      hr: null,
      anchor: BpCalibrationAnchor(
        systolic: cal.cuffSystolic,
        diastolic: cal.cuffDiastolic,
        hrAtCalibration: 0, // ignored by the offset branch
      ),
    );
    if (calibrated.sbp < minAbsoluteSbp) return null;

    return AlertCandidate(
      dedupeKey: 'hypertension_risk-${_dateKey(today)}',
      title: 'Blood pressure running high',
      body: 'Your estimated blood pressure today is noticeably above your '
          'recent average. Band estimates aren’t a diagnosis — consider '
          'checking with a validated cuff, and talk to a healthcare '
          'professional if it stays elevated.',
      payload: {
        'todaySbp': todaySbp,
        'priorAvgSbp': priorAvg.round(),
        'priorDays': priorSbp.length,
        'calibratedSbp': calibrated.sbp,
      },
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final hypertensionRiskRuleProvider = Provider<HypertensionRiskRule>((ref) {
  return HypertensionRiskRule(
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    calibrationRepo: ref.watch(bpCalibrationRepositoryProvider),
  );
});
