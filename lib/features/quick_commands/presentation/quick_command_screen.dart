import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../data/quick_command_service.dart';
import '../domain/quick_command_models.dart';

class QuickCommandScreen extends StatefulWidget {
  final String householdId;
  final VoidCallback onPantryChanged;
  final VoidCallback onShoppingListChanged;

  const QuickCommandScreen({
    super.key,
    required this.householdId,
    required this.onPantryChanged,
    required this.onShoppingListChanged,
  });

  @override
  State<QuickCommandScreen> createState() => _QuickCommandScreenState();
}

class _QuickCommandScreenState extends State<QuickCommandScreen> {
  late final QuickCommandService _service = QuickCommandService(
    householdId: widget.householdId,
  );
  final TextEditingController _commandController = TextEditingController();
  QuickCommandExecutionResult? _lastResult;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      showErrorFeedback(
        context,
        context.tr(en: 'Enter a command first.', sk: 'Najprv zadaj príkaz.'),
        title: context.tr(en: 'Command missing', sk: 'Chýba príkaz'),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final preview = _service.preview(command);
      final confirmed = await _confirmPreview(preview);
      if (confirmed != true) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
        return;
      }

      final result = await _service.execute(command);
      if (!mounted) {
        return;
      }

      if (result.changedPantry) {
        widget.onPantryChanged();
      }
      if (result.changedShoppingList) {
        widget.onShoppingListChanged();
      }

