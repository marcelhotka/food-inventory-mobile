import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/recipe.dart';

class RecipesRemoteDataSource {
  RecipesRemoteDataSource({required String householdId, SupabaseClient? client})
    : _householdId = householdId,
      _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<List<Recipe>> fetchRecipes() async {
    final client = _requireClient();

    final response = await client
        .from('recipes')
        .select('*, recipe_ingredients(*)')
        .or('is_public.eq.true,household_id.eq.$_householdId')
        .order('is_public', ascending: false)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((item) => Recipe.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> fetchFavoriteRecipeIds(String userId) async {
    final client = _requireClient();
    final response = await client
        .from('recipe_favorites')
        .select('recipe_id')
        .eq('household_id', _householdId)
        .eq('user_id', userId);

    return (response as List<dynamic>)
        .map((item) => (item as Map<String, dynamic>)['recipe_id'] as String)
        .toSet();
  }

  Future<void> setRecipeFavorite({
    required String recipeId,
    required String userId,
    required bool isFavorite,
  }) async {
    final client = _requireClient();

    if (isFavorite) {
      await client.from('recipe_favorites').upsert({
        'household_id': _householdId,
        'user_id': userId,
        'recipe_id': recipeId,
      }, onConflict: 'user_id,recipe_id');
      return;
    }

    await client
        .from('recipe_favorites')
        .delete()
        .eq('household_id', _householdId)
        .eq('user_id', userId)
        .eq('recipe_id', recipeId);
  }

  Future<Recipe> createRecipe(Recipe recipe) async {
    final client = _requireClient();

    final recipeResponse = await client
        .from('recipes')
        .insert({
          'household_id': recipe.householdId,
          'created_by_user_id': recipe.createdByUserId,
          'name': recipe.name,
          'description': recipe.description,
          'total_minutes': recipe.totalMinutes,
          'default_servings': recipe.defaultServings,
          'is_public': recipe.isPublic,
        })
        .select()
        .single();

    final recipeId = recipeResponse['id'] as String;

    if (recipe.ingredients.isNotEmpty) {
      await client
          .from('recipe_ingredients')
          .insert(
            recipe.ingredients
                .map(
                  (ingredient) => {
                    'recipe_id': recipeId,
                    'name': ingredient.name,
                    'quantity': ingredient.quantity,
                    'unit': ingredient.unit,
                    'sort_order': ingredient.sortOrder,
                  },
                )
                .toList(),
          );
    }

    final fullRecipeResponse = await client
        .from('recipes')
        .select('*, recipe_ingredients(*)')
        .eq('id', recipeId)
        .single();

    return Recipe.fromMap(fullRecipeResponse);
  }

  Future<Recipe> updateRecipe(Recipe recipe) async {
    final client = _requireClient();

    await client
        .from('recipes')
        .update({
          'name': recipe.name,
          'description': recipe.description,
          'total_minutes': recipe.totalMinutes,
          'default_servings': recipe.defaultServings,
          'updated_at': recipe.updatedAt?.toIso8601String(),
        })
        .eq('id', recipe.id);

    await client.from('recipe_ingredients').delete().eq('recipe_id', recipe.id);

    if (recipe.ingredients.isNotEmpty) {
      await client
          .from('recipe_ingredients')
          .insert(
            recipe.ingredients
                .map(
                  (ingredient) => {
                    'recipe_id': recipe.id,
                    'name': ingredient.name,
                    'quantity': ingredient.quantity,
                    'unit': ingredient.unit,
                    'sort_order': ingredient.sortOrder,
                  },
                )
                .toList(),
          );
    }

    final fullRecipeResponse = await client
        .from('recipes')
        .select('*, recipe_ingredients(*)')
        .eq('id', recipe.id)
        .single();

    return Recipe.fromMap(fullRecipeResponse);
  }

  Future<void> deleteRecipe(String recipeId) async {
    final client = _requireClient();
    await client.from('recipes').delete().eq('id', recipeId);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const RecipesConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class RecipesConfigException implements Exception {
  final String message;

  const RecipesConfigException(this.message);

  @override
  String toString() => message;
}
