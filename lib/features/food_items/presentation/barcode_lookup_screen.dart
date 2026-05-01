import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/forms/app_input_decoration.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_page_header.dart';
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
              title: context.tr(
                en: 'Scan or lookup code',
                sk: 'Naskenuj alebo vyhľadaj kód',
              ),
              subtitle: context.tr(
                en: 'Find product details quickly and open pantry form with prefilled values.',
                sk: 'Rýchlo nájdi detaily produktu a otvor formulár špajze s predvyplnenými hodnotami.',
              ),
              onBack: () => Navigator.of(context).maybePop(),
              badges: [
                _LookupBadge(
                  icon: Icons.bolt_rounded,
                  label: context.tr(en: 'Fast lookup', sk: 'Rýchle vyhľadanie'),
                ),
                _LookupBadge(
                  icon: Icons.inventory_2_outlined,
                  label: context.tr(
                    en: 'Prefilled pantry',
                    sk: 'Predvyplnená špajza',
                  ),
                ),
              ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: SafoColors.primarySoft,
                        borderRadius: BorderRadius.circular(SafoRadii.md),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: SafoColors.primary,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: SafoSpacing.lg),
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
                const SizedBox(height: SafoSpacing.md),
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
          const SizedBox(height: SafoSpacing.lg),
          Container(
            padding: const EdgeInsets.all(SafoSpacing.lg),
            decoration: BoxDecoration(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(SafoRadii.xl),
              border: Border.all(color: SafoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(en: 'Try a demo code', sk: 'Skús demo kód'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SafoSpacing.xs),
                Text(
                  context.tr(
                    en: 'Useful for testing how lookup opens pantry forms in Safo.',
                    sk: 'Hodí sa na testovanie, ako lookup v Safo otvorí formulár špajze.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _service.demoCodes
                      .map(
                        (code) => ActionChip(
                          label: Text(code),
                          onPressed: _isLookingUp
                              ? null
                              : () => _useDemoCode(code),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LookupBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SafoRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
