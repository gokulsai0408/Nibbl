import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../widgets/motion.dart' show Pressable;

class _LogOption {
  const _LogOption(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

/// The primary action: photo logging is the fastest path, so it gets the hero slot.
const _hero = _LogOption(Icons.photo_camera_rounded, 'Snap your plate', 'AI does the math', '/log/photo');

const _secondary = [
  _LogOption(Icons.mic_rounded, 'Say it', 'Voice', '/log/voice'),
  _LogOption(Icons.edit_note_rounded, 'Type it', 'Text', '/log/text'),
  _LogOption(Icons.qr_code_scanner_rounded, 'Scan', 'Barcode', '/barcode'),
  _LogOption(Icons.search_rounded, 'Search', 'Foods & meals', '/foods'),
];

/// Draggable bottom sheet with every way to log food.
Future<void> showLogOptionsSheet(BuildContext context, {String? meal}) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      void go(String route) {
        Haptics.light();
        final router = GoRouter.of(sheetContext);
        Navigator.of(sheetContext).pop();
        router.push(meal == null ? route : '$route?meal=$meal');
      }

      // Sized to its content: no extra empty space to drag into.
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Log food', style: context.text.headlineSmall),
              const SizedBox(height: Space.lg),
              _HeroOption(option: _hero, onTap: () => go(_hero.route)),
              const SizedBox(height: Space.sm),
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: Space.sm),
                Row(
                  children: [
                    for (var col = 0; col < 2; col++) ...[
                      if (col > 0) const SizedBox(width: Space.sm),
                      Expanded(
                        child: _TileOption(
                          option: _secondary[row * 2 + col],
                          onTap: () => go(_secondary[row * 2 + col].route),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _HeroOption extends StatelessWidget {
  const _HeroOption({required this.option, required this.onTap});
  final _LogOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${option.title}. ${option.subtitle}',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          borderRadius: Radii.lgAll,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: context.palette.heroGradient),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.palette.onHero.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(option.icon, color: context.palette.onHero, size: 28),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.title, style: context.text.titleLarge?.copyWith(color: context.palette.onHero)),
                          const SizedBox(height: 2),
                          Text(
                            option.subtitle,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.palette.onHero.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: context.palette.onHero),
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

class _TileOption extends StatelessWidget {
  const _TileOption({required this.option, required this.onTap});
  final _LogOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${option.title}. ${option.subtitle}',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: context.colors.surfaceContainerLow,
          borderRadius: Radii.mdAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: context.isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(option.icon, color: context.colors.primary, size: 22),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(option.title, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
