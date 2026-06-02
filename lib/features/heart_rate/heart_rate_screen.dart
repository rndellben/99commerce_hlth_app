import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 32),
            // Current HR display
            const Icon(Icons.favorite, color: AppColors.heartRate, size: 48),
            const SizedBox(height: 16),
            Text(
              '--',
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
            Text(
              'Waiting for data...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            // Resting HR card
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
                  Text('-- bpm',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.heartRate)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Chart placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '24-hour trend chart\n(fl_chart integration)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Measure button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: trigger on-demand HR measurement via BLE
                },
                icon: const Icon(Icons.favorite),
                label: const Text('Measure Now'),
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
          ],
        ),
      ),
    );
  }
}
