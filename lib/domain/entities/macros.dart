import 'package:flutter/foundation.dart';

/// Immutable nutrition value object (kcal + grams of macros).
@immutable
class Macros {
  const Macros({this.kcal = 0, this.protein = 0, this.carbs = 0, this.fat = 0});

  static const zero = Macros();

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  Macros operator +(Macros o) =>
      Macros(kcal: kcal + o.kcal, protein: protein + o.protein, carbs: carbs + o.carbs, fat: fat + o.fat);

  Macros scale(double f) => Macros(kcal: kcal * f, protein: protein * f, carbs: carbs * f, fat: fat * f);

  /// Calories implied by the macro grams (4/4/9 rule).
  double get kcalFromMacros => protein * 4 + carbs * 4 + fat * 9;

  static Macros sum(Iterable<Macros> items) => items.fold(Macros.zero, (a, b) => a + b);

  Map<String, dynamic> toJson() => {'kcal': kcal, 'protein': protein, 'carbs': carbs, 'fat': fat};

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
    kcal: (json['kcal'] as num? ?? 0).toDouble(),
    protein: (json['protein'] as num? ?? 0).toDouble(),
    carbs: (json['carbs'] as num? ?? 0).toDouble(),
    fat: (json['fat'] as num? ?? 0).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is Macros && other.kcal == kcal && other.protein == protein && other.carbs == carbs && other.fat == fat;

  @override
  int get hashCode => Object.hash(kcal, protein, carbs, fat);
}
