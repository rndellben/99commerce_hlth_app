import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/features/activity/vo2max_providers.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/ui/widgets/trend_chart_card.dart';

/// "Estimated VO2 Max" card for the Activity screen: a headline fitness number
/// (mL/kg/min) with rating + fitness-age, and a 4-week trend of per-workout
/// estimates. Falls back to a profile-completion prompt when age is missing,
/// or a "do a workout" empty state before any estimate exists.
class Vo2MaxCard extends ConsumerWidget {
  const Vo2MaxCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(fitnessScoreProvider);
    final trendAsync = ref.watch(vo2TrendProvider);
    final profileComplete =
        ref.watch(profileCompleteForVo2Provider).valueOrNull ?? true;

    final score = scoreAsync.valueOrNull;
    final trend = trendAsync.valueOrNull ?? const <TrendPoint>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  color: AppColors.activity, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Estimated VO2 Max',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (score?.confidence != null)
                _ConfidenceDot(confidence: score!.confidence!),
            ],
          ),
          const SizedBox(height: 12),
          if (!profileComplete && score == null)
            const _ProfilePrompt()
          else if (score == null)
            const _NoDataPrompt()
          else
            _Headline(
              vo2: score.score,
              rating: score.label,
              fitnessAge: score.components?['fitness_age']?.round(),
            ),
          if (score != null) ...[
            const SizedBox(height: 8),
            TrendChartCard(
              points: trend,
              color: AppColors.activity,
              subtitle: '4-week trend',
              showDots: true,
              fillUnder: true,
              height: 140,
            ),
          ],
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.vo2, this.rating, this.fitnessAge});
  final double vo2;
  final String? rating;
  final int? fitnessAge;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          vo2.toStringAsFixed(1),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 6),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'mL/kg/min',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (rating != null)
              Text(
                rating!,
                style: TextStyle(
                  color: _ratingColor(rating!),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (fitnessAge != null)
              Text(
                'Fitness age $fitnessAge',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static Color _ratingColor(String rating) {
    switch (rating) {
      case 'Superior':
      case 'Excellent':
        return AppColors.scoreExcellent;
      case 'Good':
        return AppColors.scoreGood;
      case 'Fair':
        return AppColors.scoreFair;
      default:
        return AppColors.scorePoor;
    }
  }
}

class _ConfidenceDot extends StatelessWidget {
  const _ConfidenceDot({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.8
        ? AppColors.success
        : (confidence >= 0.5 ? AppColors.warning : AppColors.textTertiary);
    final label = confidence >= 0.8
        ? 'High'
        : (confidence >= 0.5 ? 'Medium' : 'Low');
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label confidence',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _ProfilePrompt extends StatelessWidget {
  const _ProfilePrompt();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Add your date of birth in your profile to estimate VO2 Max.',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }
}

class _NoDataPrompt extends StatelessWidget {
  const _NoDataPrompt();
  @override
  Widget build(BuildContext context) {
    return const Text(
      'Track a 10-minute walk or run to get your first estimate.',
      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }
}
