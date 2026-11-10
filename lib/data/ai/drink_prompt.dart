import 'dart:convert';

import '../../domain/ai/ai_service.dart';
import '../../domain/entities/drink.dart';
import '../../domain/entities/macros.dart';

export '../../domain/entities/drink.dart';

abstract final class DrinkPrompts {
  static const system = '''
You estimate drinks from photos for a hydration tracker.

Estimate the volume of liquid actually in the container(s), in millilitres:
- Identify the container: glass, steel tumbler, mug, cup, plastic or steel bottle, can, carton, shaker, jug.
- Judge its size from visual cues (hands, table items, labels like "500 ml" or "1 L", standard sizes: tumbler ~250-300 ml, mug ~300-350 ml, tea cup ~150 ml, can 330 ml, small bottle 500 ml, large bottle 1 L).
- Multiply by the fill level you can see (e.g. a 500 ml bottle half full = 250 ml).
- If several drinks are shown, add them up.
- container_ml is the FULL capacity of the main container (e.g. 1000 for a 1 L bottle even if half empty), 0 if unclear.

hydration_ml: water, coconut water, buttermilk, milk, tea, coffee, juice and soft drinks count fully; alcoholic drinks count 0.
Nutrition (calories, protein, carbs, fat) is for the whole amount: plain water, black tea/coffee and soda water are 0. Include sugar and milk when visible or typical (e.g. Indian chai with milk and sugar).
"name" is short, like "Glass of water" or "Masala chai". "note" is at most 8 words about what you assumed.''';

  static const Map<String, dynamic> schema = {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'emoji': {'type': 'string'},
      'ml': {'type': 'number'},
      'hydration_ml': {'type': 'number'},
      'container_ml': {'type': 'number'},
      'calories': {'type': 'number'},
      'protein': {'type': 'number'},
      'carbs': {'type': 'number'},
      'fat': {'type': 'number'},
      'confidence': {'type': 'number'},
      'note': {'type': 'string'},
    },
    'required': ['name', 'emoji', 'ml', 'hydration_ml', 'container_ml', 'calories', 'protein', 'carbs', 'fat', 'confidence', 'note'],
    'additionalProperties': false,
  };

  static String userMessage({String? hint}) =>
      'How much liquid is in this?${hint == null || hint.trim().isEmpty ? '' : ' Extra info: ${hint.trim()}'}';

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    return 0;
  }

  static DrinkEstimate parse(String content) {
    final text = content.trim().replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '').replaceAll('```', '').trim();
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
    if (d is! Map) throw const AiException("Couldn't read that drink. Try a clearer photo.");
    final j = Map<String, dynamic>.from(d);
    final ml = _num(j['ml']).round().clamp(0, 5000);
    if (ml <= 0) throw const AiException('No drink spotted. Try a photo of the glass or bottle.');
    final hydration = j.containsKey('hydration_ml') ? _num(j['hydration_ml']).round().clamp(0, ml) : ml;
    final emoji = (j['emoji'] as String?)?.trim();
    return DrinkEstimate(
      name: (j['name'] as String?)?.trim().isNotEmpty == true ? j['name'] as String : 'Drink',
      emoji: emoji == null || emoji.isEmpty ? '🥤' : emoji,
      ml: ml,
      hydrationMl: hydration,
      containerMl: _num(j['container_ml']).round().clamp(0, 5000),
      macros: Macros(
        kcal: _num(j['calories']),
        protein: _num(j['protein']),
        carbs: _num(j['carbs']),
        fat: _num(j['fat']),
      ),
      confidence: _num(j['confidence']).clamp(0, 1).toDouble(),
      note: (j['note'] as String?) ?? '',
    );
  }
}
