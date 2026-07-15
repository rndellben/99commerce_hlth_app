import 'package:flutter_test/flutter_test.dart';
import 'package:hlth_app/core/database/app_database.dart' as db;
import 'package:hlth_app/core/repositories/notification_log_repository.dart';
import 'package:hlth_app/core/services/alerts/alert_evaluator.dart';
import 'package:hlth_app/core/services/alerts/alert_rule.dart';
import 'package:hlth_app/core/services/notification_service.dart';

void main() {
  const userId = 'u1';
  final t0 = DateTime.utc(2026, 6, 22, 12);

  late _FakeNotifications notifications;
  late _FakeLog log;

  setUp(() {
    notifications = _FakeNotifications();
    log = _FakeLog();
  });

  AlertEvaluator evaluatorWith(
    AlertRule rule, {
    bool enabled = true,
    bool dnd = false,
  }) =>
      AlertEvaluator(
        rules: [rule],
        log: log,
        notifications: notifications,
        policy: _FixedPolicy(enabled: enabled, dnd: dnd),
      );

  test('fires once when a candidate exists and nothing has fired before',
      () async {
    final rule = _StubRule(candidate: _candidate());
    final results = await evaluatorWith(rule).evaluateAll(userId: userId, now: t0);

    expect(results.single.fired, isTrue);
    expect(results.single.reason, 'fired');
    expect(notifications.shown, hasLength(1));
    expect(log.entries, hasLength(1));
  });

  test('rate-limits a second fire inside minInterval', () async {
    final rule = _StubRule(
      candidate: _candidate(),
      minInterval: const Duration(days: 7),
    );
    final e = evaluatorWith(rule);

    await e.evaluateAll(userId: userId, now: t0);
    final second = await e.evaluateAll(
      userId: userId,
      now: t0.add(const Duration(days: 3)), // < 7 days
    );

    expect(second.single.fired, isFalse);
    expect(second.single.reason, 'rate-limited');
    expect(notifications.shown, hasLength(1)); // not fired again
  });

  test('fires again once minInterval has elapsed', () async {
    final rule = _StubRule(
      candidate: _candidate(),
      minInterval: const Duration(days: 7),
    );
    final e = evaluatorWith(rule);

    await e.evaluateAll(userId: userId, now: t0);
    final later = await e.evaluateAll(
      userId: userId,
      now: t0.add(const Duration(days: 8)), // > 7 days
    );

    expect(later.single.fired, isTrue);
    expect(notifications.shown, hasLength(2));
  });

  test('does nothing when the rule returns no candidate', () async {
    final rule = _StubRule(candidate: null);
    final results = await evaluatorWith(rule).evaluateAll(userId: userId, now: t0);

    expect(results.single.fired, isFalse);
    expect(results.single.reason, 'no-candidate');
    expect(notifications.shown, isEmpty);
    expect(log.entries, isEmpty);
  });

  test('a throwing rule is isolated and reported as error', () async {
    final results =
        await evaluatorWith(_ThrowingRule()).evaluateAll(userId: userId, now: t0);
    expect(results.single.fired, isFalse);
    expect(results.single.reason, 'error');
    expect(notifications.shown, isEmpty);
  });

  test('OS permission missing: not shown AND not logged — the candidate is '
      'deferred, so it fires on the first pass after permission returns',
      () async {
    notifications.osEnabled = false;
    final rule = _StubRule(candidate: _candidate());
    final e = evaluatorWith(rule);

    final blocked = await e.evaluateAll(userId: userId, now: t0);
    expect(blocked.single.reason, 'blocked-by-os');
    expect(notifications.shown, isEmpty);
    expect(log.entries, isEmpty, reason: 'rate limit must not be burned');

    notifications.osEnabled = true;
    final after = await e.evaluateAll(
        userId: userId, now: t0.add(const Duration(minutes: 30)));
    expect(after.single.fired, isTrue);
    expect(notifications.shown, hasLength(1));
  });

  test('master toggle off: nothing shown, nothing logged', () async {
    final rule = _StubRule(candidate: _candidate());
    final results = await evaluatorWith(rule, enabled: false)
        .evaluateAll(userId: userId, now: t0);
    expect(results.single.reason, 'disabled-in-settings');
    expect(notifications.shown, isEmpty);
    expect(log.entries, isEmpty);
  });

  test('DND: silenced but still recorded (per the settings-screen copy)',
      () async {
    final rule = _StubRule(candidate: _candidate());
    final results = await evaluatorWith(rule, dnd: true)
        .evaluateAll(userId: userId, now: t0);
    expect(results.single.fired, isFalse);
    expect(results.single.reason, 'dnd-silenced');
    expect(notifications.shown, isEmpty);
    expect(log.entries, hasLength(1));
  });
}

class _FixedPolicy extends NotificationDeliveryPolicy {
  const _FixedPolicy({required this.enabled, required this.dnd});
  final bool enabled;
  final bool dnd;
  @override
  Future<({bool enabled, bool dnd})> read() async =>
      (enabled: enabled, dnd: dnd);
}

AlertCandidate _candidate() => const AlertCandidate(
      dedupeKey: 'k',
      title: 'T',
      body: 'B',
      channel: AlertChannel.alert,
    );

class _StubRule implements AlertRule {
  _StubRule({
    required this.candidate,
    this.minInterval = const Duration(days: 1),
  });
  final AlertCandidate? candidate;
  @override
  final Duration minInterval;
  @override
  final String type = 'stub';
  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async => candidate;
}

class _ThrowingRule implements AlertRule {
  @override
  String get type => 'boom';
  @override
  Duration get minInterval => const Duration(days: 1);
  @override
  Future<AlertCandidate?> evaluate(AlertContext ctx) async =>
      throw StateError('boom');
}

class _FakeNotifications implements NotificationService {
  final List<String> shown = [];
  bool osEnabled = true;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> areNotificationsEnabled() async => osEnabled;
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    AlertChannel channel = AlertChannel.alert,
    String? payload,
  }) async {
    shown.add('$id:$title');
  }
}

class _FakeLog implements NotificationLogRepository {
  final List<String> entries = [];
  final Map<String, DateTime> _lastByKey = {};

  @override
  Future<void> insert({
    required String userId,
    required String type,
    required String dedupeKey,
    required String title,
    required String body,
    String? payload,
    required String channel,
    required DateTime firedAtUtc,
  }) async {
    entries.add('$userId|$type');
    _lastByKey['$userId|$type'] = firedAtUtc;
  }

  @override
  Future<DateTime?> lastFiredFor({
    required String userId,
    required String type,
  }) async =>
      _lastByKey['$userId|$type'];

  @override
  Future<List<db.NotificationLogData>> recent({
    required String userId,
    int limit = 50,
  }) async =>
      [];
}
