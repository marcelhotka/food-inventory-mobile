import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_metadata.dart';
import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_alert_dialog.dart';
import '../../../core/widgets/safo_flow_hint_card.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../data/tester_sample_data_service.dart';

class TesterInfoScreen extends StatefulWidget {
  final Household household;

  const TesterInfoScreen({super.key, required this.household});

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
  late final AuthRepository _authRepository = AuthRepository();
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  late final TesterSampleDataService _testerSampleDataService =
      TesterSampleDataService(household: widget.household);

  bool _isLoadingSampleData = false;
  bool _isClearingSampleData = false;
  bool _isResettingOnboarding = false;
  bool _isPreparingFirstRun = false;
  bool _isRestartingFirstRun = false;

  String _feedbackTemplate(BuildContext context) {
    return context.tr(
      en: 'Tested flow:\nWhat I expected:\nWhat happened:\nSeverity:\nNotes / screenshot:',
      sk: 'Testovaný flow:\nČo som očakával:\nČo sa stalo:\nZávažnosť:\nPoznámka / screenshot:',
    );
  }

  String _qaChecklistTemplate(BuildContext context) {
    return context.tr(
      en: 'QA checklist:\n- Onboarding and auth\n- Household create / join\n- Pantry add / edit / opened / expiring\n- Shopping add / bought / move to pantry\n- Recipes safe-for-you / servings / shopping add\n- Meal plan add / assign cook\n- Quick command / barcode / fridge scan\n- Dashboard density and alerts\n- Empty, loading, error, offline states',
      sk: 'QA checklist:\n- Onboarding a prihlásenie\n- Vytvorenie / pripojenie domácnosti\n- Špajza: pridať / upraviť / otvorené / exspirácia\n- Nákup: pridať / kúpené / presun do špajze\n- Recepty: safe-for-you / porcie / pridanie do nákupu\n- Jedálniček: pridať / priradiť kuchára\n- Rýchly príkaz / barcode / scan chladničky\n- Hustota dashboardu a upozornenia\n- Empty, loading, error a offline stavy',
    );
  }

  String _buildSummary(BuildContext context) {
    return context.tr(
      en: 'App: ${SafoAppMetadata.appName}\nVersion: ${SafoAppMetadata.buildLabel}\nStage: ${SafoAppMetadata.releaseStage}\nHousehold: ${widget.household.name}\nInvite code: ${widget.household.inviteCode}',
      sk: 'Aplikácia: ${SafoAppMetadata.appName}\nVerzia: ${SafoAppMetadata.buildLabel}\nFáza: ${SafoAppMetadata.releaseStage}\nDomácnosť: ${widget.household.name}\nPozývací kód: ${widget.household.inviteCode}',
    );
  }

  String _fullTesterPack(BuildContext context) {
    return [
      _buildSummary(context),
      '',
      _qaChecklistTemplate(context),
      '',
      _feedbackTemplate(context),
    ].join('\n');
  }

