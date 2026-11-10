import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../providers/food_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/portion_editor.dart';
import 'water_sheet.dart';

class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final water = summary.meta.waterMl;
    final goal = summary.waterGoalMl;
    const step = 250;
    // One tidy row: at most 8 glasses, each an equal share of the goal.
    final glasses = (goal / step).ceil().clamp(1, 8);
    final perGlass = goal <= 0 ? step : (goal / glasses).ceil();
    final filled = (water / perGlass).floor();
    final color = context.palette.water;
    final progress = goal == 0 ? 0.0 : (water / goal).clamp(0.0, 1.0);

    void add(int delta) {
      delta > 0 ? Haptics.light() : Haptics.tap();
      ref.read(dayMetaProvider.notifier).addWater(summary.dayKey, delta);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: color),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text('Water', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
              ),
              const SizedBox(width: Space.sm),
              Semantics(
                label: '$water of $goal millilitres. Tap to add a drink',
                button: true,
                child: GestureDetector(
                  onTap: () => showAddDrinkSheet(context, dayKey: summary.dayKey),
                  child: ExcludeSemantics(
                    child: Text.rich(
                      maxLines: 1,
                      TextSpan(
                        children: [
                          TextSpan(text: '${(water / 1000).toStringAsFixed(2)} L', style: context.text.titleMedium),
                          TextSpan(
                            text: ' / ${(goal / 1000).toStringAsFixed(1)} L',
                            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              for (var i = 0; i < glasses; i++) ...[
                if (i > 0) const SizedBox(width: Space.xs),
                Expanded(
                  child: _Glass(
                    filled: i < filled,
                    color: color,
                    // Tap a glass to fill up to it, or tap the last filled one to empty it.
                    onTap: () => add(((i < filled ? i : i + 1) * perGlass) - water),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  progress >= 1 ? 'Goal reached 💧' : '${((1 - progress) * goal / 1000).toStringAsFixed(1)} L to go',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: Space.sm),
              IconButton.filledTonal(
                tooltip: 'Remove 250 ml',
                onPressed: water > 0 ? () => add(-step) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              IconButton.filledTonal(
                tooltip: 'Add a drink (photo, bottle or size)',
                onPressed: () => showAddDrinkSheet(context, dayKey: summary.dayKey),
                icon: const Icon(Icons.photo_camera_rounded),
              ),
              IconButton.filled(
                tooltip: 'Add 250 ml (hold for more sizes)',
                onPressed: () => add(step),
                onLongPress: () => showAddDrinkSheet(context, dayKey: summary.dayKey),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({required this.filled, required this.color, required this.onTap});
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: filled ? 'Glass of water, filled. Tap to remove' : 'Empty glass. Tap to add 250 millilitres',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motionDuration(context, AppDurations.medium),
          curve: AppCurves.easeOut,
          height: 44,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4), bottom: Radius.circular(10)),
            border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.35), width: 1.4),
          ),
          child: filled ? const Icon(Icons.water_drop_rounded, size: 14, color: Colors.white) : null,
        ),
      ),
    );
  }
}

/// Bottom sheet to adjust portion / move meal / delete a saved entry.
Future<void> showEditLogSheet(BuildContext context, WidgetRef ref, FoodLog log) {
  var food = log.food;
  var meal = log.meal;
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          0,
          Space.lg,
          Space.lg + MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                EmojiAvatar(emoji: food.emoji, size: 48),
                const SizedBox(width: Space.md),
                Expanded(child: Text(food.name, style: ctx.text.titleLarge)),
              ],
            ),
            const SizedBox(height: Space.lg),
            PortionEditor(food: food, onChanged: (f) => setState(() => food = f)),
            const SizedBox(height: Space.lg),
            MealPicker(value: meal, onChanged: (m) => setState(() => meal = m)),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Haptics.medium();
                    ref.read(logsProvider.notifier).remove(log.id);
                    showAppSnack(
                      context,
                      'Removed ${log.food.name}',
                      onUndo: () => ref.read(logsProvider.notifier).restore([log]),
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete', maxLines: 1, softWrap: false),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Haptics.success();
                      ref.read(logsProvider.notifier).update(log.copyWith(food: food, meal: meal));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> saveMealAsTemplate(BuildContext context, WidgetRef ref, MealType meal, List<FoodLog> logs) async {
  final ctrl = TextEditingController(text: 'My ${meal.label.toLowerCase()}');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save meal template'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Template name'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
      ],
    ),
  );
  disposeAfterClose([ctrl]);
  if (name == null || name.trim().isEmpty) return;
  await ref.read(templatesProvider.notifier).create(name.trim(), logs.map((l) => l.food).toList(), emoji: meal.emoji);
  Haptics.success();
  if (context.mounted) showAppSnack(context, 'Saved "$name". Find it under Search → Meals.');
}

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.summary});
  final DaySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = summary.meta.note;
    return AppCard(
      semanticLabel: note.isEmpty ? 'Add a daily note' : 'Daily note: $note. Tap to edit',
      onTap: () => _edit(context, ref, note),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_rounded, color: context.colors.tertiary),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note', style: context.text.titleMedium),
                const SizedBox(height: Space.xxs),
                Text(
                  note.isEmpty ? 'How was today?' : note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: note.isEmpty ? context.colors.onSurfaceVariant : context.colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 18, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: kSheetAnimation,
      useRootNavigator: true, // open above the floating nav bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          Space.lg,
          0,
          Space.lg,
          Space.lg + MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily note · ${parseDayKey(summary.dayKey).friendlyLabel}', style: ctx.text.titleLarge),
            const SizedBox(height: Space.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Felt great after the morning walk...'),
            ),
            const SizedBox(height: Space.sm),
            FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save note')),
          ],
        ),
      ),
    );
    disposeAfterClose([ctrl]);
    if (result != null) {
      Haptics.light();
      await ref.read(dayMetaProvider.notifier).setNote(summary.dayKey, result);
    }
  }
}
