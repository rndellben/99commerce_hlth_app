import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/services/feature_gate.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/health_metric_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(featureGateProvider);
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final latestHr = ref.watch(latestHrSampleProvider).valueOrNull;
    final latestSpo2 = ref.watch(latestSpo2SampleProvider).valueOrNull;
    final latestHrv = ref.watch(latestHrvSampleProvider).valueOrNull;
    final latestBp = ref.watch(latestBpReadingProvider).valueOrNull;
    final hrSpark = ref.watch(hrSparklineProvider).valueOrNull ?? const [];
    final spo2Spark =
        ref.watch(spo2SparklineProvider).valueOrNull ?? const [];
    final hrvSpark = ref.watch(hrvSparklineProvider).valueOrNull ?? const [];
    final bpSpark = ref.watch(bpSparklineProvider).valueOrNull ?? const [];
    final todayLabel = _todayDateLabel();

    // Realtime HR (from band stream) takes precedence over stored samples.
    final ble = ref.watch(bleServiceProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                  const _ConnectionChip(),
                ],
              ),
            ),
          ),

          if (gate.onboardingProgress < 1.0)
            SliverToBoxAdapter(
              child: _OnboardingCard(gate: gate),
            ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                StreamBuilder<int>(
                  stream: ble.realtimeHeartRate,
                  builder: (context, snap) {
                    final realtime = snap.data;
                    final value = realtime?.toString() ??
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
                HealthMetricCard(
                  title: 'Blood Pressure',
                  value: latestBp == null
                      ? '--'
                      : '${latestBp.systolicMmhg}/${latestBp.diastolicMmhg}',
                  unit: latestBp == null ? '' : 'mmHg',
                  icon: Icons.monitor_heart_outlined,
                  color: AppColors.bloodPressure,
                  date: todayLabel,
                  sparkline: bpSpark,
                  onTap: () => context.push('/blood-pressure'),
                ),
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
                ),
                HealthMetricCard(
                  title: 'One Key',
                  value: 'Tap',
                  unit: '',
                  icon: Icons.touch_app,
                  color: AppColors.recovery,
                  onTap: () => context.push('/one-key'),
                ),
                HealthMetricCard(
                  title: 'Steps',
                  value: today?.steps?.toString() ?? '--',
                  unit: '',
                  icon: Icons.directions_walk,
                  color: AppColors.activity,
                  date: todayLabel,
                  onTap: () => context.push('/activity'),
                ),
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
                HealthMetricCard(
                  title: 'Resting HR',
                  value: today?.restingHrBpm?.toString() ?? '--',
                  unit: 'bpm',
                  icon: Icons.monitor_heart,
                  color: AppColors.heartRate,
                  date: todayLabel,
                ),
                HealthMetricCard(
                  title: 'Recovery',
                  value: today?.recoveryScore?.toString() ?? '--',
                  unit: '/100',
                  icon: Icons.battery_charging_full,
                  color: AppColors.recovery,
                  isLocked: !gate.recoveryScore,
                  lockedMessage:
                      'Available in ${gate.daysUntilRecovery} days',
                  onTap: () => context.push('/recovery'),
                ),
                HealthMetricCard(
                  title: 'Body Age',
                  value: '--',
                  unit: '',
                  icon: Icons.person_outline,
                  color: AppColors.primary,
                  isLocked: !gate.bodyAgePreliminary,
                  lockedMessage: 'Available in ${gate.daysUntilBodyAge} days',
                ),
              ]),
            ),
          ),

          SliverToBoxAdapter(
            child: _UnlockingSoonSection(gate: gate),
          ),

          // Mandatory regulatory disclaimer — hlth-regulatory-language-guide.md
          // §"Required Disclaimers".
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'This is a wellness feature, not a medical device. Not intended '
                'to diagnose, treat, or prevent any condition. Consult your '
                'healthcare provider for medical advice.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
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
}

class _OnboardingCard extends StatelessWidget {
  final FeatureGate gate;
  const _OnboardingCard({required this.gate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.primary),
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

class _UnlockingSoonSection extends StatelessWidget {
  final FeatureGate gate;
  const _UnlockingSoonSection({required this.gate});

  @override
  Widget build(BuildContext context) {
    final entries = <_UnlockEntry>[];
    if (!gate.sleepStaging) {
      entries.add(_UnlockEntry(
        label: 'Sleep Staging',
        message: (3 - gate.daysSinceFirstWear).clamp(0, 3) <= 0
            ? 'Ready after tonight'
            : 'In ${(3 - gate.daysSinceFirstWear).clamp(0, 3)} more nights',
      ));
    }
    if (!gate.recoveryScore) {
      entries.add(_UnlockEntry(
        label: 'Recovery Score',
        message: 'In ${gate.daysUntilRecovery} more days',
      ));
    }
    if (!gate.bodyAgePreliminary) {
      entries.add(_UnlockEntry(
        label: 'Body Age',
        message: 'In ${gate.daysUntilBodyAge} more days',
      ));
    }
    if (!gate.illnessWarning) {
      entries.add(_UnlockEntry(
        label: 'Illness Warning',
        message: 'In ${gate.daysUntilIllnessWarning} more days',
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
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
            ...entries.map((e) => Padding(
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
                )),
          ],
        ),
      ),
    );
  }
}

class _UnlockEntry {
  final String label;
  final String message;
  _UnlockEntry({required this.label, required this.message});
}

/// Chip showing real BLE connection state. Tap to open BLE Debug.
class _ConnectionChip extends ConsumerWidget {
  const _ConnectionChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(bleConnectionStateProvider);
    final connected = stateAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );
    final color = connected ? AppColors.success : AppColors.textTertiary;
    final label = connected ? 'Connected' : 'Not connected';
    final icon =
        connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled;

    return InkWell(
      onTap: () => context.push('/debug'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
