import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/models/score.dart';
import 'package:hlth_app/core/repositories/bp_repository.dart';
import 'package:hlth_app/core/repositories/daily_metrics_repository.dart';
import 'package:hlth_app/core/repositories/hr_repository.dart';
import 'package:hlth_app/core/repositories/hrv_repository.dart';
import 'package:hlth_app/core/repositories/notification_log_repository.dart';
import 'package:hlth_app/core/repositories/score_repository.dart';
import 'package:hlth_app/core/repositories/spo2_repository.dart';
import 'package:hlth_app/core/repositories/stress_repository.dart';
import 'package:hlth_app/features/blood_pressure/bp_calibration_providers.dart';

// ─── Daily metrics ────────────────────────────────────────────────────────────

/// Today's `daily_metrics` row (null until the aggregator has run).
final todayDailyMetricsProvider = StreamProvider<DailyMetrics?>((ref) {
  final repo = ref.watch(dailyMetricsRepositoryProvider);
  final today = DateTime.now();
  return repo.watchForDay(
    userId: ActiveSession.defaultUserId,
    localDate: DateTime(today.year, today.month, today.day),
  );
});

// ─── Latest sample providers ─────────────────────────────────────────────────

final latestHrSampleProvider = StreamProvider<HrSample?>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestSpo2SampleProvider = StreamProvider<Spo2Sample?>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestHrvSampleProvider = StreamProvider<HrvSample?>((ref) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestBpReadingProvider = StreamProvider<BpReading?>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

final latestStressSampleProvider = StreamProvider<StressSample?>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  return repo.watchLatest(userId: ActiveSession.defaultUserId);
});

// ─── Score providers ─────────────────────────────────────────────────────────

final latestRecoveryScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.recovery,
  );
});

final latestCardioLoadScoreProvider = StreamProvider<Score?>((ref) {
  final repo = ref.watch(scoreRepositoryProvider);
  return repo.watchLatest(
    userId: ActiveSession.defaultUserId,
    scoreType: ScoreType.cardioLoad,
  );
});

// ─── Sparkline providers (last 24h sample series) ────────────────────────────

DateTime _last24hCutoff() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 24));

final hrSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(hrRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.bpm.toDouble()).toList());
});

final spo2SparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(spo2RepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.pctMin.toDouble()).toList());
});

final hrvSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(hrvRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.rmssdMs).toList());
});

final bpSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(bpRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.systolicMmhg.toDouble()).toList());
});

final stressSparklineProvider = StreamProvider<List<double>>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  return repo
      .watchInRange(
        userId: ActiveSession.defaultUserId,
        from: _last24hCutoff(),
        to: DateTime.now().toUtc(),
      )
      .map((rows) => rows.map((r) => r.stressScore.toDouble()).toList());
});

/// Today's stress samples (full day) — for the Day tab on the detail screen.
final todayStressSamplesProvider = StreamProvider<List<StressSample>>((ref) {
  final repo = ref.watch(stressRepositoryProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).toUtc();
  final end = start.add(const Duration(days: 1));
  return repo.watchInRange(
    userId: ActiveSession.defaultUserId,
    from: start,
    to: end,
  );
});

// ─── Device / BLE state ───────────────────────────────────────────────────────

/// Latest battery reading from the ring. Null until the band sends its first
/// battery update after connecting.
final bleBatteryProvider =
    StreamProvider<({int level, bool charging})>((ref) {
  return ref.watch(bleServiceProvider).batteryUpdate;
});

/// True for ~5 seconds after each periodic-sync tick, false otherwise.
/// Drives the "syncing" icon state in the home header.
final isSyncingProvider = StreamProvider<bool>((ref) async* {
  yield false;
  await for (final _ in ref.watch(bleServiceProvider).periodicSyncTick) {
    yield true;
    await Future<void>.delayed(const Duration(seconds: 5));
    yield false;
  }
});

/// Firmware update available — stubbed false until the OTA check service is
/// implemented. The header shows an "Update" button when this is true.
final firmwareUpdateAvailableProvider = Provider<bool>((_) => false);

// ─── BP calibration ───────────────────────────────────────────────────────────

/// True when the user has at least one active BP calibration on record.
/// The home BP tile uses this to decide between the calibration flow and
/// the trend view on first tap.
final hasBpCalibrationProvider = Provider<bool>((ref) {
  return ref.watch(activeBpCalibrationProvider).valueOrNull != null;
});

// ─── In-app alert banners ─────────────────────────────────────────────────────

enum HomeAlertType { highBp, irregularRhythm, sleepBreathing, appUpdate }

class HomeAlert {
  const HomeAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
  });
  final String id;
  final HomeAlertType type;
  final String title;
  final String body;
}

/// Alert IDs dismissed by the user in the current session.
/// Persisted only for the lifetime of the session — a fresh launch re-evaluates.
final dismissedAlertIdsProvider = StateProvider<Set<String>>((_) => {});

/// Alerts derived from live health data and the notification log.
/// Drives the dismissible banner row above the metric tiles on Home.
final activeHomeAlertsProvider = FutureProvider<List<HomeAlert>>((ref) async {
  final dismissed = ref.watch(dismissedAlertIdsProvider);
  final alerts = <HomeAlert>[];

  // ── High BP ──────────────────────────────────────────────────────────────
  // Elevated if systolic ≥ 140 OR diastolic ≥ 90 (Stage-1 hypertension
  // threshold — wellness language, not a medical diagnosis).
  final bpPair = ref.watch(calibratedLatestBpProvider).valueOrNull;
  if (bpPair != null &&
      (bpPair.displaySbp >= 140 || bpPair.displayDbp >= 90)) {
    const id = 'high-bp';
    if (!dismissed.contains(id)) {
      alerts.add(const HomeAlert(
        id: id,
        type: HomeAlertType.highBp,
        title: 'Elevated blood pressure',
        body: 'Your recent reading is above the typical range. '
            'Consider checking again and consulting your provider.',
      ));
    }
  }

  // ── Irregular rhythm (from notification log) ──────────────────────────────
  const irregularId = 'irregular-rhythm';
  if (!dismissed.contains(irregularId)) {
    final logRepo = ref.watch(notificationLogRepositoryProvider);
    final recent = await logRepo.recent(
      userId: ActiveSession.defaultUserId,
      limit: 20,
    );
    final sevenDaysAgo =
        DateTime.now().toUtc().subtract(const Duration(days: 7));
    final hasRecent = recent.any((r) =>
        r.type == 'irregular_rhythm' &&
        DateTime.fromMillisecondsSinceEpoch(r.firedAtUtcSec * 1000,
                isUtc: true)
            .isAfter(sevenDaysAgo));
    if (hasRecent) {
      alerts.add(const HomeAlert(
        id: irregularId,
        type: HomeAlertType.irregularRhythm,
        title: 'Irregular rhythm pattern detected',
        body: 'Your heart rate pattern looks different from usual. '
            'This is a wellness observation, not a diagnosis.',
      ));
    }
  }

  // Sleep breathing disturbance and app-update alerts are stubbed for now.
  // They will be wired in once the respective rules and OTA service exist.

  return alerts;
});
