import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class HealthMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLocked;
  final String? lockedMessage;

  const HealthMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLocked = false,
    this.lockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? AppColors.divider
                : color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: isLocked ? _buildLocked(context) : _buildActive(context),
      ),
    );
  }

  Widget _buildActive(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(color: color),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        const Spacer(),
        Icon(Icons.lock_outline, color: AppColors.textTertiary, size: 24),
        const SizedBox(height: 4),
        Text(
          lockedMessage ?? 'Coming soon',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
