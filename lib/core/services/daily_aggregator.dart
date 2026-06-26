import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/sleep_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/step_bucket_repository.dart';
import 'package:hlth_app/core/services/activity_classifier.dart';
import 'package:uuid/uuid.dart';

/// Reads per-metric samples for a given local day and writes the
/// derived `daily_metrics` rollup row.
///
/// Conventions (hlth-db-schema.md §4.2, hlth-engineering-primer.md §Phase 1):
/// * **Resting HR** = lowest 10-minute moving average during sleep window;
///   falls back to lowest morning HR (04:00–10:00 local); else median HR.
/// * **HRV (RMSSD / SDNN)** = median of the samples inside the most recent
///   sleep window `[bedtime, wake)`; falls back to the morning-resting reading
///   (04:00–09:00 local) only when the night has no HRV samples. Sleep-window
///   HRV per Ryan 2026-06-23 — daytime HRV is a motion-contaminated signal.
/// * **SpO2 overnight** = mean/min of samples inside the most recent sleep
///   session window; falls back to 00:00–06:00 local if no session yet.
/// * **Blood pressure** = the median-systolic reading (with its own
///   diastolic) from the sleep window; falls back to the day's hourly
///   snapshots. Stored raw — cuff calibration is applied at the display
///   layer, not here.
/// * **Sleep** = direct copy of the most recent SleepSession that ended on
///   `localDate` (or earlier same morning).
/// * **Activity** = preserved from any existing row (step sync writes those
///   columns directly; aggregator must not clobber them).
class DailyAggregator {
  DailyAggregator({
    required this.hrRepo,
    required this.hrvRepo,
    required this.spo2Repo,
    required this.sleepRepo,
    required this.dailyRepo,
    required this.stepBucketRepo,
    required this.bpRepo,
    ActivityClassifier? classifier,
  }) : classifier = classifier ?? ActivityClassifier();

  final HrRepository hrRepo;
  final HrvRepository hrvRepo;
  final Spo2Repository spo2Repo;
  final SleepRepository sleepRepo;
  final DailyMetricsRepository dailyRepo;
  final StepBucketRepository stepBucketRepo;
  final BpRepository bpRepo;
  final ActivityClassifier classifier;

  static const _uuid = Uuid();
  static const _algorithmVersion = 'aggregator-v1';

