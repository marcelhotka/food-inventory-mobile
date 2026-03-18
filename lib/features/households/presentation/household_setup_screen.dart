import 'package:flutter/material.dart';

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
      showSuccessFeedback(context, 'Household created.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to create household.');
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
      showErrorFeedback(context, 'Enter a household code.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.repository.joinHousehold(_joinCodeController.text.trim());
      await widget.onCreated();
      if (!mounted) return;
      showSuccessFeedback(context, 'Joined household.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to join household.');
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
        title: const Text('Create household'),
        actions: [
          IconButton(
            onPressed: widget.authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
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
                        ? 'Join a shared kitchen'
                        : 'Start your shared kitchen',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isJoinMode
                        ? 'Enter a household code from another family member to share the same pantry and shopping list.'
                        : 'Create one household so your pantry and shopping list can be shared later with other family members.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Create'),
                        icon: Icon(Icons.add_home_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Join'),
                        icon: Icon(Icons.group_add_outlined),
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
                      decoration: appInputDecoration('Household code'),
                    )
                  else
                    TextFormField(
                      controller: _nameController,
                      decoration: appInputDecoration('Household name'),
                      validator: (value) {
                        if (_isJoinMode) {
                          return null;
                        }
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a household name';
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
                            ? (_isJoinMode ? 'Joining...' : 'Creating...')
                            : (_isJoinMode
                                  ? 'Join household'
                                  : 'Create household'),
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
