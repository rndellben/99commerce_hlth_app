import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

class SpO2Screen extends StatelessWidget {
  const SpO2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Oxygen'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.air, color: AppColors.spo2, size: 48),
            const SizedBox(height: 16),
            Text(
              '--',
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
            const SizedBox(height: 40),
            // Overnight average card
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
                  Text('-- %',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.spo2)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Overnight SpO2 curve\n(fl_chart integration)',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.air),
                label: const Text('Measure Now'),
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
          ],
        ),
      ),
    );
  }
}
