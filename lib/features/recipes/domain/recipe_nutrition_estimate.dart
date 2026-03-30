import 'recipe.dart';
import 'recipe_ingredient.dart';

class RecipeNutritionEstimate {
  final int selectedServings;
  final int caloriesTotal;
  final double proteinTotal;
  final double fiberTotal;
  final int caloriesPerServing;
  final double proteinPerServing;
  final double fiberPerServing;
  final int balanceScore;

  const RecipeNutritionEstimate({
    required this.selectedServings,
    required this.caloriesTotal,
    required this.proteinTotal,
    required this.fiberTotal,
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.fiberPerServing,
    required this.balanceScore,
  });
}

class _NutritionProfile {
  final double caloriesPerBase;
  final double proteinPerBase;
  final double fiberPerBase;
  final String baseUnit;

  const _NutritionProfile({
    required this.caloriesPerBase,
    required this.proteinPerBase,
    required this.fiberPerBase,
    required this.baseUnit,
  });
}

RecipeNutritionEstimate estimateRecipeNutrition(
  Recipe recipe, {
  required int servings,
}) {
  final scaleFactor = servings / recipe.defaultServings;
  var totalCalories = 0.0;
  var totalProtein = 0.0;
  var totalFiber = 0.0;

  for (final ingredient in recipe.ingredients) {
    final profile = _profileForIngredient(ingredient);
    if (profile == null) {
      continue;
    }

    final scaledQuantity = ingredient.quantity * scaleFactor;
    final baseQuantity = _convertToBaseUnit(
      quantity: scaledQuantity,
      fromUnit: ingredient.unit,
      toUnit: profile.baseUnit,
    );
    if (baseQuantity == null || baseQuantity <= 0) {
      continue;
    }

    totalCalories += (baseQuantity / 100) * profile.caloriesPerBase;
    totalProtein += (baseQuantity / 100) * profile.proteinPerBase;
    totalFiber += (baseQuantity / 100) * profile.fiberPerBase;
  }

  final normalizedServings = servings <= 0 ? 1 : servings;
  final caloriesPerServing = (totalCalories / normalizedServings).round();
  final proteinPerServing = totalProtein / normalizedServings;
  final fiberPerServing = totalFiber / normalizedServings;

  var balanceScore = 50;
  if (proteinPerServing >= 20) {
    balanceScore += 18;
  } else if (proteinPerServing >= 12) {
    balanceScore += 10;
  } else if (proteinPerServing < 8) {
    balanceScore -= 8;
  }

  if (fiberPerServing >= 6) {
    balanceScore += 15;
  } else if (fiberPerServing >= 3) {
    balanceScore += 8;
  } else if (fiberPerServing < 2) {
    balanceScore -= 6;
  }

  if (caloriesPerServing >= 350 && caloriesPerServing <= 750) {
    balanceScore += 10;
  } else if (caloriesPerServing > 900) {
    balanceScore -= 12;
  } else if (caloriesPerServing < 200) {
    balanceScore -= 5;
  }

  return RecipeNutritionEstimate(
    selectedServings: normalizedServings,
    caloriesTotal: totalCalories.round(),
    proteinTotal: totalProtein < 0 ? 0 : totalProtein,
    fiberTotal: totalFiber < 0 ? 0 : totalFiber,
    caloriesPerServing: caloriesPerServing < 0 ? 0 : caloriesPerServing,
    proteinPerServing: proteinPerServing < 0 ? 0 : proteinPerServing,
    fiberPerServing: fiberPerServing < 0 ? 0 : fiberPerServing,
    balanceScore: balanceScore.clamp(0, 100),
  );
}

_NutritionProfile? _profileForIngredient(RecipeIngredient ingredient) {
  final key = _canonicalIngredientKey(ingredient.name);
  switch (key) {
    case 'milk':
      return const _NutritionProfile(
        caloriesPerBase: 60,
        proteinPerBase: 3.2,
        fiberPerBase: 0,
        baseUnit: 'ml',
      );
    case 'cheese':
      return const _NutritionProfile(
        caloriesPerBase: 350,
        proteinPerBase: 25,
        fiberPerBase: 0,
        baseUnit: 'g',
      );
    case 'eggs':
      return const _NutritionProfile(
        caloriesPerBase: 78,
        proteinPerBase: 6.3,
        fiberPerBase: 0,
        baseUnit: 'pcs',
      );
    case 'pasta':
      return const _NutritionProfile(
        caloriesPerBase: 360,
        proteinPerBase: 12,
        fiberPerBase: 3,
        baseUnit: 'g',
      );
    case 'tomato':
      return const _NutritionProfile(
        caloriesPerBase: 18,
        proteinPerBase: 0.9,
        fiberPerBase: 1.2,
        baseUnit: 'g',
      );
    case 'rice':
      return const _NutritionProfile(
        caloriesPerBase: 360,
        proteinPerBase: 7,
        fiberPerBase: 1.3,
        baseUnit: 'g',
      );
    case 'chicken':
      return const _NutritionProfile(
        caloriesPerBase: 165,
        proteinPerBase: 31,
        fiberPerBase: 0,
        baseUnit: 'g',
      );
    case 'ham':
      return const _NutritionProfile(
        caloriesPerBase: 145,
        proteinPerBase: 21,
        fiberPerBase: 0,
        baseUnit: 'g',
      );
    case 'bread':
      return const _NutritionProfile(
        caloriesPerBase: 250,
        proteinPerBase: 9,
        fiberPerBase: 3,
        baseUnit: 'g',
      );
    case 'beans':
      return const _NutritionProfile(
        caloriesPerBase: 120,
        proteinPerBase: 8,
        fiberPerBase: 7,
        baseUnit: 'g',
      );
    case 'peas':
      return const _NutritionProfile(
        caloriesPerBase: 80,
        proteinPerBase: 5,
        fiberPerBase: 5,
        baseUnit: 'g',
      );
    case 'yogurt':
      return const _NutritionProfile(
        caloriesPerBase: 60,
        proteinPerBase: 4,
        fiberPerBase: 0,
        baseUnit: 'g',
      );
    case 'cream':
      return const _NutritionProfile(
        caloriesPerBase: 340,
        proteinPerBase: 2.5,
        fiberPerBase: 0,
        baseUnit: 'ml',
      );
    case 'butter':
      return const _NutritionProfile(
        caloriesPerBase: 717,
        proteinPerBase: 1,
        fiberPerBase: 0,
        baseUnit: 'g',
      );
    case 'oil':
      return const _NutritionProfile(
        caloriesPerBase: 884,
        proteinPerBase: 0,
        fiberPerBase: 0,
        baseUnit: 'ml',
      );
    default:
      return null;
  }
}

