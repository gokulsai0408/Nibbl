import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../widgets/common.dart';
import '../../widgets/food_picker_sheet.dart';
import '../../widgets/macro_bar.dart';
import '../../widgets/portion_editor.dart';

/// One AI-detected item in the review list.
class ReviewItemCard extends StatelessWidget {
  const ReviewItemCard({super.key, required this.item, required this.onTap});
  final LoggedFood item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conf = item.confidence;
    final lowConfidence = conf != null && conf < 0.6;
    return AppCard(
      padding: const EdgeInsets.all(Space.md),
      onTap: onTap,
      semanticLabel:
          '${item.name}, ${formatMultiplier(item.multiplier)} times ${item.servingLabel}, '
          '${item.macros.kcal.round()} calories. Tap to edit',
      child: Row(
        children: [
          EmojiAvatar(emoji: item.emoji, size: 48),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${formatMultiplier(item.multiplier)} × ${item.servingLabel} · ${item.grams.round()} g',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xxs),
                MacroInline(macros: item.macros),
                if (lowConfidence) ...[
                  const SizedBox(height: Space.xxs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.help_outline_rounded, size: 14, color: context.palette.warning),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Low confidence · double-check',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall?.copyWith(color: context.palette.warning),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatKcal(item.macros.kcal), style: context.text.titleLarge),
              Text('kcal', style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

enum ItemEditAction { save, delete }

class ItemEditResult {
  const ItemEditResult(this.action, [this.item]);
  final ItemEditAction action;
  final LoggedFood? item;
}

/// Draggable sheet: rename, portion slider, swap with DB food, delete.
Future<ItemEditResult?> showItemEditSheet(BuildContext context, LoggedFood initial) {
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    sheetAnimationStyle: kSheetAnimation,
    useRootNavigator: true, // open above the floating nav bar
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, controller) => _ItemEditor(initial: initial, controller: controller),
    ),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.initial, required this.controller});
  final LoggedFood initial;
  final ScrollController controller;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late LoggedFood _item = widget.initial;
  late final _nameCtrl = TextEditingController(text: widget.initial.name);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _swap() async {
    final food = await showFoodPickerSheet(
      context,
      title: 'Swap "${_item.name}" with…',
      initialQuery: _item.name.split(' ').first,
    );
    if (food == null || !mounted) return;
    Haptics.light();
    setState(() {
      _item = LoggedFood.fromFood(food);
      _nameCtrl.text = food.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.controller,
      // Top gap keeps the field's floating label clear of the sheet handle;
      // bottom clears the keyboard and the system gesture bar.
      padding: EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.lg + MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            EmojiAvatar(emoji: _item.emoji, size: 52),
            const SizedBox(width: Space.md),
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: context.text.titleMedium,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => _item = _item.copyWith(name: v),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        PortionEditor(food: _item, onChanged: (f) => setState(() => _item = f)),
        const SizedBox(height: Space.lg),
        OutlinedButton.icon(
          onPressed: _swap,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Swap with a database food'),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.error,
                side: BorderSide(color: context.colors.error.withValues(alpha: 0.4)),
              ),
              onPressed: () => Navigator.pop(context, const ItemEditResult(ItemEditAction.delete)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove', maxLines: 1, softWrap: false),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  Navigator.pop(
                    context,
                    ItemEditResult(
                      ItemEditAction.save,
                      _item.copyWith(name: name.isEmpty ? widget.initial.name : name),
                    ),
                  );
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
