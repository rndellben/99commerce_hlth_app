import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sleep',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Last night',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Sleep score
            Center(
              child: Column(
                children: [
                  Text(
                    '--',
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: AppColors.sleep),
                  ),
                  Text(
                    'Sleep Score',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Sleep staging hypnogram placeholder
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Sleep staging hypnogram\nAwake | Light | Deep | REM',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Sleep metrics
            _MetricRow(label: 'Time in Bed', value: '--'),
            _MetricRow(label: 'Total Sleep', value: '--'),
            _MetricRow(label: 'Efficiency', value: '--'),
            _MetricRow(label: 'Deep Sleep', value: '--'),
            _MetricRow(label: 'REM Sleep', value: '--'),
            _MetricRow(label: 'Avg HR (sleep)', value: '--'),
            _MetricRow(label: 'Avg SpO2 (sleep)', value: '--'),
            const Spacer(),
            // D/W/M toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PeriodChip(label: 'D', selected: true),
                const SizedBox(width: 8),
                _PeriodChip(label: 'W', selected: false),
                const SizedBox(width: 8),
                _PeriodChip(label: 'M', selected: false),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _PeriodChip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
