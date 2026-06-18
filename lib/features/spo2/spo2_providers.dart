import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';

/// All SpO2 samples whose `capturedAt` falls inside the given local
/// date. Used by the Day tab on the detail screen so the chart shows
/// every reading (overnight slot + any manual measurements) for the
/// chosen day.
final spo2SamplesForDateProvider =
    StreamProvider.family<List<Spo2Sample>, DateTime>((ref, localDate) {
  final repo = ref.watch(spo2RepositoryProvider);
  final dayStart =
      DateTime(localDate.year, localDate.month, localDate.day).toUtc();
  final dayEnd = dayStart.add(const Duration(days: 1));
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: dayStart,
    to: dayEnd,
  );
});

/// daily_metrics row for the given local date — exposes the
/// `spo2OvernightAvg` / `spo2OvernightMin` rollups so the Day view can
/// surface them as standalone metric tiles even when the per-sample
/// stream is sparse.
final spo2DailyMetricsForDateProvider =
    StreamProvider.family<DailyMetrics?, DateTime>((ref, localDate) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(localDate.year, localDate.month, localDate.day),
  );
});

/// Inclusive local-date range request — used by Week + Month tabs.
class Spo2DateRange {
  const Spo2DateRange({required this.fromDate, required this.toDate});

  /// Inclusive local-day start (midnight local).
  final DateTime fromDate;

  /// Inclusive local-day end (midnight of last day; the provider extends
  /// to next-day-midnight so the last day is fully covered).
  final DateTime toDate;

  @override
  bool operator ==(Object other) =>
      other is Spo2DateRange &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(fromDate, toDate);
}

/// daily_metrics rows for a Week/Month view — each row carries the
/// overnight SpO2 rollups for one day. Sparse: days without an
/// overnight measurement simply aren't returned.
final spo2DailyMetricsInRangeProvider =
    FutureProvider.family<List<DailyMetrics>, Spo2DateRange>(
        (ref, range) async {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.getInRange(
    userId: ActiveSession.defaultUserId,
    fromDate: range.fromDate,
    toDate: range.toDate,
  );
});
