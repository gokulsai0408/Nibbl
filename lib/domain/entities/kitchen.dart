import 'food_log.dart';
import 'macros.dart';

/// Something the user has at home to cook with.
class PantryItem {
  const PantryItem({required this.id, required this.name, required this.emoji, required this.addedAt, this.qty = ''});

  final String id;
  final String name;
  final String emoji;
  final DateTime addedAt;

  /// Optional amount on hand, e.g. "4" or "500 g".
  final String qty;

  /// How it's described to the AI: "Eggs (4)".
  String get forPrompt => qty.isEmpty ? name : '$name ($qty)';

  PantryItem copyWith({String? name, String? qty}) =>
      PantryItem(id: id, name: name ?? this.name, emoji: emoji, addedAt: addedAt, qty: qty ?? this.qty);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'addedAt': addedAt.toIso8601String(),
    'qty': qty,
  };

  factory PantryItem.fromJson(Map<String, dynamic> j) => PantryItem(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '🥫',
    addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
    qty: j['qty'] as String? ?? '',
  );
}

/// What the user wants from Mochi's recipe.
class RecipeRequest {
  const RecipeRequest({
    required this.pantry,
    this.servings = 1,
    this.maxMinutes = 30,
    this.kcalPerServing,
    this.proteinLeft,
    this.meal,
    this.note = '',
    this.avoid = const [],
    this.basics = true,
    this.fix = '',
  });

  /// Ingredients on hand, with amounts where known ("Eggs (4)").
  final List<String> pantry;
  final int servings;
  final int maxMinutes;

  /// Calorie budget per serving, if the user wants it to fit their day.
  final int? kcalPerServing;
  final int? proteinLeft;
  final String? meal;

  /// Free-text craving or constraint ("something spicy", "no oven").
  final String note;

  /// Dishes already suggested, so "Try another" gives something new.
  final List<String> avoid;

  /// Salt, oil and common spices may be used without being listed.
  final bool basics;

  /// Correction for a retry ("You used X, which I don't have").
  final String fix;

  RecipeRequest copyWith({List<String>? avoid, String? fix}) => RecipeRequest(
    pantry: pantry,
    servings: servings,
    maxMinutes: maxMinutes,
    kcalPerServing: kcalPerServing,
    proteinLeft: proteinLeft,
    meal: meal,
    note: note,
    avoid: avoid ?? this.avoid,
    basics: basics,
    fix: fix ?? this.fix,
  );
}

class RecipeIngredient {
  const RecipeIngredient({required this.name, required this.amount, this.fromPantry = true});

  final String name;
  final String amount;

  /// False for optional extras the user may not have (salt, water…).
  final bool fromPantry;

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'fromPantry': fromPantry};

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
    name: j['name']?.toString() ?? '',
    amount: j['amount']?.toString() ?? '',
    fromPantry: j['fromPantry'] as bool? ?? j['from_pantry'] as bool? ?? true,
  );
}

class RecipeStep {
  const RecipeStep({required this.title, required this.detail, this.minutes = 0});

  final String title;
  final String detail;
  final int minutes;

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail, 'minutes': minutes};

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
    title: j['title']?.toString() ?? '',
    detail: j['detail']?.toString() ?? j['text']?.toString() ?? '',
    minutes: (j['minutes'] as num? ?? 0).round(),
  );
}

/// A dish Mochi suggests from what's in the kitchen.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.emoji,
    required this.summary,
    required this.minutes,
    required this.servings,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    required this.tips,
    required this.perServing,
    required this.gramsPerServing,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String emoji;
  final String summary;
  final int minutes;
  final int servings;
  final String difficulty;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tips;

  /// Nutrition for one serving.
  final Macros perServing;
  final double gramsPerServing;
  final DateTime createdAt;

  /// One serving as a loggable food.
  LoggedFood toLoggedFood({double servings = 1}) => LoggedFood(
    name: title,
    emoji: emoji,
    servingLabel: '1 serving',
    servingGrams: gramsPerServing,
    base: perServing,
    multiplier: servings,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'summary': summary,
    'minutes': minutes,
    'servings': servings,
    'difficulty': difficulty,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': [for (final s in steps) s.toJson()],
    'tips': tips,
    'perServing': perServing.toJson(),
    'gramsPerServing': gramsPerServing,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Recipe',
    emoji: j['emoji'] as String? ?? '🍳',
    summary: j['summary'] as String? ?? '',
    minutes: (j['minutes'] as num? ?? 20).round(),
    servings: (j['servings'] as num? ?? 1).round(),
    difficulty: j['difficulty'] as String? ?? 'Easy',
    ingredients: [
      for (final i in (j['ingredients'] as List? ?? const []))
        RecipeIngredient.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
    steps: [
      for (final s in (j['steps'] as List? ?? const [])) RecipeStep.fromJson(Map<String, dynamic>.from(s as Map)),
    ],
    tips: [for (final t in (j['tips'] as List? ?? const [])) t.toString()],
    perServing: Macros.fromJson(Map<String, dynamic>.from(j['perServing'] as Map? ?? const {})),
    gramsPerServing: (j['gramsPerServing'] as num? ?? 300).toDouble(),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