      setState(() {
        _lastResult = result;
      });
      showSuccessFeedback(context, result.summary);
    } on QuickCommandException catch (error) {
      if (!mounted) {
        return;
      }
      showErrorFeedback(
        context,
        error.message,
        title: context.tr(
          en: 'Command not understood',
          sk: 'Príkaz sa nepodarilo pochopiť',
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to process quick command.',
          sk: 'Príkaz sa nepodarilo spracovať.',
        ),
        title: context.tr(
          en: 'Quick command failed',
          sk: 'Rýchly príkaz zlyhal',
        ),
        actionLabel: context.tr(en: 'Retry', sk: 'Skúsiť znova'),
        onAction: _submit,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool?> _confirmPreview(QuickCommandPreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr(
              en: 'Confirm quick command',
              sk: 'Potvrdiť rýchly príkaz',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'The app understood this:',
                    sk: 'Aplikácia pochopila toto:',
                  ),
                ),
                const SizedBox(height: 12),
                ...preview.commands.expand((command) {
                  return [
                    Text(
                      _intentLabel(command.intent),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...command.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('• ${_itemPreviewLabel(item)}'),
                            ..._dietaryModifierLabels(item.name).map(
                              (label) => Chip(
                                label: Text(label),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ];
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr(en: 'Edit', sk: 'Upraviť')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr(en: 'Confirm', sk: 'Potvrdiť')),
            ),
          ],
        );
      },
    );
  }

  String _intentLabel(QuickCommandIntent intent) {
    return switch (intent) {
      QuickCommandIntent.addToPantry => context.tr(
        en: 'Add to pantry',
        sk: 'Pridať do špajze',
      ),
      QuickCommandIntent.addToShoppingList => context.tr(
        en: 'Add to shopping list',
        sk: 'Pridať do nákupného zoznamu',
      ),
      QuickCommandIntent.consumeFromPantry => context.tr(
        en: 'Use from pantry',
        sk: 'Minúť zo špajze',
      ),
      QuickCommandIntent.markOpened => context.tr(
        en: 'Mark as opened',
        sk: 'Označiť ako otvorené',
      ),
    };
  }

  String _itemPreviewLabel(QuickCommandItem item) {
    final storage = item.storageLocation == null
        ? ''
        : ' • ${_storageLabel(item.storageLocation!)}';
    final expiration = item.expirationDate == null
        ? ''
        : ' • ${context.tr(en: 'exp.', sk: 'exp.')} ${_formatDate(item.expirationDate!)}';
    return '${_formatQuantity(item.quantity)} ${item.unit} ${item.name}$storage$expiration';
  }

  List<String> _dietaryModifierLabels(String value) {
    final normalized = _normalizeValue(value);
    final labels = <String>[];
    if (normalized.contains('bezlepk') ||
        normalized.contains('glutenfree') ||
        normalized.contains('glutenfrei')) {
      labels.add(context.tr(en: 'gluten-free', sk: 'bez lepku'));
    }
    if (normalized.contains('bezlakt') || normalized.contains('lactosefree')) {
      labels.add(context.tr(en: 'lactose-free', sk: 'bez laktózy'));
    }
    if (normalized.contains('bezvajec') ||
        normalized.contains('nahradavajec')) {
      labels.add(context.tr(en: 'egg-free', sk: 'bez vajec'));
    }
    return labels;
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

  String _storageLabel(String storageLocation) {
    return switch (storageLocation) {
      'fridge' => context.tr(en: 'fridge', sk: 'chladnička'),
      'freezer' => context.tr(en: 'freezer', sk: 'mraznička'),
      _ => context.tr(en: 'pantry', sk: 'špajza'),
    };
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _fillExample(String value) {
    setState(() {
      _commandController.text = value;
    });
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
              title: context.tr(
                en: 'Quick kitchen command',
                sk: 'Rýchly kuchynský príkaz',
              ),
              subtitle: context.tr(
                en: 'Tell Safo what happened and it will update pantry or shopping for you.',
                sk: 'Povedz Safo, čo sa stalo, a ono podľa toho upraví špajzu alebo nákupný zoznam.',
              ),
              onBack: () => Navigator.of(context).maybePop(),
              badges: [
                _QuickCommandBadge(
                  icon: Icons.record_voice_over_outlined,
                  label: context.tr(
                    en: 'Natural language',
                    sk: 'Prirodzený jazyk',
                  ),
                ),
                _QuickCommandBadge(
                  icon: Icons.checklist_rtl_rounded,
                  label: context.tr(en: 'Preview first', sk: 'Najprv kontrola'),
                ),
              ],
            ),
          ),
          const SizedBox(height: SafoSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SafoSpacing.lg),
            decoration: BoxDecoration(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(SafoRadii.xl),
              border: Border.all(color: SafoColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Type what happened in the kitchen and the app will update pantry or shopping for you.',
                    sk: 'Napíš, čo sa stalo v kuchyni, a aplikácia podľa toho upraví špajzu alebo nákupný zoznam.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                TextField(
                  controller: _commandController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: appInputDecoration(
                    context.tr(
                      en: 'Example: pridaj 2 jogurty a mlieko',
                      sk: 'Príklad: pridaj 2 jogurty a mlieko',
                    ),
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt_rounded),
                    label: Text(
                      _isSubmitting
                          ? context.tr(
                              en: 'Processing...',
                              sk: 'Spracovávam...',
                            )
                          : context.tr(en: 'Run command', sk: 'Spustiť príkaz'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SafoSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SafoSpacing.lg),
            decoration: BoxDecoration(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(SafoRadii.xl),
              border: Border.all(color: SafoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    en: 'Try example commands',
                    sk: 'Skús vzorové príkazy',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SafoSpacing.xs),
                Text(
                  context.tr(
                    en: 'Great for testing pantry, shopping, and opened-item flows quickly.',
                    sk: 'Hodí sa na rýchle testovanie špajze, nákupu a otvorených položiek.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('pridaj 2 jogurty a mlieko'),
                      onPressed: () =>
                          _fillExample('pridaj 2 jogurty a mlieko'),
                    ),
                    ActionChip(
                      label: const Text('minuli sa vajcia'),
                      onPressed: () => _fillExample('minuli sa vajcia'),
                    ),
                    ActionChip(
                      label: const Text('otvoril som syr'),
                      onPressed: () => _fillExample('otvoril som syr'),
                    ),
                    ActionChip(
                      label: const Text('kup 2 litre mlieka'),
                      onPressed: () => _fillExample('kup 2 litre mlieka'),
                    ),
                    ActionChip(
                      label: const Text('pridaj mlieko 1 liter'),
                      onPressed: () => _fillExample('pridaj mlieko 1 liter'),
                    ),
                    ActionChip(
                      label: const Text('pridaj 2 jogurty do chladničky'),
                      onPressed: () =>
                          _fillExample('pridaj 2 jogurty do chladničky'),
                    ),
                    ActionChip(
                      label: const Text('pridaj hrášok do mrazničky'),
                      onPressed: () =>
                          _fillExample('pridaj hrášok do mrazničky'),
                    ),
                    ActionChip(
                      label: const Text(
                        'pridaj mlieko do chladničky; kup chlieb',
                      ),
                      onPressed: () => _fillExample(
                        'pridaj mlieko do chladničky; kup chlieb',
                      ),
                    ),
                    ActionChip(
                      label: const Text(
                        'pridaj mlieko do chladničky a kup chlieb',
                      ),
                      onPressed: () => _fillExample(
                        'pridaj mlieko do chladničky a kup chlieb',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SafoSpacing.lg),
          if (_lastResult != null)
            Container(
              padding: const EdgeInsets.all(SafoSpacing.lg),
              decoration: BoxDecoration(
                color: SafoColors.surface,
                borderRadius: BorderRadius.circular(SafoRadii.xl),
                border: Border.all(color: SafoColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(en: 'Last result', sk: 'Posledný výsledok'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.md),
                  Text(
                    _lastResult!.summary,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._lastResult!.details.map(
                    (detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $detail'),
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

class _QuickCommandBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickCommandBadge({required this.icon, required this.label});

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
