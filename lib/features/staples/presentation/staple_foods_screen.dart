import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../data/staple_food_repository.dart';
import '../domain/staple_food.dart';
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
      showSuccessFeedback(context, 'Staple food added.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add staple food.');
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
      showSuccessFeedback(context, 'Staple food updated.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update staple food.');
    }
  }

  Future<void> _deleteStaple(StapleFood item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete staple food'),
        content: Text('Do you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
      showSuccessFeedback(context, 'Staple food deleted.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to delete staple food.');
    }
  }

  Future<void> _addMissingStaplesToShoppingList(
    List<StapleFood> staples,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      showErrorFeedback(context, 'No signed-in user.');
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
        showSuccessFeedback(context, 'Staple foods are already covered.');
      } else {
        widget.onShoppingListChanged?.call();
        showSuccessFeedback(
          context,
          '$changedCount shopping item${changedCount == 1 ? '' : 's'} updated from staple foods.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        'Failed to update shopping list from staples.',
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
      appBar: AppBar(title: const Text('Staple foods')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Add staple'),
      ),
      body: FutureBuilder<List<StapleFood>>(
        future: _staplesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Failed to load staple foods.',
              onRetry: _reload,
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              message: 'No staple foods yet.',
              onRefresh: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Foods your household wants to keep at home regularly.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: () =>
                                _addMissingStaplesToShoppingList(items),
                            child: const Text(
                              'Add missing staples to shopping list',
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
