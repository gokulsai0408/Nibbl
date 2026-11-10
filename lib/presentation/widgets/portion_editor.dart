import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/date_x.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/macros.dart';
import 'count_up_text.dart';
import 'motion.dart';

enum _Unit { servings, grams }

/// Portion editor: pick an amount in servings or exact grams, and optionally
/// override calories and macros by hand.
///
/// [onChanged] receives the whole updated [LoggedFood] (new multiplier and,
/// if the user edited nutrition, a new per-serving base).
class PortionEditor extends StatefulWidget {
  const PortionEditor({
    super.key,
    required this.food,
    required this.onChanged,
    this.max = 5,
    this.allowNutritionEdit = true,
  });

  final LoggedFood food;
  final ValueChanged<LoggedFood> onChanged;

  /// Slider range in servings. Typed amounts may go beyond it.
  final double max;

  /// Show the "Edit calories & macros" section.
  final bool allowNutritionEdit;

  @override
  State<PortionEditor> createState() => _PortionEditorState();
}

class _PortionEditorState extends State<PortionEditor> {
  static const _minMult = 0.05;
  static const _maxMult = 50.0;
  static const _quickServings = [0.5, 1.0, 1.5, 2.0];
  static const _quickGrams = [50, 100, 150, 200, 250];

  late _Unit _unit = _defaultUnit;
  late final _amountCtrl = TextEditingController(text: _amountText);
  final _amountFocus = FocusNode();
  bool _editNutrition = false;

  late final _nutritionCtrls = {for (final k in _Nutrient.values) k: TextEditingController(text: _nutrientText(k))};
  late final _nutritionFocus = {for (final k in _Nutrient.values) k: FocusNode()};

  LoggedFood get _food => widget.food;
  bool get _gramsAvailable => _food.servingGrams > 0;
  double get _mult => _food.multiplier;

  _Unit get _defaultUnit {
    // AI and gram-based servings ("150 g") read more naturally in grams.
    final label = _food.servingLabel.trim().toLowerCase();
    return _gramsAvailable && RegExp(r'^\d+(\.\d+)?\s*g$').hasMatch(label) ? _Unit.grams : _Unit.servings;
  }

  String get _amountText => _unit == _Unit.grams ? _food.grams.round().toString() : _trimNum(_mult, digits: 2);

  String _nutrientText(_Nutrient k) {
    final v = k.read(_food.macros);
    return k == _Nutrient.kcal ? v.round().toString() : _trimNum(v, digits: 1);
  }

  static String _trimNum(double v, {int digits = 1}) {
    final s = v.toStringAsFixed(digits);
    return s.contains('.') ? s.replaceAll(RegExp(r'\.?0+$'), '') : s;
  }

