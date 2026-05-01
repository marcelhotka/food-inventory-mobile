import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../domain/staple_food.dart';
import '../domain/staple_food_presets.dart';

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
  static const List<String> _unitOptions = [
    'pcs',
    'g',
    'kg',
    'ml',
    'l',
    'custom',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  String _selectedCategory = 'other';
  String _selectedUnit = 'pcs';
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController.text = item?.name ?? '';
    _quantityController.text = item?.quantity.toString() ?? '1';
    _unitController.text = item?.unit ?? 'pcs';
    _selectedCategory = item?.category ?? 'other';
    _selectedUnit = _unitOptions.contains(_unitController.text.trim())
        ? _unitController.text.trim()
        : 'custom';
  }

  void _applyPreset(StapleFoodPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      _nameController.text = context.tr(en: preset.nameEn, sk: preset.nameSk);
      _quantityController.text = _formatQuantity(preset.quantity);
      _unitController.text = preset.unit;
      _selectedCategory = preset.category;
      _selectedUnit = preset.unit;
    });
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
                      en: 'Edit staple food',
                      sk: 'Upraviť základnú potravinu',
                    )
                  : context.tr(
                      en: 'Add staple food',
                      sk: 'Pridať základnú potravinu',
                    ),
              subtitle: context.tr(
                en: 'Define what should stay regularly stocked at home and in what quantity.',
                sk: 'Nastav, čo má byť doma pravidelne dostupné a v akom množstve.',
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
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr(
                        en: 'Popular staples',
                        sk: 'Obľúbené základné potraviny',
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr(
                        en: 'Tap one to prefill the form faster.',
                        sk: 'Ťukni na niektorú a formulár sa rýchlo predvyplní.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stapleFoodPresets.map((preset) {
                      final isSelected = _selectedPresetId == preset.id;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          context.tr(en: preset.nameEn, sk: preset.nameSk),
                        ),
                        onSelected: (_) => _applyPreset(preset),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
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
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: appInputDecoration(
                            context.tr(en: 'Unit', sk: 'Jednotka'),
                          ),
                          items: _unitOptions
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_unitLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedUnit = value;
                              if (value != 'custom') {
                                _unitController.text = value;
                              } else if (_unitController.text.trim().isEmpty) {
                                _unitController.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedUnit == 'custom') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unitController,
                      decoration: appInputDecoration(
                        context.tr(en: 'Custom unit', sk: 'Vlastná jednotka'),
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
                  ],
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
        ],
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

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _unitLabel(String value) {
    return switch (value) {
      'pcs' => context.tr(en: 'Pieces', sk: 'Kusy'),
      'g' => context.tr(en: 'Grams', sk: 'Gramy'),
      'kg' => context.tr(en: 'Kilograms', sk: 'Kilogramy'),
      'ml' => context.tr(en: 'Milliliters', sk: 'Mililitre'),
      'l' => context.tr(en: 'Liters', sk: 'Litre'),
      'custom' => context.tr(en: 'Custom', sk: 'Vlastná'),
      _ => value,
    };
  }
}
