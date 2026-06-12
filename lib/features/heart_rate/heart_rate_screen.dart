import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Heart Rate detail screen. Shows the band's RT HR (realtime
/// heart-rate stream pushed via `DeviceNotifyListener`) as the headline
/// value — same source the Home dashboard HR card consumes. Falls back
/// to the latest stored DB sample when the band isn't pushing yet.
///
/// "Measure Now" briefly toggles the band into continuous monitoring
/// mode (`startMeasureHrRaw`) which guarantees a tick within a few
/// seconds even if the band was idling.
class HeartRateScreen extends ConsumerStatefulWidget {
  const HeartRateScreen({super.key});

  @override
  ConsumerState<HeartRateScreen> createState() => _HeartRateScreenState();
}

class _HeartRateScreenState extends ConsumerState<HeartRateScreen> {
  bool _measuring = false;

  Future<void> _measureNow() async {
    final ble = ref.read(bleServiceProvider);
    setState(() => _measuring = true);
    try {
      // Wake the band into a brief continuous-read window so RT HR
      // updates within seconds. 30s window is plenty for a UX-grade
      // "tap-to-measure" interaction.
      await ble.startMeasureHrRaw(durationSec: 30);
    } catch (_) {
      // Non-fatal — RT HR stream will still emit when band pushes its
      // next routine update.
    }
    // Leave _measuring=true for a short visual cooldown; band may
    // continue streaming for ~30s but we don't need to block the UI.
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _measuring = false);
  }

  @override
  Widget build(BuildContext context) {
    final ble = ref.watch(bleServiceProvider);
    final latestHr = ref.watch(latestHrSampleProvider).valueOrNull;
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heart Rate'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.favorite, color: AppColors.heartRate, size: 48),
            const SizedBox(height: 16),
            StreamBuilder<int>(
              stream: ble.realtimeHeartRate,
              builder: (context, snap) {
                final realtime = snap.data;
                final value = realtime?.toString() ??
                    latestHr?.bpm.toString() ??
                    '--';
                final source = realtime != null
                    ? 'Live'
                    : (latestHr != null
                        ? 'Last reading ${_timeAgo(latestHr.capturedAt)}'
                        : (connected
                            ? 'Waiting for band update...'
                            : 'Connect your band to see live HR'));
                return Column(
                  children: [
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(color: AppColors.heartRate),
                    ),
                    Text(
                      'bpm',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (realtime != null) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          source,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Resting Heart Rate',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    today?.restingHrBpm == null
                        ? '-- bpm'
                        : '${today!.restingHrBpm} bpm',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.heartRate),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    !connected || _measuring ? null : _measureNow,
                icon: _measuring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.favorite),
                label: Text(_measuring ? 'Measuring...' : 'Measure Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.heartRate,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!connected)
              Text(
                'Connect your band from the Settings tab to enable Measure.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().toUtc().difference(t.toUtc());
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
