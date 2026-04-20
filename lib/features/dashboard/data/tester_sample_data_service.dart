import 'package:supabase_flutter/supabase_flutter.dart';

import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';

class TesterSampleDataService {
  final Household household;

  TesterSampleDataService({required this.household});

  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: household.id,
  );
  late final RecipesRepository _recipesRepository = RecipesRepository(
    householdId: household.id,
  );

  Future<TesterSampleLoadResult> loadSampleData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw const TesterSampleDataAuthException();
    }

    final pantryItems = await _foodItemsRepository.getFoodItems();
    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
    final mealPlanEntries = await _mealPlanRepository.getEntries();
    final recipes = await _recipesRepository.getRecipes();
    final now = DateTime.now();
    final nowUtc = DateTime.now().toUtc();

    final pantryKeys = pantryItems
        .map((item) => _itemKey(item.name, item.unit))
        .toSet();
    final shoppingKeys = shoppingItems
        .where((item) => !item.isBought)
        .map((item) => _itemKey(item.name, item.unit))
        .toSet();
    final mealPlanKeys = mealPlanEntries
        .map(
          (entry) =>
              '${entry.recipeId ?? entry.recipeName}|${entry.scheduledFor.toIso8601String().split('T').first}|${entry.mealType}',
        )
        .toSet();

    final samplePantry = [
      FoodItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Mlieko',
        barcode: null,
        category: 'dairy',
        storageLocation: 'fridge',
        quantity: 1,
        lowStockThreshold: 1,
        unit: 'l',
        expirationDate: DateTime(now.year, now.month, now.day + 2),
        openedAt: null,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
      FoodItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Vajcia',
        barcode: null,
        category: 'dairy',
        storageLocation: 'fridge',
        quantity: 6,
        lowStockThreshold: 6,
        unit: 'pcs',
        expirationDate: DateTime(now.year, now.month, now.day + 5),
        openedAt: null,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
      FoodItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Syr',
        barcode: null,
        category: 'dairy',
        storageLocation: 'fridge',
        quantity: 150,
        lowStockThreshold: 100,
        unit: 'g',
        expirationDate: DateTime(now.year, now.month, now.day + 3),
        openedAt: nowUtc.subtract(const Duration(days: 1)),
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
      FoodItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Chlieb',
        barcode: null,
        category: 'grains',
        storageLocation: 'pantry',
        quantity: 1,
        lowStockThreshold: 1,
        unit: 'pcs',
        expirationDate: DateTime(now.year, now.month, now.day + 1),
        openedAt: null,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    ];

    final sampleShopping = [
      ShoppingListItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Maslo',
        quantity: 250,
        unit: 'g',
        source: ShoppingListItem.sourceManual,
        isBought: false,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
      ShoppingListItem(
        id: '',
        userId: user.id,
        householdId: household.id,
        name: 'Paradajková omáčka',
        quantity: 1,
        unit: 'pcs',
        source: ShoppingListItem.sourceRecipeMissing,
        isBought: false,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    ];

    final omelette = recipes.cast<dynamic>().firstWhere(
      (recipe) => recipe.id == 'omelette',
      orElse: () => null,
    );
    final pasta = recipes.cast<dynamic>().firstWhere(
      (recipe) => recipe.id == 'pasta',
      orElse: () => null,
    );

    final sampleMealPlan = [
      if (omelette != null)
        MealPlanEntry(
          id: '',
          householdId: household.id,
          userId: user.id,
          recipeId: omelette.id as String,
          recipeName: omelette.name as String,
          servings: (omelette.defaultServings as int?) ?? 2,
          scheduledFor: DateTime(now.year, now.month, now.day),
          mealType: 'breakfast',
          note: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      if (pasta != null)
        MealPlanEntry(
          id: '',
          householdId: household.id,
          userId: user.id,
          recipeId: pasta.id as String,
          recipeName: pasta.name as String,
          servings: (pasta.defaultServings as int?) ?? 2,
          scheduledFor: DateTime(now.year, now.month, now.day + 1),
          mealType: 'dinner',
          note: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
    ];

    var addedPantry = 0;
    for (final item in samplePantry) {
      final key = _itemKey(item.name, item.unit);
      if (pantryKeys.contains(key)) {
        continue;
      }
      await _foodItemsRepository.addFoodItem(item);
      pantryKeys.add(key);
      addedPantry++;
    }

    var addedShopping = 0;
    for (final item in sampleShopping) {
      final key = _itemKey(item.name, item.unit);
      if (shoppingKeys.contains(key)) {
        continue;
      }
      await _shoppingListRepository.addShoppingListItem(item);
      shoppingKeys.add(key);
      addedShopping++;
    }

    var addedMeals = 0;
    for (final entry in sampleMealPlan) {
      final key =
          '${entry.recipeId ?? entry.recipeName}|${entry.scheduledFor.toIso8601String().split('T').first}|${entry.mealType}';
      if (mealPlanKeys.contains(key)) {
        continue;
      }
      await _mealPlanRepository.addEntry(entry);
      mealPlanKeys.add(key);
      addedMeals++;
    }

    return TesterSampleLoadResult(
      addedPantry: addedPantry,
      addedShopping: addedShopping,
      addedMeals: addedMeals,
    );
  }
}

class TesterSampleLoadResult {
  final int addedPantry;
  final int addedShopping;
  final int addedMeals;

  const TesterSampleLoadResult({
    required this.addedPantry,
    required this.addedShopping,
    required this.addedMeals,
  });
}

class TesterSampleDataAuthException implements Exception {
  const TesterSampleDataAuthException();
}

String _itemKey(String name, String unit) {
  return '${_normalizeValue(name)}|${_normalizeUnit(unit)}';
}

String _normalizeValue(String value) {
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

String _normalizeUnit(String value) {
  final normalized = value.trim().toLowerCase();
  if (const {
    'pcs',
    'pc',
    'piece',
    'pieces',
    'ks',
    'kus',
    'kusy',
    'kusov',
  }.contains(normalized)) {
    return 'pcs';
  }
  if (const {'g', 'gram', 'grams', 'gramy', 'gramov'}.contains(normalized)) {
    return 'g';
  }
  if (const {'kg', 'kilogram', 'kilograms', 'kilo'}.contains(normalized)) {
    return 'kg';
  }
  if (const {
    'ml',
    'milliliter',
    'milliliters',
    'mililitre',
  }.contains(normalized)) {
    return 'ml';
  }
  if (const {'l', 'liter', 'liters', 'litre', 'litra'}.contains(normalized)) {
    return 'l';
  }
  return normalized;
}
