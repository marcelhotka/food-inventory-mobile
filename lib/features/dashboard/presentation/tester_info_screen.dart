import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';

class TesterInfoScreen extends StatefulWidget {
  final Household household;

  const TesterInfoScreen({super.key, required this.household});

  static const buildLabel = '1.0.0+1';

  @override
  State<TesterInfoScreen> createState() => _TesterInfoScreenState();
}

class _TesterInfoScreenState extends State<TesterInfoScreen> {
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );
  late final RecipesRepository _recipesRepository = RecipesRepository(
    householdId: widget.household.id,
  );

  bool _isLoadingSampleData = false;

  Future<void> _loadSampleData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'You need to be signed in.',
          sk: 'Musíš byť prihlásený.',
        ),
      );
      return;
    }

    setState(() {
      _isLoadingSampleData = true;
    });

    try {
      final pantryItems = await _foodItemsRepository.getFoodItems();
      final shoppingItems = await _shoppingListRepository
          .getShoppingListItems();
      final mealPlanEntries = await _mealPlanRepository.getEntries();
      final recipes = await _recipesRepository.getRecipes();
      final now = DateTime.now();
      final nowUtc = DateTime.now().toUtc();

      final pantryKeys = pantryItems
          .map((item) => _itemKey(item.name, item.unit))
          .toSet();
      final shoppingKeys = shoppingItems
          .where((item) => !item.isBought)
          .map((item) => _itemKey(item.name, item.unit))
          .toSet();
      final mealPlanKeys = mealPlanEntries
          .map(
            (entry) =>
                '${entry.recipeId ?? entry.recipeName}|${entry.scheduledFor.toIso8601String().split('T').first}|${entry.mealType}',
          )
          .toSet();

      final samplePantry = [
        FoodItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Mlieko',
          barcode: null,
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 1,
          lowStockThreshold: 1,
          unit: 'l',
          expirationDate: DateTime(now.year, now.month, now.day + 2),
          openedAt: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        FoodItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Vajcia',
          barcode: null,
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 6,
          lowStockThreshold: 6,
          unit: 'pcs',
          expirationDate: DateTime(now.year, now.month, now.day + 5),
          openedAt: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        FoodItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Syr',
          barcode: null,
          category: 'dairy',
          storageLocation: 'fridge',
          quantity: 150,
          lowStockThreshold: 100,
          unit: 'g',
          expirationDate: DateTime(now.year, now.month, now.day + 3),
          openedAt: nowUtc.subtract(const Duration(days: 1)),
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        FoodItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Chlieb',
          barcode: null,
          category: 'grains',
          storageLocation: 'pantry',
          quantity: 1,
          lowStockThreshold: 1,
          unit: 'pcs',
          expirationDate: DateTime(now.year, now.month, now.day + 1),
          openedAt: null,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      ];

      final sampleShopping = [
        ShoppingListItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Maslo',
          quantity: 250,
          unit: 'g',
          source: ShoppingListItem.sourceManual,
          isBought: false,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        ShoppingListItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: 'Paradajková omáčka',
          quantity: 1,
          unit: 'pcs',
          source: ShoppingListItem.sourceRecipeMissing,
          isBought: false,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      ];

      final omelette = recipes.cast<dynamic>().firstWhere(
        (recipe) => recipe.id == 'omelette',
        orElse: () => null,
      );
      final pasta = recipes.cast<dynamic>().firstWhere(
        (recipe) => recipe.id == 'pasta',
        orElse: () => null,
      );

      final sampleMealPlan = [
        if (omelette != null)
          MealPlanEntry(
            id: '',
            householdId: widget.household.id,
            userId: user.id,
            recipeId: omelette.id as String,
            recipeName: omelette.name as String,
            servings: (omelette.defaultServings as int?) ?? 2,
            scheduledFor: DateTime(now.year, now.month, now.day),
            mealType: 'breakfast',
            note: null,
            createdAt: nowUtc,
            updatedAt: nowUtc,
          ),
        if (pasta != null)
          MealPlanEntry(
            id: '',
            householdId: widget.household.id,
            userId: user.id,
            recipeId: pasta.id as String,
            recipeName: pasta.name as String,
            servings: (pasta.defaultServings as int?) ?? 2,
            scheduledFor: DateTime(now.year, now.month, now.day + 1),
            mealType: 'dinner',
            note: null,
            createdAt: nowUtc,
            updatedAt: nowUtc,
          ),
      ];

      var addedPantry = 0;
      for (final item in samplePantry) {
        final key = _itemKey(item.name, item.unit);
        if (pantryKeys.contains(key)) {
          continue;
        }
        await _foodItemsRepository.addFoodItem(item);
        pantryKeys.add(key);
        addedPantry++;
      }

      var addedShopping = 0;
      for (final item in sampleShopping) {
        final key = _itemKey(item.name, item.unit);
        if (shoppingKeys.contains(key)) {
          continue;
        }
        await _shoppingListRepository.addShoppingListItem(item);
        shoppingKeys.add(key);
        addedShopping++;
      }

      var addedMeals = 0;
      for (final entry in sampleMealPlan) {
        final key =
            '${entry.recipeId ?? entry.recipeName}|${entry.scheduledFor.toIso8601String().split('T').first}|${entry.mealType}';
        if (mealPlanKeys.contains(key)) {
          continue;
        }
        await _mealPlanRepository.addEntry(entry);
        mealPlanKeys.add(key);
        addedMeals++;
      }

      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Sample data loaded: $addedPantry pantry, $addedShopping shopping, $addedMeals meal plan.',
          sk: 'Ukážkové dáta nahraté: $addedPantry špajza, $addedShopping nákup, $addedMeals jedálniček.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to load sample data.',
          sk: 'Ukážkové dáta sa nepodarilo nahrať.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSampleData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Tester info', sk: 'Tester info')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: context.tr(en: 'Current build', sk: 'Aktuálny build'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Version ${TesterInfoScreen.buildLabel}',
                    sk: 'Verzia ${TesterInfoScreen.buildLabel}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _isLoadingSampleData ? null : _loadSampleData,
                  icon: _isLoadingSampleData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    _isLoadingSampleData
                        ? context.tr(en: 'Loading...', sk: 'Nahrávam...')
                        : context.tr(
                            en: 'Load sample test data',
                            sk: 'Nahrať ukážkové dáta',
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(
              en: 'Recommended test flow',
              sk: 'Odporúčaný test',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Open Preferences and try the sample tester profile.',
                    sk: 'Otvor Preferencie a skús ukážkový testerský profil.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Use sample data or add a few Pantry items and test expiring soon, opened items, and low stock.',
                    sk: 'Použi ukážkové dáta alebo pridaj pár pantry položiek a vyskúšaj čoskoro sa minie, otvorené položky a málo zásob.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Use Shopping List, mark items as bought, and move them to Pantry.',
                    sk: 'Použi nákupný zoznam, označ položky ako kúpené a presuň ich do špajze.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Try Recipes, serving changes, and add missing ingredients.',
                    sk: 'Skús Recepty, zmenu porcií a pridanie chýbajúcich ingrediencií.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Test Meal plan, Quick command, Notifications, Barcode lookup, and Fridge scan.',
                    sk: 'Otestuj Jedálniček, Rýchly príkaz, Upozornenia, sken kódu a sken chladničky.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(en: 'What to watch', sk: 'Na čo sa zamerať'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Anything confusing or hard to find.',
                    sk: 'Čokoľvek, čo je mätúce alebo ťažko nájditeľné.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Unexpected duplicate items or quantity issues.',
                    sk: 'Nečakané duplicity položiek alebo problémy s množstvom.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Flows that need too many taps to finish.',
                    sk: 'Flowy, ktoré potrebujú priveľa klikov na dokončenie.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'Places where the dashboard feels too dense.',
                    sk: 'Miesta, kde dashboard pôsobí príliš nahusto.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(en: 'Best test setup', sk: 'Najlepší test setup'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletText(
                  text: context.tr(
                    en: 'Use Chrome for quick retesting and iPhone build for real-device checks.',
                    sk: 'Na rýchle retesty používaj Chrome a na kontrolu reálneho zariadenia iPhone build.',
                  ),
                ),
                _BulletText(
                  text: context.tr(
                    en: 'If a flow feels slow, note the exact action that caused it.',
                    sk: 'Ak flow pôsobí pomaly, poznač si presne akciu, pri ktorej sa to stalo.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('• $text'),
    );
  }
}

String _itemKey(String name, String unit) {
  return '${_normalizeValue(name)}|${_normalizeUnit(unit)}';
}

String _normalizeValue(String value) {
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
  if (const {
    'pcs',
    'pc',
    'piece',
    'pieces',
    'ks',
    'kus',
    'kusy',
    'kusov',
  }.contains(normalized)) {
    return 'pcs';
  }
  if (const {'g', 'gram', 'grams', 'gramy', 'gramov'}.contains(normalized)) {
    return 'g';
  }
  if (const {'kg', 'kilogram', 'kilograms', 'kilo'}.contains(normalized)) {
    return 'kg';
  }
  if (const {
    'ml',
    'milliliter',
    'milliliters',
    'mililitre',
  }.contains(normalized)) {
    return 'ml';
  }
  if (const {'l', 'liter', 'liters', 'litre', 'litra'}.contains(normalized)) {
    return 'l';
  }
  return normalized;
}
