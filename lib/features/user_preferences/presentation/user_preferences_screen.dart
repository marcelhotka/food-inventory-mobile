import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _favoriteMealsController.text = _joinList(preferences?.favoriteMeals);
    _favoriteFoodsController.text = _joinList(preferences?.favoriteFoods);
    _allergiesController.text = _joinList(preferences?.allergies);
    _intolerancesController.text = _joinList(preferences?.intolerances);
    _householdSizeController.text =
        preferences?.householdSize?.toString() ?? '';
    _selectedDietStyle = preferences?.dietStyle;
    _selectedCookingFrequency = preferences?.cookingFrequency;
    _onboardingCompleted = preferences?.onboardingCompleted ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(context, 'No signed-in user.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now().toUtc();
    final current = _loadedPreferences;
    final preferences = UserPreferences(
      userId: user.id,
      favoriteMeals: _splitList(_favoriteMealsController.text),
      favoriteFoods: _splitList(_favoriteFoodsController.text),
      allergies: _splitList(_allergiesController.text),
      intolerances: _splitList(_intolerancesController.text),
      dietStyle: _selectedDietStyle,
      cookingFrequency: _selectedCookingFrequency,
      householdSize: _parseHouseholdSize(_householdSizeController.text),
      onboardingCompleted: widget.isOnboarding ? true : _onboardingCompleted,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final saved = await _repository.savePreferences(preferences);
      _applyLoadedPreferences(saved);
      if (widget.onCompleted != null) {
        await widget.onCompleted!();
      }
      if (!mounted) return;
      showSuccessFeedback(
        context,
        widget.isOnboarding
            ? 'Preferences saved. Your kitchen is ready.'
            : 'Preferences saved.',
      );
      if (widget.isOnboarding) {
        return;
      }
    } on UserPreferencesConfigException catch (error) {
      if (!mounted) return;
      showErrorFeedback(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to save preferences.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
          widget.isOnboarding ? 'Set up your kitchen' : 'Preferences',
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
              message: configError?.message ?? 'Failed to load preferences.',
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
                            ? 'Tell us about your kitchen'
                            : 'Personalize your kitchen',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.isOnboarding
                            ? 'Answer a few questions so we can prepare better recipe suggestions, shopping defaults and household recommendations from the start.'
                            : 'Save favorite meals, food preferences and dietary limits now. Later we can reuse this exact data for onboarding, recipe suggestions and smarter shopping defaults.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      _PreferenceSection(
                        title: 'Meals and foods',
                        subtitle:
                            'Tell us what you enjoy most so we can later shape recipe suggestions and shopping defaults.',
                        children: [
                          _PreferenceField(
                            label: 'Favorite meals',
                            hint: 'Pasta, omelette, curry',
                            child: TextFormField(
                              controller: _favoriteMealsController,
                              decoration: appInputDecoration(
                                'Favorite meals (comma separated)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: 'Favorite foods',
                            hint: 'Cheese, rice, yogurt',
                            child: TextFormField(
                              controller: _favoriteFoodsController,
                              decoration: appInputDecoration(
                                'Favorite foods (comma separated)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PreferenceSection(
                        title: 'Dietary needs',
                        subtitle:
                            'Capture allergies, intolerances and diet style so later suggestions stay relevant and safe.',
                        children: [
                          _PreferenceField(
                            label: 'Allergies',
                            hint: 'Peanuts, shellfish',
                            child: TextFormField(
                              controller: _allergiesController,
                              decoration: appInputDecoration(
                                'Allergies (comma separated)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: 'Intolerances',
                            hint: 'Lactose, gluten',
                            child: TextFormField(
                              controller: _intolerancesController,
                              decoration: appInputDecoration(
                                'Intolerances (comma separated)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PreferenceField(
                            label: 'Diet style',
                            hint: 'Choose the closest long-term preference',
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedDietStyle,
                              decoration: appInputDecoration('Diet style'),
                              items: _dietStyles
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(_dietStyleLabel(value)),
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
                        title: 'Household habits',
                        subtitle:
                            'These values help us tune meal-planning and pantry expectations later on.',
                        children: [
                          _PreferenceField(
                            label: 'Cooking frequency',
                            hint: 'How often this household cooks at home',
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCookingFrequency,
                              decoration: appInputDecoration(
                                'Cooking frequency',
                              ),
                              items: _cookingFrequencies
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        _cookingFrequencyLabel(value),
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
                            label: 'Household size',
                            hint:
                                'How many people usually eat from this kitchen',
                            child: TextFormField(
                              controller: _householdSizeController,
                              keyboardType: TextInputType.number,
                              decoration: appInputDecoration('Household size'),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return null;
                                }
                                final parsed = int.tryParse(value!.trim());
                                if (parsed == null || parsed <= 0) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
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
                          title: const Text('Mark onboarding as completed'),
                          subtitle: const Text(
                            'This lets us reuse the same record later when we add first-login onboarding.',
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
                                ? 'Saving...'
                                : widget.isOnboarding
                                ? 'Continue'
                                : 'Save preferences',
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

  static String _joinList(List<String>? values) {
    if (values == null || values.isEmpty) {
      return '';
    }
    return values.join(', ');
  }

  static List<String> _splitList(String rawValue) {
    return rawValue
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _parseHouseholdSize(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  static String _dietStyleLabel(String value) {
    return switch (value) {
      'omnivore' => 'Omnivore',
      'vegetarian' => 'Vegetarian',
      'vegan' => 'Vegan',
      'pescatarian' => 'Pescatarian',
      'low_carb' => 'Low carb',
      'high_protein' => 'High protein',
      _ => value,
    };
  }

  static String _cookingFrequencyLabel(String value) {
    return switch (value) {
      'daily' => 'Daily',
      'few_times_week' => 'A few times a week',
      'weekends_only' => 'Weekends only',
      'rarely' => 'Rarely',
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
