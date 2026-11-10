import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/tokens.dart';
import '../../domain/entities/food_log.dart';
import '../../core/services/haptics.dart';
import 'motion.dart';

/// Rounded surface card with optional gradient and tap handling.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.gradient,
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // One separator per surface: soft shadow in light mode, hairline border in dark mode.
    final shadow = context.palette.cardShadow;
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? context.colors.surface) : null,
      gradient: gradient,
      borderRadius: Radii.mdAll,
      border: gradient == null && shadow.isEmpty
          ? Border.all(color: context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline)
          : null,
      boxShadow: shadow,
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: Radii.mdAll, child: content);
    }
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: Pressable(
        enabled: onTap != null,
        scale: 0.985,
        child: DecoratedBox(
          decoration: decoration,
          child: Material(type: MaterialType.transparency, borderRadius: Radii.mdAll, child: content),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.sm, top: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Emoji in a soft tinted squircle; doubles as a Hero target.
class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar({super.key, required this.emoji, this.size = 44, this.heroTag, this.color});
  final String emoji;
  final double size;
  final Object? heroTag;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? context.colors.surfaceContainer,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
        semanticsLabel: '',
      ),
    );
    if (heroTag == null) return avatar;
    return Hero(
      tag: heroTag!,
      child: Material(type: MaterialType.transparency, child: avatar),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String emoji;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? Space.md : Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 88,
            height: compact ? 64 : 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Text(
              emoji,
              style: TextStyle(fontSize: compact ? 30 : 40),
              semanticsLabel: '',
            ),
          ).popIn(context),
          const SizedBox(height: Space.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Left-aligned empty state for use inside cards (icon, title, one line).
class InlineEmpty extends StatelessWidget {
  const InlineEmpty({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: context.isDark ? 0.18 : 0.1),
            borderRadius: Radii.smAll,
          ),
          child: Icon(icon, color: context.colors.primary, size: 22),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              const SizedBox(height: 2),
              Text(message, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.title = 'Something went wrong'});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.cloud_off_rounded, color: context.colors.error, size: 34),
          ).popIn(context),
          const SizedBox(height: Space.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Space.xs),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder rows shown while AI is working.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceContainer;
    final highlight = context.colors.surfaceContainerLow;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(8)),
    );
    final rows = Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                borderRadius: Radii.mdAll,
                border: Border.all(color: base),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(14)),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(140.0 + (i % 3) * 30, 14),
                        const SizedBox(height: Space.xs),
                        bar(90, 10),
                      ],
                    ),
                  ),
                  bar(48, 18),
                ],
              ),
            ),
          ),
      ],
    );
    return Semantics(
      label: 'Loading',
      child: MediaQuery.disableAnimationsOf(context)
          ? rows
          : Shimmer.fromColors(baseColor: base, highlightColor: highlight, child: rows),
    );
  }
}

