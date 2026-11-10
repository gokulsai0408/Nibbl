import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../domain/services/nutrition_calculator.dart';
import '../../providers/profile_settings_providers.dart';
import '../../providers/progress_providers.dart';
import '../../widgets/brand_backdrop.dart';
import '../../widgets/count_up_text.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';
import 'onboarding_widgets.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _nameCtrl = TextEditingController();
  int _step = 0;
  static const _steps = 7;

  /// Page transitions are slower than UI micro-motion so the slide reads as
  /// one calm movement rather than a jump.
  static const _pageDuration = Duration(milliseconds: 460);

  Goal _goal = Goal.lose;
  Sex _sex = Sex.female;
  double _age = 30;
  double _height = 168;
  double _weight = 72;
  ActivityLevel _activity = ActivityLevel.light;
  double _target = 66;
  double _pace = 0.5;
  int _calorieAdjust = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _name => _nameCtrl.text.trim();
  String get _hey => _name.isEmpty ? '' : ', $_name';

  NutritionTargets get _baseTargets => NutritionCalculator.compute(
    goal: _goal,
    sex: _sex,
    age: _age.round(),
    heightCm: _height,
    weightKg: _weight,
    activity: _activity,
    paceKgPerWeek: _goal == Goal.maintain ? 0 : _pace,
  );

  NutritionTargets get _targets {
    final base = _baseTargets;
    if (_calorieAdjust == 0) return base;
    final kcal = base.calories + _calorieAdjust;
    final fat = (kcal * 0.27 / 9).round();
    final carbs = math.max(((kcal - base.protein * 4 - fat * 9) / 4).round(), 50);
    return NutritionTargets(calories: kcal, protein: base.protein, carbs: carbs, fat: fat);
  }

  int? get _weeks => _goal == Goal.maintain
      ? null
      : NutritionCalculator.weeksToGoal(goal: _goal, weightKg: _weight, targetWeightKg: _target, paceKgPerWeek: _pace);

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _page.animateToPage(step, duration: motionDuration(context, _pageDuration), curve: AppCurves.easeInOut);
  }

  void _next() {
    Haptics.light();
    if (_step == 1) {
      // Seed a sensible target weight based on the goal.
      _target = switch (_goal) {
        Goal.lose => (_weight * 0.92).roundToDouble(),
        Goal.maintain => _weight,
        Goal.gain => (_weight * 1.06).roundToDouble(),
      };
      if (_goal == Goal.gain && _pace > 0.5) _pace = 0.5;
    }
    if (_step < _steps - 1) _go(_step + 1);
  }

  void _back() {
    Haptics.tap();
    if (_step > 0) _go(_step - 1);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = UserProfile(
      name: _name,
      goal: _goal,
      sex: _sex,
      age: _age.round(),
      heightCm: _height,
      weightKg: _weight,
      activity: _activity,
      targetWeightKg: _goal == Goal.maintain ? _weight : _target,
      paceKgPerWeek: _goal == Goal.maintain ? 0 : _pace,
      targets: _targets,
      customTargets: _calorieAdjust != 0,
      createdAt: DateTime.now(),
    );
    await Haptics.success();
    await ref.read(profileProvider.notifier).save(profile);
    await ref.read(weightsProvider.notifier).log(_weight);
    // The router redirect moves us to /home once the profile exists.
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_step) {
      0 => 'Let\'s go',
      const (_steps - 1) => 'Start tracking',
      _ => 'Continue',
    };
    return PopScope(
      // System back steps backwards through onboarding instead of leaving.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BrandBackdrop(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.lg, 0),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        opacity: _step > 0 ? 1 : 0,
                        duration: motionDuration(context, AppDurations.medium),
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: _step > 0 ? _back : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      Expanded(
                        child: StepProgress(step: _step, total: _steps),
                      ),
                      const SizedBox(width: Space.sm),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${_step + 1}/$_steps',
                          textAlign: TextAlign.end,
                          style: context.text.labelMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _welcome(),
                      _goalStep(),
                      _bodyStep(),
                      _measureStep(),
                      _activityStep(),
                      _targetStep(),
                      _summaryStep(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.lg, Space.lg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Pressable(
                      child: FilledButton(
                        onPressed: _saving ? null : (_step == _steps - 1 ? _finish : _next),
                        child: AnimatedSwitcher(
                          duration: motionDuration(context, AppDurations.medium),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: child),
                          ),
                          child: _saving
                              ? const SizedBox.square(
                                  key: ValueKey('saving'),
                                  dimension: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Row(
                                  key: ValueKey(label),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(label, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: Space.xs),
                                    Icon(
                                      _step == _steps - 1 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepScaffold({
    required String title,
    required String mochi,
    MascotMood mood = MascotMood.happy,
    required List<Widget> children,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.lg),
      children: [
        MochiSays(text: mochi, mood: mood).entrance(context),
        const SizedBox(height: Space.lg),
        Semantics(header: true, child: Text(title, style: context.text.headlineMedium)).entrance(context, index: 1),
        const SizedBox(height: Space.lg),
        for (var i = 0; i < children.length; i++) children[i].entrance(context, index: i + 2),
      ],
    );
  }

  Widget _welcome() {
    Widget feature(IconData icon, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.16 : 0.10),
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: Space.xxs),
            Text(label, style: context.text.labelLarge?.copyWith(color: color)),
          ],
        ),
      ),
    );
    final palette = context.palette;
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(Space.lg),
      children: [
        const SizedBox(height: Space.md),
        Center(child: const Mascot(mood: MascotMood.excited, size: 150).popIn(context)),
        const SizedBox(height: Space.lg),
        Text(
          "Hi, I'm Mochi!",
          textAlign: TextAlign.center,
          style: context.text.headlineLarge,
        ).entrance(context, index: 1),
        const SizedBox(height: Space.xxs),
        Text(
          "Welcome to Nibbl. I'll be your food buddy.",
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
        ).entrance(context, index: 2),
        const SizedBox(height: Space.xl),
        Row(
          children: [
            feature(Icons.photo_camera_rounded, 'Snap', context.colors.primary),
            const SizedBox(width: Space.xs),
            feature(Icons.mic_rounded, 'Say', palette.fat),
            const SizedBox(width: Space.xs),
            feature(Icons.keyboard_rounded, 'Type', palette.protein),
          ],
        ).entrance(context, index: 3),
        const SizedBox(height: Space.sm),
        Text(
          'Log it any way you like. We\'ll handle the numbers.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ).entrance(context, index: 3),
        const SizedBox(height: Space.xl),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          decoration: const InputDecoration(
            labelText: 'What should I call you? (optional)',
            prefixIcon: Icon(Icons.waving_hand_rounded),
          ),
        ).entrance(context, index: 4),
        const SizedBox(height: Space.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: context.colors.onSurfaceVariant),
            const SizedBox(width: Space.xxs),
            Flexible(
              child: Text(
                'Your data stays on this device.',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
          ],
        ).entrance(context, index: 5),
      ],
    );
  }

  Widget _goalStep() => _stepScaffold(
    title: 'What\'s your goal?',
    mochi: 'Nice to meet you$_hey! What are we working towards together?',
    mood: MascotMood.excited,
    children: [
      for (final g in Goal.values)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: ChoiceCard(
            leading: Text(g.emoji, style: const TextStyle(fontSize: 24), semanticsLabel: ''),
            title: g.label,
            subtitle: g.description,
            selected: _goal == g,
            onTap: () => setState(() => _goal = g),
          ),
        ),
    ],
  );

  Widget _bodyStep() => _stepScaffold(
    title: 'About you',
    mochi: 'A couple of quick basics so I can estimate how much energy your body uses.',
    children: [
      TileSelector<Sex>(
        options: const [
          TileOption(value: Sex.female, title: 'Female', icon: Icons.female_rounded),
          TileOption(value: Sex.male, title: 'Male', icon: Icons.male_rounded),
        ],
        value: _sex,
        onChanged: (v) => setState(() => _sex = v),
      ),
      const SizedBox(height: Space.md),
      NumberPicker(
        framed: true,
        icon: Icons.cake_rounded,
        label: 'Age',
        value: _age,
        min: 13,
        max: 90,
        step: 1,
        unit: 'years',
        onChanged: (v) => setState(() => _age = v),
      ),
    ],
  );

  Widget _measureStep() {
    final bmi = _weight / math.pow(_height / 100, 2);
    final palette = context.palette;
    final (bmiLabel, bmiColor) = switch (bmi) {
      < 18.5 => ('Underweight', palette.fat),
      < 25 => ('Healthy', palette.success),
      < 30 => ('Overweight', palette.carbs),
      _ => ('Obese', palette.warning),
    };
    return _stepScaffold(
      title: 'Height & weight',
      mochi: 'No judgement here, ever. You can update these any time.',
      children: [
        NumberPicker(
          framed: true,
          icon: Icons.height_rounded,
          label: 'Height',
          value: _height,
          min: 120,
          max: 220,
          step: 1,
          unit: 'cm',
          onChanged: (v) => setState(() => _height = v),
        ),
        const SizedBox(height: Space.md),
        NumberPicker(
          framed: true,
          icon: Icons.monitor_weight_rounded,
          label: 'Weight',
          value: _weight,
          min: 35,
          max: 250,
          step: 0.5,
          decimals: 1,
          unit: 'kg',
          caption: InfoChip(label: 'BMI ${bmi.toStringAsFixed(1)} · $bmiLabel', color: bmiColor),
          onChanged: (v) => setState(() => _weight = v),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'Tip: hold + or − to change quickly.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }

  static const _activityIcons = {
    ActivityLevel.sedentary: Icons.weekend_rounded,
    ActivityLevel.light: Icons.directions_walk_rounded,
    ActivityLevel.moderate: Icons.directions_run_rounded,
    ActivityLevel.active: Icons.fitness_center_rounded,
    ActivityLevel.athlete: Icons.bolt_rounded,
  };

  Widget _activityStep() => _stepScaffold(
    title: 'How active are you?',
    mochi: 'Think of a typical week. Be honest, you can fine-tune this later.',
    children: [
      for (final a in ActivityLevel.values)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: ChoiceCard(
            leading: Icon(_activityIcons[a]),
            title: a.label,
            subtitle: a.description,
            selected: _activity == a,
            onTap: () => setState(() => _activity = a),
          ),
        ),
    ],
  );

  static String _fmtKg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  static String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _targetStep() {
    if (_goal == Goal.maintain) {
      return _stepScaffold(
        title: 'Steady as she goes',
        mochi: 'Love it. We\'ll aim for your maintenance calories and keep an eye on the trend.',
        mood: MascotMood.excited,
        children: [
          OnboardingCard(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              children: [
                Text('⚖️', style: const TextStyle(fontSize: 64), semanticsLabel: '').popIn(context),
                const SizedBox(height: Space.sm),
                Text('Keep ${_fmtKg(_weight)} kg', style: context.text.titleLarge),
                const SizedBox(height: Space.xxs),
                Text(
                  'Small ups and downs are normal. We watch the weekly average.',
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final weeks = _weeks;
    final lose = _goal == Goal.lose;
    final minT = lose ? 35.0 : _weight;
    final maxT = lose ? _weight : 250.0;
    final diff = (_weight - _target).abs();
    final paces = lose
        ? const [(0.25, 'Gentle'), (0.5, 'Steady'), (0.75, 'Brisk'), (1.0, 'Fast')]
        : const [(0.25, 'Lean'), (0.5, 'Steady')];
    return _stepScaffold(
      title: 'Target & pace',
      mochi: lose
          ? 'Slow and steady keeps the weight off for good.'
          : 'Lean gains beat fast gains. Let\'s build it right.',
      children: [
        NumberPicker(
          framed: true,
          icon: Icons.flag_rounded,
          label: 'Target weight',
          value: _target.clamp(minT, maxT),
          min: minT,
          max: maxT,
          step: 0.5,
          decimals: 1,
          unit: 'kg',
          caption: diff > 0
              ? InfoChip(label: '${lose ? '−' : '+'}${diff.toStringAsFixed(1)} kg', color: context.colors.primary)
              : null,
          onChanged: (v) => setState(() => _target = v),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Icon(Icons.speed_rounded, size: 20, color: context.colors.primary),
            const SizedBox(width: Space.xs),
            Text('Weekly pace', style: context.text.titleMedium),
          ],
        ),
        const SizedBox(height: Space.sm),
        TileSelector<double>(
          options: [
            for (final (p, word) in paces) TileOption(value: p, title: _fmtKg(p), unit: 'kg / wk', caption: word),
          ],
          value: _pace,
          onChanged: (v) => setState(() => _pace = v),
        ),
        const SizedBox(height: Space.lg),
        if (weeks != null)
          AnimatedSwitcher(
            duration: motionDuration(context, AppDurations.medium),
            child: OnboardingCard(
              key: ValueKey(weeks),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 28), semanticsLabel: ''),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: weeks == 0
                        ? Text('You\'re already there!', style: context.text.titleMedium)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reach ${_fmtKg(_target)} kg by ${_fmtDate(DateTime.now().add(Duration(days: weeks * 7)))}',
                                style: context.text.titleMedium,
                              ),
                              Text(
                                'About $weeks weeks at this pace',
                                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summaryStep() {
    final t = _targets;
    final base = _baseTargets;
    final palette = context.palette;
    final onHero = palette.onHero;
    final weeks = _weeks;

    Widget macro(String label, int g, Color c, IconData icon) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
        decoration: BoxDecoration(
          color: c.withValues(alpha: context.isDark ? 0.16 : 0.10),
          borderRadius: Radii.mdAll,
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: Space.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: CountUpText(
                value: g,
                suffix: 'g',
                style: context.text.titleLarge?.copyWith(color: c),
              ),
            ),
            Text(label, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );

    return _stepScaffold(
      title: 'Your daily plan',
      mochi: 'All done$_hey! Here\'s the plan I made for you. Nudge it if you like.',
      mood: MascotMood.excited,
      children: [
        Container(
          padding: const EdgeInsets.all(Space.xl),
          decoration: BoxDecoration(
            gradient: palette.heroGradient,
            borderRadius: Radii.lgAll,
            boxShadow: [
              BoxShadow(
                color: palette.heroGradient.colors.first.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: onHero.withValues(alpha: 0.85), size: 18),
                  const SizedBox(width: Space.xxs),
                  Text(
                    'Daily calories',
                    style: context.text.labelLarge?.copyWith(color: onHero.withValues(alpha: 0.85)),
                  ),
                ],
              ),
              const SizedBox(height: Space.xs),
              CountUpText(
                value: t.calories,
                duration: AppDurations.ring,
                style: context.text.displayLarge?.copyWith(color: onHero),
              ),
              Text('kcal / day', style: context.text.titleMedium?.copyWith(color: onHero.withValues(alpha: 0.8))),
              if (weeks != null && weeks > 0) ...[
                const SizedBox(height: Space.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
                  decoration: BoxDecoration(
                    color: onHero.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    '🎯 ${_fmtKg(_target)} kg by ${_fmtDate(DateTime.now().add(Duration(days: weeks * 7)))}',
                    style: context.text.labelMedium?.copyWith(color: onHero, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            macro('Protein', t.protein, palette.protein, Icons.egg_alt_rounded),
            const SizedBox(width: Space.xs),
            macro('Carbs', t.carbs, palette.carbs, Icons.bakery_dining_rounded),
            const SizedBox(width: Space.xs),
            macro('Fat', t.fat, palette.fat, Icons.water_drop_rounded),
          ],
        ),
        const SizedBox(height: Space.lg),
        OnboardingCard(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.sm),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: context.colors.primary),
                  const SizedBox(width: Space.xs),
                  Text('Fine-tune calories', style: context.text.titleMedium),
                  const Spacer(),
                  InfoChip(
                    label: _calorieAdjust == 0
                        ? 'Recommended'
                        : '${_calorieAdjust > 0 ? '+' : '−'}${_calorieAdjust.abs()} kcal',
                    color: _calorieAdjust == 0 ? palette.success : context.colors.primary,
                  ),
                ],
              ),
              Slider(
                value: _calorieAdjust.toDouble(),
                min: -400,
                max: 400,
                divisions: 16,
                semanticFormatterCallback: (v) => '${base.calories + v.round()} calories',
                onChanged: (v) {
                  if (v.round() != _calorieAdjust) Haptics.tap();
                  setState(() => _calorieAdjust = v.round());
                },
              ),
              Text(
                _calorieAdjust == 0
                    ? 'Maintenance ≈ ${NutritionCalculator.tdee(sex: _sex, weightKg: _weight, heightCm: _height, age: _age.round(), activity: _activity).round()} kcal'
                    : 'Adjusted from ${base.calories} kcal recommended',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
