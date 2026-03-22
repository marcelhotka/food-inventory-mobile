import 'package:flutter/material.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
import '../../households/domain/household.dart';
import '../../households/presentation/household_screen.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/food_item_remote_data_source.dart';
import '../data/food_items_repository.dart';
import '../domain/food_item.dart';
import '../domain/food_item_prefill.dart';
import 'barcode_lookup_screen.dart';
import 'food_item_form_screen.dart';
import 'fridge_scan_screen.dart';
import 'scan_history_screen.dart';

enum PantryFilter { all, expiringSoon, noExpiry }

class FoodItemsScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final Household household;
  final VoidCallback onPantryChanged;
  final VoidCallback onShoppingListChanged;
  final int refreshToken;

  const FoodItemsScreen({
    super.key,
    required this.authRepository,
    required this.household,
    required this.onPantryChanged,
    required this.onShoppingListChanged,
    required this.refreshToken,
  });

  @override
  State<FoodItemsScreen> createState() => _FoodItemsScreenState();
}

class _FoodItemsScreenState extends State<FoodItemsScreen> {
  late final FoodItemsRepository repository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<_PantryViewData> _pantryFuture;
  PantryFilter _selectedFilter = PantryFilter.all;

  @override
  void initState() {
    super.initState();
    _pantryFuture = _loadPantryViewData();
  }

