import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_ingredient.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_entry.dart';
import 'meal_plan_form_screen.dart';
import 'meal_plan_import_screen.dart';

class MealPlanScreen extends StatefulWidget {
  final String householdId;
  final VoidCallback? onShoppingListChanged;

  const MealPlanScreen({
    super.key,
    required this.householdId,
    this.onShoppingListChanged,
  });

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.householdId,
  );
  late final RecipesRepository _recipesRepository = RecipesRepository(
    householdId: widget.householdId,
  );
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.householdId,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.householdId);
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();

  late Future<_MealPlanViewData> _viewFuture = _loadViewData();

  Future<void> _reload() async {
    setState(() {
      _viewFuture = _loadViewData();
    });
    await _viewFuture;
  }

  Future<_MealPlanViewData> _loadViewData() async {
    final entriesFuture = _mealPlanRepository.getEntries();
    final recipesFuture = _recipesRepository.getRecipes();
    UserPreferences? preferences;

    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }

    final results = await Future.wait<Object>([entriesFuture, recipesFuture]);
    return _MealPlanViewData(
      entries: results[0] as List<MealPlanEntry>,
      recipes: results[1] as List<Recipe>,
      preferences: preferences,
    );
  }

  Future<void> _openCreateForm() async {
    final recipes = await _recipesRepository.getRecipes();
    if (!mounted) {
      return;
    }
    final entry = await Navigator.of(context).push<MealPlanEntry>(
      MaterialPageRoute(
        builder: (_) => MealPlanFormScreen(
          householdId: widget.householdId,
          recipes: recipes,
        ),
      ),
    );

    if (entry == null) {
      return;
    }

    final confirmed = await _confirmMealPlanSafetyForEntry(
      entry,
      actionLabel: 'add this meal to your plan',
      recipes: recipes,
      preferences: null,
    );
    if (!confirmed) {
      return;
    }

    try {
      await _mealPlanRepository.addEntry(entry);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Meal plan entry added.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add meal plan entry.');
    }
  }

  Future<void> _openImportMealPlan() async {
    final recipes = await _recipesRepository.getRecipes();
    if (!mounted) {
      return;
    }

    final importedEntries = await Navigator.of(context)
        .push<List<MealPlanEntry>>(
          MaterialPageRoute(
            builder: (_) => MealPlanImportScreen(
              householdId: widget.householdId,
              recipes: recipes,
            ),
          ),
        );

    if (importedEntries == null || importedEntries.isEmpty) {
      return;
    }

    final confirmed = await _confirmMealPlanSafetyForEntries(
      importedEntries,
      actionLabel: 'import these meals into your plan',
      recipes: recipes,
      preferences: null,
    );
    if (!confirmed) {
      return;
    }

    try {
      for (final entry in importedEntries) {
        await _mealPlanRepository.addEntry(entry);
      }
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        '${importedEntries.length} meal plan entr${importedEntries.length == 1 ? 'y' : 'ies'} imported.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to import meal plan.');
    }
  }

  Future<void> _openEditForm(MealPlanEntry entry) async {
    final recipes = await _recipesRepository.getRecipes();
    if (!mounted) {
      return;
    }
    final updated = await Navigator.of(context).push<MealPlanEntry>(
      MaterialPageRoute(
        builder: (_) => MealPlanFormScreen(
          householdId: widget.householdId,
          recipes: recipes,
          initialEntry: entry,
        ),
      ),
    );

    if (updated == null) {
      return;
    }

    final confirmed = await _confirmMealPlanSafetyForEntry(
      updated,
      actionLabel: 'save this meal plan entry',
      recipes: recipes,
      preferences: null,
    );
    if (!confirmed) {
      return;
    }

    try {
      await _mealPlanRepository.editEntry(updated);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Meal plan entry updated.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update meal plan entry.');
    }
  }

  Future<void> _deleteEntry(MealPlanEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal plan entry'),
        content: Text('Do you want to delete "${entry.recipeName}"?'),
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
      await _mealPlanRepository.removeEntry(entry.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Meal plan entry deleted.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to delete meal plan entry.');
    }
  }

  Future<void> _addMissingPlannedIngredients(
    List<MealPlanEntry> entries,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(context, 'No signed-in user.');
      return;
    }

    try {
      final recipes = await _recipesRepository.getRecipes();
      final pantryItems = await _foodItemsRepository.getFoodItems();
      final shoppingItems = await _shoppingListRepository
          .getShoppingListItems();

      int changedCount = 0;
      for (final entry in entries) {
        if (entry.recipeId == null) {
          continue;
        }
        final recipe = _findRecipeById(recipes, entry.recipeId);
        if (recipe == null) {
          continue;
        }
        for (final ingredient in recipe.ingredients) {
          final available = _availableQuantity(
            ingredient.name,
            ingredient.unit,
            pantryItems,
          );
          final missing = ingredient.quantity - available;
          if (missing <= 0.0001) {
            continue;
          }
          changedCount += await _upsertShoppingNeed(
            userId: user.id,
            existingItems: shoppingItems,
            name: ingredient.name,
            quantity: missing,
            unit: ingredient.unit,
          );
        }
      }

      if (!mounted) return;
      if (changedCount == 0) {
        showSuccessFeedback(context, 'Meal plan is already covered.');
      } else {
        widget.onShoppingListChanged?.call();
        showSuccessFeedback(
          context,
          '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from meal plan.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        'Failed to update shopping list from meal plan.',
      );
    }
  }

  double _availableQuantity(
    String name,
    String unit,
    List<FoodItem> pantryItems,
  ) {
    double sum = 0;
    for (final item in pantryItems) {
      if (_itemKey(item.name, item.unit) != _itemKey(name, unit)) {
        continue;
      }
      final converted = _convertQuantity(
        quantity: item.quantity,
        fromUnit: item.unit,
        toUnit: unit,
      );
      if (converted != null) {
        sum += converted;
      }
    }
    return sum;
  }

  Future<int> _upsertShoppingNeed({
    required String userId,
    required List<ShoppingListItem> existingItems,
    required String name,
    required double quantity,
    required String unit,
  }) async {
    final key = _itemKey(name, unit);
    final matchingItems = existingItems
        .where((item) => _itemKey(item.name, item.unit) == key)
        .toList();
    final now = DateTime.now().toUtc();

    if (matchingItems.isEmpty) {
      final created = await _shoppingListRepository.addShoppingListItem(
        ShoppingListItem(
          id: '',
          userId: userId,
          householdId: widget.householdId,
          name: name,
          quantity: quantity,
          unit: unit,
          source: ShoppingListItem.sourceManual,
          isBought: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      existingItems.add(created);
      return 1;
    }

    final primary = matchingItems.first;
    final updated = await _shoppingListRepository.editShoppingListItem(
      primary.copyWith(
        quantity: quantity > primary.quantity ? quantity : primary.quantity,
        source: ShoppingListItem.mergeSource(
          primary.source,
          ShoppingListItem.sourceManual,
        ),
        isBought: false,
        updatedAt: now,
      ),
    );

    final index = existingItems.indexWhere((item) => item.id == primary.id);
    if (index >= 0) {
      existingItems[index] = updated;
    }
    return 1;
  }

  Future<UserPreferences?> _loadCurrentPreferencesSafely() async {
    try {
      return await _userPreferencesRepository.getCurrentUserPreferences();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _confirmMealPlanSafetyForEntry(
    MealPlanEntry entry, {
    required String actionLabel,
    required List<Recipe> recipes,
    required UserPreferences? preferences,
  }) async {
    final recipe = _findRecipeById(recipes, entry.recipeId);
    if (recipe == null) {
      return true;
    }

    final effectivePreferences =
        preferences ?? await _loadCurrentPreferencesSafely();
    final warning = _buildRecipeSafetyWarning(recipe, effectivePreferences);
    if (warning == null || !mounted) {
      return true;
    }

    return _showMealPlanSafetyDialog(
      warning: warning,
      actionLabel: actionLabel,
      affectedMealNames: [entry.recipeName],
    );
  }

  Future<bool> _confirmMealPlanSafetyForEntries(
    List<MealPlanEntry> entries, {
    required String actionLabel,
    required List<Recipe> recipes,
    required UserPreferences? preferences,
  }) async {
    final effectivePreferences =
        preferences ?? await _loadCurrentPreferencesSafely();
    final unsafeEntries = <MealPlanEntry>[];
    final matchedSignals = <String>{};
    _FoodSafetyWarningType? warningType;

    for (final entry in entries) {
      final recipe = _findRecipeById(recipes, entry.recipeId);
      final warning = _buildRecipeSafetyWarning(recipe, effectivePreferences);
      if (warning == null) {
        continue;
      }
      unsafeEntries.add(entry);
      warningType ??= warning.type;
      matchedSignals.addAll(warning.matchedSignals);
    }

    if (unsafeEntries.isEmpty || !mounted) {
      return true;
    }

    return _showMealPlanSafetyDialog(
      warning: _FoodSafetyWarning(
        type: warningType ?? _FoodSafetyWarningType.intolerance,
        matchedSignals: matchedSignals.toList()..sort(),
      ),
      actionLabel: actionLabel,
      affectedMealNames: unsafeEntries
          .map((entry) => entry.recipeName)
          .toList(),
    );
  }

  Future<bool> _showMealPlanSafetyDialog({
    required _FoodSafetyWarning warning,
    required String actionLabel,
    required List<String> affectedMealNames,
  }) async {
    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final title = isAllergy ? 'Allergy warning' : 'Intolerance warning';
    final mealPreview = affectedMealNames.take(3).join(', ');
    final hasMoreMeals = affectedMealNames.length > 3;
    final affectedMealsText = hasMoreMeals
        ? '$mealPreview and ${affectedMealNames.length - 3} more'
        : mealPreview;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          'Some planned meals may conflict with your preferences because they contain ${warning.matchedSignals.join(', ')}.\n\nAffected meals: $affectedMealsText.\n\nDo you still want to $actionLabel?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Plan'),
        actions: [
          IconButton(
            onPressed: _openImportMealPlan,
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import meal plan',
          ),
          IconButton(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            tooltip: 'Add meal',
          ),
        ],
      ),
      body: FutureBuilder<_MealPlanViewData>(
        future: _viewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Failed to load meal plan.',
              onRetry: _reload,
            );
          }

          final viewData =
              snapshot.data ??
              const _MealPlanViewData(
                entries: <MealPlanEntry>[],
                recipes: <Recipe>[],
                preferences: null,
              );
          final entries = viewData.entries;
          final recipes = viewData.recipes;
          final preferences = viewData.preferences;
          final upcomingEntries = entries.where((entry) {
            final today = DateTime.now();
            final current = DateTime(today.year, today.month, today.day);
            final scheduled = DateTime(
              entry.scheduledFor.year,
              entry.scheduledFor.month,
              entry.scheduledFor.day,
            );
            return !scheduled.isBefore(current);
          }).toList();

          return RefreshIndicator(
            onRefresh: _reload,
            child: entries.isEmpty
                ? AppEmptyState(
                    message: 'No meal plan entries yet.',
                    onRefresh: _reload,
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _openImportMealPlan,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Import meal plan'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: upcomingEntries.isEmpty
                            ? null
                            : () => _addMissingPlannedIngredients(
                                upcomingEntries,
                              ),
                        child: const Text(
                          'Add missing planned ingredients to shopping list',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._groupEntries(entries).entries.map((group) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFCF7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE6DDCF),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.key,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),
                                ...group.value.map((entry) {
                                  final recipe = _findRecipeById(
                                    recipes,
                                    entry.recipeId,
                                  );
                                  final warning = _buildRecipeSafetyWarning(
                                    recipe,
                                    preferences,
                                  );

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.recipeName),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_mealTypeLabel(entry.mealType)}${entry.note == null || entry.note!.isEmpty ? '' : ' • ${entry.note}'}',
                                        ),
                                        if (warning != null) ...[
                                          const SizedBox(height: 6),
                                          _MealSafetyBadge(warning: warning),
                                        ],
                                      ],
                                    ),
                                    onTap: () => _openEditForm(entry),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        if (entry.recipeId == null)
                                          TextButton(
                                            onPressed: () =>
                                                _openEditForm(entry),
                                            child: const Text('Link recipe'),
                                          ),
                                        IconButton(
                                          onPressed: () => _deleteEntry(entry),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Add meal'),
      ),
    );
  }

  Map<String, List<MealPlanEntry>> _groupEntries(List<MealPlanEntry> entries) {
    final grouped = <String, List<MealPlanEntry>>{};
    for (final entry in entries) {
      final key = _formatDate(entry.scheduledFor);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  String _itemKey(String name, String unit) {
    return '${_normalizeName(name)}|${_normalizeUnit(unit)}';
  }

  String _normalizeName(String value) {
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
    if (const {'pcs', 'pc', 'piece', 'pieces', 'ks'}.contains(normalized)) {
      return 'pcs';
    }
    if (const {'g', 'gram', 'grams'}.contains(normalized)) {
      return 'g';
    }
    if (const {'kg', 'kilogram', 'kilograms'}.contains(normalized)) {
      return 'kg';
    }
    if (const {'ml', 'milliliter', 'milliliters'}.contains(normalized)) {
      return 'ml';
    }
    if (const {'l', 'liter', 'liters'}.contains(normalized)) {
      return 'l';
    }
    return normalized;
  }

  double? _convertQuantity({
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
    const pieceFactors = {'pcs': 1.0};

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
      return quantity;
    }
    return null;
  }

  String _mealTypeLabel(String value) {
    return switch (value) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      _ => 'Meal',
    };
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Recipe? _findRecipeById(List<Recipe> recipes, String? recipeId) {
    if (recipeId == null) {
      return null;
    }

    for (final recipe in recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }

    return null;
  }

  _FoodSafetyWarning? _buildRecipeSafetyWarning(
    Recipe? recipe,
    UserPreferences? preferences,
  ) {
    if (recipe == null || preferences == null) {
      return null;
    }

    final candidateSignals = recipe.ingredients
        .expand((ingredient) => _ingredientSignalSet(ingredient))
        .toSet();

    final allergyMatches = _matchPreferenceSignals(
      preferenceEntries: preferences.allergies,
      candidateSignals: candidateSignals,
    );
    if (allergyMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.allergy,
        matchedSignals: allergyMatches,
      );
    }

    final intoleranceMatches = _matchPreferenceSignals(
      preferenceEntries: preferences.intolerances,
      candidateSignals: candidateSignals,
    );
    if (intoleranceMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.intolerance,
        matchedSignals: intoleranceMatches,
      );
    }

    return null;
  }

  Set<String> _ingredientSignalSet(RecipeIngredient ingredient) {
    final signals = <String>{};
    final normalizedName = _normalizeName(ingredient.name);
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
      final signal = _canonicalFoodSignal(_normalizeName(entry));
      if (signal.isEmpty) {
        continue;
      }
      if (candidateSignals.contains(signal)) {
        matches.add(signal);
      }
    }
    return matches.toList()..sort();
  }

  String _canonicalIngredientKey(String value) {
    final normalized = _normalizeName(value);

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
      'bread': 'bread',
      'chlieb': 'bread',
      'pecivo': 'bread',
      'fish': 'fish',
      'ryba': 'fish',
      'soy': 'soy',
      'soya': 'soy',
      'peanuts': 'peanuts',
      'peanut': 'peanuts',
      'arasidy': 'peanuts',
      'sesame': 'sesame',
      'sezam': 'sesame',
    };

    return canonicalMap[normalized] ?? normalized;
  }

  String _canonicalFoodSignal(String value) {
    switch (value) {
      case 'lactose':
      case 'dairy':
      case 'milk':
      case 'cheese':
      case 'mlieko':
      case 'syr':
        return 'lactose';
      case 'gluten':
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

class _MealSafetyBadge extends StatelessWidget {
  const _MealSafetyBadge({required this.warning});

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
    final title = isAllergy ? 'Allergy warning' : 'Intolerance warning';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$title: contains ${warning.matchedSignals.join(', ')}.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MealPlanViewData {
  final List<MealPlanEntry> entries;
  final List<Recipe> recipes;
  final UserPreferences? preferences;

  const _MealPlanViewData({
    required this.entries,
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
