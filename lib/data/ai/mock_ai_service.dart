import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/ai/ai_service.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/kitchen.dart';
import '../../domain/entities/macros.dart';
import '../../domain/entities/tracking.dart';
import '../seed/food_seed.dart';
import 'drink_prompt.dart';

/// Offline AI that returns realistic data, so the whole app works without a key.
class MockAiService implements AiService {
  MockAiService({math.Random? random}) : _rng = random ?? math.Random();
  final math.Random _rng;

  @override
  String get displayName => 'Demo AI (offline)';

  Food _food(String id) => builtInFoods.firstWhere((f) => f.id == id);

  LoggedFood _item(String id, double mult, double confidence) =>
      LoggedFood.fromFood(_food(id), multiplier: mult).copyWith(confidence: confidence);

  Future<void> _think([int baseMs = 1400]) => Future<void>.delayed(Duration(milliseconds: baseMs + _rng.nextInt(900)));

  // ---------------------------------------------------------------- Photo

  static const _photoMeals = <List<(String, double)>>[
    [('chicken_breast', 1), ('brown_rice', 1), ('broccoli', 1), ('avocado', 0.5)],
    [('scrambled_eggs', 1), ('toast_wholegrain', 2), ('avocado', 0.5), ('coffee_black', 1)],
    [('spaghetti_bolognese', 1), ('side_salad', 1), ('wine', 1)],
    [('salmon', 1), ('sweet_potato', 1), ('broccoli', 1), ('olive_oil', 0.5)],
    [('burger', 1), ('fries', 1), ('soda', 1)],
    [('poke_bowl', 1), ('orange_juice', 0.5)],
    [('greek_yogurt', 1), ('granola', 1), ('berries', 1)],
    [('sushi', 1), ('side_salad', 1)],
  ];

  @override
  Future<List<LoggedFood>> analyzePhotos(List<Uint8List> photos, {String? hint, List<String> tags = const []}) async {
    await _think(2200 + 400 * (photos.length - 1));
    if (hint != null && hint.trim().isNotEmpty) {
      // When the user describes the photo, honour their description.
      return _parse(hint);
    }
    final meal = _photoMeals[photos.first.length % _photoMeals.length];
    return [for (final (id, mult) in meal) _item(id, mult, 0.72 + _rng.nextDouble() * 0.25)];
  }

  // ----------------------------------------------------------------- Text

  @override
  Future<List<LoggedFood>> parseText(String description) async {
    await _think();
    return _parse(description);
  }

  static final _splitter = RegExp(r',|;|\+|\n|\band\b|\bwith\b|\bplus\b|&', caseSensitive: false);
  static const _wordNumbers = {
    'a': 1.0,
    'an': 1.0,
    'one': 1.0,
    'two': 2.0,
    'three': 3.0,
    'four': 4.0,
    'five': 5.0,
    'six': 6.0,
    'half': 0.5,
    'couple': 2.0,
    'few': 3.0,
    'some': 1.0,
    'double': 2.0,
  };
  static const _fillers = {
    'of',
    'cup',
    'cups',
    'slice',
    'slices',
    'piece',
    'pieces',
    'bowl',
    'bowls',
    'glass',
    'glasses',
    'plate',
    'plates',
    'serving',
    'servings',
    'small',
    'medium',
    'large',
    'big',
    'little',
    'had',
    'ate',
    'i',
    'my',
    'the',
    'some',
    'g',
    'grams',
    'gram',
    'ml',
    'tbsp',
    'tsp',
    'handful',
    'bit',
    'portion',
  };
  static const _aliases = {
    'eggs': 'egg',
    'toast': 'toast_white',
    'coffee': 'coffee_black',
    'oats': 'oatmeal',
    'porridge': 'oatmeal',
    'yogurt': 'greek_yogurt',
    'yoghurt': 'greek_yogurt',
    'rice': 'white_rice',
    'chicken': 'chicken_breast',
    'salmon': 'salmon',
    'fish': 'salmon',
    'beef': 'ground_beef',
    'steak': 'steak',
    'pizza': 'pizza_slice',
    'burger': 'burger',
    'fries': 'fries',
    'chips': 'chips',
    'salad': 'side_salad',
    'milk': 'milk_splash',
    'latte': 'latte',
    'cappuccino': 'latte',
    'juice': 'orange_juice',
    'shake': 'protein_shake',
    'nuts': 'almonds',
    'chocolate': 'dark_chocolate',
    'spaghetti': 'spaghetti_bolognese',
    'noodles': 'ramen',
    'cola': 'soda',
    'coke': 'soda',
    'pancake': 'pancakes',
    'berries': 'berries',
    'blueberries': 'berries',
    'potato': 'sweet_potato',
    'bread': 'toast_wholegrain',
    'sandwich': 'sandwich',
    'wrap': 'burrito',
  };

