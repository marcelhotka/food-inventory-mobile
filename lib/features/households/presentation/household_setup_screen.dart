import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/sign_out_action.dart';
import '../data/household_repository.dart';

class HouseholdSetupScreen extends StatefulWidget {
  final HouseholdRepository repository;
  final AuthRepository authRepository;
  final Future<void> Function() onCreated;

  const HouseholdSetupScreen({
    super.key,
    required this.repository,
    required this.authRepository,
    required this.onCreated,
  });

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  bool _isSubmitting = false;
  bool _isJoinMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    await confirmAndSignOut(context, widget.authRepository);
  }

  Future<void> _createHousehold() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.repository.createHousehold(_nameController.text.trim());
      await widget.onCreated();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(en: 'Household created.', sk: 'Domácnosť bola vytvorená.'),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to create household.',
          sk: 'Domácnosť sa nepodarilo vytvoriť.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _joinHousehold() async {
    if ((_joinCodeController.text).trim().isEmpty) {
      showErrorFeedback(
        context,
        context.tr(en: 'Enter a household code.', sk: 'Zadaj kód domácnosti.'),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.repository.joinHousehold(_joinCodeController.text.trim());
      await widget.onCreated();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Joined household.',
          sk: 'Pripojenie do domácnosti bolo úspešné.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to join household.',
          sk: 'Do domácnosti sa nepodarilo pripojiť.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              const SafoLogo(
                variant: SafoLogoVariant.iconTransparent,
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 10),
              const SafoLogo(
                variant: SafoLogoVariant.pill,
                height: 28,
              ),
              const Spacer(),
              Material(
                color: SafoColors.surface,
                borderRadius: BorderRadius.circular(SafoRadii.pill),
                child: InkWell(
                  onTap: () => _handleSignOut(),
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
                      Icons.logout_rounded,
                      color: SafoColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: [Color(0xFFE9F1E5), Color(0xFFF6E2CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFE2D7C6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SafoLogo(
                  variant: SafoLogoVariant.stacked,
                  width: 108,
                  height: 132,
                ),
                const SizedBox(height: 18),
                Text(
                  _isJoinMode
                      ? context.tr(
                          en: 'Join your shared kitchen',
                          sk: 'Pripoj sa do spoločnej kuchyne',
                        )
                      : context.tr(
                          en: 'Set up your shared kitchen',
                          sk: 'Nastav si spoločnú kuchyňu',
                        ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isJoinMode
                      ? context.tr(
                          en: 'Use a household code from another member and share the same pantry, shopping list, and kitchen coordination.',
                          sk: 'Použi kód domácnosti od ďalšieho člena a zdieľaj rovnakú špajzu, nákupný zoznam aj kuchynskú koordináciu.',
                        )
                      : context.tr(
                          en: 'Create one Safo household so your pantry, shopping list, and cooking plans stay in sync for everyone at home.',
                          sk: 'Vytvor jednu Safo domácnosť, aby špajza, nákupný zoznam a plány varenia ostali zosynchronizované pre všetkých doma.',
                        ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF4B5A4D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: SafoColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(en: 'Start your household', sk: 'Začni s domácnosťou'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isJoinMode
                        ? context.tr(
                            en: 'Enter the code from another Safo member.',
                            sk: 'Zadaj kód od ďalšieho člena Safo.',
                          )
                        : context.tr(
                            en: 'Create one place for pantry, shopping, and planning.',
                            sk: 'Vytvor jedno miesto pre špajzu, nákup a plánovanie.',
                          ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(context.tr(en: 'Create', sk: 'Vytvoriť')),
                        icon: const Icon(Icons.add_home_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(context.tr(en: 'Join', sk: 'Pripojiť sa')),
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                    ],
                    selected: {_isJoinMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isJoinMode = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_isJoinMode)
                    TextFormField(
                      controller: _joinCodeController,
                      decoration: appInputDecoration(
                        context.tr(en: 'Household code', sk: 'Kód domácnosti'),
                      ),
                    )
                  else
                    TextFormField(
                      controller: _nameController,
                      decoration: appInputDecoration(
                        context.tr(
                          en: 'Household name',
                          sk: 'Názov domácnosti',
                        ),
                      ),
                      validator: (value) {
                        if (_isJoinMode) {
                          return null;
                        }
                        if ((value ?? '').trim().isEmpty) {
                          return context.tr(
                            en: 'Enter a household name',
                            sk: 'Zadaj názov domácnosti',
                          );
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : (_isJoinMode ? _joinHousehold : _createHousehold),
                      child: Text(
                        _isSubmitting
                            ? (_isJoinMode
                                  ? context.tr(
                                      en: 'Joining...',
                                      sk: 'Pripájam...',
                                    )
                                  : context.tr(
                                      en: 'Creating...',
                                      sk: 'Vytváram...',
                                    ))
                            : (_isJoinMode
                                  ? context.tr(
                                      en: 'Join household',
                                      sk: 'Pripojiť sa do domácnosti',
                                    )
                                  : context.tr(
                                      en: 'Create household',
                                      sk: 'Vytvoriť domácnosť',
                                    )),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEE4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _isJoinMode
                          ? context.tr(
                              en: 'Joining a household gives you access to the shared pantry, shopping list and tasks right away.',
                              sk: 'Po pripojení do domácnosti získaš hneď prístup k zdieľanej špajzi, nákupnému zoznamu aj úlohám.',
                            )
                          : context.tr(
                              en: 'You can invite others later and build one shared kitchen flow together.',
                              sk: 'Ďalších členov môžeš pozvať neskôr a postupne si spolu vybudovať jeden spoločný kuchynský flow.',
                            ),
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
  }
}
