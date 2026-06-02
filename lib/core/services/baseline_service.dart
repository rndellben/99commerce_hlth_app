import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/models/baseline.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/repositories/baseline_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:uuid/uuid.dart';

/// Canonical metric keys used by the baselines table. Persisted as TEXT
/// so renaming breaks history — treat as a permanent contract.
class BaselineMetric {
  static const restingHrBpm = 'resting_hr_bpm';
  static const hrvRmssdMs = 'hrv_rmssd_ms';
  static const hrvSdnnMs = 'hrv_sdnn_ms';
  static const spo2OvernightAvg = 'spo2_overnight_avg';
  static const spo2OvernightMin = 'spo2_overnight_min';
  static const sleepTotalMin = 'sleep_total_min';
  static const sleepEfficiencyPct = 'sleep_efficiency_pct';
  static const steps = 'steps';
  static const respRateBpm = 'resp_rate_bpm';

  /// Iteration order = order baseline rows are written. Stable for tests.
  static const all = <String>[
    restingHrBpm,
    hrvRmssdMs,
    hrvSdnnMs,
    spo2OvernightAvg,
    spo2OvernightMin,
    sleepTotalMin,
    sleepEfficiencyPct,
    steps,
    respRateBpm,
  ];
}

/// Computes rolling-window baselines from `daily_metrics` rows.
///
/// Per hlth-engineering-primer.md §"Rolling Baselines":
/// * 14-day and 30-day = simple mean (+ stddev) over last N days of values.
/// * 90-day window also computed as mean+stddev for v1; the regression-
///   slope variant will land as a separate metric (e.g. `*_90d_slope`) once
///   a trend table exists.
/// * Days with no value are skipped — they don't count as zero.
class BaselineService {
  BaselineService({required this.dailyRepo, required this.baselineRepo});

  final DailyMetricsRepository dailyRepo;
  final BaselineRepository baselineRepo;

  static const windows = <int>[14, 30, 90];
  static const _uuid = Uuid();
  static const _algorithmVersion = 'baseline-mean-v1';

  /// Recompute every (metric, window) baseline anchored at `forDate`.
  /// Returns the number of baseline rows actually written (skipping
  /// metrics with no samples in the window).
  Future<int> recomputeAll({
    required String userId,
    DateTime? forDate,
  }) async {
    final anchor = _dateOnly(forDate ?? DateTime.now());
    var written = 0;
    final batch = <Baseline>[];
    for (final window in windows) {
      final from = anchor.subtract(Duration(days: window - 1));
      final rows = await dailyRepo.getInRange(
        userId: userId,
        fromDate: from,
        toDate: anchor,
      );
      for (final metric in BaselineMetric.all) {
        final values = _extract(metric, rows);
        if (values.isEmpty) continue;
        final stats = _stats(values);
        batch.add(Baseline(
          id: _uuid.v4(),
          userId: userId,
          metricKey: metric,
          windowDays: window,
          computedForDate: anchor,
          meanValue: stats.mean,
          stddevValue: stats.stddev,
          sampleCount: values.length,
          computedAt: DateTime.now().toUtc(),
          algorithmVersion: _algorithmVersion,
        ));
        written++;
      }
    }
    if (batch.isNotEmpty) {
      await baselineRepo.upsertMany(batch);
    }
    return written;
  }

  /// Single (metric, window) recompute — useful when only one metric changed.
  Future<Baseline?> recompute({
    required String userId,
    required String metricKey,
    required int windowDays,
    DateTime? forDate,
  }) async {
    final anchor = _dateOnly(forDate ?? DateTime.now());
    final from = anchor.subtract(Duration(days: windowDays - 1));
    final rows = await dailyRepo.getInRange(
      userId: userId,
      fromDate: from,
      toDate: anchor,
    );
    final values = _extract(metricKey, rows);
    if (values.isEmpty) return null;
    final stats = _stats(values);
    final baseline = Baseline(
      id: _uuid.v4(),
      userId: userId,
      metricKey: metricKey,
      windowDays: windowDays,
      computedForDate: anchor,
      meanValue: stats.mean,
      stddevValue: stats.stddev,
      sampleCount: values.length,
      computedAt: DateTime.now().toUtc(),
      algorithmVersion: _algorithmVersion,
    );
    await baselineRepo.upsert(baseline);
    return baseline;
  }

  // ── helpers ────────────────────────────────────────────────────────────

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<double> _extract(String metric, List<DailyMetrics> rows) {
    final out = <double>[];
    for (final r in rows) {
      final v = _valueFor(metric, r);
      if (v != null) out.add(v);
    }
    return out;
  }

  double? _valueFor(String metric, DailyMetrics m) {
    switch (metric) {
      case BaselineMetric.restingHrBpm:
        return m.restingHrBpm?.toDouble();
      case BaselineMetric.hrvRmssdMs:
        return m.hrvRmssdMs;
      case BaselineMetric.hrvSdnnMs:
        return m.hrvSdnnMs;
      case BaselineMetric.spo2OvernightAvg:
        return m.spo2OvernightAvg;
      case BaselineMetric.spo2OvernightMin:
        return m.spo2OvernightMin?.toDouble();
      case BaselineMetric.sleepTotalMin:
        return m.sleepTotalMin?.toDouble();
      case BaselineMetric.sleepEfficiencyPct:
        return m.sleepEfficiencyPct;
      case BaselineMetric.steps:
        return m.steps?.toDouble();
      case BaselineMetric.respRateBpm:
        return m.restingRespRateBpm;
      default:
        return null;
    }
  }

  ({double mean, double stddev}) _stats(List<double> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (values.length < 2) return (mean: mean, stddev: 0);
    var sq = 0.0;
    for (final v in values) {
      final d = v - mean;
      sq += d * d;
    }
    final variance = sq / (values.length - 1); // sample stddev (Bessel)
    return (mean: mean, stddev: math.sqrt(variance));
  }
}

final baselineServiceProvider = Provider<BaselineService>((ref) {
  return BaselineService(
    dailyRepo: ref.watch(dailyMetricsRepositoryProvider),
    baselineRepo: ref.watch(baselineRepositoryProvider),
  );
});
