import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';

/// All BP readings whose `capturedAt` falls inside the given local date.
/// Feeds the Day tab's hourly systolic/diastolic trend — includes the band's
/// autonomous hourly buffer (`bandScheduled`), manual "Measure Now" readings,
/// and cuff entries. Mirrors `spo2SamplesForDateProvider`.
final bpReadingsForDateProvider =
    StreamProvider.family<List<BpReading>, DateTime>((ref, localDate) {
  final repo = ref.watch(bpRepositoryProvider);
  final dayStart =
      DateTime(localDate.year, localDate.month, localDate.day).toUtc();
  final dayEnd = dayStart.add(const Duration(days: 1));
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: dayStart,
    to: dayEnd,
  );
});

/// Inclusive local-date range request — used by the Week + Month tabs.
class BpDateRange {
  const BpDateRange({required this.fromDate, required this.toDate});

  /// Inclusive local-day start (midnight local).
  final DateTime fromDate;

  /// Inclusive local-day end (midnight of last day; the provider extends to
  /// next-day-midnight so the last day is fully covered).
  final DateTime toDate;

  @override
  bool operator ==(Object other) =>
      other is BpDateRange &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(fromDate, toDate);
}

/// All BP readings across a Week/Month range. The view groups them by local
/// day and shows a daily median systolic/diastolic — richer than the
/// sleep-window `daily_metrics` value because it covers the whole day.
final bpReadingsInRangeProvider =
    StreamProvider.family<List<BpReading>, BpDateRange>((ref, range) {
  final repo = ref.watch(bpRepositoryProvider);
  final from = DateTime(
    range.fromDate.year,
    range.fromDate.month,
    range.fromDate.day,
  ).toUtc();
  final to = DateTime(
    range.toDate.year,
    range.toDate.month,
    range.toDate.day,
  ).toUtc().add(const Duration(days: 1));
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: from,
    to: to,
  );
});
