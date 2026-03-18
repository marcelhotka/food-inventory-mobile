import '../../food_items/domain/food_item.dart';
import 'recipe.dart';
import 'recipe_ingredient.dart';

class MatchedIngredient {
  final RecipeIngredient ingredient;
  final List<FoodItem> matchedItems;
  final double availableQuantityInRecipeUnit;

  const MatchedIngredient({
    required this.ingredient,
    required this.matchedItems,
    required this.availableQuantityInRecipeUnit,
  });
}

class PartialIngredient {
  final RecipeIngredient ingredient;
  final List<FoodItem> matchedItems;
  final double availableQuantityInRecipeUnit;
  final double missingQuantityInRecipeUnit;

  const PartialIngredient({
    required this.ingredient,
    required this.matchedItems,
    required this.availableQuantityInRecipeUnit,
    required this.missingQuantityInRecipeUnit,
  });
}

class MissingIngredient {
  final RecipeIngredient ingredient;
  final double missingQuantityInRecipeUnit;

  const MissingIngredient({
    required this.ingredient,
    required this.missingQuantityInRecipeUnit,
  });
}

class RecipeMatchResult {
  final Recipe recipe;
  final List<MatchedIngredient> available;
  final List<PartialIngredient> partial;
  final List<MissingIngredient> missing;

  const RecipeMatchResult({
    required this.recipe,
    required this.available,
    required this.partial,
    required this.missing,
  });
}
