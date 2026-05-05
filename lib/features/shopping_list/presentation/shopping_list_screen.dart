import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/sign_out_action.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../household_activity/data/household_activity_repository.dart';
import '../../household_activity/domain/household_activity_event.dart';
import '../../households/domain/household.dart';
import '../../households/domain/household_member.dart';
import '../../households/data/household_repository.dart';
import '../../households/presentation/household_screen.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/shopping_list_remote_data_source.dart';
import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_item.dart';
import 'shopping_list_form_screen.dart';

enum ShoppingListFilter { all, toBuy, assignedToMe, bought }

class ShoppingListScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final Household household;
  final int refreshToken;
  final VoidCallback onShoppingListChanged;

  const ShoppingListScreen({
    super.key,
    required this.authRepository,
    required this.household,
    required this.refreshToken,
    required this.onShoppingListChanged,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late final ShoppingListRepository repository = ShoppingListRepository(
    householdId: widget.household.id,
  );
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final HouseholdActivityRepository _activityRepository =
      HouseholdActivityRepository(householdId: widget.household.id);
  late final HouseholdRepository _householdRepository = HouseholdRepository();
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<_ShoppingListViewData> _shoppingListFuture;
  ShoppingListFilter _selectedFilter = ShoppingListFilter.all;

  String? get _currentUserId => widget.authRepository.currentSession?.user.id;

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

  Future<void> _handleSignOut() async {
    await confirmAndSignOut(context, widget.authRepository);
  }

  Future<_ShoppingListViewData> _loadShoppingListItems() async {
    var items = await repository.getShoppingListItems();
    List<HouseholdMember> members = const <HouseholdMember>[];
    UserPreferences? preferences;

    try {
      preferences = await _userPreferencesRepository
          .getCurrentUserPreferences();
    } catch (_) {
      preferences = null;
    }

    try {
      members = await _householdRepository.getMembers(widget.household.id);
    } catch (_) {
      members = const <HouseholdMember>[];
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
      var assignedToUserId = primary.assignedToUserId;

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
        assignedToUserId ??= duplicate.assignedToUserId;
      }

      final updatedPrimary = primary.copyWith(
        name: _preferredMergedItemName(primary.name, group.last.name),
        quantity: mergedQuantity,
        source: mergedSource,
        assignedToUserId: assignedToUserId,
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

    return _ShoppingListViewData(
      items: items,
      preferences: preferences,
      members: members,
    );
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
    if (!mounted) {
      return;
    }

    final safeItem = await _confirmProceedWithSafetyWarning(
      createdItem,
      actionLabel: context.tr(
        en: 'add this item to your shopping list',
        sk: 'pridať túto položku do nákupného zoznamu',
      ),
      preferences: null,
    );
    if (safeItem == null) {
      return;
    }

    try {
      final existingItems = await repository.getShoppingListItems();
      final result = await _saveShoppingItemWithDuplicateHandling(
        safeItem,
        existingItems: existingItems,
      );
      _logActivity(
        eventType: result.wasMerged ? 'shopping_increased' : 'shopping_added',
        itemName: result.item.name,
        quantity: safeItem.quantity,
        unit: safeItem.unit,
      );
      await _reload();
      if (!mounted) return;
      if (result.wasMerged) {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Added to existing ${result.item.name} (+${_formatQuantity(safeItem.quantity)} ${safeItem.unit}). Total: ${_formatQuantity(result.item.quantity)} ${result.item.unit}.',
            sk: 'Pridané k existujúcej položke ${result.item.name} (+${_formatQuantity(safeItem.quantity)} ${safeItem.unit}). Spolu: ${_formatQuantity(result.item.quantity)} ${result.item.unit}.',
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
        name: _preferredMergedItemName(existing.name, incomingItem.name),
        quantity: mergedQuantity,
        assignedToUserId:
            existing.assignedToUserId ?? incomingItem.assignedToUserId,
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
    if (!mounted) {
      return;
    }

    final safeItem = await _confirmProceedWithSafetyWarning(
      updatedItem,
      actionLabel: context.tr(
        en: 'save this shopping item',
        sk: 'uložiť túto nákupnú položku',
      ),
      preferences: null,
    );
    if (safeItem == null) {
      return;
    }

    try {
      await repository.editShoppingListItem(safeItem);
      _logActivity(
        eventType: 'shopping_updated',
        itemName: safeItem.name,
        quantity: safeItem.quantity,
        unit: safeItem.unit,
      );
      await _reload();
      widget.onShoppingListChanged();
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
    if (!mounted) {
      return;
    }

    final safeItem = await _confirmProceedWithSafetyWarning(
      additionalItem,
      actionLabel: context.tr(
        en: 'add this item to your shopping list',
        sk: 'pridať túto položku do nákupného zoznamu',
      ),
      preferences: null,
    );
    if (safeItem == null) {
      return;
    }

    final additionalQuantity = _convertQuantity(
      quantity: safeItem.quantity,
      fromUnit: safeItem.unit,
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
      _logActivity(
        eventType: 'shopping_increased',
        itemName: updatedItem.name,
        quantity: additionalItem.quantity,
        unit: additionalItem.unit,
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
              leading: const Icon(Icons.group_add_outlined),
              title: Text(
                context.tr(
                  en: 'Assign to household member',
                  sk: 'Priradiť členovi domácnosti',
                ),
              ),
              subtitle: Text(
                context.tr(
                  en: 'Choose who plans to buy this item',
                  sk: 'Vyber, kto plánuje kúpiť túto položku',
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _pickAssignmentTarget(item);
              },
            ),
            if (item.assignedToUserId != null)
              ListTile(
                leading: const Icon(Icons.person_remove_outlined),
                title: Text(
                  context.tr(en: 'Clear assignment', sk: 'Zrušiť priradenie'),
                ),
                subtitle: Text(
                  context.tr(
                    en: 'Anyone in the household can take it again',
                    sk: 'Položku si môže znova vziať ktokoľvek v domácnosti',
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _setAssignment(item, null);
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

  Future<void> _pickAssignmentTarget(ShoppingListItem item) async {
    try {
      final members = await _householdRepository.getMembers(
        widget.household.id,
      );
      if (!mounted) return;

      final selectedUserId = await showDialog<String?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.tr(
              en: 'Assign shopping item',
              sk: 'Priradiť nákupnú položku',
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: members
                    .map(
                      (member) => ListTile(
                        leading: Icon(
                          member.userId == _currentUserId
                              ? Icons.person
                              : Icons.group_outlined,
                        ),
                        title: Text(_memberLabel(member)),
                        subtitle: Text(_memberSubtitle(member)),
                        trailing: item.assignedToUserId == member.userId
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(member.userId),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
            ),
          ],
        ),
      );

      if (selectedUserId == null) {
        return;
      }
      await _setAssignment(item, selectedUserId);
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to load household members.',
          sk: 'Nepodarilo sa načítať členov domácnosti.',
        ),
      );
    }
  }

  Future<void> _setAssignment(
    ShoppingListItem item,
    String? assignedToUserId,
  ) async {
    if (_currentUserId == null && assignedToUserId != null) {
      return;
    }

    try {
      final assignmentDetails = assignedToUserId == null
          ? context.tr(en: 'Assignment cleared', sk: 'Priradenie zrušené')
          : assignedToUserId == _currentUserId
          ? context.tr(en: 'Assigned to me', sk: 'Priradené mne')
          : context.tr(
              en: 'Assigned to another household member',
              sk: 'Priradené inému členovi domácnosti',
            );
      await repository.editShoppingListItem(
        item.copyWith(
          assignedToUserId: assignedToUserId,
          clearAssignedToUserId: assignedToUserId == null,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      _logActivity(
        eventType: assignedToUserId == null
            ? 'shopping_unassigned'
            : 'shopping_assigned',
        itemName: item.name,
        quantity: item.quantity,
        unit: item.unit,
        details: assignmentDetails,
      );
      widget.onShoppingListChanged();
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        assignedToUserId == null
            ? context.tr(
                en: 'Shopping item is no longer assigned.',
                sk: 'Nákupná položka už nie je nikomu priradená.',
              )
            : assignedToUserId == _currentUserId
            ? context.tr(
                en: 'Shopping item assigned to you.',
                sk: 'Nákupná položka je priradená tebe.',
              )
            : context.tr(
                en: 'Shopping item assigned in household.',
                sk: 'Nákupná položka je priradená v domácnosti.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update assignment.',
          sk: 'Priradenie sa nepodarilo upraviť.',
        ),
      );
    }
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
      _logActivity(
        eventType: 'shopping_deleted',
        itemName: item.name,
        quantity: item.quantity,
        unit: item.unit,
      );
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
      if (value) {
        final pantryDetails = await _confirmBoughtPantryDetails(item);
        if (pantryDetails == null) {
          return;
        }
        await _addBoughtItemToPantry(
          item,
          storageLocation: pantryDetails.storageLocation,
          expirationDate: pantryDetails.expirationDate,
        );
        await repository.removeShoppingListItem(item.id);
      } else {
        await repository.editShoppingListItem(
          item.copyWith(isBought: value, updatedAt: DateTime.now().toUtc()),
        );
      }
      _logActivity(
        eventType: value ? 'shopping_bought' : 'shopping_unbought',
        itemName: item.name,
        quantity: item.quantity,
        unit: item.unit,
      );
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        value
            ? context.tr(
                en: 'Moved to pantry and removed from shopping list.',
                sk: 'Presunuté do špajze a odstránené z nákupného zoznamu.',
              )
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

  Future<({String storageLocation, DateTime? expirationDate})?>
  _confirmBoughtPantryDetails(ShoppingListItem item) async {
    var selectedStorage = _defaultPantryStorage(
      deriveFoodSignalInfo(item.name).itemKey,
    );
    DateTime? expirationDate;

    return showDialog<({String storageLocation, DateTime? expirationDate})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(
              en: 'Move bought item to pantry',
              sk: 'Presunúť kúpenú položku do špajze',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  en: 'Choose where to store ${localizedIngredientDisplayName(context, item.name)}.',
                  sk: 'Vyber, kam uložiť ${localizedIngredientDisplayName(context, item.name)}.',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStorage,
                decoration: InputDecoration(
                  labelText: context.tr(
                    en: 'Storage location',
                    sk: 'Umiestnenie',
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'fridge',
                    child: Text(context.tr(en: 'Fridge', sk: 'Chladnička')),
                  ),
                  DropdownMenuItem(
                    value: 'freezer',
                    child: Text(context.tr(en: 'Freezer', sk: 'Mraznička')),
                  ),
                  DropdownMenuItem(
                    value: 'pantry',
                    child: Text(context.tr(en: 'Pantry', sk: 'Špajza')),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setDialogState(() {
                    selectedStorage = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: expirationDate ?? now,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked == null) {
                    return;
                  }
                  setDialogState(() {
                    expirationDate = picked;
                  });
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr(
                      en: 'Expiration date',
                      sk: 'Dátum spotreby',
                    ),
                  ),
                  child: Text(
                    expirationDate == null
                        ? context.tr(en: 'Optional', sk: 'Voliteľné')
                        : _formatDate(expirationDate!),
                  ),
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
              onPressed: () => Navigator.of(context).pop((
                storageLocation: selectedStorage,
                expirationDate: expirationDate,
              )),
              child: Text(context.tr(en: 'Move', sk: 'Presunúť')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBoughtItemToPantry(
    ShoppingListItem item, {
    required String storageLocation,
    required DateTime? expirationDate,
  }) async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final matching = pantryItems.cast<FoodItem?>().firstWhere(
      (candidate) =>
          candidate != null &&
          candidate.openedAt == null &&
          _itemKey(candidate.name, candidate.unit) ==
              _itemKey(item.name, item.unit),
      orElse: () => null,
    );
    final now = DateTime.now().toUtc();

    if (matching == null) {
      final info = deriveFoodSignalInfo(item.name);
      await _foodItemsRepository.addFoodItem(
        FoodItem(
          id: '',
          userId: item.userId,
          householdId: item.householdId,
          name: item.name,
          barcode: null,
          category: _defaultPantryCategory(info.itemKey),
          storageLocation: storageLocation,
          quantity: item.quantity,
          lowStockThreshold: null,
          unit: item.unit,
          expirationDate: expirationDate,
          openedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }

    final incomingInExistingUnit = _convertQuantity(
      quantity: item.quantity,
      fromUnit: item.unit,
      toUnit: matching.unit,
    );
    if (incomingInExistingUnit == null) {
      return;
    }

    await _foodItemsRepository.editFoodItem(
      matching.copyWith(
        name: _preferredPantryBoughtName(matching.name, item.name),
        quantity: matching.quantity + incomingInExistingUnit,
        storageLocation: storageLocation,
        expirationDate: expirationDate ?? matching.expirationDate,
        updatedAt: now,
      ),
    );
  }

  String _defaultPantryStorage(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'cheese':
      case 'eggs':
      case 'yogurt':
      case 'butter':
      case 'cream':
      case 'ham':
        return 'fridge';
      case 'peas':
        return 'freezer';
      default:
        return 'pantry';
    }
  }

  String _defaultPantryCategory(String itemKey) {
    switch (itemKey) {
      case 'milk':
      case 'cheese':
      case 'yogurt':
      case 'butter':
      case 'cream':
        return 'dairy';
      case 'eggs':
        return 'dairy';
      case 'ham':
      case 'chicken':
        return 'meat';
      case 'peas':
        return 'frozen';
      case 'bread':
      case 'pasta':
      case 'rice':
      case 'beans':
        return 'grains';
      case 'tomato':
        return 'produce';
      default:
        return 'other';
    }
  }

  String _preferredPantryBoughtName(String existingName, String incomingName) {
    final existingNormalized = _normalizeValue(existingName);
    final incomingNormalized = _normalizeValue(incomingName);

    const genericEnglishAliases = {
      'ham',
      'bread',
      'milk',
      'cheese',
      'eggs',
      'pasta',
      'rice',
      'beans',
      'peas',
      'yogurt',
      'cream',
      'butter',
    };

    if (genericEnglishAliases.contains(existingNormalized) &&
        !genericEnglishAliases.contains(incomingNormalized)) {
      return incomingName;
    }

    return existingName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            final error = snapshot.error;
            return AppErrorState(
              kind:
                  error is ShoppingListConfigException ||
                      error is ShoppingListAuthException
                  ? AppErrorKind.setup
                  : inferAppErrorKind(error, fallback: AppErrorKind.sync),
              title:
                  error is ShoppingListConfigException ||
                      error is ShoppingListAuthException
                  ? context.tr(
                      en: 'Shopping list needs setup',
                      sk: 'Nákupný zoznam potrebuje nastavenie',
                    )
                  : context.tr(
                      en: 'Shopping list is unavailable',
                      sk: 'Nákupný zoznam nie je k dispozícii',
                    ),
              message: _errorMessage(error),
              hint:
                  error is ShoppingListConfigException ||
                      error is ShoppingListAuthException
                  ? context.tr(
                      en: 'Safo needs account or backend setup before shopping data can load.',
                      sk: 'Safo potrebuje účet alebo backend nastavenie, aby sa načítali nákupné dáta.',
                    )
                  : context.tr(
                      en: 'Safo could not load the latest shopping items right now.',
                      sk: 'Safo teraz nedokázalo načítať najnovšie nákupné položky.',
                    ),
              onRetry: _reload,
            );
          }

          final viewData =
              snapshot.data ??
              const _ShoppingListViewData(
                items: <ShoppingListItem>[],
                preferences: null,
                members: <HouseholdMember>[],
              );
          final items = viewData.items;
          final preferences = viewData.preferences;
          final members = viewData.members;
          final filteredItems = _applyFilters(items);
          if (filteredItems.isEmpty) {
            return SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  children: [
                    _ShoppingListHeader(
                      householdName: widget.household.name,
                      onOpenHousehold: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                HouseholdScreen(household: widget.household),
                          ),
                        );
                      },
                      onSignOut: () => _handleSignOut(),
                    ),
                    const SizedBox(height: 18),
                    _ShoppingSummary(
                      totalItems: items.length,
                      toBuyCount: items.where((item) => !item.isBought).length,
                      assignedToMeCount: items
                          .where(
                            (item) =>
                                !item.isBought &&
                                item.assignedToUserId == _currentUserId,
                          )
                          .length,
                    ),
                    const SizedBox(height: 12),
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
                    AppEmptyCard(
                      message: context.tr(
                        en: items.isEmpty
                            ? 'Add your first shopping item and Safo will help you keep the list in sync.'
                            : 'No shopping items match your search.',
                        sk: items.isEmpty
                            ? 'Pridaj prvú nákupnú položku a Safo ti pomôže držať zoznam zosynchronizovaný.'
                            : 'Tvojmu hľadaniu nezodpovedajú žiadne nákupné položky.',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              itemCount: filteredItems.length + 3,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ShoppingListHeader(
                    householdName: widget.household.name,
                    onOpenHousehold: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HouseholdScreen(household: widget.household),
                        ),
                      );
                    },
                    onSignOut: () => _handleSignOut(),
                  );
                }

                if (index == 1) {
                  return _ShoppingSummary(
                    totalItems: items.length,
                    toBuyCount: items.where((item) => !item.isBought).length,
                    assignedToMeCount: items
                        .where(
                          (item) =>
                              !item.isBought &&
                              item.assignedToUserId == _currentUserId,
                        )
                        .length,
                  );
                }

                if (index == 2) {
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

                final item = filteredItems[index - 3];
                return _ShoppingItemCard(
                  item: item,
                  title: localizedIngredientDisplayName(context, item.name),
                  subtitle: _buildSubtitle(item, members),
                  assignmentLabel: item.assignedToUserId == null
                      ? null
                      : item.assignedToUserId == _currentUserId
                      ? context.tr(en: 'For me', sk: 'Pre mňa')
                      : _assignedSubtitle(item.assignedToUserId!, members),
                  quantityLabel:
                      '${_formatQuantity(item.quantity)} ${item.unit}',
                  warning: _buildFoodSafetyWarning(item, preferences),
                  onTap: () => _showItemActions(item),
                  onMore: () => _showItemActions(item),
                  onToggleBought: (value) => _toggleBought(item, value),
                );
              },
            ),
          ),
          );
        },
      ),
    );
  }

  String _buildSubtitle(ShoppingListItem item, List<HouseholdMember> members) {
    return _sourceLabel(item.source);
  }

  String _assignedSubtitle(
    String assignedToUserId,
    List<HouseholdMember> members,
  ) {
    final member = members.cast<HouseholdMember?>().firstWhere(
      (member) => member?.userId == assignedToUserId,
      orElse: () => null,
    );
    if (member == null) {
      return context.tr(
        en: 'Assigned in household',
        sk: 'Priradené v domácnosti',
      );
    }
    return context.tr(
      en: 'Assigned to ${_memberLabel(member)}',
      sk: 'Priradené: ${_memberLabel(member)}',
    );
  }

  String _memberLabel(HouseholdMember member) {
    if (member.userId == _currentUserId) {
      return context.tr(en: 'You', sk: 'Ty');
    }
    return member.role == 'owner'
        ? context.tr(en: 'Owner', sk: 'Vlastník')
        : context.tr(en: 'Member', sk: 'Člen');
  }

  String _memberSubtitle(HouseholdMember member) {
    final shortId = member.userId.length <= 8
        ? member.userId
        : '${member.userId.substring(0, 8)}...';
    return shortId;
  }

  Future<void> _logActivity({
    required String eventType,
    required String itemName,
    double? quantity,
    String? unit,
    String? details,
  }) async {
    final userId = widget.authRepository.currentSession?.user.id;
    if (userId == null) {
      return;
    }

    try {
      await _activityRepository.addEvent(
        HouseholdActivityEvent(
          id: '',
          householdId: widget.household.id,
          userId: userId,
          eventType: eventType,
          itemName: itemName,
          quantity: quantity,
          unit: unit,
          details: details,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {}
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
        ShoppingListFilter.assignedToMe =>
          !item.isBought && item.assignedToUserId == _currentUserId,
        ShoppingListFilter.bought => item.isBought,
      };
    }).toList();
  }

  String _itemKey(String name, String unit) {
    return '${_canonicalShoppingItemKey(name)}|${_unitMergeKey(unit)}';
  }

  String _canonicalShoppingItemKey(String value) {
    return deriveFoodSignalInfo(value).itemKey;
  }

  String _preferredMergedItemName(String existingName, String incomingName) {
    final existingNormalized = _normalizeValue(existingName);
    final incomingNormalized = _normalizeValue(incomingName);
    if ((incomingNormalized.contains('bezlakt') &&
            !existingNormalized.contains('bezlakt')) ||
        (incomingNormalized.contains('bezlepk') &&
            !existingNormalized.contains('bezlepk')) ||
        (incomingNormalized.contains('nahradavajec') &&
            !existingNormalized.contains('nahradavajec')) ||
        (incomingNormalized.contains('bezvajec') &&
            !existingNormalized.contains('bezvajec'))) {
      return incomingName;
    }
    return existingName;
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
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

  Future<ShoppingListItem?> _confirmProceedWithSafetyWarning(
    ShoppingListItem item, {
    required String actionLabel,
    required UserPreferences? preferences,
  }) async {
    final effectivePreferences =
        preferences ?? await _loadCurrentPreferencesSafely();
    final warning = _buildFoodSafetyWarning(item, effectivePreferences);
    if (warning == null || !mounted) {
      return item;
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

    if (confirmed != true) {
      return null;
    }

    return _applySaferAlternativeToItem(item, warning) ?? item;
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
    return deriveFoodSignalInfo(value).signals;
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
    return normalizeFoodValue(value);
  }

  String _canonicalFoodSignal(String value) {
    return canonicalFoodSignal(value);
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

  ShoppingListItem? _applySaferAlternativeToItem(
    ShoppingListItem item,
    _FoodSafetyWarning warning,
  ) {
    final normalizedName = _normalizeValue(item.name);

    for (final signal in warning.matchedSignals) {
      switch (signal) {
        case 'lactose':
          if (normalizedName.contains('milk') ||
              normalizedName.contains('mlieko')) {
            return item.copyWith(name: 'Bezlaktózové mlieko');
          }
          if (normalizedName.contains('cheese') ||
              normalizedName.contains('syr') ||
              normalizedName.contains('gorgonzola') ||
              normalizedName.contains('mozzarella')) {
            return item.copyWith(name: 'Bezlaktózový syr');
          }
          if (normalizedName.contains('yogurt') ||
              normalizedName.contains('jogurt')) {
            return item.copyWith(name: 'Bezlaktózový jogurt');
          }
          if (normalizedName.contains('cream') ||
              normalizedName.contains('smot')) {
            return item.copyWith(name: 'Bezlaktózová smotana');
          }
          if (normalizedName.contains('butter') ||
              normalizedName.contains('maslo')) {
            return item.copyWith(name: 'Bezlaktózové maslo');
          }
          return item.copyWith(name: 'Bezlaktózová alternatíva');
        case 'gluten':
          if (normalizedName.contains('pasta') ||
              normalizedName.contains('cestovin')) {
            return item.copyWith(name: 'Bezlepkové cestoviny');
          }
          if (normalizedName.contains('baget')) {
            return item.copyWith(name: 'Bezlepková bageta');
          }
          if (normalizedName.contains('bread') ||
              normalizedName.contains('chlieb') ||
              normalizedName.contains('peciv')) {
            return item.copyWith(name: 'Bezlepkový chlieb');
          }
          if (normalizedName.contains('flour') ||
              normalizedName.contains('muka')) {
            return item.copyWith(name: 'Bezlepková múka');
          }
          return item.copyWith(name: 'Bezlepková alternatíva');
        case 'eggs':
          if (normalizedName.contains('egg') ||
              normalizedName.contains('vajc')) {
            return item.copyWith(name: 'Náhrada vajec');
          }
          return item.copyWith(name: 'Bezvaječná alternatíva');
      }
    }

    return null;
  }
}

class _ShoppingSaveResult {
  final ShoppingListItem item;
  final bool wasMerged;

  const _ShoppingSaveResult({required this.item, required this.wasMerged});
}

class _ShoppingListHeader extends StatelessWidget {
  final String householdName;
  final VoidCallback onOpenHousehold;
  final VoidCallback onSignOut;

  const _ShoppingListHeader({
    required this.householdName,
    required this.onOpenHousehold,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SafoLogo(
              variant: SafoLogoVariant.iconTransparent,
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            const SafoLogo(
              variant: SafoLogoVariant.pill,
              height: 28,
            ),
            const Spacer(),
            _ShoppingHeaderIconButton(
              icon: Icons.groups_2_outlined,
              onTap: onOpenHousehold,
            ),
            const SizedBox(width: 8),
            _ShoppingHeaderIconButton(
              icon: Icons.logout_rounded,
              onTap: onSignOut,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          context.tr(en: 'What should we buy next?', sk: 'Čo treba kúpiť?'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SafoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(en: 'Shopping', sk: 'Nákup'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 2),
        Text(
          householdName,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SafoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ShoppingHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ShoppingHeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SafoColors.surface,
      borderRadius: BorderRadius.circular(SafoRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(SafoRadii.pill),
            border: Border.all(color: SafoColors.border),
          ),
          child: Icon(icon, color: SafoColors.textPrimary),
        ),
      ),
    );
  }
}

class _ShoppingSummary extends StatelessWidget {
  final int totalItems;
  final int toBuyCount;
  final int assignedToMeCount;

  const _ShoppingSummary({
    required this.totalItems,
    required this.toBuyCount,
    required this.assignedToMeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.92,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ShoppingSummaryCard(
          label: context.tr(en: 'Total', sk: 'Spolu'),
          value: totalItems.toString(),
          background: SafoColors.surface,
          valueColor: SafoColors.textPrimary,
        ),
        _ShoppingSummaryCard(
          label: context.tr(en: 'To buy', sk: 'Kúpiť'),
          value: toBuyCount.toString(),
          background: SafoColors.primarySoft,
          valueColor: SafoColors.primary,
        ),
        _ShoppingSummaryCard(
          label: context.tr(en: 'For me', sk: 'Pre mňa'),
          value: assignedToMeCount.toString(),
          background: SafoColors.accentSoft,
          valueColor: SafoColors.accent,
        ),
      ],
    );
  }
}

class _ShoppingSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color valueColor;

  const _ShoppingSummaryCard({
    required this.label,
    required this.value,
    required this.background,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SafoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: context.tr(
              en: 'Search shopping items',
              sk: 'Hľadať nákupné položky',
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: SafoColors.textMuted,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
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
                selectedColor: SafoColors.primary,
                checkmarkColor: Colors.white,
              ),
              FilterChip(
                label: Text(context.tr(en: 'To buy', sk: 'Kúpiť')),
                selected: selectedFilter == ShoppingListFilter.toBuy,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.toBuy),
                selectedColor: SafoColors.primary,
                checkmarkColor: Colors.white,
              ),
              FilterChip(
                label: Text(
                  context.tr(en: 'Assigned to me', sk: 'Priradené mne'),
                ),
                selected: selectedFilter == ShoppingListFilter.assignedToMe,
                onSelected: (_) =>
                    onFilterChanged(ShoppingListFilter.assignedToMe),
                selectedColor: SafoColors.primary,
                checkmarkColor: Colors.white,
              ),
              FilterChip(
                label: Text(context.tr(en: 'Bought', sk: 'Kúpené')),
                selected: selectedFilter == ShoppingListFilter.bought,
                onSelected: (_) => onFilterChanged(ShoppingListFilter.bought),
                selectedColor: SafoColors.primary,
                checkmarkColor: Colors.white,
              ),
            ],
          ),
        ),
      ],
        ),
      ),
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  final ShoppingListItem item;
  final String title;
  final String subtitle;
  final String quantityLabel;
  final String? assignmentLabel;
  final _FoodSafetyWarning? warning;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final ValueChanged<bool> onToggleBought;

  const _ShoppingItemCard({
    required this.item,
    required this.title,
    required this.subtitle,
    required this.quantityLabel,
    required this.assignmentLabel,
    required this.warning,
    required this.onTap,
    required this.onMore,
    required this.onToggleBought,
  });

  @override
  Widget build(BuildContext context) {
    final bought = item.isBought;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SafoRadii.xl),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bought ? SafoColors.surfaceSoft : SafoColors.surface,
          borderRadius: BorderRadius.circular(SafoRadii.xl),
          border: Border.all(color: SafoColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Checkbox(
                value: bought,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  onToggleBought(value);
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: SafoColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            decoration: bought ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ShoppingMetaPill(
                        label: quantityLabel,
                        tint: SafoColors.primarySoft,
                        textColor: SafoColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ShoppingMetaPill(
                        label: subtitle,
                        tint: const Color(0xFFF3EEE4),
                        textColor: SafoColors.textSecondary,
                      ),
                      if (assignmentLabel != null)
                        _ShoppingMetaPill(
                          label: assignmentLabel!,
                          tint: SafoColors.accentSoft,
                          textColor: SafoColors.accent,
                        ),
                      if (bought)
                        _ShoppingMetaPill(
                          label: context.tr(en: 'Bought', sk: 'Kúpené'),
                          tint: const Color(0xFFE7F5EC),
                          textColor: const Color(0xFF4E7A51),
                        ),
                    ],
                  ),
                  if (warning != null) ...[
                    const SizedBox(height: 10),
                    _ShoppingSafetyBadge(warning: warning!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onMore,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: SafoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingMetaPill extends StatelessWidget {
  final String label;
  final Color tint;
  final Color textColor;

  const _ShoppingMetaPill({
    required this.label,
    required this.tint,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  final List<HouseholdMember> members;

  const _ShoppingListViewData({
    required this.items,
    required this.preferences,
    required this.members,
  });
}

enum _FoodSafetyWarningType { allergy, intolerance }

class _FoodSafetyWarning {
  final _FoodSafetyWarningType type;
  final List<String> matchedSignals;

  const _FoodSafetyWarning({required this.type, required this.matchedSignals});
}
