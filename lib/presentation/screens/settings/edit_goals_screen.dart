import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/services/nutrition_calculator.dart';
import '../../providers/profile_settings_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/motion.dart';
import '../onboarding/onboarding_widgets.dart';

/// Edit profile inputs and see recalculated targets live; optionally override.
class EditGoalsScreen extends ConsumerStatefulWidget {
  const EditGoalsScreen({super.key});

  @override
  ConsumerState<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends ConsumerState<EditGoalsScreen> {
  late UserProfile _p = ref.read(profileProvider)!;
  late bool _custom = _p.customTargets;
  late NutritionTargets _manual = _p.targets;
  late final _name = TextEditingController(text: _p.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  NutritionTargets get _computed => NutritionCalculator.forProfile(_p);
  NutritionTargets get _effective => _custom ? _manual : _computed;

  void _update(UserProfile p) => setState(() => _p = p);

  Future<void> _save() async {
    final next = _p.copyWith(name: _name.text.trim(), targets: _effective, customTargets: _custom);
    await ref.read(profileProvider.notifier).save(next);
    await Haptics.success();
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Goals updated')));
  }

  Widget _macroSlider(
    String label,
    int value,
    int min,
    int max,
    Color color,
    ValueChanged<int> onChanged, {
    String unit = 'g',
    int step = 5,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.titleSmall)),
            Text('$value $unit', style: context.text.titleSmall?.copyWith(color: color)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: color, thumbColor: color),
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            semanticFormatterCallback: (v) => '$label ${v.round()} $unit',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  static const _goalShort = {Goal.lose: 'Lose', Goal.maintain: 'Maintain', Goal.gain: 'Gain'};

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.xs),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 1.1),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _effective;
    final pal = context.palette;
    final macroKcal = NutritionCalculator.kcalFromMacros(t.protein, t.carbs, t.fat);
    final weeks = NutritionCalculator.weeksToGoal(
      goal: _p.goal,
      weightKg: _p.weightKg,
      targetWeightKg: _p.targetWeightKg,
      paceKgPerWeek: _p.paceKgPerWeek,
    );

