import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_page_header.dart';
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
  DateTime? _openedAt;
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
    _openedAt = item?.openedAt;
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
      openedAt: _openedAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, item);
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
                  ? context.tr(
                      en: 'Edit pantry item',
                      sk: 'Upraviť položku špajze',
                    )
                  : context.tr(
                      en: 'Add pantry item',
                      sk: 'Pridať položku do špajze',
                    ),
              subtitle: context.tr(
                en: 'Adjust quantity, category, storage, and expiry before saving to Safo.',
                sk: 'Pred uložením do Safo uprav množstvo, kategóriu, uloženie a spotrebu.',
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
                      context.tr(en: 'Name', sk: 'Názov'),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return context.tr(
                          en: 'Enter a name',
                          sk: 'Zadaj názov',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: appInputDecoration(
                      context.tr(en: 'Barcode', sk: 'Čiarový kód'),
                    ),
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
                            child: Text(_categoryLabel(context, value)),
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
                    decoration: appInputDecoration(
                      context.tr(en: 'Storage location', sk: 'Umiestnenie'),
                    ),
                    items: _storageOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_storageLabel(context, value)),
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
                          decoration: appInputDecoration(
                            context.tr(en: 'Quantity', sk: 'Množstvo'),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lowStockThresholdController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: appInputDecoration(
                      context.tr(
                        en: 'Low stock threshold (optional)',
                        sk: 'Limit nízkej zásoby (voliteľné)',
                      ),
                    ),
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return null;
                      }
                      if (double.tryParse(trimmed) == null) {
                        return context.tr(
                          en: 'Enter a valid number',
                          sk: 'Zadaj platné číslo',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickExpirationDate,
                    child: InputDecorator(
                      decoration: appInputDecoration(
                        context.tr(en: 'Expiration date', sk: 'Dátum spotreby'),
                      ),
                      child: Text(
                        _expirationDate == null
                            ? context.tr(en: 'Optional', sk: 'Voliteľné')
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
                      child: Text(
                        context.tr(en: 'Clear date', sk: 'Vymazať dátum'),
                      ),
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
                      child: Text(
                        context.tr(
                          en: 'Product details were prefilled from barcode lookup. You can still edit them before saving.',
                          sk: 'Detaily produktu boli predvyplnené podľa čiarového kódu. Pred uložením ich ešte môžeš upraviť.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(
                        widget.isEditing
                            ? context.tr(en: 'Save changes', sk: 'Uložiť zmeny')
                            : context.tr(en: 'Add item', sk: 'Pridať položku'),
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  String _categoryLabel(BuildContext context, String value) {
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

  String _storageLabel(BuildContext context, String value) {
    return switch (value) {
      'fridge' => context.tr(en: 'Fridge', sk: 'Chladnička'),
      'freezer' => context.tr(en: 'Freezer', sk: 'Mraznička'),
      _ => context.tr(en: 'Pantry', sk: 'Špajza'),
    };
  }
}
