import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/barcode_lookup_service.dart';
import '../domain/barcode_lookup_result.dart';
import '../domain/food_item_prefill.dart';

class BarcodeLookupScreen extends StatefulWidget {
  const BarcodeLookupScreen({super.key});

  @override
  State<BarcodeLookupScreen> createState() => _BarcodeLookupScreenState();
}

class _BarcodeLookupScreenState extends State<BarcodeLookupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final BarcodeLookupService _service = const BarcodeLookupService();

  bool _isLookingUp = false;

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final barcode = _barcodeController.text.trim();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLookingUp = true;
    });

    final result = await _service.lookup(barcode);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLookingUp = false;
    });

    if (result == null) {
      final fallback = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.tr(en: 'Product not found', sk: 'Produkt sa nenašiel'),
          ),
          content: Text(
            context.tr(
              en: 'We could not find barcode "$barcode". Do you want to continue with a basic prefilled item and edit it manually?',
              sk: 'Čiarový kód „$barcode“ sa nepodarilo nájsť. Chceš pokračovať so základne predvyplnenou položkou a upraviť ju ručne?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr(en: 'Use anyway', sk: 'Použiť aj tak')),
            ),
          ],
        ),
      );

      if (fallback == true && mounted) {
        Navigator.of(context).pop(
          FoodItemPrefill(
            name: context.tr(en: 'Scanned product', sk: 'Naskenovaný produkt'),
            barcode: barcode,
            quantity: 1,
            unit: 'pcs',
          ),
        );
      }
      return;
    }

    switch (result.source) {
      case BarcodeLookupSource.cache:
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Loaded instantly from recent lookup.',
            sk: 'Načítané okamžite z nedávneho vyhľadávania.',
          ),
        );
      case BarcodeLookupSource.online:
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Product found online.',
            sk: 'Produkt bol nájdený online.',
          ),
        );
      case BarcodeLookupSource.demo:
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Using local demo product.',
            sk: 'Používam lokálny demo produkt.',
          ),
        );
    }

    Navigator.of(context).pop(result.prefill);
  }

  void _useDemoCode(String code) {
    _barcodeController.text = code;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Scan code', sk: 'Skenovať kód')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DDCF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F0DF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF4E7A51),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr(
                          en: 'Barcode lookup',
                          sk: 'Vyhľadanie čiarového kódu',
                        ),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    en: 'We first try an online product lookup. If nothing is found, we fall back to the local demo products. After lookup, the pantry form opens prefilled.',
                    sk: 'Najprv skúšame online vyhľadanie produktu. Ak sa nič nenájde, použijeme lokálne demo produkty. Po vyhľadaní sa otvorí formulár špajze s predvyplnenými údajmi.',
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: appInputDecoration(
                      context.tr(en: 'Barcode', sk: 'Čiarový kód'),
                    ),
                    validator: (value) {
                      final barcode = value?.trim() ?? '';
                      if (barcode.isEmpty) {
                        return context.tr(
                          en: 'Enter a barcode',
                          sk: 'Zadaj čiarový kód',
                        );
                      }
                      if (barcode.length < 8) {
                        return context.tr(
                          en: 'Enter a valid barcode',
                          sk: 'Zadaj platný čiarový kód',
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isLookingUp ? null : _submit,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(
                      _isLookingUp
                          ? context.tr(en: 'Looking up...', sk: 'Vyhľadávam...')
                          : context.tr(
                              en: 'Lookup barcode',
                              sk: 'Vyhľadať kód',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr(en: 'Try a demo code', sk: 'Skús demo kód'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _service.demoCodes
                .map(
                  (code) => ActionChip(
                    label: Text(code),
                    onPressed: _isLookingUp ? null : () => _useDemoCode(code),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
