import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/score_gauge.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const ScoreGauge(score: 0, label: 'Recovery', size: 160),
            const SizedBox(height: 8),
            Text(
              'Waiting for baseline data...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            // Contributing factors
            Text(
              'Contributing Factors',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _FactorRow(label: 'HRV vs baseline', value: '--', icon: Icons.show_chart),
            _FactorRow(label: 'Resting HR', value: '--', icon: Icons.favorite),
            _FactorRow(label: 'Sleep quality', value: '--', icon: Icons.bedtime),
            _FactorRow(label: 'SpO2 overnight', value: '--', icon: Icons.air),
            _FactorRow(label: 'Activity load', value: '--', icon: Icons.directions_walk),
            const Spacer(),
            Text(
              'This is a wellness feature, not a medical device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _FactorRow({
    required this.label,
    required this.value,
    required this.icon,
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
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
