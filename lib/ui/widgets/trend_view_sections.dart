import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrendNotificationBanner
// ─────────────────────────────────────────────────────────────────────────────

/// Notification row shown between the chart and the averages section.
/// Hidden entirely when [message] is null or empty (spec: "if none → hidden").
class TrendNotificationBanner extends StatelessWidget {
  const TrendNotificationBanner({super.key, required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_outlined,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TrendAveragesRow
// ─────────────────────────────────────────────────────────────────────────────

/// Low / mid / high averages strip shown below the chart.
/// Pass null for any value that doesn't apply to the metric.
class TrendAveragesRow extends StatelessWidget {
  const TrendAveragesRow({
    super.key,
    this.low,
    this.mid,
    this.high,
    this.lowLabel = 'Low',
    this.midLabel = 'Avg',
    this.highLabel = 'High',
    this.unit = '',
    required this.color,
  });

  final double? low;
  final double? mid;
  final double? high;
  final String lowLabel;
  final String midLabel;
  final String highLabel;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (low == null && mid == null && high == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (low != null) ...[
            _AverageStat(
                label: lowLabel,
                value: low!,
                unit: unit,
                color: AppColors.textTertiary),
            const _Divider(),
          ],
          if (mid != null) ...[
            _AverageStat(label: midLabel, value: mid!, unit: unit, color: color),
            if (high != null) const _Divider(),
          ],
          if (high != null)
            _AverageStat(
                label: highLabel,
                value: high!,
                unit: unit,
                color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _AverageStat extends StatelessWidget {
  const _AverageStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  final String label;
  final double value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value.toStringAsFixed(0),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DataDetailsCard
// ─────────────────────────────────────────────────────────────────────────────

/// Tappable card that routes to the data-details screen for a month
/// summary → day-reading drill-down.
///
/// Pass [metric] (e.g. 'heart-rate') to let the details screen know which
/// dataset to load.
class DataDetailsCard extends StatelessWidget {
  const DataDetailsCard({super.key, required this.metric});
  final String metric;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/data-details?metric=$metric'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Data details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Last7DaysTile
// ─────────────────────────────────────────────────────────────────────────────

/// Trailing 7-day averages tile shown below the main trend data.
/// "View more" routes to the data-details screen.
class Last7DaysTile extends StatelessWidget {
  const Last7DaysTile({
    super.key,
    required this.metric,
    required this.averageValue,
    required this.unit,
    required this.color,
    this.label = 'Last 7 days',
    this.sublabel,
  });

  final String metric;
  final double? averageValue;
  final String unit;
  final Color color;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              GestureDetector(
                onTap: () =>
                    context.push('/data-details?metric=$metric'),
                child: const Text(
                  'View more',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (averageValue != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: averageValue!.toStringAsFixed(1),
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const TextSpan(
                    text: '  avg',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '--',
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (sublabel != null) ...[
            const SizedBox(height: 4),
            Text(
              sublabel!,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AboutMetricSection
// ─────────────────────────────────────────────────────────────────────────────

/// "About [Metric]" informational section shown near the bottom of the
/// trend view, above the disclaimer.
class AboutMetricSection extends StatelessWidget {
  const AboutMetricSection({
    super.key,
    required this.title,
    required this.body,
  });
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}
