import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/date_x.dart';
import '../../../domain/entities/food.dart';
import '../../../domain/entities/food_log.dart';
import '../../../domain/entities/tracking.dart';
import '../../providers/food_providers.dart';
import '../../providers/log_providers.dart';
import '../../widgets/common.dart';

/// Food database: search, favorites, recents, saved meals, custom foods.
class FoodsScreen extends ConsumerStatefulWidget {
  const FoodsScreen({super.key, this.initialMeal, this.initialTab = 0});
  final MealType? initialMeal;
  final int initialTab;

  @override
  ConsumerState<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends ConsumerState<FoodsScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 5, vsync: this, initialIndex: widget.initialTab.clamp(0, 4));
  final _search = TextEditingController();
  String _query = '';
  late MealType _meal = widget.initialMeal ?? MealType.forTime(DateTime.now());

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _quickLog(List<LoggedFood> foods, LogSource source, String label) async {
    Haptics.success();
    final day = ref.read(selectedDateProvider);
    final added = await ref.read(logsProvider.notifier).addFoods(foods, meal: _meal, day: day, source: source);
    if (!mounted) return;
    showAppSnack(
      context,
      'Added $label to ${_meal.label}',
      onUndo: () => ref.read(logsProvider.notifier).removeAll(added.map((l) => l.id)),
    );
  }

  void _openFood(Food f) => context.push('/food/${Uri.encodeComponent(f.id)}?meal=${_meal.name}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foods'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(164),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search 70+ foods & your custom foods',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? IconButton(
                            tooltip: 'Scan barcode',
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: () => context.push('/barcode?meal=${_meal.name}'),
                          )
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                          ),
                  ),
                  onChanged: (v) {
                    setState(() => _query = v);
                    if (v.isNotEmpty && _tabs.index != 0) _tabs.animateTo(0);
                  },
                ),
              ),
              const SizedBox(height: Space.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: MealPicker(value: _meal, onChanged: (m) => setState(() => _meal = m)),
              ),
              PillTabBar(
                controller: _tabs,
                scrollable: true,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Favorites'),
                  Tab(text: 'Recent'),
                  Tab(text: 'Meals'),
                  Tab(text: 'My foods'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New custom food',
        onPressed: () => context.push('/foods/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_allTab(), _favoritesTab(), _recentTab(), _mealsTab(), _customTab()],
      ),
    );
  }

  Widget _foodList(List<Food> foods, {bool allowDelete = false}) {
    final favorites = ref.watch(favoritesProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 100),
      itemCount: foods.length,
      itemBuilder: (context, i) {
        final f = foods[i];
        final tile = _FoodTile(
          food: f,
          isFavorite: favorites.contains(f.id),
          onTap: () => _openFood(f),
          onQuickAdd: () => _quickLog([LoggedFood.fromFood(f)], LogSource.search, f.name),
        );
        if (!allowDelete) return tile;
        return SwipeToDelete(
          dismissKey: ValueKey('custom-${f.id}'),
          surfaceColor: context.theme.scaffoldBackgroundColor,
          onDelete: () {
            ref.read(foodsProvider.notifier).delete(f.id);
            showAppSnack(context, 'Deleted ${f.name}', onUndo: () => ref.read(foodsProvider.notifier).upsert(f));
          },
          child: tile,
        );
      },
    );
  }

  Widget _allTab() {
    final results = ref.watch(foodSearchProvider(_query));
    if (results.isEmpty) {
      return EmptyState(
        emoji: '🔍',
        title: 'No results for "$_query"',
        message: 'Create it as a custom food, or describe it with AI.',
        actionLabel: 'Describe with AI',
        onAction: () => context.push('/log/text?meal=${_meal.name}'),
      );
    }
    return _foodList(results);
  }

  Widget _favoritesTab() {
    final favs = ref.watch(favoritesProvider);
    final foods = ref.watch(foodsProvider).where((f) => favs.contains(f.id)).toList();
    if (foods.isEmpty) {
      return const EmptyState(
        emoji: '⭐',
        title: 'No favorites yet',
        message: 'Tap the star on any food to pin it here for one-tap logging.',
      );
    }
    return _foodList(foods);
  }

  Widget _recentTab() {
    final recents = ref.watch(recentFoodsProvider);
    if (recents.isEmpty) {
      return const EmptyState(
        emoji: '🕑',
        title: 'Nothing recent',
        message: 'Foods you log show up here so you can re-log them in one tap.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 100),
      itemCount: recents.length,
      itemBuilder: (context, i) {
        final f = recents[i];
        return ListTile(
          leading: EmojiAvatar(emoji: f.emoji, size: 44),
          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${formatMultiplier(f.multiplier)} × ${f.servingLabel} · ${formatKcal(f.macros.kcal)} kcal'),
          trailing: IconButton.filledTonal(
            tooltip: 'Log ${f.name} again',
            onPressed: () => _quickLog([f], LogSource.search, f.name),
            icon: const Icon(Icons.replay_rounded),
          ),
        );
      },
    );
  }

  Widget _mealsTab() {
    final templates = ref.watch(templatesProvider);
    if (templates.isEmpty) {
      return const EmptyState(
        emoji: '🍱',
        title: 'No saved meals',
        message:
            'On the Today screen, open a meal\'s ••• menu and choose "Save as meal template". '
            'You can also save from the AI review screen.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 100),
      itemCount: templates.length,
      itemBuilder: (context, i) {
        final t = templates[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: SwipeToDelete(
            dismissKey: ValueKey('tpl-${t.id}'),
            onDelete: () {
              ref.read(templatesProvider.notifier).delete(t.id);
              showAppSnack(
                context,
                'Deleted "${t.name}"',
                onUndo: () => ref.read(templatesProvider.notifier).restore(t),
              );
            },
            child: _TemplateCard(template: t, onLog: () => _quickLog(t.items, LogSource.template, t.name)),
          ),
        );
      },
    );
  }

  Widget _customTab() {
    final foods = ref.watch(foodsProvider).where((f) => f.isCustom || f.barcode != null).toList();
    if (foods.isEmpty) {
      return EmptyState(
        emoji: '🧑‍🍳',
        title: 'No custom foods',
        message: 'Add your own recipes or products. Scanned barcodes are saved here too.',
        actionLabel: 'Create custom food',
        onAction: () => context.push('/foods/new'),
      );
    }
    return _foodList(foods, allowDelete: true);
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.isFavorite, required this.onTap, required this.onQuickAdd});
  final Food food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: EmojiAvatar(emoji: food.emoji, size: 44, heroTag: 'food-${food.id}'),
      title: Row(
        children: [
          Flexible(child: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isFavorite) ...[
            const SizedBox(width: 4),
            Icon(Icons.star_rounded, size: 16, color: context.palette.carbs, semanticLabel: 'Favorite'),
          ],
        ],
      ),
      subtitle: Text(
        [if (food.brand != null) food.brand!, food.servingLabel, '${formatKcal(food.macros.kcal)} kcal'].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton.filledTonal(
        tooltip: 'Quick add ${food.name}',
        onPressed: onQuickAdd,
        icon: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onLog});
  final MealTemplate template;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final m = template.macros;
    return AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          EmojiAvatar(emoji: template.emoji, size: 48),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: context.text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  template.items.map((i) => i.name).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text('${formatKcal(m.kcal)} kcal · P ${m.protein.round()}g', style: context.text.labelMedium),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onLog, child: const Text('Log')),
        ],
      ),
    );
  }
}
