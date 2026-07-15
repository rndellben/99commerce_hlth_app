import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/providers/bp_calibration_providers.dart';
import 'package:hlth_app/core/repositories/notification_log_repository.dart';

/// Home-screen-specific state only. The app-wide read-models this file
/// used to host (latest samples, sparklines, scores, device status) now
/// live in `core/providers/` — import those directly instead of reaching
/// into this feature.

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
