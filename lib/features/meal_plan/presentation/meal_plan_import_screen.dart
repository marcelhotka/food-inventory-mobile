import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_display_text.dart';
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
        _errorText = context.tr(
          en: 'Paste your meal plan text first.',
          sk: 'Najprv vlož text jedálnička.',
        );
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
          ? context.tr(
              en: 'Some lines need adjustment. Use formats shown below.',
              sk: 'Niektoré riadky treba upraviť. Použi formáty nižšie.',
            )
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
        _errorText = context.tr(
          en: 'No valid meal plan entries to import.',
          sk: 'Na import nie sú žiadne platné položky jedálnička.',
        );
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
        error: context.tr(
          en: 'Use format: date | meal type | meal name',
          sk: 'Použi formát: dátum | typ jedla | názov jedla',
        ),
      );
    }

    final parsedDate = _parseDate(split[0]);
    if (parsedDate == null) {
      return _ParsedMealLine(
        source: line,
        error: context.tr(
          en: 'Could not read date.',
          sk: 'Nepodarilo sa prečítať dátum.',
        ),
      );
    }

    final mealType = _normalizeMealType(split[1]);
    if (mealType == null) {
      return _ParsedMealLine(
        source: line,
        error: context.tr(
          en: 'Meal type should be breakfast, lunch, dinner, or snack.',
          sk: 'Typ jedla má byť raňajky, obed, večera alebo desiata.',
        ),
      );
    }

    final mealName = split.sublist(2).join(' | ').trim();
    if (mealName.isEmpty) {
      return _ParsedMealLine(
        source: line,
        error: context.tr(
          en: 'Meal name is missing.',
          sk: 'Chýba názov jedla.',
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return _ParsedMealLine(
        source: line,
        error: context.tr(
          en: 'No signed-in user.',
          sk: 'Nie je prihlásený žiadny používateľ.',
        ),
      );
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
        servings: matchedRecipe?.defaultServings ?? 2,
        scheduledFor: parsedDate,
        mealType: mealType,
        note: matchedRecipe == null
            ? context.tr(
                en: 'Imported from pasted meal plan',
                sk: 'Importované z vloženého jedálnička',
              )
            : null,
        createdAt: now,
        updatedAt: now,
      ),
      matchedRecipe: matchedRecipe,
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

  String _mealTypeLabel(BuildContext context, String value) {
    return switch (value) {
      'breakfast' => context.tr(en: 'Breakfast', sk: 'Raňajky'),
      'lunch' => context.tr(en: 'Lunch', sk: 'Obed'),
      'dinner' => context.tr(en: 'Dinner', sk: 'Večera'),
      'snack' => context.tr(en: 'Snack', sk: 'Desiata'),
      _ => context.tr(en: 'Meal', sk: 'Jedlo'),
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
                en: 'Import meal plan',
                sk: 'Import jedálnička',
              ),
              subtitle: context.tr(
                en: 'Paste your meal plan text and let Safo turn it into structured entries.',
                sk: 'Vlož text jedálnička a nechaj Safo premeniť ho na štruktúrované položky.',
              ),
              onBack: () => Navigator.of(context).maybePop(),
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
                    en: 'Paste one meal per line.',
                    sk: 'Vlož jedno jedlo na každý riadok.',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SafoSpacing.xs),
                Text(
                  context.tr(
                    en: 'Supported formats:',
                    sk: 'Podporované formáty:',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('• 2026-03-20 | dinner | Cheese Omelette'),
                const Text('• 20.03.2026 | lunch | Chicken Rice Bowl'),
                const SizedBox(height: SafoSpacing.md),
                TextField(
                  controller: _controller,
                  maxLines: 8,
                  decoration: appInputDecoration(
                    context.tr(en: 'Meal plan text', sk: 'Text jedálnička'),
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                FilledButton(
                  onPressed: _parse,
                  child: Text(
                    context.tr(en: 'Review import', sk: 'Skontrolovať import'),
                  ),
                ),
              ],
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: SafoSpacing.sm),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_parsedLines.isNotEmpty) ...[
            const SizedBox(height: SafoSpacing.lg),
            Text(
              context.tr(en: 'Preview', sk: 'Náhľad'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ..._parsedLines.map((line) {
              final entry = line.entry;
              return Container(
                margin: const EdgeInsets.only(bottom: SafoSpacing.sm),
                padding: const EdgeInsets.all(SafoSpacing.md),
                decoration: BoxDecoration(
                  color: SafoColors.surface,
                  borderRadius: BorderRadius.circular(SafoRadii.lg),
                  border: Border.all(color: SafoColors.border),
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
                            line.error ??
                                context.tr(
                                  en: 'Invalid line',
                                  sk: 'Neplatný riadok',
                                ),
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
                            line.matchedRecipe == null
                                ? entry.recipeName
                                : localizedRecipeName(
                                    context,
                                    line.matchedRecipe!,
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDate(entry.scheduledFor)} • ${_mealTypeLabel(context, entry.mealType)} • ${entry.servings} ${context.tr(en: entry.servings == 1 ? 'serving' : 'servings', sk: entry.servings == 1 ? 'porcia' : 'porcie')}',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            line.matchedRecipe == null
                                ? context.tr(
                                    en: 'No matching recipe linked yet',
                                    sk: 'Zatiaľ nie je prepojený žiadny zodpovedajúci recept',
                                  )
                                : '${context.tr(en: 'Linked to recipe:', sk: 'Prepojené s receptom:')} ${localizedRecipeName(context, line.matchedRecipe!)}',
                          ),
                        ],
                      ),
              );
            }),
            const SizedBox(height: SafoSpacing.xs),
            FilledButton.tonal(
              onPressed: _import,
              child: Text(
                context.tr(
                  en: 'Import valid meals',
                  sk: 'Importovať platné jedlá',
                ),
              ),
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
  final Recipe? matchedRecipe;
  final String? error;

  const _ParsedMealLine({
    required this.source,
    this.entry,
    this.matchedRecipe,
    this.error,
  });
}
