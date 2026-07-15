import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/models/health_samples.dart';
import 'package:hlth_app/core/repositories/device_repository.dart';
import 'package:hlth_app/core/sync/band_sync_service.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';

/// Stress detail screen.
///
/// Mirrors QWatch's stress UX: headline value with zone label
/// (Relax 0-29 / Normal 30-59 / Medium 60-79 / High 80-100), a bar chart
/// of today's samples, and a Scheduled-monitoring toggle backed by the
/// band's `PressureSettingReq` on/off. No interval picker — band uses
/// its own ~30 min slot cadence.
class StressScreen extends ConsumerStatefulWidget {
  const StressScreen({super.key});

  @override
  ConsumerState<StressScreen> createState() => _StressScreenState();
}

class _StressScreenState extends ConsumerState<StressScreen> {
  bool? _scheduledEnabled;
  bool _scheduledBusy = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadScheduled();
    // Kick off a sync on entry so the screen doesn't show "no samples"
    // until the next 30-min periodic tick lands. No-op when disconnected.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromBand());
  }

  Future<void> _refreshFromBand() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final device = await ref
          .read(deviceRepositoryProvider)
          .getActiveForUser(ActiveSession.defaultUserId);
      if (device == null) return; // not paired
      final sync = ref.read(bandSyncServiceProvider);
      // Pull today + yesterday — H59 sometimes files samples under the
      // wear day's index rather than the sync day, per the HRV quirk.
      final today = await sync.syncStress(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
        dayOffset: 0,
      );
      final yesterday = await sync.syncStress(
        userId: ActiveSession.defaultUserId,
        deviceId: device.id,
        dayOffset: 1,
      );
      if (mounted) {
        final total = today.count + yesterday.count;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(total == 0
                ? 'No new strain samples on band yet'
                : 'Synced $total strain sample(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _loadScheduled() async {
    try {
      final cfg = await ref.read(bleServiceProvider).getStressScheduled();
      if (!mounted) return;
      setState(() => _scheduledEnabled = cfg['isEnable'] as bool?);
    } catch (_) {
      // Disconnected — leave null so UI shows "Connect the band".
    }
  }

  Future<void> _toggleScheduled(bool enabled) async {
    final ble = ref.read(bleServiceProvider);
    setState(() {
      _scheduledBusy = true;
      // Optimistic — same H59 ack quirk as HR/SpO2/HRV/BP: write-ack is
      // unreliable, reconcile via a read 1.5s later.
      _scheduledEnabled = enabled;
    });
    try {
      await ble.setStressScheduled(enabled: enabled);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      try {
        final cfg = await ble.getStressScheduled();
        if (!mounted) return;
        setState(() => _scheduledEnabled = cfg['isEnable'] as bool? ?? enabled);
      } catch (_) {
        // Read-back failed — keep optimistic state.
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scheduledEnabled = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scheduledBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(latestStressSampleProvider).valueOrNull;
    final today = ref.watch(todayStressSamplesProvider).valueOrNull ?? const [];

    return MetricTrendScaffold(
      metricName: 'Stress',
      allowAddEdit: false,
      aboutTitle: 'Stress',
      aboutText: 'The stress score reflects your body\'s physiological stress level based on heart rate variability patterns. Lower scores indicate a more relaxed state.',
      extraActions: [
        IconButton(
          icon: _syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          tooltip: 'Sync strain from band',
          onPressed: _syncing ? null : _refreshFromBand,
        ),
      ],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshFromBand,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),
              _Headline(latest: latest),
              const SizedBox(height: 28),
              _DayChart(samples: today),
              const SizedBox(height: 20),
              _ZoneBreakdown(samples: today),
              const SizedBox(height: 20),
              _ScheduledCard(
                enabled: _scheduledEnabled,
                busy: _scheduledBusy,
                onToggle: _toggleScheduled,
              ),
              const SizedBox(height: 20),
              DataDetailsCard(metric: 'stress'),
              const SizedBox(height: 16),
              Last7DaysTile(
                metric: 'stress',
                averageValue: null,
                unit: '',
                color: AppColors.warning,
              ),
              const SizedBox(height: 16),
              AboutMetricSection(
                title: 'About Stress',
                body: 'The stress score reflects your body\'s physiological stress level based on heart rate variability patterns. Lower scores indicate a more relaxed state.',
              ),
              const SizedBox(height: 20),
              const Text(
                'The band measures strain automatically using HRV. Wear it during '
                'the day for a full picture.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.latest});
  final StressSample? latest;

  @override
  Widget build(BuildContext context) {
    final score = latest?.stressScore;
    return Column(
      children: [
        Icon(Icons.spa_outlined,
            color: _zoneColor(score), size: 48),
        const SizedBox(height: 12),
        Text(
          score?.toString() ?? '--',
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(color: _zoneColor(score)),
        ),
        Text(
          score == null ? 'No reading yet' : _zoneLabel(score),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _zoneColor(score),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          latest == null
              ? 'Wear the band so the next scheduled measurement can sync'
              : 'Last reading ${_timeAgo(latest!.capturedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DayChart extends StatelessWidget {
  const _DayChart({required this.samples});
  final List<StressSample> samples;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's strain",
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: samples.isEmpty
                ? Center(
                    child: Text(
                      'No samples synced yet today',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _StressBarsPainter(samples),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('00:00',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
              Text('12:00',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
              Text('23:59',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StressBarsPainter extends CustomPainter {
  _StressBarsPainter(this.samples);
  final List<StressSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    // Anchor on the local midnight of the first sample.
    final first = samples.first.capturedAt.toLocal();
    final dayStart = DateTime(first.year, first.month, first.day);
    const dayMs = 24 * 60 * 60 * 1000;
    final barWidth = (size.width / 48).clamp(2.0, 6.0); // ~30-min slots

    for (final s in samples) {
      final local = s.capturedAt.toLocal();
      final offsetMs = local.difference(dayStart).inMilliseconds;
      final fx = offsetMs / dayMs; // 0..1 across the day
      final x = fx * size.width;
      final height = (s.stressScore / 100.0) * size.height;
      final color = _zoneColor(s.stressScore);
      canvas.drawRect(
        Rect.fromLTWH(
            x - barWidth / 2, size.height - height, barWidth, height),
        Paint()..color = color,
      );
    }

    // Zone bands as horizontal guides (very subtle).
    final guidePaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.15);
    for (final zone in const [29, 59, 79]) {
      final y = size.height - (zone / 100.0) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }
  }

  @override
  bool shouldRepaint(_StressBarsPainter old) => old.samples != samples;
}

class _ZoneBreakdown extends StatelessWidget {
  const _ZoneBreakdown({required this.samples});
  final List<StressSample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();
    final relax = samples.where((s) => s.stressScore < 30).length;
    final normal =
        samples.where((s) => s.stressScore >= 30 && s.stressScore < 60).length;
    final medium =
        samples.where((s) => s.stressScore >= 60 && s.stressScore < 80).length;
    final high = samples.where((s) => s.stressScore >= 80).length;
    final total = samples.length;
    String pct(int n) =>
        total == 0 ? '0%' : '${((n / total) * 100).round()}%';
    final scores = samples.map((s) => s.stressScore).toList();
    scores.sort();
    final min = scores.first;
    final max = scores.last;
    final avg = (scores.reduce((a, b) => a + b) / scores.length).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day summary',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(context, 'Average', avg.toString()),
              _stat(context, 'Min', min.toString()),
              _stat(context, 'Max', max.toString()),
            ],
          ),
          const SizedBox(height: 16),
          _zoneRow('Relax', '0-29', _zoneColor(15), pct(relax)),
          const SizedBox(height: 6),
          _zoneRow('Normal', '30-59', _zoneColor(45), pct(normal)),
          const SizedBox(height: 6),
          _zoneRow('Medium', '60-79', _zoneColor(70), pct(medium)),
          const SizedBox(height: 6),
          _zoneRow('High', '80-100', _zoneColor(90), pct(high)),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }

  Widget _zoneRow(String label, String range, Color color, String pct) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text('$label  $range', style: const TextStyle(fontSize: 13))),
        Text(pct,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({
    required this.enabled,
    required this.busy,
    required this.onToggle,
  });
  final bool? enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: SwitchListTile(
        secondary: const Icon(Icons.schedule, color: AppColors.warning),
        title: const Text('Strain Detection'),
        subtitle: Text(
          enabled == null
              ? 'Connect the band to view status'
              : enabled!
                  ? 'Auto-measures throughout the day'
                  : 'Off — only synced if the band has prior data',
        ),
        value: enabled ?? false,
        onChanged:
            (busy || enabled == null) ? null : (v) => onToggle(v),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

Color _zoneColor(int? score) {
  if (score == null) return AppColors.textTertiary;
  if (score < 30) return const Color(0xFF2ED573); // green — relax
  if (score < 60) return const Color(0xFF3742FA); // blue — normal
  if (score < 80) return AppColors.warning; // amber — medium
  return AppColors.error; // red — high
}

String _zoneLabel(int score) {
  if (score < 30) return 'Relax';
  if (score < 60) return 'Normal';
  if (score < 80) return 'Medium';
  return 'High';
}

String _timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(t.toUtc());
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
