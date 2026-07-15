import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which channel a notification fires on. `alert` is high-importance
/// (health events — heads-up, sound); `retention` is default-importance
/// (nudges to reopen the app).
enum AlertChannel { alert, retention }

/// Local-notification delivery wrapper around `flutter_local_notifications`.
///
/// Delivery-agnostic on purpose: the alert rules engine talks to this
/// interface, so a server-push (FCM) implementation can be slotted in later
/// without touching the rules. V1 is local-only — every alert is computed
/// on-device from synced data, so no server round-trip is needed.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _alertChannelId = 'hlth_alerts';
  static const _retentionChannelId = 'hlth_retention';

  bool _initialized = false;

  /// Wire platform init + create the Android channels. Idempotent.
  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Ask for permission explicitly later via [requestPermission], not at init.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        'Health alerts',
        description: 'Important health readings that need your attention.',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _retentionChannelId,
        'Reminders',
        description: 'Nudges to open the app and back up your data.',
        importance: Importance.defaultImportance,
      ),
    );

    _initialized = true;
  }

  /// Request the OS notification permission (Android 13+ POST_NOTIFICATIONS
  /// runtime prompt / iOS prompt). Returns whether it's granted.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Whether the OS will actually display our notifications right now
  /// (Android 13+ POST_NOTIFICATIONS grant / iOS authorization).
  ///
  /// The alert engine checks this BEFORE recording a fire: `show()` on a
  /// denied device is a silent no-op, and logging it anyway would burn the
  /// rule's rate-limit window on a notification nobody saw. Unknown
  /// platforms (tests, desktop) resolve to true — the status quo.
  Future<bool> areNotificationsEnabled() async {
    try {
      await init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final options = await ios.checkPermissions();
        return options?.isEnabled ?? true;
      }
      return true;
    } catch (_) {
      // Introspection failure must never block delivery attempts.
      return true;
    }
  }

  /// Show a notification immediately on [channel].
  Future<void> show({
    required int id,
    required String title,
    required String body,
    AlertChannel channel = AlertChannel.alert,
    String? payload,
  }) async {
    await init();
    final isAlert = channel == AlertChannel.alert;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        isAlert ? _alertChannelId : _retentionChannelId,
        isAlert ? 'Health alerts' : 'Reminders',
        importance: isAlert ? Importance.high : Importance.defaultImportance,
        priority: isAlert ? Priority.high : Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// The user's in-app delivery preferences, written by the Notifications
/// settings screen and enforced by the alert engine:
///
///  * master toggle OFF → nothing is shown and nothing is logged (alerts
///    resume, with their rate-limits intact, when re-enabled);
///  * Do Not Disturb ON → nothing is shown but fires ARE logged, matching
///    the screen's copy "Notifications are silenced but still recorded".
///
/// Before 2026-07-14 these prefs were written but never read — the toggles
/// were cosmetic. The key constants live here (not in the screen) so the
/// writer and the reader cannot drift apart.
class NotificationDeliveryPolicy {
  const NotificationDeliveryPolicy();

  static const kEnabledKey = 'notifications_enabled';
  static const kDndKey = 'notifications_dnd';

  /// Reads the current preferences. Any storage failure (e.g. plugin not
  /// registered in a bare test environment) resolves to the permissive
  /// defaults — identical to pre-policy behavior.
  Future<({bool enabled, bool dnd})> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        enabled: prefs.getBool(kEnabledKey) ?? true,
        dnd: prefs.getBool(kDndKey) ?? false,
      );
    } catch (_) {
      return (enabled: true, dnd: false);
    }
  }
}
