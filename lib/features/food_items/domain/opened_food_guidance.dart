import 'food_item.dart';

int recommendedOpenedUseWithinDays(FoodItem item) {
  final normalizedName = _normalizeOpenedFoodValue(item.name);

  if (normalizedName.contains('mlieko') ||
      normalizedName.contains('milk') ||
      normalizedName.contains('jogurt') ||
      normalizedName.contains('yogurt') ||
      normalizedName.contains('smotan') ||
      normalizedName.contains('cream')) {
    return 3;
  }
  if (normalizedName.contains('syr') ||
      normalizedName.contains('cheese') ||
      normalizedName.contains('tofu')) {
    return 4;
  }
  if (normalizedName.contains('sunka') ||
      normalizedName.contains('ham') ||
      normalizedName.contains('salam') ||
      normalizedName.contains('kurac') ||
      normalizedName.contains('chicken') ||
      normalizedName.contains('maso') ||
      normalizedName.contains('meat')) {
    return 2;
  }
  if (normalizedName.contains('chlieb') ||
      normalizedName.contains('chleba') ||
      normalizedName.contains('bread') ||
      normalizedName.contains('pecivo') ||
      normalizedName.contains('baget')) {
    return 4;
  }

  switch (item.category) {
    case 'dairy':
      return 3;
    case 'meat':
      return 2;
    case 'produce':
      return 3;
    case 'canned':
      return 4;
    case 'frozen':
      return 2;
    case 'beverages':
      return 5;
    case 'grains':
      return 7;
    default:
      return 3;
  }
}

int daysSinceOpened(DateTime? value) {
  if (value == null) {
    return 0;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final opened = DateTime(value.year, value.month, value.day);
  return today.difference(opened).inDays;
}

int openedDaysLeft(FoodItem item) {
  if (item.openedAt == null) {
    return 9999;
  }
  return recommendedOpenedUseWithinDays(item) - daysSinceOpened(item.openedAt);
}

DateTime? recommendedOpenedUseByDate(FoodItem item, {DateTime? openedDate}) {
  final effectiveOpenedDate = openedDate ?? item.openedAt;
  if (effectiveOpenedDate == null) {
    return null;
  }

  final normalizedOpenedDate = DateTime(
    effectiveOpenedDate.year,
    effectiveOpenedDate.month,
    effectiveOpenedDate.day,
  );
  return normalizedOpenedDate.add(
    Duration(days: recommendedOpenedUseWithinDays(item)),
  );
}

DateTime? adjustedExpirationAfterOpening(
  FoodItem item, {
  DateTime? openedDate,
}) {
  final openedUseByDate = recommendedOpenedUseByDate(
    item,
    openedDate: openedDate,
  );
  final currentExpiration = item.expirationDate;

  if (openedUseByDate == null) {
    return currentExpiration;
  }
  if (currentExpiration == null) {
    return openedUseByDate;
  }
  return currentExpiration.isBefore(openedUseByDate)
      ? currentExpiration
      : openedUseByDate;
}

String _normalizeOpenedFoodValue(String value) {
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
