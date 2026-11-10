import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/date_x.dart';
import 'motion.dart';

/// Animates between numeric values (counts up on first build).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.format,
    this.suffix = '',
    this.duration = AppDurations.slow,
    this.textAlign,
  });

  final num value;
  final TextStyle? style;
  final String Function(double value)? format;
  final String suffix;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: motionDuration(context, duration),
      curve: AppCurves.easeOut,
      builder: (context, v, _) => Text(
        '${format?.call(v) ?? formatKcal(v)}$suffix',
        style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        textAlign: textAlign,
      ),
    );
  }
}
