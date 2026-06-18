import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/step_bucket.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';

/// `daily_metrics` row for a specific local date. Streams so the Activity
/// detail screen updates as soon as `syncSteps` lands a fresh aggregate.
final dailyMetricsForDateProvider =
    StreamProvider.family<DailyMetrics?, DateTime>((ref, localDate) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(localDate.year, localDate.month, localDate.day),
  );
});

/// Range request — used by the Week / Month tabs.
class ActivityRange {
  const ActivityRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is ActivityRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Stream of `daily_metrics` rows whose `local_date` falls inside the
/// given inclusive window. Week tab passes Mon-Sun; Month tab passes
/// 1st to last day of month.
final dailyMetricsInRangeProvider =
    StreamProvider.family<List<DailyMetrics>, ActivityRange>((ref, range) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    fromDate: range.from,
    toDate: range.to,
  );
});

/// 15-min step buckets for a specific local date. Used by the Day view's
/// sparkline.
///
/// `tzOffsetMin` is resolved from `DateTime.now()` — for historical days
/// in a DST-shifting locale this can be off by 60 min at most, which is
/// well within a 15-min-bucket day window. Good enough for V1.
final stepBucketsForDateProvider =
    StreamProvider.family<List<StepBucket>, DateTime>((ref, localDate) {
  final repo = ref.watch(stepBucketRepositoryProvider);
  final tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(localDate.year, localDate.month, localDate.day),
    tzOffsetMin: tzOffsetMin,
  );
});
