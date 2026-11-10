import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';

/// Segmented progress bar: one pill per step, filled up to the current one.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      label: 'Step ${step + 1} of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: Space.xxs),
            Expanded(
              flex: i == step ? 3 : 2,
              child: AnimatedContainer(
                duration: motionDuration(context, AppDurations.slow),
                curve: AppCurves.easeOut,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step
                      ? primary.withValues(alpha: i == step ? 1 : 0.55)
                      : context.colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mochi with a speech bubble: the friendly voice of each onboarding step.
class MochiSays extends StatelessWidget {
  const MochiSays({super.key, required this.text, this.mood = MascotMood.happy});

  final String text;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Mascot(mood: mood, size: 60),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.outlineVariant),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(Radii.md),
                topRight: Radius.circular(Radii.md),
                bottomRight: Radius.circular(Radii.md),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: context.palette.floatShadow,
            ),
            child: Text(text, style: context.text.bodyMedium),
          ),
        ),
      ],
    );
  }
}

/// Rounded surface used to group a control on the onboarding pages.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.md)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Large value display + slider + hold-to-repeat steppers. Used for age,
/// height and weights.
class NumberPicker extends StatefulWidget {
  const NumberPicker({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.decimals = 0,
    this.caption,
    this.icon,
    this.framed = false,
  });

  /// Wraps the picker in its own rounded card (onboarding). Off when the
  /// caller already provides a card.
  final bool framed;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String unit;
  final int decimals;
  final Widget? caption;
  final IconData? icon;
  final ValueChanged<double> onChanged;

  @override
  State<NumberPicker> createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _set(double v) {
    final w = widget;
    final snapped = (v / w.step).round() * w.step;
    final clamped = snapped.clamp(w.min, w.max).toDouble();
    if (clamped != w.value) {
      Haptics.tap();
      w.onChanged(clamped);
    }
  }

  void _startRepeat(double delta) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 70), (_) {
      final next = widget.value + delta;
      if (next < widget.min || next > widget.max) return _stopRepeat();
      _set(next);
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  Widget _stepper(IconData icon, String tooltip, double delta) {
    final enabled = delta < 0 ? widget.value > widget.min : widget.value < widget.max;
    return GestureDetector(
      onLongPressStart: enabled ? (_) => _startRepeat(delta) : null,
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        iconSize: 26,
        style: IconButton.styleFrom(minimumSize: const Size.square(52)),
        onPressed: enabled ? () => _set(widget.value + delta) : null,
        icon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final display = w.value.toStringAsFixed(w.decimals);
    return Semantics(
      label: '${w.label}: $display ${w.unit}',
      child: _frame(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (w.icon != null) ...[
                  Icon(w.icon, size: 20, color: context.colors.primary),
                  const SizedBox(width: Space.xs),
                ],
                Text(w.label, style: context.text.titleMedium),
                const Spacer(),
                if (w.caption != null) w.caption!,
              ],
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                _stepper(Icons.remove_rounded, 'Decrease ${w.label}', -w.step),
                Expanded(
                  // Scales down instead of overflowing at large text sizes.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          display,
                          style: context.text.displayMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: Space.xxs),
                        Text(w.unit, style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                _stepper(Icons.add_rounded, 'Increase ${w.label}', w.step),
              ],
            ),
            Slider(
              value: w.value.clamp(w.min, w.max),
              min: w.min,
              max: w.max,
              divisions: ((w.max - w.min) / w.step).round(),
              semanticFormatterCallback: (v) => '${v.toStringAsFixed(w.decimals)} ${w.unit}',
              onChanged: _set,
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame(Widget child) => widget.framed
      ? OnboardingCard(padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs), child: child)
      : child;
}

/// Small rounded tag, e.g. the BMI readout.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motionDuration(context, AppDurations.medium),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(
        label,
        style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Shared selection styling for the tile-style pickers.
BoxDecoration _selectableDecoration(BuildContext context, bool selected) {
  final primary = context.colors.primary;
  return BoxDecoration(
    color: selected ? primary.withValues(alpha: context.isDark ? 0.18 : 0.08) : context.colors.surface,
    borderRadius: Radii.mdAll,
    border: Border.all(color: selected ? primary : context.colors.outlineVariant, width: selected ? 2 : 1),
    boxShadow: selected
        ? [BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))]
        : const [],
  );
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({required this.selected, required this.onTap, required this.child, required this.padding});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        child: AnimatedContainer(
          duration: motionDuration(context, AppDurations.medium),
          curve: AppCurves.easeOut,
          decoration: _selectableDecoration(context, selected),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: Radii.mdAll,
              onTap: () {
                Haptics.tap();
                onTap();
              },
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of equal-width option tiles. Labels scale to fit, so they never
/// wrap onto a second line on narrow phones.
class TileSelector<T> extends StatelessWidget {
  const TileSelector({super.key, required this.options, required this.value, required this.onChanged});

  final List<TileOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: Space.xs),
            Expanded(child: _tile(context, options[i])),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, TileOption<T> o) {
    final selected = o.value == value;
    final accent = selected ? context.colors.primary : context.colors.onSurface;
    Widget oneLine(String s, TextStyle? style) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(s, maxLines: 1, softWrap: false, style: style),
    );
    return _SelectableTile(
      selected: selected,
      onTap: () => onChanged(o.value),
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs, vertical: Space.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (o.icon != null) ...[
            AnimatedScale(
              scale: selected ? 1.12 : 1,
              duration: motionDuration(context, AppDurations.medium),
              curve: AppCurves.easeOut,
              child: Icon(o.icon, size: 32, color: accent),
            ),
            const SizedBox(height: Space.xxs),
          ],
          oneLine(
            o.title,
            (o.icon != null ? context.text.titleMedium : context.text.titleLarge)?.copyWith(color: accent),
          ),
          if (o.unit != null)
            oneLine(o.unit!, context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          if (o.caption != null) ...[
            const SizedBox(height: Space.xxs),
            oneLine(
              o.caption!,
              context.text.labelMedium?.copyWith(
                color: selected ? context.colors.primary : context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TileOption<T> {
  const TileOption({required this.value, required this.title, this.unit, this.caption, this.icon});

  final T value;
  final String title;
  final String? unit;
  final String? caption;
  final IconData? icon;
}

/// Big selectable card for single-choice questions.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;

  /// Shown inside a tinted rounded square (an emoji or an Icon).
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return _SelectableTile(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          if (leading != null) ...[
            AnimatedContainer(
              duration: motionDuration(context, AppDurations.medium),
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? primary.withValues(alpha: 0.16) : context.colors.surfaceContainerHighest,
                borderRadius: Radii.smAll,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: selected ? primary : context.colors.onSurfaceVariant, size: 24),
                child: leading!,
              ),
            ),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          AnimatedContainer(
            duration: motionDuration(context, AppDurations.medium),
            curve: AppCurves.easeOut,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? primary : Colors.transparent,
              border: Border.all(color: selected ? primary : context.colors.outlineVariant, width: 2),
            ),
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: motionDuration(context, AppDurations.medium),
              curve: AppCurves.easeOut,
              child: Icon(Icons.check_rounded, size: 16, color: context.colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
