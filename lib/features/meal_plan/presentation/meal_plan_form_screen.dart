import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/forms/app_input_decoration.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../domain/meal_plan_entry.dart';

class MealPlanFormScreen extends StatefulWidget {
  final String householdId;
  final List<Recipe> recipes;
  final MealPlanEntry? initialEntry;
  final Recipe? prefilledRecipe;

  const MealPlanFormScreen({
    super.key,
    required this.householdId,
    required this.recipes,
    this.initialEntry,
    this.prefilledRecipe,
  });

  bool get isEditing => initialEntry != null;

  @override
  State<MealPlanFormScreen> createState() => _MealPlanFormScreenState();
}

class _MealPlanFormScreenState extends State<MealPlanFormScreen> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  final _formKey = GlobalKey<FormState>();
  final _recipeNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _servingsController = TextEditingController(text: '2');
  DateTime _scheduledFor = DateTime.now();
  String _mealType = 'dinner';
  String? _selectedRecipeId;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _scheduledFor = DateTime(
      (entry?.scheduledFor ?? DateTime.now()).year,
      (entry?.scheduledFor ?? DateTime.now()).month,
      (entry?.scheduledFor ?? DateTime.now()).day,
    );
    _mealType = entry?.mealType ?? 'dinner';
    _selectedRecipeId = entry?.recipeId ?? widget.prefilledRecipe?.id;
    _recipeNameController.text =
        entry?.recipeName ?? widget.prefilledRecipe?.name ?? '';
    _servingsController.text =
        (entry?.servings ?? widget.prefilledRecipe?.defaultServings ?? 2)
            .toString();
    _noteController.text = entry?.note ?? '';
  }

  @override
  void dispose() {
    _recipeNameController.dispose();
    _noteController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledFor,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _scheduledFor = DateTime(picked.year, picked.month, picked.day);
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

    final selectedRecipe = _findRecipeById(_selectedRecipeId);
    final now = DateTime.now().toUtc();
    final existing = widget.initialEntry;

    final entry = MealPlanEntry(
      id: existing?.id ?? '',
      householdId: existing?.householdId ?? widget.householdId,
      userId: existing?.userId ?? user.id,
      recipeId: selectedRecipe?.id,
      recipeName: _recipeNameController.text.trim(),
      servings: int.parse(_servingsController.text.trim()),
      scheduledFor: _scheduledFor,
      mealType: _mealType,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Meal Plan' : 'Add Meal Plan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _selectedRecipeId,
                decoration: appInputDecoration(
                  'Recipe (optional, includes your own recipes)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Custom meal'),
                  ),
                  ...widget.recipes.map(
                    (recipe) => DropdownMenuItem<String?>(
                      value: recipe.id,
                      child: Text(localizedRecipeName(context, recipe)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRecipeId = value;
                    final recipe = _findRecipeById(value);
                    if (recipe != null) {
                      _recipeNameController.text = localizedRecipeName(
                        context,
                        recipe,
                      );
                      _servingsController.text = recipe.defaultServings
                          .toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_selectedRecipeId == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tip: create your own recipe in Recipes and later link it here.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_selectedRecipeId == null) const SizedBox(height: 16),
              TextFormField(
                controller: _recipeNameController,
                decoration: appInputDecoration('Meal name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a meal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _servingsController,
                keyboardType: TextInputType.number,
                decoration: appInputDecoration('Servings'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Enter servings';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _mealType,
                decoration: appInputDecoration('Meal type'),
                items: _mealTypes
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_mealTypeLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _mealType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(18),
                child: InputDecorator(
                  decoration: appInputDecoration('Date'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(_scheduledFor)),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: appInputDecoration('Note (optional)'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.isEditing ? 'Save changes' : 'Add to meal plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Recipe? _findRecipeById(String? recipeId) {
    if (recipeId == null) {
      return null;
    }

    for (final recipe in widget.recipes) {
      if (recipe.id == recipeId) {
        return recipe;
      }
    }

    return null;
  }
}
