import 'dart:convert';

import '../../domain/ai/ai_service.dart';
import '../../domain/entities/food_log.dart';
import '../../domain/entities/macros.dart';

/// Turns a model's (possibly messy) JSON response into [LoggedFood] items.
abstract final class AiJsonParser {
  static List<LoggedFood> parseItems(String content) {
    final decoded = _decodeLoosely(content);
    final rawItems = switch (decoded) {
      {'items': final List<dynamic> items} => items,
      {'foods': final List<dynamic> items} => items,
      final List<dynamic> items => items,
      _ => throw const AiException('The AI response did not contain any food items.'),
    };

    final items = <LoggedFood>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final name = (m['name'] ?? m['food'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      var grams = _num(m['grams'] ?? m['weight_g'] ?? m['portion_grams'], 100);
      if (grams <= 0) grams = 100;
      var macros = Macros(
        kcal: _num(m['calories'] ?? m['kcal'], 0),
        protein: _num(m['protein'] ?? m['protein_g'], 0),
        carbs: _num(m['carbs'] ?? m['carbs_g'] ?? m['carbohydrates'], 0),
        fat: _num(m['fat'] ?? m['fat_g'], 0),
      );
      // Missing calories but macros present: derive them (4/4/9).
      if (macros.kcal <= 0 && macros.kcalFromMacros > 0) {
        macros = Macros(kcal: macros.kcalFromMacros, protein: macros.protein, carbs: macros.carbs, fat: macros.fat);
      }
      items.add(
        LoggedFood(
          name: _capitalize(name),
          emoji: (m['emoji'] as String?)?.trim().isNotEmpty == true ? m['emoji'] as String : '🍽️',
          servingLabel: (m['serving'] ?? m['portion'] ?? '${grams.round()} g').toString(),
          servingGrams: grams,
          base: macros,
          confidence: m['confidence'] == null ? null : _num(m['confidence'], 0.7).clamp(0, 1).toDouble(),
        ),
      );
    }
    if (items.isEmpty) throw const AiException('No foods were recognised. Try adding more detail.');
    return items;
  }

  static Object? _decodeLoosely(String content) {
    var text = content.trim();
    // Strip ```json fences if the model added them.
    text = text.replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '').replaceAll('```', '').trim();
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
      throw const AiException('Could not read the AI response. Please try again.');
    }
  }

  static double _num(Object? v, double fallback) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? fallback;
    return fallback;
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
