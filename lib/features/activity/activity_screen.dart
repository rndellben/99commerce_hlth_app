import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Today',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Steps
            Center(
              child: Column(
                children: [
                  Icon(Icons.directions_walk,
                      color: AppColors.activity, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    '--',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.activity),
                  ),
                  Text(
                    'steps',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Activity stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department,
                    value: '--',
                    label: 'Calories',
                    color: AppColors.heartRate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.timer,
                    value: '--',
                    label: 'Active min',
                    color: AppColors.activity,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.straighten,
                    value: '--',
                    label: 'Distance',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No exercises recorded yet.\nStart a 10+ minute walk or run\nto estimate your fitness level.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
