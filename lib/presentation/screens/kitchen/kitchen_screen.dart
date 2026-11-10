import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../../domain/entities/kitchen.dart';
import '../../providers/core_providers.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';
import 'recipe_screen.dart';

/// "My kitchen": what you have at home, and a one-tap recipe from Mochi.
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  final _addCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _servings = 1;
  int _minutes = 30;
  bool _fitBudget = true;
  bool _basics = true;
  bool _scanning = false;

  @override
  void dispose() {
    _addCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addTyped() async {
    final text = _addCtrl.text;
    if (text.trim().isEmpty) return;
    final n = await ref.read(pantryProvider.notifier).addText(text);
    _addCtrl.clear();
    if (n > 0) Haptics.light();
    if (n == 0 && mounted) showAppSnack(context, 'Already in your kitchen');
  }

  Future<void> _scan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final found = await ref.read(aiServiceProvider).scanPantry(await file.readAsBytes());
      if (!mounted) return;
      if (found.isEmpty) {
        showAppSnack(context, 'No ingredients spotted. Try a closer photo.');
        return;
      }
      final picked = await _confirmScan(found);
      if (picked == null || picked.isEmpty) return;
      final n = await ref.read(pantryProvider.notifier).addAll([for (final (n, e) in picked) (n, e)]);
      Haptics.success();
      if (mounted) showAppSnack(context, 'Added $n ingredient${n == 1 ? '' : 's'}');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Lets the user untick anything the scan got wrong.
  Future<List<(String, String)>?> _confirmScan(List<(String, String)> found) {
    final selected = {for (final f in found) f.$1: true};
    return showModalBottomSheet<List<(String, String)>>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Found ${found.length}. Untick any mistakes.', style: ctx.text.titleMedium),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final (name, emoji) in found)
                    FilterChip(
                      avatar: Text(emoji),
                      label: Text(name),
                      selected: selected[name]!,
                      onSelected: (v) => setSheet(() => selected[name] = v),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, [
                  for (final f in found)
                    if (selected[f.$1]!) f,
                ]),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(PantryItem item) async {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.qty);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.emoji}  ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'How much do you have?', hintText: 'e.g. 4, 500 g, 1 cup'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Remove')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final qty = qtyCtrl.text.trim();
    disposeAfterClose([nameCtrl, qtyCtrl]);
    if (!mounted) return;
    final notifier = ref.read(pantryProvider.notifier);
    if (result == 'delete') {
      notifier.remove(item.id);
      showAppSnack(context, 'Removed ${item.name}', onUndo: () => notifier.restore(item));
    } else if (result == 'save') {
      notifier.update(item.copyWith(name: name.isEmpty ? item.name : name, qty: qty));
    }
  }

  void _cook() {
    final pantry = ref.read(pantryProvider);
    final today = ref.read(daySummaryProvider(DateTime.now().dayKey));
    final left = today.remainingKcal.round();
    Haptics.medium();
    final request = RecipeRequest(
      pantry: [for (final p in pantry) p.forPrompt],
      servings: _servings,
      maxMinutes: _minutes,
      // Leave a little room so one dish doesn't use the whole day.
      kcalPerServing: _fitBudget && left > 150 ? (left * 0.9).round().clamp(150, 900) : null,
      proteinLeft: _fitBudget ? (today.targets.protein - today.totals.protein).round() : null,
      meal: MealType.forTime(DateTime.now()).label.toLowerCase(),
      note: _noteCtrl.text,
      basics: _basics,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipeScreen(request: request)));
  }

  @override
  Widget build(BuildContext context) {
    final pantry = ref.watch(pantryProvider);
    final saved = ref.watch(savedRecipesProvider);
    final left = ref.watch(daySummaryProvider(DateTime.now().dayKey)).remainingKcal.round();
    final names = {for (final p in pantry) p.name.toLowerCase()};
    final staples = [
      for (final s in kitchenStaples)
        if (!names.contains(s.$1.toLowerCase())) s,
    ];
    final ready = pantry.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My kitchen'),
        actions: [
          if (pantry.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all ingredients?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) ref.read(pantryProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
              children: [
                Row(
                  children: [
                    const Mascot(mood: MascotMood.happy, size: 44, interactive: false),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'What do you have? I\'ll find a simple dish.',
                        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),

                // ---- Add
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(hintText: '4 eggs, 500g rice, onion…'),
                        onSubmitted: (_) => _addTyped(),
                      ),
                    ),
                    const SizedBox(width: Space.xs),
                    IconButton.filled(tooltip: 'Add', onPressed: _addTyped, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
                const SizedBox(height: Space.sm),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ActionChip(
                        avatar: _scanning
                            ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(_scanning ? 'Scanning…' : 'Scan fridge'),
                        onPressed: _scanning ? null : _scan,
                      ),
                      for (final (name, emoji) in staples) ...[
                        const SizedBox(width: Space.xs),
                        ActionChip(
                          avatar: Text(emoji),
                          label: Text(name),
                          onPressed: () {
                            Haptics.tap();
                            ref.read(pantryProvider.notifier).addAll([(name, emoji)]);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),

                // ---- Ingredients
                SectionHeader(
                  title: pantry.isEmpty ? 'Ingredients' : 'Ingredients · ${pantry.length}',
                  trailing: pantry.isEmpty
                      ? null
                      : Tooltip(
                          message: 'Tap an ingredient to set how much you have',
                          child: Icon(Icons.info_outline_rounded, size: 18, color: context.colors.onSurfaceVariant),
                        ),
                ),
                AnimatedSize(
                  duration: motionDuration(context, AppDurations.medium),
                  curve: AppCurves.easeOut,
                  alignment: Alignment.topCenter,
                  child: pantry.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xs),
                          child: Text(
                            'Nothing added yet.',
                            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            spacing: Space.xs,
                            runSpacing: Space.xs,
                            children: [
                              for (final p in pantry)
                                InputChip(
                                  key: ValueKey(p.id),
                                  avatar: Text(p.emoji),
                                  label: Text(p.qty.isEmpty ? p.name : '${p.name} · ${p.qty}'),
                                  onPressed: () => _edit(p),
                                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                                  onDeleted: () {
                                    Haptics.tap();
                                    ref.read(pantryProvider.notifier).remove(p.id);
                                    showAppSnack(
                                      context,
                                      'Removed ${p.name}',
                                      onUndo: () => ref.read(pantryProvider.notifier).restore(p),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: Space.lg),

                // ---- Preferences
                const SectionHeader(title: 'Preferences'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.people_alt_outlined),
                        title: const Text('Servings'),
                        trailing: _Stepper(
                          value: _servings,
                          min: 1,
                          max: 6,
                          onChanged: (v) => setState(() => _servings = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xs),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: context.colors.onSurfaceVariant),
                            const SizedBox(width: Space.md),
                            Expanded(child: Text('Time', style: context.text.bodyLarge)),
                            SegmentedButton<int>(
                              showSelectedIcon: false,
                              style: const ButtonStyle(visualDensity: VisualDensity.compact),
                              segments: const [
                                ButtonSegment(value: 15, label: Text('15m')),
                                ButtonSegment(value: 30, label: Text('30m')),
                                ButtonSegment(value: 60, label: Text('60m')),
                              ],
                              selected: {_minutes},
                              onSelectionChanged: (s) {
                                Haptics.tap();
                                setState(() => _minutes = s.first);
                              },
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.track_changes_rounded),
                        title: const Text('Fit my calories'),
                        subtitle: Text(left > 150 ? '$left kcal left today' : 'Not much left today'),
                        value: _fitBudget,
                        onChanged: (v) => setState(() => _fitBudget = v),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.soup_kitchen_outlined),
                        title: const Text('I have salt, oil & spices'),
                        value: _basics,
                        onChanged: (v) => setState(() => _basics = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm),
                        child: TextField(
                          controller: _noteCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Anything special? e.g. spicy, no oven',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- Saved recipes
                if (saved.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  SectionHeader(title: 'Saved · ${saved.length}'),
                  for (final r in saved) ...[
                    AppCard(
                      padding: const EdgeInsets.all(Space.sm),
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => RecipeScreen.saved(recipe: r))),
                      child: Row(
                        children: [
                          EmojiAvatar(emoji: r.emoji, size: 40),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall,
                            ),
                          ),
                          Text(
                            '${r.perServing.kcal.round()} kcal',
                            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                  ],
                ],
              ],
            ),
          ),

          // ---- Cook button
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: Space.sm),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: ready ? _cook : null,
                  icon: const Icon(Icons.soup_kitchen_rounded),
                  label: Text(
                    ready ? 'Cook with Mochi' : 'Add ${2 - pantry.length} more to start',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Fewer',
          visualDensity: VisualDensity.compact,
          onPressed: value > min
              ? () {
                  Haptics.tap();
                  onChanged(value - 1);
                }
              : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 24,
          child: Text('$value', textAlign: TextAlign.center, style: context.text.titleMedium),
        ),
        IconButton(
          tooltip: 'More',
          visualDensity: VisualDensity.compact,
          onPressed: value < max
              ? () {
                  Haptics.tap();
                  onChanged(value + 1);
                }
              : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}
