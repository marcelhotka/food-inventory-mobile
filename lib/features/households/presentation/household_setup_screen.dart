import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/sign_out_action.dart';
import '../data/household_repository.dart';
import '../domain/household.dart';

enum _HouseholdSetupStep { choose, create, join }

class HouseholdSetupScreen extends StatefulWidget {
  final HouseholdRepository repository;
  final AuthRepository authRepository;
  final Future<void> Function() onCreated;
  final VoidCallback? onBackToKitchenSetup;
  final Household? editableHousehold;
  final bool openCreateByDefault;

  const HouseholdSetupScreen({
    super.key,
    required this.repository,
    required this.authRepository,
    required this.onCreated,
    this.onBackToKitchenSetup,
    this.editableHousehold,
    this.openCreateByDefault = false,
  });

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  bool _isSubmitting = false;
  late _HouseholdSetupStep _step;

  bool get _isEditingExistingHousehold => widget.editableHousehold != null;

  @override
  void initState() {
    super.initState();
    _step = widget.openCreateByDefault
        ? _HouseholdSetupStep.create
        : _HouseholdSetupStep.choose;
    _nameController.text = widget.editableHousehold?.name ?? '';
  }

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
      if (_isEditingExistingHousehold) {
        await widget.repository.updateHouseholdName(
          widget.editableHousehold!.id,
          _nameController.text.trim(),
        );
      } else {
        await widget.repository.createHousehold(_nameController.text.trim());
      }
      await widget.onCreated();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        _isEditingExistingHousehold
            ? context.tr(
                en: 'Household name updated.',
                sk: 'Názov domácnosti je upravený.',
              )
            : context.tr(
                en: 'Household created.',
                sk: 'Domácnosť bola vytvorená.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        _isEditingExistingHousehold
            ? context.tr(
                en: 'Failed to update household name.',
                sk: 'Názov domácnosti sa nepodarilo upraviť.',
              )
            : context.tr(
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

  void _goTo(_HouseholdSetupStep step) {
    setState(() {
      _step = step;
    });
  }

  void _goBack() {
    if (_step == _HouseholdSetupStep.choose ||
        (_isEditingExistingHousehold && _step == _HouseholdSetupStep.create)) {
      widget.onBackToKitchenSetup?.call();
      return;
    }
    setState(() {
      _step = _HouseholdSetupStep.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 180) {
              _goBack();
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  if (_step != _HouseholdSetupStep.choose) ...[
                    _HouseholdHeaderButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _goBack,
                    ),
                    const SizedBox(width: 10),
                  ],
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
                  _HouseholdHeaderButton(
                    icon: Icons.logout_rounded,
                    onTap: _handleSignOut,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _HouseholdHero(step: _step),
              const SizedBox(height: 20),
              if (_step == _HouseholdSetupStep.choose && !_isEditingExistingHousehold) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: SafoColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SafoColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          en: 'Choose how you want to start',
                          sk: 'Vyber si, ako chceš začať',
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          en: 'You can start your own shared kitchen or jump into one that already exists at home.',
                          sk: 'Môžeš si založiť vlastnú spoločnú kuchyňu alebo sa pripojiť do tej, ktorá už doma funguje.',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SafoColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HouseholdChoiceCard(
                  primary: true,
                  icon: Icons.add_home_rounded,
                  title: context.tr(
                    en: 'Create household',
                    sk: 'Vytvoriť domácnosť',
                  ),
                  subtitle: context.tr(
                    en: 'Start fresh and invite your family later.',
                    sk: 'Začni odznova a ďalších členov pozveš neskôr.',
                  ),
                  onTap: () => _goTo(_HouseholdSetupStep.create),
                ),
                const SizedBox(height: 14),
                _HouseholdChoiceCard(
                  primary: false,
                  icon: Icons.link_rounded,
                  title: context.tr(
                    en: 'Join household',
                    sk: 'Pripojiť sa do domácnosti',
                  ),
                  subtitle: context.tr(
                    en: 'Use an invite code and access the shared pantry right away.',
                    sk: 'Použi pozývací kód a hneď získaj prístup k spoločnej špajzi.',
                  ),
                  onTap: () => _goTo(_HouseholdSetupStep.join),
                ),
                const SizedBox(height: 14),
                _HouseholdInfoCard(
                  icon: Icons.auto_awesome_rounded,
                  title: context.tr(
                    en: 'Everything stays in one place',
                    sk: 'Všetko ostane na jednom mieste',
                  ),
                  message: context.tr(
                    en: 'Pantry, shopping, expiring food, and cooking plans will stay shared for everyone in the household.',
                    sk: 'Špajza, nákup, potraviny pred expirácou aj plánovanie varenia budú spoločné pre všetkých v domácnosti.',
                  ),
                ),
              ] else ...[
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
                        if (!_isEditingExistingHousehold) ...[
                          _HouseholdModeSwitcher(
                            selectedStep: _step,
                            onSelected: _goTo,
                          ),
                          const SizedBox(height: 18),
                        ],
                        _HouseholdSectionBadge(
                          label: _step == _HouseholdSetupStep.join
                              ? context.tr(
                                  en: 'Step 2 of 2',
                                  sk: 'Krok 2 z 2',
                                )
                              : _isEditingExistingHousehold
                              ? context.tr(
                                  en: 'Update your household',
                                  sk: 'Uprav svoju domácnosť',
                                )
                              : context.tr(
                                  en: 'Step 2 of 2',
                                  sk: 'Krok 2 z 2',
                                ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _step == _HouseholdSetupStep.join
                              ? context.tr(
                                  en: 'Enter invite code',
                                  sk: 'Zadaj pozývací kód',
                                )
                              : _isEditingExistingHousehold
                              ? context.tr(
                                  en: 'Update household name',
                                  sk: 'Uprav názov domácnosti',
                                )
                              : context.tr(
                                  en: 'Name your household',
                                  sk: 'Pomenuj domácnosť',
                                ),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == _HouseholdSetupStep.join
                              ? context.tr(
                                  en: 'Ask your household admin for the 6-character code.',
                                  sk: 'Požiadaj správcu domácnosti o 6-miestny kód.',
                                )
                              : _isEditingExistingHousehold
                              ? context.tr(
                                  en: 'Adjust the shared household name if you want it to read better for everyone at home.',
                                  sk: 'Uprav spoločný názov domácnosti, ak ho chceš sprehľadniť pre všetkých doma.',
                                )
                              : context.tr(
                                  en: 'Choose a name everyone at home will recognize.',
                                  sk: 'Vyber názov, ktorý bude doma každému jasný.',
                                ),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SafoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_step == _HouseholdSetupStep.join)
                          TextFormField(
                            controller: _joinCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: appInputDecoration(
                              context.tr(
                                en: 'Household code',
                                sk: 'Kód domácnosti',
                              ),
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
                        _HouseholdHelperList(
                          items: _step == _HouseholdSetupStep.join
                              ? [
                                  context.tr(
                                    en: 'Ask for the invite code from someone already in the household.',
                                    sk: 'Vyžiadaj si pozývací kód od niekoho, kto už v domácnosti je.',
                                  ),
                                  context.tr(
                                    en: 'After joining, you will instantly see the shared pantry and shopping list.',
                                    sk: 'Po pripojení hneď uvidíš spoločnú špajzu aj nákupný zoznam.',
                                  ),
                                ]
                              : [
                                  context.tr(
                                    en: 'Pick a simple name everyone at home will recognize.',
                                    sk: 'Vyber jednoduchý názov, ktorý doma každý spozná.',
                                  ),
                                  context.tr(
                                    en: 'You can invite more members and assign tasks later.',
                                    sk: 'Ďalších členov aj úlohy môžeš pridať neskôr.',
                                  ),
                                ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSubmitting
                                ? null
                                : (_step == _HouseholdSetupStep.join
                                      ? _joinHousehold
                                      : _createHousehold),
                            child: Text(
                              _isSubmitting
                                  ? (_step == _HouseholdSetupStep.join
                                        ? context.tr(
                                            en: 'Joining...',
                                            sk: 'Pripájam...',
                                          )
                                        : _isEditingExistingHousehold
                                        ? context.tr(
                                            en: 'Saving...',
                                            sk: 'Ukladám...',
                                          )
                                        : context.tr(
                                            en: 'Creating...',
                                            sk: 'Vytváram...',
                                          ))
                                  : (_step == _HouseholdSetupStep.join
                                        ? context.tr(
                                            en: 'Join household',
                                            sk: 'Pripojiť sa do domácnosti',
                                          )
                                        : _isEditingExistingHousehold
                                        ? context.tr(
                                            en: 'Save household name',
                                            sk: 'Uložiť názov domácnosti',
                                          )
                                        : context.tr(
                                            en: 'Create household',
                                            sk: 'Vytvoriť domácnosť',
                                          )),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _HouseholdInfoCard(
                          icon: _step == _HouseholdSetupStep.join
                              ? Icons.groups_rounded
                              : Icons.favorite_rounded,
                          title: _step == _HouseholdSetupStep.join
                              ? context.tr(
                                  en: 'You will join the shared kitchen',
                                  sk: 'Pripojíš sa do spoločnej kuchyne',
                                )
                              : _isEditingExistingHousehold
                              ? context.tr(
                                  en: 'Keep it clear for everyone',
                                  sk: 'Udrž to pre všetkých jasné',
                                )
                              : context.tr(
                                  en: 'Invite others later',
                                  sk: 'Ďalších pozveš neskôr',
                                ),
                          message: _step == _HouseholdSetupStep.join
                              ? context.tr(
                                  en: 'Joining gives you immediate access to the shared pantry, shopping list, and household tasks.',
                                  sk: 'Po pripojení hneď získaš prístup k spoločnej špajzi, nákupnému zoznamu aj domácim úlohám.',
                                )
                              : _isEditingExistingHousehold
                              ? context.tr(
                                  en: 'Changing the name here keeps the shared kitchen clearer for everyone before you continue.',
                                  sk: 'Zmena názvu tu pomôže, aby bola spoločná kuchyňa pre všetkých prehľadnejšia ešte pred pokračovaním.',
                                )
                              : context.tr(
                                  en: 'You can invite other members later and build one shared kitchen flow together.',
                                  sk: 'Ďalších členov môžeš pozvať neskôr a postupne si spolu vybudovať jeden spoločný kuchynský flow.',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseholdSectionBadge extends StatelessWidget {
  final String label;

  const _HouseholdSectionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: SafoColors.primarySoft,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: SafoColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HouseholdHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HouseholdHeaderButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SafoColors.surface,
      borderRadius: BorderRadius.circular(SafoRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(SafoRadii.pill),
            border: Border.all(color: SafoColors.border),
          ),
          child: Icon(icon, color: SafoColors.textPrimary),
        ),
      ),
    );
  }
}

class _HouseholdModeSwitcher extends StatelessWidget {
  final _HouseholdSetupStep selectedStep;
  final ValueChanged<_HouseholdSetupStep> onSelected;

  const _HouseholdModeSwitcher({
    required this.selectedStep,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SafoColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SafoColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HouseholdModeButton(
              label: context.tr(
                en: 'Create',
                sk: 'Vytvoriť',
              ),
              selected: selectedStep == _HouseholdSetupStep.create,
              onTap: () => onSelected(_HouseholdSetupStep.create),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HouseholdModeButton(
              label: context.tr(
                en: 'Join',
                sk: 'Pripojiť sa',
              ),
              selected: selectedStep == _HouseholdSetupStep.join,
              onTap: () => onSelected(_HouseholdSetupStep.join),
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HouseholdModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SafoColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? Colors.white : SafoColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseholdHero extends StatelessWidget {
  final _HouseholdSetupStep step;

  const _HouseholdHero({required this.step});

  @override
  Widget build(BuildContext context) {
    final icon = switch (step) {
      _HouseholdSetupStep.choose => Icons.groups_rounded,
      _HouseholdSetupStep.create => Icons.add_home_rounded,
      _HouseholdSetupStep.join => Icons.link_rounded,
    };
    final heroImage = step == _HouseholdSetupStep.create ||
            step == _HouseholdSetupStep.choose ||
            step == _HouseholdSetupStep.join
        ? Image.asset(
            'assets/branding/create-household-hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          )
        : Container(
            color: const Color(0xFFE8F7EE),
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: SafoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: heroImage,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    const Color(0xFFF9F6F0).withValues(alpha: 0.12),
                    SafoColors.background.withValues(alpha: 0.84),
                    SafoColors.background,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.35, 0.78, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: SafoColors.primary,
                size: 30,
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
                  switch (step) {
                    _HouseholdSetupStep.choose => context.tr(
                      en: 'Set up your household',
                      sk: 'Nastav si domácnosť',
                    ),
                    _HouseholdSetupStep.create => context.tr(
                      en: 'Create household',
                      sk: 'Vytvoriť domácnosť',
                    ),
                    _HouseholdSetupStep.join => context.tr(
                      en: 'Join household',
                      sk: 'Pripojiť sa do domácnosti',
                    ),
                  },
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  switch (step) {
                    _HouseholdSetupStep.choose => context.tr(
                      en: 'Create a new household or join an existing one with your family or housemates.',
                      sk: 'Vytvor novú domácnosť alebo sa pripoj do existujúcej spolu s rodinou či spolubývajúcimi.',
                    ),
                    _HouseholdSetupStep.create => context.tr(
                      en: 'Start fresh and create one shared place for pantry, shopping, and planning.',
                      sk: 'Začni odznova a vytvor jedno spoločné miesto pre špajzu, nákup aj plánovanie.',
                    ),
                    _HouseholdSetupStep.join => context.tr(
                      en: 'Enter the invite code from another member to join the shared kitchen.',
                      sk: 'Zadaj pozývací kód od ďalšieho člena a pripoj sa do spoločnej kuchyne.',
                    ),
                  },
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

class _HouseholdHelperList extends StatelessWidget {
  final List<String> items;

  const _HouseholdHelperList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: SafoColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: SafoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: SafoColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _HouseholdInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HouseholdInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SafoColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _HouseholdChoiceCard extends StatelessWidget {
  final bool primary;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HouseholdChoiceCard({
    required this.primary,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = primary ? SafoColors.primary : SafoColors.surface;
    final borderColor = primary ? SafoColors.primary : SafoColors.border;
    final iconBackground = primary
        ? Colors.white.withValues(alpha: 0.18)
        : SafoColors.primarySoft;
    final iconColor = primary ? Colors.white : SafoColors.primary;
    final titleColor = primary ? Colors.white : SafoColors.textPrimary;
    final subtitleColor = primary
        ? Colors.white.withValues(alpha: 0.78)
        : SafoColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: subtitleColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
