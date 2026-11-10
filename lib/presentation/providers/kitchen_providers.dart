import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_store.dart';
import '../../domain/ai/ai_service.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/services/ingredient_matcher.dart';

/// Picks a fitting emoji for a typed ingredient.
String ingredientEmoji(String name) {
  final n = name.toLowerCase();
  const map = <String, String>{
    'egg': '🥚',
    'milk': '🥛',
    'curd': '🥣',
    'yogurt': '🥣',
    'dahi': '🥣',
    'paneer': '🧀',
    'cheese': '🧀',
    'butter': '🧈',
    'ghee': '🧈',
    'bread': '🍞',
    'rice': '🍚',
    'atta': '🌾',
    'flour': '🌾',
    'roti': '🫓',
    'oats': '🥣',
    'poha': '🍚',
    'rava': '🌾',
    'suji': '🌾',
    'pasta': '🍝',
    'noodle': '🍜',
    'dal': '🫘',
    'lentil': '🫘',
    'chana': '🫘',
    'rajma': '🫘',
    'bean': '🫘',
    'chicken': '🍗',
    'mutton': '🍖',
    'fish': '🐟',
    'prawn': '🦐',
    'tofu': '🧊',
    'soya': '🫘',
    'potato': '🥔',
    'aloo': '🥔',
    'onion': '🧅',
    'tomato': '🍅',
    'garlic': '🧄',
    'ginger': '🫚',
    'chilli': '🌶️',
    'chili': '🌶️',
    'capsicum': '🫑',
    'pepper': '🫑',
    'carrot': '🥕',
    'spinach': '🥬',
    'palak': '🥬',
    'cabbage': '🥬',
    'lettuce': '🥬',
    'broccoli': '🥦',
    'cauliflower': '🥦',
    'gobi': '🥦',
    'peas': '🫛',
    'corn': '🌽',
    'cucumber': '🥒',
    'mushroom': '🍄',
    'brinjal': '🍆',
    'eggplant': '🍆',
    'lemon': '🍋',
    'lime': '🍋',
    'banana': '🍌',
    'apple': '🍎',
    'mango': '🥭',
    'avocado': '🥑',
    'coconut': '🥥',
    'peanut': '🥜',
    'nut': '🥜',
    'almond': '🥜',
    'oil': '🫒',
    'honey': '🍯',
    'sugar': '🍬',
    'salt': '🧂',
    'masala': '🧂',
    'spice': '🧂',
    'jeera': '🧂',
    'cumin': '🧂',
    'turmeric': '🧂',
    'coriander': '🌿',
    'mint': '🌿',
    'herb': '🌿',
    'curry leaves': '🌿',
  };
  for (final e in map.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return '🥫';
}

/// A few staples offered as one-tap chips (typing is faster for the rest).
const kitchenStaples = <(String, String)>[
  ('Eggs', '🥚'),
  ('Onions', '🧅'),
  ('Tomatoes', '🍅'),
  ('Potatoes', '🥔'),
  ('Rice', '🍚'),
  ('Atta', '🌾'),
  ('Dal', '🫘'),
  ('Paneer', '🧀'),
];

class PantryNotifier extends Notifier<List<PantryItem>> {
  late final JsonBox<PantryItem> _box = JsonBox(
    HiveStore.box(HiveStore.pantry),
    PantryItem.fromJson,
    (p) => p.toJson(),
  );

  @override
  List<PantryItem> build() => _box.values()..sort((a, b) => a.addedAt.compareTo(b.addedAt));

  bool contains(String name) => state.any((p) => p.name.toLowerCase() == name.trim().toLowerCase());

  /// Adds items, skipping blanks and duplicates. Returns how many were added.
  Future<int> addAll(Iterable<(String, String?)> items, {Map<String, String> qty = const {}}) async {
    final now = DateTime.now();
    final added = <PantryItem>[];
    final seen = {for (final p in state) p.name.toLowerCase()};
    var i = 0;
    for (final (rawName, emoji) in items) {
      final name = rawName.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      final pretty = name[0].toUpperCase() + name.substring(1);
      added.add(
        PantryItem(
          id: 'p${now.microsecondsSinceEpoch}_${i++}',
          name: pretty,
          emoji: emoji ?? ingredientEmoji(pretty),
          addedAt: now.add(Duration(microseconds: i)),
          qty: qty[name] ?? '',
        ),
      );
    }
    if (added.isEmpty) return 0;
    state = [...state, ...added];
    await _box.putAll({for (final p in added) p.id: p});
    return added.length;
  }

  /// Splits "4 eggs, 500g rice and onion" into separate items with amounts.
  Future<int> addText(String text) {
    final parsed = [
      for (final part in text.split(RegExp(r',|;|\n|\band\b|&|\+', caseSensitive: false))) parseIngredient(part),
    ];
    return addAll(
      [for (final (name, _) in parsed) (name, null)],
      qty: {
        for (final (name, q) in parsed)
          if (q.isNotEmpty) name: q,
      },
    );
  }

  Future<void> update(PantryItem item) async {
    state = [for (final p in state) p.id == item.id ? item : p];
    await _box.put(item.id, item);
  }

  Future<void> remove(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _box.delete(id);
  }

  Future<void> restore(PantryItem item) async {
    state = [...state, item]..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    await _box.put(item.id, item);
  }

  Future<void> clear() async {
    state = const [];
    await _box.clear();
  }
}

final pantryProvider = NotifierProvider<PantryNotifier, List<PantryItem>>(PantryNotifier.new);

class SavedRecipesNotifier extends Notifier<List<Recipe>> {
  late final JsonBox<Recipe> _box = JsonBox(HiveStore.box(HiveStore.recipes), Recipe.fromJson, (r) => r.toJson());

  @override
  List<Recipe> build() => _box.values()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool isSaved(String id) => state.any((r) => r.id == id);

  Future<void> toggle(Recipe r) async {
    if (isSaved(r.id)) {
      state = state.where((x) => x.id != r.id).toList();
      await _box.delete(r.id);
    } else {
      state = [r, ...state];
      await _box.put(r.id, r);
    }
  }
}

final savedRecipesProvider = NotifierProvider<SavedRecipesNotifier, List<Recipe>>(SavedRecipesNotifier.new);

/// Number of ingredients in the kitchen (cheap to watch).
final pantryCountProvider = Provider<int>((ref) => ref.watch(pantryProvider).length);

/// Asks the AI for a recipe, then checks every ingredient against the
/// kitchen. If it used something the user doesn't have, it retries once with
/// a correction; anything still missing is flagged in the result.
Future<Recipe> cookRecipe(AiService ai, RecipeRequest request) async {
  var recipe = await ai.suggestRecipe(request);
  var missing = missingIngredients(recipe.ingredients.map((i) => i.name), request.pantry, allowBasics: request.basics);
  if (missing.isNotEmpty) {
    recipe = await ai.suggestRecipe(
      request.copyWith(
        fix:
            'Your last idea used ${missing.join(', ')}, which I do not have. '
            'Use ONLY my listed ingredients this time.',
      ),
    );
    missing = missingIngredients(recipe.ingredients.map((i) => i.name), request.pantry, allowBasics: request.basics);
  }
  final missingSet = missing.toSet();
  return Recipe(
    id: recipe.id,
    title: recipe.title,
    emoji: recipe.emoji,
    summary: recipe.summary,
    minutes: recipe.minutes,
    servings: recipe.servings,
    difficulty: recipe.difficulty,
    ingredients: [
      for (final i in recipe.ingredients)
        RecipeIngredient(name: i.name, amount: i.amount, fromPantry: !missingSet.contains(i.name)),
    ],
    steps: recipe.steps,
    tips: recipe.tips.take(2).toList(),
    perServing: recipe.perServing,
    gramsPerServing: recipe.gramsPerServing,
    createdAt: recipe.createdAt,
  );
}
