import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../domain/entities/macros.dart';
import 'motion.dart';

/// Labeled, animated progress bar for one macro.
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, required this.goal, required this.color});

  final String label;
  final double value;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    final left = goal - value;
    return Semantics(
      label: '$label: ${value.round()} of $goal grams',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: Space.xs),
                Expanded(child: Text(label, style: context.text.labelLarge)),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${value.round()}', style: context.text.labelLarge),
                      TextSpan(
                        text: ' / ${goal}g',
                        style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            LayoutBuilder(
              builder: (context, c) => Container(
                height: 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.18 : 0.14),
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: motionDuration(context, AppDurations.ring),
                  curve: AppCurves.easeOut,
                  builder: (context, p, _) => Container(
                    width: c.maxWidth * p,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.xxs),
            Text(
              left >= 0 ? '${left.round()}g left' : '${(-left).round()}g over',
              style: context.text.bodySmall?.copyWith(
                color: left >= 0 ? context.colors.onSurfaceVariant : context.palette.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact P · C · F summary used in lists.
class MacroInline extends StatelessWidget {
  const MacroInline({super.key, required this.macros, this.style});

  final Macros macros;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = style ?? context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    Widget dot(Color c) => Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    Widget part(Color c, String letter, double g) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(c),
        Text('$letter ${g.round()}g', style: base),
      ],
    );
    return Semantics(
      label:
          'Protein ${macros.protein.round()} grams, carbs ${macros.carbs.round()} grams, fat ${macros.fat.round()} grams',
      child: ExcludeSemantics(
        child: Wrap(
          spacing: Space.sm,
          children: [
            part(p.protein, 'P', macros.protein),
            part(p.carbs, 'C', macros.carbs),
            part(p.fat, 'F', macros.fat),
          ],
        ),
      ),
    );
  }
}
