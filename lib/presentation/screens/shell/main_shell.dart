import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../widgets/brand_backdrop.dart';
import '../../widgets/daily_automation.dart';
import '../../widgets/mochi_level_watcher.dart';
import '../../widgets/motion.dart';
import 'log_options_sheet.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content scrolls underneath the floating capsule (Apple-style material).
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: DailyAutomation(child: MochiLevelWatcher(child: BrandBackdrop(child: shell))),
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        onSelect: (i) {
          Haptics.tap();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating capsule tab bar: frosted material with a bright top edge, deep
/// soft shadow, and a pill that slides behind the active tab.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex, required this.onSelect});
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const height = 68.0;
  static const _radius = 26.0;

  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Today'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Mochi'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  /// Fixed width of the center Log slot; the four tabs share the rest.
  static const _centerW = 60.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dark = context.isDark;
    // Higher-contrast setting: make the material solid.
    final solid = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(_radius);

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, bottom > 0 ? bottom : Space.sm),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.5 : 0.13),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.3 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            // Moderate blur: big sigmas are one of the most expensive effects on phones.
            filter: ImageFilter.blur(sigmaX: solid ? 0 : 12, sigmaY: solid ? 0 : 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.surface.withValues(alpha: solid ? 1 : (dark ? 0.84 : 0.88)),
                borderRadius: radius,
                border: Border.all(
                  color: dark ? Colors.white.withValues(alpha: 0.09) : Colors.white.withValues(alpha: 0.95),
                ),
              ),
              // Bright top edge: light catching the material.
              position: DecorationPosition.background,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.06 : 0.5),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final tabW = (c.maxWidth - _centerW) / 4;
                    final pillW = tabW - 2;
                    final i = currentIndex;
                    final slotLeft = i < 2 ? i * tabW : 2 * tabW + _centerW + (i - 2) * tabW;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: motionDuration(context, const Duration(milliseconds: 340)),
                          curve: AppCurves.easeOut,
                          left: slotLeft + (tabW - pillW) / 2,
                          top: 7,
                          bottom: 7,
                          width: pillW,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: dark ? 0.2 : 0.11),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < 2; i++) _tab(context, i),
                            const SizedBox(width: _centerW, child: _LogButton()),
                            for (var i = 2; i < 4; i++) _tab(context, i),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i) {
    final item = _items[i];
    final selected = currentIndex == i;
    final color = selected ? context.colors.primary : context.colors.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: Pressable(
            scale: 0.94,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: motionDuration(context, AppDurations.fast),
                  child: Icon(selected ? item.activeIcon : item.icon, key: ValueKey(selected), color: color, size: 24),
                ),
                const SizedBox(height: 2),
                // Keeps breathing room inside the pill; shrinks slightly rather than touching the edge.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      softWrap: false,
                      style: context.text.labelSmall?.copyWith(
                        color: color,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Center action: a glossy brand button inside the capsule.
class _LogButton extends StatefulWidget {
  const _LogButton();

  @override
  State<_LogButton> createState() => _LogButtonState();
}

class _LogButtonState extends State<_LogButton> {
  bool _open = false;

  Future<void> _openSheet() async {
    Haptics.medium();
    setState(() => _open = true);
    await showLogOptionsSheet(context);
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log food',
      hint: 'Opens photo, voice, text, barcode and search logging',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _openSheet,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Pressable(
            scale: 0.92,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: context.palette.heroGradient,
                shape: BoxShape.circle,
                border: Border.all(color: context.palette.onHero.withValues(alpha: 0.35), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: _open ? 0.15 : 0.35),
                    blurRadius: _open ? 6 : 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: AnimatedRotation(
                turns: _open ? 0.125 : 0,
                duration: motionDuration(context, AppDurations.medium),
                curve: AppCurves.easeOut,
                child: Icon(Icons.add_rounded, color: context.palette.onHero, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps every tab alive (like IndexedStack) but cross-fades the incoming tab
/// in with a gentle rise and scale, so switching tabs never "snaps".
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});
  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  late int _previous = widget.currentIndex;

  @override
  void didUpdateWidget(AnimatedBranchContainer old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _previous = old.currentIndex;
      if (MediaQuery.disableAnimationsOf(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Drop the outgoing tab from the tree once the cross-fade ends.
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
  }

  late final _incoming = CurvedAnimation(parent: _c, curve: AppCurves.easeOut);
  // Outgoing tab fades away quickly in the first third.
  late final _outgoing = ReverseAnimation(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // FadeTransition/SlideTransition animate on the GPU layer without
    // rebuilding or re-laying out the screen every frame (smoother on phones).
    final dir = widget.currentIndex >= _previous ? 1.0 : -1.0;
    final slide = Tween(begin: Offset(dir * 0.04, 0), end: Offset.zero).animate(_incoming);
    final animating = _c.isAnimating;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i == widget.currentIndex)
            RepaintBoundary(
              child: FadeTransition(
                opacity: _incoming,
                child: SlideTransition(
                  position: slide,
                  child: TickerMode(enabled: true, child: widget.children[i]),
                ),
              ),
            )
          else if (animating && i == _previous)
            IgnorePointer(
              child: RepaintBoundary(
                child: FadeTransition(
                  opacity: _outgoing,
                  child: TickerMode(enabled: false, child: widget.children[i]),
                ),
              ),
            )
          else
            Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
      ],
    );
  }
}
