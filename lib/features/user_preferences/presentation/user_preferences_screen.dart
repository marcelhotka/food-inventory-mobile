import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/user_preferences_remote_data_source.dart';
import '../data/user_preferences_repository.dart';
import '../domain/user_preferences.dart';

class UserPreferencesScreen extends StatefulWidget {
  final bool isOnboarding;
  final Future<void> Function()? onCompleted;

  const UserPreferencesScreen({
    super.key,
    this.isOnboarding = false,
    this.onCompleted,
  });

  @override
  State<UserPreferencesScreen> createState() => _UserPreferencesScreenState();
}

class _UserPreferencesScreenState extends State<UserPreferencesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _favoriteMealsController = TextEditingController();
  final _favoriteFoodsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _intolerancesController = TextEditingController();
  final _householdSizeController = TextEditingController();

  late final UserPreferencesRepository _repository =
      UserPreferencesRepository();
  late Future<UserPreferences?> _preferencesFuture = _repository
      .getCurrentUserPreferences();

  String? _selectedDietStyle;
  String? _selectedCookingFrequency;
  String? _selectedLanguage;
  Set<String> _selectedFavoriteMeals = <String>{};
  Set<String> _selectedFavoriteFoods = <String>{};
  Set<String> _selectedAllergies = <String>{};
  Set<String> _selectedIntolerances = <String>{};
  bool _onboardingCompleted = false;
  bool _isSaving = false;
  UserPreferences? _loadedPreferences;

  static const _dietStyles = [
    'omnivore',
    'vegetarian',
    'vegan',
    'pescatarian',
    'low_carb',
    'high_protein',
  ];

  static const _cookingFrequencies = [
    'daily',
    'few_times_week',
    'weekends_only',
    'rarely',
  ];

  static const _favoriteMealOptions = [
    'pasta',
    'omelette',
    'rice_bowl',
    'sandwich',
    'salad',
    'soup',
    'curry',
    'breakfast',
  ];

  static const _favoriteFoodOptions = [
    'milk',
    'cheese',
    'eggs',
    'yogurt',
    'bread',
    'rice',
    'pasta',
    'chicken',
    'beans',
    'tomatoes',
  ];

  static const _allergyOptions = [
    'peanuts',
    'tree_nuts',
    'eggs',
    'soy',
    'fish',
    'shellfish',
    'sesame',
  ];

  static const _intoleranceOptions = ['lactose', 'gluten', 'milk', 'eggs'];

  @override
  void dispose() {
    _favoriteMealsController.dispose();
    _favoriteFoodsController.dispose();
    _allergiesController.dispose();
    _intolerancesController.dispose();
    _householdSizeController.dispose();
    super.dispose();
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
    _selectedDietStyle = preferences?.dietStyle;
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
      dietStyle: _selectedDietStyle,
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
      _selectedDietStyle = 'omnivore';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
          widget.isOnboarding
              ? context.tr(en: 'Set up your kitchen', sk: 'Nastavenie kuchyne')
              : context.tr(en: 'Preferences', sk: 'Preferencie'),
        ),
      ),
      body: FutureBuilder<UserPreferences?>(
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
              message:
                  configError?.message ??
                  context.tr(
                    en: 'Failed to load preferences.',
                    sk: 'Preferencie sa nepodarilo načítať.',
                  ),
              onRetry: _reload,
            );
          }

          _applyLoadedPreferences(snapshot.data);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
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
                                en: 'Personalize your kitchen',
                                sk: 'Prispôsob si svoju kuchyňu',
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
                                en: 'Save favorite meals, food preferences and dietary limits now. Later we can reuse this exact data for onboarding, recipe suggestions and smarter shopping defaults.',
                                sk: 'Ulož si obľúbené jedlá, potraviny a stravovacie obmedzenia. Neskôr tieto údaje využijeme pri onboardingu, odporúčaní receptov aj pri múdrejších nákupoch.',
                              ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      _PreferenceSection(
                        title: context.tr(
                          en: 'Meals and foods',
                          sk: 'Jedlá a potraviny',
                        ),
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
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedDietStyle,
                              decoration: appInputDecoration(
                                context.tr(
                                  en: 'Diet style',
                                  sk: 'Štýl stravovania',
                                ),
                              ),
                              items: _dietStyles
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        _dietStyleLabel(context, value),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDietStyle = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreferenceSection(
                        title: context.tr(en: 'Language', sk: 'Jazyk'),
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

  static String _dietStyleLabel(BuildContext context, String value) {
    return switch (value) {
      'omnivore' => context.tr(en: 'Omnivore', sk: 'Všežravec'),
      'vegetarian' => context.tr(en: 'Vegetarian', sk: 'Vegetarián'),
      'vegan' => context.tr(en: 'Vegan', sk: 'Vegán'),
      'pescatarian' => context.tr(en: 'Pescatarian', sk: 'Pescetarián'),
      'low_carb' => context.tr(en: 'Low carb', sk: 'Nízkosacharidová strava'),
      'high_protein' => context.tr(
        en: 'High protein',
        sk: 'Vysokobielkovinová strava',
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
      'omelette' => context.tr(en: 'Omelette', sk: 'Omeleta'),
      'rice_bowl' => context.tr(en: 'Rice bowl', sk: 'Ryžový bowl'),
      'sandwich' => context.tr(en: 'Sandwich', sk: 'Sendvič'),
      'salad' => context.tr(en: 'Salad', sk: 'Šalát'),
      'soup' => context.tr(en: 'Soup', sk: 'Polievka'),
      'curry' => context.tr(en: 'Curry', sk: 'Kari'),
      'breakfast' => context.tr(en: 'Breakfast', sk: 'Raňajky'),
      _ => value,
    };
  }

  static String _favoriteFoodLabel(BuildContext context, String value) {
    return switch (value) {
      'milk' => context.tr(en: 'Milk', sk: 'Mlieko'),
      'cheese' => context.tr(en: 'Cheese', sk: 'Syr'),
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      'yogurt' => context.tr(en: 'Yogurt', sk: 'Jogurt'),
      'bread' => context.tr(en: 'Bread', sk: 'Chlieb'),
      'rice' => context.tr(en: 'Rice', sk: 'Ryža'),
      'pasta' => context.tr(en: 'Pasta', sk: 'Cestoviny'),
      'chicken' => context.tr(en: 'Chicken', sk: 'Kuracie mäso'),
      'beans' => context.tr(en: 'Beans', sk: 'Fazuľa'),
      'tomatoes' => context.tr(en: 'Tomatoes', sk: 'Paradajky'),
      _ => value,
    };
  }

  static String _allergyLabel(BuildContext context, String value) {
    return switch (value) {
      'peanuts' => context.tr(en: 'Peanuts', sk: 'Arašidy'),
      'tree_nuts' => context.tr(en: 'Tree nuts', sk: 'Orechy'),
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      'soy' => context.tr(en: 'Soy', sk: 'Sója'),
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
      'milk' => context.tr(en: 'Milk', sk: 'Mlieko'),
      'eggs' => context.tr(en: 'Eggs', sk: 'Vajcia'),
      _ => value,
    };
  }
}

class _PreferenceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _PreferenceSection({
    required this.title,
    required this.subtitle,
    required this.children,
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
  final String customLabel;
  final ValueChanged<Set<String>> onChanged;

  const _PreferenceChipSelector({
    required this.options,
    required this.selectedValues,
    required this.labelBuilder,
    required this.customController,
    required this.customLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((value) {
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
        const SizedBox(height: 12),
        TextFormField(
          controller: customController,
          decoration: appInputDecoration(customLabel),
        ),
      ],
    );
  }
}
