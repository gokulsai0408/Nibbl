import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/drink.dart';
import '../../../domain/entities/food_log.dart';
import '../../providers/core_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/profile_settings_providers.dart';
import '../../widgets/common.dart';

/// Add a drink: snap a photo (AI estimates the ml), pick a size, or type it.
Future<void> showAddDrinkSheet(BuildContext context, {required String dayKey, bool openCamera = false}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: kSheetAnimation,
    builder: (ctx) => _AddDrinkSheet(dayKey: dayKey, openCamera: openCamera, hostContext: context),
  );
}

class _AddDrinkSheet extends ConsumerStatefulWidget {
  const _AddDrinkSheet({required this.dayKey, required this.openCamera, required this.hostContext});
  final String dayKey;
  final bool openCamera;

  /// For the confirmation snackbar after the sheet closes.
  final BuildContext hostContext;

  @override
  ConsumerState<_AddDrinkSheet> createState() => _AddDrinkSheetState();
}

class _AddDrinkSheetState extends ConsumerState<_AddDrinkSheet> {
  static const _sizes = [
    ('🥃', 'Small glass', 150),
    ('🥛', 'Glass', 250),
    ('☕', 'Mug', 350),
    ('🧴', 'Bottle', 500),
    ('💧', 'Large bottle', 750),
    ('🫗', '1 litre', 1000),
  ];

  final _custom = TextEditingController();
  final _hint = TextEditingController();
  Uint8List? _photo;
  bool _analyzing = false;
  DrinkEstimate? _estimate;
  int _ml = 250;
  bool _logCalories = true;

  @override
  void initState() {
    super.initState();
    if (widget.openCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _snap(ImageSource.camera));
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    _hint.dispose();
    super.dispose();
  }

