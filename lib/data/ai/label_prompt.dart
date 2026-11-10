import 'dart:convert';

import '../../domain/ai/ai_service.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/macros.dart';

/// Reading packaged-food labels (or estimating from the product name) for
/// barcodes the databases don't know.
abstract final class LabelPrompts {
  static const system = '''
You read packaged-food labels for a nutrition app.

If a nutrition table is visible, copy its numbers exactly (do not estimate):
- Use the per-serving column when it exists, with its serving size in grams/ml. Otherwise use per-100 g/ml and set servingGrams to 100.
- Energy in kJ only? Convert: kcal = kJ / 4.184.
- "serving" is a short human label such as "1 packet (30 g)" or "100 g".
- fromLabel = true.

If there is no readable table (front of pack only, or just a product name), estimate from what you know about that exact product or very similar products. fromLabel = false.

Always give: name (product name as printed, without the brand), brand (or empty), emoji (one), serving, servingGrams, calories, protein, carbs, fat.''';

  static const Map<String, dynamic> schema = {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'brand': {'type': 'string'},
      'emoji': {'type': 'string'},
      'serving': {'type': 'string'},
      'servingGrams': {'type': 'number'},
      'calories': {'type': 'number'},
      'protein': {'type': 'number'},
      'carbs': {'type': 'number'},
      'fat': {'type': 'number'},
      'fromLabel': {'type': 'boolean'},
    },
    'required': [
      'name',
      'brand',
      'emoji',
      'serving',
      'servingGrams',
      'calories',
      'protein',
      'carbs',
      'fat',
      'fromLabel',
    ],
    'additionalProperties': false,
  };

  static String userMessage({required int photos, String? name, String? brand}) {
    final b = StringBuffer();
    if (photos > 0) {
      b.write(photos == 1 ? 'Here is the product. ' : 'Here are $photos photos of the same product. ');
      b.write('Read the nutrition label.');
    } else {
      b.write('Estimate nutrition for this packaged product.');
    }
    if (name != null && name.isNotEmpty) b.write(' Product: $name.');
    if (brand != null && brand.isNotEmpty) b.write(' Brand: $brand.');
    return b.toString();
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return 0;
  }

  /// Returns the product and whether the numbers came from a real label.
  static (Food, bool) parse(String content, {required String barcode}) {
    var text = content.trim().replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '').replaceAll('```', '').trim();
    Object? d;
    try {
      d = jsonDecode(text);
    } catch (_) {
      final s = text.indexOf('{');
      final e = text.lastIndexOf('}');
      if (s >= 0 && e > s) {
        try {
          d = jsonDecode(text.substring(s, e + 1));
        } catch (_) {}
      }
    }
    if (d is! Map) throw const AiException("Couldn't read that label. Try a sharper, closer photo.");
    final j = Map<String, dynamic>.from(d);
    var macros = Macros(
      kcal: _num(j['calories']),
      protein: _num(j['protein']),
      carbs: _num(j['carbs']),
      fat: _num(j['fat']),
    );
    if (macros.kcal <= 0 && macros.kcalFromMacros > 0) {
      macros = Macros(kcal: macros.kcalFromMacros, protein: macros.protein, carbs: macros.carbs, fat: macros.fat);
    }
    if (macros.kcal <= 0) throw const AiException("Couldn't find nutrition values. Try a photo of the label.");
    final grams = _num(j['servingGrams']);
    final brand = (j['brand'] as String?)?.trim();
    final name = (j['name'] as String?)?.trim();
    final emoji = (j['emoji'] as String?)?.trim();
    return (
      Food(
        id: 'off_$barcode',
        name: (name == null || name.isEmpty) ? 'Scanned product' : name,
        brand: (brand == null || brand.isEmpty) ? null : brand,
        emoji: (emoji == null || emoji.isEmpty) ? '🛒' : emoji,
        servingLabel: (j['serving'] as String?)?.trim().isNotEmpty == true ? j['serving'] as String : '1 serving',
        servingGrams: grams > 0 ? grams : 100,
        macros: macros,
        barcode: barcode,
        isCustom: true,
      ),
      j['fromLabel'] == true,
    );
  }
}
