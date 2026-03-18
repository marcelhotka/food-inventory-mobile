import 'package:flutter/material.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
import '../../households/domain/household.dart';
import '../../households/presentation/household_screen.dart';
import '../data/shopping_list_remote_data_source.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_item.dart';
import 'shopping_list_form_screen.dart';

enum ShoppingListFilter { all, toBuy, bought }

class ShoppingListScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final Household household;
  final int refreshToken;

  const ShoppingListScreen({
    super.key,
    required this.authRepository,
    required this.household,
    required this.refreshToken,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final ShoppingListRepository repository = ShoppingListRepository(
    householdId: widget.household.id,
  );
  final TextEditingController _searchController = TextEditingController();

  late Future<List<ShoppingListItem>> _shoppingListFuture;
  ShoppingListFilter _selectedFilter = ShoppingListFilter.all;

  @override
  void initState() {
    super.initState();
    _shoppingListFuture = _loadShoppingListItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ShoppingListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _shoppingListFuture = _loadShoppingListItems();
    });

    await _shoppingListFuture;
  }

  Future<List<ShoppingListItem>> _loadShoppingListItems() async {
    var items = await repository.getShoppingListItems();
    final groups = <String, List<ShoppingListItem>>{};

    for (final item in items) {
      final key = _itemKey(item.name, item.unit);
      groups.putIfAbsent(key, () => []).add(item);
    }

    var changed = false;

    for (final group in groups.values) {
      if (group.length <= 1) {
        continue;
      }

      changed = true;
      final primary = group.first;
      var mergedQuantity = primary.quantity;
      var mergedSource = primary.source;
      var anyBought = primary.isBought;

      for (final duplicate in group.skip(1)) {
        if (duplicate.quantity > mergedQuantity) {
          mergedQuantity = duplicate.quantity;
        }
        mergedSource = ShoppingListItem.mergeSource(
          mergedSource,
          duplicate.source,
        );
        anyBought = anyBought || duplicate.isBought;
      }

      final updatedPrimary = primary.copyWith(
        quantity: mergedQuantity,
        source: mergedSource,
        isBought: anyBought,
        updatedAt: DateTime.now().toUtc(),
      );

      await repository.editShoppingListItem(updatedPrimary);

      for (final duplicate in group.skip(1)) {
        await repository.removeShoppingListItem(duplicate.id);
      }
    }

    if (changed) {
      items = await repository.getShoppingListItems();
    }

    return items;
  }

  Future<void> _openCreateForm() async {
    final createdItem = await Navigator.of(context).push<ShoppingListItem>(
      MaterialPageRoute(
        builder: (_) =>
            ShoppingListFormScreen(householdId: widget.household.id),
      ),
    );

    if (createdItem == null) {
      return;
    }

    try {
      final existingItems = await repository.getShoppingListItems();
      final result = await _saveShoppingItemWithDuplicateHandling(
        createdItem,
        existingItems: existingItems,
      );
      await _reload();
      if (!mounted) return;
      if (result.wasMerged) {
        showSuccessFeedback(
          context,
          'Updated existing ${result.item.name} (${_formatQuantity(result.item.quantity)} ${result.item.unit}).',
        );
      } else {
        showSuccessFeedback(context, 'Shopping item added.');
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to add shopping item.');
    }
  }

  Future<_ShoppingSaveResult> _saveShoppingItemWithDuplicateHandling(
    ShoppingListItem incomingItem, {
    required List<ShoppingListItem> existingItems,
  }) async {
    final normalizedName = _itemKey(incomingItem.name, incomingItem.unit);
    final existing = existingItems.cast<ShoppingListItem?>().firstWhere(
      (item) =>
          item != null && _itemKey(item.name, item.unit) == normalizedName,
      orElse: () => null,
    );

    if (existing == null) {
      final created = await repository.addShoppingListItem(incomingItem);
      existingItems.add(created);
      return _ShoppingSaveResult(item: created, wasMerged: false);
    }

    final updated = await repository.editShoppingListItem(
      existing.copyWith(
        quantity: incomingItem.quantity,
        isBought: false,
        source: ShoppingListItem.mergeSource(
          existing.source,
          ShoppingListItem.sourceManual,
        ),
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final index = existingItems.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      existingItems[index] = updated;
    }

    return _ShoppingSaveResult(item: updated, wasMerged: true);
  }

  Future<void> _openEditForm(ShoppingListItem item) async {
    final updatedItem = await Navigator.of(context).push<ShoppingListItem>(
      MaterialPageRoute(
        builder: (_) => ShoppingListFormScreen(
          initialItem: item,
          householdId: widget.household.id,
        ),
      ),
    );

    if (updatedItem == null) {
      return;
    }

    try {
      await repository.editShoppingListItem(updatedItem);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Shopping item updated.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update shopping item.');
    }
  }

  Future<void> _deleteItem(ShoppingListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete shopping item'),
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
      await repository.removeShoppingListItem(item.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(context, 'Shopping item deleted.');
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to delete shopping item.');
    }
  }

  Future<void> _toggleBought(ShoppingListItem item, bool value) async {
    try {
      await repository.editShoppingListItem(
        item.copyWith(isBought: value, updatedAt: DateTime.now().toUtc()),
      );
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        value ? 'Marked as bought.' : 'Marked as not bought.',
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(context, 'Failed to update shopping item.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
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
      body: FutureBuilder<List<ShoppingListItem>>(
        future: _shoppingListFuture,
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

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              message: 'No shopping list items yet.',
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
                  _ShoppingSearchAndFilterBar(
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
                    message: 'No shopping items match your search.',
                    onRefresh: _reload,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredItems.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ShoppingSearchAndFilterBar(
                    controller: _searchController,
                    selectedFilter: _selectedFilter,
                    onSearchChanged: (_) => setState(() {}),
                    onFilterChanged: (value) {
                      setState(() {
                        _selectedFilter = value;
                      });
                    },
                  );
                }

                final item = filteredItems[index - 1];
                return Card(
                  child: ListTile(
                    onTap: () => _openEditForm(item),
                    leading: Checkbox(
                      value: item.isBought,
                      onChanged: (value) {
                        if (value == null) return;
                        _toggleBought(item, value);
                      },
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        decoration: item.isBought
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text(_buildSubtitle(item)),
                    trailing: IconButton(
                      onPressed: () => _deleteItem(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _buildSubtitle(ShoppingListItem item) {
    return '${item.quantity} ${item.unit} • ${_sourceLabel(item.source)}';
  }

  List<ShoppingListItem> _applyFilters(List<ShoppingListItem> items) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesQuery =
          query.isEmpty || item.name.toLowerCase().contains(query);

      if (!matchesQuery) {
        return false;
      }

      return switch (_selectedFilter) {
        ShoppingListFilter.all => true,
        ShoppingListFilter.toBuy => !item.isBought,
        ShoppingListFilter.bought => item.isBought,
      };
    }).toList();
  }

  String _itemKey(String name, String unit) {
    return '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _errorMessage(Object? error) {
    if (error is ShoppingListConfigException ||
        error is ShoppingListAuthException) {
      return error.toString();
    }
    return 'Failed to load shopping list items.';
  }

  String _sourceLabel(String value) {
    return switch (value) {
      ShoppingListItem.sourceRecipeMissing => 'Recipe',
      ShoppingListItem.sourceLowStock => 'Low stock',
      ShoppingListItem.sourceMultiple => 'Multiple',
      _ => 'Manual',
    };
  }
}

class _ShoppingSaveResult {
  final ShoppingListItem item;
  final bool wasMerged;

  const _ShoppingSaveResult({required this.item, required this.wasMerged});
}

class _ShoppingSearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final ShoppingListFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ShoppingListFilter> onFilterChanged;

  const _ShoppingSearchAndFilterBar({
    required this.controller,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search shopping items',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: selectedFilter == ShoppingListFilter.all,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.all),
              ),
              FilterChip(
                label: const Text('To buy'),
                selected: selectedFilter == ShoppingListFilter.toBuy,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.toBuy),
              ),
              FilterChip(
                label: const Text('Bought'),
                selected: selectedFilter == ShoppingListFilter.bought,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.bought),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
