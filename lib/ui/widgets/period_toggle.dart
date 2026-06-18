import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Time-window granularity used by detail screens that show Day / Week /
/// Month tabs (Sleep, Heart Rate, SpO2, Activity).
enum Period { day, week, month }

extension PeriodX on Period {
  String get label => switch (this) {
        Period.day => 'Day',
        Period.week => 'Week',
        Period.month => 'Month',
      };
}

/// Three-segment pill toggle (Day / Week / Month) used on every metric
/// detail screen. Matches the QWatch Pro Sleep tab styling so the app
/// stays visually consistent across HR, SpO2, Sleep, Activity, etc.
class PeriodToggle extends StatelessWidget {
  const PeriodToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Period value;
  final ValueChanged<Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final p in Period.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        p == value ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: p == value
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