  List<LoggedFood> _parse(String text) {
    final parts = text.split(_splitter).map((s) => s.trim()).where((s) => s.isNotEmpty);
    final out = <LoggedFood>[];
    for (final part in parts) {
      final (qty, words) = _quantityAndWords(part.toLowerCase());
      if (words.isEmpty) continue;
      final match = _bestMatch(words);
      if (match != null) {
        out.add(LoggedFood.fromFood(match, multiplier: qty).copyWith(confidence: 0.8 + _rng.nextDouble() * 0.15));
      } else {
        final name = words.join(' ');
        out.add(
          LoggedFood(
            name: name[0].toUpperCase() + name.substring(1),
            emoji: '🍽️',
            servingLabel: '1 serving',
            servingGrams: 150,
            base: const Macros(kcal: 180, protein: 7, carbs: 20, fat: 7),
            multiplier: qty,
            confidence: 0.45,
          ),
        );
      }
    }
    if (out.isEmpty) throw const AiException('I couldn\'t find any foods in that. Try "2 eggs and toast".');
    return out;
  }

  (double, List<String>) _quantityAndWords(String part) {
    var qty = 1.0;
    final tokens = part.replaceAll(RegExp(r'[^a-z0-9.½¼¾ ]'), ' ').split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final words = <String>[];
    var qtySet = false;
    for (final t in tokens) {
      final n =
          double.tryParse(t) ??
          switch (t) {
            '½' => 0.5,
            '¼' => 0.25,
            '¾' => 0.75,
            _ => null,
          };
      if (!qtySet && n != null) {
        // Treat big numbers as grams relative to a ~100 g serving.
        qty = n > 20 ? (n / 100).clamp(0.25, 10).toDouble() : n;
        qtySet = true;
        continue;
      }
      if (!qtySet && _wordNumbers.containsKey(t)) {
        qty = _wordNumbers[t]!;
        qtySet = true;
        continue;
      }
      if (_fillers.contains(t)) continue;
      words.add(t);
    }
    return (qty, words);
  }

