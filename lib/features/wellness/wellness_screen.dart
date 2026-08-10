import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/providers/health_data_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/metric_trend_scaffold.dart';
import 'package:hlth_app/ui/widgets/score_gauge.dart';
import 'package:hlth_app/ui/widgets/trend_view_sections.dart';

/// Wellness Balance detail screen (advanced-health-features-build-guide.md §2).
/// Reads the same `latestWellnessScoreProvider` the home card uses, so the two
/// never disagree. Contributing factors are the engine's 0–100 sub-scores
/// (HRV, resting HR, sleep, activity, circadian), coloured by how each is
/// tracking. This is a wellness trend — never framed as a diagnosis.
class WellnessScreen extends ConsumerWidget {
  const WellnessScreen({super.key});

  static const _aboutText =
      'Your Wellness Balance is a weekly view of how your body is coping with '
      'stress, based on your heart rate variability, resting heart rate, sleep, '
      'activity, and daily rhythm compared with your own recent baseline. '
      'It is a trend indicator, not a diagnosis.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(latestWellnessScoreProvider).valueOrNull;
    final components = score?.components ?? const <String, double>{};

    final String subtitle;
    if (score == null) {
      subtitle = 'Waiting for baseline data...';
    } else if (score.provisional) {
      subtitle = 'Calibrating — still building your baseline';
    } else {
      subtitle = score.label ?? 'Wellness Balance';
    }

    return MetricTrendScaffold(
      metricName: 'Wellness Balance',
      allowAddEdit: false,
      aboutTitle: 'Wellness Balance',
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
                label: 'Balance',
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
              for (final f in _factors)
                if (components.containsKey(f.key))
                  _FactorRow(
                    label: f.label,
                    icon: f.icon,
                    value: '${components[f.key]!.round()}/100',
                    color: _factorColor(components[f.key]),
                  ),
              const SizedBox(height: 32),
              const AboutMetricSection(
                title: 'About Wellness Balance',
                body: _aboutText,
              ),
              const SizedBox(height: 16),
              Text(
                'This is a wellness feature, not a medical device. It does not '
                'diagnose or detect any mental-health condition.',
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

  static const List<({String key, String label, IconData icon})> _factors = [
    (key: 'hrv', label: 'Heart rate variability', icon: Icons.show_chart),
    (key: 'rhr', label: 'Resting heart rate', icon: Icons.favorite),
    (key: 'sleep', label: 'Sleep quality', icon: Icons.bedtime),
    (key: 'activity', label: 'Activity', icon: Icons.directions_walk),
    (key: 'circadian', label: 'Daily rhythm', icon: Icons.schedule),
  ];

  /// Colour a sub-score by its 0–100 value: green = supporting balance,
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
