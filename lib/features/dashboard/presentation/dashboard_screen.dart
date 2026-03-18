import 'package:flutter/material.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/data/scan_sessions_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../food_items/domain/scan_session.dart';
import '../../food_items/presentation/scan_history_screen.dart';
import '../../households/domain/household.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../staples/data/staple_food_repository.dart';
import '../../staples/domain/staple_food.dart';
import '../../staples/presentation/staple_foods_screen.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../meal_plan/presentation/meal_plan_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Household household;
  final int pantryRefreshToken;
  final int shoppingListRefreshToken;
  final VoidCallback onOpenPantry;
  final VoidCallback onOpenShoppingList;
  final VoidCallback onOpenRecipes;
  final ValueChanged<String> onOpenRecipe;
  final VoidCallback onShoppingListChanged;
  final int recipesRefreshToken;
  final int mealPlanRefreshToken;

  const DashboardScreen({
    super.key,
    required this.household,
    required this.pantryRefreshToken,
    required this.shoppingListRefreshToken,
    required this.onOpenPantry,
    required this.onOpenShoppingList,
    required this.onOpenRecipes,
    required this.onOpenRecipe,
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

  late Future<_DashboardData> _dashboardFuture = _loadDashboard();

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

  Future<_DashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      _foodItemsRepository.getFoodItems(),
      _shoppingListRepository.getShoppingListItems(),
      _recipesRepository.getRecipes(),
      _stapleFoodRepository.getStapleFoods(),
      _scanSessionsRepository.getScanSessions(),
      _mealPlanRepository.getEntries(),
    ]);

    final pantryItems = results[0] as List<FoodItem>;
    final shoppingItems = results[1] as List<ShoppingListItem>;
    final recipes = results[2] as List<Recipe>;
    final stapleFoods = results[3] as List<StapleFood>;
    final scans = results[4] as List<ScanSession>;
    final mealPlanEntries = results[5] as List<MealPlanEntry>;

    return _DashboardData(
      pantryItems: pantryItems,
      shoppingItems: shoppingItems,
      recipes: recipes,
      stapleFoods: stapleFoods,
      scans: scans,
      mealPlanEntries: mealPlanEntries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<_DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Failed to load dashboard.',
              onRetry: _reload,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return AppEmptyState(
              message: 'No dashboard data yet.',
              onRefresh: _reload,
            );
          }

          final expiringSoon = data.pantryItems
              .where((item) => _daysUntil(item.expirationDate) <= 3)
              .length;
          final lowStock = data.pantryItems.where(_isLowStock).length;
          final toBuy = data.shoppingItems
              .where((item) => !item.isBought)
              .length;
          final recentScan = data.scans.isEmpty ? null : data.scans.first;

          final expiringItems = [...data.pantryItems]
            ..retainWhere((item) => _daysUntil(item.expirationDate) <= 3)
            ..sort(
              (a, b) => _daysUntil(
                a.expirationDate,
              ).compareTo(_daysUntil(b.expirationDate)),
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

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Household overview',
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
                      title: 'Expiring soon',
                      value: expiringSoon.toString(),
                      subtitle: 'Next 3 days',
                      icon: Icons.schedule_rounded,
                      onTap: widget.onOpenPantry,
                    ),
                    _MetricCard(
                      title: 'Low stock',
                      value: lowStock.toString(),
                      subtitle: 'Needs attention',
                      icon: Icons.warning_amber_rounded,
                      onTap: widget.onOpenPantry,
                    ),
                    _MetricCard(
                      title: 'To buy',
                      value: toBuy.toString(),
                      subtitle: 'Active shopping items',
                      icon: Icons.shopping_cart_outlined,
                      onTap: widget.onOpenShoppingList,
                    ),
                    _MetricCard(
                      title: 'Recipes',
                      value: data.recipes.length.toString(),
                      subtitle: 'Available to compare',
                      icon: Icons.menu_book_outlined,
                      onTap: widget.onOpenRecipes,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Quick actions',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenPantry,
                        icon: const Icon(Icons.kitchen_outlined),
                        label: const Text('Open pantry'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenShoppingList,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Shopping list'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenRecipes,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Recipes'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openStaples,
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: const Text('Staple foods'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openMealPlan,
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('Meal plan'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Use soon',
                  trailing: TextButton(
                    onPressed: widget.onOpenPantry,
                    child: const Text('Open pantry'),
                  ),
                  child: expiringItems.isEmpty
                      ? const Text('Nothing is close to expiration right now.')
                      : Column(
                          children: expiringItems.take(4).map((item) {
                            return _DashboardRow(
                              title: item.name,
                              subtitle:
                                  '${_expiryLabel(item.expirationDate)} • ${_formatQuantity(item.quantity)} ${item.unit}',
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Low stock items',
                  trailing: TextButton(
                    onPressed: widget.onOpenPantry,
                    child: const Text('Open pantry'),
                  ),
                  child: lowStockItems.isEmpty
                      ? const Text('No low stock items at the moment.')
                      : Column(
                          children: lowStockItems.take(4).map((item) {
                            return _DashboardRow(
                              title: item.name,
                              subtitle:
                                  '${_formatQuantity(item.quantity)} ${item.unit} left • limit ${_formatQuantity(item.lowStockThreshold!)} ${item.unit}',
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Cook again',
                  trailing: TextButton(
                    onPressed: widget.onOpenRecipes,
                    child: const Text('Open recipes'),
                  ),
                  child: favoriteRecipes.isEmpty
                      ? const Text('No favorite recipes yet.')
                      : Column(
                          children: favoriteRecipes.map((recipe) {
                            final recipeMatch = _matchRecipeSummary(
                              recipe,
                              data.pantryItems,
                            );
                            return _DashboardRow(
                              title: recipe.name,
                              subtitle:
                                  '${recipeMatch.available} available • ${recipeMatch.partial} partial • ${recipeMatch.missing} missing',
                              onTap: () => widget.onOpenRecipe(recipe.id),
                              actionLabel: 'Cook now',
                              onActionTap: () => widget.onOpenRecipe(recipe.id),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Staples missing',
                  trailing: TextButton(
                    onPressed: _openStaples,
                    child: const Text('Open staples'),
                  ),
                  child: missingStaples.isEmpty
                      ? const Text('All staple foods are covered right now.')
                      : Column(
                          children: missingStaples.take(4).map((gap) {
                            return _DashboardRow(
                              title: gap.staple.name,
                              subtitle:
                                  'Missing ${_formatQuantity(gap.missingQuantity)} ${gap.staple.unit} to reach target ${_formatQuantity(gap.staple.quantity)} ${gap.staple.unit}',
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Shopping focus',
                  trailing: TextButton(
                    onPressed: widget.onOpenShoppingList,
                    child: const Text('Open list'),
                  ),
                  child: latestToBuy.isEmpty
                      ? const Text('Shopping list is clear.')
                      : Column(
                          children: latestToBuy.map((item) {
                            return _DashboardRow(
                              title: item.name,
                              subtitle:
                                  '${_formatQuantity(item.quantity)} ${item.unit} • ${_shoppingSourceLabel(item.source)}',
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Upcoming meals',
                  trailing: TextButton(
                    onPressed: _openMealPlan,
                    child: const Text('Open meal plan'),
                  ),
                  child: upcomingMeals.isEmpty
                      ? const Text('No meal plan entries yet.')
                      : Column(
                          children: upcomingMeals.map((entry) {
                            return _DashboardRow(
                              title: entry.recipeName,
                              subtitle:
                                  '${_formatDate(entry.scheduledFor)} • ${_mealTypeLabel(entry.mealType)}',
                              onTap: _openMealPlan,
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Latest scan',
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
                          child: const Text('Open history'),
                        ),
                  child: recentScan == null
                      ? const Text('No fridge scan yet.')
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recentScan.imageLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_formatDateTime(recentScan.createdAt)} • ${recentScan.candidates.where((item) => item.isSelected).length} confirmed',
                                  ),
                                  if (recentScan.analysisError != null &&
                                      recentScan.analysisError!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Used fallback detection.',
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

  const _DashboardData({
    required this.pantryItems,
    required this.shoppingItems,
    required this.recipes,
    required this.stapleFoods,
    required this.scans,
    required this.mealPlanEntries,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
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

String _expiryLabel(DateTime? value) {
  final days = _daysUntil(value);
  if (days < 0) {
    return 'Expired';
  }
  if (days == 0) {
    return 'Today';
  }
  if (days == 1) {
    return 'Tomorrow';
  }
  return 'In $days days';
}

String _shoppingSourceLabel(String source) {
  switch (source) {
    case ShoppingListItem.sourceLowStock:
      return 'Low stock';
    case ShoppingListItem.sourceRecipeMissing:
      return 'Recipe';
    case ShoppingListItem.sourceMultiple:
      return 'Multiple';
    default:
      return 'Manual';
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

String _mealTypeLabel(String value) {
  return switch (value) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' => 'Snack',
    _ => 'Meal',
  };
}
