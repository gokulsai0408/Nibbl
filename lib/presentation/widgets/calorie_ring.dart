import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/date_x.dart';
import 'count_up_text.dart';
import 'motion.dart';

/// Animated calorie ring. Fills with a gradient; overflow wraps in a warning color.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.goal,
    this.size = 180,
    this.strokeWidth = 16,
    this.onDark = true,
    this.center,
  });

  /// Replaces the default "kcal left" label (e.g. with the mascot).
  final Widget? center;

  final double consumed;
  final int goal;
  final double size;
  final double strokeWidth;

  /// When placed on the gradient hero card, use light foreground colors.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final remaining = goal - consumed;
    final over = remaining < 0;
    final progress = goal <= 0 ? 0.0 : consumed / goal;
    final fg = onDark ? Colors.white : context.colors.onSurface;
    final palette = context.palette;

    return Semantics(
      label: over
          ? '${formatKcal(-remaining)} calories over your goal of ${formatKcal(goal)}'
          : '${formatKcal(remaining)} calories remaining of ${formatKcal(goal)}',
      child: MergeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: motionDuration(context, AppDurations.ring),
              curve: AppCurves.easeOut,
              builder: (context, p, child) => CustomPaint(
                painter: _RingPainter(
                  progress: p,
                  strokeWidth: strokeWidth,
                  track: fg.withValues(alpha: onDark ? 0.18 : 0.08),
                  colors: onDark ? const [Color(0xFFFFFFFF), Color(0xFFD9FFF0)] : context.palette.heroGradient.colors,
                  overflow: palette.warning,
                ),
                child: child,
              ),
              child: center != null
                  ? Center(child: center)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CountUpText(
                            value: remaining.abs(),
                            style: context.text.displaySmall?.copyWith(color: fg, height: 1),
                          ),
                          const SizedBox(height: Space.xxs),
                          Text(
                            over ? 'kcal over' : 'kcal left',
                            style: context.text.labelMedium?.copyWith(color: fg.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.track,
    required this.colors,
    required this.overflow,
  });

  final double progress;
  final double strokeWidth;
  final Color track;
  final List<Color> colors;
  final Color overflow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );

    // Never fully empty: at zero the round cap leaves a small starting dot
    // (like activity rings), so switching to an empty day still reads as a ring.
    final main = math.max(progress.clamp(0.0, 1.0), 0.0001);
    {
      final shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [colors.first, colors.last, colors.first],
        transform: const GradientRotation(start),
      ).createShader(rect);
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * main,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..shader = shader,
      );
    }

    final extra = (progress - 1).clamp(0.0, 1.0);
    if (extra > 0) {
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * extra,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth * 0.62
          ..color = overflow,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.colors != colors || old.overflow != overflow;
}
