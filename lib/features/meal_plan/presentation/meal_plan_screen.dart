import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../households/data/household_repository.dart';
import '../../households/domain/household_member.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_ingredient.dart';
import '../../recipes/domain/recipe_nutrition_estimate.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_entry.dart';
import 'meal_plan_form_screen.dart';
import 'meal_plan_import_screen.dart';

enum MealPlanFilter { all, upcoming, assignedToMe }

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
  late final HouseholdRepository _householdRepository = HouseholdRepository();

  late Future<_MealPlanViewData> _viewFuture = _loadViewData();
  MealPlanFilter _selectedFilter = MealPlanFilter.all;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _reload() async {
    setState(() {
      _viewFuture = _loadViewData();
    });
    await _viewFuture;
  }

  Future<_MealPlanViewData> _loadViewData() async {
    final entriesFuture = _mealPlanRepository.getEntries();
    final recipesFuture = _recipesRepository.getRecipes();
    final membersFuture = _loadHouseholdMembersSafely();
    UserPreferences? preferences;

    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }

    final results = await Future.wait<Object>([
      entriesFuture,
      recipesFuture,
      membersFuture,
    ]);
    return _MealPlanViewData(
      entries: results[0] as List<MealPlanEntry>,
      recipes: results[1] as List<Recipe>,
      members: results[2] as List<HouseholdMember>,
      preferences: preferences,
    );
  }

  Future<List<HouseholdMember>> _loadHouseholdMembersSafely() async {
    try {
      return await _householdRepository.getMembers(widget.householdId);
    } catch (_) {
      return const <HouseholdMember>[];
    }
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
      actionLabel: context.tr(
        en: 'add this meal to your plan',
        sk: 'pridať toto jedlo do tvojho jedálnička',
      ),
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
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Meal plan entry added.',
          sk: 'Položka jedálnička bola pridaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add meal plan entry.',
          sk: 'Položku jedálnička sa nepodarilo pridať.',
        ),
      );
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
      actionLabel: context.tr(
        en: 'import these meals into your plan',
        sk: 'importovať tieto jedlá do tvojho jedálnička',
      ),
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
        context.tr(
          en: '${importedEntries.length} meal plan entr${importedEntries.length == 1 ? 'y' : 'ies'} imported.',
          sk: 'Importovaných položiek jedálnička: ${importedEntries.length}.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to import meal plan.',
          sk: 'Jedálniček sa nepodarilo importovať.',
        ),
      );
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
      actionLabel: context.tr(
        en: 'save this meal plan entry',
        sk: 'uložiť túto položku jedálnička',
      ),
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
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Meal plan entry updated.',
          sk: 'Položka jedálnička bola upravená.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update meal plan entry.',
          sk: 'Položku jedálnička sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _deleteEntry(MealPlanEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(
            en: 'Delete meal plan entry',
            sk: 'Odstrániť položku jedálnička',
          ),
        ),
        content: Text(
          context.tr(
            en: 'Do you want to delete "${entry.recipeName}"?',
            sk: 'Chceš odstrániť „${entry.recipeName}“?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Delete', sk: 'Odstrániť')),
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
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Meal plan entry deleted.',
          sk: 'Položka jedálnička bola odstránená.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to delete meal plan entry.',
          sk: 'Položku jedálnička sa nepodarilo odstrániť.',
        ),
      );
    }
  }

  Future<void> _pickCookAssignment(
    MealPlanEntry entry,
    List<HouseholdMember> members,
  ) async {
    final selectedUserId = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(en: 'Assign cook', sk: 'Priradiť varenie')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: members
                  .map(
                    (member) => ListTile(
                      leading: Icon(
                        member.userId == _currentUserId
                            ? Icons.person
                            : Icons.group_outlined,
                      ),
                      title: Text(_memberLabel(member)),
                      subtitle: Text(_memberSubtitle(member)),
                      trailing: entry.assignedCookUserId == member.userId
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () => Navigator.of(context).pop(member.userId),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
        ],
      ),
    );

    if (selectedUserId == null) {
      return;
    }
    await _setCookAssignment(entry, selectedUserId);
  }

  Future<void> _setCookAssignment(
    MealPlanEntry entry,
    String? assignedCookUserId,
  ) async {
    try {
      await _mealPlanRepository.editEntry(
        entry.copyWith(
          assignedCookUserId: assignedCookUserId,
          clearAssignedCookUserId: assignedCookUserId == null,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        assignedCookUserId == null
            ? context.tr(
                en: 'Cooking assignment cleared.',
                sk: 'Priradenie varenia bolo zrušené.',
              )
            : assignedCookUserId == _currentUserId
            ? context.tr(
                en: 'Meal assigned to you.',
                sk: 'Varenie je priradené tebe.',
              )
            : context.tr(
                en: 'Meal assigned in household.',
                sk: 'Varenie je priradené v domácnosti.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update cooking assignment.',
          sk: 'Priradenie varenia sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _addMissingPlannedIngredients(
    List<MealPlanEntry> entries,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'No signed-in user.',
          sk: 'Nie je prihlásený žiadny používateľ.',
        ),
      );
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
        final scaleFactor = entry.servings / recipe.defaultServings;
        for (final ingredient in recipe.ingredients) {
          final available = _availableQuantity(
            ingredient.name,
            ingredient.unit,
            pantryItems,
          );
          final requiredQuantity = ingredient.quantity * scaleFactor;
          final missing = requiredQuantity - available;
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
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Meal plan is already covered.',
            sk: 'Jedálniček je už pokrytý.',
          ),
        );
      } else {
        widget.onShoppingListChanged?.call();
        showSuccessFeedback(
          context,
          context.tr(
            en: '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from meal plan.',
            sk: 'Aktualizované nákupné položky z jedálnička: $changedCount.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update shopping list from meal plan.',
          sk: 'Nákupný zoznam sa nepodarilo aktualizovať z jedálnička.',
        ),
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
      affectedMealNames: [localizedRecipeName(context, recipe)],
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
      affectedMealNames: unsafeEntries.map((entry) {
        final recipe = _findRecipeById(recipes, entry.recipeId);
        return recipe == null
            ? entry.recipeName
            : localizedRecipeName(context, recipe);
      }).toList(),
    );
  }

  Future<bool> _showMealPlanSafetyDialog({
    required _FoodSafetyWarning warning,
    required String actionLabel,
    required List<String> affectedMealNames,
  }) async {
    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );
    final mealPreview = affectedMealNames.take(3).join(', ');
    final hasMoreMeals = affectedMealNames.length > 3;
    final affectedMealsText = hasMoreMeals
        ? context.tr(
            en: '$mealPreview and ${affectedMealNames.length - 3} more',
            sk: '$mealPreview a ďalších ${affectedMealNames.length - 3}',
          )
        : mealPreview;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          context.tr(
            en: 'Some planned meals may conflict with your preferences because they contain ${warning.matchedSignals.join(', ')}.\n\nAffected meals: $affectedMealsText.\n\nDo you still want to $actionLabel?',
            sk: 'Niektoré plánované jedlá môžu kolidovať s tvojimi preferenciami, pretože obsahujú ${warning.matchedSignals.join(', ')}.\n\nOvplyvnené jedlá: $affectedMealsText.\n\nStále chceš $actionLabel?',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Meal Plan', sk: 'Jedálniček')),
        actions: [
          IconButton(
            onPressed: _openImportMealPlan,
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: context.tr(
              en: 'Import meal plan',
              sk: 'Importovať jedálniček',
            ),
          ),
          IconButton(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            tooltip: context.tr(en: 'Add meal', sk: 'Pridať jedlo'),
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
              kind: AppErrorKind.sync,
              title: context.tr(
                en: 'Meal plan is unavailable',
                sk: 'Jedálniček nie je k dispozícii',
              ),
              message: context.tr(
                en: 'Failed to load meal plan.',
                sk: 'Jedálniček sa nepodarilo načítať.',
              ),
              hint: context.tr(
                en: 'Safo could not load planned meals right now.',
                sk: 'Safo teraz nedokázalo načítať naplánované jedlá.',
              ),
              onRetry: _reload,
            );
          }

          final viewData =
              snapshot.data ??
              const _MealPlanViewData(
                entries: <MealPlanEntry>[],
                recipes: <Recipe>[],
                members: <HouseholdMember>[],
                preferences: null,
              );
          final entries = viewData.entries;
          final recipes = viewData.recipes;
          final members = viewData.members;
          final preferences = viewData.preferences;
          final filteredEntries = _applyMealPlanFilter(entries);
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
                    message: context.tr(
                      en: 'No meal plan entries yet.',
                      sk: 'Zatiaľ nemáš žiadne položky jedálnička.',
                    ),
                    onRefresh: _reload,
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _openImportMealPlan,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(
                          context.tr(
                            en: 'Import meal plan',
                            sk: 'Importovať jedálniček',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: upcomingEntries.isEmpty
                            ? null
                            : () => _addMissingPlannedIngredients(
                                upcomingEntries,
                              ),
                        child: Text(
                          context.tr(
                            en: 'Add missing planned ingredients to shopping list',
                            sk: 'Pridať chýbajúce plánované ingrediencie do nákupného zoznamu',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MealPlanFilterBar(
                        selectedFilter: _selectedFilter,
                        onFilterChanged: (filter) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (filteredEntries.isEmpty)
                        AppEmptyState(
                          message: context.tr(
                            en: 'No meals match this filter.',
                            sk: 'Tomuto filtru nezodpovedajú žiadne jedlá.',
                          ),
                          onRefresh: _reload,
                        )
                      else
                        ..._groupEntries(filteredEntries).entries.map((group) {
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
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
                                    final nutrition = recipe == null
                                        ? null
                                        : estimateRecipeNutrition(
                                            recipe,
                                            servings: entry.servings,
                                          );
                                    final displayedRecipeName = recipe == null
                                        ? entry.recipeName
                                        : localizedRecipeName(context, recipe);

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(displayedRecipeName),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${_mealTypeLabel(context, entry.mealType)} • ${entry.servings} ${context.tr(en: entry.servings == 1 ? 'serving' : 'servings', sk: entry.servings == 1 ? 'porcia' : 'porcie')}${entry.note == null || entry.note!.isEmpty ? '' : ' • ${entry.note}'}',
                                          ),
                                          if (entry.assignedCookUserId !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _cookAssignmentLabel(
                                                entry,
                                                members,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ],
                                          if (nutrition != null) ...[
                                            const SizedBox(height: 6),
                                            _MealNutritionRow(
                                              nutrition: nutrition,
                                            ),
                                          ],
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
                                              child: Text(
                                                context.tr(
                                                  en: 'Link recipe',
                                                  sk: 'Prepojiť recept',
                                                ),
                                              ),
                                            ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'assign_cook') {
                                                _pickCookAssignment(
                                                  entry,
                                                  members,
                                                );
                                              } else if (value ==
                                                  'clear_assignment') {
                                                _setCookAssignment(entry, null);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'assign_cook',
                                                child: Text(
                                                  context.tr(
                                                    en: 'Assign cook',
                                                    sk: 'Priradiť varenie',
                                                  ),
                                                ),
                                              ),
                                              if (entry.assignedCookUserId !=
                                                  null)
                                                PopupMenuItem(
                                                  value: 'clear_assignment',
                                                  child: Text(
                                                    context.tr(
                                                      en: 'Clear assignment',
                                                      sk: 'Zrušiť priradenie',
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _deleteEntry(entry),
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
        label: Text(context.tr(en: 'Add meal', sk: 'Pridať jedlo')),
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

  List<MealPlanEntry> _applyMealPlanFilter(List<MealPlanEntry> entries) {
    return entries.where((entry) {
      return switch (_selectedFilter) {
        MealPlanFilter.all => true,
        MealPlanFilter.upcoming => !_isPastMeal(entry),
        MealPlanFilter.assignedToMe =>
          !_isPastMeal(entry) && entry.assignedCookUserId == _currentUserId,
      };
    }).toList();
  }

  bool _isPastMeal(MealPlanEntry entry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      entry.scheduledFor.year,
      entry.scheduledFor.month,
      entry.scheduledFor.day,
    );
    return scheduled.isBefore(today);
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

  String _mealTypeLabel(BuildContext context, String value) {
    return switch (value) {
      'breakfast' => context.tr(en: 'Breakfast', sk: 'Raňajky'),
      'lunch' => context.tr(en: 'Lunch', sk: 'Obed'),
      'dinner' => context.tr(en: 'Dinner', sk: 'Večera'),
      'snack' => context.tr(en: 'Snack', sk: 'Desiata'),
      _ => context.tr(en: 'Meal', sk: 'Jedlo'),
    };
  }

  String _cookAssignmentLabel(
    MealPlanEntry entry,
    List<HouseholdMember> members,
  ) {
    final assignedUserId = entry.assignedCookUserId;
    if (assignedUserId == null) {
      return '';
    }
    if (assignedUserId == _currentUserId) {
      return context.tr(en: 'Cooking: you', sk: 'Varíš: ty');
    }
    final member = members.cast<HouseholdMember?>().firstWhere(
      (member) => member?.userId == assignedUserId,
      orElse: () => null,
    );
    if (member == null) {
      return context.tr(en: 'Cooking assigned', sk: 'Varenie priradené');
    }
    return context.tr(
      en: 'Cooking: ${_memberLabel(member)}',
      sk: 'Varí: ${_memberLabel(member)}',
    );
  }

  String _memberLabel(HouseholdMember member) {
    if (member.userId == _currentUserId) {
      return context.tr(en: 'You', sk: 'Ty');
    }
    return member.role == 'owner'
        ? context.tr(en: 'Owner', sk: 'Vlastník')
        : context.tr(en: 'Member', sk: 'Člen');
  }

  String _memberSubtitle(HouseholdMember member) {
    if (member.userId.length <= 8) {
      return member.userId;
    }
    return '${member.userId.substring(0, 8)}...';
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
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$title: ${context.tr(en: 'contains', sk: 'obsahuje')} ${warning.matchedSignals.join(', ')}.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MealPlanFilterBar extends StatelessWidget {
  const _MealPlanFilterBar({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final MealPlanFilter selectedFilter;
  final ValueChanged<MealPlanFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: Text(context.tr(en: 'All', sk: 'Všetko')),
            selected: selectedFilter == MealPlanFilter.all,
            onSelected: (_) => onFilterChanged(MealPlanFilter.all),
          ),
          FilterChip(
            label: Text(context.tr(en: 'Upcoming', sk: 'Nadchádzajúce')),
            selected: selectedFilter == MealPlanFilter.upcoming,
            onSelected: (_) => onFilterChanged(MealPlanFilter.upcoming),
          ),
          FilterChip(
            label: Text(context.tr(en: 'My cooking', sk: 'Moje varenie')),
            selected: selectedFilter == MealPlanFilter.assignedToMe,
            onSelected: (_) => onFilterChanged(MealPlanFilter.assignedToMe),
          ),
        ],
      ),
    );
  }
}

class _MealNutritionRow extends StatelessWidget {
  const _MealNutritionRow({required this.nutrition});

  final RecipeNutritionEstimate nutrition;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _MealInfoChip(
          label:
              '${nutrition.caloriesTotal} ${context.tr(en: 'kcal', sk: 'kcal')}',
          color: const Color(0xFFFFF0D9),
        ),
        _MealInfoChip(
          label:
              '${nutrition.proteinTotal.toStringAsFixed(1)} g ${context.tr(en: 'protein', sk: 'bielkoviny')}',
          color: const Color(0xFFE7F3E8),
        ),
        _MealInfoChip(
          label:
              '${nutrition.fiberTotal.toStringAsFixed(1)} g ${context.tr(en: 'fiber', sk: 'vláknina')}',
          color: const Color(0xFFE8EEF8),
        ),
      ],
    );
  }
}

class _MealInfoChip extends StatelessWidget {
  const _MealInfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MealPlanViewData {
  final List<MealPlanEntry> entries;
  final List<Recipe> recipes;
  final List<HouseholdMember> members;
  final UserPreferences? preferences;

  const _MealPlanViewData({
    required this.entries,
    required this.recipes,
    required this.members,
    required this.preferences,
  });
}

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matchedSignals;

  const _FoodSafetyWarning({required this.type, required this.matchedSignals});
}
