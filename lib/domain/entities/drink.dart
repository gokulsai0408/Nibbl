import 'macros.dart';

/// What the AI sees in a drink photo.
class DrinkEstimate {
  const DrinkEstimate({
    required this.name,
    required this.emoji,
    required this.ml,
    required this.hydrationMl,
    this.containerMl = 0,
    this.macros = Macros.zero,
    this.confidence = 0.7,
    this.note = '',
  });

  final String name;
  final String emoji;

  /// Liquid volume in the container.
  final int ml;

  /// How much counts toward the water goal (e.g. 0 for alcohol).
  final int hydrationMl;

  /// Full size of the container (0 if unknown), used to save it as a bottle.
  final int containerMl;
  final Macros macros;
  final double confidence;
  final String note;

  bool get hasCalories => macros.kcal >= 5;
}


/// A bottle or cup the user saved, so they can log part of it in one tap.
class SavedBottle {
  const SavedBottle({required this.id, required this.name, required this.emoji, required this.ml});
  final String id;
  final String name;
  final String emoji;
  final int ml;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji, 'ml': ml};

  factory SavedBottle.fromJson(Map<String, dynamic> j) => SavedBottle(
        id: j['id'] as String? ?? 'b',
        name: j['name'] as String? ?? 'My bottle',
        emoji: j['emoji'] as String? ?? '🧴',
        ml: (j['ml'] as num? ?? 500).round(),
      );
}
