import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/forms/app_input_decoration.dart';
import '../domain/food_item.dart';
import '../domain/food_item_prefill.dart';

class FoodItemFormScreen extends StatefulWidget {
  final FoodItem? initialItem;
  final FoodItemPrefill? prefill;
  final String householdId;

  const FoodItemFormScreen({
    super.key,
    this.initialItem,
    this.prefill,
    required this.householdId,
  });

  bool get isEditing => initialItem != null;

  @override
  State<FoodItemFormScreen> createState() => _FoodItemFormScreenState();
}

class _FoodItemFormScreenState extends State<FoodItemFormScreen> {
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

  static const List<String> _storageOptions = ['fridge', 'freezer', 'pantry'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _unitController = TextEditingController();

  DateTime? _expirationDate;
  String _selectedCategory = 'other';
  String _selectedStorageLocation = 'pantry';

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    final prefill = widget.prefill;
    _nameController.text = item?.name ?? prefill?.name ?? '';
    _barcodeController.text = item?.barcode ?? prefill?.barcode ?? '';
    _quantityController.text =
        item?.quantity.toString() ?? prefill?.quantity.toString() ?? '1';
    _lowStockThresholdController.text =
        item?.lowStockThreshold?.toString() ??
        prefill?.lowStockThreshold?.toString() ??
        '';
    _unitController.text = item?.unit ?? prefill?.unit ?? 'pcs';
    _expirationDate = item?.expirationDate ?? prefill?.expirationDate;
    _selectedCategory = item?.category ?? prefill?.category ?? 'other';
    _selectedStorageLocation =
        item?.storageLocation ?? prefill?.storageLocation ?? 'pantry';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _quantityController.dispose();
    _lowStockThresholdController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() {
        _expirationDate = picked;
      });
    }
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

    final quantity = double.parse(_quantityController.text.trim());
    final lowStockThreshold = _lowStockThresholdController.text.trim().isEmpty
        ? null
        : double.tryParse(_lowStockThresholdController.text.trim());
    final item = FoodItem(
      id: existing?.id ?? '',
      userId: existing?.userId ?? user.id,
      householdId: existing?.householdId ?? widget.householdId,
      name: _nameController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      category: _selectedCategory,
      storageLocation: _selectedStorageLocation,
      quantity: quantity,
      lowStockThreshold: lowStockThreshold,
      unit: _unitController.text.trim(),
      expirationDate: _expirationDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Pantry Item' : 'Add Pantry Item'),
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
                decoration: appInputDecoration('Name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                decoration: appInputDecoration('Barcode'),
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
              DropdownButtonFormField<String>(
                initialValue: _selectedStorageLocation,
                decoration: appInputDecoration('Storage location'),
                items: _storageOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_storageLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedStorageLocation = value;
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _lowStockThresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: appInputDecoration(
                  'Low stock threshold (optional)',
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  if (double.tryParse(trimmed) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickExpirationDate,
                child: InputDecorator(
                  decoration: appInputDecoration('Expiration date'),
                  child: Text(
                    _expirationDate == null
                        ? 'Optional'
                        : _formatDate(_expirationDate!),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_expirationDate != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expirationDate = null;
                    });
                  },
                  child: const Text('Clear date'),
                ),
              const SizedBox(height: 24),
              if (!widget.isEditing && widget.prefill != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5EA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Product details were prefilled from barcode lookup. You can still edit them before saving.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
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

  String _storageLabel(String value) {
    return switch (value) {
      'fridge' => 'Fridge',
      'freezer' => 'Freezer',
      _ => 'Pantry',
    };
  }
}