double? _convertToBaseUnit({
  required double quantity,
  required String fromUnit,
  required String toUnit,
}) {
  final normalizedFrom = _normalizeUnit(fromUnit);
  final normalizedTo = _normalizeUnit(toUnit);

  if (normalizedFrom == normalizedTo) {
    return quantity;
  }

  const weightFactors = {'g': 1.0, 'kg': 1000.0};
  const volumeFactors = {'ml': 1.0, 'l': 1000.0};
  const pieceFactors = {
    'pcs': 1.0,
    'pc': 1.0,
    'piece': 1.0,
    'pieces': 1.0,
    'ks': 1.0,
  };

  if (weightFactors.containsKey(normalizedFrom) &&
      weightFactors.containsKey(normalizedTo)) {
    final base = quantity * weightFactors[normalizedFrom]!;
    return base / weightFactors[normalizedTo]!;
  }

  if (volumeFactors.containsKey(normalizedFrom) &&
      volumeFactors.containsKey(normalizedTo)) {
    final base = quantity * volumeFactors[normalizedFrom]!;
    return base / volumeFactors[normalizedTo]!;
  }

  if (pieceFactors.containsKey(normalizedFrom) &&
      pieceFactors.containsKey(normalizedTo)) {
    final base = quantity * pieceFactors[normalizedFrom]!;
    return base / pieceFactors[normalizedTo]!;
  }

  return null;
}

String _canonicalIngredientKey(String value) {
  final normalized = _normalizeValue(value);
  if (normalized.contains('bezlakt') || normalized.contains('mlieko')) {
    return 'milk';
  }
  if (normalized.contains('gorgonzola') ||
      normalized.contains('mozzarella') ||
      normalized.contains('cheese') ||
      normalized.contains('syr')) {
    return 'cheese';
  }
  if (normalized.contains('vaj')) {
    return 'eggs';
  }
  if (normalized.contains('cestovin') || normalized.contains('pasta')) {
    return 'pasta';
  }
  if (normalized.contains('paradaj') || normalized.contains('tomato')) {
    return 'tomato';
  }
  if (normalized.contains('ryz')) {
    return 'rice';
  }
  if (normalized.contains('kur')) {
    return 'chicken';
  }
  if (normalized.contains('sunka') || normalized.contains('ham')) {
    return 'ham';
  }
  if (normalized.contains('baget') ||
      normalized.contains('chlieb') ||
      normalized.contains('bread') ||
      normalized.contains('peciv')) {
    return 'bread';
  }
  if (normalized.contains('fazu')) {
    return 'beans';
  }
  if (normalized.contains('hrach') || normalized.contains('peas')) {
    return 'peas';
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
  if (normalized.contains('olej') || normalized.contains('oil')) {
    return 'oil';
  }
  return normalized;
}

String _normalizeUnit(String value) {
  final normalized = _normalizeValue(value);
  switch (normalized) {
    case 'gram':
    case 'gramy':
    case 'gramov':
    case 'g':
      return 'g';
    case 'kilogram':
    case 'kilogramy':
    case 'kilogramov':
    case 'kg':
    case 'kilo':
      return 'kg';
    case 'liter':
    case 'litra':
    case 'litre':
    case 'litrov':
    case 'l':
      return 'l';
    case 'mililiter':
    case 'mililitre':
    case 'mililitrov':
    case 'ml':
      return 'ml';
    case 'kus':
    case 'kusy':
    case 'kusov':
    case 'ks':
    case 'pcs':
    case 'piece':
    case 'pieces':
      return 'pcs';
    default:
      return normalized;
  }
}

String _normalizeValue(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('č', 'c')
      .replaceAll('ď', 'd')
      .replaceAll('é', 'e')
      .replaceAll('ě', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ĺ', 'l')
      .replaceAll('ľ', 'l')
      .replaceAll('ň', 'n')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ŕ', 'r')
      .replaceAll('š', 's')
      .replaceAll('ť', 't')
      .replaceAll('ú', 'u')
      .replaceAll('ý', 'y')
      .replaceAll('ž', 'z');
}