  @override
  void didUpdateWidget(covariant FoodItemsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _pantryFuture = _loadPantryViewData();
    });

    await _pantryFuture;
  }

  Future<_PantryViewData> _loadPantryViewData() async {
    final items = await repository.getFoodItems();
    UserPreferences? preferences;
    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }
    return _PantryViewData(items: items, preferences: preferences);
  }

  Future<void> _openCreateForm() async {
    await _openCreateFormWithPrefill();
  }

  Future<void> _openCreateFormWithPrefill([FoodItemPrefill? prefill]) async {
    final createdItem = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodItemFormScreen(
          prefill: prefill,
          householdId: widget.household.id,
        ),
      ),
    );

    if (createdItem == null) {
      return;
    }

    try {
      final currentItems = await repository.getFoodItems();
      final result = await _savePantryItemWithDuplicateHandling(
        createdItem,
        existingItems: currentItems,
        promptForMerge: true,
      );
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      if (result.wasMerged) {
        showSuccessFeedback(
          context,
          'Updated existing ${result.item.name} (+${_formatCompactNumber(result.addedQuantity)} ${result.item.unit}).',
        );
      } else {
        showSuccessFeedback(context, 'Pantry item added.');
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add pantry item.');
    }
  }

  Future<void> _openBarcodeLookup() async {
    final prefill = await Navigator.of(context).push<FoodItemPrefill>(
      MaterialPageRoute(builder: (_) => const BarcodeLookupScreen()),
    );

    if (prefill == null) {
      return;
    }

    await _openCreateFormWithPrefill(prefill);
  }

  Future<void> _openFridgeScan() async {
    final prefills = await Navigator.of(context).push<List<FoodItemPrefill>>(
      MaterialPageRoute(
        builder: (_) => FridgeScanScreen(householdId: widget.household.id),
      ),
    );

    if (prefills == null || prefills.isEmpty) {
      return;
    }

    final user = widget.authRepository.currentSession?.user;
    if (user == null) {
      if (!mounted) return;
      showErrorFeedback(context, 'You need to be signed in.');
      return;
    }

    try {
      final currentItems = await repository.getFoodItems();
      var createdCount = 0;
      var mergedCount = 0;

      for (final prefill in prefills) {
        final now = DateTime.now().toUtc();
        final item = FoodItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: prefill.name,
          barcode: prefill.barcode,
          category: prefill.category,
          storageLocation: prefill.storageLocation,
          quantity: prefill.quantity,
          lowStockThreshold: prefill.lowStockThreshold,
          unit: prefill.unit,
          expirationDate: prefill.expirationDate,
          createdAt: now,
          updatedAt: now,
        );
        final result = await _savePantryItemWithDuplicateHandling(
          item,
          existingItems: currentItems,
          promptForMerge: false,
        );
        if (result.wasMerged) {
          mergedCount++;
        } else {
          createdCount++;
        }
        final index = currentItems.indexWhere(
          (existing) => existing.id == result.item.id,
        );
        if (index >= 0) {
          currentItems[index] = result.item;
        } else {
          currentItems.add(result.item);
        }
      }

      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      final parts = <String>[];
      if (createdCount > 0) {
        parts.add('$createdCount new item${createdCount == 1 ? '' : 's'}');
      }
      if (mergedCount > 0) {
        parts.add(
          '$mergedCount updated existing item${mergedCount == 1 ? '' : 's'}',
        );
      }
      showSuccessFeedback(
        context,
        parts.isEmpty
            ? 'Scan processed.'
            : 'Scan processed: ${parts.join(', ')}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add scanned items.');
    }
  }

  Future<_PantrySaveResult> _savePantryItemWithDuplicateHandling(
    FoodItem incomingItem, {
    required List<FoodItem> existingItems,
    required bool promptForMerge,
  }) async {
    final match = _findMatchingPantryItem(existingItems, incomingItem);
    if (match == null) {
      final created = await repository.addFoodItem(incomingItem);
      existingItems.add(created);
      return _PantrySaveResult(
        item: created,
        wasMerged: false,
        addedQuantity: incomingItem.quantity,
      );
    }

    var shouldMerge = !promptForMerge;

    if (promptForMerge) {
      final decision = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Similar pantry item found'),
          content: Text(
            'You already have "${match.name}" in pantry. Do you want to increase the existing quantity instead of creating a duplicate item?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Create separately'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Increase existing'),
            ),
          ],
        ),
      );

      shouldMerge = decision == true;
    }

    if (!shouldMerge) {
      final created = await repository.addFoodItem(incomingItem);
      existingItems.add(created);
      return _PantrySaveResult(
        item: created,
        wasMerged: false,
        addedQuantity: incomingItem.quantity,
      );
    }

    final merged = _mergePantryItems(match, incomingItem);
    final persisted = await repository.editFoodItem(merged);
    final index = existingItems.indexWhere((item) => item.id == match.id);
    if (index >= 0) {
      existingItems[index] = persisted;
    }
    return _PantrySaveResult(
      item: persisted,
      wasMerged: true,
      addedQuantity: incomingItem.quantity,
    );
  }

  FoodItem? _findMatchingPantryItem(
    List<FoodItem> items,
    FoodItem incomingItem,
  ) {
    final incomingBarcode = incomingItem.barcode?.trim();

    for (final item in items) {
      final existingBarcode = item.barcode?.trim();
      if (incomingBarcode != null &&
          incomingBarcode.isNotEmpty &&
          existingBarcode != null &&
          existingBarcode.isNotEmpty &&
          incomingBarcode == existingBarcode) {
        return item;
      }
    }

    final incomingKey = _pantryDuplicateKey(incomingItem);

    for (final item in items) {
      final itemKey = _pantryDuplicateKey(item);
      if (itemKey == incomingKey) {
        return item;
      }
    }

    return null;
  }

  FoodItem _mergePantryItems(FoodItem existing, FoodItem incoming) {
    final mergedExpiration = [existing.expirationDate, incoming.expirationDate]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (current, value) {
          if (current == null) {
            return value;
          }
          return value.isBefore(current) ? value : current;
        });
    final mergedThreshold =
        [
          existing.lowStockThreshold,
          incoming.lowStockThreshold,
        ].whereType<double>().fold<double?>(null, (current, value) {
          if (current == null) {
            return value;
          }
          return value > current ? value : current;
        });
    final distinctBarcodes = {
      ...[
        existing.barcode?.trim(),
        incoming.barcode?.trim(),
      ].whereType<String>().where((value) => value.isNotEmpty),
    };

    return existing.copyWith(
      quantity: existing.quantity + incoming.quantity,
      category: _mergedCategory(existing.category, incoming.category),
      lowStockThreshold: mergedThreshold,
      expirationDate: mergedExpiration,
      clearExpirationDate: mergedExpiration == null,
      barcode: distinctBarcodes.length == 1 ? distinctBarcodes.first : null,
      clearBarcode: distinctBarcodes.length != 1,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _openEditForm(FoodItem item) async {
    final updatedItem = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodItemFormScreen(
          initialItem: item,
          householdId: widget.household.id,
        ),
      ),
    );

    if (updatedItem == null) {
      return;
    }

    try {
      await repository.editFoodItem(updatedItem);
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(context, 'Pantry item updated.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update pantry item.');
    }
  }

  Future<void> _openAddMoreForm(FoodItem item) async {
    final additionalItem = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodItemFormScreen(
          householdId: widget.household.id,
          prefill: FoodItemPrefill(
            name: item.name,
            barcode: item.barcode,
            category: item.category,
            storageLocation: item.storageLocation,
            quantity: 1,
            unit: item.unit,
            expirationDate: item.expirationDate,
            lowStockThreshold: item.lowStockThreshold,
          ),
        ),
      ),
    );

    if (additionalItem == null) {
      return;
    }

    try {
      final updatedItem = item.copyWith(
        quantity: item.quantity + additionalItem.quantity,
        updatedAt: DateTime.now().toUtc(),
      );
      await repository.editFoodItem(updatedItem);
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        'Added to existing ${updatedItem.name} (+${_formatCompactNumber(additionalItem.quantity)} ${additionalItem.unit}). Total: ${_formatCompactNumber(updatedItem.quantity)} ${updatedItem.unit}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add more to pantry item.');
    }
  }

  Future<void> _deleteItem(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete food item'),
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
      await repository.removeFoodItem(item.id);
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(context, 'Pantry item deleted.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to delete pantry item.');
    }
  }

  Future<void> _markItemAsUsed(FoodItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: '1');

    final usedQuantity = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Use ${item.name}'),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Used quantity (${item.unit})',
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final rawValue = controller.text.trim();
                  final parsed = _parseQuantity(rawValue);

                  if (rawValue.isEmpty) {
                    setDialogState(() {
                      errorText = 'Enter quantity';
                    });
                    return;
                  }

                  if (parsed == null || parsed <= 0) {
                    setDialogState(() {
                      errorText = 'Enter a valid number';
                    });
                    return;
                  }

                  if (parsed > item.quantity + 0.000001) {
                    setDialogState(() {
                      errorText = 'Cannot use more than you have';
                    });
                    return;
                  }

                  Navigator.pop(context, parsed);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (usedQuantity == null) {
      return;
    }

    try {
      final remainingQuantity = double.parse(
        (item.quantity - usedQuantity).toStringAsFixed(6),
      );

      if (remainingQuantity <= 0.000001) {
        await repository.removeFoodItem(item.id);
      } else {
        final updatedItem = item.copyWith(
          quantity: remainingQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.editFoodItem(updatedItem);
      }
      if (!mounted) return;
      setState(() {
        _pantryFuture = _loadPantryViewData();
      });
      widget.onPantryChanged();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              remainingQuantity <= 0.000001
                  ? '${item.name} used up and removed.'
                  : '${item.name} updated.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      if (remainingQuantity <= 0.000001) {
        return;
      }
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to update pantry item: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }

  Future<void> _showItemActions(FoodItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add more'),
              subtitle: const Text('Increase the current quantity'),
              onTap: () {
                Navigator.of(context).pop();
                _openAddMoreForm(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              subtitle: const Text('Replace or update this item'),
              onTap: () {
                Navigator.of(context).pop();
                _openEditForm(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Mark as used'),
              onTap: () {
                Navigator.of(context).pop();
                _markItemAsUsed(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  double? _parseQuantity(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String _shoppingKey(String name, String unit) {
    return '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
  }

  bool _isLowStock(FoodItem item) {
    final threshold = item.lowStockThreshold;
    if (threshold == null) {
      return false;
    }
    return item.quantity <= threshold;
  }

  Future<void> _addLowStockItemsToShoppingList(List<FoodItem> items) async {
    final lowStockItems = items.where(_isLowStock).toList();
    if (lowStockItems.isEmpty) {
      showErrorFeedback(context, 'No low stock items to add.');
      return;
    }

    final user = widget.authRepository.currentSession?.user;
    if (user == null) {
      showErrorFeedback(context, 'You need to be signed in.');
      return;
    }

    try {
      final existingShoppingItems = await _shoppingListRepository
          .getShoppingListItems();

      var createdCount = 0;
      for (final item in lowStockItems) {
        final normalizedKey = _shoppingKey(item.name, item.unit);
        final targetQuantity = item.lowStockThreshold ?? item.quantity;
        final missingQuantity = targetQuantity - item.quantity;
        final quantityToBuy = missingQuantity > 0 ? missingQuantity : 1.0;
        final matchingItems = existingShoppingItems
            .where(
              (shoppingItem) =>
                  _shoppingKey(shoppingItem.name, shoppingItem.unit) ==
                  normalizedKey,
            )
            .toList();

        if (matchingItems.isNotEmpty) {
          final primary = matchingItems.first;
          var mergedSource = primary.source;
          var mergedQuantity = primary.quantity > quantityToBuy
              ? primary.quantity
              : quantityToBuy;

          for (final duplicate in matchingItems.skip(1)) {
            mergedSource = ShoppingListItem.mergeSource(
              mergedSource,
              duplicate.source,
            );
            if (duplicate.quantity > mergedQuantity) {
              mergedQuantity = duplicate.quantity;
            }
          }

          mergedSource = ShoppingListItem.mergeSource(
            mergedSource,
            ShoppingListItem.sourceLowStock,
          );

          final updated = primary.copyWith(
            quantity: mergedQuantity,
            source: mergedSource,
            isBought: false,
            updatedAt: DateTime.now().toUtc(),
          );
          await _shoppingListRepository.editShoppingListItem(updated);

          for (final duplicate in matchingItems.skip(1)) {
            await _shoppingListRepository.removeShoppingListItem(duplicate.id);
            existingShoppingItems.removeWhere(
              (item) => item.id == duplicate.id,
            );
          }

          existingShoppingItems.removeWhere((item) => item.id == updated.id);
          existingShoppingItems.add(updated);
          createdCount++;
          continue;
        }

        final shoppingItem = ShoppingListItem(
          id: '',
          userId: user.id,
          householdId: widget.household.id,
          name: item.name,
          quantity: quantityToBuy,
          unit: item.unit,
          source: ShoppingListItem.sourceLowStock,
          isBought: false,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final created = await _shoppingListRepository.addShoppingListItem(
          shoppingItem,
        );
        existingShoppingItems.add(created);
        createdCount++;
      }

      if (!mounted) {
        return;
      }

      if (createdCount == 0) {
        showSuccessFeedback(
          context,
          'Low stock items are already on the shopping list.',
        );
      } else {
        widget.onShoppingListChanged();
        showSuccessFeedback(
          context,
          '$createdCount low stock item${createdCount == 1 ? '' : 's'} added to shopping list.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      showErrorFeedback(context, 'Failed to add low stock items.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseholdScreen(household: widget.household),
                ),
              );
            },
            icon: const Icon(Icons.groups_2_outlined),
            tooltip: 'Household',
          ),
          IconButton(
            onPressed: _openBarcodeLookup,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan code',
          ),
          IconButton(
            onPressed: _openFridgeScan,
            icon: const Icon(Icons.photo_camera_back_outlined),
            tooltip: 'Scan fridge',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ScanHistoryScreen(householdId: widget.household.id),
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan history',
          ),
          IconButton(
            onPressed: widget.authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: FutureBuilder<_PantryViewData>(
        future: _pantryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: _errorMessage(snapshot.error),
              onRetry: _reload,
            );
          }

          final items = snapshot.data?.items ?? [];
          final preferences = snapshot.data?.preferences;
          if (items.isEmpty) {
            return AppEmptyState(
              message: 'No pantry items yet.',
              onRefresh: _reload,
            );
          }

          final filteredItems = _applyFilters(items);
          if (filteredItems.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _SearchAndFilterBar(
                    controller: _searchController,
                    selectedFilter: _selectedFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onFilterChanged: (value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  AppEmptyState(
                    message: 'No pantry items match your search.',
                    onRefresh: _reload,
                  ),
                ],
              ),
            );
          }

          final expiringSoonCount = items.where(_isExpiringSoon).length;
          final lowStockCount = items.where(_isLowStock).length;
          final shouldShowDuplicateMerge =
              _selectedFilter == PantryFilter.all &&
              _searchController.text.trim().isEmpty;
          final duplicateGroups = shouldShowDuplicateMerge
              ? _findMergeableDuplicateGroups(items)
              : const <List<FoodItem>>[];
          final duplicateItemCount = duplicateGroups.fold<int>(
            0,
            (sum, group) => sum + group.length - 1,
          );
          final groupedEntries = _buildGroupedEntries(filteredItems);

          final headerWidgets = <Widget>[
            _PantrySummary(
              totalItems: items.length,
              expiringSoonCount: expiringSoonCount,
              lowStockCount: lowStockCount,
            ),
            const SizedBox(height: 12),
            _SearchAndFilterBar(
              controller: _searchController,
              selectedFilter: _selectedFilter,
              onSearchChanged: (_) => setState(() {}),
              onFilterChanged: (value) {
                setState(() {
                  _selectedFilter = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (lowStockCount > 0)
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () =>
                            _openLowStockScreen(items, preferences),
                        child: Text(
                          'View $lowStockCount low stock item${lowStockCount == 1 ? '' : 's'}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _addLowStockItemsToShoppingList(items),
                        child: const Text('Add to shopping list'),
                      ),
                    ),
                  ],
                ),
              ),
            if (lowStockCount > 0) const SizedBox(height: 16),
            if (duplicateItemCount > 0)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => _mergeDuplicateItems(duplicateGroups),
                  child: Text(
                    'Merge $duplicateItemCount duplicate item${duplicateItemCount == 1 ? '' : 's'}',
                  ),
                ),
              ),
            if (duplicateItemCount > 0) const SizedBox(height: 16),
          ];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: headerWidgets.length + groupedEntries.length,
              itemBuilder: (context, index) {
                if (index < headerWidgets.length) {
                  return headerWidgets[index];
                }

                final entry = groupedEntries[index - headerWidgets.length];
                return _buildGroupedEntry(entry, preferences);
              },
            ),
          );
        },
      ),
    );
  }

  List<FoodItem> _applyFilters(List<FoodItem> items) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.storageLocation.toLowerCase().contains(query) ||
          (item.barcode?.toLowerCase().contains(query) ?? false);

      if (!matchesQuery) {
        return false;
      }

      return switch (_selectedFilter) {
        PantryFilter.all => true,
        PantryFilter.expiringSoon => _isExpiringSoon(item),
        PantryFilter.noExpiry => item.expirationDate == null,
      };
    }).toList();
  }

  List<List<FoodItem>> _findMergeableDuplicateGroups(List<FoodItem> items) {
    final grouped = <String, List<FoodItem>>{};

    for (final item in items) {
      final key = _pantryDuplicateKey(item);

      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.values
        .where((group) => group.length > 1)
        .map((group) => [...group]..sort(_compareFoodItemsForDisplay))
        .toList()
      ..sort(
        (a, b) =>
            a.first.name.toLowerCase().compareTo(b.first.name.toLowerCase()),
      );
  }

  Future<void> _mergeDuplicateItems(List<List<FoodItem>> groups) async {
    final duplicateCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.length - 1,
    );
    final previewNames = groups
        .take(3)
        .map((group) => group.first.name)
        .join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Merge duplicate pantry items'),
        content: Text(
          'This will merge $duplicateCount duplicate item${duplicateCount == 1 ? '' : 's'} and sum their quantities.'
          '${previewNames.isEmpty ? '' : '\n\nExamples: $previewNames'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      var mergedGroups = 0;

      for (final group in groups) {
        final primary = group.first;
        final duplicates = group.skip(1).toList();
        final now = DateTime.now().toUtc();
        final mergedQuantity = group.fold<double>(
          0,
          (sum, item) => sum + item.quantity,
        );
        final mergedExpiration = group
            .map((item) => item.expirationDate)
            .whereType<DateTime>()
            .fold<DateTime?>(null, (current, value) {
              if (current == null) {
                return value;
              }
              return value.isBefore(current) ? value : current;
            });
        final mergedThreshold = group
            .map((item) => item.lowStockThreshold)
            .whereType<double>()
            .fold<double?>(null, (current, value) {
              if (current == null) {
                return value;
              }
              return value > current ? value : current;
            });
        final distinctBarcodes = group
            .map((item) => item.barcode?.trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .toSet();

        await repository.editFoodItem(
          primary.copyWith(
            quantity: mergedQuantity,
            lowStockThreshold: mergedThreshold,
            expirationDate: mergedExpiration,
            clearExpirationDate: mergedExpiration == null,
            barcode: distinctBarcodes.length == 1
                ? distinctBarcodes.first
                : null,
            clearBarcode: distinctBarcodes.length != 1,
            updatedAt: now,
          ),
        );

        for (final duplicate in duplicates) {
          await repository.removeFoodItem(duplicate.id);
        }

        mergedGroups++;
      }

      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        'Merged $mergedGroups pantry duplicate group${mergedGroups == 1 ? '' : 's'}.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to merge duplicate items.');
    }
  }

  Future<void> _openLowStockScreen(
    List<FoodItem> items,
    UserPreferences? preferences,
  ) async {
    final lowStockItems = items.where(_isLowStock).toList()
      ..sort(_compareFoodItemsForDisplay);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Low stock')),
          body: lowStockItems.isEmpty
              ? AppEmptyState(
                  message: 'No low stock items.',
                  onRefresh: _reload,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lowStockItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = lowStockItems[index];
                    return _buildFoodItemCard(
                      item,
                      subtitle:
                          '${_formatCompactNumber(item.quantity)} ${item.unit} • ${_categoryLabel(item.category)} • ${_storageLocationLabel(item.storageLocation)}'
                          '${item.lowStockThreshold == null ? '' : ' • Limit ${_formatCompactNumber(item.lowStockThreshold!)} ${item.unit}'}',
                      warning: _buildFoodSafetyWarning(item, preferences),
                    );
                  },
                ),
        ),
      ),
    );
  }

  List<_PantryListEntry> _buildGroupedEntries(List<FoodItem> items) {
    const orderedLocations = ['fridge', 'freezer', 'pantry'];
    final entries = <_PantryListEntry>[];

    for (final location in orderedLocations) {
      final locationItems =
          items.where((item) => item.storageLocation == location).toList()
            ..sort(_compareFoodItemsForDisplay);

      if (locationItems.isEmpty) {
        continue;
      }

      entries.add(
        _PantrySectionEntry(
          title: _storageLocationLabel(location),
          count: locationItems.length,
        ),
      );

      for (var index = 0; index < locationItems.length; index++) {
        entries.add(
          _PantryItemEntry(
            item: locationItems[index],
            isLastInSection: index == locationItems.length - 1,
          ),
        );
      }
    }

    return entries;
  }

  Widget _buildGroupedEntry(
    _PantryListEntry entry,
    UserPreferences? preferences,
  ) {
    return switch (entry) {
      _PantrySectionEntry(:final title, :final count) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _StorageSectionHeader(title: title, count: count),
      ),
      _PantryItemEntry(:final item, :final isLastInSection) => Padding(
        padding: EdgeInsets.only(bottom: isLastInSection ? 16 : 12),
        child: _buildFoodItemCard(
          item,
          subtitle:
              '${_formatCompactNumber(item.quantity)} ${item.unit} • ${_categoryLabel(item.category)}'
              '${_isLowStock(item) ? ' • Low stock' : ''}',
          warning: _buildFoodSafetyWarning(item, preferences),
        ),
      ),
    };
  }

  Widget _buildFoodItemCard(
    FoodItem item, {
    required String subtitle,
    _FoodSafetyWarning? warning,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE7EAE3)),
      ),
      child: ListTile(
        onTap: () => _showItemActions(item),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF1B2A41),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (item.expirationDate != null)
              _ExpiryBadge(
                label: _expiryShortLabel(item.expirationDate!),
                state: _expiryState(item.expirationDate!),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7785),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              _FoodSafetyBadge(warning: warning),
            ],
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showItemActions(item),
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ),
    );
  }

  _FoodSafetyWarning? _buildFoodSafetyWarning(
    FoodItem item,
    UserPreferences? preferences,
  ) {
    if (preferences == null) {
      return null;
    }

    final signals = _foodSignalSet(item);
    if (signals.isEmpty) {
      return null;
    }

    final allergyMatches = _matchPreferenceSignals(
      preferences.allergies,
      signals,
    );
    if (allergyMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.allergy,
        matches: allergyMatches,
      );
    }

    final intoleranceMatches = _matchPreferenceSignals(
      preferences.intolerances,
      signals,
    );
    if (intoleranceMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.intolerance,
        matches: intoleranceMatches,
      );
    }

    return null;
  }

  Set<String> _foodSignalSet(FoodItem item) {
    final haystack = '${item.name.toLowerCase()} ${item.category.toLowerCase()}'
        .trim();
    final signals = <String>{};

    void addIfMatches(String signal, List<String> keywords) {
      if (keywords.any((keyword) => haystack.contains(keyword))) {
        signals.add(signal);
      }
    }

    addIfMatches('lactose', [
      'milk',
      'cheese',
      'yogurt',
      'cream',
      'butter',
      'dairy',
      'mozzarella',
      'cheddar',
      'gouda',
      'parmesan',
      'syr',
      'mlieko',
      'jogurt',
      'smotana',
      'maslo',
    ]);
    addIfMatches('gluten', [
      'bread',
      'pasta',
      'flour',
      'wheat',
      'couscous',
      'noodle',
      'toast',
      'pecivo',
      'pečivo',
      'chlieb',
      'muka',
      'múka',
      'cestoviny',
    ]);
    addIfMatches('eggs', ['egg', 'eggs', 'vajce', 'vajcia']);
    addIfMatches('peanuts', ['peanut', 'arasid', 'arašid']);
    addIfMatches('tree nuts', [
      'almond',
      'hazelnut',
      'walnut',
      'cashew',
      'pistachio',
      'pecan',
      'mandla',
      'orech',
    ]);
    addIfMatches('soy', ['soy', 'soya', 'tofu']);
    addIfMatches('fish', [
      'fish',
      'salmon',
      'tuna',
      'cod',
      'losos',
      'tuniak',
      'ryba',
    ]);
    addIfMatches('shellfish', [
      'shrimp',
      'prawn',
      'crab',
      'lobster',
      'mussel',
      'kreveta',
      'krab',
      'homar',
      'slavka',
      'slávka',
    ]);
    addIfMatches('sesame', ['sesame', 'sezam']);

    return signals;
  }

  List<String> _matchPreferenceSignals(
    List<String> preferences,
    Set<String> itemSignals,
  ) {
    final matches = <String>{};
    for (final preference in preferences) {
      final canonical = _canonicalFoodSignal(preference.trim().toLowerCase());
      if (canonical != null && itemSignals.contains(canonical)) {
        matches.add(canonical);
      }
    }
    return matches.toList()..sort();
  }

  String? _canonicalFoodSignal(String raw) {
    const aliases = {
      'lactose': 'lactose',
      'dairy': 'lactose',
      'milk': 'lactose',
      'mlieko': 'lactose',
      'gluten': 'gluten',
      'wheat': 'gluten',
      'celiac': 'gluten',
      'celiak': 'gluten',
      'egg': 'eggs',
      'eggs': 'eggs',
      'vajce': 'eggs',
      'vajcia': 'eggs',
      'peanut': 'peanuts',
      'peanuts': 'peanuts',
      'arasidy': 'peanuts',
      'arašidy': 'peanuts',
      'nuts': 'tree nuts',
      'tree nuts': 'tree nuts',
      'orechy': 'tree nuts',
      'orech': 'tree nuts',
      'soy': 'soy',
      'soya': 'soy',
      'fish': 'fish',
      'ryba': 'fish',
      'ryby': 'fish',
      'shellfish': 'shellfish',
      'seafood': 'shellfish',
      'krevety': 'shellfish',
      'sesame': 'sesame',
      'sezam': 'sesame',
    };
    return aliases[raw];
  }

  bool _isExpiringSoon(FoodItem item) {
    final expirationDate = item.expirationDate;
    if (expirationDate == null) {
      return false;
    }

    return _daysUntilExpiration(expirationDate) <= 3;
  }

  int _daysUntilExpiration(DateTime expirationDate) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedExpiration = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return normalizedExpiration.difference(normalizedToday).inDays;
  }

  int _compareFoodItemsForDisplay(FoodItem a, FoodItem b) {
    final aDate = a.expirationDate;
    final bDate = b.expirationDate;

    if (aDate != null && bDate != null) {
      return aDate.compareTo(bDate);
    }
    if (aDate != null) {
      return -1;
    }
    if (bDate != null) {
      return 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  String _expiryShortLabel(DateTime expirationDate) {
    final days = _daysUntilExpiration(expirationDate);
    if (days < 0) {
      return 'Expired';
    }
    if (days == 0) {
      return 'Today';
    }
    if (days == 1) {
      return 'Tomorrow';
    }
    return 'In $days days';
  }

  _ExpiryState _expiryState(DateTime expirationDate) {
    final days = _daysUntilExpiration(expirationDate);
    if (days < 0) {
      return _ExpiryState.expired;
    }
    if (days <= 1) {
      return _ExpiryState.urgent;
    }
    if (days <= 3) {
      return _ExpiryState.soon;
    }
    return _ExpiryState.normal;
  }

  String _formatCompactNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
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

  String _storageLocationLabel(String value) {
    return switch (value) {
      'fridge' => 'Fridge',
      'freezer' => 'Freezer',
      _ => 'Pantry',
    };
  }

  String _errorMessage(Object? error) {
    if (error is FoodItemsConfigException || error is FoodItemsAuthException) {
      return error.toString();
    }
    return 'Failed to load food items.';
  }

  String _normalizePantryName(String value) {
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

  String _normalizePantryUnit(String value) {
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

  String _pantryDuplicateKey(FoodItem item) {
    return [
      _normalizePantryName(item.name),
      _normalizePantryUnit(item.unit),
      item.storageLocation.trim().toLowerCase(),
    ].join('|');
  }

  String _mergedCategory(String existing, String incoming) {
    if (existing == incoming) {
      return existing;
    }
    if (existing == 'other' && incoming != 'other') {
      return incoming;
    }
    return existing;
  }
}

class _PantrySaveResult {
  final FoodItem item;
  final bool wasMerged;
  final double addedQuantity;

  const _PantrySaveResult({
    required this.item,
    required this.wasMerged,
    required this.addedQuantity,
  });
}

class _PantryViewData {
  final List<FoodItem> items;
  final UserPreferences? preferences;

  const _PantryViewData({required this.items, required this.preferences});
}

sealed class _PantryListEntry {
  const _PantryListEntry();
}

class _PantrySectionEntry extends _PantryListEntry {
  final String title;
  final int count;

  const _PantrySectionEntry({required this.title, required this.count});
}

class _PantryItemEntry extends _PantryListEntry {
  final FoodItem item;
  final bool isLastInSection;

  const _PantryItemEntry({required this.item, required this.isLastInSection});
}

class _PantrySummary extends StatelessWidget {
  final int totalItems;
  final int expiringSoonCount;
  final int lowStockCount;

  const _PantrySummary({
    required this.totalItems,
    required this.expiringSoonCount,
    required this.lowStockCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total items',
            value: totalItems.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Expiring soon',
            value: expiringSoonCount.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Low stock',
            value: lowStockCount.toString(),
          ),
        ),
      ],
    );
  }
}

