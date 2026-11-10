import 'macros.dart';

/// A food in the local database (built-in, custom, or cached from a barcode).
/// [macros] are per one [servingLabel] serving.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.emoji,
    required this.servingLabel,
    required this.servingGrams,
    required this.macros,
    this.brand,
    this.barcode,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String servingLabel;
  final double servingGrams;
  final Macros macros;
  final String? brand;
  final String? barcode;
  final bool isCustom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'servingLabel': servingLabel,
    'servingGrams': servingGrams,
    'macros': macros.toJson(),
    'brand': brand,
    'barcode': barcode,
    'isCustom': isCustom,
  };

  factory Food.fromJson(Map<String, dynamic> j) => Food(
    id: j['id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String? ?? '🍽️',
    servingLabel: j['servingLabel'] as String? ?? '1 serving',
    servingGrams: (j['servingGrams'] as num? ?? 100).toDouble(),
    macros: Macros.fromJson(Map<String, dynamic>.from(j['macros'] as Map)),
    brand: j['brand'] as String?,
    barcode: j['barcode'] as String?,
    isCustom: j['isCustom'] as bool? ?? false,
  );
}
