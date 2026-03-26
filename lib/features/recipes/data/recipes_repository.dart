import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';
import 'recipes_remote_data_source.dart';

class RecipesRepository {
  RecipesRepository({
    required String householdId,
    RecipesRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource =
           remoteDataSource ??
           RecipesRemoteDataSource(householdId: householdId);

  final RecipesRemoteDataSource _remoteDataSource;

  Future<List<Recipe>> getRecipes() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    try {
      final remoteRecipes = await _remoteDataSource.fetchRecipes();
      final favoriteIds = userId == null
          ? <String>{}
          : await _remoteDataSource.fetchFavoriteRecipeIds(userId);
      final remoteIds = remoteRecipes.map((recipe) => recipe.id).toSet();
      final mergedRecipes = [
        ...remoteRecipes.map(
          (recipe) =>
              recipe.copyWith(isFavorite: favoriteIds.contains(recipe.id)),
        ),
        ..._seedRecipes
            .where((recipe) => !remoteIds.contains(recipe.id))
            .map(
              (recipe) =>
                  recipe.copyWith(isFavorite: favoriteIds.contains(recipe.id)),
            ),
      ];
      if (mergedRecipes.isNotEmpty) {
        return mergedRecipes;
      }
    } catch (_) {
      // Keep the app usable while the database is still being prepared.
    }

    return _seedRecipes;
  }

  Future<Recipe> addRecipe(Recipe recipe) {
    return _remoteDataSource.createRecipe(recipe);
  }

  Future<Recipe> editRecipe(Recipe recipe) {
    return _remoteDataSource.updateRecipe(recipe);
  }

  Future<void> removeRecipe(String recipeId) {
    return _remoteDataSource.deleteRecipe(recipeId);
  }

  Future<void> setRecipeFavorite({
    required String recipeId,
    required bool isFavorite,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('No signed-in user.');
    }

    await _remoteDataSource.setRecipeFavorite(
      recipeId: recipeId,
      userId: userId,
      isFavorite: isFavorite,
    );
  }
}

const _seedRecipes = [
  Recipe(
    id: 'omelette',
    householdId: null,
    createdByUserId: null,
    name: 'Cheese Omelette',
    description: 'Quick breakfast from fridge basics.',
    totalMinutes: 15,
    defaultServings: 2,
    isPublic: true,
    isFavorite: false,
    createdAt: null,
    updatedAt: null,
    ingredients: [
      RecipeIngredient(
        id: 'omelette_1',
        name: 'eggs',
        quantity: 4,
        unit: 'pcs',
        sortOrder: 0,
      ),
      RecipeIngredient(
        id: 'omelette_2',
        name: 'milk',
        quantity: 200,
        unit: 'ml',
        sortOrder: 1,
      ),
      RecipeIngredient(
        id: 'omelette_3',
        name: 'cheese',
        quantity: 100,
        unit: 'g',
        sortOrder: 2,
      ),
    ],
  ),
  Recipe(
    id: 'pasta',
    householdId: null,
    createdByUserId: null,
    name: 'Tomato Pasta',
    description: 'Simple pantry dinner with just a few ingredients.',
    totalMinutes: 30,
    defaultServings: 2,
    isPublic: true,
    isFavorite: false,
    createdAt: null,
    updatedAt: null,
    ingredients: [
      RecipeIngredient(
        id: 'pasta_1',
        name: 'pasta',
        quantity: 250,
        unit: 'g',
        sortOrder: 0,
      ),
      RecipeIngredient(
        id: 'pasta_2',
        name: 'tomato sauce',
        quantity: 1,
        unit: 'pcs',
        sortOrder: 1,
      ),
      RecipeIngredient(
        id: 'pasta_3',
        name: 'cheese',
        quantity: 50,
        unit: 'g',
        sortOrder: 2,
      ),
    ],
  ),
  Recipe(
    id: 'rice_bowl',
    householdId: null,
    createdByUserId: null,
    name: 'Chicken Rice Bowl',
    description: 'Easy lunch that works well with shared pantry stock.',
    totalMinutes: 45,
    defaultServings: 3,
    isPublic: true,
    isFavorite: false,
    createdAt: null,
    updatedAt: null,
    ingredients: [
      RecipeIngredient(
        id: 'rice_bowl_1',
        name: 'chicken',
        quantity: 300,
        unit: 'g',
        sortOrder: 0,
      ),
      RecipeIngredient(
        id: 'rice_bowl_2',
        name: 'rice',
        quantity: 200,
        unit: 'g',
        sortOrder: 1,
      ),
      RecipeIngredient(
        id: 'rice_bowl_3',
        name: 'onion',
        quantity: 1,
        unit: 'pcs',
        sortOrder: 2,
      ),
    ],
  ),
  Recipe(
    id: 'sandwich',
    householdId: null,
    createdByUserId: null,
    name: 'Ham Sandwich',
    description: 'Fast meal for busy evenings.',
    totalMinutes: 15,
    defaultServings: 2,
    isPublic: true,
    isFavorite: false,
    createdAt: null,
    updatedAt: null,
    ingredients: [
      RecipeIngredient(
        id: 'sandwich_1',
        name: 'bread',
        quantity: 4,
        unit: 'pcs',
        sortOrder: 0,
      ),
      RecipeIngredient(
        id: 'sandwich_2',
        name: 'ham',
        quantity: 120,
        unit: 'g',
        sortOrder: 1,
      ),
      RecipeIngredient(
        id: 'sandwich_3',
        name: 'cheese',
        quantity: 80,
        unit: 'g',
        sortOrder: 2,
      ),
    ],
  ),
];
