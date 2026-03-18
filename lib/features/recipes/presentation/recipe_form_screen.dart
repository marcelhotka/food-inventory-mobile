import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/forms/app_input_decoration.dart';
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
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Recipe' : 'Add Recipe'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: appInputDecoration('Recipe name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a recipe name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: appInputDecoration('Description'),
              ),
              const SizedBox(height: 24),
              Text(
                'Ingredients',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                            decoration: appInputDecoration('Ingredient name'),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter ingredient name';
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
                                  decoration: appInputDecoration('Quantity'),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter quantity';
                                    }
                                    if (double.tryParse(value!.trim()) ==
                                        null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: ingredient.unitController,
                                  decoration: appInputDecoration('Unit'),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Enter a unit';
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
                              label: const Text('Remove'),
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
                  label: const Text('Add ingredient'),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.isEditing ? 'Save changes' : 'Save recipe',
                  ),
                ),
              ),
            ],
          ),
        ),
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
