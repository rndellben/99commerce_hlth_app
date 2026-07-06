import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/services/activity_detector_service.dart';
import 'package:hlth_app/features/workouts/workouts_screen.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Shown when the activity detector flags a sustained bout: nudges the user to
/// start a workout so the band records it (the clean input for VO2 max).
/// Renders nothing when there's no pending prompt.
class WorkoutPromptBanner extends ConsumerWidget {
  const WorkoutPromptBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingWorkoutPromptProvider);
    if (pending == null) return const SizedBox.shrink();

    void clear() => ref.read(pendingWorkoutPromptProvider.notifier).clear();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.activity.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_run, color: AppColors.activity, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Looks like you're active — start a workout to track your fitness.",
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () {
              clear();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
              );
            },
            child: const Text('Start',
                style: TextStyle(
                    color: AppColors.activity, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: AppColors.textTertiary, size: 18),
            onPressed: clear,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
