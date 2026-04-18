import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
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
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';
import '../domain/recipe_match_result.dart';
import '../domain/recipe_nutrition_estimate.dart';
import 'recipe_display_text.dart';
import 'recipe_form_screen.dart';

enum RecipeFilter {
  all,
  under15Minutes,
  under30Minutes,
  under45Minutes,
  safeForMe,
  favorites,
  publicOnly,
  householdOnly,
}

class RecipesScreen extends StatefulWidget {
  final Household household;
  final VoidCallback onShoppingListChanged;
  final VoidCallback onPantryChanged;
  final VoidCallback onMealPlanChanged;
  final int refreshToken;
  final String? focusedRecipeId;
  final RecipeFilter initialFilter;

  const RecipesScreen({
    super.key,
    required this.household,
    required this.onShoppingListChanged,
    required this.onPantryChanged,
    required this.onMealPlanChanged,
    required this.refreshToken,
    required this.focusedRecipeId,
    required this.initialFilter,
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
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();

  late Future<_RecipesViewData> _recipesViewFuture = _loadRecipesViewData();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  RecipeFilter _selectedFilter = RecipeFilter.all;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _presentedFocusedRecipeId;
  final Map<String, int> _selectedServingsByRecipeId = {};

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  Future<void> _reload() async {
    setState(() {
      _recipesViewFuture = _loadRecipesViewData();
    });
    await _recipesViewFuture;
  }

  Future<_RecipesViewData> _loadRecipesViewData() async {
    final pantryFuture = _foodItemsRepository.getFoodItems();
    final recipesFuture = _recipesRepository.getRecipes();
    UserPreferences? preferences;

    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }

    final results = await Future.wait<Object>([pantryFuture, recipesFuture]);
    return _RecipesViewData(
      pantryItems: results[0] as List<FoodItem>,
      recipes: results[1] as List<Recipe>,
      preferences: preferences,
    );
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
      _presentedFocusedRecipeId = null;
      setState(() {
        _selectedFilter = RecipeFilter.all;
        _searchQuery = '';
      });
    }
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _selectedFilter = widget.initialFilter;
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

  int _selectedServingsFor(Recipe recipe) {
    return _selectedServingsByRecipeId[recipe.id] ?? recipe.defaultServings;
  }

  Future<void> _selectServings(Recipe recipe) async {
    final controller = TextEditingController(
      text: _selectedServingsFor(recipe).toString(),
    );
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              context.tr(
                en: 'Servings for ${localizedRecipeName(context, recipe)}',
                sk: 'Porcie pre ${localizedRecipeName(context, recipe)}',
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr(
                  en: 'Number of servings',
                  sk: 'Počet porcií',
                ),
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
              ),
              FilledButton(
                onPressed: () {
                  final parsed = int.tryParse(controller.text.trim());
                  if (parsed == null || parsed <= 0) {
                    setDialogState(() {
                      errorText = context.tr(
                        en: 'Enter a valid number',
                        sk: 'Zadaj platné číslo',
                      );
                    });
                    return;
                  }
                  Navigator.pop(context, parsed);
                },
                child: Text(context.tr(en: 'Apply', sk: 'Použiť')),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedServingsByRecipeId[recipe.id] = selected;
      if (widget.focusedRecipeId == recipe.id) {
        _presentedFocusedRecipeId = null;
      }
    });

    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Servings updated. Ingredients and nutrition were recalculated.',
        sk: 'Porcie sú upravené. Suroviny aj nutričné hodnoty sa prepočítali.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Recipes', sk: 'Recepty')),
        actions: [
          IconButton(
            onPressed: _openCreateRecipe,
            icon: const Icon(Icons.add),
            tooltip: context.tr(en: 'Add recipe', sk: 'Pridať recept'),
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
            child: FutureBuilder<_RecipesViewData>(
              future: _recipesViewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingState();
                }

                if (snapshot.hasError) {
                  return AppErrorState(
                    message: context.tr(
                      en: 'Failed to load recipes or pantry items.',
                      sk: 'Recepty alebo pantry položky sa nepodarilo načítať.',
                    ),
                    onRetry: _reload,
                  );
                }

                final viewData =
                    snapshot.data ??
                    const _RecipesViewData(
                      pantryItems: <FoodItem>[],
                      recipes: <Recipe>[],
                      preferences: null,
                    );
                final pantryItems = viewData.pantryItems;
                final recipes = viewData.recipes;
                final preferences = viewData.preferences;

                if (recipes.isEmpty) {
                  return AppEmptyState(
                    message: context.tr(
                      en: 'No recipes available yet.',
                      sk: 'Zatiaľ nemáš dostupné žiadne recepty.',
                    ),
                    onRefresh: _reload,
                  );
                }

                final filteredRecipes = _applyRecipeFilters(
                  recipes,
                  pantryItems,
                  preferences,
                );
                if (filteredRecipes.isEmpty) {
                  return AppEmptyState(
                    message: context.tr(
                      en: 'No recipes match your search.',
                      sk: 'Tvojmu hľadaniu nezodpovedajú žiadne recepty.',
                    ),
                    onRefresh: _reload,
                  );
                }

                Recipe? focusedRecipe;
                final focusedRecipeId = widget.focusedRecipeId;
                if (focusedRecipeId != null) {
                  for (final recipe in filteredRecipes) {
                    if (recipe.id == focusedRecipeId) {
                      focusedRecipe = recipe;
                      break;
                    }
                  }
                }
                if (focusedRecipe != null &&
                    _presentedFocusedRecipeId != focusedRecipe.id) {
                  final selectedRecipe = focusedRecipe;
                  final selectedServings = _selectedServingsFor(selectedRecipe);
                  final focusedResult = _matchRecipe(
                    selectedRecipe,
                    pantryItems,
                    servings: selectedServings,
                  );
                  final focusedWarning = _buildRecipeSafetyWarning(
                    selectedRecipe,
                    preferences,
                  );
                  final focusedNutrition = estimateRecipeNutrition(
                    selectedRecipe,
                    servings: selectedServings,
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    _presentedFocusedRecipeId = selectedRecipe.id;
                    _showFocusedRecipeSheet(
                      selectedRecipe,
                      focusedResult,
                      focusedWarning,
                      focusedNutrition,
                    );
                  });
                }

                final quickCookingMinutes = _quickCookingMinutesForFilter(
                  _selectedFilter,
                );
                final showQuickCookingMode = quickCookingMinutes != null;
                final quickCookingSafeCount = showQuickCookingMode
                    ? filteredRecipes
                          .where(
                            (recipe) =>
                                _buildRecipeSafetyWarning(
                                  recipe,
                                  preferences,
                                ) ==
                                null,
                          )
                          .length
                    : 0;
                final quickCookingReadyCount = showQuickCookingMode
                    ? filteredRecipes.where((recipe) {
                        final result = _matchRecipe(
                          recipe,
                          pantryItems,
                          servings: _selectedServingsFor(recipe),
                        );
                        return result.missing.isEmpty &&
                            result.partial.isEmpty &&
                            _buildRecipeSafetyWarning(recipe, preferences) ==
                                null;
                      }).length
                    : 0;
                final leadingItemCount = showQuickCookingMode ? 1 : 0;

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRecipes.length + leadingItemCount,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (showQuickCookingMode && index == 0) {
                        return _QuickCookingModeCard(
                          minutes: quickCookingMinutes,
                          recipeCount: filteredRecipes.length,
                          safeCount: quickCookingSafeCount,
                          readyCount: quickCookingReadyCount,
                        );
                      }

                      final recipe = filteredRecipes[index - leadingItemCount];
                      final selectedServings = _selectedServingsFor(recipe);
                      final result = _matchRecipe(
                        recipe,
                        pantryItems,
                        servings: selectedServings,
                      );
                      final warning = _buildRecipeSafetyWarning(
                        recipe,
                        preferences,
                      );
                      final nutrition = estimateRecipeNutrition(
                        recipe,
                        servings: selectedServings,
                      );
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
                                      localizedRecipeName(context, recipe),
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
                                        ? context.tr(
                                            en: 'Remove from favorites',
                                            sk: 'Odstrániť z obľúbených',
                                          )
                                        : context.tr(
                                            en: 'Add to favorites',
                                            sk: 'Pridať do obľúbených',
                                          ),
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
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text(
                                            context.tr(
                                              en: 'Edit',
                                              sk: 'Upraviť',
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            context.tr(
                                              en: 'Delete',
                                              sk: 'Zmazať',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SummaryChip(
                                    label: '${recipe.totalMinutes} min',
                                    color: const Color(0xFFE8EEF8),
                                  ),
                                  _SummaryChip(
                                    label:
                                        '${context.tr(en: 'Base', sk: 'Základ')}: ${recipe.defaultServings} ${context.tr(en: recipe.defaultServings == 1 ? 'serving' : 'servings', sk: recipe.defaultServings == 1 ? 'porcia' : 'porcie')}',
                                    color: const Color(0xFFEDE8F8),
                                  ),
                                  ActionChip(
                                    label: Text(
                                      '${context.tr(en: 'For', sk: 'Pre')} $selectedServings ${context.tr(en: selectedServings == 1 ? 'serving' : 'servings', sk: selectedServings == 1 ? 'porciu' : 'porcie')}',
                                    ),
                                    onPressed: () => _selectServings(recipe),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(localizedRecipeDescription(context, recipe)),
                              const SizedBox(height: 12),
                              _RecipeNutritionSummary(nutrition: nutrition),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SummaryChip(
                                    label:
                                        '${result.available.length} ${context.tr(en: 'available', sk: 'dostupné')}',
                                    color: const Color(0xFFE5F0DF),
                                  ),
                                  _SummaryChip(
                                    label:
                                        '${result.partial.length} ${context.tr(en: 'partial', sk: 'čiastočne')}',
                                    color: const Color(0xFFF4EDC8),
                                  ),
                                  _SummaryChip(
                                    label:
                                        '${result.missing.length} ${context.tr(en: 'missing', sk: 'chýba')}',
                                    color: const Color(0xFFF6E2CC),
                                  ),
                                ],
                              ),
                              if (warning != null) ...[
                                const SizedBox(height: 12),
                                _RecipeSafetyBadge(warning: warning),
                              ],
                              const SizedBox(height: 16),
                              _RecipeIngredientAvailabilitySections(
                                result: result,
                                displayIngredientName: _displayIngredientName,
                                formatQuantity: _formatQuantity,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => _addRecipeToMealPlan(recipe),
                                  child: Text(
                                    context.tr(
                                      en: 'Add to meal plan',
                                      sk: 'Pridať do jedálnička',
                                    ),
                                  ),
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
                                  child: Text(
                                    context.tr(
                                      en: 'Add missing to shopping list',
                                      sk: 'Pridať chýbajúce do nákupného zoznamu',
                                    ),
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
                                  child: Text(
                                    context.tr(
                                      en: 'Cook now',
                                      sk: 'Variť teraz',
                                    ),
                                  ),
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
                                  child: Text(
                                    context.tr(
                                      en: 'Use available from pantry',
                                      sk: 'Použiť dostupné zo špajze',
                                    ),
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

  Future<void> _showFocusedRecipeSheet(
    Recipe recipe,
    RecipeMatchResult result,
    _FoodSafetyWarning? warning,
    RecipeNutritionEstimate nutrition,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizedRecipeName(context, recipe),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      label: '${recipe.totalMinutes} min',
                      color: const Color(0xFFE8EEF8),
                    ),
                    _SummaryChip(
                      label:
                          '${context.tr(en: 'Base', sk: 'Základ')}: ${recipe.defaultServings} ${context.tr(en: recipe.defaultServings == 1 ? 'serving' : 'servings', sk: recipe.defaultServings == 1 ? 'porcia' : 'porcie')}',
                      color: const Color(0xFFEDE8F8),
                    ),
                    ActionChip(
                      label: Text(
                        '${context.tr(en: 'For', sk: 'Pre')} ${result.selectedServings} ${context.tr(en: result.selectedServings == 1 ? 'serving' : 'servings', sk: result.selectedServings == 1 ? 'porciu' : 'porcie')}',
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _selectServings(recipe);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(localizedRecipeDescription(context, recipe)),
                const SizedBox(height: 12),
                _RecipeNutritionSummary(nutrition: nutrition),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      label:
                          '${result.available.length} ${context.tr(en: 'available', sk: 'dostupné')}',
                      color: const Color(0xFFE5F0DF),
                    ),
                    _SummaryChip(
                      label:
                          '${result.partial.length} ${context.tr(en: 'partial', sk: 'čiastočne')}',
                      color: const Color(0xFFF4EDC8),
                    ),
                    _SummaryChip(
                      label:
                          '${result.missing.length} ${context.tr(en: 'missing', sk: 'chýba')}',
                      color: const Color(0xFFF6E2CC),
                    ),
                  ],
                ),
                if (warning != null) ...[
                  const SizedBox(height: 12),
                  _RecipeSafetyBadge(warning: warning),
                ],
                const SizedBox(height: 20),
                _RecipeIngredientAvailabilitySections(
                  result: result,
                  displayIngredientName: _displayIngredientName,
                  formatQuantity: _formatQuantity,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _addRecipeToMealPlan(recipe);
                    },
                    child: Text(
                      context.tr(
                        en: 'Add to meal plan',
                        sk: 'Pridať do jedálnička',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        (result.available.isEmpty && result.partial.isEmpty)
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _cookRecipe(result);
                          },
                    child: Text(context.tr(en: 'Cook now', sk: 'Variť teraz')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed:
                        (result.missing.isEmpty && result.partial.isEmpty)
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _addMissingToShoppingList(result);
                          },
                    child: Text(
                      context.tr(
                        en: 'Add missing to shopping list',
                        sk: 'Pridať chýbajúce do nákupného zoznamu',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Recipe> _applyRecipeFilters(
    List<Recipe> recipes,
    List<FoodItem> pantryItems,
    UserPreferences? preferences,
  ) {
    final filtered = recipes.where((recipe) {
      final warning = _buildRecipeSafetyWarning(recipe, preferences);
      final matchesFilter = switch (_selectedFilter) {
        RecipeFilter.all => true,
        RecipeFilter.under15Minutes => recipe.totalMinutes <= 15,
        RecipeFilter.under30Minutes => recipe.totalMinutes <= 30,
        RecipeFilter.under45Minutes => recipe.totalMinutes <= 45,
        RecipeFilter.safeForMe => warning == null,
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

    if (_quickCookingMinutesForFilter(_selectedFilter) != null) {
      final focusedRecipeId = widget.focusedRecipeId;
      filtered.sort((a, b) {
        if (a.id == focusedRecipeId) {
          return -1;
        }
        if (b.id == focusedRecipeId) {
          return 1;
        }

        final aWarning = _buildRecipeSafetyWarning(a, preferences);
        final bWarning = _buildRecipeSafetyWarning(b, preferences);
        if (aWarning == null && bWarning != null) {
          return -1;
        }
        if (aWarning != null && bWarning == null) {
          return 1;
        }

        final aResult = _matchRecipe(
          a,
          pantryItems,
          servings: _selectedServingsFor(a),
        );
        final bResult = _matchRecipe(
          b,
          pantryItems,
          servings: _selectedServingsFor(b),
        );
        final aMissingScore = aResult.missing.length + aResult.partial.length;
        final bMissingScore = bResult.missing.length + bResult.partial.length;
        if (aMissingScore != bMissingScore) {
          return aMissingScore.compareTo(bMissingScore);
        }

        if (aResult.available.length != bResult.available.length) {
          return bResult.available.length.compareTo(aResult.available.length);
        }

        return a.totalMinutes.compareTo(b.totalMinutes);
      });

      return filtered;
    }

    filtered.sort((a, b) {
      final aWarning = _buildRecipeSafetyWarning(a, preferences);
      final bWarning = _buildRecipeSafetyWarning(b, preferences);
      if (aWarning == null && bWarning != null) {
        return -1;
      }
      if (aWarning != null && bWarning == null) {
        return 1;
      }

      final focusedRecipeId = widget.focusedRecipeId;
      if (focusedRecipeId == null) {
        return 0;
      }

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

  int? _quickCookingMinutesForFilter(RecipeFilter filter) {
    return switch (filter) {
      RecipeFilter.under15Minutes => 15,
      RecipeFilter.under30Minutes => 30,
      RecipeFilter.under45Minutes => 45,
      _ => null,
    };
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
      showSuccessFeedback(
        context,
        context.tr(en: 'Recipe added.', sk: 'Recept bol pridaný.'),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add recipe.',
          sk: 'Recept sa nepodarilo pridať.',
        ),
      );
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
      showSuccessFeedback(
        context,
        context.tr(en: 'Recipe updated.', sk: 'Recept bol upravený.'),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update recipe.',
          sk: 'Recept sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _deleteRecipe(Recipe recipe) async {
    final useConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(en: 'Delete recipe', sk: 'Zmazať recept')),
        content: Text(
          context.tr(
            en: 'Do you want to delete "${localizedRecipeName(context, recipe)}"?',
            sk: 'Chceš zmazať recept "${localizedRecipeName(context, recipe)}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Delete', sk: 'Zmazať')),
          ),
        ],
      ),
    );

    if (useConfirmed != true) {
      return;
    }

    try {
      await _recipesRepository.removeRecipe(recipe.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(en: 'Recipe deleted.', sk: 'Recept bol zmazaný.'),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to delete recipe.',
          sk: 'Recept sa nepodarilo zmazať.',
        ),
      );
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
            ? context.tr(
                en: 'Removed from favorite recipes.',
                sk: 'Odstránené z obľúbených receptov.',
              )
            : context.tr(
                en: 'Added to favorite recipes.',
                sk: 'Pridané medzi obľúbené recepty.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update favorite recipe.',
          sk: 'Obľúbený recept sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _addRecipeToMealPlan(Recipe recipe) async {
    final confirmed = await _confirmProceedWithSafetyWarning(
      recipe: recipe,
      preferences: null,
      actionLabel: context.tr(
        en: 'add this recipe to your meal plan',
        sk: 'pridať tento recept do jedálnička',
      ),
    );
    if (!confirmed) {
      return;
    }

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
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Recipe added to meal plan.',
          sk: 'Recept bol pridaný do jedálnička.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add recipe to meal plan.',
          sk: 'Recept sa nepodarilo pridať do jedálnička.',
        ),
      );
    }
  }

  RecipeMatchResult _matchRecipe(
    Recipe recipe,
    List<FoodItem> pantryItems, {
    required int servings,
  }) {
    final available = <MatchedIngredient>[];
    final partial = <PartialIngredient>[];
    final missing = <MissingIngredient>[];
    final scaleFactor = servings / recipe.defaultServings;

    for (final ingredient in recipe.ingredients) {
      final requiredQuantity = ingredient.quantity * scaleFactor;
      final matchedItems = _findMatchedItems(ingredient.name, pantryItems);

      if (matchedItems.isEmpty) {
        missing.add(
          MissingIngredient(
            ingredient: ingredient,
            requiredQuantityInRecipeUnit: requiredQuantity,
            missingQuantityInRecipeUnit: requiredQuantity,
          ),
        );
        continue;
      }

      final availableQuantity = _sumAvailableQuantity(ingredient, matchedItems);

      if (availableQuantity <= 0) {
        missing.add(
          MissingIngredient(
            ingredient: ingredient,
            requiredQuantityInRecipeUnit: requiredQuantity,
            missingQuantityInRecipeUnit: requiredQuantity,
          ),
        );
      } else if (availableQuantity >= requiredQuantity) {
        available.add(
          MatchedIngredient(
            ingredient: ingredient,
            matchedItems: matchedItems,
            requiredQuantityInRecipeUnit: requiredQuantity,
            availableQuantityInRecipeUnit: availableQuantity,
          ),
        );
      } else {
        partial.add(
          PartialIngredient(
            ingredient: ingredient,
            matchedItems: matchedItems,
            requiredQuantityInRecipeUnit: requiredQuantity,
            availableQuantityInRecipeUnit: availableQuantity,
            missingQuantityInRecipeUnit: requiredQuantity - availableQuantity,
          ),
        );
      }
    }

    return RecipeMatchResult(
      recipe: recipe,
      selectedServings: servings,
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

  String _displayIngredientName(String value) {
    final key = _canonicalIngredientKey(value);
    return switch (key) {
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      'milk' => context.tr(en: 'Milk', sk: 'Mlieko'),
      'cheese' => context.tr(en: 'Cheese', sk: 'Syr'),
      'pasta' => context.tr(en: 'Pasta', sk: 'Cestoviny'),
      'tomatosauce' => context.tr(en: 'Tomato sauce', sk: 'Paradajková omáčka'),
      'chicken' => context.tr(en: 'Chicken', sk: 'Kuracie mäso'),
      'rice' => context.tr(en: 'Rice', sk: 'Ryža'),
      'onion' => context.tr(en: 'Onion', sk: 'Cibuľa'),
      'bread' => context.tr(en: 'Bread', sk: 'Chlieb'),
      'ham' => context.tr(en: 'Ham', sk: 'Šunka'),
      _ => value,
    };
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
    final confirmed = await _confirmProceedWithSafetyWarning(
      recipe: result.recipe,
      preferences: null,
      actionLabel: context.tr(
        en: 'add missing ingredients to your shopping list',
        sk: 'pridať chýbajúce suroviny do nákupného zoznamu',
      ),
    );
    if (!confirmed) {
      return;
    }

    try {
      final freshResult = await _refreshRecipeMatch(result.recipe);
      final changedCount = await _addMissingToShoppingListInternal(freshResult);

      if (!mounted) return;
      if (changedCount == 0) {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Shopping list already matches this recipe.',
            sk: 'Nákupný zoznam už zodpovedá tomuto receptu.',
          ),
        );
      } else {
        widget.onShoppingListChanged();
        showSuccessFeedback(
          context,
          context.tr(
            en: '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from recipe.',
            sk: 'Z receptu sa upravilo $changedCount nákupn${changedCount == 1 ? 'á položka' : 'é položky'}.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add missing items.',
          sk: 'Chýbajúce položky sa nepodarilo pridať.',
        ),
      );
    }
  }

  Future<void> _useAvailableFromPantry(RecipeMatchResult result) async {
    final confirmed = await _confirmProceedWithSafetyWarning(
      recipe: result.recipe,
      preferences: null,
      actionLabel: context.tr(
        en: 'use ingredients from your pantry',
        sk: 'použiť suroviny z tvojej špajze',
      ),
    );
    if (!confirmed) {
      return;
    }

    final freshResult = await _refreshRecipeMatch(result.recipe);

    final useConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(
            en: 'Use ingredients from recipe',
            sk: 'Použiť suroviny z receptu',
          ),
        ),
        content: Text(
          freshResult.partial.isEmpty
              ? context.tr(
                  en: 'This will deduct the recipe ingredients from your pantry.',
                  sk: 'Týmto sa odrátajú suroviny receptu z tvojej špajze.',
                )
              : context.tr(
                  en: 'This will deduct only the available pantry ingredients. Missing parts stay unchanged.',
                  sk: 'Týmto sa odrátajú len dostupné suroviny zo špajze. Chýbajúce časti ostanú nezmenené.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr(en: 'Use ingredients', sk: 'Použiť suroviny'),
            ),
          ),
        ],
      ),
    );

    if (useConfirmed != true) {
      return;
    }

    try {
      final changedCount = await _consumeAvailableFromPantry(freshResult);
      await _reload();
      widget.onPantryChanged();

      if (!mounted) return;
      if (changedCount == 0) {
        showErrorFeedback(
          context,
          context.tr(
            en: 'No pantry quantities were updated.',
            sk: 'Žiadne množstvá v špajzi sa neupravili.',
          ),
        );
      } else {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Updated $changedCount pantry item${changedCount == 1 ? '' : 's'} from recipe.',
            sk: 'Z receptu sa upravilo $changedCount položk${changedCount == 1 ? 'a' : 'y'} v špajzi.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update pantry from recipe.',
          sk: 'Špajzu sa nepodarilo upraviť podľa receptu.',
        ),
      );
    }
  }

  Future<void> _cookRecipe(RecipeMatchResult result) async {
    final confirmed = await _confirmProceedWithSafetyWarning(
      recipe: result.recipe,
      preferences: null,
      actionLabel: context.tr(en: 'cook this recipe', sk: 'variť tento recept'),
    );
    if (!confirmed) {
      return;
    }

    final freshResult = await _refreshRecipeMatch(result.recipe);
    final canConsume =
        freshResult.available.isNotEmpty || freshResult.partial.isNotEmpty;
    if (!canConsume) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'Nothing from this recipe can be cooked yet.',
          sk: 'Z tohto receptu sa zatiaľ nedá nič uvariť.',
        ),
      );
      return;
    }

    final canAddMissing =
        freshResult.missing.isNotEmpty || freshResult.partial.isNotEmpty;
    var addMissingToShopping = canAddMissing;

    final cookConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            context.tr(
              en: 'Cook ${localizedRecipeName(context, freshResult.recipe)}',
              sk: 'Variť ${localizedRecipeName(context, freshResult.recipe)}',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  en: 'This will deduct the available ingredients from your pantry.',
                  sk: 'Týmto sa odrátajú dostupné suroviny z tvojej špajze.',
                ),
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
                  title: Text(
                    context.tr(
                      en: 'Add missing ingredients to shopping list',
                      sk: 'Pridať chýbajúce suroviny do nákupného zoznamu',
                    ),
                  ),
                  subtitle: Text(
                    context.tr(
                      en: 'Useful if you want to finish the recipe later.',
                      sk: 'Užitočné, ak chceš recept dokončiť neskôr.',
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr(en: 'Cook now', sk: 'Variť teraz')),
            ),
          ],
        ),
      ),
    );

    if (cookConfirmed != true) {
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
            ? context.tr(
                en: 'Recipe flow completed.',
                sk: 'Práca s receptom bola dokončená.',
              )
            : context.tr(
                en: 'Cooked recipe and ${parts.join(', ')}.',
                sk: 'Recept bol spracovaný a ${parts.join(', ')}.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to cook recipe.',
          sk: 'Recept sa nepodarilo spracovať.',
        ),
      );
    }
  }

  Future<int> _consumeAvailableFromPantry(RecipeMatchResult result) async {
    final pantryEntries = <_PantryConsumptionEntry>[
      ...result.available.map(
        (item) => _PantryConsumptionEntry(
          ingredient: item.ingredient,
          matchedItems: item.matchedItems,
          quantityToConsumeInRecipeUnit: item.requiredQuantityInRecipeUnit,
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
    return _matchRecipe(
      recipe,
      pantryItems,
      servings: _selectedServingsFor(recipe),
    );
  }

  Future<bool> _confirmProceedWithSafetyWarning({
    required Recipe recipe,
    required UserPreferences? preferences,
    required String actionLabel,
  }) async {
    UserPreferences? effectivePreferences = preferences;
    if (effectivePreferences == null) {
      try {
        effectivePreferences = await _userPreferencesRepository
            .getCurrentUserPreferences();
      } catch (_) {
        effectivePreferences = null;
      }
    }

    final warning = _buildRecipeSafetyWarning(recipe, effectivePreferences);
    if (warning == null || !mounted) {
      return true;
    }

    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );
    final warningText = warning.matchedSignals.join(', ');
    final suggestions = _suggestSafeRecipeAlternatives(recipe, warning);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                  en: 'This recipe may conflict with your preferences because it contains $warningText.\n\nDo you still want to $actionLabel?',
                  sk: 'Tento recept môže kolidovať s tvojimi preferenciami, pretože obsahuje $warningText.\n\nNapriek tomu chceš $actionLabel?',
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    en: 'Safer alternatives:',
                    sk: 'Bezpečnejšie alternatívy:',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...suggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $suggestion'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Continue', sk: 'Pokračovať')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  List<String> _suggestSafeRecipeAlternatives(
    Recipe recipe,
    _FoodSafetyWarning warning,
  ) {
    final suggestions = <String>{};
    final ingredientKeys = recipe.ingredients
        .map((ingredient) => _canonicalIngredientKey(ingredient.name))
        .toSet();

    for (final signal in warning.matchedSignals) {
      switch (signal) {
        case 'lactose':
          suggestions.add(
            context.tr(
              en: 'Use lactose-free dairy alternatives',
              sk: 'Použi bezlaktózové mliečne alternatívy',
            ),
          );
          if (ingredientKeys.contains('milk')) {
            suggestions.add(
              context.tr(
                en: 'Swap milk for lactose-free milk',
                sk: 'Nahraď mlieko bezlaktózovým mliekom',
              ),
            );
          }
          if (ingredientKeys.contains('cheese')) {
            suggestions.add(
              context.tr(
                en: 'Swap cheese for lactose-free cheese',
                sk: 'Nahraď syr bezlaktózovým syrom',
              ),
            );
          }
          break;
        case 'gluten':
          suggestions.add(
            context.tr(
              en: 'Try gluten-free alternatives for grains or pasta',
              sk: 'Skús bezlepkové alternatívy pre obilniny alebo cestoviny',
            ),
          );
          break;
        case 'eggs':
          suggestions.add(
            context.tr(
              en: 'Try an egg-free version of this recipe',
              sk: 'Skús bezvaječnú verziu tohto receptu',
            ),
          );
          break;
      }
    }

    return suggestions.take(3).toList();
  }

  Future<int> _addMissingToShoppingListInternal(
    RecipeMatchResult result,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError(
        context.tr(
          en: 'No signed-in user.',
          sk: 'Žiadny prihlásený používateľ.',
        ),
      );
    }

    final existingItems = await _shoppingListRepository.getShoppingListItems();
    UserPreferences? preferences;
    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }
    int changedCount = 0;

    for (final missing in result.missing) {
      final ingredient = missing.ingredient;
      changedCount += await _upsertShoppingNeed(
        userId: user.id,
        existingItems: existingItems,
        ingredientName: _preferredShoppingIngredientName(
          ingredient.name,
          preferences,
        ),
        quantity: missing.missingQuantityInRecipeUnit,
        unit: ingredient.unit,
      );
    }

    for (final partial in result.partial) {
      final ingredient = partial.ingredient;
      changedCount += await _upsertShoppingNeed(
        userId: user.id,
        existingItems: existingItems,
        ingredientName: _preferredShoppingIngredientName(
          ingredient.name,
          preferences,
        ),
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
      return item.openedAt != null ? 0 : 1;
    }

    final ingredientKey = _canonicalIngredientKey(ingredientName);
    final itemKey = _canonicalIngredientKey(item.name);
    if (ingredientKey == itemKey) {
      return item.openedAt != null ? 2 : 3;
    }

    final storagePriority = switch (item.storageLocation.trim().toLowerCase()) {
      'fridge' => 0,
      'pantry' => 1,
      'freezer' => 2,
      _ => 3,
    };
    final openedOffset = item.openedAt != null ? 0 : 1;
    return 4 + (storagePriority * 2) + openedOffset;
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
    final convertedIncomingQuantity = _convertToIngredientUnit(
      quantity: quantity,
      fromUnit: unit,
      toUnit: existing.unit,
    );
    var mergedQuantity =
        existing.quantity + (convertedIncomingQuantity ?? quantity);

    for (final duplicate in matchingItems.skip(1)) {
      final duplicateConvertedQuantity = _convertToIngredientUnit(
        quantity: duplicate.quantity,
        fromUnit: duplicate.unit,
        toUnit: existing.unit,
      );
      mergedQuantity += duplicateConvertedQuantity ?? duplicate.quantity;
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

  _FoodSafetyWarning? _buildRecipeSafetyWarning(
    Recipe recipe,
    UserPreferences? preferences,
  ) {
    if (preferences == null) {
      return null;
    }

    final matchedAllergies = _matchPreferenceSignals(
      preferenceEntries: preferences.allergies,
      candidateSignals: recipe.ingredients
          .expand((ingredient) => _ingredientSignalSet(ingredient))
          .toSet(),
    );
    if (matchedAllergies.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.allergy,
        matchedSignals: matchedAllergies,
      );
    }

    final matchedIntolerances = _matchPreferenceSignals(
      preferenceEntries: preferences.intolerances,
      candidateSignals: recipe.ingredients
          .expand((ingredient) => _ingredientSignalSet(ingredient))
          .toSet(),
    );
    if (matchedIntolerances.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.intolerance,
        matchedSignals: matchedIntolerances,
      );
    }

    return null;
  }

  String _preferredShoppingIngredientName(
    String ingredientName,
    UserPreferences? preferences,
  ) {
    if (preferences == null) {
      return ingredientName;
    }

    final matchedIntolerances = _matchPreferenceSignals(
      preferenceEntries: preferences.intolerances,
      candidateSignals: {
        _canonicalFoodSignal(_normalize(ingredientName)),
        _canonicalIngredientKey(ingredientName),
      },
    );

    if (matchedIntolerances.contains('lactose')) {
      final normalizedName = _normalize(ingredientName);
      if (normalizedName.contains('milk') ||
          normalizedName.contains('mlieko')) {
        return 'Bezlaktózové mlieko';
      }
      if (normalizedName.contains('cheese') ||
          normalizedName.contains('syr') ||
          normalizedName.contains('gorgonzola') ||
          normalizedName.contains('mozzarella')) {
        return 'Bezlaktózový syr';
      }
      if (normalizedName.contains('yogurt') ||
          normalizedName.contains('jogurt')) {
        return 'Bezlaktózový jogurt';
      }
      if (normalizedName.contains('cream') ||
          normalizedName.contains('smotan')) {
        return 'Bezlaktózová smotana';
      }
      if (normalizedName.contains('butter') ||
          normalizedName.contains('maslo')) {
        return 'Bezlaktózové maslo';
      }
    }

    return ingredientName;
  }

  Set<String> _ingredientSignalSet(RecipeIngredient ingredient) {
    final signals = <String>{};
    final normalizedName = _normalize(ingredient.name);
    final canonicalKey = _canonicalIngredientKey(ingredient.name);

    signals.add(canonicalKey);
    signals.add(_canonicalFoodSignal(normalizedName));

    if (canonicalKey == 'milk' || canonicalKey == 'cheese') {
      signals.add('dairy');
      signals.add('lactose');
    }
    if (canonicalKey == 'eggs') {
      signals.add('eggs');
      signals.add('egg');
    }

    return signals
        .map(_canonicalFoodSignal)
        .where((signal) => signal.isNotEmpty)
        .toSet();
  }

  List<String> _matchPreferenceSignals({
    required List<String> preferenceEntries,
    required Set<String> candidateSignals,
  }) {
    final matches = <String>{};
    for (final entry in preferenceEntries) {
      final signal = _canonicalFoodSignal(_normalize(entry));
      if (signal.isEmpty) {
        continue;
      }
      if (candidateSignals.contains(signal)) {
        matches.add(signal);
      }
    }
    return matches.toList()..sort();
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
      case 'sój':
      case 'soj':
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

class _QuickCookingModeCard extends StatelessWidget {
  const _QuickCookingModeCard({
    required this.minutes,
    required this.recipeCount,
    required this.safeCount,
    required this.readyCount,
  });

  final int minutes;
  final int recipeCount;
  final int safeCount;
  final int readyCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF7E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.timer_outlined, color: Color(0xFF8A5A00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          en: 'What can I cook in $minutes minutes?',
                          sk: 'Čo uvarím za $minutes minút?',
                        ),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          en: 'Recipes are sorted by safety and by what you already have at home.',
                          sk: 'Recepty sú zoradené podľa bezpečnosti a podľa toho, čo už máš doma.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: context.tr(
                    en: '$recipeCount recipes',
                    sk: '$recipeCount receptov',
                  ),
                  color: const Color(0xFFFFE9BA),
                ),
                _SummaryChip(
                  label: context.tr(
                    en: '$safeCount safe for me',
                    sk: '$safeCount bezpečných pre mňa',
                  ),
                  color: const Color(0xFFE5F0DF),
                ),
                _SummaryChip(
                  label: context.tr(
                    en: '$readyCount ready from pantry',
                    sk: '$readyCount pripravených zo špajze',
                  ),
                  color: const Color(0xFFE8EEF8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeIngredientAvailabilitySections extends StatelessWidget {
  const _RecipeIngredientAvailabilitySections({
    required this.result,
    required this.displayIngredientName,
    required this.formatQuantity,
  });

  final RecipeMatchResult result;
  final String Function(String value) displayIngredientName;
  final String Function(double value) formatQuantity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            en: 'Ingredients for ${result.selectedServings} ${result.selectedServings == 1 ? 'serving' : 'servings'}',
            sk: 'Suroviny pre ${result.selectedServings} ${result.selectedServings == 1 ? 'porciu' : 'porcie'}',
          ),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _RecipeIngredientSection(
          title: context.tr(en: 'Available', sk: 'Dostupné'),
          emptyText: context.tr(
            en: 'Nothing from this recipe is fully available right now.',
            sk: 'Z tohto receptu momentálne nie je nič úplne dostupné.',
          ),
          children: result.available.map((item) {
            return _IngredientRequirementLine(
              text:
                  '• ${displayIngredientName(item.ingredient.name)}: ${context.tr(en: 'need', sk: 'treba')} ${formatQuantity(item.requiredQuantityInRecipeUnit)} ${item.ingredient.unit} • ${context.tr(en: 'at home', sk: 'doma')} ${formatQuantity(item.availableQuantityInRecipeUnit)} ${item.ingredient.unit}',
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _RecipeIngredientSection(
          title: context.tr(
            en: 'Partially available',
            sk: 'Čiastočne dostupné',
          ),
          emptyText: context.tr(
            en: 'Nothing is partially available right now.',
            sk: 'Momentálne nie je nič čiastočne dostupné.',
          ),
          children: result.partial.map((item) {
            return _IngredientRequirementLine(
              text:
                  '• ${displayIngredientName(item.ingredient.name)}: ${context.tr(en: 'need', sk: 'treba')} ${formatQuantity(item.requiredQuantityInRecipeUnit)} ${item.ingredient.unit} • ${context.tr(en: 'have', sk: 'máš')} ${formatQuantity(item.availableQuantityInRecipeUnit)} ${item.ingredient.unit} • ${context.tr(en: 'missing', sk: 'chýba')} ${formatQuantity(item.missingQuantityInRecipeUnit)} ${item.ingredient.unit}',
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _RecipeIngredientSection(
          title: context.tr(en: 'Missing', sk: 'Chýba'),
          emptyText: context.tr(
            en: 'No ingredients are completely missing for this recipe.',
            sk: 'Tomuto receptu momentálne úplne nechýbajú žiadne suroviny.',
          ),
          children: result.missing.map((item) {
            return _IngredientRequirementLine(
              text:
                  '• ${displayIngredientName(item.ingredient.name)}: ${context.tr(en: 'need', sk: 'treba')} ${formatQuantity(item.requiredQuantityInRecipeUnit)} ${item.ingredient.unit}',
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecipeIngredientSection extends StatelessWidget {
  const _RecipeIngredientSection({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty) Text(emptyText) else ...children,
      ],
    );
  }
}

class _IngredientRequirementLine extends StatelessWidget {
  const _IngredientRequirementLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text),
    );
  }
}

class _RecipeNutritionSummary extends StatelessWidget {
  const _RecipeNutritionSummary({required this.nutrition});

  final RecipeNutritionEstimate nutrition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            en: 'Nutrition for ${nutrition.selectedServings} ${nutrition.selectedServings == 1 ? 'serving' : 'servings'}',
            sk: 'Nutričný odhad pre ${nutrition.selectedServings} ${nutrition.selectedServings == 1 ? 'porciu' : 'porcie'}',
          ),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SummaryChip(
              label:
                  '${nutrition.caloriesTotal} ${context.tr(en: 'kcal', sk: 'kcal')}',
              color: const Color(0xFFFFF0D9),
            ),
            _SummaryChip(
              label:
                  '${nutrition.proteinTotal.toStringAsFixed(1)} g ${context.tr(en: 'protein', sk: 'bielkoviny')}',
              color: const Color(0xFFE7F3E8),
            ),
            _SummaryChip(
              label:
                  '${nutrition.fiberTotal.toStringAsFixed(1)} g ${context.tr(en: 'fiber', sk: 'vláknina')}',
              color: const Color(0xFFE8EEF8),
            ),
            _SummaryChip(
              label: _balanceLabel(context, nutrition.balanceScore),
              color: const Color(0xFFEDE8F8),
            ),
            _SummaryChip(
              label:
                  '${context.tr(en: 'per serving', sk: 'na porciu')}: ${nutrition.caloriesPerServing} ${context.tr(en: 'kcal', sk: 'kcal')}',
              color: const Color(0xFFF4F1FB),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6DDCF)),
          ),
          child: Text(
            _nutritionInsight(context, nutrition),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _nutritionInsight(
    BuildContext context,
    RecipeNutritionEstimate nutrition,
  ) {
    return switch (deriveRecipeNutritionInsight(nutrition)) {
      RecipeNutritionInsight.balanced => context.tr(
        en: 'Balanced meal with solid protein and fiber.',
        sk: 'Vyvážené jedlo s dobrým obsahom bielkovín aj vlákniny.',
      ),
      RecipeNutritionInsight.moreProtein => context.tr(
        en: 'Good fiber, but it could use more protein.',
        sk: 'Dobrá vláknina, ale zišlo by sa viac bielkovín.',
      ),
      RecipeNutritionInsight.lowerFiber => context.tr(
        en: 'Lower fiber meal. Add vegetables, beans or whole grains if you want more balance.',
        sk: 'Jedlo má menej vlákniny. Ak chceš lepšiu vyváženosť, pridaj zeleninu, strukoviny alebo celozrnné prílohy.',
      ),
      RecipeNutritionInsight.higherCalories => context.tr(
        en: 'More filling and higher-calorie meal.',
        sk: 'Sýtejšie a kalorickejšie jedlo.',
      ),
      RecipeNutritionInsight.lighterMeal => context.tr(
        en: 'Lighter meal. Good if you want something smaller.',
        sk: 'Ľahšie jedlo. Dobrá voľba, ak chceš niečo menšie.',
      ),
      RecipeNutritionInsight.proteinForward => context.tr(
        en: 'Protein-forward meal with decent overall balance.',
        sk: 'Jedlo orientované na bielkoviny s celkom dobrou vyváženosťou.',
      ),
      RecipeNutritionInsight.everydayBalance => context.tr(
        en: 'Reasonable everyday meal with a solid energy balance.',
        sk: 'Rozumné každodenné jedlo s celkom dobrým energetickým pomerom.',
      ),
    };
  }

  String _balanceLabel(BuildContext context, int score) {
    if (score >= 75) {
      return context.tr(en: 'Well balanced', sk: 'Dobre vyvážené');
    }
    if (score >= 60) {
      return context.tr(en: 'Good choice', sk: 'Dobrá voľba');
    }
    if (score >= 45) {
      return context.tr(en: 'More energy', sk: 'Viac energie');
    }
    return context.tr(en: 'Treat meal', sk: 'Skôr maškrta');
  }
}

class _RecipeSafetyBadge extends StatelessWidget {
  const _RecipeSafetyBadge({required this.warning});

  final _FoodSafetyWarning warning;

  @override
  Widget build(BuildContext context) {
    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final backgroundColor = isAllergy
        ? const Color(0xFFFDE7E9)
        : const Color(0xFFFFF3D9);
    final foregroundColor = isAllergy
        ? const Color(0xFF9F1D2C)
        : const Color(0xFF8A5A00);
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$title: ${context.tr(en: 'contains', sk: 'obsahuje')} ${warning.matchedSignals.join(', ')}.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
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
              decoration: InputDecoration(
                hintText: context.tr(
                  en: 'Search recipes',
                  sk: 'Hľadať recepty',
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(context.tr(en: 'All', sk: 'Všetko')),
                  selected: selectedFilter == RecipeFilter.all,
                  onSelected: (_) => onFilterChanged(RecipeFilter.all),
                ),
                FilterChip(
                  label: const Text('15 min'),
                  selected: selectedFilter == RecipeFilter.under15Minutes,
                  onSelected: (_) =>
                      onFilterChanged(RecipeFilter.under15Minutes),
                ),
                FilterChip(
                  label: const Text('30 min'),
                  selected: selectedFilter == RecipeFilter.under30Minutes,
                  onSelected: (_) =>
                      onFilterChanged(RecipeFilter.under30Minutes),
                ),
                FilterChip(
                  label: const Text('45 min'),
                  selected: selectedFilter == RecipeFilter.under45Minutes,
                  onSelected: (_) =>
                      onFilterChanged(RecipeFilter.under45Minutes),
                ),
                FilterChip(
                  label: Text(
                    context.tr(en: 'Safe for me', sk: 'Bezpečné pre mňa'),
                  ),
                  selected: selectedFilter == RecipeFilter.safeForMe,
                  onSelected: (_) => onFilterChanged(RecipeFilter.safeForMe),
                ),
                FilterChip(
                  label: Text(context.tr(en: 'Favorites', sk: 'Obľúbené')),
                  selected: selectedFilter == RecipeFilter.favorites,
                  onSelected: (_) => onFilterChanged(RecipeFilter.favorites),
                ),
                FilterChip(
                  label: Text(context.tr(en: 'Public', sk: 'Verejné')),
                  selected: selectedFilter == RecipeFilter.publicOnly,
                  onSelected: (_) => onFilterChanged(RecipeFilter.publicOnly),
                ),
                FilterChip(
                  label: Text(context.tr(en: 'Household', sk: 'Domácnosť')),
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

class _RecipesViewData {
  final List<FoodItem> pantryItems;
  final List<Recipe> recipes;
  final UserPreferences? preferences;

  const _RecipesViewData({
    required this.pantryItems,
    required this.recipes,
    required this.preferences,
  });
}

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matchedSignals;

  const _FoodSafetyWarning({required this.type, required this.matchedSignals});
}
