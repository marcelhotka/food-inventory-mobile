import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../meal_plan/presentation/meal_plan_form_screen.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_match_result.dart';
import 'recipe_form_screen.dart';

enum RecipeFilter { all, favorites, publicOnly, householdOnly }

class RecipesScreen extends StatefulWidget {
  final Household household;
  final VoidCallback onShoppingListChanged;
  final VoidCallback onPantryChanged;
  final VoidCallback onMealPlanChanged;
  final int refreshToken;
  final String? focusedRecipeId;

  const RecipesScreen({
    super.key,
    required this.household,
    required this.onShoppingListChanged,
    required this.onPantryChanged,
    required this.onMealPlanChanged,
    required this.refreshToken,
    required this.focusedRecipeId,
  });

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final RecipesRepository _recipesRepository = RecipesRepository(
    householdId: widget.household.id,
  );
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );

  late Future<List<FoodItem>> _foodItemsFuture = _foodItemsRepository
      .getFoodItems();
  late Future<List<Recipe>> _recipesFuture = _recipesRepository.getRecipes();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  RecipeFilter _selectedFilter = RecipeFilter.all;
  String _searchQuery = '';
  Timer? _searchDebounce;

  Future<void> _reload() async {
    setState(() {
      _foodItemsFuture = _foodItemsRepository.getFoodItems();
      _recipesFuture = _recipesRepository.getRecipes();
    });
    await Future.wait([_foodItemsFuture, _recipesFuture]);
  }

  @override
  void didUpdateWidget(covariant RecipesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
    if (oldWidget.focusedRecipeId != widget.focusedRecipeId &&
        widget.focusedRecipeId != null) {
      _searchDebounce?.cancel();
      _searchController.clear();
      setState(() {
        _selectedFilter = RecipeFilter.all;
        _searchQuery = '';
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            onPressed: _openCreateRecipe,
            icon: const Icon(Icons.add),
            tooltip: 'Add recipe',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _RecipesSearchAndFilterBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              selectedFilter: _selectedFilter,
              onSearchChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                });
              },
              onFilterChanged: (value) {
                setState(() {
                  _selectedFilter = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Object>>(
              future: Future.wait<Object>([_foodItemsFuture, _recipesFuture]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState();
                }

                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'Failed to load recipes or pantry items.',
                    onRetry: _reload,
                  );
                }

                final data = snapshot.data ?? const <Object>[];
                final pantryItems = data.isNotEmpty
                    ? data[0] as List<FoodItem>
                    : <FoodItem>[];
                final recipes = data.length > 1
                    ? data[1] as List<Recipe>
                    : <Recipe>[];

                if (recipes.isEmpty) {
                  return AppEmptyState(
                    message: 'No recipes available yet.',
                    onRefresh: _reload,
                  );
                }

                final filteredRecipes = _applyRecipeFilters(recipes);
                if (filteredRecipes.isEmpty) {
                  return AppEmptyState(
                    message: 'No recipes match your search.',
                    onRefresh: _reload,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRecipes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recipe = filteredRecipes[index];
                      final result = _matchRecipe(recipe, pantryItems);
                      final isFocused = recipe.id == widget.focusedRecipeId;

                      return Card(
                        color: isFocused ? const Color(0xFFFFF8E8) : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isFocused
                                ? const Color(0xFFE0C36B)
                                : Colors.transparent,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      recipe.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _toggleFavorite(recipe),
                                    icon: Icon(
                                      recipe.isFavorite
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                    ),
                                    tooltip: recipe.isFavorite
                                        ? 'Remove from favorites'
                                        : 'Add to favorites',
                                  ),
                                  if (!recipe.isPublic)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openEditRecipe(recipe);
                                        } else if (value == 'delete') {
                                          _deleteRecipe(recipe);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(recipe.description),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SummaryChip(
                                    label:
                                        '${result.available.length} available',
                                    color: const Color(0xFFE5F0DF),
                                  ),
                                  _SummaryChip(
                                    label: '${result.partial.length} partial',
                                    color: const Color(0xFFF4EDC8),
                                  ),
                                  _SummaryChip(
                                    label: '${result.missing.length} missing',
                                    color: const Color(0xFFF6E2CC),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Available',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (result.available.isEmpty)
                                const Text(
                                  'Nothing from this recipe is fully available right now.',
                                )
                              else
                                ...result.available.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '• ${item.ingredient.name}: ${_formatQuantity(item.availableQuantityInRecipeUnit)} ${item.ingredient.unit} available',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Partially available',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (result.partial.isEmpty)
                                const Text(
                                  'Nothing is partially available right now.',
                                )
                              else
                                ...result.partial.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '• ${item.ingredient.name}: have ${_formatQuantity(item.availableQuantityInRecipeUnit)} ${item.ingredient.unit}, missing ${_formatQuantity(item.missingQuantityInRecipeUnit)} ${item.ingredient.unit}',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'Missing',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (result.missing.isEmpty)
                                const Text(
                                  'No ingredients are completely missing for this recipe.',
                                )
                              else
                                ...result.missing.map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '• ${item.ingredient.name} (${_formatQuantity(item.missingQuantityInRecipeUnit)} ${item.ingredient.unit})',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _addRecipeToMealPlan(recipe),
                                  child: const Text('Add to meal plan'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed:
                                      (result.missing.isEmpty &&
                                          result.partial.isEmpty)
                                      ? null
                                      : () => _addMissingToShoppingList(result),
                                  child: const Text(
                                    'Add missing to shopping list',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed:
                                      (result.available.isEmpty &&
                                          result.partial.isEmpty)
                                      ? null
                                      : () => _cookRecipe(result),
                                  child: const Text('Cook now'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed:
                                      (result.available.isEmpty &&
                                          result.partial.isEmpty)
                                      ? null
                                      : () => _useAvailableFromPantry(result),
                                  child: const Text(
                                    'Use available from pantry',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Recipe> _applyRecipeFilters(List<Recipe> recipes) {
    final filtered = recipes.where((recipe) {
      final matchesFilter = switch (_selectedFilter) {
        RecipeFilter.all => true,
        RecipeFilter.favorites => recipe.isFavorite,
        RecipeFilter.publicOnly => recipe.isPublic,
        RecipeFilter.householdOnly => !recipe.isPublic,
      };

      if (!matchesFilter) {
        return false;
      }

      if (_searchQuery.isEmpty) {
        return true;
      }

      final recipeName = recipe.name.toLowerCase();
      final recipeDescription = recipe.description.toLowerCase();
      return recipeName.contains(_searchQuery) ||
          recipeDescription.contains(_searchQuery);
    }).toList();

    final focusedRecipeId = widget.focusedRecipeId;
    if (focusedRecipeId == null) {
      return filtered;
    }

    filtered.sort((a, b) {
      if (a.id == focusedRecipeId) {
        return -1;
      }
      if (b.id == focusedRecipeId) {
        return 1;
      }
      return 0;
    });

    return filtered;
  }

  Future<void> _openCreateRecipe() async {
    final createdRecipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(householdId: widget.household.id),
      ),
    );

    if (createdRecipe == null) {
      return;
    }

    try {
      await _recipesRepository.addRecipe(createdRecipe);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Recipe added.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add recipe.');
    }
  }

  Future<void> _openEditRecipe(Recipe recipe) async {
    final updatedRecipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(
          householdId: widget.household.id,
          initialRecipe: recipe,
        ),
      ),
    );

    if (updatedRecipe == null) {
      return;
    }

    try {
      await _recipesRepository.editRecipe(updatedRecipe);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Recipe updated.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update recipe.');
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recipe'),
        content: Text('Do you want to delete "${recipe.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _recipesRepository.removeRecipe(recipe.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Recipe deleted.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to delete recipe.');
    }
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    try {
      await _recipesRepository.setRecipeFavorite(
        recipeId: recipe.id,
        isFavorite: !recipe.isFavorite,
      );
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        recipe.isFavorite
            ? 'Removed from favorite recipes.'
            : 'Added to favorite recipes.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update favorite recipe.');
    }
  }

  Future<void> _addRecipeToMealPlan(Recipe recipe) async {
    final allRecipes = await _recipesRepository.getRecipes();
    if (!mounted) {
      return;
    }

    final createdEntry = await Navigator.of(context).push<MealPlanEntry>(
      MaterialPageRoute(
        builder: (_) => MealPlanFormScreen(
          householdId: widget.household.id,
          recipes: allRecipes,
          prefilledRecipe: recipe,
        ),
      ),
    );

    if (createdEntry == null) {
      return;
    }

    try {
      await _mealPlanRepository.addEntry(createdEntry);
      widget.onMealPlanChanged();
      if (!mounted) return;
      showSuccessFeedback(context, 'Recipe added to meal plan.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add recipe to meal plan.');
    }
  }

  RecipeMatchResult _matchRecipe(Recipe recipe, List<FoodItem> pantryItems) {
    final available = <MatchedIngredient>[];
    final partial = <PartialIngredient>[];
    final missing = <MissingIngredient>[];

    for (final ingredient in recipe.ingredients) {
      final matchedItems = _findMatchedItems(ingredient.name, pantryItems);

      if (matchedItems.isEmpty) {
        missing.add(
          MissingIngredient(
            ingredient: ingredient,
            missingQuantityInRecipeUnit: ingredient.quantity,
          ),
        );
        continue;
      }

      final availableQuantity = _sumAvailableQuantity(ingredient, matchedItems);

      if (availableQuantity <= 0) {
        missing.add(
          MissingIngredient(
            ingredient: ingredient,
            missingQuantityInRecipeUnit: ingredient.quantity,
          ),
        );
      } else if (availableQuantity >= ingredient.quantity) {
        available.add(
          MatchedIngredient(
            ingredient: ingredient,
            matchedItems: matchedItems,
            availableQuantityInRecipeUnit: availableQuantity,
          ),
        );
      } else {
        partial.add(
          PartialIngredient(
            ingredient: ingredient,
            matchedItems: matchedItems,
            availableQuantityInRecipeUnit: availableQuantity,
            missingQuantityInRecipeUnit:
                ingredient.quantity - availableQuantity,
          ),
        );
      }
    }

    return RecipeMatchResult(
      recipe: recipe,
      available: available,
      partial: partial,
      missing: missing,
    );
  }

  double _sumAvailableQuantity(
    RecipeIngredient ingredient,
    List<FoodItem> matchedItems,
  ) {
    double sum = 0;
    for (final item in matchedItems) {
      final converted = _convertToIngredientUnit(
        quantity: item.quantity,
        fromUnit: item.unit,
        toUnit: ingredient.unit,
      );
      if (converted != null) {
        sum += converted;
      }
    }
    return sum;
  }

  double? _convertToIngredientUnit({
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

  bool _matchesIngredient(String ingredientName, String pantryName) {
    final ingredientNormalized = _normalize(ingredientName);
    final pantryNormalized = _normalize(pantryName);
    final ingredientKey = _canonicalIngredientKey(ingredientName);
    final pantryKey = _canonicalIngredientKey(pantryName);

    return ingredientNormalized == pantryNormalized ||
        ingredientKey == pantryKey;
  }

  List<FoodItem> _findMatchedItems(
    String ingredientName,
    List<FoodItem> pantryItems,
  ) {
    return pantryItems
        .where((item) => _matchesIngredient(ingredientName, item.name))
        .toList();
  }

  String _normalize(String value) {
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

    var normalized = value.toLowerCase();
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Set<String> _ingredientAliases(String value) {
    final normalized = _normalize(value);

    const aliasMap = {
      'eggs': {'eggs', 'egg', 'vajce', 'vajcia'},
      'milk': {'milk', 'mlieko'},
      'cheese': {'cheese', 'syr'},
      'pasta': {'pasta', 'cestoviny'},
      'tomatosauce': {
        'tomatosauce',
        'tomato',
        'paradajkovaomacka',
        'paradajky',
      },
      'chicken': {'chicken', 'kuracie', 'kuraciemaso', 'kura'},
      'rice': {'rice', 'ryza'},
      'onion': {'onion', 'cibula'},
      'bread': {'bread', 'chlieb', 'pecivo'},
      'ham': {'ham', 'sunka'},
    };

    for (final entry in aliasMap.entries) {
      if (entry.value.contains(normalized)) {
        return entry.value;
      }
    }

    return {normalized};
  }

  String _canonicalIngredientKey(String value) {
    final normalized = _normalize(value);
    final aliases = _ingredientAliases(value);

    const canonicalMap = {
      'eggs': 'eggs',
      'egg': 'eggs',
      'vajce': 'eggs',
      'vajcia': 'eggs',
      'milk': 'milk',
      'mlieko': 'milk',
      'cheese': 'cheese',
      'syr': 'cheese',
      'pasta': 'pasta',
      'cestoviny': 'pasta',
      'tomatosauce': 'tomatosauce',
      'tomato': 'tomatosauce',
      'paradajkovaomacka': 'tomatosauce',
      'paradajky': 'tomatosauce',
      'chicken': 'chicken',
      'kuracie': 'chicken',
      'kuraciemaso': 'chicken',
      'kura': 'chicken',
      'rice': 'rice',
      'ryza': 'rice',
      'onion': 'onion',
      'cibula': 'onion',
      'bread': 'bread',
      'chlieb': 'bread',
      'pecivo': 'bread',
      'ham': 'ham',
      'sunka': 'ham',
    };

    if (canonicalMap.containsKey(normalized)) {
      return canonicalMap[normalized]!;
    }

    for (final alias in aliases) {
      if (canonicalMap.containsKey(alias)) {
        return canonicalMap[alias]!;
      }
    }

    return normalized;
  }

  String _normalizeUnit(String value) {
    return value.trim().toLowerCase();
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  Future<void> _addMissingToShoppingList(RecipeMatchResult result) async {
    try {
      final freshResult = await _refreshRecipeMatch(result.recipe);
      final changedCount = await _addMissingToShoppingListInternal(freshResult);

      if (!mounted) return;
      if (changedCount == 0) {
        showSuccessFeedback(
          context,
          'Shopping list already matches this recipe.',
        );
      } else {
        widget.onShoppingListChanged();
        showSuccessFeedback(
          context,
          '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from recipe.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add missing items.');
    }
  }

  Future<void> _useAvailableFromPantry(RecipeMatchResult result) async {
    final freshResult = await _refreshRecipeMatch(result.recipe);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use ingredients from recipe'),
        content: Text(
          freshResult.partial.isEmpty
              ? 'This will deduct the recipe ingredients from your pantry.'
              : 'This will deduct only the available pantry ingredients. Missing parts stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use ingredients'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final changedCount = await _consumeAvailableFromPantry(freshResult);
      await _reload();
      widget.onPantryChanged();

      if (!mounted) return;
      if (changedCount == 0) {
        showErrorFeedback(context, 'No pantry quantities were updated.');
      } else {
        showSuccessFeedback(
          context,
          'Updated $changedCount pantry item${changedCount == 1 ? '' : 's'} from recipe.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update pantry from recipe.');
    }
  }

  Future<void> _cookRecipe(RecipeMatchResult result) async {
    final freshResult = await _refreshRecipeMatch(result.recipe);
    final canConsume =
        freshResult.available.isNotEmpty || freshResult.partial.isNotEmpty;
    if (!canConsume) {
      showErrorFeedback(context, 'Nothing from this recipe can be cooked yet.');
      return;
    }

    final canAddMissing =
        freshResult.missing.isNotEmpty || freshResult.partial.isNotEmpty;
    var addMissingToShopping = canAddMissing;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Cook ${freshResult.recipe.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will deduct the available ingredients from your pantry.',
              ),
              if (canAddMissing) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: addMissingToShopping,
                  onChanged: (value) {
                    setState(() {
                      addMissingToShopping = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Add missing ingredients to shopping list'),
                  subtitle: const Text(
                    'Useful if you want to finish the recipe later.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cook now'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final pantryChangedCount = await _consumeAvailableFromPantry(freshResult);
      var shoppingChangedCount = 0;

      if (addMissingToShopping) {
        shoppingChangedCount = await _addMissingToShoppingListInternal(
          freshResult,
        );
      }

      await _reload();
      widget.onPantryChanged();
      if (shoppingChangedCount > 0) {
        widget.onShoppingListChanged();
      }

      if (!mounted) return;
      final parts = <String>[];
      if (pantryChangedCount > 0) {
        parts.add(
          'used $pantryChangedCount pantry item${pantryChangedCount == 1 ? '' : 's'}',
        );
      }
      if (shoppingChangedCount > 0) {
        parts.add(
          'updated $shoppingChangedCount shopping item${shoppingChangedCount == 1 ? '' : 's'}',
        );
      }

      showSuccessFeedback(
        context,
        parts.isEmpty
            ? 'Recipe flow completed.'
            : 'Cooked recipe and ${parts.join(', ')}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to cook recipe.');
    }
  }

  Future<int> _consumeAvailableFromPantry(RecipeMatchResult result) async {
    final pantryEntries = <_PantryConsumptionEntry>[
      ...result.available.map(
        (item) => _PantryConsumptionEntry(
          ingredient: item.ingredient,
          matchedItems: item.matchedItems,
          quantityToConsumeInRecipeUnit: item.ingredient.quantity,
        ),
      ),
      ...result.partial.map(
        (item) => _PantryConsumptionEntry(
          ingredient: item.ingredient,
          matchedItems: item.matchedItems,
          quantityToConsumeInRecipeUnit: item.availableQuantityInRecipeUnit,
        ),
      ),
    ].where((entry) => entry.quantityToConsumeInRecipeUnit > 0).toList();

    if (pantryEntries.isEmpty) {
      return 0;
    }

    final pantryState = <String, FoodItem>{
      for (final entry in pantryEntries)
        for (final item in entry.matchedItems) item.id: item,
    };

    int changedCount = 0;

    for (final entry in pantryEntries) {
      changedCount += await _consumeAcrossMatchedItems(
        pantryState: pantryState,
        ingredient: entry.ingredient,
        matchedItems: entry.matchedItems,
        quantityToConsumeInRecipeUnit: entry.quantityToConsumeInRecipeUnit,
      );
    }

    return changedCount;
  }

  Future<RecipeMatchResult> _refreshRecipeMatch(Recipe recipe) async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    return _matchRecipe(recipe, pantryItems);
  }

  Future<int> _addMissingToShoppingListInternal(
    RecipeMatchResult result,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final existingItems = await _shoppingListRepository.getShoppingListItems();
    int changedCount = 0;

    for (final missing in result.missing) {
      final ingredient = missing.ingredient;
      changedCount += await _upsertShoppingNeed(
        userId: user.id,
        existingItems: existingItems,
        ingredientName: ingredient.name,
        quantity: missing.missingQuantityInRecipeUnit,
        unit: ingredient.unit,
      );
    }

    for (final partial in result.partial) {
      final ingredient = partial.ingredient;
      changedCount += await _upsertShoppingNeed(
        userId: user.id,
        existingItems: existingItems,
        ingredientName: ingredient.name,
        quantity: partial.missingQuantityInRecipeUnit,
        unit: ingredient.unit,
      );
    }

    return changedCount;
  }

  Future<int> _consumeAcrossMatchedItems({
    required Map<String, FoodItem> pantryState,
    required RecipeIngredient ingredient,
    required List<FoodItem> matchedItems,
    required double quantityToConsumeInRecipeUnit,
  }) async {
    var remaining = quantityToConsumeInRecipeUnit;
    var changedCount = 0;
    final now = DateTime.now().toUtc();

    final sortedItems = [...matchedItems]
      ..sort((a, b) {
        final priorityComparison = _consumptionPriority(
          ingredient.name,
          a,
        ).compareTo(_consumptionPriority(ingredient.name, b));
        if (priorityComparison != 0) {
          return priorityComparison;
        }

        final aExpiry = a.expirationDate;
        final bExpiry = b.expirationDate;
        if (aExpiry == null && bExpiry == null) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (aExpiry == null) {
          return 1;
        }
        if (bExpiry == null) {
          return -1;
        }
        return aExpiry.compareTo(bExpiry);
      });

    for (final originalItem in sortedItems) {
      if (remaining <= 0.0001) {
        break;
      }

      final currentItem = pantryState[originalItem.id];
      if (currentItem == null) {
        continue;
      }

      final availableInRecipeUnit = _convertToIngredientUnit(
        quantity: currentItem.quantity,
        fromUnit: currentItem.unit,
        toUnit: ingredient.unit,
      );

      if (availableInRecipeUnit == null || availableInRecipeUnit <= 0) {
        continue;
      }

      final toConsumeInRecipeUnit = remaining < availableInRecipeUnit
          ? remaining
          : availableInRecipeUnit;

      final toConsumeInItemUnit = _convertToIngredientUnit(
        quantity: toConsumeInRecipeUnit,
        fromUnit: ingredient.unit,
        toUnit: currentItem.unit,
      );

      if (toConsumeInItemUnit == null || toConsumeInItemUnit <= 0) {
        continue;
      }

      final nextQuantity = (currentItem.quantity - toConsumeInItemUnit)
          .clamp(0.0, double.infinity)
          .toDouble();

      if (nextQuantity <= 0.0001) {
        await _foodItemsRepository.removeFoodItem(currentItem.id);
        pantryState.remove(currentItem.id);
      } else {
        final updatedItem = currentItem.copyWith(
          quantity: nextQuantity,
          updatedAt: now,
        );
        final persisted = await _foodItemsRepository.editFoodItem(updatedItem);
        pantryState[currentItem.id] = persisted;
      }

      changedCount++;
      remaining -= toConsumeInRecipeUnit;
    }

    return changedCount;
  }

  int _consumptionPriority(String ingredientName, FoodItem item) {
    final ingredientNormalized = _normalize(ingredientName);
    final itemNormalized = _normalize(item.name);
    if (ingredientNormalized == itemNormalized) {
      return 0;
    }

    final ingredientKey = _canonicalIngredientKey(ingredientName);
    final itemKey = _canonicalIngredientKey(item.name);
    if (ingredientKey == itemKey) {
      return 1;
    }

    return switch (item.storageLocation.trim().toLowerCase()) {
      'fridge' => 2,
      'pantry' => 3,
      'freezer' => 4,
      _ => 5,
    };
  }

  Future<int> _upsertShoppingNeed({
    required String userId,
    required List<ShoppingListItem> existingItems,
    required String ingredientName,
    required double quantity,
    required String unit,
  }) async {
    final normalizedKey =
        '${_canonicalIngredientKey(ingredientName)}|${_normalizeUnit(unit)}';
    final matchingItems = existingItems
        .where(
          (item) =>
              '${_canonicalIngredientKey(item.name)}|${_normalizeUnit(item.unit)}' ==
              normalizedKey,
        )
        .toList();
    final now = DateTime.now().toUtc();

    if (matchingItems.isEmpty) {
      final created = await _shoppingListRepository.addShoppingListItem(
        ShoppingListItem(
          id: '',
          userId: userId,
          householdId: widget.household.id,
          name: ingredientName,
          quantity: quantity,
          unit: unit,
          source: ShoppingListItem.sourceRecipeMissing,
          isBought: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      existingItems.add(created);
      return 1;
    }

    final existing = matchingItems.first;
    final mergedSource = ShoppingListItem.mergeSource(
      existing.source,
      ShoppingListItem.sourceRecipeMissing,
    );
    var mergedQuantity = existing.quantity > quantity
        ? existing.quantity
        : quantity;

    for (final duplicate in matchingItems.skip(1)) {
      if (duplicate.quantity > mergedQuantity) {
        mergedQuantity = duplicate.quantity;
      }
    }

    if (existing.quantity == mergedQuantity &&
        _normalizeUnit(existing.unit) == _normalizeUnit(unit) &&
        existing.isBought == false &&
        existing.source == mergedSource &&
        matchingItems.length == 1) {
      return 0;
    }

    final updated = existing.copyWith(
      name: ingredientName,
      quantity: mergedQuantity,
      unit: unit,
      source: mergedSource,
      isBought: false,
      updatedAt: now,
    );
    await _shoppingListRepository.editShoppingListItem(updated);

    for (final duplicate in matchingItems.skip(1)) {
      await _shoppingListRepository.removeShoppingListItem(duplicate.id);
      existingItems.removeWhere((item) => item.id == duplicate.id);
    }

    existingItems.removeWhere((item) => item.id == updated.id);
    existingItems.add(updated);
    return 1;
  }
}

class _PantryConsumptionEntry {
  final RecipeIngredient ingredient;
  final List<FoodItem> matchedItems;
  final double quantityToConsumeInRecipeUnit;

  const _PantryConsumptionEntry({
    required this.ingredient,
    required this.matchedItems,
    required this.quantityToConsumeInRecipeUnit,
  });
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _RecipesSearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final RecipeFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<RecipeFilter> onFilterChanged;

  const _RecipesSearchAndFilterBar({
    required this.controller,
    required this.focusNode,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search recipes',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selectedFilter == RecipeFilter.all,
                  onSelected: (_) => onFilterChanged(RecipeFilter.all),
                ),
                FilterChip(
                  label: const Text('Favorites'),
                  selected: selectedFilter == RecipeFilter.favorites,
                  onSelected: (_) => onFilterChanged(RecipeFilter.favorites),
                ),
                FilterChip(
                  label: const Text('Public'),
                  selected: selectedFilter == RecipeFilter.publicOnly,
                  onSelected: (_) => onFilterChanged(RecipeFilter.publicOnly),
                ),
                FilterChip(
                  label: const Text('Household'),
                  selected: selectedFilter == RecipeFilter.householdOnly,
                  onSelected: (_) =>
                      onFilterChanged(RecipeFilter.householdOnly),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
