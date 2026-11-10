/// Parses typed ingredients and checks recipes against what the user has.
library;

/// Splits "4 eggs", "500g rice", "rice 500 g", "eggs x4" into (name, qty).
(String, String) parseIngredient(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return ('', '');
  const units =
      r'(?:kg|g|gm|gms|grams?|ml|l|ltr|litres?|liters?|cups?|tbsp|tsp|pcs?|pieces?|packs?|packets?|dozen|bunch(?:es)?|cans?|loaf|slices?)';
  final lead = RegExp('^(\\d+(?:[.,]\\d+)?|½|¼|¾)\\s*($units)?\\.?\\s+(?:of\\s+)?(.+)\$', caseSensitive: false);
  final trail = RegExp('^(.+?)\\s*(?:[x×-]\\s*)?(\\d+(?:[.,]\\d+)?)\\s*($units)?\$', caseSensitive: false);
  final m1 = lead.firstMatch(text);
  if (m1 != null) {
    final qty = [m1.group(1), m1.group(2)].whereType<String>().join(m1.group(2) == null ? '' : ' ');
    return (_cap(m1.group(3)!), qty);
  }
  final m2 = trail.firstMatch(text);
  if (m2 != null && RegExp('[a-zA-Z]').hasMatch(m2.group(1)!)) {
    final qty = [m2.group(2), m2.group(3)].whereType<String>().join(m2.group(3) == null ? '' : ' ');
    return (_cap(m2.group(1)!), qty);
  }
  return (_cap(text), '');
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Regional/alternate names mapped to one canonical word.
const _synonyms = {
  'aloo': 'potato',
  'alu': 'potato',
  'pyaz': 'onion',
  'pyaaz': 'onion',
  'kanda': 'onion',
  'tamatar': 'tomato',
  'dahi': 'curd',
  'yogurt': 'curd',
  'yoghurt': 'curd',
  'chili': 'chilli',
  'chilly': 'chilli',
  'mirchi': 'chilli',
  'capsicum': 'capsicum',
  'bellpepper': 'capsicum',
  'dhania': 'coriander',
  'cilantro': 'coriander',
  'jeera': 'cumin',
  'haldi': 'turmeric',
  'adrak': 'ginger',
  'lehsun': 'garlic',
  'lasun': 'garlic',
  'palak': 'spinach',
  'gobi': 'cauliflower',
  'chawal': 'rice',
  'anda': 'egg',
  'ande': 'egg',
  'doodh': 'milk',
  'maida': 'flour',
  'atta': 'flour',
  'besan': 'gramflour',
  'chana': 'chickpea',
  'chole': 'chickpea',
  'moong': 'dal',
  'toor': 'dal',
  'masoor': 'dal',
  'urad': 'dal',
  'lentil': 'dal',
  'daal': 'dal',
  'brinjal': 'eggplant',
  'baingan': 'eggplant',
  'bhindi': 'okra',
  'ladyfinger': 'okra',
  'matar': 'peas',
  'pea': 'peas',
  'nimbu': 'lemon',
  'lime': 'lemon',
  'murgi': 'chicken',
  'murgh': 'chicken',
  'scallion': 'onion',
};

/// Words that describe preparation rather than an ingredient.
const _filler = {
  'a',
  'an',
  'and',
  'or',
  'of',
  'to',
  'taste',
  'fresh',
  'chopped',
  'finely',
  'sliced',
  'diced',
  'minced',
  'grated',
  'boiled',
  'cooked',
  'raw',
  'large',
  'medium',
  'small',
  'whole',
  'big',
  'pinch',
  'handful',
  'for',
  'garnish',
  'optional',
  'some',
  'little',
  'few',
  'cubed',
  'crumbled',
  'beaten',
  'leftover',
  'ripe',
  'peeled',
  'washed',
  'soaked',
  'roughly',
  'thinly',
  'pieces',
  'piece',
  'cup',
  'cups',
  'tbsp',
  'tsp',
  'g',
  'kg',
  'ml',
  'cooking',
  'as',
  'needed',
  'each',
  'about',
  'plus',
  'extra',
  'warm',
  'hot',
  'cold',
  'water',
  'salt',
};

/// Assumed in every kitchen when the user allows basics.
const _basics = {
  'oil',
  'ghee',
  'pepper',
  'turmeric',
  'cumin',
  'mustard',
  'seeds',
  'seed',
  'powder',
  'masala',
  'garam',
  'red',
  'black',
  'chilli',
  'coriander',
  'hing',
  'asafoetida',
  'spice',
  'spices',
  'sugar',
  'vinegar',
  'refined',
  'vegetable',
  'sunflower',
  'groundnut',
  'ground',
  'curry',
  'leaves',
  'bay',
  'leaf',
  'kasuri',
  'methi',
  'fenugreek',
  'ajwain',
  'carom',
  'cinnamon',
  'cardamom',
  'clove',
  'cloves',
  'paprika',
  'oregano',
  'herbs',
  'seasoning',
};

String _singular(String w) {
  if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.length > 4 && (w.endsWith('oes') || w.endsWith('ches') || w.endsWith('shes'))) {
    return w.substring(0, w.length - 2);
  }
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) return w.substring(0, w.length - 1);
  return w;
}

Set<String> _words(String text) {
  final out = <String>{};
  for (final raw in text.toLowerCase().split(RegExp('[^a-z]+'))) {
    if (raw.isEmpty) continue;
    final w = _singular(raw);
    out.add(_synonyms[w] ?? _synonyms[raw] ?? w);
  }
  return out;
}

/// Ingredient names in a recipe that aren't in the user's [pantry] (and
/// aren't basics such as salt, water or, when [allowBasics], oil and spices).
List<String> missingIngredients(
  Iterable<String> recipeIngredients,
  Iterable<String> pantry, {
  bool allowBasics = true,
}) {
  final have = <String>{};
  for (final p in pantry) {
    have.addAll(_words(p).where((w) => w.length >= 3 && !_filler.contains(w)));
  }
  final missing = <String>[];
  for (final ing in recipeIngredients) {
    final words = _words(ing).where((w) => !_filler.contains(w)).toSet();
    if (words.isEmpty) continue; // only water / salt / filler
    if (words.any(have.contains)) continue;
    if (allowBasics && words.every(_basics.contains)) continue;
    missing.add(ing);
  }
  return missing;
}
