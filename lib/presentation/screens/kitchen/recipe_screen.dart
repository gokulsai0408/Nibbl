import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food_log.dart';
import '../../../domain/entities/kitchen.dart';
import '../../../domain/entities/mochi.dart';
import '../../providers/core_providers.dart';
import '../../providers/kitchen_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/motion.dart';

/// Shows (and, for a [request], generates) one of Mochi's recipes.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, required RecipeRequest this.request}) : recipe = null;
  const RecipeScreen.saved({super.key, required Recipe this.recipe}) : request = null;

  final RecipeRequest? request;
  final Recipe? recipe;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  Recipe? _recipe;
  Object? _error;
  bool _loading = false;
  final _seen = <String>[];
  final _doneSteps = <int>{};
  final _checked = <int>{};

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    if (_recipe == null) _generate();
  }

  Future<void> _generate() async {
    final request = widget.request;
    if (request == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await cookRecipe(ref.read(aiServiceProvider), request.copyWith(avoid: [..._seen]));
      if (!mounted) return;
      _seen.add(r.title);
      Haptics.success();
      setState(() {
        _recipe = r;
        _doneSteps.clear();
        _checked.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _log(Recipe r) async {
    var servings = 1.0;
    var meal = MealType.forTime(DateTime.now());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      sheetAnimationStyle: kSheetAnimation,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final kcal = (r.perServing.kcal * servings).round();
          return Padding(
            padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg + MediaQuery.paddingOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    EmojiAvatar(emoji: r.emoji, size: 48),
                    const SizedBox(width: Space.md),
                    Expanded(child: Text(r.title, style: ctx.text.titleLarge)),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    Expanded(child: Text('How much did you eat?', style: ctx.text.titleSmall)),
                    IconButton.filledTonal(
                      tooltip: 'Less',
                      onPressed: servings > 0.5 ? () => setSheet(() => servings -= 0.5) : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 92,
                      child: Text(
                        '${formatMultiplier(servings)} serving${servings == 1 ? '' : 's'}',
                        textAlign: TextAlign.center,
                        style: ctx.text.titleSmall,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'More',
                      onPressed: servings < 6 ? () => setSheet(() => servings += 0.5) : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                MealPicker(value: meal, onChanged: (m) => setSheet(() => meal = m)),
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check_rounded),
                  label: Text('Log $kcal kcal to ${meal.label}'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(logsProvider.notifier)
        .addFoods(
          [r.toLoggedFood(servings: servings)],
          meal: meal,
          day: DateTime.now().dateOnly,
          source: LogSource.manual,
        );
    Haptics.success();
    if (mounted) showAppSnack(context, 'Logged ${r.title} to ${meal.label} ${meal.emoji}');
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    final saved = r != null && ref.watch(savedRecipesProvider.select((l) => l.any((x) => x.id == r.id)));
    final canRetry = widget.request != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(r == null || _loading ? 'Mochi\'s kitchen' : 'Recipe'),
        actions: [
          if (r != null && !_loading)
            IconButton(
              tooltip: 'Share with friends',
              onPressed: () => context.push('/social/new', extra: r),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          if (r != null && !_loading)
            IconButton(
              tooltip: saved ? 'Remove from saved' : 'Save recipe',
              onPressed: () {
                Haptics.light();
                ref.read(savedRecipesProvider.notifier).toggle(r);
                showAppSnack(context, saved ? 'Removed from saved recipes' : 'Saved to your kitchen');
              },
              icon: AnimatedSwitcher(
                duration: motionDuration(context, AppDurations.medium),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  key: ValueKey(saved),
                  color: saved ? context.colors.primary : null,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: motionDuration(context, AppDurations.slow),
        switchInCurve: AppCurves.easeOut,
        child: _loading
            ? const _Cooking(key: ValueKey('loading'))
            : _error != null
            ? Center(
                key: const ValueKey('error'),
                child: ErrorState(message: _error.toString(), onRetry: canRetry ? _generate : null),
              )
            : r == null
            ? const SizedBox.shrink()
            : _RecipeBody(
                key: ValueKey(r.id),
                recipe: r,
                doneSteps: _doneSteps,
                checked: _checked,
                onToggleStep: (i) {
                  Haptics.tap();
                  setState(() => _doneSteps.contains(i) ? _doneSteps.remove(i) : _doneSteps.add(i));
                  if (_doneSteps.length == r.steps.length) Haptics.success();
                },
                onToggleIngredient: (i) {
                  Haptics.tap();
                  setState(() => _checked.contains(i) ? _checked.remove(i) : _checked.add(i));
                },
              ),
      ),
      bottomNavigationBar: r == null || _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: Space.sm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xs),
                child: Row(
                  children: [
                    if (canRetry) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Another', maxLines: 1, softWrap: false),
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                        onPressed: () => _log(r),
                        icon: const Icon(Icons.restaurant_rounded),
                        label: const Text('I made this · Log it', maxLines: 1, softWrap: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Mochi in a chef hat while the recipe is generated.
class _Cooking extends StatefulWidget {
  const _Cooking({super.key});

  @override
  State<_Cooking> createState() => _CookingState();
}

class _CookingState extends State<_Cooking> {
  static const _lines = [
    'Checking your ingredients…',
    'Picking something simple…',
    'Writing the steps…',
    'Counting calories…',
  ];
  int _i = 0;
  late final Timer _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
    if (mounted) setState(() => _i = (_i + 1) % _lines.length);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(mood: MascotMood.excited, size: 150, outfit: {MochiItem.chefHat}, interactive: false),
            const SizedBox(height: Space.lg),
            Text('Mochi is cooking up an idea', style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Space.xs),
            AnimatedSwitcher(
              duration: motionDuration(context, AppDurations.medium),
              child: Text(
                _lines[_i],
                key: ValueKey(_i),
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: Space.lg),
            const SizedBox(width: 160, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody({
    super.key,
    required this.recipe,
    required this.doneSteps,
    required this.checked,
    required this.onToggleStep,
    required this.onToggleIngredient,
  });

  final Recipe recipe;
  final Set<int> doneSteps;
  final Set<int> checked;
  final ValueChanged<int> onToggleStep;
  final ValueChanged<int> onToggleIngredient;

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final p = context.palette;
    final m = r.perServing;
    final progress = r.steps.isEmpty ? 0.0 : doneSteps.length / r.steps.length;

    Widget stat(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.colors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.xl),
      children: [
        // ---- Hero
        AppCard(
          gradient: BrandSurfaces.hero(context.isDark),
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EmojiAvatar(emoji: r.emoji, size: 64),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(r.title, style: context.text.headlineSmall)),
                ],
              ),
              if (r.summary.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(r.summary, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
              const SizedBox(height: Space.md),
              Wrap(
                spacing: Space.xs,
                runSpacing: Space.xs,
                children: [
                  stat(Icons.timer_outlined, '${r.minutes} min'),
                  stat(Icons.people_alt_outlined, '${r.servings} serving${r.servings == 1 ? '' : 's'}'),
                  stat(Icons.local_fire_department_rounded, '~${m.kcal.round()} kcal each'),
                ],
              ),
            ],
          ),
        ).entrance(context),
        const SizedBox(height: Space.sm),

        // ---- Macros per serving
        Row(
          children: [
            _Macro(label: 'Protein', value: m.protein, color: p.protein),
            const SizedBox(width: Space.xs),
            _Macro(label: 'Carbs', value: m.carbs, color: p.carbs),
            const SizedBox(width: Space.xs),
            _Macro(label: 'Fat', value: m.fat, color: p.fat),
          ],
        ).entrance(context, index: 1),
        const SizedBox(height: Space.lg),

        // ---- Ingredients
        SectionHeader(title: 'Ingredients · ${r.ingredients.length}'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Space.xs),
          child: Column(
            children: [
              for (final (i, ing) in r.ingredients.indexed)
                CheckboxListTile(
                  value: checked.contains(i),
                  onChanged: (_) => onToggleIngredient(i),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    ing.name,
                    style: context.text.bodyLarge?.copyWith(
                      decoration: checked.contains(i) ? TextDecoration.lineThrough : null,
                      color: checked.contains(i) ? context.colors.onSurfaceVariant : null,
                    ),
                  ),
                  subtitle: ing.fromPantry
                      ? null
                      : Text('Not in your list', style: context.text.labelSmall?.copyWith(color: p.warning)),
                  secondary: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      ing.amount,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(color: context.colors.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),

        // ---- Steps
        SectionHeader(
          title: 'Steps',
          trailing: Text(
            '${doneSteps.length}/${r.steps.length} done',
            style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress),
            duration: motionDuration(context, AppDurations.slow),
            curve: AppCurves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
          ),
        ),
        const SizedBox(height: Space.sm),
        for (final (i, step) in r.steps.indexed)
          _StepTile(
            index: i,
            step: step,
            done: doneSteps.contains(i),
            last: i == r.steps.length - 1,
            onTap: () => onToggleStep(i),
          ),
        if (doneSteps.length == r.steps.length && r.steps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Row(
              children: [
                const Mascot(mood: MascotMood.excited, size: 48, interactive: false),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text('All done! Enjoy your ${r.title.toLowerCase()} 🎉', style: context.text.titleSmall),
                ),
              ],
            ),
          ).popIn(context),

        // ---- Tips
        if (r.tips.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          const SectionHeader(title: 'Tips'),
          AppCard(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, t) in r.tips.indexed) ...[
                  if (i > 0) const SizedBox(height: Space.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💡', style: context.text.bodyLarge),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(t, style: context.text.bodyMedium)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.16 : 0.1),
          borderRadius: Radii.smAll,
        ),
        child: Column(
          children: [
            Text(
              formatGrams(value),
              style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            Text(label, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// One numbered step on a vertical timeline; tap to mark it done.
class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.done,
    required this.last,
    required this.onTap,
  });

  final int index;
  final RecipeStep step;
  final bool done;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dur = motionDuration(context, AppDurations.medium);
    final primary = context.colors.primary;
    final success = context.palette.success;
    return Semantics(
      button: true,
      checked: done,
      label: 'Step ${index + 1}: ${step.title}. ${step.detail}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.smAll,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    const SizedBox(height: Space.sm),
                    AnimatedContainer(
                      duration: dur,
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? success : primary.withValues(alpha: context.isDark ? 0.2 : 0.12),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: context.text.labelLarge?.copyWith(color: primary, fontWeight: FontWeight.w800),
                            ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: done ? success.withValues(alpha: 0.5) : context.colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, Space.sm, Space.xs, Space.md),
                  child: AnimatedOpacity(
                    duration: dur,
                    opacity: done ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(step.title, style: context.text.titleSmall)),
                            if (step.minutes > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(Radii.pill),
                                ),
                                child: Text('${step.minutes} min', style: context.text.labelSmall),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(step.detail, style: context.text.bodyMedium?.copyWith(height: 1.4)),
                      ],
                    ),
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
