import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/sign_out_action.dart';
import '../data/user_preferences_remote_data_source.dart';
import '../data/user_preferences_repository.dart';
import '../domain/user_preferences.dart';

class UserPreferencesScreen extends StatefulWidget {
  final bool isOnboarding;
  final Future<void> Function()? onCompleted;
  final Future<void> Function()? onBackToSignIn;
  final VoidCallback? onNextToHouseholdSetup;

  const UserPreferencesScreen({
    super.key,
    this.isOnboarding = false,
    this.onCompleted,
    this.onBackToSignIn,
    this.onNextToHouseholdSetup,
  });

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  static const _kitchenSetupHeroAsset =
      'assets/branding/kitchen-setup-hero.png';

  final _formKey = GlobalKey<FormState>();
  final _favoriteMealsController = TextEditingController();
  final _favoriteFoodsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _intolerancesController = TextEditingController();
  final _householdSizeController = TextEditingController();

  late final UserPreferencesRepository _repository =
      UserPreferencesRepository();
  late final AuthRepository _authRepository = AuthRepository();
  late Future<UserPreferences?> _preferencesFuture = _repository
      .getCurrentUserPreferences();

  Set<String> _selectedDietStyles = <String>{};
  String? _selectedCookingFrequency;
  String? _selectedLanguage;
  Set<String> _selectedFavoriteMeals = <String>{};
  Set<String> _selectedFavoriteFoods = <String>{};
  Set<String> _selectedAllergies = <String>{};
  Set<String> _selectedIntolerances = <String>{};
  bool _onboardingCompleted = false;
  bool _isSaving = false;
  UserPreferences? _loadedPreferences;
  bool _didPrecacheHero = false;

  static const _dietStyles = [
    'no_special_diet',
    'vegan',
    'vegetarian',
    'keto',
    'omnivore',
    'flexitarian',
    'pescatarian',
    'low_carb',
    'mediterranean',
    'gluten_free',
    'lactose_free',
    'halal',
    'kosher',
    'plant_based',
  ];

  static const _cookingFrequencies = [
    'daily',
    'few_times_week',
    'weekends_only',
    'rarely',
  ];

  static const _favoriteMealOptions = [
    'pasta',
    'salad',
    'soup',
    'sandwich',
    'pizza',
    'burger',
    'sushi',
    'curry',
    'rice_dishes',
    'noodles',
    'grilled',
    'omelette',
  ];

  static const _favoriteFoodOptions = [
    'chicken',
    'rice',
    'eggs',
    'cheese',
    'bread',
    'potatoes',
    'pasta',
    'beef',
    'fish',
    'seafood',
    'fruit',
    'vegetables',
    'chocolate',
    'yogurt',
    'nuts',
    'beans',
  ];

  static const _allergyOptions = [
    'eggs',
    'peanuts',
    'soy',
    'tree_nuts',
    'milk',
    'wheat',
    'fish',
    'shellfish',
    'sesame',
  ];

  static const _intoleranceOptions = [
    'lactose',
    'gluten',
    'histamine',
    'fructose',
    'fodmap',
    'additives',
    'alcohol',
  ];