/// Horizontal meal-type selector.
class MealPicker extends StatelessWidget {
  const MealPicker({super.key, required this.value, required this.onChanged});
  final MealType value;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in MealType.values)
            Padding(
              padding: const EdgeInsets.only(right: Space.xs),
              child: ChoiceChip(
                showCheckmark: false,
                avatar: Icon(
                  m.icon,
                  size: 18,
                  // Matches the chip label: light on the ink pill when selected.
                  color: value == m
                      ? (context.isDark ? BrandColors.darkBg : Colors.white)
                      : context.colors.onSurfaceVariant,
                ),
                label: Text(m.label),
                selected: value == m,
                onSelected: (_) {
                  Haptics.tap();
                  onChanged(m);
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Vertical list of screen sections with a first-entry stagger. Uses a Column
/// (not a recycling ListView) so entrances don't replay while scrolling.
class SectionList extends StatelessWidget {
  const SectionList({super.key, required this.children, this.gap = Space.md, required this.padding});
  final List<Widget> children;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Under the floating nav bar, the Scaffold reports its height as bottom padding.
    // Soft scroll-edge fade at the top instead of a hard cut-off.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0xFF000000)],
        stops: [0, (20 / bounds.height).clamp(0.0, 1.0)],
      ).createShader(bounds),
      child: SingleChildScrollView(
        padding: padding.add(EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i].entrance(context, index: i),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a snackbar with an optional Undo action.
/// Short floating message. Always auto-hides after [duration] (3s), even when
/// it has an Undo action: Flutter keeps action snackbars on screen until
/// tapped unless `persist` is set to false.
void showAppSnack(
  BuildContext context,
  String message, {
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 3),
  String actionLabel = 'Undo',
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      persist: false,
      dismissDirection: DismissDirection.horizontal,
      action: onUndo == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              onPressed: () {
                Haptics.tap();
                onUndo();
              },
            ),
    ),
  );
  // Belt and braces: accessibility services can also pin snackbars open.
  Timer(duration + const Duration(milliseconds: 100), () {
    try {
      controller.close();
    } catch (_) {
      // Already gone.
    }
  });
}

/// Swipe-left-to-delete row with a rounded red backdrop.
///
/// The sliding content gets an opaque surface and inner padding, so its text
/// never sits on the red backdrop or touches the right edge while swiping.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.onDelete,
    required this.child,
    this.surfaceColor,
    this.contentPadding = EdgeInsets.zero,
    this.borderRadius = Radii.mdAll,
  });

  final Key dismissKey;
  final VoidCallback onDelete;
  final Widget child;

  /// Background behind the sliding content. Defaults to the theme surface.
  final Color? surfaceColor;
  final EdgeInsetsGeometry contentPadding;
  final BorderRadius borderRadius;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> {
  final _progress = ValueNotifier<double>(0);
  bool _armed = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const threshold = 0.4;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Dismissible(
        key: widget.dismissKey,
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: threshold},
        movementDuration: const Duration(milliseconds: 240),
        resizeDuration: const Duration(milliseconds: 280),
        onUpdate: (d) {
          _progress.value = d.progress;
          final armed = d.reached;
          if (armed != _armed) {
            _armed = armed;
            Haptics.tap();
          }
        },
        onDismissed: (_) {
          Haptics.medium();
          widget.onDelete();
        },
        background: DecoratedBox(
          decoration: BoxDecoration(color: context.colors.error, borderRadius: widget.borderRadius),
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, p, child) {
                  final t = (p / threshold).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(scale: 0.7 + 0.3 * Curves.easeOutBack.transform(t), child: child),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_rounded, color: Colors.white),
                    const SizedBox(width: Space.xxs),
                    Text(
                      'Delete',
                      style: context.text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Material (not DecoratedBox) so InkWell ripples inside stay visible.
        child: Material(
          color: widget.surfaceColor ?? context.colors.surface,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: widget.contentPadding, child: widget.child),
        ),
      ),
    );
  }
}

/// Disposes text controllers used by a dialog or sheet once its closing
/// animation has finished. Disposing right after `showDialog` returns crashes,
/// because the route still rebuilds its text fields while animating out.
void disposeAfterClose(Iterable<ChangeNotifier> notifiers) {
  Future<void>.delayed(const Duration(milliseconds: 800), () {
    for (final n in notifiers) {
      n.dispose();
    }
  });
}

/// A [TabBar] inside a soft rounded track, with the theme's pill indicator
/// sliding between tabs. Works as an AppBar `bottom`.
class PillTabBar extends StatelessWidget implements PreferredSizeWidget {
  const PillTabBar({super.key, required this.controller, required this.tabs, this.scrollable = false});
  final TabController controller;
  final List<Widget> tabs;
  final bool scrollable;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final track = context.isDark ? const Color(0xFF1B2042) : const Color(0xFFF7EBE1);
    final bar = TabBar(
      controller: controller,
      isScrollable: scrollable,
      tabAlignment: scrollable ? TabAlignment.start : TabAlignment.fill,
      indicatorPadding: EdgeInsets.zero,
      tabs: tabs,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xxs, Space.md, Space.xs),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(Radii.pill)),
        child: bar,
      ),
    );
  }
}