  String _householdJoinScenario(BuildContext context) {
    return context.tr(
      en:
          'Household join scenario\n'
          '1. Open Safo on a second device or browser.\n'
          '2. Sign in or continue as guest.\n'
          '3. Go through onboarding until Household setup.\n'
          '4. Choose Join household.\n'
          '5. Enter invite code: ${widget.household.inviteCode}\n'
          '6. Confirm the shared household name: ${widget.household.name}\n'
          '7. Verify Pantry, Shopping, and Meal plan now match the shared household.\n'
          '8. Pull to refresh on the first device and verify the new member/feed update appears.',
      sk:
          'Scenár pripojenia do domácnosti\n'
          '1. Otvor Safo na druhom zariadení alebo v druhom prehliadači.\n'
          '2. Prihlás sa alebo pokračuj ako hosť.\n'
          '3. Prejdi onboarding až po nastavenie domácnosti.\n'
          '4. Vyber Pripojiť sa do domácnosti.\n'
          '5. Zadaj pozývací kód: ${widget.household.inviteCode}\n'
          '6. Skontroluj názov spoločnej domácnosti: ${widget.household.name}\n'
          '7. Over, že Špajza, Nákup a Jedálniček už zodpovedajú spoločnej domácnosti.\n'
          '8. Na prvom zariadení obnov obrazovku a over, že sa zobrazí nový člen alebo update vo feede.',
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
          en: 'Sign in to load sample data for this household.',
          sk: 'Prihlás sa, aby si mohol nahrať ukážkové dáta pre túto domácnosť.',
        ),
        title: context.tr(en: 'Sign in required', sk: 'Treba sa prihlásiť'),
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
      builder: (context) => SafoAlertDialog(
        badge: context.tr(en: 'Tester mode', sk: 'Tester režim'),
        icon: Icons.cleaning_services_outlined,
        iconColor: SafoColors.warning,
        iconBackgroundColor: SafoColors.warningSoft,
        title: context.tr(en: 'Clear sample data', sk: 'Vymazať ukážkové dáta'),
        subtitle: context.tr(
          en: 'This removes only the sample Pantry, Shopping List, and Meal plan items added from Tester info.',
          sk: 'Týmto sa odstránia len ukážkové položky zo špajze, nákupného zoznamu a jedálnička pridané z Tester info.',
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
      final (:removedPantry, :removedShopping, :removedMeals) =
          await _removeSampleData();

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

  Future<({int removedPantry, int removedShopping, int removedMeals})>
  _removeSampleData() async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
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

    return (
      removedPantry: removedPantry,
      removedShopping: removedShopping,
      removedMeals: removedMeals,
    );
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

  Future<void> _copyQaChecklist() async {
    await Clipboard.setData(ClipboardData(text: _qaChecklistTemplate(context)));
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'QA checklist copied.',
        sk: 'QA checklist bol skopírovaný.',
      ),
    );
  }

  Future<void> _copyBuildSummary() async {
    await Clipboard.setData(ClipboardData(text: _buildSummary(context)));
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Build summary copied.',
        sk: 'Zhrnutie buildu bolo skopírované.',
      ),
    );
  }

  Future<void> _copyTesterPack() async {
    await Clipboard.setData(ClipboardData(text: _fullTesterPack(context)));
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Tester pack copied.',
        sk: 'Tester balík bol skopírovaný.',
      ),
    );
  }

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: widget.household.inviteCode));
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Invite code copied.',
        sk: 'Pozývací kód bol skopírovaný.',
      ),
    );
  }

  Future<void> _copyHouseholdJoinScenario() async {
    await Clipboard.setData(
      ClipboardData(text: _householdJoinScenario(context)),
    );
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Household join scenario copied.',
        sk: 'Scenár pripojenia do domácnosti bol skopírovaný.',
      ),
    );
  }

  Future<void> _resetOnboardingFlag() async {
    setState(() {
      _isResettingOnboarding = true;
    });

    try {
      final wasReset = await _resetOnboardingFlagInternal();
      if (!wasReset) {
        return;
      }

      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Onboarding flag reset. Sign out or restart the flow to test first-run screens again.',
          sk: 'Onboarding flag bol resetovaný. Odhlás sa alebo reštartuj flow a môžeš znovu testovať first-run obrazovky.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to reset onboarding flag.',
          sk: 'Onboarding flag sa nepodarilo resetovať.',
        ),
        title: context.tr(en: 'Reset not completed', sk: 'Reset sa nedokončil'),
        actionLabel: context.tr(en: 'Retry', sk: 'Skúsiť znova'),
        onAction: _resetOnboardingFlag,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingOnboarding = false;
        });
      }
    }
  }

  Future<bool> _resetOnboardingFlagInternal() async {
    final preferences = await _userPreferencesRepository
        .getCurrentUserPreferences();

    if (preferences == null) {
      if (!mounted) return false;
      showWarningFeedback(
        context,
        context.tr(
          en: 'No saved kitchen setup was found yet. Finish onboarding once first, then you can reset it here.',
          sk: 'Zatiaľ sa nenašlo uložené nastavenie kuchyne. Najprv onboarding raz dokonči a potom ho tu budeš vedieť resetovať.',
        ),
      );
      return false;
    }

    await _userPreferencesRepository.savePreferences(
      preferences.copyWith(
        onboardingCompleted: false,
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    return true;
  }

  Future<void> _prepareFreshFirstRunPass() async {
    await _prepareFirstRunPass(signOutAfterPreparation: false);
  }

  Future<void> _restartFreshFirstRunPass() async {
    await _prepareFirstRunPass(signOutAfterPreparation: true);
  }

  Future<void> _prepareFirstRunPass({
    required bool signOutAfterPreparation,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SafoAlertDialog(
        badge: context.tr(en: 'First-run retest', sk: 'First-run retest'),
        icon: Icons.restart_alt_rounded,
        iconColor: SafoColors.accent,
        iconBackgroundColor: SafoColors.accentSoft,
        title: context.tr(
          en: signOutAfterPreparation
              ? 'Prepare and restart onboarding'
              : 'Prepare a fresh first-run pass',
          sk: signOutAfterPreparation
              ? 'Pripraviť a reštartovať onboarding'
              : 'Pripraviť nový first-run priechod',
        ),
        subtitle: context.tr(
          en: signOutAfterPreparation
              ? 'This clears sample data, resets the onboarding flag, and signs you out so you can replay the first-run flow immediately.'
              : 'This clears sample data and resets the onboarding flag so you can replay the first-run flow again.',
          sk: signOutAfterPreparation
              ? 'Týmto sa vymažú ukážkové dáta, resetuje onboarding flag a Safo ťa odhlási, aby si mohol first-run flow hneď prejsť znova.'
              : 'Týmto sa vymažú ukážkové dáta a resetuje onboarding flag, aby si mohol znovu prejsť first-run flow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.tr(
                en: signOutAfterPreparation ? 'Prepare and restart' : 'Prepare',
                sk: signOutAfterPreparation
                    ? 'Pripraviť a reštartovať'
                    : 'Pripraviť',
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      if (signOutAfterPreparation) {
        _isRestartingFirstRun = true;
      } else {
        _isPreparingFirstRun = true;
      }
    });

    try {
      final counts = await _removeSampleData();
      final wasReset = await _resetOnboardingFlagInternal();
      if (!mounted) return;
      if (!wasReset) {
        return;
      }
      if (signOutAfterPreparation) {
        await _authRepository.signOut();
        return;
      }
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Fresh first-run pass is ready. Removed ${counts.removedPantry} pantry, ${counts.removedShopping} shopping, and ${counts.removedMeals} meal plan samples. Sign out to replay onboarding.',
          sk: 'Nový first-run priechod je pripravený. Odstránilo sa ${counts.removedPantry} položiek zo špajze, ${counts.removedShopping} z nákupu a ${counts.removedMeals} z jedálnička. Odhlás sa a onboarding si môžeš prejsť znova.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: signOutAfterPreparation
              ? 'Failed to prepare and restart the first-run flow.'
              : 'Failed to prepare a fresh first-run pass.',
          sk: signOutAfterPreparation
              ? 'Nepodarilo sa pripraviť a reštartovať first-run flow.'
              : 'Nepodarilo sa pripraviť nový first-run priechod.',
        ),
        title: context.tr(
          en: signOutAfterPreparation
              ? 'Restart not completed'
              : 'Preparation not completed',
          sk: signOutAfterPreparation
              ? 'Reštart sa nedokončil'
              : 'Príprava sa nedokončila',
        ),
        actionLabel: context.tr(en: 'Retry', sk: 'Skúsiť znova'),
        onAction: signOutAfterPreparation
            ? _restartFreshFirstRunPass
            : _prepareFreshFirstRunPass,
      );
    } finally {
      if (mounted) {
        setState(() {
          if (signOutAfterPreparation) {
            _isRestartingFirstRun = false;
          } else {
            _isPreparingFirstRun = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SafoSpacing.md,
          SafoSpacing.sm,
          SafoSpacing.md,
          SafoSpacing.xxl,
        ),
        children: [
          SafeArea(
            bottom: false,
            child: SafoPageHeader(
              title: context.tr(en: 'Tester info', sk: 'Tester info'),
              subtitle: context.tr(
                en: 'Use this screen to load test data, clear it, and run a structured Safo review pass.',
                sk: 'Použi túto obrazovku na nahratie test dát, ich vymazanie a štruktúrovaný testovací priechod Safo.',
              ),
              onBack: () => Navigator.of(context).maybePop(),
              badges: [
                _TesterBadge(
                  icon: Icons.dataset_outlined,
                  label: context.tr(en: 'Sample data', sk: 'Ukážkové dáta'),
                ),
                _TesterBadge(
                  icon: Icons.verified_outlined,
                  label: context.tr(en: 'QA flow', sk: 'QA flow'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SafoSpacing.lg),
          SafoFlowHintCard(
            icon: Icons.science_outlined,
            eyebrow: context.tr(en: 'QA helper', sk: 'QA pomocník'),
            title: context.tr(
              en: 'Prepare Safo for realistic testing in a few quick steps.',
              sk: 'Priprav Safo na realistické testovanie v pár rýchlych krokoch.',
            ),
            description: context.tr(
              en: 'Load sample data, clear it when you need a fresh pass, and keep one simple checklist for what to test next.',
              sk: 'Nahraj ukážkové dáta, podľa potreby ich vymaž a maj po ruke jednoduchý checklist toho, čo testovať ďalej.',
            ),
            highlights: [
              context.tr(en: 'Sample data', sk: 'Ukážkové dáta'),
              context.tr(en: 'Clear reset', sk: 'Čistý reset'),
              context.tr(en: 'QA checklist', sk: 'QA checklist'),
            ],
          ),
          const SizedBox(height: SafoSpacing.lg),
          _InfoCard(
            title: context.tr(en: 'Current build', sk: 'Aktuálny build'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Version ${SafoAppMetadata.buildLabel}',
                    sk: 'Verzia ${SafoAppMetadata.buildLabel}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    en: 'Stage: ${SafoAppMetadata.releaseStage}',
                    sk: 'Fáza: ${SafoAppMetadata.releaseStage}',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(
                          en: 'Invite code: ${widget.household.inviteCode}',
                          sk: 'Pozývací kód: ${widget.household.inviteCode}',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SafoColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _copyInviteCode,
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(context.tr(en: 'Copy', sk: 'Kopírovať')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyHouseholdJoinScenario,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(
                    context.tr(
                      en: 'Copy household join scenario',
                      sk: 'Skopírovať join scenár domácnosti',
                    ),
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyBuildSummary,
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(
                    context.tr(
                      en: 'Copy build summary',
                      sk: 'Skopírovať zhrnutie buildu',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyTesterPack,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(
                    context.tr(
                      en: 'Copy tester pack',
                      sk: 'Skopírovať tester balík',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: context.tr(
              en: 'First-run retest tools',
              sk: 'Nástroje na first-run retest',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Use these actions when you want to replay onboarding cleanly without rebuilding the whole household by hand.',
                    sk: 'Použi tieto akcie, keď chceš znovu prejsť onboarding čisto bez ručného prestavovania celej domácnosti.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isResettingOnboarding
                      ? null
                      : _resetOnboardingFlag,
                  icon: _isResettingOnboarding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restart_alt_rounded),
                  label: Text(
                    _isResettingOnboarding
                        ? context.tr(en: 'Resetting...', sk: 'Resetujem...')
                        : context.tr(
                            en: 'Reset onboarding flag',
                            sk: 'Resetovať onboarding',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: _isPreparingFirstRun
                      ? null
                      : _prepareFreshFirstRunPass,
                  icon: _isPreparingFirstRun
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(
                    _isPreparingFirstRun
                        ? context.tr(en: 'Preparing...', sk: 'Pripravujem...')
                        : context.tr(
                            en: 'Prepare fresh first-run pass',
                            sk: 'Pripraviť nový first-run priechod',
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _isRestartingFirstRun
                      ? null
                      : _restartFreshFirstRunPass,
                  icon: _isRestartingFirstRun
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    _isRestartingFirstRun
                        ? context.tr(en: 'Restarting...', sk: 'Reštartujem...')
                        : context.tr(
                            en: 'Prepare and restart onboarding',
                            sk: 'Pripraviť a reštartovať onboarding',
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
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _copyQaChecklist,
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  label: Text(
                    context.tr(
                      en: 'Copy QA checklist',
                      sk: 'Skopírovať QA checklist',
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

class _TesterBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TesterBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SafoRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
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
