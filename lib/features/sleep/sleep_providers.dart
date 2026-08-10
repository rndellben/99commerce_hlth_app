import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/sleep.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/nightly_record_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/services/alerts/breathing_disruption_rule.dart';

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

/// The night's derived vitals — resting HR, SpO2, HRV, BP measured over the
/// sleep window — keyed by the session's WAKE date. The DailyAggregator
/// attributes each night's rollup to the morning the user woke, so the
/// `daily_metrics` row for the wake date carries the "during sleep" values
/// (per Ryan's 2026-06-23 sleep-screen spec).
///
/// Streams (not a one-shot read) so the tiles update the moment a sync
/// re-aggregates the row. The aggregator fills the vitals across several
/// sync ticks — HR, HRV, SpO2 and BP can land in different passes — so a
/// cached one-shot read would freeze whatever subset existed when the screen
/// first opened (e.g. HRV present but resting HR not yet).
final sleepNightMetricsProvider =
    StreamProvider.family<DailyMetrics?, DateTime>((ref, wakeDate) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(wakeDate.year, wakeDate.month, wakeDate.day),
  );
});

/// STRICTLY sleep-window HRV for a session. Primary source: the
/// `nightly_records` row's `rmssdMedian` (the exact per-night median Cardio
/// Load banks). The Sleep screen's HRV tile reads THIS instead of
/// `daily_metrics.hrvRmssdMs`, because that rollup is also written by the
/// daytime PPG capture as a fallback — which let an awake capture's
/// (sometimes inflated) RMSSD masquerade as "measured during sleep"
/// (290 ms seen on-device 2026-07-07).
///
/// Fallback: the nightly record's median needs ≥5 RMSSD epochs
/// (`vascular_load.reduceSession`), so a short night — 3.7 h yields only 4
/// hourly band samples — stores null and the tile showed '--' even though
/// in-sleep HRV existed (2026-07-15). That threshold is a SCORING validity
/// gate, not a display rule: when the record has no median, take the median
/// directly over band HRV samples inside [startedAt, endedAt). Bounded by
/// the session window, so awake/daytime captures still can't leak in.
final sleepWindowHrvProvider =
    FutureProvider.family<double?, SleepSession>((ref, session) async {
  final wake = session.endedAt.toLocal();
  final record = await ref.watch(nightlyRecordRepositoryProvider).getForDate(
        userId: ActiveSession.defaultUserId,
        localDate: DateTime(wake.year, wake.month, wake.day),
      );
  final banked = record?.rmssdMedian;
  if (banked != null && banked.isFinite) return banked;

  final samples = await ref.watch(hrvRepositoryProvider).getInRange(
        userId: ActiveSession.defaultUserId,
        from: session.startedAt,
        to: session.endedAt,
      );
  final vals = samples
      .map((s) => s.rmssdMs)
      .where((v) => v.isFinite && v > 0)
      .toList()
    ..sort();
  // A 1-sample "median" is a coin flip; 2+ genuine in-sleep readings is an
  // honest, if coarse, night value.
  if (vals.length < 2) return null;
  final mid = vals.length ~/ 2;
  return vals.length.isOdd ? vals[mid] : (vals[mid - 1] + vals[mid]) / 2;
});

/// Overnight low-oxygen scan for one session — Ryan's June 17 "surfaced card
/// on the sleep dashboard" ask. Runs the SAME pure detection as
/// [BreathingDisruptionRule] (which drives the notification), so the card and
/// the push can never disagree. The card decides visibility from the result
/// (≥2 low hourly buckets with ≥4 buckets of coverage). Also pulls the
/// night's HR so the detector can add the bradycardia-tachycardia
/// corroboration signal.
final breathingRiskForSessionProvider =
    FutureProvider.family<BreathingDisruptionResult, SleepSession>(
        (ref, session) async {
  final spo2 = await ref.watch(spo2RepositoryProvider).getInRange(
        userId: ActiveSession.defaultUserId,
        from: session.startedAt,
        to: session.endedAt,
      );
  final hr = await ref.watch(hrRepositoryProvider).getInRange(
        userId: ActiveSession.defaultUserId,
        from: session.startedAt,
        to: session.endedAt,
      );
  return BreathingDisruptionRule.detect(spo2, hrSamples: hr);
});

/// One flagged night in the breathing-disruption trend.
class BreathingTrendNight {
  const BreathingTrendNight({required this.wakeDate, required this.result});
  final DateTime wakeDate;
  final BreathingDisruptionResult result;
}

/// Last [days] nights of breathing-disruption results (most recent first),
/// keeping only nights with enough SpO2 coverage to judge. Powers the
/// multi-night trend strip on the sleep card so a recurring pattern — the
/// thing that actually warrants attention (guide Layer 6) — is visible, not
/// just last night in isolation.
final breathingTrendProvider =
    FutureProvider.family<List<BreathingTrendNight>, int>((ref, days) async {
  final now = DateTime.now();
  final sessions = await ref.watch(sleepRepositoryProvider).getInRange(
        userId: ActiveSession.defaultUserId,
        from: now.subtract(Duration(days: days)),
        to: now,
        type: SleepSessionType.night,
      );
  final spo2Repo = ref.watch(spo2RepositoryProvider);
  final hrRepo = ref.watch(hrRepositoryProvider);
  final out = <BreathingTrendNight>[];
  for (final s in sessions) {
    final spo2 = await spo2Repo.getInRange(
      userId: ActiveSession.defaultUserId,
      from: s.startedAt,
      to: s.endedAt,
    );
    final hr = await hrRepo.getInRange(
      userId: ActiveSession.defaultUserId,
      from: s.startedAt,
      to: s.endedAt,
    );
    final r = BreathingDisruptionRule.detect(spo2, hrSamples: hr);
    if (r.totalBuckets >= 4) {
      out.add(BreathingTrendNight(wakeDate: s.endedAt.toLocal(), result: r));
    }
  }
  out.sort((a, b) => b.wakeDate.compareTo(a.wakeDate));
  return out;
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
