import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/data/scan_sessions_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../food_items/domain/scan_session.dart';
import '../../food_items/presentation/scan_history_screen.dart';
import '../../households/domain/household.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_ingredient.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import 'tester_info_screen.dart';
import 'notifications_screen.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../staples/data/staple_food_repository.dart';
import '../../staples/domain/staple_food.dart';
import '../../staples/presentation/staple_foods_screen.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../meal_plan/presentation/meal_plan_screen.dart';
import '../../quick_commands/presentation/quick_command_screen.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../../user_preferences/presentation/user_preferences_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Household household;
  final int pantryRefreshToken;
  final int shoppingListRefreshToken;
  final VoidCallback onOpenPantry;
  final VoidCallback onOpenExpiringSoon;
  final VoidCallback onOpenShoppingList;
  final VoidCallback onOpenRecipes;
  final VoidCallback onOpenSafeRecipes;
  final ValueChanged<String> onOpenRecipe;
  final VoidCallback onPantryChanged;
  final VoidCallback onShoppingListChanged;
  final int recipesRefreshToken;
  final int mealPlanRefreshToken;

  const DashboardScreen({
    super.key,
    required this.household,
    required this.pantryRefreshToken,
    required this.shoppingListRefreshToken,
    required this.onOpenPantry,
    required this.onOpenExpiringSoon,
    required this.onOpenShoppingList,
    required this.onOpenRecipes,
    required this.onOpenSafeRecipes,
    required this.onOpenRecipe,
    required this.onPantryChanged,
    required this.onShoppingListChanged,
    required this.recipesRefreshToken,
    required this.mealPlanRefreshToken,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final RecipesRepository _recipesRepository = RecipesRepository(
    householdId: widget.household.id,
  );
  late final StapleFoodRepository _stapleFoodRepository = StapleFoodRepository(
    householdId: widget.household.id,
  );
  late final ScanSessionsRepository _scanSessionsRepository =
      ScanSessionsRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();

  late Future<_DashboardData> _dashboardFuture = _loadDashboard();

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pantryRefreshToken != widget.pantryRefreshToken ||
        oldWidget.shoppingListRefreshToken != widget.shoppingListRefreshToken ||
        oldWidget.recipesRefreshToken != widget.recipesRefreshToken ||
        oldWidget.mealPlanRefreshToken != widget.mealPlanRefreshToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await _dashboardFuture;
  }

  Future<void> _openStaples() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StapleFoodsScreen(
          householdId: widget.household.id,
          onShoppingListChanged: widget.onShoppingListChanged,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _openMealPlan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealPlanScreen(
          householdId: widget.household.id,
          onShoppingListChanged: widget.onShoppingListChanged,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _openPreferences() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UserPreferencesScreen()));

    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _openQuickCommand() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickCommandScreen(
          householdId: widget.household.id,
          onPantryChanged: widget.onPantryChanged,
          onShoppingListChanged: widget.onShoppingListChanged,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _openTesterInfo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TesterInfoScreen(household: widget.household),
      ),
    );
    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          household: widget.household,
          onOpenPantry: widget.onOpenPantry,
          onOpenShoppingList: widget.onOpenShoppingList,
          onOpenMealPlan: _openMealPlan,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _reload();
  }

  Future<_DashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      _foodItemsRepository.getFoodItems(),
      _shoppingListRepository.getShoppingListItems(),
      _recipesRepository.getRecipes(),
      _stapleFoodRepository.getStapleFoods(),
      _scanSessionsRepository.getScanSessions(),
      _mealPlanRepository.getEntries(),
      _loadPreferencesSafely(),
    ]);

    final pantryItems = results[0] as List<FoodItem>;
    final shoppingItems = results[1] as List<ShoppingListItem>;
    final recipes = results[2] as List<Recipe>;
    final stapleFoods = results[3] as List<StapleFood>;
    final scans = results[4] as List<ScanSession>;
    final mealPlanEntries = results[5] as List<MealPlanEntry>;
    final preferences = results[6] as UserPreferences?;

    return _DashboardData(
      pantryItems: pantryItems,
      shoppingItems: shoppingItems,
      recipes: recipes,
      stapleFoods: stapleFoods,
      scans: scans,
      mealPlanEntries: mealPlanEntries,
      preferences: preferences,
    );
  }

  Future<UserPreferences?> _loadPreferencesSafely() async {
    try {
      return await _userPreferencesRepository.getCurrentUserPreferences();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Dashboard', sk: 'Prehľad')),
        actions: [
          FutureBuilder<_DashboardData>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final count = data == null
                  ? 0
                  : data.pantryItems
                            .where(
                              (item) => _daysUntil(item.expirationDate) <= 3,
                            )
                            .length +
                        data.shoppingItems
                            .where((item) => !item.isBought)
                            .take(6)
                            .length +
                        data.mealPlanEntries
                            .where(
                              (entry) => _daysUntil(entry.scheduledFor) <= 1,
                            )
                            .length +
                        data.pantryItems
                            .where((item) => item.openedAt != null)
                            .length +
                        data.pantryItems.where(_isLowStock).length;

              return IconButton(
                onPressed: _openNotifications,
                tooltip: context.tr(en: 'Notifications', sk: 'Upozornenia'),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded),
                    if (count > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE07A5F),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune_rounded),
            tooltip: context.tr(en: 'Preferences', sk: 'Preferencie'),
          ),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: context.tr(
                en: 'Failed to load dashboard.',
                sk: 'Prehľad sa nepodarilo načítať.',
              ),
              onRetry: _reload,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return AppEmptyState(
              message: context.tr(
                en: 'No dashboard data yet.',
                sk: 'Zatiaľ nie sú k dispozícii žiadne údaje pre prehľad.',
              ),
              onRefresh: _reload,
            );
          }

          final expiringSoon = data.pantryItems
              .where((item) => _daysUntil(item.expirationDate) <= 3)
              .length;
          final openedItems =
              data.pantryItems.where((item) => item.openedAt != null).toList()
                ..sort((a, b) => b.openedAt!.compareTo(a.openedAt!));
          final lowStock = data.pantryItems.where(_isLowStock).length;
          final toBuy = data.shoppingItems
              .where((item) => !item.isBought)
              .length;
          final recentScan = data.scans.isEmpty ? null : data.scans.first;
          final hasSafetyPreferences =
              data.preferences != null &&
              (data.preferences!.allergies.isNotEmpty ||
                  data.preferences!.intolerances.isNotEmpty);
          final safeRecommendedRecipes = _recommendedSafeRecipes(
            data.recipes,
            data.pantryItems,
            data.preferences,
          ).take(4).toList();
          final avoidedRecipes = _avoidedRecipes(
            data.recipes,
            data.preferences,
          ).take(3).toList();

          final expiringItems = [...data.pantryItems]
            ..retainWhere((item) => _daysUntil(item.expirationDate) <= 3)
            ..sort(
              (a, b) => _daysUntil(
                a.expirationDate,
              ).compareTo(_daysUntil(b.expirationDate)),
            );
          final useSoonItems = _buildUseSoonItems(
            pantryItems: data.pantryItems,
            openedItems: openedItems,
            expiringItems: expiringItems,
          );

          final lowStockItems = data.pantryItems.where(_isLowStock).toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

          final latestToBuy = data.shoppingItems
              .where((item) => !item.isBought)
              .take(4)
              .toList();
          final favoriteRecipes = data.recipes
              .where((recipe) => recipe.isFavorite)
              .take(4)
              .toList();
          final missingStaples =
              data.stapleFoods
                  .map(
                    (staple) => _StapleGap(
                      staple: staple,
                      missingQuantity: _calculateMissingStapleQuantity(
                        staple,
                        data.pantryItems,
                      ),
                    ),
                  )
                  .where((gap) => gap.missingQuantity > 0.0001)
                  .toList()
                ..sort(
                  (a, b) => b.missingQuantity.compareTo(a.missingQuantity),
                );
          final upcomingMeals = data.mealPlanEntries.take(4).toList();
          final myShoppingTasks =
              data.shoppingItems
                  .where(
                    (item) =>
                        !item.isBought &&
                        item.assignedToUserId == _currentUserId,
                  )
                  .toList()
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final visibleShoppingTasks = myShoppingTasks.take(4).toList();
          final myCookingTasks = data.mealPlanEntries
              .where(
                (entry) =>
                    entry.assignedCookUserId == _currentUserId &&
                    !_isPastMeal(entry.scheduledFor),
              )
              .take(3)
              .toList();
          final myTaskCount =
              visibleShoppingTasks.length + myCookingTasks.length;
          final hiddenOverviewCount =
              avoidedRecipes.length +
              openedItems.length +
              lowStockItems.length +
              favoriteRecipes.length +
              missingStaples.length +
              latestToBuy.length +
              upcomingMeals.length +
              (recentScan == null ? 0 : 1);
          final hiddenOverviewSubtitle = hiddenOverviewCount == 0
              ? context.tr(
                  en: 'No extra details need attention right now.',
                  sk: 'Momentálne netreba riešiť žiadne ďalšie detaily.',
                )
              : context.tr(
                  en: '$hiddenOverviewCount extra details: avoid, opened, low stock, shopping and meal plan.',
                  sk: '$hiddenOverviewCount ďalších detailov: vyhnúť sa, otvorené, nízke zásoby, nákup a jedálniček.',
                );

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.tr(
                    en: 'Household overview',
                    sk: 'Prehľad domácnosti',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.household.name,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      title: context.tr(
                        en: 'Expiring soon',
                        sk: 'Čoskoro sa minie',
                      ),
                      value: expiringSoon.toString(),
                      subtitle: context.tr(
                        en: 'Next 3 days',
                        sk: 'Najbližšie 3 dni',
                      ),
                      icon: Icons.schedule_rounded,
                      onTap: widget.onOpenExpiringSoon,
                    ),
                    _MetricCard(
                      title: context.tr(en: 'Low stock', sk: 'Málo zásob'),
                      value: lowStock.toString(),
                      subtitle: context.tr(
                        en: 'Needs attention',
                        sk: 'Treba doplniť',
                      ),
                      icon: Icons.warning_amber_rounded,
                      onTap: widget.onOpenPantry,
                    ),
                    _MetricCard(
                      title: context.tr(en: 'Opened', sk: 'Otvorené'),
                      value: openedItems.length.toString(),
                      subtitle: context.tr(
                        en: 'Already opened',
                        sk: 'Už otvorené',
                      ),
                      icon: Icons.inventory_2_outlined,
                      onTap: widget.onOpenPantry,
                    ),
                    _MetricCard(
                      title: context.tr(en: 'To buy', sk: 'Kúpiť'),
                      value: toBuy.toString(),
                      subtitle: context.tr(
                        en: 'Active shopping items',
                        sk: 'Aktívne položky na nákup',
                      ),
                      icon: Icons.shopping_cart_outlined,
                      onTap: widget.onOpenShoppingList,
                    ),
                    _MetricCard(
                      title: context.tr(en: 'Recipes', sk: 'Recepty'),
                      value: data.recipes.length.toString(),
                      subtitle: context.tr(
                        en: 'Available to compare',
                        sk: 'Dostupné na porovnanie',
                      ),
                      icon: Icons.menu_book_outlined,
                      onTap: widget.onOpenRecipes,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: context.tr(en: 'Quick actions', sk: 'Rýchle akcie'),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenPantry,
                        icon: const Icon(Icons.kitchen_outlined),
                        label: Text(
                          context.tr(en: 'Open pantry', sk: 'Otvoriť špajzu'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenShoppingList,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: Text(
                          context.tr(en: 'Shopping list', sk: 'Nákupný zoznam'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenRecipes,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(context.tr(en: 'Recipes', sk: 'Recepty')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openStaples,
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: Text(
                          context.tr(
                            en: 'Staple foods',
                            sk: 'Základné potraviny',
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openMealPlan,
                        icon: const Icon(Icons.event_note_outlined),
                        label: Text(
                          context.tr(en: 'Meal plan', sk: 'Jedálniček'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openQuickCommand,
                        icon: const Icon(Icons.mic_none_rounded),
                        label: Text(
                          context.tr(en: 'Quick command', sk: 'Rýchly príkaz'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openPreferences,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          context.tr(en: 'Preferences', sk: 'Preferencie'),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openTesterInfo,
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          context.tr(en: 'Tester info', sk: 'Tester info'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (myTaskCount > 0) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: context.tr(en: 'My tasks', sk: 'Moje úlohy'),
                    child: Column(
                      children: [
                        ...visibleShoppingTasks.map((item) {
                          return _DashboardRow(
                            title: localizedIngredientDisplayName(
                              context,
                              item.name,
                            ),
                            subtitle:
                                '${context.tr(en: 'Shopping', sk: 'Nákup')} • ${_formatQuantity(item.quantity)} ${item.unit}',
                            onTap: widget.onOpenShoppingList,
                            actionLabel: context.tr(en: 'Open', sk: 'Otvoriť'),
                            onActionTap: widget.onOpenShoppingList,
                          );
                        }),
                        ...myCookingTasks.map((entry) {
                          final matchingRecipe = _findRecipeById(
                            data.recipes,
                            entry.recipeId,
                          );
                          return _DashboardRow(
                            title: matchingRecipe == null
                                ? entry.recipeName
                                : localizedRecipeName(context, matchingRecipe),
                            subtitle:
                                '${context.tr(en: 'Cooking', sk: 'Varenie')} • ${_formatDate(entry.scheduledFor)} • ${_mealTypeLabel(context, entry.mealType)}',
                            onTap: _openMealPlan,
                            actionLabel: context.tr(en: 'Open', sk: 'Otvoriť'),
                            onActionTap: _openMealPlan,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: context.tr(
                    en: 'Safe for you',
                    sk: 'Bezpečné pre teba',
                  ),
                  trailing: TextButton(
                    onPressed: hasSafetyPreferences
                        ? widget.onOpenSafeRecipes
                        : _openPreferences,
                    child: Text(
                      hasSafetyPreferences
                          ? context.tr(
                              en: 'Open recipes',
                              sk: 'Otvoriť recepty',
                            )
                          : context.tr(
                              en: 'Set preferences',
                              sk: 'Nastaviť preferencie',
                            ),
                    ),
                  ),
                  child: !hasSafetyPreferences
                      ? Text(
                          context.tr(
                            en: 'Add allergies or intolerances in Preferences to get personalized safe recipe recommendations.',
                            sk: 'Pridaj alergie alebo intolerancie v Preferenciách a získaj osobné bezpečné odporúčania receptov.',
                          ),
                        )
                      : safeRecommendedRecipes.isEmpty
                      ? Text(
                          context.tr(
                            en: 'No safe recipe recommendations yet. Try adding more recipes or updating your pantry.',
                            sk: 'Zatiaľ nemáme bezpečné odporúčania receptov. Skús pridať viac receptov alebo upraviť zásoby.',
                          ),
                        )
                      : Column(
                          children: safeRecommendedRecipes.map((recipe) {
                            final recipeMatch = _matchRecipeSummary(
                              recipe,
                              data.pantryItems,
                            );
                            return _DashboardRow(
                              title: localizedRecipeName(context, recipe),
                              subtitle:
                                  '${recipeMatch.available} ${context.tr(en: 'available', sk: 'dostupné')} • ${recipeMatch.partial} ${context.tr(en: 'partial', sk: 'čiastočne')} • ${recipeMatch.missing} ${context.tr(en: 'missing', sk: 'chýba')}',
                              onTap: () => widget.onOpenRecipe(recipe.id),
                              actionLabel: context.tr(
                                en: 'Cook now',
                                sk: 'Variť teraz',
                              ),
                              onActionTap: () => widget.onOpenRecipe(recipe.id),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: context.tr(en: 'Use soon', sk: 'Použi čoskoro'),
                  trailing: TextButton(
                    onPressed: widget.onOpenPantry,
                    child: Text(
                      context.tr(en: 'Open pantry', sk: 'Otvoriť špajzu'),
                    ),
                  ),
                  child: useSoonItems.isEmpty
                      ? Text(
                          context.tr(
                            en: 'Nothing urgent to use right now.',
                            sk: 'Momentálne netreba nič súrne použiť.',
                          ),
                        )
                      : Column(
                          children: useSoonItems.take(4).map((item) {
                            final useSoonDetails = <String>[];
                            if (item.openedAt != null) {
                              useSoonDetails.add(
                                '${context.tr(en: 'Opened', sk: 'Otvorené')} ${_formatDate(item.openedAt!)}',
                              );
                              final openedLabel = _openedUseSoonLabel(
                                context,
                                item,
                              );
                              if (openedLabel != null) {
                                useSoonDetails.add(openedLabel);
                              }
                            }
                            if (item.expirationDate != null) {
                              useSoonDetails.add(
                                _expiryLabel(context, item.expirationDate),
                              );
                            }
                            useSoonDetails.add(
                              '${_formatQuantity(item.quantity)} ${item.unit}',
                            );
                            return _DashboardRow(
                              title: localizedIngredientDisplayName(
                                context,
                                item.name,
                              ),
                              subtitle: useSoonDetails.join(' • '),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    context.tr(en: 'More overview', sk: 'Ďalšie prehľady'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(hiddenOverviewSubtitle),
                  children: [
                    _SectionCard(
                      title: context.tr(
                        en: 'Avoid for now',
                        sk: 'Zatiaľ sa vyhni',
                      ),
                      trailing: TextButton(
                        onPressed: hasSafetyPreferences
                            ? widget.onOpenRecipes
                            : _openPreferences,
                        child: Text(
                          hasSafetyPreferences
                              ? context.tr(
                                  en: 'Open recipes',
                                  sk: 'Otvoriť recepty',
                                )
                              : context.tr(
                                  en: 'Set preferences',
                                  sk: 'Nastaviť preferencie',
                                ),
                        ),
                      ),
                      child: !hasSafetyPreferences
                          ? Text(
                              context.tr(
                                en: 'Add allergies or intolerances in Preferences to see which recipes currently conflict with your needs.',
                                sk: 'Pridaj alergie alebo intolerancie v Preferenciách a uvidíš, ktoré recepty s nimi kolidujú.',
                              ),
                            )
                          : avoidedRecipes.isEmpty
                          ? Text(
                              context.tr(
                                en: 'Nothing currently conflicts with your saved allergies or intolerances.',
                                sk: 'Momentálne nič nekoliduje s tvojimi uloženými alergiami alebo intoleranciami.',
                              ),
                            )
                          : Column(
                              children: avoidedRecipes.map((recipe) {
                                final warning = _buildRecipeSafetyWarning(
                                  recipe,
                                  data.preferences,
                                );
                                final warningLabel = warning == null
                                    ? context.tr(
                                        en: 'Potential conflict',
                                        sk: 'Možný konflikt',
                                      )
                                    : '${_warningTypeLabel(context, warning.type)}: ${context.tr(en: 'contains', sk: 'obsahuje')} ${warning.matchedSignals.join(', ')}';
                                return _DashboardRow(
                                  title: localizedRecipeName(context, recipe),
                                  subtitle: warningLabel,
                                  onTap: () => widget.onOpenRecipe(recipe.id),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(
                        en: 'Opened items',
                        sk: 'Otvorené položky',
                      ),
                      trailing: TextButton(
                        onPressed: widget.onOpenPantry,
                        child: Text(
                          context.tr(en: 'Open pantry', sk: 'Otvoriť špajzu'),
                        ),
                      ),
                      child: openedItems.isEmpty
                          ? Text(
                              context.tr(
                                en: 'No opened pantry items right now.',
                                sk: 'Momentálne nemáš žiadne otvorené potraviny.',
                              ),
                            )
                          : Column(
                              children: openedItems.take(4).map((item) {
                                final openedLabel = _openedUseSoonLabel(
                                  context,
                                  item,
                                );
                                return _DashboardRow(
                                  title: localizedIngredientDisplayName(
                                    context,
                                    item.name,
                                  ),
                                  subtitle:
                                      '${context.tr(en: 'Opened', sk: 'Otvorené')} ${_formatDate(item.openedAt!)}${openedLabel == null ? '' : ' • $openedLabel'} • ${_formatQuantity(item.quantity)} ${item.unit}',
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(
                        en: 'Low stock items',
                        sk: 'Položky s nízkou zásobou',
                      ),
                      trailing: TextButton(
                        onPressed: widget.onOpenPantry,
                        child: Text(
                          context.tr(en: 'Open pantry', sk: 'Otvoriť špajzu'),
                        ),
                      ),
                      child: lowStockItems.isEmpty
                          ? Text(
                              context.tr(
                                en: 'No low stock items at the moment.',
                                sk: 'Momentálne nie sú žiadne položky s nízkou zásobou.',
                              ),
                            )
                          : Column(
                              children: lowStockItems.take(4).map((item) {
                                return _DashboardRow(
                                  title: localizedIngredientDisplayName(
                                    context,
                                    item.name,
                                  ),
                                  subtitle:
                                      '${_formatQuantity(item.quantity)} ${item.unit} ${context.tr(en: 'left', sk: 'zostáva')} • ${context.tr(en: 'limit', sk: 'limit')} ${_formatQuantity(item.lowStockThreshold!)} ${item.unit}',
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(en: 'Cook again', sk: 'Uvar znova'),
                      trailing: TextButton(
                        onPressed: widget.onOpenRecipes,
                        child: Text(
                          context.tr(en: 'Open recipes', sk: 'Otvoriť recepty'),
                        ),
                      ),
                      child: favoriteRecipes.isEmpty
                          ? Text(
                              context.tr(
                                en: 'No favorite recipes yet.',
                                sk: 'Zatiaľ nemáš obľúbené recepty.',
                              ),
                            )
                          : Column(
                              children: favoriteRecipes.map((recipe) {
                                final recipeMatch = _matchRecipeSummary(
                                  recipe,
                                  data.pantryItems,
                                );
                                return _DashboardRow(
                                  title: localizedRecipeName(context, recipe),
                                  subtitle:
                                      '${recipeMatch.available} ${context.tr(en: 'available', sk: 'dostupné')} • ${recipeMatch.partial} ${context.tr(en: 'partial', sk: 'čiastočne')} • ${recipeMatch.missing} ${context.tr(en: 'missing', sk: 'chýba')}',
                                  onTap: () => widget.onOpenRecipe(recipe.id),
                                  actionLabel: context.tr(
                                    en: 'Cook now',
                                    sk: 'Variť teraz',
                                  ),
                                  onActionTap: () =>
                                      widget.onOpenRecipe(recipe.id),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(
                        en: 'Staples missing',
                        sk: 'Chýbajúce základy',
                      ),
                      trailing: TextButton(
                        onPressed: _openStaples,
                        child: Text(
                          context.tr(en: 'Open staples', sk: 'Otvoriť základy'),
                        ),
                      ),
                      child: missingStaples.isEmpty
                          ? Text(
                              context.tr(
                                en: 'All staple foods are covered right now.',
                                sk: 'Všetky základné potraviny sú momentálne pokryté.',
                              ),
                            )
                          : Column(
                              children: missingStaples.take(4).map((gap) {
                                return _DashboardRow(
                                  title: gap.staple.name,
                                  subtitle:
                                      '${context.tr(en: 'Missing', sk: 'Chýba')} ${_formatQuantity(gap.missingQuantity)} ${gap.staple.unit} ${context.tr(en: 'to reach target', sk: 'do cieľa')} ${_formatQuantity(gap.staple.quantity)} ${gap.staple.unit}',
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(
                        en: 'Shopping focus',
                        sk: 'Nákupné priority',
                      ),
                      trailing: TextButton(
                        onPressed: widget.onOpenShoppingList,
                        child: Text(
                          context.tr(en: 'Open list', sk: 'Otvoriť zoznam'),
                        ),
                      ),
                      child: latestToBuy.isEmpty
                          ? Text(
                              context.tr(
                                en: 'Shopping list is clear.',
                                sk: 'Nákupný zoznam je čistý.',
                              ),
                            )
                          : Column(
                              children: latestToBuy.map((item) {
                                return _DashboardRow(
                                  title: localizedIngredientDisplayName(
                                    context,
                                    item.name,
                                  ),
                                  subtitle:
                                      '${_formatQuantity(item.quantity)} ${item.unit} • ${_shoppingSourceLabel(context, item.source)}',
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(
                        en: 'Upcoming meals',
                        sk: 'Plánované jedlá',
                      ),
                      trailing: TextButton(
                        onPressed: _openMealPlan,
                        child: Text(
                          context.tr(
                            en: 'Open meal plan',
                            sk: 'Otvoriť jedálniček',
                          ),
                        ),
                      ),
                      child: upcomingMeals.isEmpty
                          ? Text(
                              context.tr(
                                en: 'No meal plan entries yet.',
                                sk: 'Zatiaľ nemáš naplánované žiadne jedlá.',
                              ),
                            )
                          : Column(
                              children: upcomingMeals.map((entry) {
                                final matchingRecipe = _findRecipeById(
                                  data.recipes,
                                  entry.recipeId,
                                );
                                return _DashboardRow(
                                  title: matchingRecipe == null
                                      ? entry.recipeName
                                      : localizedRecipeName(
                                          context,
                                          matchingRecipe,
                                        ),
                                  subtitle:
                                      '${_formatDate(entry.scheduledFor)} • ${_mealTypeLabel(context, entry.mealType)} • ${entry.servings} ${context.tr(en: entry.servings == 1 ? 'serving' : 'servings', sk: entry.servings == 1 ? 'porcia' : 'porcie')}',
                                  onTap: _openMealPlan,
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: context.tr(en: 'Latest scan', sk: 'Posledný scan'),
                      trailing: recentScan == null
                          ? null
                          : TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ScanHistoryScreen(
                                      householdId: widget.household.id,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                context.tr(
                                  en: 'Open history',
                                  sk: 'Otvoriť históriu',
                                ),
                              ),
                            ),
                      child: recentScan == null
                          ? Text(
                              context.tr(
                                en: 'No fridge scan yet.',
                                sk: 'Zatiaľ nemáš žiadny scan chladničky.',
                              ),
                            )
                          : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ScanHistoryScreen(
                                        householdId: widget.household.id,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Ink(
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        recentScan.imageLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_formatDateTime(recentScan.createdAt)} • ${recentScan.candidates.where((item) => item.isSelected).length} confirmed',
                                      ),
                                      if (recentScan.analysisError != null &&
                                          recentScan
                                              .analysisError!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          context.tr(
                                            en: 'Used fallback detection.',
                                            sk: 'Použitá bola náhradná detekcia.',
                                          ),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final List<FoodItem> pantryItems;
  final List<ShoppingListItem> shoppingItems;
  final List<Recipe> recipes;
  final List<StapleFood> stapleFoods;
  final List<ScanSession> scans;
  final List<MealPlanEntry> mealPlanEntries;
  final UserPreferences? preferences;

  const _DashboardData({
    required this.pantryItems,
    required this.shoppingItems,
    required this.recipes,
    required this.stapleFoods,
    required this.scans,
    required this.mealPlanEntries,
    required this.preferences,
  });
}

class _StapleGap {
  final StapleFood staple;
  final double missingQuantity;

  const _StapleGap({required this.staple, required this.missingQuantity});
}

class _RecipeMatchSummary {
  final int available;
  final int partial;
  final int missing;

  const _RecipeMatchSummary({
    required this.available,
    required this.partial,
    required this.missing,
  });
}

class _RecipeRecommendation {
  final Recipe recipe;
  final _RecipeMatchSummary match;

  const _RecipeRecommendation({required this.recipe, required this.match});
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DDCF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final trailingWidget = trailing;
    final headerChildren = <Widget>[
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ];
    if (trailingWidget != null) {
      headerChildren.add(trailingWidget);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6DDCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: headerChildren),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DashboardRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _DashboardRow({
    required this.title,
    required this.subtitle,
    this.onTap,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (actionLabel != null && onActionTap != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilledButton.tonal(
                      onPressed: onActionTap,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isLowStock(FoodItem item) {
  final threshold = item.lowStockThreshold;
  if (threshold == null) {
    return false;
  }
  return item.quantity <= threshold;
}

_RecipeMatchSummary _matchRecipeSummary(Recipe recipe, List<FoodItem> pantry) {
  int available = 0;
  int partial = 0;
  int missing = 0;

  for (final ingredient in recipe.ingredients) {
    final matchedItems = pantry
        .where(
          (item) =>
              _normalizeName(item.name) == _normalizeName(ingredient.name),
        )
        .toList();

    if (matchedItems.isEmpty) {
      missing++;
      continue;
    }

    double availableQuantity = 0;
    for (final item in matchedItems) {
      final converted = _convertQuantity(
        quantity: item.quantity,
        fromUnit: item.unit,
        toUnit: ingredient.unit,
      );
      if (converted != null) {
        availableQuantity += converted;
      }
    }

    if (availableQuantity <= 0) {
      missing++;
    } else if (availableQuantity >= ingredient.quantity) {
      available++;
    } else {
      partial++;
    }
  }

  return _RecipeMatchSummary(
    available: available,
    partial: partial,
    missing: missing,
  );
}

List<Recipe> _recommendedSafeRecipes(
  List<Recipe> recipes,
  List<FoodItem> pantry,
  UserPreferences? preferences,
) {
  final recommendations =
      recipes
          .where(
            (recipe) => _buildRecipeSafetyWarning(recipe, preferences) == null,
          )
          .map(
            (recipe) => _RecipeRecommendation(
              recipe: recipe,
              match: _matchRecipeSummary(recipe, pantry),
            ),
          )
          .toList()
        ..sort((a, b) {
          final availabilityScoreA =
              (a.match.available * 2) + a.match.partial - (a.match.missing * 2);
          final availabilityScoreB =
              (b.match.available * 2) + b.match.partial - (b.match.missing * 2);
          final scoreComparison = availabilityScoreB.compareTo(
            availabilityScoreA,
          );
          if (scoreComparison != 0) {
            return scoreComparison;
          }
          return a.recipe.name.toLowerCase().compareTo(
            b.recipe.name.toLowerCase(),
          );
        });

  return recommendations.map((item) => item.recipe).toList();
}

List<Recipe> _avoidedRecipes(
  List<Recipe> recipes,
  UserPreferences? preferences,
) {
  final avoided =
      recipes
          .where(
            (recipe) => _buildRecipeSafetyWarning(recipe, preferences) != null,
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return avoided;
}

List<FoodItem> _buildUseSoonItems({
  required List<FoodItem> pantryItems,
  required List<FoodItem> openedItems,
  required List<FoodItem> expiringItems,
}) {
  final prioritizedById = <String, FoodItem>{};

  for (final item in openedItems) {
    prioritizedById[item.id] = item;
  }
  for (final item in expiringItems) {
    prioritizedById.putIfAbsent(item.id, () => item);
  }

  final useSoonItems = prioritizedById.values.toList()
    ..sort((a, b) {
      final aOpened = a.openedAt != null;
      final bOpened = b.openedAt != null;
      if (aOpened != bOpened) {
        return aOpened ? -1 : 1;
      }

      final openedDaysLeftComparison = _openedDaysLeft(
        a,
      ).compareTo(_openedDaysLeft(b));
      if (openedDaysLeftComparison != 0) {
        return openedDaysLeftComparison;
      }

      final aExpiryDays = _daysUntil(a.expirationDate);
      final bExpiryDays = _daysUntil(b.expirationDate);
      if (aExpiryDays != bExpiryDays) {
        return aExpiryDays.compareTo(bExpiryDays);
      }

      if (a.openedAt != null && b.openedAt != null) {
        return a.openedAt!.compareTo(b.openedAt!);
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  return useSoonItems;
}

int _openedUseWithinDays(FoodItem item) {
  switch (item.category) {
    case 'dairy':
      return 3;
    case 'meat':
      return 2;
    case 'produce':
      return 3;
    case 'canned':
      return 4;
    case 'frozen':
      return 2;
    case 'beverages':
      return 5;
    case 'grains':
      return 7;
    default:
      return 3;
  }
}

int _daysSinceOpened(DateTime? value) {
  if (value == null) {
    return 0;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final opened = DateTime(value.year, value.month, value.day);
  return today.difference(opened).inDays;
}

int _openedDaysLeft(FoodItem item) {
  if (item.openedAt == null) {
    return 9999;
  }
  return _openedUseWithinDays(item) - _daysSinceOpened(item.openedAt);
}

String? _openedUseSoonLabel(BuildContext context, FoodItem item) {
  if (item.openedAt == null) {
    return null;
  }

  final daysLeft = _openedDaysLeft(item);
  if (daysLeft < 0) {
    return context.tr(en: 'Use as soon as possible', sk: 'Použi čo najskôr');
  }
  if (daysLeft == 0) {
    return context.tr(
      en: 'Use today after opening',
      sk: 'Použi dnes po otvorení',
    );
  }
  if (daysLeft == 1) {
    return context.tr(en: 'Use within 1 day', sk: 'Použi do 1 dňa');
  }
  return context.tr(
    en: 'Use within $daysLeft days',
    sk: 'Použi do $daysLeft dní',
  );
}

_FoodSafetyWarning? _buildRecipeSafetyWarning(
  Recipe recipe,
  UserPreferences? preferences,
) {
  if (preferences == null) {
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

Recipe? _findRecipeById(List<Recipe> recipes, String? recipeId) {
  if (recipeId == null || recipeId.isEmpty) {
    return null;
  }

  for (final recipe in recipes) {
    if (recipe.id == recipeId) {
      return recipe;
    }
  }

  return null;
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

String _warningTypeLabel(BuildContext context, _FoodSafetyWarningType type) {
  switch (type) {
    case _FoodSafetyWarningType.allergy:
      return context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu');
    case _FoodSafetyWarningType.intolerance:
      return context.tr(
        en: 'Intolerance warning',
        sk: 'Upozornenie na intoleranciu',
      );
  }
}

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matchedSignals;

  const _FoodSafetyWarning({required this.type, required this.matchedSignals});
}

double _calculateMissingStapleQuantity(
  StapleFood staple,
  List<FoodItem> pantry,
) {
  double available = 0;

  for (final item in pantry) {
    if (_itemKey(item.name, item.unit) != _itemKey(staple.name, staple.unit)) {
      continue;
    }

    final converted = _convertQuantity(
      quantity: item.quantity,
      fromUnit: item.unit,
      toUnit: staple.unit,
    );
    if (converted != null) {
      available += converted;
    }
  }

  return staple.quantity - available;
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

int _daysUntil(DateTime? value) {
  if (value == null) {
    return 9999;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  return target.difference(today).inDays;
}

bool _isPastMeal(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final scheduled = DateTime(value.year, value.month, value.day);
  return scheduled.isBefore(today);
}

String _expiryLabel(BuildContext context, DateTime? value) {
  final days = _daysUntil(value);
  if (days < 0) {
    return context.tr(en: 'Expired', sk: 'Po záruke');
  }
  if (days == 0) {
    return context.tr(en: 'Today', sk: 'Dnes');
  }
  if (days == 1) {
    return context.tr(en: 'Tomorrow', sk: 'Zajtra');
  }
  return context.tr(en: 'In $days days', sk: 'O $days dní');
}

String _shoppingSourceLabel(BuildContext context, String source) {
  switch (source) {
    case ShoppingListItem.sourceLowStock:
      return context.tr(en: 'Low stock', sk: 'Málo zásob');
    case ShoppingListItem.sourceRecipeMissing:
      return context.tr(en: 'Recipe', sk: 'Recept');
    case ShoppingListItem.sourceMultiple:
      return context.tr(en: 'Multiple', sk: 'Viac zdrojov');
    default:
      return context.tr(en: 'Manual', sk: 'Ručne');
  }
}

String _formatQuantity(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

String _mealTypeLabel(BuildContext context, String value) {
  return switch (value) {
    'breakfast' => context.tr(en: 'Breakfast', sk: 'Raňajky'),
    'lunch' => context.tr(en: 'Lunch', sk: 'Obed'),
    'dinner' => context.tr(en: 'Dinner', sk: 'Večera'),
    'snack' => context.tr(en: 'Snack', sk: 'Snack'),
    _ => context.tr(en: 'Meal', sk: 'Jedlo'),
  };
}
