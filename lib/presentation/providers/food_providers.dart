import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/tracking.dart';
import 'core_providers.dart';

const _uuid = Uuid();

class FoodsNotifier extends Notifier<List<Food>> {
  @override
  List<Food> build() => ref.watch(foodRepoProvider).all();

  Food? byId(String id) {
    for (final f in state) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> upsert(Food food) async {
    await ref.read(foodRepoProvider).upsert(food);
    state = ref.read(foodRepoProvider).all();
  }

  Future<void> delete(String id) async {
    await ref.read(foodRepoProvider).delete(id);
    state = ref.read(foodRepoProvider).all();
  }

  String newCustomId() => 'custom_${_uuid.v4()}';
}

final foodsProvider = NotifierProvider<FoodsNotifier, List<Food>>(FoodsNotifier.new);

class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(foodRepoProvider).favorites();

  Future<void> toggle(String foodId) async {
    final next = {...state};
    if (!next.remove(foodId)) next.add(foodId);
    state = next;
    await ref.read(foodRepoProvider).setFavorites(next);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

/// Ranked food search: prefix matches first, then word matches, then substring.
final foodSearchProvider = Provider.family<List<Food>, String>((ref, query) {
  final foods = ref.watch(foodsProvider);
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return [...foods]..sort((a, b) => a.name.compareTo(b.name));
  }
  int rank(Food f) {
    final name = f.name.toLowerCase();
    final brand = (f.brand ?? '').toLowerCase();
    if (name.startsWith(q)) return 0;
    if (name.split(RegExp(r'[\s(),]+')).any((w) => w.startsWith(q))) return 1;
    if (name.contains(q) || brand.contains(q)) return 2;
    return 99;
  }

  final matches = foods.where((f) => rank(f) < 99).toList()
    ..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.length.compareTo(b.name.length);
    });
  return matches;
});

class TemplatesNotifier extends Notifier<List<MealTemplate>> {
  @override
  List<MealTemplate> build() => ref.watch(templateRepoProvider).all();

  Future<MealTemplate> create(String name, List<LoggedFood> items, {String emoji = '🍱'}) async {
    final t = MealTemplate(id: _uuid.v4(), name: name, emoji: emoji, items: items, createdAt: DateTime.now());
    state = [t, ...state];
    await ref.read(templateRepoProvider).upsert(t);
    return t;
  }

  Future<void> delete(String id) async {
    state = state.where((t) => t.id != id).toList();
    await ref.read(templateRepoProvider).delete(id);
  }

  Future<void> restore(MealTemplate t) async {
    state = [t, ...state.where((x) => x.id != t.id)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await ref.read(templateRepoProvider).upsert(t);
  }
}

final templatesProvider = NotifierProvider<TemplatesNotifier, List<MealTemplate>>(TemplatesNotifier.new);
