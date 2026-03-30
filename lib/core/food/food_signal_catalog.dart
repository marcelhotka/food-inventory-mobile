class FoodSignalInfo {
  final String normalizedName;
  final String itemKey;
  final Set<String> signals;
  final bool isLactoseFree;
  final bool isGlutenFree;
  final bool isEggFree;

  const FoodSignalInfo({
    required this.normalizedName,
    required this.itemKey,
    required this.signals,
    required this.isLactoseFree,
    required this.isGlutenFree,
    required this.isEggFree,
  });
}

FoodSignalInfo deriveFoodSignalInfo(String rawValue) {
  final normalized = _normalizeFoodValue(rawValue);
  final isLactoseFree = normalized.contains('bezlakt');
  final isGlutenFree = normalized.contains('bezlepk');
  final isEggFree =
      normalized.contains('bezvajec') || normalized.contains('nahradavajec');

  final itemKey = _canonicalItemKey(normalized);
  final signals = <String>{itemKey};

  if (!isLactoseFree &&
      const {'milk', 'cheese', 'yogurt', 'cream', 'butter'}.contains(itemKey)) {
    signals.add('dairy');
    signals.add('lactose');
  }

  if (!isGlutenFree &&
      const {'bread', 'pasta', 'flour'}.contains(itemKey)) {
    signals.add('gluten');
  }

  if (!isEggFree && itemKey == 'eggs') {
    signals.add('eggs');
  }

  signals.addAll(signals.map(_canonicalFoodSignal).where((e) => e.isNotEmpty));

  return FoodSignalInfo(
    normalizedName: normalized,
    itemKey: itemKey,
    signals: signals,
    isLactoseFree: isLactoseFree,
    isGlutenFree: isGlutenFree,
    isEggFree: isEggFree,
  );
}

String canonicalFoodSignal(String value) => _canonicalFoodSignal(
  _normalizeFoodValue(value),
);

String normalizeFoodValue(String value) => _normalizeFoodValue(value);

String _canonicalItemKey(String normalized) {
  if (normalized.contains('mlieko') || normalized.contains('milk')) {
    return 'milk';
  }
  if (normalized.contains('syr') ||
      normalized.contains('cheese') ||
      normalized.contains('gorgonzola') ||
      normalized.contains('mozzarella')) {
    return 'cheese';
  }
  if (normalized.contains('jogurt') || normalized.contains('yogurt')) {
    return 'yogurt';
  }
  if (normalized.contains('smotan') || normalized.contains('cream')) {
    return 'cream';
  }
  if (normalized.contains('maslo') || normalized.contains('butter')) {
    return 'butter';
  }
  if (normalized.contains('vajc') || normalized.contains('egg')) {
    return 'eggs';
  }
  if (normalized.contains('cestovin') || normalized.contains('pasta')) {
    return 'pasta';
  }
  if (normalized.contains('chlieb') ||
      normalized.contains('peciv') ||
      normalized.contains('baget') ||
      normalized.contains('bread')) {
    return 'bread';
  }
  if (normalized.contains('muka') || normalized.contains('flour')) {
    return 'flour';
  }
  if (normalized.contains('arasid')) {
    return 'peanuts';
  }
  if (normalized.contains('orech') || normalized.contains('mandl')) {
    return 'tree_nuts';
  }
  if (normalized.contains('soj')) {
    return 'soy';
  }
  if (normalized.contains('ryb')) {
    return 'fish';
  }
  if (normalized.contains('krevet')) {
    return 'shellfish';
  }
  if (normalized.contains('sezam')) {
    return 'sesame';
  }
  return normalized;
}

String _canonicalFoodSignal(String value) {
  switch (value) {
    case 'lactose':
    case 'laktoza':
    case 'laktozu':
    case 'laktozy':
    case 'dairy':
    case 'mliecne':
    case 'mliecnych':
    case 'mliecna':
    case 'milk':
    case 'cheese':
    case 'mlieko':
    case 'syr':
      return 'lactose';
    case 'gluten':
    case 'lepok':
    case 'lepku':
    case 'wheat':
    case 'pasta':
    case 'bread':
    case 'cestoviny':
    case 'chlieb':
    case 'pecivo':
    case 'bageta':
    case 'bagetu':
    case 'bagety':
    case 'baget':
    case 'muka':
    case 'flour':
      return 'gluten';
    case 'egg':
    case 'eggs':
    case 'vajce':
    case 'vajcia':
    case 'vajec':
      return 'eggs';
    case 'peanut':
    case 'peanuts':
    case 'arasidy':
      return 'peanuts';
    case 'nuts':
    case 'nut':
    case 'almond':
    case 'walnut':
    case 'hazelnut':
    case 'mandla':
    case 'orech':
    case 'orechy':
      return 'tree_nuts';
    case 'soy':
    case 'soya':
    case 'soj':
    case 'sojove':
      return 'soy';
    case 'fish':
    case 'ryba':
      return 'fish';
    case 'shellfish':
    case 'shrimp':
    case 'prawn':
    case 'kreveta':
      return 'shellfish';
    case 'sesame':
    case 'sezam':
      return 'sesame';
    default:
      return value;
  }
}

String _normalizeFoodValue(String value) {
  const replacements = {
    'á': 'a',
    'ä': 'a',
    'č': 'c',
    'ď': 'd',
    'é': 'e',
    'ě': 'e',
    'í': 'i',
    'ĺ': 'l',
    'ľ': 'l',
    'ň': 'n',
    'ó': 'o',
    'ô': 'o',
    'ŕ': 'r',
    'ř': 'r',
    'š': 's',
    'ť': 't',
    'ú': 'u',
    'ů': 'u',
    'ý': 'y',
    'ž': 'z',
  };

  var normalized = value.toLowerCase().trim();
  replacements.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