  DateTime get _day {
    final d = DateTime.tryParse(widget.dayKey) ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  Future<void> _snap(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photo = bytes;
      _estimate = null;
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() => _analyzing = true);
    try {
      final e = await ref.read(aiServiceProvider).estimateDrink(photo, hint: _hint.text);
      if (!mounted) return;
      Haptics.success();
      setState(() {
        _estimate = e;
        _ml = e.ml;
      });
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _add(int hydrationMl, {String label = 'water', List<String> logIds = const []}) async {
    // Grab the notifiers now: Undo runs after this sheet is gone, and a
    // disposed sheet's `ref` can't be used (that is why Undo did nothing).
    final water = ref.read(dayMetaProvider.notifier);
    final logs = ref.read(logsProvider.notifier);
    final dayKey = widget.dayKey;
    // Updates the total instantly; the disk write finishes in the background.
    if (hydrationMl > 0) unawaited(water.addWater(dayKey, hydrationMl));
    Haptics.light();
    if (!mounted) return;
    final host = widget.hostContext;
    Navigator.pop(context);
    if (host.mounted) {
      showAppSnack(
        host,
        hydrationMl > 0 ? 'Added $hydrationMl ml of $label 💧' : 'Logged $label',
        duration: const Duration(seconds: 5),
        onUndo: () {
          if (hydrationMl > 0) water.addWater(dayKey, -hydrationMl);
          if (logIds.isNotEmpty) logs.removeAll(logIds);
        },
      );
    }
  }

  Future<void> _saveBottle({String name = '', int ml = 0, String emoji = '🧴'}) async {
    final nameCtrl = TextEditingController(text: name);
    final mlCtrl = TextEditingController(text: ml > 0 ? '$ml' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save a bottle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. My steel bottle'),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: mlCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: 'Full size', suffixText: 'ml', hintText: 'e.g. 1000'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    final size = int.tryParse(mlCtrl.text) ?? 0;
    final title = nameCtrl.text.trim();
    disposeAfterClose([nameCtrl, mlCtrl]);
    if (ok != true || !mounted) return;
    if (size < 50) {
      showAppSnack(context, 'Enter the bottle size in ml');
      return;
    }
    await ref
        .read(settingsProvider.notifier)
        .saveBottle(
          SavedBottle(
            id: 'b${DateTime.now().millisecondsSinceEpoch}',
            name: title.isEmpty ? 'My bottle' : title,
            emoji: emoji,
            ml: size,
          ),
        );
    Haptics.success();
    if (mounted) showAppSnack(context, 'Saved. Log part of it any time from My bottles.');
  }

  Future<void> _confirmEstimate() async {
    final e = _estimate!;
    final ratio = e.ml == 0 ? 1.0 : _ml / e.ml;
    final hydration = (e.hydrationMl * ratio).round();
    var logIds = const <String>[];
    if (_logCalories && e.hasCalories) {
      final added = await ref
          .read(logsProvider.notifier)
          .addFoods(
            [
              LoggedFood(
                name: e.name,
                emoji: e.emoji,
                servingLabel: '$_ml ml',
                servingGrams: _ml.toDouble(),
                base: e.macros.scale(ratio),
                confidence: e.confidence,
              ),
            ],
            meal: MealType.forTime(DateTime.now()),
            day: _day,
            source: LogSource.photo,
          );
      logIds = [for (final l in added) l.id];
    }
    await _add(hydration, label: e.name.toLowerCase(), logIds: logIds);
  }

  @override
  Widget build(BuildContext context) {
    final water = context.palette.water;
    final bottles = ref.watch(settingsProvider.select((s) => s.savedBottles));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, color: water),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  'Add a drink',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),

          // ---- My bottles
          if (bottles.isNotEmpty) ...[
            const SectionHeader(title: 'My bottles'),
            for (final b in bottles) ...[
              _BottleRow(
                bottle: b,
                onAdd: (fraction) => _add((b.ml * fraction).round(), label: b.name.toLowerCase()),
                onRemove: () => ref.read(settingsProvider.notifier).removeBottle(b.id),
              ),
              const SizedBox(height: Space.xs),
            ],
            const SizedBox(height: Space.md),
          ],

          // ---- Photo
          if (_photo == null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _snap(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Snap your drink', maxLines: 1, softWrap: false),
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs),
                IconButton.filledTonal(
                  tooltip: 'From gallery',
                  onPressed: () => _snap(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                ),
              ],
            )
          else
            _PhotoResult(
              photo: _photo!,
              analyzing: _analyzing,
              estimate: _estimate,
              ml: _ml,
              logCalories: _logCalories,
              hint: _hint,
              onMl: (v) => setState(() => _ml = v),
              onLogCalories: (v) => setState(() => _logCalories = v),
              onRetake: () => _snap(ImageSource.camera),
              onReanalyze: _analyze,
              onConfirm: _confirmEstimate,
              onSaveBottle: () => _saveBottle(
                name: _estimate?.name ?? '',
                ml: (_estimate?.containerMl ?? 0) > 0 ? _estimate!.containerMl : (_estimate?.ml ?? 0),
                emoji: _estimate?.emoji ?? '🧴',
              ),
            ),
          if (_photo == null) ...[
            const SizedBox(height: Space.xs),
            Text(
              'Mochi estimates how much is in your glass, bottle or cup.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Space.lg),

          // ---- Quick sizes
          const SectionHeader(title: 'Quick add'),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - Space.xs * 2) / 3;
              return Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  for (final (emoji, label, ml) in _sizes)
                    SizedBox(
                      width: w,
                      child: Material(
                        color: water.withValues(alpha: context.isDark ? 0.14 : 0.08),
                        borderRadius: Radii.mdAll,
                        child: InkWell(
                          borderRadius: Radii.mdAll,
                          onTap: () => _add(ml),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
                            child: Column(
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 24)),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelMedium,
                                ),
                                Text(
                                  '$ml ml',
                                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.lg),

          // ---- Custom
          const SectionHeader(title: 'Exact amount'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  decoration: const InputDecoration(hintText: 'e.g. 400', suffixText: 'ml'),
                  onSubmitted: (_) {
                    final v = int.tryParse(_custom.text);
                    if (v != null && v > 0) _add(v);
                  },
                ),
              ),
              const SizedBox(width: Space.xs),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(72, 52)),
                onPressed: () {
                  final v = int.tryParse(_custom.text);
                  if (v == null || v <= 0) {
                    showAppSnack(context, 'Type how many ml you drank');
                    return;
                  }
                  _add(v);
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _saveBottle(),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save a bottle or cup you use often'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A saved bottle: log a quarter, half, three quarters or all of it.
class _BottleRow extends StatelessWidget {
  const _BottleRow({required this.bottle, required this.onAdd, required this.onRemove});
  final SavedBottle bottle;
  final ValueChanged<double> onAdd;
  final VoidCallback onRemove;

  static const _parts = [(0.25, '¼'), (0.5, '½'), (0.75, '¾'), (1.0, 'Full')];

  @override
  Widget build(BuildContext context) {
    final water = context.palette.water;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.xxs, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(bottle.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  '${bottle.name} · ${bottle.ml} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Remove bottle',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              for (final (i, (f, label)) in _parts.indexed) ...[
                if (i > 0) const SizedBox(width: Space.xs),
                Expanded(
                  child: Material(
                    color: water.withValues(alpha: context.isDark ? 0.16 + 0.1 * f : 0.07 + 0.1 * f),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      onTap: () => onAdd(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Column(
                          children: [
                            Text(label, style: context.text.labelLarge),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${(bottle.ml * f).round()} ml',
                                style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoResult extends StatelessWidget {
  const _PhotoResult({
    required this.photo,
    required this.analyzing,
    required this.estimate,
    required this.ml,
    required this.logCalories,
    required this.hint,
    required this.onMl,
    required this.onLogCalories,
    required this.onRetake,
    required this.onReanalyze,
    required this.onConfirm,
    required this.onSaveBottle,
  });

  final Uint8List photo;
  final bool analyzing;
  final DrinkEstimate? estimate;
  final int ml;
  final bool logCalories;
  final TextEditingController hint;
  final ValueChanged<int> onMl;
  final ValueChanged<bool> onLogCalories;
  final VoidCallback onRetake;
  final VoidCallback onReanalyze;
  final VoidCallback onConfirm;
  final VoidCallback onSaveBottle;

  @override
  Widget build(BuildContext context) {
    final e = estimate;
    final ratio = e == null || e.ml == 0 ? 1.0 : ml / e.ml;
    return AppCard(
      padding: const EdgeInsets.all(Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: Radii.smAll,
                child: Image.memory(photo, width: 84, height: 84, fit: BoxFit.cover),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: analyzing || e == null
                    ? Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: Row(
                          children: [
                            const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: Space.sm),
                            Expanded(child: Text('Measuring your drink…', style: context.text.titleSmall)),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.emoji}  ${e.name}', style: context.text.titleMedium),
                          if (e.note.isNotEmpty)
                            Text(
                              e.note,
                              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                          const SizedBox(height: 4),
                          Text('$ml ml', style: context.text.headlineSmall?.copyWith(color: context.palette.water)),
                        ],
                      ),
              ),
            ],
          ),
          if (e != null && !analyzing) ...[
            Slider(
              value: ml.clamp(50, 2000).toDouble(),
              min: 50,
              max: 2000,
              divisions: 39,
              label: '$ml ml',
              onChanged: (v) => onMl(v.round()),
            ),
            if (e.hydrationMl < e.ml)
              Text(
                'Counts as ${(e.hydrationMl * ratio).round()} ml of water',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            if (e.hasCalories)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: logCalories,
                onChanged: onLogCalories,
                title: Text('Also log ${(e.macros.kcal * ratio).round()} kcal'),
                subtitle: const Text('Adds it to your food diary'),
              ),
            const SizedBox(height: Space.xs),
            FilledButton.icon(onPressed: onConfirm, icon: const Icon(Icons.check_rounded), label: Text('Add $ml ml')),
            const SizedBox(height: Space.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hint,
                    decoration: const InputDecoration(isDense: true, hintText: 'Not right? e.g. "1 L bottle, half"'),
                    onSubmitted: (_) => onReanalyze(),
                  ),
                ),
                IconButton(tooltip: 'Re-check', onPressed: onReanalyze, icon: const Icon(Icons.refresh_rounded)),
                IconButton(tooltip: 'Retake photo', onPressed: onRetake, icon: const Icon(Icons.photo_camera_outlined)),
                IconButton(
                  tooltip: e.containerMl > 0 ? 'Save this ${e.containerMl} ml bottle' : 'Save as my bottle',
                  onPressed: onSaveBottle,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
