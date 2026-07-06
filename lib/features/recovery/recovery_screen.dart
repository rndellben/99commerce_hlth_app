import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/models/daily_metrics.dart';
import 'package:hlth_app/features/activity/activity_providers.dart';
import 'package:hlth_app/features/home/home_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/score_gauge.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';

/// Recovery (Stability) detail screen. Reads the same
/// `latestRecoveryScoreProvider` the home card uses, so the two never
/// disagree. Each contributing factor shows the night's RAW measurement
/// (bpm / ms / min), coloured by how that factor scored against the user's
/// baseline (the engine's 0–100 sub-score). Wrapped in the MVP
/// `MetricTrendScaffold` shell (about drawer + data-details + 7-day tile).
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  static const _aboutText =
      'The stability score reflects how consistently your body is recovering '
      'based on resting heart rate, HRV, and sleep patterns over the past '
      '14 days.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(latestRecoveryScoreProvider).valueOrNull;
    final components = score?.components ?? const <String, double>{};
    // The score is computed for a local date; pull that night's metrics so we
    // can show real values, not sub-scores.
    final forDate = score?.computedForDate ?? DateTime.now();
    final metrics = ref.watch(dailyMetricsForDateProvider(forDate)).valueOrNull;

    final String subtitle;
    if (score == null) {
      subtitle = 'Waiting for baseline data...';
    } else if (score.provisional) {
      subtitle = 'Calibrating — still building your baseline';
    } else {
      subtitle = score.label ?? 'Recovery';
    }

    return MetricTrendScaffold(
      metricName: 'Stability',
      allowAddEdit: false,
      aboutTitle: 'Stability',
      aboutText: _aboutText,
      extraActions: const [],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              ScoreGauge(
                score: score?.score.round() ?? 0,
                label: 'Recovery',
                size: 160,
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contributing Factors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              for (final f in _buildFactors(metrics))
                _FactorRow(
                  label: f.label,
                  icon: f.icon,
                  value: f.value,
                  color: _factorColor(components[f.key]),
                ),
              const SizedBox(height: 32),
              const DataDetailsCard(metric: 'recovery'),
              const SizedBox(height: 16),
              Last7DaysTile(
                metric: 'recovery',
                averageValue: null,
                unit: '/100',
                color: AppColors.recovery,
              ),
              const SizedBox(height: 16),
              const AboutMetricSection(
                title: 'About Stability',
                body: _aboutText,
              ),
              const SizedBox(height: 16),
              Text(
                'This is a wellness feature, not a medical device.',
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Engine component key → friendly label, icon, and the night's raw value.
  List<({String key, String label, IconData icon, String value})> _buildFactors(
      DailyMetrics? m) {
    final total = m?.sleepTotalMin ?? 0;
    String mins(double? pct) =>
        (pct == null || total == 0) ? '--' : '${(pct * total).round()} min';
    return [
      (
        key: 'hrv',
        label: 'HRV (overnight)',
        icon: Icons.show_chart,
        value: m?.hrvRmssdMs == null ? '--' : '${m!.hrvRmssdMs!.round()} ms',
      ),
      (
        key: 'hr',
        label: 'Resting HR',
        icon: Icons.favorite,
        value: m?.restingHrBpm == null ? '--' : '${m!.restingHrBpm} bpm',
      ),
      (
        key: 'deep',
        label: 'Deep sleep',
        icon: Icons.bedtime,
        value: mins(m?.sleepDeepPct),
      ),
      (
        key: 'rem',
        label: 'REM sleep',
        icon: Icons.nights_stay,
        value: mins(m?.sleepRemPct),
      ),
      (
        key: 'resp',
        label: 'Respiratory rate',
        icon: Icons.air,
        value: m?.restingRespRateBpm == null
            ? '--'
            : '${m!.restingRespRateBpm!.round()} br/min',
      ),
    ];
  }

  /// Colour a factor by its 0–100 sub-score: green = helping recovery,
  /// amber = neutral, red = dragging it down, grey = not available.
  Color _factorColor(double? subScore) {
    if (subScore == null) return AppColors.textSecondary;
    if (subScore >= 67) return AppColors.scoreGood;
    if (subScore >= 34) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }
}

class _FactorRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FactorRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
