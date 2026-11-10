import 'package:dio/dio.dart';

import '../../domain/entities/food.dart';
import '../../domain/entities/macros.dart';

class BarcodeLookupException implements Exception {
  const BarcodeLookupException(this.message, {this.notFound = false, this.productName, this.brand});
  final String message;
  final bool notFound;

  /// Known when a database has the product but no usable nutrition.
  final String? productName;
  final String? brand;

  @override
  String toString() => message;
}

/// Equivalent spellings of one barcode. The same product can be stored as
/// UPC-A (12), EAN-13 (13, leading 0), GTIN-14, or scanned as UPC-E (8).
List<String> barcodeVariants(String raw) {
  final code = raw.replaceAll(RegExp(r'\D'), '');
  if (code.isEmpty) return [raw.trim()];
  final out = <String>{code};
  if (code.length == 8 && (code.startsWith('0') || code.startsWith('1'))) {
    final upcA = _expandUpcE(code);
    if (upcA != null) out.add(upcA);
  }
  for (final c in out.toList()) {
    final trimmed = c.replaceFirst(RegExp(r'^0+'), '');
    if (trimmed.length >= 8) {
      out
        ..add(trimmed)
        ..add(trimmed.padLeft(12, '0'))
        ..add(trimmed.padLeft(13, '0'))
        ..add(trimmed.padLeft(14, '0'));
    }
  }
  return out.where((c) => c.length >= 8 && c.length <= 14).toList();
}

/// UPC-E (8 digits incl. number system and check digit) → UPC-A.
String? _expandUpcE(String e) {
  if (e.length != 8) return null;
  final ns = e[0];
  final d = e.substring(1, 7);
  final check = e[7];
  final last = d[5];
  final String body;
  switch (last) {
    case '0' || '1' || '2':
      body = '${d.substring(0, 2)}${last}0000${d.substring(2, 5)}';
    case '3':
      body = '${d.substring(0, 3)}00000${d.substring(3, 5)}';
    case '4':
      body = '${d.substring(0, 4)}00000${d[4]}';
    default:
      body = '${d.substring(0, 5)}0000$last';
  }
  return '$ns$body$check';
}

/// Open Food Facts product lookup (free, no key). https://world.openfoodfacts.org
class OpenFoodFactsApi {
  OpenFoodFactsApi({Dio? dio, Dio? upcDio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://world.openfoodfacts.org',
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                // OFF asks API clients to identify themselves.
                headers: {'User-Agent': 'Nibbl/1.0 (Flutter; nutrition tracker)'},
              ),
            ),
        _upc = upcDio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.upcitemdb.com',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final Dio _dio;
  final Dio _upc;

  static const _notFoundMsg = "This product isn't in the barcode databases yet. Snap its nutrition label and "
      'Nibbl will read it for you.';

