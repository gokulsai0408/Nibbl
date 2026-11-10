enum Goal {
  lose('Lose weight', '🔥', 'Trim down at a sustainable pace'),
  maintain('Maintain', '⚖️', 'Keep your weight steady and eat well'),
  gain('Build & gain', '💪', 'Add healthy weight and muscle');

  const Goal(this.label, this.emoji, this.description);
  final String label;
  final String emoji;
  final String description;
}

enum Sex {
  male('Male'),
  female('Female');

  const Sex(this.label);
  final String label;
}

enum ActivityLevel {
  sedentary(1.2, 'Sedentary', 'Desk job, little exercise'),
  light(1.375, 'Lightly active', 'Light exercise 1–3 days/week'),
  moderate(1.55, 'Moderately active', 'Exercise 3–5 days/week'),
  active(1.725, 'Very active', 'Hard exercise 6–7 days/week'),
  athlete(1.9, 'Athlete', 'Physical job or twice-daily training');

  const ActivityLevel(this.multiplier, this.label, this.description);
  final double multiplier;
  final String label;
  final String description;
}

class NutritionTargets {
  const NutritionTargets({required this.calories, required this.protein, required this.carbs, required this.fat});

  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  NutritionTargets copyWith({int? calories, int? protein, int? carbs, int? fat}) => NutritionTargets(
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
  );

  Map<String, dynamic> toJson() => {'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat};

  factory NutritionTargets.fromJson(Map<String, dynamic> j) => NutritionTargets(
    calories: (j['calories'] as num).round(),
    protein: (j['protein'] as num).round(),
    carbs: (j['carbs'] as num).round(),
    fat: (j['fat'] as num).round(),
  );
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.goal,
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    required this.targetWeightKg,
    required this.paceKgPerWeek,
    required this.targets,
    required this.customTargets,
    required this.createdAt,
  });

  final String name;
  final Goal goal;
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;
  final double targetWeightKg;
  final double paceKgPerWeek;
  final NutritionTargets targets;

  /// When true, targets were set manually and are not recalculated.
  final bool customTargets;
  final DateTime createdAt;

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  UserProfile copyWith({
    String? name,
    Goal? goal,
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activity,
    double? targetWeightKg,
    double? paceKgPerWeek,
    NutritionTargets? targets,
    bool? customTargets,
  }) => UserProfile(
    name: name ?? this.name,
    goal: goal ?? this.goal,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    activity: activity ?? this.activity,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
    targets: targets ?? this.targets,
    customTargets: customTargets ?? this.customTargets,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'goal': goal.name,
    'sex': sex.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'activity': activity.name,
    'targetWeightKg': targetWeightKg,
    'paceKgPerWeek': paceKgPerWeek,
    'targets': targets.toJson(),
    'customTargets': customTargets,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String? ?? '',
    goal: Goal.values.byName(j['goal'] as String),
    sex: Sex.values.byName(j['sex'] as String),
    age: (j['age'] as num).round(),
    heightCm: (j['heightCm'] as num).toDouble(),
    weightKg: (j['weightKg'] as num).toDouble(),
    activity: ActivityLevel.values.byName(j['activity'] as String),
    targetWeightKg: (j['targetWeightKg'] as num).toDouble(),
    paceKgPerWeek: (j['paceKgPerWeek'] as num).toDouble(),
    targets: NutritionTargets.fromJson(Map<String, dynamic>.from(j['targets'] as Map)),
    customTargets: j['customTargets'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
