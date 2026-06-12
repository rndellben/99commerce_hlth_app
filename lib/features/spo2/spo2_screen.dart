import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Blood Oxygen detail screen. The H59 doesn't push SpO2 continuously
/// (the band only measures when scheduled or actively triggered), so
/// "Measure Now" runs an on-demand `manualModeSpO2` measurement — same
/// path the BLE Debug "Stream SpO2" button uses. ~30-60s round trip;
/// one final % value when the band converges.
class SpO2Screen extends ConsumerStatefulWidget {
  const SpO2Screen({super.key});

  @override
  ConsumerState<SpO2Screen> createState() => _SpO2ScreenState();
}

class _SpO2ScreenState extends ConsumerState<SpO2Screen> {
  bool _measuring = false;
  int? _liveSpo2;
  int? _liveHr;
  StreamSubscription<({int spo2, int hr})>? _sub;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    if (_measuring) {
      // Best-effort: tell the band to stop if we leave mid-measurement.
      ref.read(bleServiceProvider).stopSpo2Stream();
    }
    super.dispose();
  }

  Future<void> _measureNow() async {
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _measuring = true;
      _liveSpo2 = null;
      _liveHr = null;
    });
    _sub?.cancel();
    _sub = ble.spo2Stream.listen((t) {
      if (!mounted) return;
      setState(() {
        _liveSpo2 = t.spo2;
        _liveHr = t.hr;
      });
      // First good reading is the band's converged value — auto-stop.
      _finish();
    });
    // Safety timeout — band sometimes never converges (poor contact).
    _timeoutTimer = Timer(const Duration(seconds: 75), () {
      if (mounted && _measuring) _finish(timedOut: true);
    });

    try {
      await ble.startSpo2Stream();
    } catch (e) {
      _finish();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start measurement: $e')),
        );
      }
    }
  }

  Future<void> _finish({bool timedOut = false}) async {
    _sub?.cancel();
    _sub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    try {
      await ref.read(bleServiceProvider).stopSpo2Stream();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _measuring = false);
    if (timedOut && _liveSpo2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Measurement timed out — make sure the band is snug and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(latestSpo2SampleProvider).valueOrNull;
    final today = ref.watch(todayDailyMetricsProvider).valueOrNull;
    final connectedAsync = ref.watch(bleConnectionStateProvider);
    final connected = connectedAsync.maybeWhen(
      data: (s) => s == BleConnectionState.connected,
      orElse: () => false,
    );

    // Headline value priority: live in-flight reading → latest stored
    // sample → placeholder.
    final headlineValue =
        _liveSpo2?.toString() ?? latest?.pctMin.toString() ?? '--';
    final headlineSubtitle = _measuring
        ? (_liveSpo2 == null
            ? 'Measuring... wear the band snugly'
            : 'Live reading')
        : (latest != null
            ? 'Last reading ${_timeAgo(latest.capturedAt)}'
            : (connected
                ? 'Tap Measure Now to get a reading'
                : 'Connect your band to measure SpO2'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Oxygen'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.air, color: AppColors.spo2, size: 48),
            const SizedBox(height: 16),
            Text(
              headlineValue,
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(color: AppColors.spo2),
            ),
            Text(
              '% SpO2',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_measuring)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.spo2),
                  ),
                if (_measuring) const SizedBox(width: 8),
                Text(headlineSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (_liveHr != null && _measuring) ...[
              const SizedBox(height: 4),
              Text('HR during read: $_liveHr bpm',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
            ],
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
                  Text('Overnight Average',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    today?.spo2OvernightAvg == null
                        ? '-- %'
                        : '${today!.spo2OvernightAvg!.toStringAsFixed(0)} %',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.spo2),
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
                    : const Icon(Icons.air),
                label: Text(_measuring ? 'Measuring...' : 'Measure Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spo2,
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
            if (connected && !_measuring)
              Text(
                'Takes ~30-60s. Keep the band snug and your hand still.',
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
