import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/services/feature_gate.dart';
import 'package:hlth_app/core/services/scheduled_ppg_capture_service.dart';
import 'package:hlth_app/core/services/supabase_connection_monitor.dart';
import 'package:hlth_app/core/providers/bp_calibration_providers.dart';
import 'package:hlth_app/core/providers/device_status_providers.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/health_metric_card.dart';
import 'package:hlth_app/ui/widgets/shell_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeCaptureRespiratory());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeCaptureRespiratory() {
    if (!mounted) return;
    ref
        .read(scheduledPpgCaptureServiceProvider)
        .maybeRunDaily(userId: ActiveSession.defaultUserId);
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Capture when the band (re)connects so a mid-session connect refreshes
    // respiratory without waiting for the next periodic tick.
    ref.listen<AsyncValue<BleConnectionState>>(
      bleConnectionStateProvider,
      (prev, next) {
        if (next.valueOrNull == BleConnectionState.connected) {
          _maybeCaptureRespiratory();
        }
      },
    );

    final gate = ref.watch(featureGateProvider);
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final latestHr = ref.watch(latestHrSampleProvider).valueOrNull;
    final latestSpo2 = ref.watch(latestSpo2SampleProvider).valueOrNull;
    final latestHrv = ref.watch(latestHrvSampleProvider).valueOrNull;
    final latestBpPair = ref.watch(calibratedLatestBpProvider).valueOrNull;
    final latestStress = ref.watch(latestStressSampleProvider).valueOrNull;
    final recoveryScore = ref.watch(latestRecoveryScoreProvider).valueOrNull;
    final cardioLoadScore =
        ref.watch(latestCardioLoadScoreProvider).valueOrNull;
    final hrSpark = ref.watch(hrSparklineProvider).valueOrNull ?? const [];
    final spo2Spark =
        ref.watch(spo2SparklineProvider).valueOrNull ?? const [];
    final hrvSpark = ref.watch(hrvSparklineProvider).valueOrNull ?? const [];
    final bpSpark = ref.watch(bpSparklineProvider).valueOrNull ?? const [];
    final stressSpark =
        ref.watch(stressSparklineProvider).valueOrNull ?? const [];
    final todayLabel = _todayDateLabel();
    final ble = ref.watch(bleServiceProvider);
    final alerts = ref.watch(activeHomeAlertsProvider).valueOrNull ?? const [];

    return TabScrollNotifier(
      scrollToTop: _scrollToTop,
      child: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Header ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HomeHeader(gate: gate),
            ),

            // ── Onboarding progress card (days 0-13) ───────────────────────
            if (gate.onboardingProgress < 1.0)
              SliverToBoxAdapter(
                child: _OnboardingCard(gate: gate),
              ),

            // ── In-app alert banners ───────────────────────────────────────
            if (alerts.isNotEmpty)
              SliverToBoxAdapter(
                child: _AlertBannerList(alerts: alerts),
              ),

            // ── Metric tiles — spec order ──────────────────────────────────
            // 1. Health Score  2. Cardio Load  3. Stability (Recovery)
            // 4. Blood Pressure  5. Heart Rate  6. Sleep
            // 7. Stress  8. Activity  9. HRV  10. SpO2
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                delegate: SliverChildListDelegate([
                  // 1 — Health Score (composite — not yet computed)
                  HealthMetricCard(
                    title: 'Health Score',
                    value: '--',
                    unit: '',
                    icon: Icons.monitor_heart_outlined,
                    color: AppColors.primary,
                    isLocked: true,
                    lockedMessage: 'Coming soon',
                  ),

                  // 2 — Cardio Load Score
                  HealthMetricCard(
                    title: 'Cardio Load',
                    value:
                        cardioLoadScore?.score.round().toString() ?? '--',
                    unit: cardioLoadScore == null ? '' : '/100',
                    icon: Icons.favorite_border,
                    color: AppColors.heartRate,
                    date: cardioLoadScore == null
                        ? 'Building baseline'
                        : (cardioLoadScore.provisional
                            ? 'Calibrating'
                            : cardioLoadScore.label),
                  ),

                  // 3 — Stability Score (= Recovery)
                  HealthMetricCard(
                    title: 'Stability',
                    value:
                        recoveryScore?.score.round().toString() ?? '--',
                    unit: '/100',
                    icon: Icons.battery_charging_full,
                    color: AppColors.recovery,
                    date: recoveryScore == null
                        ? null
                        : (recoveryScore.provisional
                            ? 'Calibrating'
                            : recoveryScore.label),
                    isLocked:
                        recoveryScore == null && !gate.recoveryScore,
                    lockedMessage:
                        'Available in ${gate.daysUntilRecovery} days',
                    onTap: () => context.push('/recovery'),
                  ),

                  // 4 — Blood Pressure
                  HealthMetricCard(
                    title: 'Blood Pressure',
                    value: latestBpPair == null
                        ? '--'
                        : '${latestBpPair.displaySbp}/${latestBpPair.displayDbp}',
                    unit: latestBpPair == null ? '' : 'mmHg',
                    icon: Icons.monitor_heart_outlined,
                    color: AppColors.bloodPressure,
                    date: todayLabel,
                    sparkline: bpSpark,
                    // First-time → calibration flow; returning → trend view.
                    onTap: () => context.push('/blood-pressure'),
                  ),

                  // 5 — Heart Rate (realtime takes precedence over stored;
                  // seeded stream replays the last fresh push so this card
                  // and the Heart Rate screen always agree)
                  StreamBuilder<int>(
                    stream: ble.realtimeHeartRateSeeded,
                    builder: (context, snap) {
                      final value = snap.data?.toString() ??
                          latestHr?.bpm.toString() ??
                          '--';
                      return HealthMetricCard(
                        title: 'Heart Rate',
                        value: value,
                        unit: 'bpm',
                        icon: Icons.favorite,
                        color: AppColors.heartRate,
                        date: todayLabel,
                        sparkline: hrSpark,
                        onTap: () => context.push('/heart-rate'),
                      );
                    },
                  ),

                  // 6 — Sleep
                  HealthMetricCard(
                    title: 'Sleep',
                    value: _formatSleep(today?.sleepTotalMin),
                    unit: today?.sleepTotalMin == null ? '' : 'h',
                    icon: Icons.bedtime,
                    color: AppColors.sleep,
                    isLocked: !gate.basicSleep,
                    lockedMessage: 'After your first night',
                    onTap: () => context.push('/sleep'),
                  ),

                  // 7 — Stress
                  HealthMetricCard(
                    title: 'Stress',
                    value:
                        latestStress?.stressScore.toString() ?? '--',
                    unit: latestStress == null
                        ? ''
                        : _stressLabel(latestStress.stressScore),
                    icon: Icons.spa_outlined,
                    color: AppColors.warning,
                    date: todayLabel,
                    sparkline: stressSpark,
                    onTap: () => context.push('/stress'),
                  ),

                  // 8 — Activity (steps)
                  HealthMetricCard(
                    title: 'Activity',
                    value: today?.steps?.toString() ?? '--',
                    unit: 'steps',
                    icon: Icons.directions_walk,
                    color: AppColors.activity,
                    date: todayLabel,
                    onTap: () => context.go('/activity'),
                  ),

                  // 9 — HRV
                  HealthMetricCard(
                    title: 'HRV',
                    value: latestHrv?.rmssdMs.toStringAsFixed(0) ??
                        today?.hrvRmssdMs?.toStringAsFixed(0) ??
                        '--',
                    unit: 'ms',
                    icon: Icons.show_chart,
                    color: AppColors.respiratory,
                    date: todayLabel,
                    sparkline: hrvSpark,
                    onTap: () => context.push('/hrv'),
                  ),

                  // 10 — SpO2
                  HealthMetricCard(
                    title: 'SpO2',
                    value: latestSpo2?.pctMin.toString() ?? '--',
                    unit: '%',
                    icon: Icons.air,
                    color: AppColors.spo2,
                    date: todayLabel,
                    sparkline: spo2Spark,
                    onTap: () => context.push('/spo2'),
                  ),
                ]),
              ),
            ),

            // ── Unlocking soon ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _UnlockingSoonSection(gate: gate),
            ),

            // ── Regulatory disclaimer ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  'This is a wellness feature, not a medical device. Not '
                  'intended to diagnose, treat, or prevent any condition. '
                  'Consult your healthcare provider for medical advice.',
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSleep(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h.${(m * 10 / 60).round()}';
  }

  String _todayDateLabel() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String _stressLabel(int score) {
    if (score < 30) return 'Relax';
    if (score < 60) return 'Normal';
    if (score < 80) return 'Medium';
    return 'High';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

/// Home screen header implementing the four device states from the spec:
///
///   Unpaired              — red-dot device icon, no battery, Add button
///   Paired + offline      — device icon, battery %, airplane icon, sync button
///   Paired + online       — device icon, battery %, connected icon, sync button
///   Paired + online + syncing — device icon, battery %, syncing icon, (spinner)
///   + Firmware available  — "Update" button replaces sync button
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.gate});
  final FeatureGate gate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleConnectionStateProvider).valueOrNull ??
        BleConnectionState.disconnected;
    final battery = ref.watch(bleBatteryProvider).valueOrNull;
    final cloudHealth = ref.watch(connectionHealthProvider);
    final isSyncing = ref.watch(isSyncingProvider).valueOrNull ?? false;
    final firmwareUpdate = ref.watch(firmwareUpdateAvailableProvider);
    // isPaired = a device record exists in the DB (firstWearDate is set).
    // Checking daysSinceFirstWear > 0 would incorrectly mark day-0 users as
    // unpaired when BLE is temporarily disconnected.
    final isPaired = ref.watch(firstWearDateProvider).valueOrNull != null ||
        bleState == BleConnectionState.connected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // ── Left: branding + greeting ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HLTH',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  _greeting(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),

          // ── Right: device status cluster ─────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Device icon (+ red dot when unpaired)
              _DeviceStatusIcon(isPaired: isPaired),

              // Battery % — only when paired and battery data is available
              if (isPaired && battery != null) ...[
                const SizedBox(width: 6),
                _BatteryChip(battery: battery),
              ],

              const SizedBox(width: 8),

              // Connection status icon
              if (isPaired)
                _ConnectionStatusIcon(
                  isSyncing: isSyncing,
                  cloudHealth: cloudHealth,
                ),

              const SizedBox(width: 6),

              // Action button: Update > Sync (paired) | Add (unpaired)
              if (firmwareUpdate)
                _HeaderButton(
                  icon: Icons.system_update_alt,
                  label: 'Update',
                  color: AppColors.warning,
                  onTap: () => context.push('/settings/device'),
                )
              else if (isPaired)
                _SyncButton()
              else
                _HeaderButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add',
                  color: AppColors.primary,
                  onTap: () => context.push('/pairing'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DeviceStatusIcon extends StatelessWidget {
  const _DeviceStatusIcon({required this.isPaired});
  final bool isPaired;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'BLE Debug',
      child: GestureDetector(
        onTap: () => context.push('/debug'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isPaired ? Icons.watch_outlined : Icons.watch_off_outlined,
              size: 22,
              color:
                  isPaired ? AppColors.textSecondary : AppColors.textTertiary,
            ),
            if (!isPaired)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BatteryChip extends StatelessWidget {
  const _BatteryChip({required this.battery});
  final ({int level, bool charging}) battery;

  @override
  Widget build(BuildContext context) {
    final color = battery.level > 20 ? AppColors.success : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          battery.charging
              ? Icons.battery_charging_full
              : _batteryIcon(battery.level),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(
          '${battery.level}%',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  IconData _batteryIcon(int level) {
    if (level > 80) return Icons.battery_full;
    if (level > 50) return Icons.battery_5_bar;
    if (level > 30) return Icons.battery_3_bar;
    if (level > 15) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }
}

class _ConnectionStatusIcon extends StatelessWidget {
  const _ConnectionStatusIcon({
    required this.isSyncing,
    required this.cloudHealth,
  });
  final bool isSyncing;
  final ConnectionHealth cloudHealth;

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
      );
    }
    final (icon, color, tooltip) = switch (cloudHealth) {
      ConnectionHealth.connected => (
          Icons.cloud_done_outlined,
          AppColors.success,
          'Connected',
        ),
      ConnectionHealth.offline => (
          Icons.airplanemode_active,
          AppColors.textTertiary,
          'Offline',
        ),
      ConnectionHealth.authExpired => (
          Icons.cloud_off_outlined,
          AppColors.warning,
          'Sign in required',
        ),
    };
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _SyncButton extends ConsumerWidget {
  const _SyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing =
        ref.watch(isSyncingProvider).valueOrNull ?? false;
    return IconButton(
      icon: const Icon(Icons.sync, size: 20),
      color: isSyncing ? AppColors.primary : AppColors.textSecondary,
      tooltip: 'Sync',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: isSyncing ? null : () {/* Sync triggered by native tick */},
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alert banners
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBannerList extends ConsumerWidget {
  const _AlertBannerList({required this.alerts});
  final List<HomeAlert> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: alerts
            .map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AlertBanner(alert: alert),
                ))
            .toList(),
      ),
    );
  }
}

class _AlertBanner extends ConsumerWidget {
  const _AlertBanner({required this.alert});
  final HomeAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon) = _style(alert.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _dismiss(ref),
            child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  void _dismiss(WidgetRef ref) {
    ref.read(dismissedAlertIdsProvider.notifier).update(
          (ids) => {...ids, alert.id},
        );
  }

  (Color, IconData) _style(HomeAlertType type) {
    return switch (type) {
      HomeAlertType.highBp => (AppColors.error, Icons.monitor_heart_outlined),
      HomeAlertType.irregularRhythm => (
          AppColors.warning,
          Icons.favorite_border
        ),
      HomeAlertType.sleepBreathing => (AppColors.spo2, Icons.bedtime_outlined),
      HomeAlertType.appUpdate => (AppColors.primary, Icons.system_update_alt),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding progress card
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.gate});
  final FeatureGate gate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day ${gate.daysSinceFirstWear} of 14',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: gate.onboardingProgress,
              backgroundColor: AppColors.surfaceLight,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              "Learning your body's patterns",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unlocking soon section
// ─────────────────────────────────────────────────────────────────────────────

class _UnlockingSoonSection extends StatelessWidget {
  const _UnlockingSoonSection({required this.gate});
  final FeatureGate gate;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, String message})>[];
    if (!gate.sleepStaging) {
      entries.add((
        label: 'Sleep Staging',
        message: (3 - gate.daysSinceFirstWear).clamp(0, 3) <= 0
            ? 'Ready after tonight'
            : 'In ${(3 - gate.daysSinceFirstWear).clamp(0, 3)} more nights',
      ));
    }
    if (!gate.recoveryScore) {
      entries.add((
        label: 'Stability Score',
        message: 'In ${gate.daysUntilRecovery} more days',
      ));
    }
    if (!gate.bodyAgePreliminary) {
      entries.add((
        label: 'Body Age',
        message: 'In ${gate.daysUntilBodyAge} more days',
      ));
    }
    if (!gate.illnessWarning) {
      entries.add((
        label: 'Illness Warning',
        message: 'In ${gate.daysUntilIllnessWarning} more days',
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlocking soon',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.label,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                    ),
                    Text(
                      e.message,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
