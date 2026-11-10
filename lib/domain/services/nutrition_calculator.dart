import 'dart:math' as math;

import '../entities/user_profile.dart';

/// Energy & macro target maths.
///
/// BMR: Mifflin-St Jeor
///   men:   10·kg + 6.25·cm − 5·age + 5
///   women: 10·kg + 6.25·cm − 5·age − 161
/// TDEE = BMR × activity multiplier.
/// Goal adjustment: ±(pace kg/week × 7700 kcal/kg ÷ 7) per day.
abstract final class NutritionCalculator {
  static const kcalPerKg = 7700.0;

  static double bmr({required Sex sex, required double weightKg, required double heightCm, required int age}) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  static double tdee({
    required Sex sex,
    required double weightKg,
    required double heightCm,
    required int age,
    required ActivityLevel activity,
  }) => bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age) * activity.multiplier;

  static NutritionTargets compute({
    required Goal goal,
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required double paceKgPerWeek,
  }) {
    final maintenance = tdee(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age, activity: activity);
    final dailyDelta = paceKgPerWeek * kcalPerKg / 7;

    double calories = switch (goal) {
      Goal.lose => maintenance - dailyDelta,
      Goal.maintain => maintenance,
      Goal.gain => maintenance + dailyDelta,
    };

    // Safety floor: never recommend below a minimum intake.
    final floor = sex == Sex.male ? 1500.0 : 1200.0;
    calories = math.max(calories, floor);
    final kcal = (calories / 10).round() * 10;

    // Protein scales with bodyweight; higher when cutting to preserve muscle.
    final proteinPerKg = switch (goal) {
      Goal.lose => 2.0,
      Goal.maintain => 1.6,
      Goal.gain => 1.8,
    };
    final protein = math.min(weightKg * proteinPerKg, kcal * 0.35 / 4);
    final fat = kcal * 0.27 / 9;
    final carbs = math.max((kcal - protein * 4 - fat * 9) / 4, 50.0);

    return NutritionTargets(calories: kcal, protein: protein.round(), carbs: carbs.round(), fat: fat.round());
  }

  static NutritionTargets forProfile(UserProfile p) => compute(
    goal: p.goal,
    sex: p.sex,
    age: p.age,
    heightCm: p.heightCm,
    weightKg: p.weightKg,
    activity: p.activity,
    paceKgPerWeek: p.paceKgPerWeek,
  );

  /// Weeks to reach target weight at the chosen pace (null for maintain).
  static int? weeksToGoal({
    required Goal goal,
    required double weightKg,
    required double targetWeightKg,
    required double paceKgPerWeek,
  }) {
    if (goal == Goal.maintain || paceKgPerWeek <= 0) return null;
    final diff = (targetWeightKg - weightKg).abs();
    if (diff < 0.1) return 0;
    return (diff / paceKgPerWeek).ceil();
  }

  /// Calories from macro grams.
  static int kcalFromMacros(int protein, int carbs, int fat) => protein * 4 + carbs * 4 + fat * 9;
}
