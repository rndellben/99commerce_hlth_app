import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/repositories/notification_log_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/alerts/breathing_disruption_rule.dart';
import 'package:hlth_app/core/services/alerts/hypertension_risk_rule.dart';
import 'package:hlth_app/core/services/alerts/irregular_rhythm_rule.dart';
import 'package:hlth_app/core/services/alerts/morning_report_rule.dart';
import 'package:hlth_app/core/services/alerts/retention_rule.dart';
import 'package:hlth_app/core/services/notification_service.dart';

/// Outcome of evaluating one rule on one pass.
class AlertFireResult {
  const AlertFireResult({required this.type, required this.fired, this.reason});
  final String type;
  final bool fired;

  /// 'fired' | 'no-candidate' | 'rate-limited' | 'error'.
  final String? reason;
}

/// Runs every registered [AlertRule] on a pass, enforces per-rule
/// rate-limiting via the notification log, and fires through
/// [NotificationService]. Called after each sync tick.
///
/// A single rule throwing never aborts the others — each is isolated and
/// recorded as `error`.
class AlertEvaluator {
  AlertEvaluator({
    required this.rules,
    required this.log,
    required this.notifications,
  });

  final List<AlertRule> rules;
  final NotificationLogRepository log;
  final NotificationService notifications;

  Future<List<AlertFireResult>> evaluateAll({
    required String userId,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now().toUtc();
    final results = <AlertFireResult>[];

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

        final payloadJson =
            candidate.payload == null ? null : jsonEncode(candidate.payload);
        await notifications.show(
          id: rule.type.hashCode & 0x7fffffff,
          title: candidate.title,
          body: candidate.body,
          channel: candidate.channel,
          payload: payloadJson,
        );
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
        results.add(
            AlertFireResult(type: rule.type, fired: true, reason: 'fired'));
      } catch (_) {
        results.add(
            AlertFireResult(type: rule.type, fired: false, reason: 'error'));
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
    ],
    log: ref.watch(notificationLogRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
