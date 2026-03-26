import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
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
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
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
      showErrorFeedback(context, error.message);
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
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _fillExample(String value) {
    setState(() {
      _commandController.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Quick command', sk: 'Rýchly príkaz')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr(
              en: 'Type what happened in the kitchen and the app will update pantry or shopping for you.',
              sk: 'Napíš, čo sa stalo v kuchyni, a aplikácia podľa toho upraví špajzu alebo nákupný zoznam.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('pridaj 2 jogurty a mlieko'),
                onPressed: () => _fillExample('pridaj 2 jogurty a mlieko'),
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
            ],
          ),
          const SizedBox(height: 24),
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
                    ? context.tr(en: 'Processing...', sk: 'Spracovávam...')
                    : context.tr(en: 'Run command', sk: 'Spustiť príkaz'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_lastResult != null) ...[
            Text(
              context.tr(en: 'Last result', sk: 'Posledný výsledok'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
            ),
          ],
        ],
      ),
    );
  }
}
