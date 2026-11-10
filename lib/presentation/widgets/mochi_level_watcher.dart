import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/services/sound_fx.dart';
import '../../core/theme/tokens.dart';
import '../../domain/entities/mochi.dart';
import '../providers/mochi_providers.dart';
import '../providers/profile_settings_providers.dart';
import 'mascot.dart';
import 'motion.dart';

/// Celebrates when Mochi reaches a new level (once per level).
class MochiLevelWatcher extends ConsumerStatefulWidget {
  const MochiLevelWatcher({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MochiLevelWatcher> createState() => _MochiLevelWatcherState();
}

class _MochiLevelWatcherState extends ConsumerState<MochiLevelWatcher> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted || _showing) return;
    final level = ref.read(mochiProgressProvider).level;
    final seen = ref.read(settingsProvider).mochiLevelSeen;
    final notifier = ref.read(settingsProvider.notifier);
    if (level < seen) {
      // Data was deleted or restored from an older backup.
      await notifier.setMochiLevelSeen(level);
      return;
    }
    if (level == seen) return;
    final unlocked = [
      for (final i in MochiItem.values)
        if (i.unlockLevel > seen && i.unlockLevel <= level) i,
    ];
    _showing = true;
    await notifier.setMochiLevelSeen(level);
    Haptics.success();
    SoundFx.boing();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => _LevelUpDialog(level: level, unlocked: unlocked),
    );
    _showing = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mochiProgressProvider.select((p) => p.level), (prev, next) {
      if (prev != next) _check();
    });
    return widget.child;
  }
}

class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.level, required this.unlocked});
  final int level;
  final List<MochiItem> unlocked;

  @override
  Widget build(BuildContext context) {
    final stage = MochiStage.forLevel(level);
    final grew = stage.fromLevel == level && level > 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: Radii.lgAll),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(
              mood: MascotMood.excited,
              size: 140,
              outfit: unlocked.isEmpty ? null : {unlocked.last},
              interactive: false,
            ).popIn(context),
            const SizedBox(height: Space.sm),
            Text('Level $level!', style: context.text.headlineSmall),
            const SizedBox(height: Space.xxs),
            Text(
              grew
                  ? 'Mochi grew into a ${stage.label.toLowerCase()}! Thanks for showing up every day.'
                  : 'Mochi is so proud of you. Keep it up!',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            if (unlocked.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                alignment: WrapAlignment.center,
                children: [for (final i in unlocked) Chip(avatar: Text(i.emoji), label: Text('${i.label} unlocked'))],
              ),
            ],
            const SizedBox(height: Space.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/mochi');
                },
                child: Text(unlocked.isEmpty ? 'See Mochi' : 'Dress up Mochi'),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ],
        ),
      ),
    );
  }
}
