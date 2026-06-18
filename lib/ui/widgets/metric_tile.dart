import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// "Normal / High / Low / none" status badge state for a [MetricTile].
enum MetricStatus { normal, high, low, none }

/// Inclusive reference range used to classify a metric value into a
/// [MetricStatus]. Use [statusFor] when both a low- and a high-bound
/// matter; for one-sided thresholds pass `highIfAbove` to widen the
/// "High" bucket without changing the "Normal" range.
class MetricRange {
  const MetricRange(this.lo, this.hi);
  final double lo;
  final double hi;
}

MetricStatus statusFor({
  required double value,
  required MetricRange ok,
  double? highIfAbove,
}) {
  if (value <= 0) return MetricStatus.none;
  if (highIfAbove != null && value > highIfAbove) return MetricStatus.high;
  if (value < ok.lo) return MetricStatus.low;
  if (value > ok.hi) return MetricStatus.high;
  return MetricStatus.normal;
}

/// Single metric card — matches QWatch Pro's per-stat tile layout:
/// label (top-left), optional reference range (small/grey), big value,
/// optional unit suffix, optional status chip on the right.
///
/// Designed to be laid out in pairs via [MetricGrid].
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.reference = '',
    this.valueUnit,
    this.status = MetricStatus.none,
  });

  final String label;
  final String reference;
  final String value;
  final String? valueUnit;
  final MetricStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reference,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (valueUnit != null)
                        TextSpan(
                          text: ' $valueUnit',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (status != MetricStatus.none) _StatusChip(status: status),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final MetricStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MetricStatus.normal => ('Normal', AppColors.success),
      MetricStatus.high => ('High', AppColors.warning),
      MetricStatus.low => ('Low', AppColors.warning),
      MetricStatus.none => ('', Colors.transparent),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Two-column grid of [MetricTile]s with consistent 12px gaps. Use as
/// the standard layout under the chart on any detail screen.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.tiles});

  final List<MetricTile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final w = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}
