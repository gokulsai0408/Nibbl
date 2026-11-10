import 'package:flutter/material.dart';

import 'food.dart';
import 'macros.dart';

enum MealType {
  breakfast('Breakfast', '🍳', Icons.wb_twilight_rounded),
  lunch('Lunch', '🥗', Icons.wb_sunny_rounded),
  dinner('Dinner', '🍝', Icons.nights_stay_rounded),
  snack('Snacks', '🍎', Icons.cookie_rounded);

  const MealType(this.label, this.emoji, this.icon);
  final String label;
  final String emoji;
  final IconData icon;

  /// Best guess for the meal being eaten at [time].
  static MealType forTime(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes < 10 * 60 + 30) return MealType.breakfast;
    if (minutes < 15 * 60) return MealType.lunch;
    if (minutes < 17 * 60 + 30) return MealType.snack;
    if (minutes < 21 * 60 + 30) return MealType.dinner;
    return MealType.snack;
  }

  static MealType? tryParse(String? name) {
    if (name == null) return null;
    for (final m in MealType.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

enum LogSource { photo, text, voice, barcode, search, template, manual }

/// A food as eaten: a base serving plus a portion [multiplier].
/// Used both for AI results (editable before saving) and saved log entries.
class LoggedFood {
  const LoggedFood({
    required this.name,
    required this.emoji,
    required this.servingLabel,
    required this.servingGrams,
    required this.base,
    this.multiplier = 1,
    this.confidence,
    this.foodId,
  });

  final String name;
  final String emoji;
  final String servingLabel;
  final double servingGrams;

  /// Macros for one base serving.
  final Macros base;
  final double multiplier;

  /// AI confidence 0..1 (null for database foods).
  final double? confidence;

  /// Link back to a [Food] in the database, if any.
  final String? foodId;

  Macros get macros => base.scale(multiplier);
  double get grams => servingGrams * multiplier;

  factory LoggedFood.fromFood(Food food, {double multiplier = 1}) => LoggedFood(
    name: food.name,
    emoji: food.emoji,
    servingLabel: food.servingLabel,
    servingGrams: food.servingGrams,
    base: food.macros,
    multiplier: multiplier,
    foodId: food.id,
  );

  LoggedFood copyWith({
    String? name,
    String? emoji,
    String? servingLabel,
    double? servingGrams,
    Macros? base,
    double? multiplier,
    double? confidence,
    String? foodId,
  }) => LoggedFood(
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    servingLabel: servingLabel ?? this.servingLabel,
    servingGrams: servingGrams ?? this.servingGrams,
    base: base ?? this.base,
    multiplier: multiplier ?? this.multiplier,
    confidence: confidence ?? this.confidence,
    foodId: foodId ?? this.foodId,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'servingLabel': servingLabel,
    'servingGrams': servingGrams,
    'base': base.toJson(),
    'multiplier': multiplier,
    'confidence': confidence,
    'foodId': foodId,
  };

  factory LoggedFood.fromJson(Map<String, dynamic> j) => LoggedFood(
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '🍽️',
    servingLabel: j['servingLabel'] as String? ?? '1 serving',
    servingGrams: (j['servingGrams'] as num? ?? 100).toDouble(),
    base: Macros.fromJson(Map<String, dynamic>.from(j['base'] as Map)),
    multiplier: (j['multiplier'] as num? ?? 1).toDouble(),
    confidence: (j['confidence'] as num?)?.toDouble(),
    foodId: j['foodId'] as String?,
  );
}

/// A saved diary entry.
class FoodLog {
  const FoodLog({
    required this.id,
    required this.dayKey,
    required this.meal,
    required this.food,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String dayKey;
  final MealType meal;
  final LoggedFood food;
  final LogSource source;
  final DateTime createdAt;

  FoodLog copyWith({MealType? meal, LoggedFood? food}) => FoodLog(
    id: id,
    dayKey: dayKey,
    meal: meal ?? this.meal,
    food: food ?? this.food,
    source: source,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dayKey': dayKey,
    'meal': meal.name,
    'food': food.toJson(),
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FoodLog.fromJson(Map<String, dynamic> j) => FoodLog(
    id: j['id'] as String,
    dayKey: j['dayKey'] as String,
    meal: MealType.tryParse(j['meal'] as String?) ?? MealType.snack,
    food: LoggedFood.fromJson(Map<String, dynamic>.from(j['food'] as Map)),
    source: LogSource.values.asNameMap()[j['source']] ?? LogSource.manual,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
