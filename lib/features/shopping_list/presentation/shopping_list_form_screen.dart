import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/forms/app_input_decoration.dart';
import '../domain/shopping_list_item.dart';

class ShoppingListFormScreen extends StatefulWidget {
  final ShoppingListItem? initialItem;
  final String householdId;

  const ShoppingListFormScreen({
    super.key,
    this.initialItem,
    required this.householdId,
  });

  bool get isEditing => initialItem != null;

  @override
  State<ShoppingListFormScreen> createState() => _ShoppingListFormScreenState();
}

class _ShoppingListFormScreenState extends State<ShoppingListFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item?.quantity.toString() ?? '1';
    _unitController.text = item?.unit ?? 'pcs';
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

    final item = ShoppingListItem(
      id: existing?.id ?? '',
      userId: existing?.userId ?? user.id,
      householdId: existing?.householdId ?? widget.householdId,
      name: _nameController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unitController.text.trim(),
      source: existing?.source ?? ShoppingListItem.sourceManual,
      isBought: existing?.isBought ?? false,
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
          widget.isEditing ? 'Edit Shopping Item' : 'Add Shopping Item',
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
                decoration: appInputDecoration('Name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
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
                      decoration: appInputDecoration('Quantity'),
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
                  child: Text(widget.isEditing ? 'Save changes' : 'Add item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
