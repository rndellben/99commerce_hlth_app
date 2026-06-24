import 'package:hlth_app/core/services/notification_service.dart';

/// Inputs handed to every rule on each evaluation pass.
class AlertContext {
  const AlertContext({required this.userId, required this.now});
  final String userId;
  final DateTime now;
}

/// What a rule wants to fire. Returned from [AlertRule.evaluate]; null means
/// "nothing to fire this pass."
class AlertCandidate {
  const AlertCandidate({
    required this.dedupeKey,
    required this.title,
    required this.body,
    this.channel = AlertChannel.alert,
    this.payload,
  });

  /// Per-occurrence key (e.g. 'afib-2026-06-22'). Logged for audit; the
  /// rate-limit itself is enforced per (userId, rule.type).
  final String dedupeKey;
  final String title;
  final String body;
  final AlertChannel channel;
  final Map<String, dynamic>? payload;
}

/// A single alert rule. Implementations read whatever data they need
/// (injected via their constructor) and decide whether to fire.
///
/// Contract: be **conservative** — return null whenever the data is
/// missing, stale, or ambiguous. No false alarms (Ryan's hard requirement).
/// The [AlertEvaluator] enforces [minInterval] rate-limiting, so rules do
/// not implement their own throttling.
abstract class AlertRule {
  /// Stable id — also the rate-limit key and notification group.
  String get type;

  /// Minimum spacing between two fires of this rule (e.g. 7 days).
  Duration get minInterval;

  /// Return a candidate to fire, or null to fire nothing this pass.
  Future<AlertCandidate?> evaluate(AlertContext ctx);
}
