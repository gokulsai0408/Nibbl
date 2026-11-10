import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/entities/food_log.dart';
import '../../providers/food_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/portion_editor.dart';

class FoodDetailScreen extends ConsumerStatefulWidget {
  const FoodDetailScreen({super.key, required this.foodId, this.initialMeal});
  final String foodId;
  final MealType? initialMeal;

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  double _mult = 1;
  late MealType _meal = widget.initialMeal ?? MealType.forTime(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final id = Uri.decodeComponent(widget.foodId);
    final food = ref.watch(foodsProvider.select((list) => list.where((f) => f.id == id).firstOrNull));
    final isFav = ref.watch(favoritesProvider.select((s) => s.contains(id)));

    if (food == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            emoji: '🤷',
            title: 'Food not found',
            message: 'It may have been deleted.',
            actionLabel: 'Go back',
            onAction: () => context.pop(),
          ),
        ),
      );
    }

    final item = LoggedFood.fromFood(food, multiplier: _mult);
    final m = item.macros;
    final p = context.palette;
    final kcalP = m.protein * 4, kcalC = m.carbs * 4, kcalF = m.fat * 9;
    final total = kcalP + kcalC + kcalF;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () {
              Haptics.light();
              ref.read(favoritesProvider.notifier).toggle(food.id);
            },
            icon: AnimatedSwitcher(
              duration: motionDuration(context, AppDurations.medium),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: c),
              ),
              child: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                key: ValueKey(isFav),
                color: isFav ? p.carbs : null,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        children: [
          Center(
            child: EmojiAvatar(emoji: food.emoji, size: 104, heroTag: 'food-${food.id}'),
          ),
          const SizedBox(height: Space.md),
          Text(food.name, textAlign: TextAlign.center, style: context.text.headlineSmall),
          if (food.brand != null)
            Text(
              food.brand!,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          const SizedBox(height: Space.xl),
          AppCard(
            child: PortionEditor(
              food: item,
              max: 6,
              // Database foods: amount only; edit nutrition after adding.
              allowNutritionEdit: false,
              onChanged: (f) => setState(() => _mult = f.multiplier),
            ),
          ).entrance(context, index: 1),
          const SizedBox(height: Space.md),
          if (total > 0)
            AppCard(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 110,
                    child: Semantics(
                      label:
                          'Calories split: protein ${(kcalP / total * 100).round()} percent, '
                          'carbs ${(kcalC / total * 100).round()} percent, fat ${(kcalF / total * 100).round()} percent',
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(value: kcalP, color: p.protein, radius: 18, showTitle: false),
                            PieChartSectionData(value: kcalC, color: p.carbs, radius: 18, showTitle: false),
                            PieChartSectionData(value: kcalF, color: p.fat, radius: 18, showTitle: false),
                          ],
                        ),
                        duration: motionDuration(context, AppDurations.slow),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calorie split', style: context.text.titleMedium),
                        const SizedBox(height: Space.xs),
                        _legend(context, p.protein, 'Protein', kcalP / total),
                        _legend(context, p.carbs, 'Carbs', kcalC / total),
                        _legend(context, p.fat, 'Fat', kcalF / total),
                      ],
                    ),
                  ),
                ],
              ),
            ).entrance(context, index: 2),
          const SizedBox(height: Space.lg),
          MealPicker(value: _meal, onChanged: (v) => setState(() => _meal = v)),
          const SizedBox(height: Space.md),
          Pressable(
            child: FilledButton.icon(
              onPressed: () async {
                final day = ref.read(selectedDateProvider);
                await ref.read(logsProvider.notifier).addFoods([item], meal: _meal, day: day, source: LogSource.search);
                await Haptics.success();
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                context.pop();
                messenger.showSnackBar(SnackBar(content: Text('Added ${food.name} to ${_meal.label}')));
              },
              icon: const Icon(Icons.check_rounded),
              label: Text('Log to ${_meal.label}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String label, double frac) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: Space.xs),
        Expanded(child: Text(label, style: context.text.bodyMedium)),
        Text('${(frac * 100).round()}%', style: context.text.labelLarge),
      ],
    ),
  );
}
