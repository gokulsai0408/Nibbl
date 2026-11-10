import 'dart:convert';
import 'dart:math' as math;

import '../../domain/ai/ai_service.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/entities/macros.dart';

/// Prompts, schemas and parsing for the kitchen features, shared by every
/// AI provider.
abstract final class RecipePrompts {
  static const recipeSystem = '''
You are Mochi, a home-cooking helper. Suggest ONE realistic, everyday dish the user can cook right now.

Ingredients (strict):
- Use ONLY items from the user's list. Never add anything that is not on it.
- Always allowed: water, salt. Oil, ghee and common dry spices are allowed ONLY if the user says basics are available.
- Respect amounts given in brackets: never use more than the user has.
- Use 2-7 ingredients. Pick a real, well-known dish (home-style Indian, egg dish, stir-fry, salad, sandwich…), not a random mix. If the list is too limited for a proper dish, make the simplest sensible thing.
- Set fromPantry=true for listed items and false for allowed basics.

Style (short and clear):
- title: the dish name only. summary: max 10 words.
- 3-6 steps. Each step: a 2-4 word title and ONE or TWO short sentences with heat level, time and a "done when" cue.
- Exact amounts for the requested servings (g, cups, tbsp, pieces).
- Max 2 tips, each under 12 words.
- difficulty: Easy or Medium. Must fit the time limit with common equipment.

Nutrition is PER SERVING and realistic, including the oil/ghee used: calories ≈ protein*4 + carbs*4 + fat*9. gramsPerServing = cooked weight of one serving. If a calorie budget is given, stay at or under it.''';

  static const pantryScanSystem =
      'You identify cooking ingredients in a photo of a fridge, pantry shelf, counter or groceries. '
      'List every distinct, clearly visible food ingredient with a short common name (e.g. "Eggs", '
      '"Tomatoes", "Paneer", "Basmati rice") and one fitting emoji. Ignore non-food items and do not guess '
      'hidden contents. If there is no food, return an empty list.';

  static const Map<String, dynamic> recipeSchema = {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'emoji': {'type': 'string'},
      'summary': {'type': 'string'},
      'minutes': {'type': 'integer'},
      'servings': {'type': 'integer'},
      'difficulty': {'type': 'string'},
      'ingredients': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'amount': {'type': 'string'},
            'fromPantry': {'type': 'boolean'},
          },
          'required': ['name', 'amount', 'fromPantry'],
          'additionalProperties': false,
        },
      },
      'steps': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'detail': {'type': 'string'},
            'minutes': {'type': 'integer'},
          },
          'required': ['title', 'detail', 'minutes'],
          'additionalProperties': false,
        },
      },
      'tips': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'calories': {'type': 'number'},
      'protein': {'type': 'number'},
      'carbs': {'type': 'number'},
      'fat': {'type': 'number'},
      'gramsPerServing': {'type': 'number'},
    },
    'required': [
      'title', 'emoji', 'summary', 'minutes', 'servings', 'difficulty', 'ingredients', 'steps', 'tips', //
      'calories', 'protein', 'carbs', 'fat', 'gramsPerServing',
    ],
    'additionalProperties': false,
  };

  static const Map<String, dynamic> pantrySchema = {
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'emoji': {'type': 'string'},
          },
          'required': ['name', 'emoji'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['items'],
    'additionalProperties': false,
  };

  static String recipeUserMessage(RecipeRequest r) {
    final b = StringBuffer()
      ..writeln('My ingredients: ${r.pantry.join(', ')}.')
      ..writeln(
        r.basics ? 'Basics available: salt, cooking oil/ghee, common dry spices.' : 'Basics: only salt and water.',
      )
      ..writeln('Servings: ${r.servings}. Time limit: ${r.maxMinutes} minutes total.');
    if (r.meal != null) b.writeln('Meal: ${r.meal}.');
    if (r.kcalPerServing != null) b.writeln('Calorie budget per serving: about ${r.kcalPerServing} kcal.');
    if (r.proteinLeft != null && r.proteinLeft! > 0) b.writeln('I still need about ${r.proteinLeft} g protein today.');
    if (r.note.trim().isNotEmpty) b.writeln('Request: ${r.note.trim()}');
    if (r.avoid.isNotEmpty) b.writeln('Suggest something different from: ${r.avoid.join(', ')}.');
    if (r.fix.isNotEmpty) b.writeln(r.fix);
    return b.toString();
  }

  static Object? _decode(String content) {
    var text = content.trim().replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '').replaceAll('```', '').trim();
    try {
      return jsonDecode(text);
    } catch (_) {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(text.substring(start, end + 1));
        } catch (_) {}
      }
      throw const AiException('Could not read Mochi\'s recipe. Please try again.');
    }
  }

  static double _num(Object? v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? fallback;
    return fallback;
  }

  static Recipe parseRecipe(String content) {
    final d = _decode(content);
    if (d is! Map) throw const AiException('Mochi couldn\'t come up with a recipe. Try adding a few more ingredients.');
    final j = Map<String, dynamic>.from(d);
    final steps = [
      for (final s in (j['steps'] as List? ?? const []))
        if (s is Map) RecipeStep.fromJson(Map<String, dynamic>.from(s)),
    ];
    if (steps.isEmpty) {
      throw const AiException('Mochi couldn\'t come up with a recipe. Try adding a few more ingredients.');
    }
    var macros = Macros(
      kcal: _num(j['calories'], 0),
      protein: _num(j['protein'], 0),
      carbs: _num(j['carbs'], 0),
      fat: _num(j['fat'], 0),
    );
    if (macros.kcal <= 0) {
      macros = Macros(kcal: macros.kcalFromMacros, protein: macros.protein, carbs: macros.carbs, fat: macros.fat);
    }
    final now = DateTime.now();
    return Recipe(
      id: 'r${now.microsecondsSinceEpoch}',
      title: (j['title'] ?? 'Mochi\'s special').toString(),
      emoji: (j['emoji'] as String?)?.trim().isNotEmpty == true ? j['emoji'] as String : '🍳',
      summary: (j['summary'] ?? '').toString(),
      minutes: math.max(1, _num(j['minutes'], 20).round()),
      servings: math.max(1, _num(j['servings'], 1).round()),
      difficulty: (j['difficulty'] ?? 'Easy').toString(),
      ingredients: [
        for (final i in (j['ingredients'] as List? ?? const []))
          if (i is Map) RecipeIngredient.fromJson(Map<String, dynamic>.from(i)),
      ],
      steps: steps,
      tips: [for (final t in (j['tips'] as List? ?? const [])) t.toString()],
      perServing: macros,
      gramsPerServing: math.max(50, _num(j['gramsPerServing'], 300)),
      createdAt: now,
    );
  }

  static List<(String, String)> parsePantry(String content) {
    final d = _decode(content);
    final raw = switch (d) {
      {'items': final List<dynamic> items} => items,
      final List<dynamic> items => items,
      _ => const <dynamic>[],
    };
    return [
      for (final i in raw)
        if (i is Map && (i['name']?.toString().trim().isNotEmpty ?? false))
          (
            i['name'].toString().trim(),
            (i['emoji'] as String?)?.trim().isNotEmpty == true ? i['emoji'] as String : '🥫',
          ),
    ];
  }
}
