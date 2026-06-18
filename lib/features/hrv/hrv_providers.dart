import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';

/// Range request — used by HRV detail screen's Day / Week / Month tabs.
/// Mirrors `HrRange` / `SleepRange` so call sites stay consistent across
/// detail screens.
class HrvRange {
  const HrvRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is HrvRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Stream of HRV samples within an arbitrary UTC range. Used by the Day
/// tab so the chart updates as soon as a fresh band sync persists new
/// rolling-buffer slots.
final hrvSamplesInRangeProvider =
    StreamProvider.family<List<HrvSample>, HrvRange>((ref, range) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
  );
});

/// One-shot HRV samples for a range. Used by Week / Month views — the
/// user explicitly navigates between weeks/months and we re-sync on each
/// shift, so streaming isn't required.
final hrvSamplesInRangeOnceProvider =
    FutureProvider.family<List<HrvSample>, HrvRange>((ref, range) async {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo.getInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
  );
});
