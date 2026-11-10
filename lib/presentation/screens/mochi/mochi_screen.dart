import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/mochi.dart';
import '../../providers/mochi_providers.dart';
import '../../providers/profile_settings_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';

/// Mochi's room: level, growth and the wardrobe.
class MochiScreen extends ConsumerWidget {
  const MochiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(mochiProgressProvider);
    final outfit = ref.watch(mochiOutfitProvider);
    final next = progress.nextLevelXp;
    final nextUnlock = MochiItem.values.where((i) => i.unlockLevel > progress.level).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Mochi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xl),
        children: [
          // ---- Hero
          AppCard(
            gradient: BrandSurfaces.hero(context.isDark),
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
            child: Column(
              children: [
                const Mascot(mood: MascotMood.happy, size: 170),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    _LevelBadge(level: progress.level),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${progress.stage.label} Mochi', style: context.text.titleLarge),
                          Text(
                            next == null
                                ? 'Max level reached!'
                                : '${next - progress.xp} XP to level ${progress.level + 1}',
                            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text('${progress.xp} XP', style: context.text.titleMedium?.copyWith(color: context.colors.primary)),
                  ],
                ),
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.levelProgress),
                    duration: motionDuration(context, AppDurations.ring),
                    curve: AppCurves.easeOut,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10),
                  ),
                ),
                if (nextUnlock != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'Next unlock: ${nextUnlock.emoji} ${nextUnlock.label} at level ${nextUnlock.unlockLevel}',
                    textAlign: TextAlign.center,
                    style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ).entrance(context),
          const SizedBox(height: Space.lg),

          // ---- Wardrobe
          SectionHeader(
            title: 'Wardrobe',
            trailing: outfit.isEmpty
                ? null
                : TextButton(
                    onPressed: () {
                      Haptics.tap();
                      ref.read(settingsProvider.notifier).setMochiOutfit(const []);
                    },
                    child: const Text('Take off all'),
                  ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 520 ? 4 : 3;
              final w = (c.maxWidth - Space.sm * (cols - 1)) / cols;
              return Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final item in MochiItem.values)
                    SizedBox(
                      width: w,
                      child: _ItemCard(
                        item: item,
                        unlocked: progress.isUnlocked(item),
                        worn: outfit.contains(item),
                        onTap: () {
                          if (!progress.isUnlocked(item)) {
                            Haptics.warning();
                            showAppSnack(context, '${item.label} unlocks at level ${item.unlockLevel}');
                            return;
                          }
                          Haptics.light();
                          toggleMochiItem(ref, item);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.lg),

          // ---- Growth
          const SectionHeader(title: 'Growing up'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.sm),
            child: Row(
              children: [
                for (final stage in MochiStage.values)
                  Expanded(
                    child: Opacity(
                      opacity: progress.level >= stage.fromLevel ? 1 : 0.4,
                      child: Column(
                        children: [
                          Mascot(mood: MascotMood.happy, size: 56, stage: stage, outfit: const {}, interactive: false),
                          const SizedBox(height: 4),
                          Text(
                            stage.label,
                            maxLines: 1,
                            style: context.text.labelMedium?.copyWith(
                              fontWeight: progress.stage == stage ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Lv ${stage.fromLevel}',
                            style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          // ---- How to earn XP
          const SectionHeader(title: 'How Mochi grows'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Column(
              children: [
                for (final (emoji, text, xp) in mochiXpRules)
                  ListTile(
                    dense: true,
                    leading: Text(emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(text, style: context.text.bodyMedium),
                    trailing: Text(
                      '+$xp XP',
                      style: context.text.labelLarge?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            '${progress.daysLogged} days logged · ${progress.goalDays} goal days · ${progress.waterDays} water goals',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC94D), Color(0xFFF08A24)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF08A24).withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LV',
            style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1),
          ),
          Text(
            '$level',
            style: context.text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.unlocked, required this.worn, required this.onTap});
  final MochiItem item;
  final bool unlocked;
  final bool worn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final outline = context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline;
    return Semantics(
      button: true,
      selected: worn,
      label: '${item.label}${unlocked ? (worn ? ', wearing' : '') : ', locked until level ${item.unlockLevel}'}',
      excludeSemantics: true,
      child: Pressable(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: motionDuration(context, AppDurations.medium),
            curve: AppCurves.easeOut,
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, Space.sm),
            decoration: BoxDecoration(
              color: worn
                  ? Color.alphaBlend(primary.withValues(alpha: context.isDark ? 0.18 : 0.08), context.colors.surface)
                  : context.colors.surface,
              borderRadius: Radii.mdAll,
              border: Border.all(color: worn ? primary : outline, width: worn ? 1.6 : 1),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: unlocked ? 1 : 0.35,
                      child: Mascot(mood: MascotMood.happy, size: 64, outfit: {item}, interactive: false),
                    ),
                    if (!unlocked)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: context.colors.inverseSurface.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_rounded, size: 16, color: context.colors.onInverseSurface),
                          ),
                        ),
                      ),
                    if (worn)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                        ).popIn(context),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  unlocked ? (worn ? 'Wearing' : 'Tap to wear') : 'Level ${item.unlockLevel}',
                  maxLines: 1,
                  style: context.text.labelSmall?.copyWith(color: worn ? primary : context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
