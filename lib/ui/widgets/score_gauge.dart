import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Circular score gauge for recovery, wellness, body age, etc.
class ScoreGauge extends StatelessWidget {
  final int score;
  final int maxScore;
  final String label;
  final double size;

  const ScoreGauge({
    super.key,
    required this.score,
    this.maxScore = 100,
    required this.label,
    this.size = 140,
  });

  Color get _scoreColor {
    final pct = score / maxScore;
    if (pct >= 0.7) return AppColors.scoreExcellent;
    if (pct >= 0.5) return AppColors.scoreGood;
    if (pct >= 0.3) return AppColors.scoreFair;
    return AppColors.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: score / maxScore,
          color: _scoreColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(color: _scoreColor),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 0.75 * pi;
    const sweepAngle = 1.5 * pi;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
