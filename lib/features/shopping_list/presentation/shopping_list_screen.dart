import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../auth/data/auth_repository.dart';
import '../../households/domain/household.dart';
import '../../households/presentation/household_screen.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
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
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<_ShoppingListViewData> _shoppingListFuture;
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

  Future<_ShoppingListViewData> _loadShoppingListItems() async {
    var items = await repository.getShoppingListItems();
    UserPreferences? preferences;

    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }

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
        final convertedQuantity = _convertQuantity(
          quantity: duplicate.quantity,
          fromUnit: duplicate.unit,
          toUnit: primary.unit,
        );
        mergedQuantity += convertedQuantity ?? duplicate.quantity;
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

    return _ShoppingListViewData(items: items, preferences: preferences);
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

    final confirmed = await _confirmProceedWithSafetyWarning(
      createdItem,
      actionLabel: context.tr(
        en: 'add this item to your shopping list',
        sk: 'pridať túto položku do nákupného zoznamu',
      ),
      preferences: null,
    );
    if (!confirmed) {
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
          context.tr(
            en: 'Added to existing ${result.item.name} (+${_formatQuantity(createdItem.quantity)} ${createdItem.unit}). Total: ${_formatQuantity(result.item.quantity)} ${result.item.unit}.',
            sk: 'Pridané k existujúcej položke ${result.item.name} (+${_formatQuantity(createdItem.quantity)} ${createdItem.unit}). Spolu: ${_formatQuantity(result.item.quantity)} ${result.item.unit}.',
          ),
        );
      } else {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Shopping item added.',
            sk: 'Položka bola pridaná do nákupného zoznamu.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add shopping item.',
          sk: 'Položku sa nepodarilo pridať do nákupného zoznamu.',
        ),
      );
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

    final convertedIncomingQuantity = _convertQuantity(
      quantity: incomingItem.quantity,
      fromUnit: incomingItem.unit,
      toUnit: existing.unit,
    );
    final mergedQuantity =
        existing.quantity +
        (convertedIncomingQuantity ?? incomingItem.quantity);

    final updated = await repository.editShoppingListItem(
      existing.copyWith(
        quantity: mergedQuantity,
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

    final confirmed = await _confirmProceedWithSafetyWarning(
      updatedItem,
      actionLabel: context.tr(
        en: 'save this shopping item',
        sk: 'uložiť túto nákupnú položku',
      ),
      preferences: null,
    );
    if (!confirmed) {
      return;
    }

    try {
      await repository.editShoppingListItem(updatedItem);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Shopping item updated.',
          sk: 'Položka v nákupnom zozname bola upravená.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update shopping item.',
          sk: 'Položku v nákupnom zozname sa nepodarilo upraviť.',
        ),
      );
    }
  }

  Future<void> _openAddMoreForm(ShoppingListItem item) async {
    final quantityController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: item.unit);

    final additionalItem = await showDialog<ShoppingListItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(
            en: 'Add more ${item.name}',
            sk: 'Pridať viac ${item.name}',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr(en: 'Quantity', sk: 'Množstvo'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: InputDecoration(
                labelText: context.tr(en: 'Unit', sk: 'Jednotka'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text.trim());
              final unit = unitController.text.trim();
              if (quantity == null || quantity <= 0 || unit.isEmpty) {
                return;
              }
              Navigator.of(context).pop(
                item.copyWith(
                  quantity: quantity,
                  unit: unit,
                  isBought: false,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            },
            child: Text(context.tr(en: 'Add', sk: 'Pridať')),
          ),
        ],
      ),
    );

    quantityController.dispose();
    unitController.dispose();

    if (additionalItem == null) {
      return;
    }

    final confirmed = await _confirmProceedWithSafetyWarning(
      additionalItem,
      actionLabel: context.tr(
        en: 'add this item to your shopping list',
        sk: 'pridať túto položku do nákupného zoznamu',
      ),
      preferences: null,
    );
    if (!confirmed) {
      return;
    }

    final additionalQuantity = _convertQuantity(
      quantity: additionalItem.quantity,
      fromUnit: additionalItem.unit,
      toUnit: item.unit,
    );
    if (additionalQuantity == null) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Unable to add more because the unit is not compatible with ${item.unit}.',
          sk: 'Nepodarilo sa pridať viac, pretože jednotka nie je kompatibilná s ${item.unit}.',
        ),
      );
      return;
    }

    try {
      final updatedItem = await repository.editShoppingListItem(
        item.copyWith(
          quantity: item.quantity + additionalQuantity,
          isBought: false,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Added to existing ${updatedItem.name} (+${_formatQuantity(additionalItem.quantity)} ${additionalItem.unit}). Total: ${_formatQuantity(updatedItem.quantity)} ${updatedItem.unit}.',
          sk: 'Pridané k existujúcej položke ${updatedItem.name} (+${_formatQuantity(additionalItem.quantity)} ${additionalItem.unit}). Spolu: ${_formatQuantity(updatedItem.quantity)} ${updatedItem.unit}.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add more to this shopping item.',
          sk: 'Nepodarilo sa pridať viac k tejto nákupnej položke.',
        ),
      );
    }
  }

  Future<void> _showItemActions(ShoppingListItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(context.tr(en: 'Add more', sk: 'Pridať viac')),
              subtitle: Text(
                context.tr(
                  en: 'Increase the current quantity',
                  sk: 'Navýšiť aktuálne množstvo',
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openAddMoreForm(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.tr(en: 'Edit', sk: 'Upraviť')),
              subtitle: Text(
                context.tr(
                  en: 'Replace the current value',
                  sk: 'Prepísať aktuálnu hodnotu',
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openEditForm(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.tr(en: 'Delete', sk: 'Zmazať')),
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

  Future<void> _deleteItem(ShoppingListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.tr(en: 'Delete shopping item', sk: 'Zmazať nákupnú položku'),
        ),
        content: Text(
          context.tr(
            en: 'Do you want to delete "${item.name}"?',
            sk: 'Chceš zmazať položku "${item.name}"?',
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
      await repository.removeShoppingListItem(item.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Shopping item deleted.',
          sk: 'Nákupná položka bola zmazaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to delete shopping item.',
          sk: 'Nákupnú položku sa nepodarilo zmazať.',
        ),
      );
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
        value
            ? context.tr(en: 'Marked as bought.', sk: 'Označené ako kúpené.')
            : context.tr(
                en: 'Marked as not bought.',
                sk: 'Označené ako nekúpené.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update shopping item.',
          sk: 'Nákupnú položku sa nepodarilo upraviť.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Shopping List', sk: 'Nákupný zoznam')),
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
            tooltip: context.tr(en: 'Household', sk: 'Domácnosť'),
          ),
          IconButton(
            onPressed: widget.authRepository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: context.tr(en: 'Sign out', sk: 'Odhlásiť sa'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: Text(context.tr(en: 'Add item', sk: 'Pridať položku')),
      ),
      body: FutureBuilder<_ShoppingListViewData>(
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

          final viewData =
              snapshot.data ??
              const _ShoppingListViewData(
                items: <ShoppingListItem>[],
                preferences: null,
              );
          final items = viewData.items;
          final preferences = viewData.preferences;
          if (items.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No shopping list items yet.',
                sk: 'Zatiaľ tu nemáš žiadne nákupné položky.',
              ),
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
                    message: context.tr(
                      en: 'No shopping items match your search.',
                      sk: 'Tvojmu hľadaniu nezodpovedajú žiadne nákupné položky.',
                    ),
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
                    onTap: () => _showItemActions(item),
                    leading: Checkbox(
                      value: item.isBought,
                      onChanged: (value) {
                        if (value == null) return;
                        _toggleBought(item, value);
                      },
                    ),
                    title: Text(
                      localizedIngredientDisplayName(context, item.name),
                      style: TextStyle(
                        decoration: item.isBought
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_buildSubtitle(item)),
                        ...switch (_buildFoodSafetyWarning(item, preferences)) {
                          final _FoodSafetyWarning warning => [
                            const SizedBox(height: 6),
                            _ShoppingSafetyBadge(warning: warning),
                          ],
                          null => const [],
                        },
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'add_more') {
                          _openAddMoreForm(item);
                        } else if (value == 'edit') {
                          _openEditForm(item);
                        } else if (value == 'delete') {
                          _deleteItem(item);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'add_more',
                          child: Text(
                            context.tr(en: 'Add more', sk: 'Pridať viac'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(context.tr(en: 'Edit', sk: 'Upraviť')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.tr(en: 'Delete', sk: 'Zmazať')),
                        ),
                      ],
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
    return '${name.trim().toLowerCase()}|${_unitMergeKey(unit)}';
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
    return context.tr(
      en: 'Failed to load shopping list items.',
      sk: 'Nákupný zoznam sa nepodarilo načítať.',
    );
  }

  String _sourceLabel(String value) {
    return switch (value) {
      ShoppingListItem.sourceRecipeMissing => context.tr(
        en: 'Recipe',
        sk: 'Recept',
      ),
      ShoppingListItem.sourceLowStock => context.tr(
        en: 'Low stock',
        sk: 'Málo zásob',
      ),
      ShoppingListItem.sourceMultiple => context.tr(
        en: 'Multiple',
        sk: 'Viac zdrojov',
      ),
      _ => context.tr(en: 'Manual', sk: 'Ručne'),
    };
  }

  Future<UserPreferences?> _loadCurrentPreferencesSafely() async {
    try {
      return await _userPreferencesRepository.getCurrentUserPreferences();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _confirmProceedWithSafetyWarning(
    ShoppingListItem item, {
    required String actionLabel,
    required UserPreferences? preferences,
  }) async {
    final effectivePreferences =
        preferences ?? await _loadCurrentPreferencesSafely();
    final warning = _buildFoodSafetyWarning(item, effectivePreferences);
    if (warning == null || !mounted) {
      return true;
    }

    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );
    final suggestions = _suggestSafeAlternatives(item, warning);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                  en: 'This item may conflict with your preferences because it contains ${warning.matchedSignals.join(', ')}.\n\nDo you still want to $actionLabel?',
                  sk: 'Táto položka môže kolidovať s tvojimi preferenciami, pretože obsahuje ${warning.matchedSignals.join(', ')}.\n\nNapriek tomu chceš pokračovať?',
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.tr(
                    en: 'Safer alternatives:',
                    sk: 'Bezpečnejšie alternatívy:',
                  ),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...suggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $suggestion'),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Continue', sk: 'Pokračovať')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  _FoodSafetyWarning? _buildFoodSafetyWarning(
    ShoppingListItem item,
    UserPreferences? preferences,
  ) {
    if (preferences == null) {
      return null;
    }

    final candidateSignals = _foodSignalSet(item.name);
    final allergyMatches = _matchPreferenceSignals(
      preferenceEntries: preferences.allergies,
      candidateSignals: candidateSignals,
    );
    if (allergyMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.allergy,
        matchedSignals: allergyMatches,
      );
    }

    final intoleranceMatches = _matchPreferenceSignals(
      preferenceEntries: preferences.intolerances,
      candidateSignals: candidateSignals,
    );
    if (intoleranceMatches.isNotEmpty) {
      return _FoodSafetyWarning(
        type: _FoodSafetyWarningType.intolerance,
        matchedSignals: intoleranceMatches,
      );
    }

    return null;
  }

  Set<String> _foodSignalSet(String value) {
    final normalized = _normalizeValue(value);
    final signals = <String>{normalized, _canonicalFoodSignal(normalized)};

    if (normalized.contains('milk') ||
        normalized.contains('mlieko') ||
        normalized.contains('cheese') ||
        normalized.contains('syr')) {
      signals.add('dairy');
      signals.add('lactose');
    }
    if (normalized.contains('egg') || normalized.contains('vajc')) {
      signals.add('eggs');
    }
    if (normalized.contains('pasta') ||
        normalized.contains('cestovin') ||
        normalized.contains('bread') ||
        normalized.contains('chlieb') ||
        normalized.contains('peciv')) {
      signals.add('gluten');
    }

    return signals
        .map(_canonicalFoodSignal)
        .where((signal) => signal.isNotEmpty)
        .toSet();
  }

  List<String> _matchPreferenceSignals({
    required List<String> preferenceEntries,
    required Set<String> candidateSignals,
  }) {
    final matches = <String>{};
    for (final entry in preferenceEntries) {
      final signal = _canonicalFoodSignal(_normalizeValue(entry));
      if (signal.isEmpty) {
        continue;
      }
      if (candidateSignals.contains(signal)) {
        matches.add(signal);
      }
    }
    return matches.toList()..sort();
  }

  String _normalizeValue(String value) {
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

  String _canonicalFoodSignal(String value) {
    switch (value) {
      case 'lactose':
      case 'dairy':
      case 'milk':
      case 'cheese':
      case 'mlieko':
      case 'syr':
        return 'lactose';
      case 'gluten':
      case 'wheat':
      case 'pasta':
      case 'bread':
      case 'cestoviny':
      case 'chlieb':
      case 'pecivo':
        return 'gluten';
      case 'egg':
      case 'eggs':
      case 'vajce':
      case 'vajcia':
        return 'eggs';
      case 'peanut':
      case 'peanuts':
      case 'arasidy':
        return 'peanuts';
      case 'nuts':
      case 'nut':
      case 'almond':
      case 'walnut':
      case 'hazelnut':
      case 'mandla':
      case 'orech':
      case 'orechy':
        return 'tree_nuts';
      case 'soy':
      case 'soya':
      case 'sój':
      case 'soj':
        return 'soy';
      case 'fish':
      case 'ryba':
        return 'fish';
      case 'shellfish':
      case 'shrimp':
      case 'prawn':
      case 'kreveta':
        return 'shellfish';
      case 'sesame':
      case 'sezam':
        return 'sesame';
      default:
        return value;
    }
  }

  String _unitMergeKey(String unit) {
    final normalized = unit.trim().toLowerCase();
    switch (normalized) {
      case 'l':
      case 'liter':
      case 'litre':
      case 'liters':
      case 'litres':
      case 'litrov':
      case 'ml':
      case 'milliliter':
      case 'millilitre':
      case 'milliliters':
      case 'millilitres':
        return 'volume';
      case 'kg':
      case 'kilogram':
      case 'kilograms':
      case 'kilogramy':
      case 'kilogramov':
      case 'g':
      case 'gram':
      case 'grams':
      case 'gramy':
      case 'gramov':
        return 'mass';
      case 'pcs':
      case 'pc':
      case 'piece':
      case 'pieces':
      case 'ks':
      case 'kus':
      case 'kusy':
        return 'count';
      default:
        return normalized;
    }
  }

  double? _convertQuantity({
    required double quantity,
    required String fromUnit,
    required String toUnit,
  }) {
    final from = fromUnit.trim().toLowerCase();
    final to = toUnit.trim().toLowerCase();
    if (from == to) {
      return quantity;
    }

    const toBaseFactor = <String, double>{
      'kg': 1000,
      'kilogram': 1000,
      'kilograms': 1000,
      'kilogramy': 1000,
      'kilogramov': 1000,
      'g': 1,
      'gram': 1,
      'grams': 1,
      'gramy': 1,
      'gramov': 1,
      'l': 1000,
      'liter': 1000,
      'litre': 1000,
      'liters': 1000,
      'litres': 1000,
      'litrov': 1000,
      'ml': 1,
      'milliliter': 1,
      'millilitre': 1,
      'milliliters': 1,
      'millilitres': 1,
      'pcs': 1,
      'pc': 1,
      'piece': 1,
      'pieces': 1,
      'ks': 1,
      'kus': 1,
      'kusy': 1,
    };

    final fromGroup = _unitMergeKey(from);
    final toGroup = _unitMergeKey(to);
    if (fromGroup != toGroup) {
      return null;
    }

    final fromFactor = toBaseFactor[from];
    final toFactor = toBaseFactor[to];
    if (fromFactor == null || toFactor == null) {
      return null;
    }

    final baseQuantity = quantity * fromFactor;
    return baseQuantity / toFactor;
  }

  List<String> _suggestSafeAlternatives(
    ShoppingListItem item,
    _FoodSafetyWarning warning,
  ) {
    final normalizedName = _normalizeValue(item.name);
    final suggestions = <String>{};

    for (final signal in warning.matchedSignals) {
      switch (signal) {
        case 'lactose':
          suggestions.add('a lactose-free alternative');
          if (normalizedName.contains('milk') ||
              normalizedName.contains('mlieko')) {
            suggestions.add('lactose-free milk');
            suggestions.add('oat milk');
          } else if (normalizedName.contains('cheese') ||
              normalizedName.contains('syr') ||
              normalizedName.contains('gorgonzola') ||
              normalizedName.contains('mozzarella')) {
            suggestions.add('lactose-free cheese');
            suggestions.add('plant-based cheese');
          } else if (normalizedName.contains('yogurt') ||
              normalizedName.contains('jogurt')) {
            suggestions.add('lactose-free yogurt');
            suggestions.add('coconut yogurt');
          }
          break;
        case 'gluten':
          suggestions.add('a gluten-free alternative');
          if (normalizedName.contains('pasta') ||
              normalizedName.contains('cestovin')) {
            suggestions.add('gluten-free pasta');
          } else if (normalizedName.contains('bread') ||
              normalizedName.contains('chlieb') ||
              normalizedName.contains('peciv')) {
            suggestions.add('gluten-free bread');
          } else if (normalizedName.contains('flour') ||
              normalizedName.contains('muka')) {
            suggestions.add('gluten-free flour');
          }
          break;
        case 'eggs':
          suggestions.add('an egg substitute');
          suggestions.add('chia or flax replacement');
          break;
        case 'peanuts':
          suggestions.add('sunflower seed butter');
          break;
        case 'tree_nuts':
          suggestions.add('seed-based alternative');
          break;
        case 'soy':
          suggestions.add('oat-based alternative');
          suggestions.add('coconut-based alternative');
          break;
        case 'fish':
        case 'shellfish':
          suggestions.add('a non-seafood alternative');
          break;
        case 'sesame':
          suggestions.add('a sesame-free alternative');
          break;
      }
    }

    return suggestions.toList();
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
          decoration: InputDecoration(
            hintText: context.tr(
              en: 'Search shopping items',
              sk: 'Hľadať nákupné položky',
            ),
            prefixIcon: const Icon(Icons.search_rounded),
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
                label: Text(context.tr(en: 'All', sk: 'Všetko')),
                selected: selectedFilter == ShoppingListFilter.all,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.all),
              ),
              FilterChip(
                label: Text(context.tr(en: 'To buy', sk: 'Kúpiť')),
                selected: selectedFilter == ShoppingListFilter.toBuy,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.toBuy),
              ),
              FilterChip(
                label: Text(context.tr(en: 'Bought', sk: 'Kúpené')),
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

class _ShoppingSafetyBadge extends StatelessWidget {
  const _ShoppingSafetyBadge({required this.warning});

  final _FoodSafetyWarning warning;

  @override
  Widget build(BuildContext context) {
    final isAllergy = warning.type == _FoodSafetyWarningType.allergy;
    final backgroundColor = isAllergy
        ? const Color(0xFFFDE7E9)
        : const Color(0xFFFFF3D9);
    final foregroundColor = isAllergy
        ? const Color(0xFF9F1D2C)
        : const Color(0xFF8A5A00);
    final title = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$title: ${context.tr(en: 'contains', sk: 'obsahuje')} ${warning.matchedSignals.join(', ')}.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShoppingListViewData {
  final List<ShoppingListItem> items;
  final UserPreferences? preferences;

  const _ShoppingListViewData({required this.items, required this.preferences});
}

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matchedSignals;

  const _FoodSafetyWarning({required this.type, required this.matchedSignals});
}
