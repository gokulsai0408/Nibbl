import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/food.dart';
import '../../../domain/entities/macros.dart';
import '../../providers/food_providers.dart';

class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.barcode, this.initial, this.fromLabel = false});
  final String? barcode;

  /// Prefilled values (e.g. read from a label by the AI) for the user to check.
  final Food? initial;

  /// True when [initial] was copied from a real nutrition label.
  final bool fromLabel;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _grams = TextEditingController(text: '100');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String _emoji = '🍽️';
  bool _autoKcal = true;

  final _emojis = ['🍽️', '🥗', '🍲', '🍛', '🥪', '🌯', '🍝', '🍕', '🍳', '🥣', '🍰', '🍪', '🥤', '🍎', '🥩', '🐟'];

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    if (f != null) {
      String n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
      _name.text = f.name;
      _brand.text = f.brand ?? '';
      _serving.text = f.servingLabel;
      _grams.text = n(f.servingGrams);
      _kcal.text = f.macros.kcal.round().toString();
      _protein.text = n(f.macros.protein);
      _carbs.text = n(f.macros.carbs);
      _fat.text = n(f.macros.fat);
      if (!_emojis.contains(f.emoji)) _emojis.insert(0, f.emoji);
      _emoji = f.emoji;
      // Keep the label's calorie figure instead of recomputing it.
      _autoKcal = false;
    }
    for (final c in [_protein, _carbs, _fat]) {
      c.addListener(_recalc);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _serving, _grams, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  void _recalc() {
    if (!_autoKcal) return;
    final kcal = _v(_protein) * 4 + _v(_carbs) * 4 + _v(_fat) * 9;
    _kcal.text = kcal == 0 ? '' : kcal.round().toString();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      Haptics.warning();
      return;
    }
    final notifier = ref.read(foodsProvider.notifier);
    final food = Food(
      // Scanned products use the barcode id, so the next scan finds them instantly.
      id: widget.barcode != null ? 'off_${widget.barcode}' : notifier.newCustomId(),
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      emoji: _emoji,
      servingLabel: _serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim(),
      servingGrams: _v(_grams) <= 0 ? 100 : _v(_grams),
      macros: Macros(kcal: _v(_kcal), protein: _v(_protein), carbs: _v(_carbs), fat: _v(_fat)),
      barcode: widget.barcode,
      isCustom: true,
    );
    await notifier.upsert(food);
    await Haptics.success();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved ${food.name}')));
    if (widget.barcode != null) {
      // Straight to the product so it can be logged.
      context.pushReplacement('/food/${Uri.encodeComponent(food.id)}');
    } else {
      context.pop();
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _number(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Invalid';
    return null;
  }

  Widget _numField(TextEditingController c, String label, {String suffix = 'g', bool enabled = true}) => TextFormField(
    controller: c,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    validator: _number,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.barcode == null ? 'Custom food' : 'Add scanned product')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            if (widget.initial != null) ...[
              Container(
                padding: const EdgeInsets.all(Space.sm),
                decoration: BoxDecoration(
                  color: (widget.fromLabel ? context.palette.success : context.palette.warning).withValues(
                    alpha: context.isDark ? 0.18 : 0.1,
                  ),
                  borderRadius: Radii.smAll,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.fromLabel ? Icons.fact_check_outlined : Icons.auto_awesome_outlined,
                      color: widget.fromLabel ? context.palette.success : context.palette.warning,
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        widget.fromLabel
                            ? 'Read from the label. Give it a quick check, then save.'
                            : 'AI estimate. Compare with the pack if you can, then save.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            if (widget.barcode != null) ...[
              Text(
                'Barcode ${widget.barcode}',
                style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
            ],
            Text('Icon', style: context.text.titleSmall),
            const SizedBox(height: Space.xs),
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              children: [
                for (final e in _emojis)
                  Semantics(
                    selected: e == _emoji,
                    button: true,
                    label: 'Icon $e',
                    child: GestureDetector(
                      onTap: () {
                        Haptics.tap();
                        setState(() => _emoji = e);
                      },
                      child: AnimatedContainer(
                        duration: AppDurations.fast,
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: e == _emoji
                              ? context.colors.primary.withValues(alpha: 0.15)
                              : context.colors.surfaceContainer,
                          borderRadius: Radii.smAll,
                          border: Border.all(
                            color: e == _emoji ? context.colors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: _required,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _brand,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Brand (optional)'),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _serving,
                    decoration: const InputDecoration(labelText: 'Serving', hintText: '1 bowl'),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(flex: 2, child: _numField(_grams, 'Weight')),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text('Nutrition per serving', style: context.text.titleMedium),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(child: _numField(_protein, 'Protein')),
                const SizedBox(width: Space.sm),
                Expanded(child: _numField(_carbs, 'Carbs')),
                const SizedBox(width: Space.sm),
                Expanded(child: _numField(_fat, 'Fat')),
              ],
            ),
            const SizedBox(height: Space.md),
            _numField(_kcal, 'Calories', suffix: 'kcal', enabled: !_autoKcal),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Calculate calories from macros'),
              subtitle: const Text('4 kcal/g protein & carbs, 9 kcal/g fat'),
              value: _autoKcal,
              onChanged: (v) {
                setState(() => _autoKcal = v);
                _recalc();
              },
            ),
            const SizedBox(height: Space.lg),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save food')),
          ],
        ),
      ),
    );
  }
}