enum _ExpiryState { expired, urgent, soon, normal }

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matches;

  const _FoodSafetyWarning({required this.type, required this.matches});
}

class _ExpiryBadge extends StatelessWidget {
  final String label;
  final _ExpiryState state;

  const _ExpiryBadge({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = switch (state) {
      _ExpiryState.expired => (
        background: const Color(0xFFF8D7DA),
        foreground: const Color(0xFF7A1F26),
      ),
      _ExpiryState.urgent => (
        background: const Color(0xFFFCE8D8),
        foreground: const Color(0xFF8A4B00),
      ),
      _ExpiryState.soon => (
        background: const Color(0xFFF4EDC8),
        foreground: const Color(0xFF745A00),
      ),
      _ExpiryState.normal => (
        background: const Color(0xFFE6F1EA),
        foreground: const Color(0xFF215D3A),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StorageSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool hideCount;

  const _StorageSectionHeader({
    required this.title,
    required this.count,
    this.hideCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF1B2A41),
            fontWeight: FontWeight.w800,
          ),
        ),
        if (!hideCount) ...[
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7EE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF1F7A43),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAE3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF1B2A41),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1B2A41),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodSafetyBadge extends StatelessWidget {
  final _FoodSafetyWarning warning;

  const _FoodSafetyBadge({required this.warning});

  @override
  Widget build(BuildContext context) {
    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final background = isAllergy
        ? const Color(0xFFFCE8D8)
        : const Color(0xFFF4EDC8);
    final foreground = isAllergy
        ? const Color(0xFF8A4B00)
        : const Color(0xFF745A00);
    final prefix = isAllergy ? 'Allergy warning' : 'Intolerance warning';
    final labels = warning.matches.map(_warningLabel).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$prefix: contains $labels',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _warningLabel(String signal) {
    return switch (signal) {
      'lactose' => 'lactose/dairy',
      'gluten' => 'gluten',
      'eggs' => 'eggs',
      'peanuts' => 'peanuts',
      'tree nuts' => 'tree nuts',
      'soy' => 'soy',
      'fish' => 'fish',
      'shellfish' => 'shellfish',
      'sesame' => 'sesame',
      _ => signal,
    };
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final PantryFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<PantryFilter> onFilterChanged;

  const _SearchAndFilterBar({
    required this.controller,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search pantry items',
            hintStyle: const TextStyle(
              color: Color(0xFF6B7785),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF6B7785),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE7EAE3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE7EAE3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFF2ECC71),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PantryFilterChip(
              label: 'All',
              selected: selectedFilter == PantryFilter.all,
              onTap: () => onFilterChanged(PantryFilter.all),
            ),
            _PantryFilterChip(
              label: 'Expiring soon',
              selected: selectedFilter == PantryFilter.expiringSoon,
              onTap: () => onFilterChanged(PantryFilter.expiringSoon),
            ),
            _PantryFilterChip(
              label: 'No expiry',
              selected: selectedFilter == PantryFilter.noExpiry,
              onTap: () => onFilterChanged(PantryFilter.noExpiry),
            ),
          ],
        ),
      ],
    );
  }
}

class _PantryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PantryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2ECC71) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF2ECC71) : const Color(0xFFE7EAE3),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : const Color(0xFF1B2A41),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
