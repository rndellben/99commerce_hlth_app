import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Time-window granularity used by detail screens.
enum Period { day, week, month, threeMonths }

extension PeriodX on Period {
  String get label => switch (this) {
        Period.day => 'D',
        Period.week => 'W',
        Period.month => 'M',
        Period.threeMonths => '3M',
      };
}

/// Four-segment pill toggle (D / W / M / 3M) used on every metric
/// detail screen. Matches the spec timeframe selector layout.
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
                    color: p == value
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: p == value
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
