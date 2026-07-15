import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/features/activity/activity_screen.dart';
import 'package:hlth_app/features/auth/auth_screen.dart';
import 'package:hlth_app/features/auth/privacy_screen.dart';
import 'package:hlth_app/features/blood_pressure/blood_pressure_screen.dart';
import 'package:hlth_app/features/data_details/data_details_screen.dart';
import 'package:hlth_app/features/debug/ble_debug_screen.dart';
import 'package:hlth_app/features/heart_rate/heart_rate_screen.dart';
import 'package:hlth_app/features/home/home_screen.dart';
import 'package:hlth_app/features/hrv/hrv_screen.dart';
import 'package:hlth_app/features/insights/insights_screen.dart';
import 'package:hlth_app/features/onboarding/onboarding_screen.dart';
import 'package:hlth_app/features/one_key/one_key_measurement_screen.dart';
import 'package:hlth_app/features/pairing/pairing_screen.dart';
import 'package:hlth_app/features/recovery/recovery_screen.dart';
import 'package:hlth_app/features/settings/device_settings_screen.dart';
import 'package:hlth_app/features/settings/settings_screen.dart';
import 'package:hlth_app/features/sleep/sleep_screen.dart';
import 'package:hlth_app/features/spo2/spo2_screen.dart';
import 'package:hlth_app/features/stress/stress_screen.dart';
import 'package:hlth_app/features/workouts/workouts_screen.dart';
import 'package:hlth_app/ui/widgets/shell_screen.dart';
import 'package:hlth_app/core/providers/user_profile_provider.dart';

/// GoRouter wrapped in a provider so it can react to the
/// `userProfileProvider` (first-launch onboarding gate).
///
/// Auth is intentionally NOT a redirect gate. The product premise is that
/// the band itself is the entitlement — owning a paired ring is what
/// unlocks the app. A Supabase account is opt-in from Settings → Account
/// for cloud features (cross-device sync, family share, future coach).
/// Anonymous users get the full local experience; the cloud sync path
/// inside SyncService skips itself when no Supabase user is signed in.
///
/// Same goes for the GDPR consent gate — it's tied to *cloud* data
/// upload, not local-only use, so it surfaces inside the account setup
/// flow when the user opts to enable cloud sync, not at app launch.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(userProfileProvider, (_, __) => notifier.bump());
  // Auth events still trigger a refresh so the Account row in Settings
  // re-renders the right "Signed in as …" / "Sign in" copy without a
  // manual rebuild — but they no longer redirect.
  ref.listen(authStateProvider, (_, __) => notifier.bump());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Always allow /debug and /auth — useful while iterating without a
      // profile, and /auth is needed during onboarding login flow.
      if (loc == '/debug' || loc == '/auth') return null;

      // First-launch profile gate (DOB / sex / height / weight). This is
      // the ONLY mandatory step before reaching the app body — the band
      // can't personalize calibration math without these inputs.
      final profileAsync = ref.read(userProfileProvider);
      if (profileAsync.isLoading) return null;
      final hasProfile = profileAsync.valueOrNull != null;
      final atOnboarding = loc == '/onboarding';
      if (!hasProfile && !atOnboarding) return '/onboarding';
      if (hasProfile && atOnboarding) return '/';

      return null;
    },
    routes: [
      // ── Primary shell (bottom-tab nav) ───────────────────────────────────
      // Tabs: Home · Activity · Insights · Settings (per spec).
      // Sleep is a metric detail/trend view — it lives outside the shell so
      // the bottom nav is hidden when drilling into a metric.
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen()),
          GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),

      // ── Metric detail / trend-view screens (push, no bottom nav) ────────
      GoRoute(path: '/sleep', builder: (_, __) => const SleepScreen()),
      GoRoute(path: '/heart-rate', builder: (_, __) => const HeartRateScreen()),
      GoRoute(path: '/spo2', builder: (_, __) => const SpO2Screen()),
      GoRoute(path: '/hrv', builder: (_, __) => const HrvScreen()),
      GoRoute(path: '/blood-pressure', builder: (_, __) => const BloodPressureScreen()),
      GoRoute(path: '/stress', builder: (_, __) => const StressScreen()),
      GoRoute(path: '/recovery', builder: (_, __) => const RecoveryScreen()),
      GoRoute(path: '/workouts', builder: (_, __) => const WorkoutsScreen()),
      GoRoute(path: '/one-key', builder: (_, __) => const OneKeyMeasurementScreen()),

      // ── Utility screens ──────────────────────────────────────────────────
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/pairing', builder: (_, __) => const PairingScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/debug', builder: (_, __) => const BleDebugScreen()),
      GoRoute(
        path: '/data-details',
        builder: (_, state) => DataDetailsScreen(
          metric: state.uri.queryParameters['metric'] ?? 'unknown',
        ),
      ),
      GoRoute(
        path: '/settings/device',
        builder: (_, __) => const DeviceSettingsScreen(),
      ),
    ],
  );
});

/// Lightweight `Listenable` that go_router uses as a refresh trigger.
/// Bumped whenever auth state changes OR user-profile state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
