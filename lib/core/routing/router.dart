import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/features/activity/activity_screen.dart';
import 'package:hlth_app/features/blood_pressure/blood_pressure_screen.dart';
import 'package:hlth_app/features/debug/ble_debug_screen.dart';
import 'package:hlth_app/features/heart_rate/heart_rate_screen.dart';
import 'package:hlth_app/features/home/home_screen.dart';
import 'package:hlth_app/features/onboarding/onboarding_screen.dart';
import 'package:hlth_app/features/one_key/one_key_measurement_screen.dart';
import 'package:hlth_app/features/recovery/recovery_screen.dart';
import 'package:hlth_app/features/settings/device_settings_screen.dart';
import 'package:hlth_app/features/settings/settings_screen.dart';
import 'package:hlth_app/features/sleep/sleep_screen.dart';
import 'package:hlth_app/features/spo2/spo2_screen.dart';
import 'package:hlth_app/ui/widgets/shell_screen.dart';

/// GoRouter wrapped in a provider so it can react to the
/// `userProfileProvider` and redirect users into onboarding until they
/// finish setup.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _ProfileRefreshNotifier();
  ref.listen(userProfileProvider, (_, __) => notifier.bump());
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final profileAsync = ref.read(userProfileProvider);
      // While loading, don't redirect — initialLocation handles the splash case.
      if (profileAsync.isLoading) return null;
      final hasProfile = profileAsync.valueOrNull != null;
      final goingToOnboarding = state.matchedLocation == '/onboarding';
      // Allow /debug always — useful while iterating without a profile.
      if (state.matchedLocation == '/debug') return null;
      if (!hasProfile && !goingToOnboarding) return '/onboarding';
      if (hasProfile && goingToOnboarding) return '/';
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
    ],
  );
});

/// Lightweight `Listenable` that go_router uses as a refresh trigger. We
/// bump it whenever `userProfileProvider` emits a new value.
class _ProfileRefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}
