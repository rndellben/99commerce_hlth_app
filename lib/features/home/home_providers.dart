import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';

/// Today's `daily_metrics` row (null until the aggregator has run).
final todayDailyMetricsProvider = StreamProvider<DailyMetrics?>((ref) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  final today = DateTime.now();
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(today.year, today.month, today.day),
  );
});

/// Latest stored HR sample (any time, any source).
final latestHrSampleProvider = StreamProvider<HrSample?>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

/// Latest stored SpO2 sample.
final latestSpo2SampleProvider = StreamProvider<Spo2Sample?>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});
