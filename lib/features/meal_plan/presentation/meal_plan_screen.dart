import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
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

  late Future<List<MealPlanEntry>> _entriesFuture = _mealPlanRepository
      .getEntries();

  Future<void> _reload() async {
    setState(() {
      _entriesFuture = _mealPlanRepository.getEntries();
    });
    await _entriesFuture;
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
      body: FutureBuilder<List<MealPlanEntry>>(
        future: _entriesFuture,
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

          final entries = snapshot.data ?? const <MealPlanEntry>[];
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
                                ...group.value.map(
                                  (entry) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(entry.recipeName),
                                    subtitle: Text(
                                      '${_mealTypeLabel(entry.mealType)}${entry.note == null || entry.note!.isEmpty ? '' : ' • ${entry.note}'}',
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
                                  ),
                                ),
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
}
