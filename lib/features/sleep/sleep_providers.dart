import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';

/// Most-recent night sleep session for the active user. Streams so the
/// detail screen updates as soon as a fresh overnight sync lands.
final latestSleepSessionProvider = StreamProvider<SleepSession?>((ref) {
  final repo = ref.watch(sleepRepositoryProvider);
  return repo.watchMostRecentNight(ActiveSession.defaultUserId);
});

/// Epochs (hypnogram strip) for a specific session. One-shot read —
/// epochs are immutable once written, so no need to stream.
final sleepEpochsProvider =
    FutureProvider.family<List<SleepEpoch>, String>((ref, sessionId) async {
  final repo = ref.watch(sleepRepositoryProvider);
  return repo.getEpochsForSession(sessionId);
});

/// Sleep session whose wake (endedAt) lands on the given local date.
///
/// Used by the Sleep detail screen's Day view so the date picker drives
/// which session is shown. Window is `localDate 00:00` to `localDate
/// 23:59` — any night that ended during the chosen day matches.
final sleepSessionForDateProvider =
    FutureProvider.family<SleepSession?, DateTime>((ref, localDate) async {
  final repo = ref.watch(sleepRepositoryProvider);
  // Look at any session that *ends* on this date. Cast a wide net for
  // the `from` side (previous day 06:00 local) since sleep typically
  // crosses midnight; the `to` side is just end-of-day.
  final from = DateTime(localDate.year, localDate.month, localDate.day)
      .subtract(const Duration(hours: 18));
  final to = DateTime(localDate.year, localDate.month, localDate.day, 23, 59);
  final sessions = await repo.getInRange(
    userId: ActiveSession.defaultUserId,
    from: from.toUtc(),
    to: to.toUtc(),
    type: SleepSessionType.night,
  );
  if (sessions.isEmpty) return null;
  // Pick the session whose wake-day matches localDate, falling back to
  // the most-recently-ended.
  SleepSession? match;
  for (final s in sessions) {
    final wake = s.endedAt.toLocal();
    if (wake.year == localDate.year &&
        wake.month == localDate.month &&
        wake.day == localDate.day) {
      match = s;
    }
  }
  return match ?? sessions.last;
});

/// Range request — used by Week + Month tabs.
class SleepRange {
  const SleepRange({required this.from, required this.to});
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is SleepRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final sleepSessionsInRangeProvider =
    FutureProvider.family<List<SleepSession>, SleepRange>((ref, range) async {
  final repo = ref.watch(sleepRepositoryProvider);
  return repo.getInRange(
    userId: ActiveSession.defaultUserId,
    from: range.from,
    to: range.to,
    type: SleepSessionType.night,
  );
});