  Future<DailyMetrics> aggregateDay({
    required String userId,
    required DateTime localDate,
    required int tzOffsetMin,
    void Function(String message)? log,
  }) async {
    // Treat the y/m/d as a local date and resolve its midnight as a UTC
    // instant. Using DateTime.utc + manual subtract keeps the math
    // independent of the system clock's TZ — important for tests and CI.
    final localMidnight =
        DateTime(localDate.year, localDate.month, localDate.day);
    final localMidnightAsUtc =
        DateTime.utc(localDate.year, localDate.month, localDate.day);
    final dayStartUtc =
        localMidnightAsUtc.subtract(Duration(minutes: tzOffsetMin));
    final dayEndUtc = dayStartUtc.add(const Duration(days: 1));

    // ── HR samples for the local day ─────────────────────────────────────
    final hrSamples = await hrRepo.getInRange(
      userId: userId,
      from: dayStartUtc,
      to: dayEndUtc,
    );

    // ── Most recent sleep session whose start lies in the prior 24h
    //    relative to `localDate`'s morning. That session's window is what
    //    "overnight" SpO2 + sleep summary attribute to today.
    final sessionFrom = dayStartUtc.subtract(const Duration(hours: 18));
    final sessionTo = dayStartUtc.add(const Duration(hours: 12));
    final sessions = await sleepRepo.getInRange(
      userId: userId,
      from: sessionFrom,
      to: sessionTo,
      type: SleepSessionType.night,
    );
    final session = sessions.isNotEmpty ? sessions.last : null;

    // ── Resting HR ───────────────────────────────────────────────────────
    int? restingHr;
    if (session != null) {
      final inSleep = hrSamples
          .where((s) =>
              !s.capturedAt.isBefore(session.startedAt) &&
              s.capturedAt.isBefore(session.endedAt))
          .toList();
      restingHr = _lowestSustainedHr(inSleep);
    }
    if (restingHr == null) {
      // Both sides in "naive local rendered as UTC" frame so the
      // microsecond comparison lines up regardless of system TZ.
      final morningStart = localMidnightAsUtc.add(const Duration(hours: 4));
      final morningEnd = localMidnightAsUtc.add(const Duration(hours: 10));
      final morningHr = hrSamples
          .where((s) {
            final localAsUtc = s.capturedAt.add(Duration(minutes: tzOffsetMin));
            return !localAsUtc.isBefore(morningStart) &&
                localAsUtc.isBefore(morningEnd);
          })
          .toList();
      restingHr = _lowestSustainedHr(morningHr);
    }
    restingHr ??= _median(hrSamples.map((s) => s.bpm).toList());

    // ── HRV — over the SLEEP WINDOW ──────────────────────────────────────
    // Ryan 2026-06-23: nighttime HRV, not daytime. "daytime HRV is not
    // representative … HRV can be impacted by drinking, smoking, walking,
    // exercise … take the intervals for HRV during sleep." So we take the
    // median RMSSD/SDNN of the samples inside [bedtime, wake]; the morning-
    // resting reading is only a fallback for nights with no HRV samples.
    double? hrvRmssd;
    double? hrvSdnn;
    if (session != null) {
      final hrvInSleep = await hrvRepo.getInRange(
        userId: userId,
        from: session.startedAt,
        to: session.endedAt,
      );
      hrvRmssd = sleepWindowMedianRmssd(
          hrvInSleep, session.startedAt, session.endedAt);
      hrvSdnn = sleepWindowMedianSdnn(
          hrvInSleep, session.startedAt, session.endedAt);
      log?.call('HRV sleep-window '
          '[${_hm(session.startedAt)}–${_hm(session.endedAt)}]: '
          '${hrvInSleep.length} samples → median RMSSD '
          '${hrvRmssd?.toStringAsFixed(1) ?? "—"} ms');
    }
    // Morning-resting fallback — also fetched when logging so the debug A/B
    // can show what the old morning-window value would have been.
    final morningHrv = (hrvRmssd == null || log != null)
        ? await hrvRepo.getMorningResting(userId: userId, forDate: localMidnight)
        : null;
    log?.call('  morning-window HRV (compare/fallback): '
        '${morningHrv?.rmssdMs.toStringAsFixed(1) ?? "—"} ms');
    hrvRmssd ??= morningHrv?.rmssdMs;
    hrvSdnn ??= morningHrv?.sdnnMs;

    // ── SpO2 overnight ───────────────────────────────────────────────────
    double? spo2Avg;
    int? spo2Min;
    if (session != null) {
      final stats = await spo2Repo.overnightStats(
        userId: userId,
        sleepStart: session.startedAt,
        sleepEnd: session.endedAt,
      );
      if (stats != null) {
        spo2Avg = stats.avg;
        spo2Min = stats.min;
      }
    }
    if (spo2Avg == null) {
      final fallbackStart = dayStartUtc; // 00:00 local of `localDate`
      final fallbackEnd = fallbackStart.add(const Duration(hours: 6));
      final stats = await spo2Repo.overnightStats(
        userId: userId,
        sleepStart: fallbackStart,
        sleepEnd: fallbackEnd,
      );
      if (stats != null) {
        spo2Avg = stats.avg;
        spo2Min = stats.min;
      }
    }

    // ── Blood pressure ───────────────────────────────────────────────────
    // The sleep screen frames BP as "measured during sleep", so prefer the
    // reading inside the sleep window; fall back to the day's readings.
    // getHourlySnapshots collapses the user-selectable scheduled cadence
    // (15/30/60 min) to ≤1 reading/hour so density doesn't skew the median.
    // Stored raw — the cuff calibration is applied at the display layer
    // (calibratedLatestBpProvider), not here.
    int? systolic;
    int? diastolic;
    if (session != null) {
      final bpInSleep = await bpRepo.getHourlySnapshots(
        userId: userId,
        from: session.startedAt,
        to: session.endedAt,
      );
      final pair = _medianBp(bpInSleep);
      systolic = pair?.sbp;
      diastolic = pair?.dbp;
    }
    if (systolic == null) {
      final bpDay = await bpRepo.getHourlySnapshots(
        userId: userId,
        from: dayStartUtc,
        to: dayEndUtc,
      );
      final pair = _medianBp(bpDay);
      systolic = pair?.sbp;
      diastolic = pair?.dbp;
    }
    log?.call('BP: ${systolic != null ? "$systolic/$diastolic mmHg" : "—"}');

    // ── Sleep totals ─────────────────────────────────────────────────────
    int? sleepTotalMin;
    double? sleepDeepPct;
    double? sleepRemPct;
    double? sleepLightPct;
    double? sleepEfficiencyPct;
    DateTime? bedtime;
    DateTime? wake;
    if (session != null) {
      sleepTotalMin = session.totalMin;
      bedtime = session.startedAt;
      wake = session.endedAt;
      if (session.totalMin > 0) {
        sleepDeepPct = session.deepMin / session.totalMin;
        sleepRemPct = session.remMin / session.totalMin;
        sleepLightPct = session.lightMin / session.totalMin;
      }
      // Sleep efficiency = asleep / total-in-bed. The H59's
      // `totalSleepDuration` already equals the full session window
      // (it sums deep+light+rem+awake), so dividing it by the window
      // is always 1.0 — that's wrong. Use (deep+light+rem) over the
      // sum of all stages instead.
      final asleepMin = session.deepMin + session.lightMin + session.remMin;
      final inBedMin = asleepMin + session.awakeMin;
      sleepEfficiencyPct = session.efficiencyPct ??
          (inBedMin > 0 ? asleepMin / inBedMin : null);
    }

    // ── Activity classification — active minutes from step buckets ──────
    // Bucket repo is the authoritative source for 15-min granularity. If
    // no buckets were synced for the day, activeMinutes is left null
    // (preserves any existing value rather than overwriting with 0).
    int? activeMinutes;
    final buckets = await stepBucketRepo.getForDay(
      userId: userId,
      localDate: localMidnight,
      tzOffsetMin: tzOffsetMin,
    );
    if (buckets.isNotEmpty) {
      activeMinutes = classifier.activeMinutes(buckets);
    }

    // ── Merge with existing row so step sync's activity columns survive ─
    final existing = await dailyRepo.getForDay(
      userId: userId,
      localDate: localMidnight,
    );
    final now = DateTime.now().toUtc();
    final merged = (existing ??
            DailyMetrics(
              id: _uuid.v4(),
              userId: userId,
              localDate: localMidnight,
              tzOffsetMin: tzOffsetMin,
              computedAt: now,
              algorithmVersion: _algorithmVersion,
              source: DataSource.appRecomputed,
            ))
        .copyWith(
      tzOffsetMin: tzOffsetMin,
      restingHrBpm: restingHr ?? existing?.restingHrBpm,
      hrvRmssdMs: hrvRmssd ?? existing?.hrvRmssdMs,
      hrvSdnnMs: hrvSdnn ?? existing?.hrvSdnnMs,
      spo2OvernightAvg: spo2Avg ?? existing?.spo2OvernightAvg,
      spo2OvernightMin: spo2Min ?? existing?.spo2OvernightMin,
      systolicMmhg: systolic ?? existing?.systolicMmhg,
      diastolicMmhg: diastolic ?? existing?.diastolicMmhg,
      sleepTotalMin: sleepTotalMin ?? existing?.sleepTotalMin,
      sleepDeepPct: sleepDeepPct ?? existing?.sleepDeepPct,
      sleepRemPct: sleepRemPct ?? existing?.sleepRemPct,
      sleepLightPct: sleepLightPct ?? existing?.sleepLightPct,
      sleepEfficiencyPct: sleepEfficiencyPct ?? existing?.sleepEfficiencyPct,
      bedtime: bedtime ?? existing?.bedtime,
      wake: wake ?? existing?.wake,
      activeMinutes: activeMinutes ?? existing?.activeMinutes,
      computedAt: now,
      algorithmVersion: _algorithmVersion,
      source: DataSource.appRecomputed,
    );
    await dailyRepo.upsert(merged);

    // Mark contributing HR samples as resting for downstream baselines.
    if (session != null) {
      await _markRestingDuringSleep(
        userId: userId,
        sleepStart: session.startedAt,
        sleepEnd: session.endedAt,
      );
    }
    return merged;
  }

