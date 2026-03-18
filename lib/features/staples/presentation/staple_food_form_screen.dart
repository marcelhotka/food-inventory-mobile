import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        title: Text(widget.isEditing ? 'Edit Staple Food' : 'Add Staple Food'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: appInputDecoration('Name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: appInputDecoration('Category'),
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
                      decoration: appInputDecoration('Target quantity'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter quantity';
                        }
                        if (double.tryParse(value!.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.isEditing ? 'Save changes' : 'Add staple'),
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
      'produce' => 'Produce',
      'dairy' => 'Dairy',
      'meat' => 'Meat',
      'grains' => 'Grains',
      'canned' => 'Canned',
      'frozen' => 'Frozen',
      'beverages' => 'Beverages',
      _ => 'Other',
    };
  }
}