  Future<Food> lookup(String barcode) async {
    String? name;
    String? brand;
    var reached = false;

    for (final code in barcodeVariants(barcode)) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          '/api/v2/product/$code.json',
          queryParameters: {
            'fields': 'product_name,product_name_en,generic_name,brands,nutriments,serving_size,serving_quantity,'
                'categories_tags,quantity',
          },
        );
        reached = true;
        final data = res.data;
        if (data == null || data['status'] != 1 || data['product'] == null) continue;
        final p = Map<String, dynamic>.from(data['product'] as Map);
        final food = _toFood(barcode, p);
        if (food != null) return food;
        // Product known, nutrition missing: remember its name for the AI fallback.
        name ??= _name(p);
        brand ??= _brand(p);
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          reached = true;
          continue;
        }
        // Network trouble: stop trying variants.
        break;
      }
    }

    // Second opinion for the product name (free trial endpoint, no key).
    if (name == null) {
      try {
        final res = await _upc.get<Map<String, dynamic>>('/prod/trial/lookup', queryParameters: {'upc': barcode});
        reached = true;
        final items = res.data?['items'];
        if (items is List && items.isNotEmpty && items.first is Map) {
          final item = Map<String, dynamic>.from(items.first as Map);
          final title = (item['title'] as String?)?.trim();
          if (title != null && title.isNotEmpty) {
            name = title;
            brand = (item['brand'] as String?)?.trim();
          }
        }
      } on DioException {
        // Rate-limited or offline; not essential.
      }
    }

    if (!reached && name == null) {
      throw const BarcodeLookupException("Couldn't reach the barcode database. Check your connection.");
    }
    throw BarcodeLookupException(
      name == null
          ? _notFoundMsg
          : 'Found "$name" but it has no nutrition info. Snap the label, or let Nibbl estimate it.',
      notFound: true,
      productName: name,
      brand: (brand?.isEmpty ?? true) ? null : brand,
    );
  }

  String? _name(Map<String, dynamic> p) {
    for (final k in ['product_name', 'product_name_en', 'generic_name']) {
      final v = (p[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String? _brand(Map<String, dynamic> p) => (p['brands'] as String?)?.split(',').first.trim();

  /// Null when the product has no usable nutrition data.
  Food? _toFood(String barcode, Map<String, dynamic> p) {
    final n = Map<String, dynamic>.from((p['nutriments'] as Map?) ?? const {});
    double v(String key) {
      final raw = n[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw) ?? 0;
      return 0;
    }

    double kcal(String suffix) {
      final k = v('energy-kcal$suffix');
      if (k > 0) return k;
      final kj = v('energy-kj$suffix') > 0 ? v('energy-kj$suffix') : v('energy$suffix');
      return kj > 0 ? kj / 4.184 : 0;
    }

    final servingQty = (p['serving_quantity'] is num) ? (p['serving_quantity'] as num).toDouble() : 0.0;
    final per100 = Macros(
      kcal: kcal('_100g'),
      protein: v('proteins_100g'),
      carbs: v('carbohydrates_100g'),
      fat: v('fat_100g'),
    );
    final perServing = Macros(
      kcal: kcal('_serving'),
      protein: v('proteins_serving'),
      carbs: v('carbohydrates_serving'),
      fat: v('fat_serving'),
    );
    bool empty(Macros m) => m.kcal == 0 && m.protein == 0 && m.carbs == 0 && m.fat == 0;

    final double servingGrams;
    final String servingLabel;
    final Macros macros;
    if (!empty(per100)) {
      servingGrams = servingQty > 0 ? servingQty : 100.0;
      servingLabel = servingQty > 0 ? ((p['serving_size'] as String?) ?? '${servingGrams.round()} g') : '100 g';
      macros = per100.scale(servingGrams / 100);
    } else if (!empty(perServing)) {
      // Some labels only list values per serving.
      servingGrams = servingQty > 0 ? servingQty : 100.0;
      servingLabel = (p['serving_size'] as String?) ?? '1 serving';
      macros = perServing;
    } else {
      return null;
    }

    final brand = _brand(p);
    return Food(
      id: 'off_$barcode',
      name: _name(p) ?? 'Scanned product',
      brand: (brand?.isEmpty ?? true) ? null : brand,
      emoji: _emojiFor(p['categories_tags']),
      servingLabel: servingLabel,
      servingGrams: servingGrams,
      macros: macros,
      barcode: barcode,
    );
  }

  String _emojiFor(Object? categories) {
    final tags = (categories is List) ? categories.join(' ') : '';
    const map = {
      'beverages': '🥤', 'dairies': '🥛', 'cheeses': '🧀', 'yogurts': '🥛', 'chocolates': '🍫',
      'biscuits': '🍪', 'breads': '🍞', 'cereals': '🥣', 'snacks': '🍿', 'fruits': '🍎', 'meats': '🥩',
      'fish': '🐟', 'pastas': '🍝', 'sauces': '🥫', 'frozen': '🧊', 'nuts': '🥜', 'noodles': '🍜',
    };
    for (final e in map.entries) {
      if (tags.contains(e.key)) return e.value;
    }
    return '🛒';
  }
}