  Future<void> aggregateRange({
    required String userId,
    required DateTime fromDate,
    required DateTime toDate,
    required int tzOffsetMin,
  }) async {
    var cursor = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final end = DateTime(toDate.year, toDate.month, toDate.day);
    while (!cursor.isAfter(end)) {
      await aggregateDay(
        userId: userId,
        localDate: cursor,
        tzOffsetMin: tzOffsetMin,
      );
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  /// Convenience: aggregate the trailing `days` window through today.
  Future<void> aggregateRecent({
    required String userId,
    int days = 14,
    int? tzOffsetMin,
  }) async {
    final tz = tzOffsetMin ?? DateTime.now().timeZoneOffset.inMinutes;
    final today = DateTime.now();
    final to = DateTime(today.year, today.month, today.day);
    final from = to.subtract(Duration(days: days - 1));
    await aggregateRange(
      userId: userId,
      fromDate: from,
      toDate: to,
      tzOffsetMin: tz,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────

  /// Lowest 10-minute moving-average BPM across the provided samples.
  /// Returns null if fewer than 3 samples in the window.
  int? _lowestSustainedHr(List<HrSample> samples) {
    if (samples.length < 3) {
      if (samples.isEmpty) return null;
      // Not enough data for a moving window — fall back to the minimum.
      return samples.map((s) => s.bpm).reduce((a, b) => a < b ? a : b);
    }
    final sorted = [...samples]
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    const window = Duration(minutes: 10);
    int? lowest;
    for (var i = 0; i < sorted.length; i++) {
      final windowEnd = sorted[i].capturedAt.add(window);
      final group = sorted
          .where((s) =>
              !s.capturedAt.isBefore(sorted[i].capturedAt) &&
              s.capturedAt.isBefore(windowEnd))
          .toList();
      if (group.length < 2) continue;
      final avg = group.map((s) => s.bpm).reduce((a, b) => a + b) ~/ group.length;
      if (lowest == null || avg < lowest) lowest = avg;
    }
    return lowest;
  }

  int? _median(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Representative BP pair for a set of readings: the reading whose
  /// systolic is the median, returned with its own diastolic so the pair
  /// stays a real measured pair (rather than median-of-sbp paired with an
  /// unrelated median-of-dbp). Null when there are no readings.
  ({int sbp, int dbp})? _medianBp(List<BpReading> readings) {
    if (readings.isEmpty) return null;
    final sorted = [...readings]
      ..sort((a, b) => a.systolicMmhg.compareTo(b.systolicMmhg));
    final mid = sorted[sorted.length ~/ 2];
    return (sbp: mid.systolicMmhg, dbp: mid.diastolicMmhg);
  }

  String _hm(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// Median RMSSD of the HRV samples that fall inside the sleep window
  /// `[start, end)`. Returns null when no sample lies in the window — the
  /// engine then leaves HRV absent rather than fabricating one. Static + pure
  /// so the windowing/median is unit-testable without a database.
  static double? sleepWindowMedianRmssd(
          List<HrvSample> samples, DateTime start, DateTime end) =>
      _medianD([
        for (final s in samples)
          if (_inWindow(s.capturedAt, start, end)) s.rmssdMs
      ]);

  static double? sleepWindowMedianSdnn(
          List<HrvSample> samples, DateTime start, DateTime end) =>
      _medianD([
        for (final s in samples)
          if (_inWindow(s.capturedAt, start, end) && s.sdnnMs != null) s.sdnnMs!
      ]);

  static bool _inWindow(DateTime t, DateTime start, DateTime end) =>
      !t.isBefore(start) && t.isBefore(end);

  static double? _medianD(List<double> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2.0;
  }

  Future<void> _markRestingDuringSleep({
    required String userId,
    required DateTime sleepStart,
    required DateTime sleepEnd,
  }) async {
    final samples = await hrRepo.getInRange(
      userId: userId,
      from: sleepStart,
      to: sleepEnd,
    );
    final toUpdate = samples
        .where((s) => !s.isResting)
        .map((s) => HrSample(
              id: s.id,
              userId: s.userId,
              deviceId: s.deviceId,
              capturedAt: s.capturedAt,
              tzOffsetMin: s.tzOffsetMin,
              bpm: s.bpm,
              intervalMin: s.intervalMin,
              isResting: true,
              source: s.source,
              quality: s.quality,
              algorithmVersion: s.algorithmVersion,
            ))
        .toList();
    if (toUpdate.isNotEmpty) {
      await hrRepo.insertMany(toUpdate);
    }
  }
}

final dailyAggregatorProvider = Provider<DailyAggregator>((ref) {
  return DailyAggregator(
    hrRepo: ref.watch(hrRepositoryProvider),
    hrvRepo: ref.watch(hrvRepositoryProvider),
    spo2Repo: ref.watch(spo2RepositoryProvider),
    sleepRepo: ref.watch(sleepRepositoryProvider),
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    stepBucketRepo: ref.watch(stepBucketRepositoryProvider),
    bpRepo: ref.watch(bpRepositoryProvider),
  );
});
