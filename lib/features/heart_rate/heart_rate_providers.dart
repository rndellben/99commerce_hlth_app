import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';

/// Range request — used by HR detail screen's Day / Week / Month tabs.
/// Mirrors `SleepRange` from sleep_providers.dart so the call sites look
/// consistent across detail screens.
class HrRange {
  const HrRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is HrRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Stream of HR samples within an arbitrary UTC range. Used by the Day
/// tab (24h around the anchor) so the chart updates the moment a fresh
/// band sync lands new samples.
final hrSamplesInRangeProvider =
    StreamProvider.family<List<HrSample>, HrRange>((ref, range) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
  );
});

/// One-shot HR samples for a range. Used by Week / Month views where the
/// chart bucket aggregation (daily-avg) happens in the widget — a
/// stream isn't needed because the user explicitly navigates between
/// weeks/months and we re-sync on each shift.
final hrSamplesInRangeOnceProvider =
    FutureProvider.family<List<HrSample>, HrRange>((ref, range) async {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.getInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
  );
});

/// Resting HR samples for a range. The Day tab shows "Resting HR" as a
/// metric tile — we use this to compute the per-day RHR (avg of resting
/// samples) for any historical day, not just today.
final restingHrInRangeProvider =
    FutureProvider.family<List<HrSample>, HrRange>((ref, range) async {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.getRestingInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
  );
});
