import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../domain/shopping_list_item.dart';

class ShoppingListFormScreen extends StatefulWidget {
  final ShoppingListItem? initialItem;
  final ShoppingListItem? prefillItem;
  final String householdId;

  const ShoppingListFormScreen({
    super.key,
    this.initialItem,
    this.prefillItem,
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
    final item = widget.initialItem ?? widget.prefillItem;
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
                      en: 'Edit shopping item',
                      sk: 'Upraviť nákupnú položku',
                    )
                  : context.tr(
                      en: 'Add shopping item',
                      sk: 'Pridať nákupnú položku',
                    ),
              subtitle: context.tr(
                en: 'Capture what you still need and keep shopping tasks ready for your household.',
                sk: 'Zaznač, čo ešte potrebuješ, a priprav nákupné úlohy pre domácnosť.',
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
                  const SizedBox(height: 24),
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
}
