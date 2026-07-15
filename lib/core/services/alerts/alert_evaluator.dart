import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/notification_log_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/bedtime_reminder_rule.dart';
import 'package:hlth_app/core/services/alerts/breathing_disruption_rule.dart';
import 'package:hlth_app/core/services/alerts/hypertension_risk_rule.dart';
import 'package:hlth_app/core/services/alerts/irregular_rhythm_rule.dart';
import 'package:hlth_app/core/services/alerts/morning_report_rule.dart';
import 'package:hlth_app/core/services/alerts/retention_rule.dart';
import 'package:hlth_app/core/services/breadcrumbs.dart';
import 'package:hlth_app/core/services/notification_service.dart';

/// Outcome of evaluating one rule on one pass.
class AlertFireResult {
  const AlertFireResult({required this.type, required this.fired, this.reason});
  final String type;
  final bool fired;

  /// 'fired' | 'no-candidate' | 'rate-limited' | 'disabled-in-settings' |
  /// 'blocked-by-os' | 'dnd-silenced' | 'error'.
  final String? reason;
}

/// Runs every registered [AlertRule] on a pass, enforces per-rule
/// rate-limiting via the notification log, and fires through
/// [NotificationService]. Called after each sync tick.
///
/// Delivery gates (checked once per pass, 2026-07-14):
///  * in-app master toggle OFF → nothing shown, nothing logged;
///  * OS permission missing → nothing shown, nothing logged — logging a
///    silently-dropped `show()` used to burn the rule's rate-limit on a
///    notification nobody saw, so it stayed silent even after the user
///    granted permission;
///  * in-app Do Not Disturb → not shown but LOGGED, matching the settings
///    copy "Notifications are silenced but still recorded".
///
/// A single rule throwing never aborts the others — each is isolated and
/// recorded as `error`.
class AlertEvaluator {
  AlertEvaluator({
    required this.rules,
    required this.log,
    required this.notifications,
    NotificationDeliveryPolicy? policy,
  }) : policy = policy ?? const NotificationDeliveryPolicy();

  final List<AlertRule> rules;
  final NotificationLogRepository log;
  final NotificationService notifications;
  final NotificationDeliveryPolicy policy;

  /// Serializes passes: evaluation now triggers from BOTH the sync tick and
  /// app-resume, and two concurrent passes could each clear the rate-limit
  /// check before either logs — double-firing the same rule. Overlapping
  /// callers get an empty result and the in-flight pass wins.
  bool _inFlight = false;

  Future<List<AlertFireResult>> evaluateAll({
    required String userId,
    DateTime? now,
  }) async {
    if (_inFlight) return const [];
    _inFlight = true;
    try {
      return await _evaluatePass(userId: userId, now: now);
    } finally {
      _inFlight = false;
    }
  }

  Future<List<AlertFireResult>> _evaluatePass({
    required String userId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now().toUtc();
    final results = <AlertFireResult>[];

    final prefs = await policy.read();
    final osEnabled = await notifications.areNotificationsEnabled();
    if (!osEnabled) {
      Breadcrumbs.log('alert: OS notification permission missing — '
          'candidates will be deferred, not consumed');
    }

    for (final rule in rules) {
      try {
        final candidate = await rule.evaluate(
          AlertContext(userId: userId, now: ts),
        );
        if (candidate == null) {
          results.add(AlertFireResult(
              type: rule.type, fired: false, reason: 'no-candidate'));
          continue;
        }

        final last = await log.lastFiredFor(userId: userId, type: rule.type);
        if (last != null && ts.difference(last) < rule.minInterval) {
          results.add(AlertFireResult(
              type: rule.type, fired: false, reason: 'rate-limited'));
          continue;
        }

        // Master toggle / OS permission: skip BOTH show and log so the
        // candidate is deferred intact — it fires on the first pass after
        // delivery becomes possible again.
        if (!prefs.enabled) {
          results.add(AlertFireResult(
              type: rule.type, fired: false, reason: 'disabled-in-settings'));
          continue;
        }
        if (!osEnabled) {
          results.add(AlertFireResult(
              type: rule.type, fired: false, reason: 'blocked-by-os'));
          continue;
        }

        final payloadJson =
            candidate.payload == null ? null : jsonEncode(candidate.payload);
        if (!prefs.dnd) {
          await notifications.show(
            id: rule.type.hashCode & 0x7fffffff,
            title: candidate.title,
            body: candidate.body,
            channel: candidate.channel,
            payload: payloadJson,
          );
        }
        await log.insert(
          userId: userId,
          type: rule.type,
          dedupeKey: candidate.dedupeKey,
          title: candidate.title,
          body: candidate.body,
          payload: payloadJson,
          channel: candidate.channel.name,
          firedAtUtc: ts,
        );
        if (prefs.dnd) {
          results.add(AlertFireResult(
              type: rule.type, fired: false, reason: 'dnd-silenced'));
          Breadcrumbs.log(
              'alert: ${rule.type} silenced by DND — "${candidate.title}"');
        } else {
          results.add(
              AlertFireResult(type: rule.type, fired: true, reason: 'fired'));
          Breadcrumbs.log('alert: fired ${rule.type} — "${candidate.title}"');
        }
      } catch (e) {
        results.add(
            AlertFireResult(type: rule.type, fired: false, reason: 'error'));
        Breadcrumbs.log('alert: ${rule.type} errored ($e)');
      }
    }
    return results;
  }
}

final alertEvaluatorProvider = Provider<AlertEvaluator>((ref) {
  return AlertEvaluator(
    // Grows by one entry per new rule.
    rules: [
      ref.watch(retentionRuleProvider),
      ref.watch(irregularRhythmRuleProvider),
      ref.watch(hypertensionRiskRuleProvider),
      ref.watch(breathingDisruptionRuleProvider),
      ref.watch(morningReportRuleProvider),
      ref.watch(bedtimeReminderRuleProvider),
    ],
    log: ref.watch(notificationLogRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