  Food? _bestMatch(List<String> words) {
    String singular(String w) => w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;
    Food? best;
    var bestScore = 0.0;
    for (final food in builtInFoods) {
      final nameWords = food.name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z ]'), ' ')
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map(singular)
          .toSet();
      var score = 0.0;
      for (final w in words) {
        if (nameWords.contains(singular(w))) score += 1;
        if (_aliases[w] == food.id) score += 1.5;
      }
      // Prefer shorter names on ties (more generic match).
      score -= nameWords.length * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = food;
      }
    }
    return bestScore >= 0.9 ? best : null;
  }

  // ---------------------------------------------------------------- Coach

  // -------------------------------------------------------------- Kitchen

  @override
  Future<List<(String, String)>> scanPantry(Uint8List jpegBytes) async {
    await _think(1800);
    const sets = [
      [('Eggs', '🥚'), ('Tomatoes', '🍅'), ('Onions', '🧅'), ('Milk', '🥛'), ('Spinach', '🥬')],
      [('Paneer', '🧀'), ('Capsicum', '🫑'), ('Curd', '🥣'), ('Green chillies', '🌶️'), ('Lemon', '🍋')],
      [('Potatoes', '🥔'), ('Carrots', '🥕'), ('Bread', '🍞'), ('Butter', '🧈'), ('Cheese', '🧀')],
    ];
    return sets[jpegBytes.length % sets.length];
  }

  @override
  Future<(Food, bool)> identifyProduct({
    required String barcode,
    List<Uint8List> photos = const [],
    String? name,
    String? brand,
  }) async {
    await _think(1500);
    final fromLabel = photos.isNotEmpty;
    return (
      Food(
        id: 'off_$barcode',
        name: name ?? (fromLabel ? 'Masala peanuts' : 'Packaged snack'),
        brand: brand,
        emoji: '🥜',
        servingLabel: '1 pack (30 g)',
        servingGrams: 30,
        macros: const Macros(kcal: 165, protein: 6, carbs: 9, fat: 12),
        barcode: barcode,
        isCustom: true,
      ),
      fromLabel,
    );
  }

  @override
  Future<DrinkEstimate> estimateDrink(Uint8List jpegBytes, {String? hint}) async {
    await _think(1200);
    const options = [
      DrinkEstimate(
        name: 'Glass of water',
        emoji: '🥛',
        ml: 250,
        hydrationMl: 250,
        note: 'Standard tumbler, mostly full',
      ),
      DrinkEstimate(
        name: 'Water bottle',
        emoji: '💧',
        ml: 750,
        hydrationMl: 750,
        containerMl: 1000,
        note: '1 L bottle, three-quarters full',
      ),
      DrinkEstimate(
        name: 'Masala chai',
        emoji: '☕',
        ml: 150,
        hydrationMl: 150,
        macros: Macros(kcal: 90, protein: 3, carbs: 13, fat: 3),
        note: 'Tea cup with milk and sugar',
      ),
    ];
    return options[jpegBytes.length % options.length];
  }

  @override
  Future<Recipe> suggestRecipe(RecipeRequest request) async {
    await _think(1600);
    final have = request.pantry.map((e) => e.toLowerCase()).toList();
    bool has(String k) => have.any((h) => h.contains(k)) || (request.basics && (k == 'oil' || k == 'ghee'));
    final n = request.servings;
    String amt(num perServing, String unit) {
      final v = perServing * n;
      return '${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(1)} $unit';
    }

    final options = <Recipe Function()>[
      if (has('egg'))
        () => _recipe(
          request,
          title: 'Masala omelette',
          emoji: '🍳',
          summary: 'A fluffy, spiced Indian-style omelette ready in minutes.',
          minutes: 12,
          ingredients: [
            RecipeIngredient(name: 'Eggs', amount: amt(2, 'large')),
            if (has('onion')) RecipeIngredient(name: 'Onion, finely chopped', amount: amt(0.25, 'cup')),
            if (has('tomato')) RecipeIngredient(name: 'Tomato, chopped', amount: amt(0.25, 'cup')),
            if (has('chilli')) RecipeIngredient(name: 'Green chilli, minced', amount: amt(1, 'small')),
            RecipeIngredient(name: 'Oil or butter', amount: amt(1, 'tsp'), fromPantry: has('oil') || has('butter')),
            const RecipeIngredient(name: 'Salt & pepper', amount: 'to taste', fromPantry: false),
          ],
          steps: const [
            RecipeStep(
              title: 'Prep',
              detail: 'Finely chop the vegetables so they cook quickly and evenly.',
              minutes: 4,
            ),
            RecipeStep(
              title: 'Whisk',
              detail:
                  'Crack the eggs into a bowl, add salt, pepper and the chopped vegetables. '
                  'Whisk for 30 seconds until slightly frothy.',
              minutes: 1,
            ),
            RecipeStep(
              title: 'Heat the pan',
              detail: 'Warm the oil in a non-stick pan on medium heat until it shimmers (about 1 minute).',
              minutes: 1,
            ),
            RecipeStep(
              title: 'Cook',
              detail:
                  'Pour in the eggs and tilt the pan to spread. Cook undisturbed for 2 minutes until '
                  'the edges set and the bottom is golden.',
              minutes: 3,
            ),
            RecipeStep(
              title: 'Flip & serve',
              detail: 'Flip with a wide spatula, cook 1 more minute, then fold and serve hot.',
              minutes: 1,
            ),
          ],
          tips: const ['Add a spoon of milk for an extra-fluffy omelette.', 'Roll it in a roti for a quick egg wrap.'],
          macros: const Macros(kcal: 230, protein: 14, carbs: 5, fat: 17),
          grams: 160,
        ),
      if (has('paneer'))
        () => _recipe(
          request,
          title: 'Paneer bhurji',
          emoji: '🧀',
          summary: 'Scrambled paneer with onion and tomato: high protein, very quick.',
          minutes: 15,
          ingredients: [
            RecipeIngredient(name: 'Paneer, crumbled', amount: amt(100, 'g')),
            if (has('onion')) RecipeIngredient(name: 'Onion, chopped', amount: amt(0.5, 'medium')),
            if (has('tomato')) RecipeIngredient(name: 'Tomato, chopped', amount: amt(0.5, 'medium')),
            RecipeIngredient(name: 'Oil', amount: amt(1, 'tsp'), fromPantry: has('oil')),
            const RecipeIngredient(name: 'Salt, turmeric, chilli powder', amount: 'a pinch each', fromPantry: false),
          ],
          steps: const [
            RecipeStep(
              title: 'Sauté onions',
              detail: 'Heat oil on medium. Add onions and cook 3 minutes until soft and translucent.',
              minutes: 3,
            ),
            RecipeStep(
              title: 'Add tomato & spices',
              detail:
                  'Add tomatoes, salt, turmeric and chilli. Cook 3-4 minutes until the tomatoes break down '
                  'and oil separates at the edges.',
              minutes: 4,
            ),
            RecipeStep(
              title: 'Add paneer',
              detail:
                  'Stir in the crumbled paneer and cook 2 minutes on low heat. Do not overcook or it turns rubbery.',
              minutes: 2,
            ),
            RecipeStep(title: 'Finish', detail: 'Taste, adjust salt, and serve with roti or toast.', minutes: 1),
          ],
          tips: const ['Use low-fat paneer to save about 80 kcal.', 'A squeeze of lemon at the end brightens it up.'],
          macros: const Macros(kcal: 330, protein: 19, carbs: 9, fat: 24),
          grams: 200,
        ),
      if (has('rice') && (has('dal') || has('lentil')))
        () => _recipe(
          request,
          title: 'Simple moong dal khichdi',
          emoji: '🍲',
          summary: 'Comforting one-pot rice and lentils, gentle and filling.',
          minutes: 25,
          ingredients: [
            RecipeIngredient(name: 'Rice', amount: amt(0.25, 'cup')),
            RecipeIngredient(name: 'Dal', amount: amt(0.25, 'cup')),
            RecipeIngredient(name: 'Ghee or oil', amount: amt(1, 'tsp'), fromPantry: has('ghee') || has('oil')),
            const RecipeIngredient(name: 'Salt, turmeric, water', amount: 'as needed', fromPantry: false),
          ],
          steps: const [
            RecipeStep(
              title: 'Rinse',
              detail: 'Rinse rice and dal together 2-3 times until the water runs mostly clear.',
              minutes: 2,
            ),
            RecipeStep(
              title: 'Pressure cook',
              detail:
                  'Add 3 cups water per cup of rice and dal, plus salt and turmeric. Pressure cook for 3 whistles on medium heat.',
              minutes: 15,
            ),
            RecipeStep(
              title: 'Rest',
              detail: 'Let the pressure release naturally, then mash lightly with the back of a ladle.',
              minutes: 5,
            ),
            RecipeStep(
              title: 'Temper & serve',
              detail: 'Warm the ghee, pour it over the khichdi and serve with curd or pickle.',
              minutes: 2,
            ),
          ],
          tips: const [
            'Add any vegetables you have for extra fibre.',
            'Thin it with hot water if it thickens on standing.',
          ],
          macros: const Macros(kcal: 300, protein: 11, carbs: 52, fat: 5),
          grams: 320,
        ),
      if (has('potato'))
        () => _recipe(
          request,
          title: 'Jeera aloo',
          emoji: '🥔',
          summary: 'Cumin-tossed potatoes: crispy edges, soft inside.',
          minutes: 25,
          ingredients: [
            RecipeIngredient(name: 'Potatoes, cubed', amount: amt(1.5, 'medium')),
            RecipeIngredient(name: 'Oil', amount: amt(1, 'tsp'), fromPantry: has('oil')),
            const RecipeIngredient(name: 'Cumin, salt, chilli powder', amount: 'to taste', fromPantry: false),
          ],
          steps: const [
            RecipeStep(
              title: 'Boil',
              detail:
                  'Boil the cubes in salted water for 8 minutes until a knife slides in with slight resistance. Drain well.',
              minutes: 10,
            ),
            RecipeStep(
              title: 'Temper',
              detail: 'Heat oil on medium, add cumin and let it sizzle for 20 seconds until fragrant.',
              minutes: 1,
            ),
            RecipeStep(
              title: 'Crisp',
              detail:
                  'Add potatoes and spices. Toss and cook 6-8 minutes, turning occasionally, until golden at the edges.',
              minutes: 8,
            ),
          ],
          tips: const ['Microwave the cubes 5 minutes instead of boiling to save time.'],
          macros: const Macros(kcal: 210, protein: 4, carbs: 36, fat: 6),
          grams: 220,
        ),
    ];
    // Fallback: a quick stir-fry with whatever is there.
    options.add(
      () => _recipe(
        request,
        title: 'Quick kitchen stir-fry',
        emoji: '🥘',
        summary: 'A fast, flexible pan-fry using what you have.',
        minutes: 15,
        ingredients: [
          for (final p in request.pantry.take(5))
            RecipeIngredient(name: p.replaceAll(RegExp(r' \(.*\)$'), ''), amount: amt(60, 'g')),
          RecipeIngredient(name: 'Oil', amount: amt(1, 'tsp'), fromPantry: has('oil')),
          const RecipeIngredient(name: 'Salt & pepper', amount: 'to taste', fromPantry: false),
        ],
        steps: const [
          RecipeStep(
            title: 'Prep',
            detail: 'Cut everything into similar bite-sized pieces so it cooks evenly.',
            minutes: 5,
          ),
          RecipeStep(
            title: 'Hard veg first',
            detail: 'Heat oil on high. Add the firmest ingredients first and stir-fry 3-4 minutes.',
            minutes: 4,
          ),
          RecipeStep(
            title: 'Everything else',
            detail: 'Add softer ingredients, season, and toss 2-3 minutes until just tender.',
            minutes: 3,
          ),
        ],
        tips: const ['Finish with lemon or a splash of soy sauce if you have it.'],
        macros: const Macros(kcal: 250, protein: 10, carbs: 25, fat: 11),
        grams: 250,
      ),
    );

    final avoid = request.avoid.map((a) => a.toLowerCase()).toSet();
    final fresh = [for (final o in options) o()].where((r) => !avoid.contains(r.title.toLowerCase())).toList();
    if (fresh.isEmpty) return options.last();
    return fresh[_rng.nextInt(fresh.length)];
  }

  Recipe _recipe(
    RecipeRequest r, {
    required String title,
    required String emoji,
    required String summary,
    required int minutes,
    required List<RecipeIngredient> ingredients,
    required List<RecipeStep> steps,
    required List<String> tips,
    required Macros macros,
    required double grams,
  }) => Recipe(
    id: 'r${DateTime.now().microsecondsSinceEpoch}',
    title: title,
    emoji: emoji,
    summary: summary,
    minutes: minutes,
    servings: r.servings,
    difficulty: 'Easy',
    ingredients: ingredients,
    steps: steps,
    tips: tips,
    perServing: macros,
    gramsPerServing: grams,
    createdAt: DateTime.now(),
  );

  @override
  Future<String> coachReply({required List<ChatMessage> history, required String context}) async {
    await _think(900);
    final q = history.lastWhere((m) => m.role == ChatRole.user, orElse: () => history.last).text.toLowerCase();
    int? read(String label) {
      final m = RegExp('$label: (-?\\d+)').firstMatch(context);
      return m == null ? null : int.tryParse(m.group(1)!);
    }

    final kcalLeft = read('Calories remaining today') ?? 600;
    final proteinLeft = math.max(read('Protein remaining today') ?? 40, 0);
    final waterMl = read('Water today') ?? 0;
    final avgKcal = read('7-day average calories');
    final goalKcal = read('Daily calorie target') ?? 2000;

    if (q.contains('water') || q.contains('hydrat')) {
      return 'You\'re at ${(waterMl / 1000).toStringAsFixed(1)} L. Drink a full glass now and one with each meal. That closes the gap easily.';
    }

    if (q.contains('snack')) {
      return proteinLeft > 20
          ? 'Go protein-first:\n• Greek yogurt + berries (200 kcal, 21g)\n• Protein shake (120 kcal, 24g)'
          : 'Keep it light:\n• Apple + 1 tbsp peanut butter (190 kcal)\n• Carrots + hummus (120 kcal)';
    }

    if (q.contains('protein')) {
      return proteinLeft > 0
          ? '${proteinLeft}g to go. Easiest wins:\n• 150g chicken (46g)\n• 1 can tuna (29g)\n• 1 cup Greek yogurt (20g)'
          : 'Protein target hit. Nice work. Keep the rest of today veg-heavy.';
    }

    if (q.contains('week') || q.contains('progress') || q.contains('how am i') || q.contains('doing')) {
      if (avgKcal == null || avgKcal == 0) {
        return 'Not enough data yet. Log every meal for 3 days and I\'ll give you a real read.';
      }
      final diff = avgKcal - goalKcal;
      if (diff.abs() <= goalKcal * 0.07) {
        return 'Averaging $avgKcal kcal: right on target. Keep protein steady and stay consistent on weekends.';
      }
      return diff > 0
          ? 'Averaging $diff kcal over target. Trim one snack or drink a day and you\'re back on track.'
          : 'Averaging ${diff.abs()} kcal under target. Add a protein-rich snack so you don\'t lose muscle.';
    }

    if (kcalLeft <= 0) {
      return 'You\'re at your limit today. If you\'re hungry, go for veg, broth or tea. Fresh start tomorrow.';
    }
    final pick = kcalLeft >= 550
        ? 'Salmon, sweet potato and broccoli (~500 kcal, 37g protein)'
        : kcalLeft >= 350
        ? 'Chicken breast with a big salad (~400 kcal, 48g protein)'
        : 'Tuna on crispbread with cucumber (~250 kcal, 30g protein)';
    return '$kcalLeft kcal and ${proteinLeft}g protein left. Go with: $pick.';
  }
}