  @override
  void didUpdateWidget(PortionEditor old) {
    super.didUpdateWidget(old);
    // Keep text fields in sync with changes made elsewhere (slider, chips,
    // swapping the food), but never overwrite what the user is typing.
    if (!_amountFocus.hasFocus) _amountCtrl.text = _amountText;
    for (final k in _Nutrient.values) {
      if (!_nutritionFocus[k]!.hasFocus) _nutritionCtrls[k]!.text = _nutrientText(k);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    for (final c in _nutritionCtrls.values) {
      c.dispose();
    }
    for (final f in _nutritionFocus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _setMult(double v, {bool haptic = true}) {
    final m = v.clamp(_minMult, _maxMult).toDouble();
    if (haptic) Haptics.tap();
    widget.onChanged(_food.copyWith(multiplier: m));
  }

  void _onAmountTyped(String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    if (v == null || v <= 0) return;
    _setMult(_unit == _Unit.grams ? v / _food.servingGrams : v, haptic: false);
  }

  void _step(int dir) {
    if (_unit == _Unit.grams) {
      // 10 g steps, snapped to the grid.
      final g = ((_food.grams / 10).round() + dir) * 10.0;
      _setMult(g.clamp(5, _maxMult * _food.servingGrams) / _food.servingGrams);
    } else {
      final q = ((_mult / 0.25).round() + dir) * 0.25;
      _setMult(q < 0.25 ? 0.25 : q);
    }
  }

  void _onNutrientTyped(_Nutrient k, String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    if (v == null || v < 0) return;
    // Values are typed for the current portion; store them per base serving.
    final perServing = v / _mult;
    widget.onChanged(_food.copyWith(base: k.write(_food.base, perServing)));
  }

  @override
  Widget build(BuildContext context) {
    final m = _food.macros;
    final p = context.palette;
    final grams = _unit == _Unit.grams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Summary
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portion', style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text('${formatMultiplier(_mult)} × ${_food.servingLabel}', style: context.text.titleMedium),
                  if (_gramsAvailable)
                    Text(
                      '≈ ${_food.grams.round()} g',
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            CountUpText(
              value: m.kcal,
              duration: AppDurations.medium,
              suffix: ' kcal',
              style: context.text.headlineSmall?.copyWith(color: context.colors.primary),
            ),
          ],
        ),
        const SizedBox(height: Space.md),

        // ---- Unit toggle
        if (_gramsAvailable)
          SegmentedButton<_Unit>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(
                value: _Unit.servings,
                icon: Icon(Icons.restaurant_rounded, size: 18),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Servings', maxLines: 1, softWrap: false)),
              ),
              ButtonSegment(
                value: _Unit.grams,
                icon: Icon(Icons.scale_rounded, size: 18),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Grams', maxLines: 1, softWrap: false)),
              ),
            ],
            selected: {_unit},
            onSelectionChanged: (s) {
              Haptics.tap();
              FocusScope.of(context).unfocus();
              setState(() => _unit = s.first);
              _amountCtrl.text = _amountText;
            },
          ),
        const SizedBox(height: Space.sm),

        // ---- Amount: − [ typed value ] +
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: grams ? 'Remove 10 grams' : 'Decrease portion',
              onPressed: () => _step(-1),
              icon: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: TextField(
                controller: _amountCtrl,
                focusNode: _amountFocus,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: context.text.titleLarge,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: grams ? 'g' : '×',
                  hintText: grams ? 'grams' : 'servings',
                ),
                onChanged: _onAmountTyped,
                onSubmitted: (_) => _amountCtrl.text = _amountText,
                onTapOutside: (_) {
                  _amountFocus.unfocus();
                  _amountCtrl.text = _amountText;
                },
              ),
            ),
            const SizedBox(width: Space.sm),
            IconButton.filledTonal(
              tooltip: grams ? 'Add 10 grams' : 'Increase portion',
              onPressed: () => _step(1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        if (!grams)
          Slider(
            value: _mult.clamp(0.25, widget.max).toDouble(),
            min: 0.25,
            max: widget.max,
            divisions: ((widget.max - 0.25) / 0.25).round(),
            label: '${formatMultiplier(_mult)}×',
            semanticFormatterCallback: (v) => '${formatMultiplier(v)} servings',
            onChanged: (v) {
              if (v != _mult) Haptics.tap();
              _setMult(v, haptic: false);
            },
          )
        else
          const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          alignment: WrapAlignment.center,
          children: grams
              ? [
                  for (final g in _quickGrams)
                    ChoiceChip(
                      label: Text('$g g'),
                      selected: (_food.grams - g).abs() < 0.5,
                      onSelected: (_) => _setMult(g / _food.servingGrams),
                    ),
                ]
              : [
                  for (final q in _quickServings)
                    ChoiceChip(
                      label: Text('${formatMultiplier(q)}×'),
                      selected: (_mult - q).abs() < 0.01,
                      onSelected: (_) => _setMult(q),
                    ),
                ],
        ),
        const SizedBox(height: Space.md),

        // ---- Macros
        Row(
          children: [
            _MacroTile(label: 'Protein', grams: m.protein, color: p.protein),
            const SizedBox(width: Space.xs),
            _MacroTile(label: 'Carbs', grams: m.carbs, color: p.carbs),
            const SizedBox(width: Space.xs),
            _MacroTile(label: 'Fat', grams: m.fat, color: p.fat),
          ],
        ),

        // ---- Manual nutrition override
        if (widget.allowNutritionEdit) ...[
          const SizedBox(height: Space.xs),
          Align(
            child: TextButton.icon(
              onPressed: () {
                Haptics.tap();
                setState(() => _editNutrition = !_editNutrition);
              },
              icon: AnimatedRotation(
                turns: _editNutrition ? 0.5 : 0,
                duration: motionDuration(context, AppDurations.fast),
                child: const Icon(Icons.expand_more_rounded),
              ),
              label: const Text('Edit calories & macros'),
            ),
          ),
          AnimatedSize(
            duration: motionDuration(context, AppDurations.medium),
            curve: AppCurves.easeOut,
            alignment: Alignment.topCenter,
            child: !_editNutrition
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Values for this portion. Copy them from the label if you have it.',
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            _nutrientField(_Nutrient.kcal),
                            const SizedBox(width: Space.xs),
                            _nutrientField(_Nutrient.protein),
                          ],
                        ),
                        const SizedBox(height: Space.xs),
                        Row(
                          children: [
                            _nutrientField(_Nutrient.carbs),
                            const SizedBox(width: Space.xs),
                            _nutrientField(_Nutrient.fat),
                          ],
                        ),
                        _MacroCheck(macros: m),
                      ],
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _nutrientField(_Nutrient k) => Expanded(
    child: TextField(
      controller: _nutritionCtrls[k],
      focusNode: _nutritionFocus[k],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(isDense: true, labelText: k.label, suffixText: k.unit),
      onChanged: (v) => _onNutrientTyped(k, v),
      onTapOutside: (_) => _nutritionFocus[k]!.unfocus(),
    ),
  );
}

enum _Nutrient {
  kcal('Calories', 'kcal'),
  protein('Protein', 'g'),
  carbs('Carbs', 'g'),
  fat('Fat', 'g');

  const _Nutrient(this.label, this.unit);
  final String label;
  final String unit;

  double read(Macros m) => switch (this) {
    kcal => m.kcal,
    protein => m.protein,
    carbs => m.carbs,
    fat => m.fat,
  };

  Macros write(Macros m, double v) => switch (this) {
    kcal => Macros(kcal: v, protein: m.protein, carbs: m.carbs, fat: m.fat),
    protein => Macros(kcal: m.kcal, protein: v, carbs: m.carbs, fat: m.fat),
    carbs => Macros(kcal: m.kcal, protein: m.protein, carbs: v, fat: m.fat),
    fat => Macros(kcal: m.kcal, protein: m.protein, carbs: m.carbs, fat: v),
  };
}

/// Gentle hint when calories don't add up with the macros (4/4/9 rule).
class _MacroCheck extends StatelessWidget {
  const _MacroCheck({required this.macros});
  final Macros macros;

  @override
  Widget build(BuildContext context) {
    final implied = macros.kcalFromMacros;
    final off = implied > 20 && (macros.kcal - implied).abs() / implied > 0.2;
    if (!off) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: context.palette.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Macros add up to about ${implied.round()} kcal.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.grams, required this.color});
  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.16 : 0.1),
          borderRadius: Radii.smAll,
        ),
        child: Column(
          children: [
            CountUpText(
              value: grams,
              duration: AppDurations.medium,
              format: (v) => formatGrams(v),
              style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