  @override
  void dispose() {
    _favoriteMealsController.dispose();
    _favoriteFoodsController.dispose();
    _allergiesController.dispose();
    _intolerancesController.dispose();
    _householdSizeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheHero || !widget.isOnboarding) {
      return;
    }
    _didPrecacheHero = true;
    precacheImage(const AssetImage(_kitchenSetupHeroAsset), context);
  }

  Future<void> _reload() async {
    setState(() {
      _preferencesFuture = _repository.getCurrentUserPreferences();
    });
  }

  void _applyLoadedPreferences(UserPreferences? preferences) {
    if (_loadedPreferences == preferences) {
      return;
    }
    _loadedPreferences = preferences;
    final favoriteMeals = preferences?.favoriteMeals ?? const <String>[];
    final favoriteFoods = preferences?.favoriteFoods ?? const <String>[];
    final allergies = preferences?.allergies ?? const <String>[];
    final intolerances = preferences?.intolerances ?? const <String>[];
    _selectedFavoriteMeals = _selectKnownValues(
      favoriteMeals,
      _favoriteMealOptions,
    );
    _selectedFavoriteFoods = _selectKnownValues(
      favoriteFoods,
      _favoriteFoodOptions,
    );
    _selectedAllergies = _selectKnownValues(allergies, _allergyOptions);
    _selectedIntolerances = _selectKnownValues(
      intolerances,
      _intoleranceOptions,
    );
    _favoriteMealsController.text = _joinCustomValues(
      favoriteMeals,
      _favoriteMealOptions,
    );
    _favoriteFoodsController.text = _joinCustomValues(
      favoriteFoods,
      _favoriteFoodOptions,
    );
    _allergiesController.text = _joinCustomValues(allergies, _allergyOptions);
    _intolerancesController.text = _joinCustomValues(
      intolerances,
      _intoleranceOptions,
    );
    _householdSizeController.text =
        preferences?.householdSize?.toString() ?? '';
    _selectedDietStyles = {
      ...(preferences?.dietStyles ?? const <String>[]),
    };
    _selectedCookingFrequency = preferences?.cookingFrequency;
    _selectedLanguage =
        preferences?.preferredLanguage ??
        context.localeController.locale.languageCode;
    _onboardingCompleted = preferences?.onboardingCompleted ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'No signed-in user.',
          sk: 'Nie je prihlásený používateľ.',
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final current = _loadedPreferences;
    final preferences = UserPreferences(
      userId: user.id,
      favoriteMeals: _combineSelectedAndCustom(
        _selectedFavoriteMeals,
        _favoriteMealsController.text,
      ),
      favoriteFoods: _combineSelectedAndCustom(
        _selectedFavoriteFoods,
        _favoriteFoodsController.text,
      ),
      allergies: _combineSelectedAndCustom(
        _selectedAllergies,
        _allergiesController.text,
      ),
      intolerances: _combineSelectedAndCustom(
        _selectedIntolerances,
        _intolerancesController.text,
      ),
      dietStyles: _selectedDietStyles.toList()..sort(),
      cookingFrequency: _selectedCookingFrequency,
      preferredLanguage: _selectedLanguage,
      householdSize: _parseHouseholdSize(_householdSizeController.text),
      onboardingCompleted: widget.isOnboarding ? true : _onboardingCompleted,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final saved = await _repository.savePreferences(preferences);
      if (!mounted) return;
      _applyLoadedPreferences(saved);
      context.localeController.setLocaleCode(saved.preferredLanguage);
      if (widget.onCompleted != null) {
        await widget.onCompleted!();
      }
      if (!mounted) return;
      showSuccessFeedback(
        context,
        widget.isOnboarding
            ? context.tr(
                en: 'Preferences saved. Your kitchen is ready.',
                sk: 'Preferencie sú uložené. Tvoja kuchyňa je pripravená.',
              )
            : context.tr(
                en: 'Preferences saved.',
                sk: 'Preferencie sú uložené.',
              ),
      );
      if (widget.isOnboarding) {
        return;
      }
    } on UserPreferencesConfigException catch (error) {
      if (!mounted) return;
      showErrorFeedback(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to save preferences.',
          sk: 'Preferencie sa nepodarilo uložiť.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _applySampleProfile() {
    setState(() {
      _selectedFavoriteMeals = {'pasta', 'omelette', 'soup'};
      _selectedFavoriteFoods = {'milk', 'eggs', 'bread', 'cheese'};
      _selectedAllergies = <String>{};
      _selectedIntolerances = {'lactose'};
      _favoriteMealsController.text = '';
      _favoriteFoodsController.text = '';
      _allergiesController.text = '';
      _intolerancesController.text = '';
      _householdSizeController.text = '2';
      _selectedDietStyles = {'no_special_diet'};
      _selectedCookingFrequency = 'few_times_week';
      _selectedLanguage ??= context.localeController.locale.languageCode;
      if (!widget.isOnboarding) {
        _onboardingCompleted = true;
      }
    });
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Sample tester profile filled in.',
        sk: 'Ukážkový testerský profil je predvyplnený.',
      ),
    );
  }

  void _resetOnboardingForTesting() {
    setState(() {
      _onboardingCompleted = false;
    });
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Onboarding was reset. Save preferences to apply it.',
        sk: 'Onboarding bol resetovaný. Ulož preferencie, aby sa to použilo.',
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await confirmAndSignOut(context, _authRepository);
  }

  void _handleOnboardingBackToHousehold() {
    if (widget.onNextToHouseholdSetup == null || _isSaving) {
      return;
    }
    widget.onNextToHouseholdSetup!.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: widget.isOnboarding
              ? (details) {
                  if ((details.primaryVelocity ?? 0) > 180) {
                    _handleOnboardingBackToHousehold();
                  } else if ((details.primaryVelocity ?? 0) < -180) {
                    _save();
                  }
                }
              : null,
          child: FutureBuilder<UserPreferences?>(
          future: _preferencesFuture,
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final configError = error is UserPreferencesConfigException
                ? error
                : null;
            return AppErrorState(
              kind: configError != null
                  ? AppErrorKind.setup
                  : AppErrorKind.sync,
              title: configError != null
                  ? context.tr(
                      en: 'Preferences need setup',
                      sk: 'Preferencie potrebujú nastavenie',
                    )
                  : context.tr(
                      en: 'Preferences are unavailable',
                      sk: 'Preferencie nie sú k dispozícii',
                    ),
              message:
                  configError?.message ??
                  context.tr(
                    en: 'Failed to load preferences.',
                    sk: 'Preferencie sa nepodarilo načítať.',
                  ),
              hint: configError != null
                  ? context.tr(
                      en: 'Safo still needs backend configuration before preferences can be loaded.',
                      sk: 'Safo ešte potrebuje backend nastavenie, aby sa dali načítať preferencie.',
                    )
                  : context.tr(
                      en: 'Safo could not refresh saved preferences right now.',
                      sk: 'Safo teraz nedokázalo obnoviť uložené preferencie.',
                    ),
              onRetry: _reload,
            );
          }

          _applyLoadedPreferences(snapshot.data);
          final favoriteSummaryCount =
              _selectedFavoriteMeals.length +
              _selectedFavoriteFoods.length +
              _splitList(_favoriteMealsController.text).length +
              _splitList(_favoriteFoodsController.text).length;
          final dietarySummaryCount =
              _selectedAllergies.length +
              _selectedIntolerances.length +
              _selectedDietStyles.length +
              _splitList(_allergiesController.text).length +
              _splitList(_intolerancesController.text).length;
          final profileSummaryCount = [
            if ((_selectedLanguage ?? '').isNotEmpty) _selectedLanguage,
            if ((_selectedCookingFrequency ?? '').isNotEmpty)
              _selectedCookingFrequency,
            if ((_householdSizeController.text.trim()).isNotEmpty)
              _householdSizeController.text,
          ].length;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (!widget.isOnboarding) ...[
                _PreferencesHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 18),
                _PreferencesOverview(
                  favoriteCount: favoriteSummaryCount,
                  dietaryCount: dietarySummaryCount,
                  profileCount: profileSummaryCount,
                ),
                const SizedBox(height: 18),
              ],
              if (widget.isOnboarding) ...[
                SafoPageHeader(
                  title: context.tr(
                    en: 'Set up your kitchen',
                    sk: 'Nastav si kuchyňu',
                  ),
                  subtitle: context.tr(
                    en: 'A few choices now help Safo suggest safer recipes, smarter shopping, and a calmer household flow from day one.',
                    sk: 'Pár volieb teraz pomôže Safo odporúčať bezpečnejšie recepty, múdrejšie nákupy a pokojnejší chod domácnosti od prvého dňa.',
                  ),
                  dark: false,
                  onBack: _handleOnboardingBackToHousehold,
                  trailing: IconButton(
                    onPressed: _handleSignOut,
                    style: IconButton.styleFrom(
                      foregroundColor: SafoColors.textPrimary,
                      backgroundColor: SafoColors.surfaceSoft,
                      side: const BorderSide(color: SafoColors.border),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: context.tr(en: 'Sign out', sk: 'Odhlásiť sa'),
                  ),
                  badges: [
                    _OnboardingHeaderBadge(
                      icon: Icons.tune_rounded,
                      label: context.tr(en: 'Kitchen profile', sk: 'Profil kuchyne'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _KitchenSetupHero(
                  imageAsset: _kitchenSetupHeroAsset,
                  title: context.tr(
                    en: 'Set up your kitchen',
                    sk: 'Nastav si kuchyňu',
                  ),
                  subtitle: context.tr(
                    en: 'A few choices now help Safo suggest safer recipes, smarter shopping, and a calmer household flow from day one.',
                    sk: 'Pár volieb teraz pomôže Safo odporúčať bezpečnejšie recepty, múdrejšie nákupy a pokojnejší chod domácnosti od prvého dňa.',
                  ),
                ),
                const SizedBox(height: 18),
                _KitchenSetupSummary(
                  title: context.tr(
                    en: 'What we’ll personalize',
                    sk: 'Čo si prispôsobíme',
                  ),
                  items: [
                    context.tr(
                      en: 'Meals and foods you enjoy most',
                      sk: 'Jedlá a potraviny, ktoré máš najradšej',
                    ),
                    context.tr(
                      en: 'Allergies, intolerances, and diet style',
                      sk: 'Alergie, intolerancie a štýl stravovania',
                    ),
                    context.tr(
                      en: 'Household habits like language and cooking rhythm',
                      sk: 'Návyky domácnosti ako jazyk a rytmus varenia',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE6DDCF)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isOnboarding
                            ? context.tr(
                                en: 'Tell us about your kitchen',
                                sk: 'Povedz nám viac o tvojej kuchyni',
                              )
                            : context.tr(
                                en: 'Update your kitchen profile',
                                sk: 'Uprav profil svojej kuchyne',
                              ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.isOnboarding
                            ? context.tr(
                                en: 'Answer a few questions so we can prepare better recipe suggestions, shopping defaults and household recommendations from the start.',
                                sk: 'Odpovedz na pár otázok, aby sme od začiatku vedeli pripraviť lepšie odporúčania receptov, nákupov a fungovania domácnosti.',
                              )
                            : context.tr(
                                en: 'Keep favorite meals, food preferences, and dietary limits up to date so Safo can stay useful in everyday planning.',
                                sk: 'Udržuj obľúbené jedlá, potraviny a stravovacie obmedzenia aktuálne, aby bolo Safo užitočné pri každodennom plánovaní.',
                              ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      _PreferenceSection(
                        title: context.tr(
                          en: 'Meals and foods',
                          sk: 'Jedlá a potraviny',
                        ),
                        icon: Icons.restaurant_menu_rounded,
                        accent: const Color(0xFF4C8C68),
                        subtitle: context.tr(
                          en: 'Tell us what you enjoy most so we can later shape recipe suggestions and shopping defaults.',
                          sk: 'Povedz nám, čo máš rád, aby sme neskôr vedeli lepšie odporúčať recepty a nákupy.',
                        ),
                        children: [
                          _PreferenceField(
                            label: context.tr(
                              en: 'Favorite meals',
                              sk: 'Obľúbené jedlá',
                            ),
                            hint: context.tr(
                              en: 'Choose common meals and optionally add your own',
                              sk: 'Vyber bežné jedlá a prípadne dopíš vlastné',
                            ),
                            child: _PreferenceChipSelector(
                              options: _favoriteMealOptions,
                              selectedValues: _selectedFavoriteMeals,
                              labelBuilder: (value) =>
                                  _favoriteMealLabel(context, value),
                              customController: _favoriteMealsController,
                              featuredCount: 4,
                              allowCustom: true,
                              customLabel: context.tr(
                                en: 'Other favorite meals',
                                sk: 'Iné obľúbené jedlá',
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _selectedFavoriteMeals = values;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: context.tr(
                              en: 'Favorite foods',
                              sk: 'Obľúbené potraviny',
                            ),
                            hint: context.tr(
                              en: 'Pick the foods you buy or use most often',
                              sk: 'Vyber potraviny, ktoré kupuješ alebo používaš najčastejšie',
                            ),
                            child: _PreferenceChipSelector(
                              options: _favoriteFoodOptions,
                              selectedValues: _selectedFavoriteFoods,
                              labelBuilder: (value) =>
                                  _favoriteFoodLabel(context, value),
                              customController: _favoriteFoodsController,
                              featuredCount: 4,
                              allowCustom: true,
                              customLabel: context.tr(
                                en: 'Other favorite foods',
                                sk: 'Iné obľúbené potraviny',
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _selectedFavoriteFoods = values;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreferenceSection(
                        title: context.tr(
                          en: 'Dietary needs',
                          sk: 'Stravovacie potreby',
                        ),
                        icon: Icons.health_and_safety_rounded,
                        accent: const Color(0xFFCE6A52),
                        subtitle: context.tr(
                          en: 'Capture allergies, intolerances and diet style so later suggestions stay relevant and safe.',
                          sk: 'Zadaj alergie, intolerancie a štýl stravovania, aby boli odporúčania bezpečné a relevantné.',
                        ),
                        children: [
                          _PreferenceField(
                            label: context.tr(en: 'Allergies', sk: 'Alergie'),
                            hint: context.tr(
                              en: 'Choose known allergies and optionally add your own',
                              sk: 'Vyber známe alergie a prípadne dopíš vlastné',
                            ),
                            child: _PreferenceChipSelector(
                              options: _allergyOptions,
                              selectedValues: _selectedAllergies,
                              labelBuilder: (value) =>
                                  _allergyLabel(context, value),
                              customController: _allergiesController,
                              featuredCount: 4,
                              allowCustom: true,
                              customLabel: context.tr(
                                en: 'Other allergies',
                                sk: 'Iné alergie',
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _selectedAllergies = values;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: context.tr(
                              en: 'Intolerances',
                              sk: 'Intolerancie',
                            ),
                            hint: context.tr(
                              en: 'Choose common intolerances and optionally add your own',
                              sk: 'Vyber bežné intolerancie a prípadne dopíš vlastné',
                            ),
                            child: _PreferenceChipSelector(
                              options: _intoleranceOptions,
                              selectedValues: _selectedIntolerances,
                              labelBuilder: (value) =>
                                  _intoleranceLabel(context, value),
                              customController: _intolerancesController,
                              featuredCount: 4,
                              allowCustom: true,
                              customLabel: context.tr(
                                en: 'Other intolerances',
                                sk: 'Iné intolerancie',
                              ),
                              onChanged: (values) {
                                setState(() {
                                  _selectedIntolerances = values;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: context.tr(
                              en: 'Diet style',
                              sk: 'Štýl stravovania',
                            ),
                            hint: context.tr(
                              en: 'Choose the closest long-term preference',
                              sk: 'Vyber najbližšie dlhodobé nastavenie',
                            ),
                            child: _MultiChoiceChipSelector(
                              options: _dietStyles,
                              selectedValues: _selectedDietStyles,
                              featuredCount: 4,
                              labelBuilder: (value) =>
                                  _dietStyleLabel(context, value),
                              onChanged: (values) {
                                setState(() {
                                  _selectedDietStyles =
                                      _normalizeDietStyles(values);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreferenceSection(
                        title: context.tr(en: 'Language', sk: 'Jazyk'),
                        icon: Icons.translate_rounded,
                        accent: const Color(0xFF5B74E8),
                        subtitle: context.tr(
                          en: 'Choose which language the app should use.',
                          sk: 'Vyber jazyk, ktorý má aplikácia používať.',
                        ),
                        children: [
                          _PreferenceField(
                            label: context.tr(
                              en: 'App language',
                              sk: 'Jazyk aplikácie',
                            ),
                            hint: context.tr(
                              en: 'You can switch any time later',
                              sk: 'Neskôr ho môžeš kedykoľvek zmeniť',
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedLanguage,
                              decoration: appInputDecoration(
                                context.tr(
                                  en: 'App language',
                                  sk: 'Jazyk aplikácie',
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Text(
                                    context.tr(en: 'English', sk: 'Angličtina'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'sk',
                                  child: Text(
                                    context.tr(en: 'Slovak', sk: 'Slovenčina'),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreferenceSection(
                        title: context.tr(
                          en: 'Household habits',
                          sk: 'Návyky domácnosti',
                        ),
                        icon: Icons.home_work_rounded,
                        accent: const Color(0xFF8B6F45),
                        subtitle: context.tr(
                          en: 'These values help us tune meal-planning and pantry expectations later on.',
                          sk: 'Tieto údaje nám neskôr pomôžu lepšie nastaviť plánovanie jedál a očakávania pre špajzu.',
                        ),
                        children: [
                          _PreferenceField(
                            label: context.tr(
                              en: 'Cooking frequency',
                              sk: 'Frekvencia varenia',
                            ),
                            hint: context.tr(
                              en: 'How often this household cooks at home',
                              sk: 'Ako často táto domácnosť varí doma',
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCookingFrequency,
                              decoration: appInputDecoration(
                                context.tr(
                                  en: 'Cooking frequency',
                                  sk: 'Frekvencia varenia',
                                ),
                              ),
                              items: _cookingFrequencies
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        _cookingFrequencyLabel(context, value),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCookingFrequency = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: context.tr(
                              en: 'Household size',
                              sk: 'Veľkosť domácnosti',
                            ),
                            hint: context.tr(
                              en: 'How many people usually eat from this kitchen',
                              sk: 'Koľko ľudí zvyčajne jedáva z tejto kuchyne',
                            ),
                            child: TextFormField(
                              controller: _householdSizeController,
                              keyboardType: TextInputType.number,
                              decoration: appInputDecoration(
                                context.tr(
                                  en: 'Household size',
                                  sk: 'Veľkosť domácnosti',
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return null;
                                }
                                final parsed = int.tryParse(value!.trim());
                                if (parsed == null || parsed <= 0) {
                                  return context.tr(
                                    en: 'Enter a valid number',
                                    sk: 'Zadaj platné číslo',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      if (!widget.isOnboarding) ...[
                        const SizedBox(height: 18),
                        _PreferenceSection(
                          title: context.tr(
                            en: 'Testing tools',
                            sk: 'Testovacie nástroje',
                          ),
                          subtitle: context.tr(
                            en: 'Use these shortcuts to speed up repeated tester flows.',
                            sk: 'Tieto skratky urýchlia opakované testerské scenáre.',
                          ),
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _applySampleProfile,
                                  icon: const Icon(
                                    Icons.auto_fix_high_outlined,
                                  ),
                                  label: Text(
                                    context.tr(
                                      en: 'Fill sample profile',
                                      sk: 'Vyplniť ukážkový profil',
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _resetOnboardingForTesting,
                                  icon: const Icon(Icons.restart_alt_rounded),
                                  label: Text(
                                    context.tr(
                                      en: 'Reset onboarding flag',
                                      sk: 'Resetovať onboarding',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (!widget.isOnboarding) ...[
                        CheckboxListTile(
                          value: _onboardingCompleted,
                          onChanged: (value) {
                            setState(() {
                              _onboardingCompleted = value ?? false;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.tr(
                              en: 'Mark onboarding as completed',
                              sk: 'Označiť onboarding ako dokončený',
                            ),
                          ),
                          subtitle: Text(
                            context.tr(
                              en: 'This lets us reuse the same record later when we add first-login onboarding.',
                              sk: 'Týmto sa ten istý záznam bude dať neskôr použiť pri onboardingu po prvom prihlásení.',
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 20),
                      ] else
                        const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child: Text(
                            _isSaving
                                ? context.tr(en: 'Saving...', sk: 'Ukladám...')
                                : widget.isOnboarding
                                ? context.tr(en: 'Continue', sk: 'Pokračovať')
                                : context.tr(
                                    en: 'Save preferences',
                                    sk: 'Uložiť preferencie',
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          },
        ),
      ),
      ),
    );
  }

  static Set<String> _selectKnownValues(
    List<String> values,
    List<String> knownOptions,
  ) {
    final known = knownOptions.toSet();
    return values.where(known.contains).toSet();
  }

  static String _joinCustomValues(
    List<String> values,
    List<String> knownOptions,
  ) {
    final known = knownOptions.toSet();
    return values.where((value) => !known.contains(value)).join(', ');
  }

  static List<String> _splitList(String rawValue) {
    return rawValue
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _combineSelectedAndCustom(
    Set<String> selectedValues,
    String rawCustomValues,
  ) {
    final values = <String>{...selectedValues, ..._splitList(rawCustomValues)};
    return values.toList()..sort();
  }

  static int? _parseHouseholdSize(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  static Set<String> _normalizeDietStyles(Set<String> values) {
    final next = {...values};
    if (next.contains('no_special_diet') && next.length > 1) {
      next.remove('no_special_diet');
    }
    if (next.isEmpty) {
      return <String>{};
    }
    return next;
  }

  static String _dietStyleLabel(BuildContext context, String value) {
    return switch (value) {
      'no_special_diet' => context.tr(
        en: 'No special diet',
        sk: 'Bez špeciálnej diéty',
      ),
      'vegan' => context.tr(en: 'Vegan', sk: 'Vegán'),
      'vegetarian' => context.tr(en: 'Vegetarian', sk: 'Vegetarián'),
      'keto' => context.tr(en: 'Keto', sk: 'Keto'),
      'omnivore' => context.tr(en: 'Omnivore', sk: 'Všežravec'),
      'flexitarian' => context.tr(en: 'Flexitarian', sk: 'Flexitarián'),
      'pescatarian' => context.tr(en: 'Pescatarian', sk: 'Pescetarián'),
      'low_carb' => context.tr(
        en: 'Low-carb',
        sk: 'Nízkosacharidová strava',
      ),
      'mediterranean' => context.tr(
        en: 'Mediterranean',
        sk: 'Stredomorská strava',
      ),
      'gluten_free' => context.tr(en: 'Gluten-free', sk: 'Bezlepková strava'),
      'lactose_free' => context.tr(
        en: 'Lactose-free',
        sk: 'Bezlaktózová strava',
      ),
      'halal' => context.tr(en: 'Halal', sk: 'Halal'),
      'kosher' => context.tr(en: 'Kosher', sk: 'Kóšer'),
      'plant_based' => context.tr(
        en: 'Plant-based',
        sk: 'Rastlinná strava',
      ),
      _ => value,
    };
  }

  static String _cookingFrequencyLabel(BuildContext context, String value) {
    return switch (value) {
      'daily' => context.tr(en: 'Daily', sk: 'Denne'),
      'few_times_week' => context.tr(
        en: 'A few times a week',
        sk: 'Niekoľkokrát do týždňa',
      ),
      'weekends_only' => context.tr(en: 'Weekends only', sk: 'Len cez víkend'),
      'rarely' => context.tr(en: 'Rarely', sk: 'Zriedka'),
      _ => value,
    };
  }

  static String _favoriteMealLabel(BuildContext context, String value) {
    return switch (value) {
      'pasta' => context.tr(en: 'Pasta', sk: 'Cestoviny'),
      'salad' => context.tr(en: 'Salad', sk: 'Šalát'),
      'soup' => context.tr(en: 'Soup', sk: 'Polievka'),
      'sandwich' => context.tr(en: 'Sandwich', sk: 'Sendvič'),
      'pizza' => context.tr(en: 'Pizza', sk: 'Pizza'),
      'burger' => context.tr(en: 'Burger', sk: 'Burger'),
      'sushi' => context.tr(en: 'Sushi', sk: 'Sushi'),
      'curry' => context.tr(en: 'Curry', sk: 'Kari'),
      'rice_dishes' => context.tr(en: 'Rice dishes', sk: 'Ryžové jedlá'),
      'noodles' => context.tr(en: 'Noodles', sk: 'Rezance'),
      'grilled' => context.tr(en: 'Grilled', sk: 'Grilované jedlá'),
      'omelette' => context.tr(en: 'Omelette', sk: 'Omeleta'),
      _ => value,
    };
  }

  static String _favoriteFoodLabel(BuildContext context, String value) {
    return switch (value) {
      'chicken' => context.tr(en: 'Chicken', sk: 'Kuracie mäso'),
      'rice' => context.tr(en: 'Rice', sk: 'Ryža'),
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      'cheese' => context.tr(en: 'Cheese', sk: 'Syr'),
      'bread' => context.tr(en: 'Bread', sk: 'Chlieb'),
      'potatoes' => context.tr(en: 'Potatoes', sk: 'Zemiaky'),
      'pasta' => context.tr(en: 'Pasta', sk: 'Cestoviny'),
      'beef' => context.tr(en: 'Beef', sk: 'Hovädzie mäso'),
      'fish' => context.tr(en: 'Fish', sk: 'Ryby'),
      'seafood' => context.tr(en: 'Seafood', sk: 'Morské plody'),
      'fruit' => context.tr(en: 'Fruit', sk: 'Ovocie'),
      'vegetables' => context.tr(en: 'Vegetables', sk: 'Zelenina'),
      'chocolate' => context.tr(en: 'Chocolate', sk: 'Čokoláda'),
      'yogurt' => context.tr(en: 'Yogurt', sk: 'Jogurt'),
      'nuts' => context.tr(en: 'Nuts', sk: 'Orechy'),
      'beans' => context.tr(en: 'Beans', sk: 'Fazuľa'),
      _ => value,
    };
  }

  static String _allergyLabel(BuildContext context, String value) {
    return switch (value) {
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      'peanuts' => context.tr(en: 'Peanuts', sk: 'Arašidy'),
      'soy' => context.tr(en: 'Soy', sk: 'Sója'),
      'tree_nuts' => context.tr(en: 'Tree nuts', sk: 'Stromové orechy'),
      'milk' => context.tr(en: 'Milk', sk: 'Mlieko'),
      'wheat' => context.tr(en: 'Wheat', sk: 'Pšenica'),
      'fish' => context.tr(en: 'Fish', sk: 'Ryby'),
      'shellfish' => context.tr(en: 'Shellfish', sk: 'Morské plody'),
      'sesame' => context.tr(en: 'Sesame', sk: 'Sezam'),
      _ => value,
    };
  }

  static String _intoleranceLabel(BuildContext context, String value) {
    return switch (value) {
      'lactose' => context.tr(en: 'Lactose', sk: 'Laktóza'),
      'gluten' => context.tr(en: 'Gluten', sk: 'Lepok'),
      'histamine' => context.tr(en: 'Histamine', sk: 'Histamín'),
      'fructose' => context.tr(en: 'Fructose', sk: 'Fruktóza'),
      'fodmap' => context.tr(en: 'FODMAP', sk: 'FODMAP'),
      'additives' => context.tr(en: 'Additives', sk: 'Prídavné látky'),
      'alcohol' => context.tr(en: 'Alcohol', sk: 'Alkohol'),
      _ => value,
    };
  }
}

class _OnboardingHeaderBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OnboardingHeaderBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SafoSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: SafoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        border: Border.all(color: SafoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SafoColors.textPrimary),
          const SizedBox(width: SafoSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final IconData? icon;
  final Color? accent;

  const _PreferenceSection({
    required this.title,
    required this.subtitle,
    required this.children,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6DDCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (accent ?? SafoColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: accent ?? SafoColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PreferencesHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PreferencesHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(SafoRadii.pill),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(SafoRadii.pill),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SafoColors.surface,
                    borderRadius: BorderRadius.circular(SafoRadii.pill),
                    border: Border.all(color: SafoColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: SafoColors.textPrimary,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SafoLogo(
              variant: SafoLogoVariant.pill,
              height: 28,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          context.tr(
            en: 'Your kitchen settings',
            sk: 'Nastavenia tvojej kuchyne',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SafoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(en: 'Preferences', sk: 'Preferencie'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(
            en: 'Keep recipes, shopping defaults, and household recommendations aligned with how you actually live.',
            sk: 'Udrž recepty, nákupné predvoľby a odporúčania domácnosti v súlade s tým, ako naozaj funguješ.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: SafoColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _PreferencesOverview extends StatelessWidget {
  final int favoriteCount;
  final int dietaryCount;
  final int profileCount;

  const _PreferencesOverview({
    required this.favoriteCount,
    required this.dietaryCount,
    required this.profileCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.92,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _PreferencesOverviewCard(
          label: context.tr(en: 'Favorites', sk: 'Obľúbené'),
          value: favoriteCount.toString(),
          background: SafoColors.surface,
          valueColor: SafoColors.textPrimary,
        ),
        _PreferencesOverviewCard(
          label: context.tr(en: 'Diet & safety', sk: 'Diéta a bezpečnosť'),
          value: dietaryCount.toString(),
          background: SafoColors.primarySoft,
          valueColor: SafoColors.primary,
        ),
        _PreferencesOverviewCard(
          label: context.tr(en: 'Household', sk: 'Domácnosť'),
          value: profileCount.toString(),
          background: SafoColors.accentSoft,
          valueColor: SafoColors.accent,
        ),
      ],
    );
  }
}

class _PreferencesOverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color valueColor;

  const _PreferencesOverviewCard({
    required this.label,
    required this.value,
    required this.background,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SafoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenSetupHero extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String subtitle;

  const _KitchenSetupHero({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: SafoColors.border),
      ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.12,
            child: Image.asset(
              imageAsset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    const Color(0xFFF7F3EB).withValues(alpha: 0.18),
                    SafoColors.background.withValues(alpha: 0.84),
                    SafoColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.36, 0.78, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.tr(en: 'Kitchen profile', sk: 'Profil kuchyne'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                    height: 1.45,
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

class _KitchenSetupSummary extends StatelessWidget {
  final String title;
  final List<String> items;

  const _KitchenSetupSummary({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: SafoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SafoColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceField extends StatelessWidget {
  final String label;
  final String hint;
  final Widget child;

  const _PreferenceField({
    required this.label,
    required this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PreferenceChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selectedValues;
  final String Function(String value) labelBuilder;
  final TextEditingController customController;
  final bool allowCustom;
  final String customLabel;
  final int featuredCount;
  final ValueChanged<Set<String>> onChanged;

  const _PreferenceChipSelector({
    required this.options,
    required this.selectedValues,
    required this.labelBuilder,
    required this.customController,
    this.allowCustom = true,
    required this.customLabel,
    this.featuredCount = 4,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final featuredOptions = options.take(featuredCount).toList();
    final moreOptions = options.skip(featuredCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: featuredOptions.map((value) {
            final selected = selectedValues.contains(value);
            return FilterChip(
              label: Text(labelBuilder(value)),
              selected: selected,
              onSelected: (isSelected) {
                final next = {...selectedValues};
                if (isSelected) {
                  next.add(value);
                } else {
                  next.remove(value);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
        if (moreOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: appInputDecoration(
              context.tr(en: 'More options', sk: 'Ďalšie možnosti'),
            ),
            hint: Text(
              context.tr(
                en: 'Select more options',
                sk: 'Vyber ďalšie možnosti',
              ),
            ),
            items: moreOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            labelBuilder(value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedValues.contains(value))
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: SafoColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final next = {...selectedValues};
              if (next.contains(value)) {
                next.remove(value);
              } else {
                next.add(value);
              }
              onChanged(next);
            },
          ),
        ],
        if (allowCustom) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: customController,
            decoration: appInputDecoration(customLabel),
          ),
        ],
      ],
    );
  }
}

class _MultiChoiceChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selectedValues;
  final String Function(String value) labelBuilder;
  final int featuredCount;
  final ValueChanged<Set<String>> onChanged;

  const _MultiChoiceChipSelector({
    required this.options,
    required this.selectedValues,
    required this.labelBuilder,
    this.featuredCount = 3,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final featuredOptions = options.take(featuredCount).toList();
    final moreOptions = options.skip(featuredCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: featuredOptions.map((value) {
            final selected = selectedValues.contains(value);
            return FilterChip(
              label: Text(labelBuilder(value)),
              selected: selected,
              onSelected: (isSelected) {
                final next = {...selectedValues};
                if (isSelected) {
                  next.add(value);
                } else {
                  next.remove(value);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
        if (moreOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: null,
            decoration: appInputDecoration(
              context.tr(en: 'More diet styles', sk: 'Ďalšie štýly stravy'),
            ),
            hint: Text(
              context.tr(
                en: 'Select another option',
                sk: 'Vyber ďalšiu možnosť',
              ),
            ),
            items: moreOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            labelBuilder(value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedValues.contains(value))
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: SafoColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final next = {...selectedValues};
              if (next.contains(value)) {
                next.remove(value);
              } else {
                next.add(value);
              }
              onChanged(next);
            },
          ),
        ],
      ],
    );
  }
}
