import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../domain/staple_food.dart';

class StapleFoodFormScreen extends StatefulWidget {
  final StapleFood? initialItem;
  final String householdId;

  const StapleFoodFormScreen({
    super.key,
    this.initialItem,
    required this.householdId,
  });

  bool get isEditing => initialItem != null;

  @override
  State<StapleFoodFormScreen> createState() => _StapleFoodFormScreenState();
}

class _StapleFoodFormScreenState extends State<StapleFoodFormScreen> {
  static const List<String> _categoryOptions = [
    'produce',
    'dairy',
    'meat',
    'grains',
    'canned',
    'frozen',
    'beverages',
    'other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  String _selectedCategory = 'other';

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item?.quantity.toString() ?? '1';
    _unitController.text = item?.unit ?? 'pcs';
    _selectedCategory = item?.category ?? 'other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final existing = widget.initialItem;
    final now = DateTime.now().toUtc();
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      Navigator.pop(context);
      return;
    }

    final item = StapleFood(
      id: existing?.id ?? '',
      householdId: existing?.householdId ?? widget.householdId,
      userId: existing?.userId ?? user.id,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unitController.text.trim(),
      category: _selectedCategory,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? context.tr(
                  en: 'Edit Staple Food',
                  sk: 'Upraviť základnú potravinu',
                )
              : context.tr(
                  en: 'Add Staple Food',
                  sk: 'Pridať základnú potravinu',
                ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: appInputDecoration(
                  context.tr(en: 'Name', sk: 'Názov'),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return context.tr(en: 'Enter a name', sk: 'Zadaj názov');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: appInputDecoration(
                  context.tr(en: 'Category', sk: 'Kategória'),
                ),
                items: _categoryOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_categoryLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: appInputDecoration(
                        context.tr(
                          en: 'Target quantity',
                          sk: 'Cieľové množstvo',
                        ),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return context.tr(
                            en: 'Enter quantity',
                            sk: 'Zadaj množstvo',
                          );
                        }
                        if (double.tryParse(value!.trim()) == null) {
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
                      controller: _unitController,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(
                    widget.isEditing
                        ? context.tr(en: 'Save changes', sk: 'Uložiť zmeny')
                        : context.tr(
                            en: 'Add staple',
                            sk: 'Pridať základnú potravinu',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'produce' => context.tr(en: 'Produce', sk: 'Ovocie a zelenina'),
      'dairy' => context.tr(en: 'Dairy', sk: 'Mliečne výrobky'),
      'meat' => context.tr(en: 'Meat', sk: 'Mäso'),
      'grains' => context.tr(en: 'Grains', sk: 'Obilniny'),
      'canned' => context.tr(en: 'Canned', sk: 'Konzervy'),
      'frozen' => context.tr(en: 'Frozen', sk: 'Mrazené'),
      'beverages' => context.tr(en: 'Beverages', sk: 'Nápoje'),
      _ => context.tr(en: 'Other', sk: 'Ostatné'),
    };
  }
}