    Widget macroChip(String label, int grams, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: context.isDark ? 0.45 : 0.85),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label ${grams}g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your goals')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.md),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save changes'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
        children: [
          // Live target summary
          AppCard(
            gradient: BrandSurfaces.hero(context.isDark),
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daily target',
                        style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        _custom ? 'Custom' : 'Recommended',
                        style: context.text.labelMedium?.copyWith(color: context.colors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: CountUpText(
                    value: t.calories,
                    duration: AppDurations.medium,
                    suffix: ' kcal',
                    style: context.text.displaySmall,
                  ),
                ),
                const SizedBox(height: Space.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    macroChip('Protein', t.protein, pal.protein),
                    macroChip('Carbs', t.carbs, pal.carbs),
                    macroChip('Fat', t.fat, pal.fat),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),

          // Goal
          _section(
            'Goal',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final g in Goal.values) ...[
                      if (g != Goal.values.first) const SizedBox(width: Space.xs),
                      Expanded(
                        child: _GoalTile(
                          emoji: g.emoji,
                          label: _goalShort[g]!,
                          selected: _p.goal == g,
                          onTap: () {
                            Haptics.tap();
                            _update(
                              _p.copyWith(
                                goal: g,
                                paceKgPerWeek: g == Goal.maintain
                                    ? 0
                                    : (_p.paceKgPerWeek == 0
                                          ? 0.5
                                          : _p.paceKgPerWeek.clamp(0.25, g == Goal.gain ? 0.5 : 1.0)),
                                targetWeightKg: g == Goal.maintain ? _p.weightKg : _p.targetWeightKg,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                if (_p.goal != Goal.maintain) ...[
                  const SizedBox(height: Space.md),
                  Text('Weekly pace', style: context.text.titleSmall),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final pace in _p.goal == Goal.lose ? const [0.25, 0.5, 0.75, 1.0] : const [0.25, 0.5])
                        ChoiceChip(
                          label: Text('$pace kg'),
                          selected: _p.paceKgPerWeek == pace,
                          onSelected: (_) {
                            Haptics.tap();
                            _update(_p.copyWith(paceKgPerWeek: pace));
                          },
                        ),
                    ],
                  ),
                  if (weeks != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      weeks == 0
                          ? 'You\'re already at your target.'
                          : '≈ $weeks weeks to ${_p.targetWeightKg.toStringAsFixed(1)} kg',
                      style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // About you
          _section(
            'About you',
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_rounded)),
                  ),
                  const SizedBox(height: Space.md),
                  SegmentedButton<Sex>(
                    showSelectedIcon: false,
                    segments: [for (final s in Sex.values) ButtonSegment(value: s, label: Text(s.label))],
                    selected: {_p.sex},
                    onSelectionChanged: (s) => _update(_p.copyWith(sex: s.first)),
                  ),
                  const SizedBox(height: Space.md),
                  NumberPicker(
                    label: 'Age',
                    value: _p.age.toDouble(),
                    min: 13,
                    max: 90,
                    step: 1,
                    unit: 'years',
                    onChanged: (v) => _update(_p.copyWith(age: v.round())),
                  ),
                ],
              ),
            ),
          ),

          // Body
          _section(
            'Body',
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NumberPicker(
                    label: 'Height',
                    value: _p.heightCm,
                    min: 120,
                    max: 220,
                    step: 1,
                    unit: 'cm',
                    onChanged: (v) => _update(_p.copyWith(heightCm: v)),
                  ),
                  const Divider(height: Space.xl),
                  NumberPicker(
                    label: 'Current weight',
                    value: _p.weightKg,
                    min: 35,
                    max: 250,
                    step: 0.5,
                    decimals: 1,
                    unit: 'kg',
                    onChanged: (v) => _update(_p.copyWith(weightKg: v)),
                  ),
                  if (_p.goal != Goal.maintain) ...[
                    const Divider(height: Space.xl),
                    NumberPicker(
                      label: 'Target weight',
                      value: _p.targetWeightKg,
                      min: 35,
                      max: 250,
                      step: 0.5,
                      decimals: 1,
                      unit: 'kg',
                      onChanged: (v) => _update(_p.copyWith(targetWeightKg: v)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Activity
          _section(
            'Activity',
            Column(
              children: [
                for (final a in ActivityLevel.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: ChoiceCard(
                      title: a.label,
                      subtitle: a.description,
                      selected: _p.activity == a,
                      onTap: () => _update(_p.copyWith(activity: a)),
                    ),
                  ),
              ],
            ),
          ),

          // Targets
          _section(
            'Daily targets',
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set targets manually'),
                    subtitle: Text(_custom ? 'Won\'t change with your weight' : 'Calculated for you'),
                    value: _custom,
                    onChanged: (v) => setState(() {
                      _custom = v;
                      if (v) _manual = _computed;
                    }),
                  ),
                  if (_custom) ...[
                    _macroSlider(
                      'Calories',
                      _manual.calories,
                      1000,
                      5000,
                      context.colors.primary,
                      (v) => setState(() => _manual = _manual.copyWith(calories: v)),
                      unit: 'kcal',
                      step: 50,
                    ),
                    _macroSlider(
                      'Protein',
                      _manual.protein,
                      30,
                      350,
                      pal.protein,
                      (v) => setState(() => _manual = _manual.copyWith(protein: v)),
                    ),
                    _macroSlider(
                      'Carbs',
                      _manual.carbs,
                      20,
                      600,
                      pal.carbs,
                      (v) => setState(() => _manual = _manual.copyWith(carbs: v)),
                    ),
                    _macroSlider(
                      'Fat',
                      _manual.fat,
                      20,
                      250,
                      pal.fat,
                      (v) => setState(() => _manual = _manual.copyWith(fat: v)),
                    ),
                    if ((macroKcal - _manual.calories).abs() > _manual.calories * 0.08)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: pal.warning),
                            const SizedBox(width: Space.xs),
                            Expanded(
                              child: Text(
                                'Macros add up to $macroKcal kcal.',
                                style: context.text.bodySmall?.copyWith(color: pal.warning),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _manual = _manual.copyWith(calories: macroKcal)),
                              child: const Text('Match'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Big tappable goal option: emoji + short label.
class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.emoji, required this.label, required this.selected, required this.onTap});
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motionDuration(context, AppDurations.medium),
          curve: AppCurves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: context.isDark ? 0.18 : 0.1) : context.colors.surface,
            borderRadius: Radii.mdAll,
            border: Border.all(
              color: selected ? primary : (context.isDark ? BrandColors.darkOutline : BrandColors.lightOutline),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: Space.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: context.text.titleSmall?.copyWith(
                    color: selected ? primary : context.colors.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
