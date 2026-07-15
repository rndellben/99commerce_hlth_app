import 'package:shared_preferences/shared_preferences.dart';

/// Records when the user last interacted with the app (launch / foreground
/// resume) so night-time rules have an *irrefutable* wakefulness signal.
///
/// Rationale (bedtime reminder, 2026-07-14): ring data cannot distinguish
/// "awake but motionless in bed" from "asleep" — both show zero steps and
/// near-resting HR. A foreground resume, however, can only be produced by
/// an awake human, so it is the one wake signal with a zero false-positive
/// rate. Only the UI engine writes it; the headless engine merely reads
/// (a background revive is not evidence of a conscious user).
///
/// Stored in SharedPreferences so both engines (UI + headless) see the same
/// value, mirroring how the retention gate shares its timestamp.
class AppActivityTracker {
  AppActivityTracker._();

  static const kLastActiveAtKey = 'last_app_active_at_utc_sec';

  /// Stamp "the user is using the app right now". Fire-and-forget, never
  /// throws — losing one stamp only defers evidence to the next resume.
  static Future<void> recordAppActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        kLastActiveAtKey,
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      );
    } catch (_) {
      // Prefs unavailable (e.g. during teardown) — skip silently.
    }
  }

  /// UTC instant of the last recorded interaction, or null if never stamped
  /// (fresh install) or prefs are unavailable.
  static Future<DateTime?> lastAppActiveAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sec = prefs.getInt(kLastActiveAtKey);
      if (sec == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }
}
