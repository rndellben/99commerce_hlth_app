import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/features/activity/activity_screen.dart';
import 'package:hlth_app/features/auth/auth_screen.dart';
import 'package:hlth_app/features/auth/privacy_screen.dart';
import 'package:hlth_app/features/blood_pressure/blood_pressure_screen.dart';
import 'package:hlth_app/features/debug/ble_debug_screen.dart';
import 'package:hlth_app/features/heart_rate/heart_rate_screen.dart';
import 'package:hlth_app/features/home/home_screen.dart';
import 'package:hlth_app/features/hrv/hrv_screen.dart';
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

      // Always allow /debug — useful while iterating without a profile.
      if (loc == '/debug') return null;

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
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/sleep', builder: (context, state) => const SleepScreen()),
          GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/heart-rate', builder: (context, state) => const HeartRateScreen()),
      GoRoute(path: '/spo2', builder: (context, state) => const SpO2Screen()),
      GoRoute(path: '/recovery', builder: (context, state) => const RecoveryScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/debug', builder: (context, state) => const BleDebugScreen()),
      GoRoute(
        path: '/settings/device',
        builder: (context, state) => const DeviceSettingsScreen(),
      ),
      GoRoute(
        path: '/one-key',
        builder: (context, state) => const OneKeyMeasurementScreen(),
      ),
      GoRoute(
        path: '/blood-pressure',
        builder: (context, state) => const BloodPressureScreen(),
      ),
      GoRoute(
        path: '/stress',
        builder: (context, state) => const StressScreen(),
      ),
      GoRoute(
        path: '/workouts',
        builder: (context, state) => const WorkoutsScreen(),
      ),
      GoRoute(
        path: '/hrv',
        builder: (context, state) => const HrvScreen(),
      ),
      GoRoute(
        path: '/pairing',
        builder: (context, state) => const PairingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
    ],
  );
});

/// Lightweight `Listenable` that go_router uses as a refresh trigger.
/// Bumped whenever auth state changes OR user-profile state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
