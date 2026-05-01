import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../domain/recipe.dart';
import '../domain/recipe_ingredient.dart';

class RecipeFormScreen extends StatefulWidget {
  final String householdId;
  final Recipe? initialRecipe;

  const RecipeFormScreen({
    super.key,
    required this.householdId,
    this.initialRecipe,
  });

  bool get isEditing => initialRecipe != null;

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalMinutesController = TextEditingController(text: '30');
  final _defaultServingsController = TextEditingController(text: '2');
  final List<_IngredientDraft> _ingredients = [_IngredientDraft()];

  @override
  void initState() {
    super.initState();
    final recipe = widget.initialRecipe;
    if (recipe == null) {
      return;
    }

    _nameController.text = recipe.name;
    _descriptionController.text = recipe.description;
    _totalMinutesController.text = recipe.totalMinutes.toString();
    _defaultServingsController.text = recipe.defaultServings.toString();
    _ingredients.clear();
    for (final ingredient in recipe.ingredients) {
      _ingredients.add(
        _IngredientDraft(
          name: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _totalMinutesController.dispose();
    _defaultServingsController.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngredientDraft());
    });
  }

  void _removeIngredient(int index) {
    if (_ingredients.length == 1) {
      return;
    }

    setState(() {
      final ingredient = _ingredients.removeAt(index);
      ingredient.dispose();
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      Navigator.pop(context);
      return;
    }

    final now = DateTime.now().toUtc();
    final recipe = Recipe(
      id: widget.initialRecipe?.id ?? '',
      householdId: widget.initialRecipe?.householdId ?? widget.householdId,
      createdByUserId: widget.initialRecipe?.createdByUserId ?? user.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      totalMinutes: int.parse(_totalMinutesController.text.trim()),
      defaultServings: int.parse(_defaultServingsController.text.trim()),
      isPublic: widget.initialRecipe?.isPublic ?? false,
      isFavorite: widget.initialRecipe?.isFavorite ?? false,
      createdAt: widget.initialRecipe?.createdAt ?? now,
      updatedAt: now,
      ingredients: [
        for (int i = 0; i < _ingredients.length; i++)
          RecipeIngredient(
            id: '',
            name: _ingredients[i].nameController.text.trim(),
            quantity: double.parse(
              _ingredients[i].quantityController.text.trim(),
            ),
            unit: _ingredients[i].unitController.text.trim(),
            sortOrder: i,
          ),
      ],
    );

    Navigator.pop(context, recipe);
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
              title: widget.isEditing
                  ? context.tr(en: 'Edit recipe', sk: 'Upraviť recept')
                  : context.tr(en: 'Create recipe', sk: 'Vytvoriť recept'),
              subtitle: context.tr(
                en: 'Build a reusable recipe with time, servings, and ingredients for Safo planning.',
                sk: 'Vytvor znovupoužiteľný recept s časom, porciami a ingredienciami pre plánovanie v Safo.',
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: appInputDecoration(
                      context.tr(en: 'Recipe name', sk: 'Názov receptu'),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return context.tr(
                          en: 'Enter a recipe name',
                          sk: 'Zadaj názov receptu',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: appInputDecoration(
                      context.tr(en: 'Description', sk: 'Popis'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _totalMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: appInputDecoration(
                            context.tr(en: 'Total minutes', sk: 'Celkový čas'),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed <= 0) {
                              return context.tr(
                                en: 'Enter valid minutes',
                                sk: 'Zadaj platný počet minút',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _defaultServingsController,
                          keyboardType: TextInputType.number,
                          decoration: appInputDecoration(
                            context.tr(en: 'Servings', sk: 'Porcie'),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed <= 0) {
                              return context.tr(
                                en: 'Enter servings',
                                sk: 'Zadaj počet porcií',
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr(en: 'Ingredients', sk: 'Ingrediencie'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_ingredients.length, (index) {
                    final ingredient = _ingredients[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: ingredient.nameController,
                                decoration: appInputDecoration(
                                  context.tr(
                                    en: 'Ingredient name',
                                    sk: 'Názov ingrediencie',
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return context.tr(
                                      en: 'Enter ingredient name',
                                      sk: 'Zadaj názov ingrediencie',
                                    );
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: ingredient.quantityController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: appInputDecoration(
                                        context.tr(
                                          en: 'Quantity',
                                          sk: 'Množstvo',
                                        ),
                                      ),
                                      validator: (value) {
                                        if ((value ?? '').trim().isEmpty) {
                                          return context.tr(
                                            en: 'Enter quantity',
                                            sk: 'Zadaj množstvo',
                                          );
                                        }
                                        if (double.tryParse(value!.trim()) ==
                                            null) {
                                          return context.tr(
                                            en: 'Enter a valid number',
                                            sk: 'Zadaj platné číslo',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: ingredient.unitController,
                                      decoration: appInputDecoration(
                                        context.tr(en: 'Unit', sk: 'Jednotka'),
                                      ),
                                      validator: (value) {
                                        if ((value ?? '').trim().isEmpty) {
                                          return context.tr(
                                            en: 'Enter a unit',
                                            sk: 'Zadaj jednotku',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _removeIngredient(index),
                                  icon: const Icon(Icons.delete_outline),
                                  label: Text(
                                    context.tr(en: 'Remove', sk: 'Odstrániť'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _addIngredient,
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.tr(
                          en: 'Add ingredient',
                          sk: 'Pridať ingredienciu',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(
                        widget.isEditing
                            ? context.tr(en: 'Save changes', sk: 'Uložiť zmeny')
                            : context.tr(
                                en: 'Save recipe',
                                sk: 'Uložiť recept',
                              ),
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

class _IngredientDraft {
  final nameController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final unitController = TextEditingController(text: 'pcs');

  _IngredientDraft({String? name, double? quantity, String? unit}) {
    nameController.text = name ?? '';
    quantityController.text = (quantity ?? 1).toString();
    unitController.text = unit ?? 'pcs';
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }
}
