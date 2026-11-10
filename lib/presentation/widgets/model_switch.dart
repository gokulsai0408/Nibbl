import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/tracking.dart';
import '../providers/core_providers.dart';
import '../providers/profile_settings_providers.dart';
import 'motion.dart';

/// Look and feel for each model.
extension ClaudeModelStyle on ClaudeModel {
  IconData get icon => switch (this) {
    ClaudeModel.opus => Icons.auto_awesome_rounded,
    ClaudeModel.haiku => Icons.bolt_rounded,
  };

  /// Gradient used for the badge and the selected glow.
  List<Color> get gradient => switch (this) {
    ClaudeModel.opus => const [Color(0xFF9B7BFF), Color(0xFF6A46F0)],
    ClaudeModel.haiku => const [Color(0xFFFFB55C), Color(0xFFF07B2E)],
  };

  Color get accent => gradient.last;

  /// One-word character shown above the name.
  String get tagline => switch (this) {
    ClaudeModel.opus => 'Precision',
    ClaudeModel.haiku => 'Speed',
  };

  /// (accuracy, speed) out of 5.
  (int, int) get ratings => switch (this) {
    ClaudeModel.opus => (5, 3),
    ClaudeModel.haiku => (3, 5),
  };
}

/// Two side-by-side cards for choosing which Claude model powers the app.
class ModelPicker extends ConsumerWidget {
  const ModelPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider.select((s) => s.aiModel));
    final live = ref.watch(appConfigProvider).hasLiveAi;

    return AnimatedOpacity(
      opacity: live ? 1 : 0.5,
      duration: motionDuration(context, AppDurations.fast),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, m) in ClaudeModel.values.indexed) ...[
              if (i > 0) const SizedBox(width: Space.sm),
              Expanded(
                child: _ModelCard(
                  model: m,
                  selected: m == selected,
                  onTap: live && m != selected
                      ? () {
                          Haptics.medium();
                          ref.read(settingsProvider.notifier).setAiModel(m);
                        }
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.model, required this.selected, required this.onTap});
  final ClaudeModel model;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dur = motionDuration(context, const Duration(milliseconds: 320));
    final dark = context.isDark;
    final accent = model.accent;
    final outline = dark ? BrandColors.darkOutline : BrandColors.lightOutline;
    final radius = BorderRadius.circular(20);
    final (accuracy, speed) = model.ratings;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: 'Claude ${model.label}. ${model.description}',
      excludeSemantics: true,
      child: Pressable(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: dur,
            curve: AppCurves.easeOut,
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: selected
                  ? Color.alphaBlend(accent.withValues(alpha: dark ? 0.16 : 0.07), context.colors.surface)
                  : context.colors.surface,
              border: Border.all(
                color: selected ? accent.withValues(alpha: dark ? 0.9 : 0.75) : outline,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected ? accent.withValues(alpha: dark ? 0.28 : 0.22) : Colors.transparent,
                  blurRadius: 22,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GradientBadge(model: model, glow: selected),
                    const Spacer(),
                    _Check(selected: selected, color: accent),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  model.tagline.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(model.label, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 4),
                Text(
                  model.description,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant, height: 1.3),
                ),
                const Spacer(),
                const SizedBox(height: Space.md),
                _Meter(label: 'Accuracy', value: accuracy, color: accent, active: selected),
                const SizedBox(height: 6),
                _Meter(label: 'Speed', value: speed, color: accent, active: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBadge extends StatelessWidget {
  const _GradientBadge({required this.model, required this.glow});
  final ClaudeModel model;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motionDuration(context, const Duration(milliseconds: 320)),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: model.gradient),
        boxShadow: [
          BoxShadow(
            color: model.accent.withValues(alpha: glow ? 0.45 : 0.0),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(model.icon, color: Colors.white, size: 22),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.color});
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dur = motionDuration(context, const Duration(milliseconds: 260));
    return AnimatedContainer(
      duration: dur,
      curve: AppCurves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(color: selected ? color : context.colors.outlineVariant, width: selected ? 0 : 1.6),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: dur,
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

/// Five small segments showing a 1–5 rating.
class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.color, required this.active});
  final String label;
  final int value;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final dur = motionDuration(context, const Duration(milliseconds: 320));
    final off = context.colors.outlineVariant.withValues(alpha: 0.5);
    final on = active ? color : context.colors.onSurfaceVariant.withValues(alpha: 0.55);
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AnimatedContainer(
              duration: dur,
              height: 4,
              decoration: BoxDecoration(color: i < value ? on : off, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ],
    );
  }
}
