import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
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
      appBar: AppBar(
        title: Text(
          context.tr(en: 'Create household', sk: 'Vytvoriť domácnosť'),
        ),
        actions: [
          IconButton(
            onPressed: widget.authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: context.tr(en: 'Sign out', sk: 'Odhlásiť sa'),
          ),
        ],
      ),
      body: ListView(
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
                    _isJoinMode
                        ? context.tr(
                            en: 'Join a shared kitchen',
                            sk: 'Pripoj sa do zdieľanej kuchyne',
                          )
                        : context.tr(
                            en: 'Start your shared kitchen',
                            sk: 'Spusti svoju zdieľanú kuchyňu',
                          ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isJoinMode
                        ? context.tr(
                            en: 'Enter a household code from another family member to share the same pantry and shopping list.',
                            sk: 'Zadaj kód domácnosti od ďalšieho člena rodiny, aby ste zdieľali rovnakú špajzu a nákupný zoznam.',
                          )
                        : context.tr(
                            en: 'Create one household so your pantry and shopping list can be shared later with other family members.',
                            sk: 'Vytvor jednu domácnosť, aby si mohol neskôr zdieľať špajzu a nákupný zoznam s ďalšími členmi rodiny.',
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
