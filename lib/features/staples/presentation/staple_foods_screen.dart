import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../data/staple_food_repository.dart';
import '../domain/staple_food.dart';
import '../domain/staple_food_presets.dart';
import 'staple_food_form_screen.dart';

class StapleFoodsScreen extends StatefulWidget {
  final String householdId;
  final VoidCallback? onShoppingListChanged;

  const StapleFoodsScreen({
    super.key,
    required this.householdId,
    this.onShoppingListChanged,
  });

  @override
  State<StapleFoodsScreen> createState() => _StapleFoodsScreenState();
}

class _StapleFoodsScreenState extends State<StapleFoodsScreen> {
  late final StapleFoodRepository _stapleRepository = StapleFoodRepository(
    householdId: widget.householdId,
  );
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.householdId,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.householdId);

  late Future<List<StapleFood>> _staplesFuture = _stapleRepository
      .getStapleFoods();

  Future<void> _reload() async {
    setState(() {
      _staplesFuture = _stapleRepository.getStapleFoods();
    });
    await _staplesFuture;
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<StapleFood>(
      MaterialPageRoute(
        builder: (_) => StapleFoodFormScreen(householdId: widget.householdId),
      ),
    );

    if (created == null) {
      return;
    }

    try {
      await _stapleRepository.addStapleFood(created);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Staple food added.',
          sk: 'Základná potravina bola pridaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add staple food.',
          sk: 'Základnú potravinu sa nepodarilo pridať.',
        ),
      );
    }
  }

  Future<void> _addPresetStaple(
    StapleFoodPreset preset,
    List<StapleFood> existingItems,
  ) async {
    final key = _itemKey(
      context.tr(en: preset.nameEn, sk: preset.nameSk),
      preset.unit,
    );
    final alreadyExists = existingItems.any(
      (item) => _itemKey(item.name, item.unit) == key,
    );

    if (alreadyExists) {
      showSuccessFeedback(
        context,
        context.tr(
          en: 'This staple food is already in your list.',
          sk: 'Táto základná potravina už v zozname je.',
        ),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'No signed-in user.',
          sk: 'Nie je prihlásený žiadny používateľ.',
        ),
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final created = StapleFood(
      id: '',
      householdId: widget.householdId,
      userId: user.id,
      name: context.tr(en: preset.nameEn, sk: preset.nameSk),
      quantity: preset.quantity,
      unit: preset.unit,
      category: preset.category,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _stapleRepository.addStapleFood(created);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Staple food added.',
          sk: 'Základná potravina bola pridaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add staple food.',
          sk: 'Základnú potravinu sa nepodarilo pridať.',
        ),
      );
    }
  }

  Future<void> _openEditForm(StapleFood item) async {
    final updated = await Navigator.of(context).push<StapleFood>(
      MaterialPageRoute(
        builder: (_) => StapleFoodFormScreen(
          householdId: widget.householdId,
          initialItem: item,
        ),
      ),
    );

    if (updated == null) {
      return;
    }

    try {
      await _stapleRepository.editStapleFood(updated);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Staple food updated.',
          sk: 'Základná potravina bola upravená.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update staple food.',
          sk: 'Základnú potravinu sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _deleteStaple(StapleFood item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(en: 'Delete staple food', sk: 'Zmazať základnú potravinu'),
        ),
        content: Text(
          context.tr(
            en: 'Do you want to delete "${item.name}"?',
            sk: 'Chceš zmazať "${item.name}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Delete', sk: 'Zmazať')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _stapleRepository.removeStapleFood(item.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Staple food deleted.',
          sk: 'Základná potravina bola zmazaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to delete staple food.',
          sk: 'Základnú potravinu sa nepodarilo zmazať.',
        ),
      );
    }
  }

  Future<void> _addMissingStaplesToShoppingList(
    List<StapleFood> staples,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(
        context,
        context.tr(
          en: 'No signed-in user.',
          sk: 'Nie je prihlásený žiadny používateľ.',
        ),
      );
      return;
    }

    try {
      final pantryItems = await _foodItemsRepository.getFoodItems();
      final shoppingItems = await _shoppingListRepository
          .getShoppingListItems();

      int changedCount = 0;

      for (final staple in staples) {
        final available = _sumAvailableQuantity(staple, pantryItems);
        final missing = staple.quantity - available;
        if (missing <= 0.0001) {
          continue;
        }

        changedCount += await _upsertShoppingNeed(
          userId: user.id,
          existingItems: shoppingItems,
          staple: staple,
          quantity: missing,
        );
      }

      if (!mounted) return;
      if (changedCount == 0) {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Staple foods are already covered.',
            sk: 'Základné potraviny sú už pokryté.',
          ),
        );
      } else {
        widget.onShoppingListChanged?.call();
        showSuccessFeedback(
          context,
          context.tr(
            en: '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from staple foods.',
            sk: '$changedCount nákupn${changedCount == 1 ? 'á položka bola upravená' : 'é položky boli upravené'} podľa základných potravín.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update shopping list from staples.',
          sk: 'Nákupný zoznam sa nepodarilo aktualizovať zo základných potravín.',
        ),
      );
    }
  }

  double _sumAvailableQuantity(StapleFood staple, List<FoodItem> pantryItems) {
    double sum = 0;
    for (final item in pantryItems) {
      if (_itemKey(item.name, item.unit) !=
          _itemKey(staple.name, staple.unit)) {
        continue;
      }
      final converted = _convertQuantity(
        quantity: item.quantity,
        fromUnit: item.unit,
        toUnit: staple.unit,
      );
      if (converted != null) {
        sum += converted;
      }
    }
    return sum;
  }

  Future<int> _upsertShoppingNeed({
    required String userId,
    required List<ShoppingListItem> existingItems,
    required StapleFood staple,
    required double quantity,
  }) async {
    final key = _itemKey(staple.name, staple.unit);
    final matchingItems = existingItems
        .where((item) => _itemKey(item.name, item.unit) == key)
        .toList();
    final now = DateTime.now().toUtc();

    if (matchingItems.isEmpty) {
      final created = await _shoppingListRepository.addShoppingListItem(
        ShoppingListItem(
          id: '',
          userId: userId,
          householdId: widget.householdId,
          name: staple.name,
          quantity: quantity,
          unit: staple.unit,
          source: ShoppingListItem.sourceManual,
          isBought: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      existingItems.add(created);
      return 1;
    }

    final primary = matchingItems.first;
    final mergedSource = matchingItems
        .skip(1)
        .fold<String>(
          ShoppingListItem.mergeSource(
            primary.source,
            ShoppingListItem.sourceManual,
          ),
          (current, item) => ShoppingListItem.mergeSource(current, item.source),
        );
    final updated = await _shoppingListRepository.editShoppingListItem(
      primary.copyWith(
        quantity: quantity,
        source: mergedSource,
        isBought: false,
        updatedAt: now,
      ),
    );

    final primaryIndex = existingItems.indexWhere(
      (item) => item.id == primary.id,
    );
    if (primaryIndex >= 0) {
      existingItems[primaryIndex] = updated;
    }

    for (final duplicate in matchingItems.skip(1)) {
      await _shoppingListRepository.removeShoppingListItem(duplicate.id);
      existingItems.removeWhere((item) => item.id == duplicate.id);
    }

    return 1;
  }

  double? _convertQuantity({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    final normalizedFrom = _normalizeUnit(fromUnit);
    final normalizedTo = _normalizeUnit(toUnit);

    if (normalizedFrom == normalizedTo) {
      return quantity;
    }

    const weightFactors = {'g': 1.0, 'kg': 1000.0};
    const volumeFactors = {'ml': 1.0, 'l': 1000.0};
    const pieceFactors = {
      'pcs': 1.0,
      'pc': 1.0,
      'piece': 1.0,
      'pieces': 1.0,
      'ks': 1.0,
    };

    if (weightFactors.containsKey(normalizedFrom) &&
        weightFactors.containsKey(normalizedTo)) {
      final base = quantity * weightFactors[normalizedFrom]!;
      return base / weightFactors[normalizedTo]!;
    }

    if (volumeFactors.containsKey(normalizedFrom) &&
        volumeFactors.containsKey(normalizedTo)) {
      final base = quantity * volumeFactors[normalizedFrom]!;
      return base / volumeFactors[normalizedTo]!;
    }

    if (pieceFactors.containsKey(normalizedFrom) &&
        pieceFactors.containsKey(normalizedTo)) {
      final base = quantity * pieceFactors[normalizedFrom]!;
      return base / pieceFactors[normalizedTo]!;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: Text(
          context.tr(en: 'Add staple', sk: 'Pridať základnú potravinu'),
        ),
      ),
      body: FutureBuilder<List<StapleFood>>(
        future: _staplesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              kind: inferAppErrorKind(
                snapshot.error,
                fallback: AppErrorKind.sync,
              ),
              message: context.tr(
                en: 'Failed to load staple foods.',
                sk: 'Nepodarilo sa načítať základné potraviny.',
              ),
              onRetry: _reload,
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No staple foods yet.',
                sk: 'Zatiaľ tu nie sú žiadne základné potraviny.',
              ),
              onRefresh: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
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
                      en: 'Staple foods',
                      sk: 'Základné potraviny',
                    ),
                    subtitle: context.tr(
                      en: 'Keep track of what your household wants to have at home regularly.',
                      sk: 'Sleduj, čo chce mať tvoja domácnosť doma pravidelne.',
                    ),
                    onBack: () => Navigator.of(context).maybePop(),
                    badges: [
                      _StapleBadge(
                        icon: Icons.home_outlined,
                        label:
                            '${items.length} ${context.tr(en: 'tracked', sk: 'sledované')}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SafoSpacing.lg),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            en: 'Foods your household wants to keep at home regularly.',
                            sk: 'Potraviny, ktoré chce vaša domácnosť držať doma pravidelne.',
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr(
                              en: 'Quick add common staples',
                              sk: 'Rýchlo pridať bežné základné potraviny',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: stapleFoodPresets.take(8).map((preset) {
                            return ActionChip(
                              label: Text(
                                context.tr(
                                  en: preset.nameEn,
                                  sk: preset.nameSk,
                                ),
                              ),
                              onPressed: () => _addPresetStaple(preset, items),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: () =>
                                _addMissingStaplesToShoppingList(items),
                            child: Text(
                              context.tr(
                                en: 'Add missing staples to shopping list',
                                sk: 'Pridať chýbajúce základné potraviny do nákupného zoznamu',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        onTap: () => _openEditForm(item),
                        title: Text(item.name),
                        subtitle: Text(
                          '${_formatQuantity(item.quantity)} ${item.unit} • ${_categoryLabel(item.category)}',
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteStaple(item),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: context.tr(en: 'Delete', sk: 'Zmazať'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _itemKey(String name, String unit) {
    return '${_normalizeName(name)}|${_normalizeUnit(unit)}';
  }

  String _normalizeName(String value) {
    const replacements = {
      'á': 'a',
      'ä': 'a',
      'č': 'c',
      'ď': 'd',
      'é': 'e',
      'ě': 'e',
      'í': 'i',
      'ĺ': 'l',
      'ľ': 'l',
      'ň': 'n',
      'ó': 'o',
      'ô': 'o',
      'ŕ': 'r',
      'ř': 'r',
      'š': 's',
      'ť': 't',
      'ú': 'u',
      'ů': 'u',
      'ý': 'y',
      'ž': 'z',
    };

    var normalized = value.toLowerCase().trim();
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalizeUnit(String value) {
    final normalized = value.trim().toLowerCase();
    if (const {'pcs', 'pc', 'piece', 'pieces', 'ks'}.contains(normalized)) {
      return 'pcs';
    }
    if (const {'g', 'gram', 'grams'}.contains(normalized)) {
      return 'g';
    }
    if (const {'kg', 'kilogram', 'kilograms'}.contains(normalized)) {
      return 'kg';
    }
    if (const {'ml', 'milliliter', 'milliliters'}.contains(normalized)) {
      return 'ml';
    }
    if (const {'l', 'liter', 'liters'}.contains(normalized)) {
      return 'l';
    }
    return normalized;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
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

class _StapleBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StapleBadge({required this.icon, required this.label});

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
