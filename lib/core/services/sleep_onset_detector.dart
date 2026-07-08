import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';

/// Live "is the user asleep right now?" estimate for the periodic tick.
///
/// The H59 offers NO real-time sleep event — its sleep classification is
/// retrospective (served after wake, next-day for HRV). But Ryan's 2026-06-23
/// direction is explicit: *"when sleep is triggered, we trigger these things
/// to run"* — the nightly BP measurement and the resting PPG (respiratory)
/// capture belong INSIDE sleep, not on a wall-clock guess. So this detector
/// approximates sleep onset from signals the tick already syncs:
///
///  * local time inside the night span ([nightStartHour]–[nightEndHour]) —
///    generous on the morning side because real users (2026-07-07: verified
///    sleep 03:37–12:52) sleep far later than the classic 23:00–07:00,
///  * recent average HR within [sleepMarginBpm] of the resting baseline —
///    NOTE the baseline is the overnight *minimum*, so real sleep hovers
///    well above it (observed 70–78 vs rest=60 on 2026-07-08),
///  * zero steps across the window — any walk is proof of awake.
///
/// Conservative by design: no fresh HR (band disconnected, gap night) or no
/// resting baseline yet → NOT asleep. A false "asleep" costs a once-per-night
/// BP attempt on an awake reading; a false "awake" merely defers to a later
/// tick — so every ambiguous input resolves to awake.
class SleepOnsetDetector {
  SleepOnsetDetector({
    required this.hrRepo,
    required this.stepRepo,
    required this.dailyRepo,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HrRepository hrRepo;
  final StepBucketRepository stepRepo;
  final DailyMetricsRepository dailyRepo;
  final DateTime Function() _now;

  /// Night span in local hours: `[nightStartHour, 24) ∪ [0, nightEndHour)`.
  /// 21:00 admits early sleepers; 11:00 keeps a 03:37→12:52 sleeper covered
  /// for most of their night. Outside this span we never claim sleep
  /// (daytime naps are out of scope for v1).
  static const nightStartHour = 21;
  static const nightEndHour = 11;

  /// Margin above the resting baseline that still counts as sleeping HR.
  ///
  /// 2026-07-08 on-device correction (crumbs, first full night): the resting
  /// baseline is the overnight MINIMUM (lowest sustained HR), but HR at the
  /// overnight ticks read 70–78 vs rest=60 — real sleep sits 10–18 bpm above
  /// that floor across light/REM cycles. The original +8 margin (threshold
  /// 68) judged every sleeping tick "awake", so nightly BP never fired all
  /// night. +20 (threshold 80 for a rest-60 user) admits the whole observed
  /// sleeping range; the zero-steps + night-span gates still exclude real
  /// activity, and the residual false-positive ("lying quietly in bed,
  /// pre-sleep") yields a resting BP reading — acceptable for a wellness
  /// estimate.
  static const sleepMarginBpm = 20.0;

  /// Look-back for both HR and steps. Long enough that a single spurious
  /// calm reading can't flip the verdict; short enough to catch sleep onset
  /// within ~1-2 ticks.
  static const window = Duration(minutes: 45);

  /// Mirrors [ScheduledPpgCaptureService._defaultRestingBpm]: usable ceiling
  /// until a personal baseline is banked.
  static const defaultRestingBpm = 70.0;

  /// Pure verdict — unit-testable without repos. All the I/O-fetched inputs
  /// come in as plain values.
  static bool judge({
    required int localHour,
    required double? recentAvgHr,
    required double restingHr,
    required int recentSteps,
  }) {
    if (!inNightSpan(localHour)) return false;
    if (recentAvgHr == null) return false; // no fresh HR — can't confirm
    if (recentSteps > 0) return false; // walked within the window — awake
    return recentAvgHr <= restingHr + sleepMarginBpm;
  }

  static bool inNightSpan(int localHour) =>
      localHour >= nightStartHour || localHour < nightEndHour;

  /// Fetch the live inputs and run [judge]. Never throws — any repo error
  /// resolves to awake (the conservative answer).
  Future<bool> isProbablyAsleep({required String userId}) async {
    try {
      final now = _now();
      if (!inNightSpan(now.hour)) return false;

      final nowUtc = now.toUtc();
      final recentAvgHr = await hrRepo.averageInRange(
        userId: userId,
        from: nowUtc.subtract(window),
        to: nowUtc,
      );

      // Steps across the window. The window can cross midnight, and step
      // buckets are keyed by local day — query both days it touches.
      // (Mirrors ActivityDetectorService's bucket comparison frame.)
      final windowStart = now.subtract(window);
      var recentSteps = 0;
      final days = <DateTime>{
        DateTime(windowStart.year, windowStart.month, windowStart.day),
        DateTime(now.year, now.month, now.day),
      };
      for (final day in days) {
        final buckets = await stepRepo.getForDay(
          userId: userId,
          localDate: day,
          tzOffsetMin: now.timeZoneOffset.inMinutes,
        );
        recentSteps += buckets
            .where((b) => !b.bucketStartAt.isBefore(windowStart))
            .fold<int>(0, (sum, b) => sum + b.steps);
      }

      final restingHr = await _restingReferenceBpm(userId, now);
      final asleep = judge(
        localHour: now.hour,
        recentAvgHr: recentAvgHr,
        restingHr: restingHr,
        recentSteps: recentSteps,
      );
      Breadcrumbs.log(
        'sleep-onset: ${asleep ? 'ASLEEP' : 'awake'} '
        '(hr=${recentAvgHr?.toStringAsFixed(0) ?? '--'} '
        'rest=${restingHr.toStringAsFixed(0)}+$sleepMarginBpm '
        'steps=$recentSteps h=${now.hour})',
      );
      return asleep;
    } catch (e) {
      Breadcrumbs.log('sleep-onset: error → awake ($e)');
      return false;
    }
  }

  /// Most recent banked resting HR within 14 days (same walk-back as the
  /// PPG rest gate), else [defaultRestingBpm].
  Future<double> _restingReferenceBpm(String userId, DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: today.subtract(const Duration(days: 14)),
      toDate: today,
    );
    for (final m in rows.reversed) {
      final r = m.restingHrBpm;
      if (r != null && r > 0) return r.toDouble();
    }
    return defaultRestingBpm;
  }
}

final sleepOnsetDetectorProvider = Provider<SleepOnsetDetector>((ref) {
  return SleepOnsetDetector(
    hrRepo: ref.watch(hrRepositoryProvider),
    stepRepo: ref.watch(stepBucketRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
  );
});
