import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../data/tester_sample_data_service.dart';

class TesterInfoScreen extends StatefulWidget {
  final Household household;

  const TesterInfoScreen({super.key, required this.household});

  static const buildLabel = '1.0.0+1';

  @override
  State<TesterInfoScreen> createState() => _TesterInfoScreenState();
}

class _TesterInfoScreenState extends State<TesterInfoScreen> {
  static const _samplePantryNames = {'Mlieko', 'Vajcia', 'Syr', 'Chlieb'};
  static const _sampleShoppingNames = {'Maslo', 'Paradajková omáčka'};
  static const _sampleRecipeIds = {'omelette', 'pasta'};

  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );
  late final TesterSampleDataService _testerSampleDataService =
      TesterSampleDataService(household: widget.household);

  bool _isLoadingSampleData = false;
  bool _isClearingSampleData = false;

  String _feedbackTemplate(BuildContext context) {
    return context.tr(
      en: 'Tested flow:\nWhat I expected:\nWhat happened:\nSeverity:\nNotes / screenshot:',
      sk: 'Testovaný flow:\nČo som očakával:\nČo sa stalo:\nZávažnosť:\nPoznámka / screenshot:',
    );
  }

  Future<void> _loadSampleData() async {
    setState(() {
      _isLoadingSampleData = true;
    });

    try {
      final result = await _testerSampleDataService.loadSampleData();

      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Sample data loaded: ${result.addedPantry} pantry, ${result.addedShopping} shopping, ${result.addedMeals} meal plan.',
          sk: 'Ukážkové dáta nahraté: ${result.addedPantry} špajza, ${result.addedShopping} nákup, ${result.addedMeals} jedálniček.',
        ),
      );
    } on TesterSampleDataAuthException {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'You need to be signed in.',
          sk: 'Musíš byť prihlásený.',
        ),
        title: context.tr(
          en: 'Sign in required',
          sk: 'Treba sa prihlásiť',
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
        title: context.tr(
          en: 'Sample data not loaded',
          sk: 'Ukážkové dáta sa nenahrali',
        ),
        actionLabel: context.tr(en: 'Retry', sk: 'Skúsiť znova'),
        onAction: _loadSampleData,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSampleData = false;
        });
      }
    }
  }

  Future<void> _clearSampleData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(en: 'Clear sample data', sk: 'Vymazať ukážkové dáta'),
        ),
        content: Text(
          context.tr(
            en: 'This removes only the sample Pantry, Shopping List, and Meal plan items added from Tester info.',
            sk: 'Týmto sa odstránia len ukážkové položky zo špajze, nákupného zoznamu a jedálnička pridané z Tester info.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr(en: 'Clear', sk: 'Vymazať')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isClearingSampleData = true;
    });

    try {
      final pantryItems = await _foodItemsRepository.getFoodItems();
      final shoppingItems = await _shoppingListRepository
          .getShoppingListItems();
      final mealPlanEntries = await _mealPlanRepository.getEntries();

      var removedPantry = 0;
      for (final item in pantryItems) {
        if (!_samplePantryNames.contains(item.name)) {
          continue;
        }
        await _foodItemsRepository.removeFoodItem(item.id);
        removedPantry++;
      }

      var removedShopping = 0;
      for (final item in shoppingItems) {
        if (!_sampleShoppingNames.contains(item.name)) {
          continue;
        }
        await _shoppingListRepository.removeShoppingListItem(item.id);
        removedShopping++;
      }

      var removedMeals = 0;
      for (final entry in mealPlanEntries) {
        if (!_sampleRecipeIds.contains(entry.recipeId)) {
          continue;
        }
        await _mealPlanRepository.removeEntry(entry.id);
        removedMeals++;
      }

      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Sample data removed: $removedPantry pantry, $removedShopping shopping, $removedMeals meal plan.',
          sk: 'Ukážkové dáta odstránené: $removedPantry špajza, $removedShopping nákup, $removedMeals jedálniček.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to clear sample data.',
          sk: 'Ukážkové dáta sa nepodarilo vymazať.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isClearingSampleData = false;
        });
      }
    }
  }

  Future<void> _copyFeedbackTemplate() async {
    await Clipboard.setData(ClipboardData(text: _feedbackTemplate(context)));
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Feedback template copied.',
        sk: 'Šablóna na feedback bola skopírovaná.',
      ),
    );
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isClearingSampleData ? null : _clearSampleData,
                  icon: _isClearingSampleData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined),
                  label: Text(
                    _isClearingSampleData
                        ? context.tr(en: 'Clearing...', sk: 'Mažem...')
                        : context.tr(
                            en: 'Clear sample data',
                            sk: 'Vymazať ukážkové dáta',
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
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(
              en: 'Feedback template',
              sk: 'Šablóna na feedback',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_feedbackTemplate(context)),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _copyFeedbackTemplate,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(
                    context.tr(
                      en: 'Copy feedback template',
                      sk: 'Skopírovať šablónu',
                    ),
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
