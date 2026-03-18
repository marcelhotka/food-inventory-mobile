import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/forms/app_input_decoration.dart';
import '../../recipes/domain/recipe.dart';
import '../domain/meal_plan_entry.dart';

class MealPlanImportScreen extends StatefulWidget {
  final String householdId;
  final List<Recipe> recipes;

  const MealPlanImportScreen({
    super.key,
    required this.householdId,
    required this.recipes,
  });

  @override
  State<MealPlanImportScreen> createState() => _MealPlanImportScreenState();
}

class _MealPlanImportScreenState extends State<MealPlanImportScreen> {
  final TextEditingController _controller = TextEditingController();
  List<_ParsedMealLine> _parsedLines = const [];
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _parsedLines = const [];
        _errorText = 'Paste your meal plan text first.';
      });
      return;
    }

    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsed = <_ParsedMealLine>[];
    for (final line in lines) {
      parsed.add(_parseLine(line));
    }

    setState(() {
      _parsedLines = parsed;
      _errorText = parsed.any((line) => line.entry == null)
          ? 'Some lines need adjustment. Use formats shown below.'
          : null;
    });
  }

  void _import() {
    final validEntries = _parsedLines
        .where((line) => line.entry != null)
        .map((line) => line.entry!)
        .toList();

    if (validEntries.isEmpty) {
      setState(() {
        _errorText = 'No valid meal plan entries to import.';
      });
      return;
    }

    Navigator.pop(context, validEntries);
  }

  _ParsedMealLine _parseLine(String line) {
    final split = line.contains('|')
        ? line.split('|').map((part) => part.trim()).toList()
        : line.split(RegExp(r'\s{2,}')).map((part) => part.trim()).toList();

    if (split.length < 3) {
      return _ParsedMealLine(
        source: line,
        error: 'Use format: date | meal type | meal name',
      );
    }

    final parsedDate = _parseDate(split[0]);
    if (parsedDate == null) {
      return _ParsedMealLine(source: line, error: 'Could not read date.');
    }

    final mealType = _normalizeMealType(split[1]);
    if (mealType == null) {
      return _ParsedMealLine(
        source: line,
        error: 'Meal type should be breakfast, lunch, dinner, or snack.',
      );
    }

    final mealName = split.sublist(2).join(' | ').trim();
    if (mealName.isEmpty) {
      return _ParsedMealLine(source: line, error: 'Meal name is missing.');
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _ParsedMealLine(source: line, error: 'No signed-in user.');
    }

    final matchedRecipe = _findMatchingRecipe(mealName);
    final now = DateTime.now().toUtc();

    return _ParsedMealLine(
      source: line,
      entry: MealPlanEntry(
        id: '',
        householdId: widget.householdId,
        userId: user.id,
        recipeId: matchedRecipe?.id,
        recipeName: matchedRecipe?.name ?? mealName,
        scheduledFor: parsedDate,
        mealType: mealType,
        note: matchedRecipe == null ? 'Imported from pasted meal plan' : null,
        createdAt: now,
        updatedAt: now,
      ),
      matchedRecipeName: matchedRecipe?.name,
    );
  }

  DateTime? _parseDate(String input) {
    final trimmed = input.trim();
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final eu = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(trimmed);
    if (eu != null) {
      return DateTime(
        int.parse(eu.group(3)!),
        int.parse(eu.group(2)!),
        int.parse(eu.group(1)!),
      );
    }

    return null;
  }

  String? _normalizeMealType(String input) {
    final value = input.trim().toLowerCase();
    return switch (value) {
      'breakfast' || 'ranajky' || 'raňajky' => 'breakfast',
      'lunch' || 'obed' => 'lunch',
      'dinner' || 'vecera' || 'večera' => 'dinner',
      'snack' || 'olovrant' || 'desiata' => 'snack',
      _ => null,
    };
  }

  Recipe? _findMatchingRecipe(String mealName) {
    final normalizedMeal = _normalize(mealName);
    for (final recipe in widget.recipes) {
      if (_normalize(recipe.name) == normalizedMeal) {
        return recipe;
      }
    }
    return null;
  }

  String _normalize(String value) {
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

  String _mealTypeLabel(String value) {
    return switch (value) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'dinner' => 'Dinner',
      'snack' => 'Snack',
      _ => 'Meal',
    };
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Meal Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Paste one meal per line.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text('Supported formats:'),
          const SizedBox(height: 6),
          const Text('• 2026-03-20 | dinner | Cheese Omelette'),
          const Text('• 20.03.2026 | lunch | Chicken Rice Bowl'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: appInputDecoration('Meal plan text'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _parse, child: const Text('Review import')),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_parsedLines.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Preview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._parsedLines.map((line) {
              final entry = line.entry;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE6DDCF)),
                ),
                child: entry == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.source,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            line.error ?? 'Invalid line',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.recipeName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(entry.scheduledFor)} • ${_mealTypeLabel(entry.mealType)}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.matchedRecipeName == null
                                ? 'No matching recipe linked yet'
                                : 'Linked to recipe: ${line.matchedRecipeName}',
                          ),
                        ],
                      ),
              );
            }),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _import,
              child: const Text('Import valid meals'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParsedMealLine {
  final String source;
  final MealPlanEntry? entry;
  final String? matchedRecipeName;
  final String? error;

  const _ParsedMealLine({
    required this.source,
    this.entry,
    this.matchedRecipeName,
    this.error,
  });
}
