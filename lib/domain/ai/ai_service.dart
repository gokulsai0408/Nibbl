import 'dart:typed_data';

import '../entities/drink.dart';

import '../entities/food.dart';
import '../entities/food_log.dart';
import '../entities/kitchen.dart';
import '../entities/tracking.dart';

/// Abstraction over the nutrition AI. Swap implementations without touching UI.
abstract interface class AiService {
  /// Human-readable name for settings ("Demo AI", "gpt-4o-mini @ host").
  String get displayName;

  /// Identify foods in one meal shown in [photos] (1-5 angles or dishes of
  /// the same meal) with estimated portions and macros. [tags] are quick
  /// context chips such as "Home-cooked" or "Extra ghee".
  Future<List<LoggedFood>> analyzePhotos(List<Uint8List> photos, {String? hint, List<String> tags = const []});

  /// Parse free text like "2 eggs, toast with butter and a latte".
  Future<List<LoggedFood>> parseText(String description);

  /// Identify a packaged product for [barcode] from label/pack [photos], or
  /// estimate it from [name]/[brand]. Returns the food and whether the
  /// numbers were read from a real nutrition label.
  Future<(Food, bool)> identifyProduct({
    required String barcode,
    List<Uint8List> photos = const [],
    String? name,
    String? brand,
  });

  /// Estimate the drink (and how many ml) in a photo of a glass/bottle/cup.
  Future<DrinkEstimate> estimateDrink(Uint8List jpegBytes, {String? hint});

  /// Suggest one simple dish cookable from the user's kitchen.
  Future<Recipe> suggestRecipe(RecipeRequest request);

  /// Spot ingredients in a fridge/pantry photo. Returns (name, emoji) pairs.
  Future<List<(String, String)>> scanPantry(Uint8List jpegBytes);

  /// Answer a coaching question. [context] summarises the user's data.
  Future<String> coachReply({required List<ChatMessage> history, required String context});
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => message;
}
