import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../../core/widgets/safo_page_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/sign_out_action.dart';
import '../../household_activity/data/household_activity_repository.dart';
import '../../household_activity/domain/household_activity_event.dart';
import '../../households/domain/household.dart';
import '../../households/presentation/household_screen.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../user_preferences/data/user_preferences_repository.dart';
import '../../user_preferences/domain/user_preferences.dart';
import '../data/food_item_remote_data_source.dart';
import '../data/food_items_repository.dart';
import '../domain/food_item.dart';
import '../domain/food_item_prefill.dart';
import '../domain/opened_food_guidance.dart';
import 'barcode_lookup_screen.dart';
import 'food_item_form_screen.dart';
import 'fridge_scan_screen.dart';
import 'scan_history_screen.dart';

enum PantryFilter { all, noExpiry }

class FoodItemsScreen extends StatefulWidget {
  final AuthRepository authRepository;
  final Household household;
  final VoidCallback onPantryChanged;
  final VoidCallback onShoppingListChanged;
  final int refreshToken;
  final int expiringSoonOpenToken;

  const FoodItemsScreen({
    super.key,
    required this.authRepository,
    required this.household,
    required this.onPantryChanged,
    required this.onShoppingListChanged,
    required this.refreshToken,
    required this.expiringSoonOpenToken,
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
  late final HouseholdActivityRepository _activityRepository =
      HouseholdActivityRepository(householdId: widget.household.id);
  late final UserPreferencesRepository _userPreferencesRepository =
      UserPreferencesRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<_PantryViewData> _pantryFuture;
  PantryFilter _selectedFilter = PantryFilter.all;
  int? _handledExpiringSoonOpenToken;

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
    if (oldWidget.expiringSoonOpenToken != widget.expiringSoonOpenToken) {
      _maybeOpenExpiringSoonFromShell();
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

  Future<void> _handleSignOut() async {
    await confirmAndSignOut(context, widget.authRepository);
  }

  void _maybeOpenExpiringSoonFromShell() {
    if (_handledExpiringSoonOpenToken == widget.expiringSoonOpenToken) {
      return;
    }
    _handledExpiringSoonOpenToken = widget.expiringSoonOpenToken;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final viewData = await _pantryFuture;
      if (!mounted) {
        return;
      }
      await _openExpiringSoonScreen(viewData.items, viewData.preferences);
    });
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
      _logActivity(
        eventType: result.wasMerged ? 'pantry_increased' : 'pantry_added',
        itemName: result.item.name,
        quantity: createdItem.quantity,
        unit: createdItem.unit,
      );
      await _reconcileShoppingListAfterPantryIncrease(
        name: createdItem.name,
        quantity: createdItem.quantity,
        unit: createdItem.unit,
      );
      await _reload();
      widget.onPantryChanged();
      widget.onShoppingListChanged();
      if (!mounted) return;
      if (result.wasMerged) {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Updated existing ${result.item.name} (+${_formatCompactNumber(result.addedQuantity)} ${result.item.unit}).',
            sk: 'Aktualizovaná existujúca položka ${result.item.name} (+${_formatCompactNumber(result.addedQuantity)} ${result.item.unit}).',
          ),
        );
      } else {
        showSuccessFeedback(
          context,
          context.tr(
            en: 'Pantry item added.',
            sk: 'Položka bola pridaná do špajze.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add pantry item.',
          sk: 'Položku sa nepodarilo pridať do špajze.',
        ),
      );
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
      showErrorFeedback(
        context,
        context.tr(
          en: 'You need to be signed in.',
          sk: 'Musíš byť prihlásený.',
        ),
      );
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
          openedAt: null,
          createdAt: now,
          updatedAt: now,
        );
        final result = await _savePantryItemWithDuplicateHandling(
          item,
          existingItems: currentItems,
          promptForMerge: false,
        );
        await _reconcileShoppingListAfterPantryIncrease(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
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
      widget.onShoppingListChanged();
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
            ? context.tr(en: 'Scan processed.', sk: 'Scan bol spracovaný.')
            : context.tr(
                en: 'Scan processed: ${parts.join(', ')}.',
                sk: 'Scan bol spracovaný: ${parts.join(', ')}.',
              ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add scanned items.',
          sk: 'Naskenované položky sa nepodarilo pridať.',
        ),
      );
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
          title: Text(
            context.tr(
              en: 'Similar pantry item found',
              sk: 'Našla sa podobná pantry položka',
            ),
          ),
          content: Text(
            context.tr(
              en: 'You already have "${match.name}" in pantry. Do you want to increase the existing quantity instead of creating a duplicate item?',
              sk: 'Položku "${match.name}" už v špajzi máš. Chceš navýšiť existujúce množstvo namiesto vytvorenia duplicity?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.tr(en: 'Create separately', sk: 'Vytvoriť samostatne'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr(en: 'Increase existing', sk: 'Navýšiť existujúce'),
              ),
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
      if (item.openedAt != null) {
        continue;
      }

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
      if (item.openedAt != null) {
        continue;
      }

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
      _logActivity(
        eventType: 'pantry_updated',
        itemName: updatedItem.name,
        quantity: updatedItem.quantity,
        unit: updatedItem.unit,
      );
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Pantry item updated.',
          sk: 'Položka v špajzi bola upravená.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to update pantry item.',
          sk: 'Položku v špajzi sa nepodarilo upraviť.',
        ),
      );
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
      _logActivity(
        eventType: 'pantry_increased',
        itemName: updatedItem.name,
        quantity: additionalItem.quantity,
        unit: additionalItem.unit,
      );
      await _reconcileShoppingListAfterPantryIncrease(
        name: item.name,
        quantity: additionalItem.quantity,
        unit: additionalItem.unit,
      );
      await _reload();
      widget.onPantryChanged();
      widget.onShoppingListChanged();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Added to existing ${updatedItem.name} (+${_formatCompactNumber(additionalItem.quantity)} ${additionalItem.unit}). Total: ${_formatCompactNumber(updatedItem.quantity)} ${updatedItem.unit}.',
          sk: 'Pridané k existujúcej položke ${updatedItem.name} (+${_formatCompactNumber(additionalItem.quantity)} ${additionalItem.unit}). Spolu: ${_formatCompactNumber(updatedItem.quantity)} ${updatedItem.unit}.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add more to pantry item.',
          sk: 'Nepodarilo sa pridať viac k pantry položke.',
        ),
      );
    }
  }

  Future<void> _deleteItem(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr(en: 'Delete food item', sk: 'Zmazať položku')),
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
      await repository.removeFoodItem(item.id);
      _logActivity(
        eventType: 'pantry_deleted',
        itemName: item.name,
        quantity: item.quantity,
        unit: item.unit,
      );
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Pantry item deleted.',
          sk: 'Položka zo špajze bola zmazaná.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to delete pantry item.',
          sk: 'Položku zo špajze sa nepodarilo zmazať.',
        ),
      );
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
            title: Text(
              context.tr(en: 'Use ${item.name}', sk: 'Použiť ${item.name}'),
            ),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr(
                  en: 'Used quantity (${item.unit})',
                  sk: 'Použité množstvo (${item.unit})',
                ),
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
              ),
              FilledButton(
                onPressed: () {
                  final rawValue = controller.text.trim();
                  final parsed = _parseQuantity(rawValue);

                  if (rawValue.isEmpty) {
                    setDialogState(() {
                      errorText = context.tr(
                        en: 'Enter quantity',
                        sk: 'Zadaj množstvo',
                      );
                    });
                    return;
                  }

                  if (parsed == null || parsed <= 0) {
                    setDialogState(() {
                      errorText = context.tr(
                        en: 'Enter a valid number',
                        sk: 'Zadaj platné číslo',
                      );
                    });
                    return;
                  }

                  if (parsed > item.quantity + 0.000001) {
                    setDialogState(() {
                      errorText = context.tr(
                        en: 'Cannot use more than you have',
                        sk: 'Nemôžeš použiť viac, než máš',
                      );
                    });
                    return;
                  }

                  Navigator.pop(context, parsed);
                },
                child: Text(context.tr(en: 'Save', sk: 'Uložiť')),
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
      _logActivity(
        eventType: 'pantry_used',
        itemName: item.name,
        quantity: usedQuantity,
        unit: item.unit,
      );
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
                  ? context.tr(
                      en: '${item.name} used up and removed.',
                      sk: '${item.name} sa spotrebovalo a bolo odstránené.',
                    )
                  : context.tr(
                      en: '${item.name} updated.',
                      sk: '${item.name} bolo upravené.',
                    ),
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
            content: Text(
              context.tr(
                en: 'Failed to update pantry item: $error',
                sk: 'Položku v špajzi sa nepodarilo upraviť: $error',
              ),
            ),
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
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                item.openedAt == null
                    ? context.tr(
                        en: 'Mark as opened',
                        sk: 'Označiť ako otvorené',
                      )
                    : context.tr(en: 'Opened', sk: 'Otvorené'),
              ),
              subtitle: Text(
                item.openedAt == null
                    ? context.tr(
                        en: 'Track that this product is already opened',
                        sk: 'Sleduj, že tento produkt je už otvorený',
                      )
                    : '${context.tr(en: 'Opened', sk: 'Otvorené')} ${_formatShortDate(item.openedAt!)}',
              ),
              onTap: item.openedAt != null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _markItemAsOpened(item);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.tr(en: 'Edit', sk: 'Upraviť')),
              subtitle: Text(
                context.tr(
                  en: 'Replace or update this item',
                  sk: 'Prepísať alebo upraviť túto položku',
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _openEditForm(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(
                context.tr(en: 'Mark as used', sk: 'Označiť ako použité'),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _markItemAsUsed(item);
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

  Future<void> _markItemAsOpened(FoodItem item) async {
    final normalizedUnit = _normalizeUnit(item.unit);
    final canSplitByCount =
        normalizedUnit == 'pcs' &&
        item.quantity > 1 &&
        item.quantity == item.quantity.roundToDouble();

    double openedQuantity = item.quantity;

    if (canSplitByCount) {
      final controller = TextEditingController(text: '1');
      final selectedQuantity = await showDialog<double>(
        context: context,
        builder: (context) {
          String? errorText;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                context.tr(en: 'Open ${item.name}', sk: 'Otvoriť ${item.name}'),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr(
                    en: 'How many units did you open?',
                    sk: 'Koľko kusov si otvoril?',
                  ),
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(controller.text.trim());
                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        errorText = context.tr(
                          en: 'Enter a valid whole number',
                          sk: 'Zadaj platné celé číslo',
                        );
                      });
                      return;
                    }
                    if (parsed > item.quantity) {
                      setDialogState(() {
                        errorText = context.tr(
                          en: 'Cannot open more than you have',
                          sk: 'Nemôžeš otvoriť viac, než máš',
                        );
                      });
                      return;
                    }
                    Navigator.pop(context, parsed.toDouble());
                  },
                  child: Text(
                    context.tr(en: 'Mark opened', sk: 'Označiť ako otvorené'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      controller.dispose();

      if (selectedQuantity == null) {
        return;
      }
      openedQuantity = selectedQuantity;
    }

    try {
      final now = DateTime.now();
      final openedDate = DateTime(now.year, now.month, now.day);

      if (openedQuantity >= item.quantity - 0.000001) {
        final updatedItem = item.copyWith(
          expirationDate: adjustedExpirationAfterOpening(
            item,
            openedDate: openedDate,
          ),
          openedAt: openedDate,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.editFoodItem(updatedItem);
      } else {
        final remainingItem = item.copyWith(
          quantity: item.quantity - openedQuantity,
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.editFoodItem(remainingItem);

        final openedItem = FoodItem(
          id: '',
          userId: item.userId,
          householdId: item.householdId,
          name: item.name,
          barcode: item.barcode,
          category: item.category,
          storageLocation: item.storageLocation,
          quantity: openedQuantity,
          lowStockThreshold: item.lowStockThreshold,
          unit: item.unit,
          expirationDate: adjustedExpirationAfterOpening(
            item,
            openedDate: openedDate,
          ),
          openedAt: openedDate,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await repository.addFoodItem(openedItem);
      }
      _logActivity(
        eventType: 'pantry_opened',
        itemName: item.name,
        quantity: openedQuantity,
        unit: item.unit,
      );
      await _reload();
      widget.onPantryChanged();
      if (!mounted) return;
      if (openedQuantity >= item.quantity - 0.000001) {
        showSuccessFeedback(
          context,
          context.tr(
            en: '${item.name} marked as opened.',
            sk: '${item.name} bolo označené ako otvorené.',
          ),
        );
      } else {
        showSuccessFeedback(
          context,
          context.tr(
            en: '${_formatCompactNumber(openedQuantity)} ${item.unit} of ${item.name} marked as opened.',
            sk: '${_formatCompactNumber(openedQuantity)} ${item.unit} z ${item.name} bolo označené ako otvorené.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to mark pantry item as opened.',
          sk: 'Položku v špajzi sa nepodarilo označiť ako otvorenú.',
        ),
      );
    }
  }

  double? _parseQuantity(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
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

  String _shoppingKey(String name, String unit) {
    return '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
  }

  String _formatShortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String _shoppingNameKey(String name) {
    return name.trim().toLowerCase();
  }

  String _normalizeUnit(String value) {
    final normalized = value.trim().toLowerCase();
    if (const {
      'pcs',
      'pc',
      'piece',
      'pieces',
      'ks',
      'kus',
      'kusy',
    }.contains(normalized)) {
      return 'pcs';
    }
    if (const {'g', 'gram', 'grams', 'gramy', 'gramov'}.contains(normalized)) {
      return 'g';
    }
    if (const {
      'kg',
      'kilogram',
      'kilograms',
      'kilogramy',
    }.contains(normalized)) {
      return 'kg';
    }
    if (const {
      'ml',
      'milliliter',
      'milliliters',
      'mililiter',
    }.contains(normalized)) {
      return 'ml';
    }
    if (const {
      'l',
      'liter',
      'liters',
      'litre',
      'litres',
    }.contains(normalized)) {
      return 'l';
    }
    return normalized;
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
    const pieceFactors = {'pcs': 1.0};

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

  Future<void> _reconcileShoppingListAfterPantryIncrease({
    required String name,
    required double quantity,
    required String unit,
  }) async {
    var remaining = quantity;
    if (remaining <= 0) {
      return;
    }

    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
    final matchingItems =
        shoppingItems
            .where(
              (item) =>
                  !item.isBought &&
                  _shoppingNameKey(item.name) == _shoppingNameKey(name) &&
                  _convertQuantity(
                        quantity: 1,
                        fromUnit: unit,
                        toUnit: item.unit,
                      ) !=
                      null,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final shoppingItem in matchingItems) {
      if (remaining <= 0.0001) {
        break;
      }

      final pantryQuantityInShoppingUnit = _convertQuantity(
        quantity: remaining,
        fromUnit: unit,
        toUnit: shoppingItem.unit,
      );
      if (pantryQuantityInShoppingUnit == null) {
        continue;
      }

      if (pantryQuantityInShoppingUnit >= shoppingItem.quantity - 0.0001) {
        final consumedInPantryUnit = _convertQuantity(
          quantity: shoppingItem.quantity,
          fromUnit: shoppingItem.unit,
          toUnit: unit,
        );
        await _shoppingListRepository.removeShoppingListItem(shoppingItem.id);
        if (consumedInPantryUnit != null) {
          remaining -= consumedInPantryUnit;
        } else {
          remaining = 0;
        }
        continue;
      }

      final updated = shoppingItem.copyWith(
        quantity: shoppingItem.quantity - pantryQuantityInShoppingUnit,
        updatedAt: DateTime.now().toUtc(),
      );
      await _shoppingListRepository.editShoppingListItem(updated);
      remaining = 0;
    }
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
          context.tr(
            en: 'Low stock items are already on the shopping list.',
            sk: 'Položky s nízkou zásobou už sú v nákupnom zozname.',
          ),
        );
      } else {
        widget.onShoppingListChanged();
        showSuccessFeedback(
          context,
          context.tr(
            en: '$createdCount low stock item${createdCount == 1 ? '' : 's'} added to shopping list.',
            sk: '$createdCount polož${createdCount == 1 ? 'ka' : 'ky'} s nízkou zásobou ${createdCount == 1 ? 'bola pridaná' : 'boli pridané'} do nákupného zoznamu.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add low stock items.',
          sk: 'Položky s nízkou zásobou sa nepodarilo pridať.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: Text(context.tr(en: 'Add item', sk: 'Pridať položku')),
      ),
      body: FutureBuilder<_PantryViewData>(
        future: _pantryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            return AppErrorState(
              kind:
                  error is FoodItemsConfigException ||
                      error is FoodItemsAuthException
                  ? AppErrorKind.setup
                  : AppErrorKind.sync,
              title:
                  error is FoodItemsConfigException ||
                      error is FoodItemsAuthException
                  ? context.tr(
                      en: 'Pantry needs setup',
                      sk: 'Špajza potrebuje nastavenie',
                    )
                  : context.tr(
                      en: 'Pantry is unavailable',
                      sk: 'Špajza nie je k dispozícii',
                    ),
              message: _errorMessage(error),
              hint:
                  error is FoodItemsConfigException ||
                      error is FoodItemsAuthException
                  ? context.tr(
                      en: 'Safo needs account or backend setup before pantry data can load.',
                      sk: 'Safo potrebuje účet alebo backend nastavenie, aby sa načítali dáta špajze.',
                    )
                  : context.tr(
                      en: 'Safo could not load pantry items right now.',
                      sk: 'Safo teraz nedokázalo načítať položky v špajzi.',
                    ),
              onRetry: _reload,
            );
          }

          final items = snapshot.data?.items ?? [];
          final preferences = snapshot.data?.preferences;
          if (items.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No pantry items yet.',
                sk: 'Zatiaľ tu nemáš žiadne pantry položky.',
              ),
              onRefresh: _reload,
            );
          }

          final expiringSoonCount = items.where(_isExpiringSoon).length;
          final lowStockCount = items.where(_isLowStock).length;
          final filteredItems = _applyFilters(items);
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
            _PantryHeader(
              householdName: widget.household.name,
              onOpenHousehold: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HouseholdScreen(household: widget.household),
                  ),
                );
              },
              onOpenBarcode: _openBarcodeLookup,
              onOpenFridgeScan: _openFridgeScan,
              onOpenScanHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ScanHistoryScreen(householdId: widget.household.id),
                  ),
                );
              },
              onSignOut: () => _handleSignOut(),
            ),
            const SizedBox(height: 18),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PantryActionChip(
                  onTap: _openBarcodeLookup,
                  icon: Icons.qr_code_scanner_rounded,
                  label: context.tr(en: 'Scan code', sk: 'Skenovať kód'),
                  tint: SafoColors.primarySoft,
                  iconColor: SafoColors.primary,
                ),
                _PantryActionChip(
                  onTap: _openFridgeScan,
                  icon: Icons.photo_camera_back_outlined,
                  label: context.tr(en: 'Scan fridge', sk: 'Skenovať chladničku'),
                  tint: SafoColors.accentSoft,
                  iconColor: SafoColors.accent,
                ),
                _PantryActionChip(
                  onTap: () => _openExpiringSoonScreen(items, preferences),
                  icon: Icons.schedule_rounded,
                  label: context.tr(en: 'Use soon', sk: 'Použi čoskoro'),
                  tint: SafoColors.dangerSoft,
                  iconColor: SafoColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openExpiringSoonScreen(items, preferences),
                icon: const Icon(Icons.alarm_rounded),
                label: Text(
                  expiringSoonCount > 0
                      ? context.tr(
                          en: 'View $expiringSoonCount expiring soon item${expiringSoonCount == 1 ? '' : 's'}',
                          sk: 'Zobraziť $expiringSoonCount polož${expiringSoonCount == 1 ? 'ku' : 'ky'} Čoskoro sa minie',
                        )
                      : context.tr(
                          en: 'View expiring soon items',
                          sk: 'Zobraziť položky Čoskoro sa minie',
                        ),
                ),
              ),
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
                          context.tr(
                            en: 'View $lowStockCount low stock item${lowStockCount == 1 ? '' : 's'}',
                            sk: 'Zobraziť $lowStockCount polož${lowStockCount == 1 ? 'ku' : 'ky'} s nízkou zásobou',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _addLowStockItemsToShoppingList(items),
                        child: Text(
                          context.tr(
                            en: 'Add to shopping list',
                            sk: 'Pridať do nákupného zoznamu',
                          ),
                        ),
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
                    context.tr(
                      en: 'Merge $duplicateItemCount duplicate item${duplicateItemCount == 1 ? '' : 's'}',
                      sk: 'Zlúčiť $duplicateItemCount duplicitn${duplicateItemCount == 1 ? 'ú položku' : 'é položky'}',
                    ),
                  ),
                ),
              ),
            if (duplicateItemCount > 0) const SizedBox(height: 16),
          ];

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount:
                  headerWidgets.length +
                  (groupedEntries.isEmpty ? 1 : groupedEntries.length),
              itemBuilder: (context, index) {
                if (index < headerWidgets.length) {
                  return headerWidgets[index];
                }

                if (groupedEntries.isEmpty) {
                  return AppEmptyState(
                    message: context.tr(
                      en: 'No pantry items match your search.',
                      sk: 'Tvojmu hľadaniu nezodpovedajú žiadne pantry položky.',
                    ),
                    onRefresh: _reload,
                  );
                }

                final entry = groupedEntries[index - headerWidgets.length];
                return _buildGroupedEntry(entry, preferences);
              },
            ),
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
        PantryFilter.noExpiry => item.expirationDate == null,
      };
    }).toList();
  }

  List<List<FoodItem>> _findMergeableDuplicateGroups(List<FoodItem> items) {
    final grouped = <String, List<FoodItem>>{};

    for (final item in items) {
      if (item.openedAt != null) {
        continue;
      }

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
        title: Text(
          context.tr(
            en: 'Merge duplicate pantry items',
            sk: 'Zlúčiť duplicitné pantry položky',
          ),
        ),
        content: Text(
          context.tr(
                en: 'This will merge $duplicateCount duplicate item${duplicateCount == 1 ? '' : 's'} and sum their quantities.',
                sk: 'Týmto zlúčiš $duplicateCount duplicitn${duplicateCount == 1 ? 'ú položku' : 'é položky'} a spočítajú sa ich množstvá.',
              ) +
              (previewNames.isEmpty
                  ? ''
                  : context.tr(
                      en: '\n\nExamples: $previewNames',
                      sk: '\n\nPríklady: $previewNames',
                    )),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr(en: 'Merge', sk: 'Zlúčiť')),
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
        context.tr(
          en: 'Merged $mergedGroups pantry duplicate group${mergedGroups == 1 ? '' : 's'}.',
          sk: 'Zlúčen${mergedGroups == 1 ? 'á bola' : 'é boli'} $mergedGroups duplicitn${mergedGroups == 1 ? 'á skupina' : 'é skupiny'} pantry položiek.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to merge duplicate items.',
          sk: 'Duplicitné položky sa nepodarilo zlúčiť.',
        ),
      );
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
        builder: (context) => _PantrySubsetScreen(
          title: context.tr(en: 'Low stock', sk: 'Málo zásob'),
          subtitle: context.tr(
            en: 'These pantry items are close to their minimum stock level.',
            sk: 'Tieto pantry položky sú blízko svojho minimálneho stavu zásob.',
          ),
          badgeLabel: context.tr(en: 'Restock', sk: 'Doplniť'),
          emptyMessage: context.tr(
            en: 'No low stock items.',
            sk: 'Žiadne položky s nízkou zásobou.',
          ),
          items: lowStockItems,
          itemBuilder: (item) => _buildFoodItemCard(
            item,
            subtitle:
                '${_formatCompactNumber(item.quantity)} ${item.unit} • ${_categoryLabel(item.category)} • ${_storageLocationLabel(item.storageLocation)}'
                '${item.lowStockThreshold == null ? '' : ' • Limit ${_formatCompactNumber(item.lowStockThreshold!)} ${item.unit}'}',
            warning: _buildFoodSafetyWarning(item, preferences),
          ),
          onRefresh: _reload,
        ),
      ),
    );
  }

  Future<void> _openExpiringSoonScreen(
    List<FoodItem> items,
    UserPreferences? preferences,
  ) async {
    final expiringSoonItems = items.where(_isExpiringSoon).toList()
      ..sort(_compareFoodItemsForDisplay);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _PantrySubsetScreen(
          title: context.tr(en: 'Expiring soon', sk: 'Čoskoro sa minie'),
          subtitle: context.tr(
            en: 'Use these pantry items first to waste less food.',
            sk: 'Tieto pantry položky použi ako prvé, aby sa vyhodilo menej jedla.',
          ),
          badgeLabel: context.tr(en: 'Use first', sk: 'Použiť skôr'),
          emptyMessage: context.tr(
            en: 'No expiring soon items.',
            sk: 'Žiadne položky čoskoro sa minie.',
          ),
          items: expiringSoonItems,
          itemBuilder: (item) => _buildFoodItemCard(
            item,
            subtitle:
                '${_formatCompactNumber(item.quantity)} ${item.unit} • ${_categoryLabel(item.category)} • ${_storageLocationLabel(item.storageLocation)}'
                '${item.expirationDate == null ? '' : ' • ${_expiryShortLabel(item.expirationDate!)}'}',
            warning: _buildFoodSafetyWarning(item, preferences),
          ),
          onRefresh: _reload,
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
              '${_isLowStock(item) ? ' • ${context.tr(en: 'Low stock', sk: 'Málo zásob')}' : ''}',
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
      color: SafoColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        side: const BorderSide(color: SafoColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        onTap: () => _showItemActions(item),
        title: Row(
          children: [
            Expanded(
              child: Text(
                localizedIngredientDisplayName(context, item.name),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SafoColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (item.expirationDate != null)
              _ExpiryBadge(
                label: _expiryShortLabel(item.expirationDate!),
                state: _expiryState(item.expirationDate!),
              ),
            if (item.openedAt != null) ...[
              const SizedBox(width: 8),
              _OpenedBadge(
                label: context.tr(en: 'Opened', sk: 'Otvorené'),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SafoColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (item.openedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  context.tr(
                    en: 'Opened ${_formatShortDate(item.openedAt!)}',
                    sk: 'Otvorené ${_formatShortDate(item.openedAt!)}',
                  ),
                  _openedUseSoonLabel(item),
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SafoColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (warning != null) ...[
              const SizedBox(height: 8),
              _FoodSafetyBadge(warning: warning),
            ],
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showItemActions(item),
          tooltip: context.tr(en: 'More actions', sk: 'Viac akcií'),
          icon: const Icon(
            Icons.more_horiz_rounded,
            color: SafoColors.textMuted,
          ),
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
    // Use the shared food signal catalog based on the actual item name.
    // Broad categories such as "dairy" caused false lactose warnings for eggs.
    return deriveFoodSignalInfo(item.name).signals;
  }

  List<String> _matchPreferenceSignals(
    List<String> preferences,
    Set<String> itemSignals,
  ) {
    final matches = <String>{};
    for (final preference in preferences) {
      final canonical = canonicalFoodSignal(normalizeFoodValue(preference));
      if (canonical.isNotEmpty && itemSignals.contains(canonical)) {
        matches.add(canonical);
      }
    }
    return matches.toList()..sort();
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
    final openedPriorityComparison = openedDaysLeft(
      a,
    ).compareTo(openedDaysLeft(b));
    if (openedPriorityComparison != 0) {
      return openedPriorityComparison;
    }

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
      return context.tr(en: 'Expired', sk: 'Po expirácii');
    }
    if (days == 0) {
      return context.tr(en: 'Today', sk: 'Dnes');
    }
    if (days == 1) {
      return context.tr(en: 'Tomorrow', sk: 'Zajtra');
    }
    return context.tr(en: 'In $days days', sk: 'O $days dní');
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

  String _openedUseSoonLabel(FoodItem item) {
    final daysLeft = openedDaysLeft(item);
    if (daysLeft < 0) {
      return context.tr(en: 'Use as soon as possible', sk: 'Použi čo najskôr');
    }
    if (daysLeft == 0) {
      return context.tr(
        en: 'Use today after opening',
        sk: 'Použi dnes po otvorení',
      );
    }
    if (daysLeft == 1) {
      return context.tr(en: 'Use within 1 day', sk: 'Použi do 1 dňa');
    }
    return context.tr(
      en: 'Use within $daysLeft days',
      sk: 'Použi do $daysLeft dní',
    );
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'produce' => context.tr(en: 'Produce', sk: 'Zelenina a ovocie'),
      'dairy' => context.tr(en: 'Dairy', sk: 'Mliečne'),
      'meat' => context.tr(en: 'Meat', sk: 'Mäso'),
      'grains' => context.tr(en: 'Grains', sk: 'Obilniny'),
      'canned' => context.tr(en: 'Canned', sk: 'Konzervy'),
      'frozen' => context.tr(en: 'Frozen', sk: 'Mrazené'),
      'beverages' => context.tr(en: 'Beverages', sk: 'Nápoje'),
      _ => context.tr(en: 'Other', sk: 'Ostatné'),
    };
  }

  String _storageLocationLabel(String value) {
    return switch (value) {
      'fridge' => context.tr(en: 'Fridge', sk: 'Chladnička'),
      'freezer' => context.tr(en: 'Freezer', sk: 'Mraznička'),
      _ => context.tr(en: 'Pantry', sk: 'Špajza'),
    };
  }

  String _errorMessage(Object? error) {
    if (error is FoodItemsConfigException || error is FoodItemsAuthException) {
      return error.toString();
    }
    return context.tr(
      en: 'Failed to load food items.',
      sk: 'Položky v špajzi sa nepodarilo načítať.',
    );
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

class _PantryHeader extends StatelessWidget {
  final String householdName;
  final VoidCallback onOpenHousehold;
  final VoidCallback onOpenBarcode;
  final VoidCallback onOpenFridgeScan;
  final VoidCallback onOpenScanHistory;
  final VoidCallback onSignOut;

  const _PantryHeader({
    required this.householdName,
    required this.onOpenHousehold,
    required this.onOpenBarcode,
    required this.onOpenFridgeScan,
    required this.onOpenScanHistory,
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
            _PantryHeaderIconButton(
              icon: Icons.groups_2_outlined,
              onTap: onOpenHousehold,
            ),
            const SizedBox(width: 8),
            _PantryHeaderIconButton(
              icon: Icons.history_rounded,
              onTap: onOpenScanHistory,
            ),
            const SizedBox(width: 8),
            _PantryHeaderIconButton(
              icon: Icons.logout_rounded,
              onTap: onSignOut,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          context.tr(en: 'Pantry overview', sk: 'Prehľad špajze'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SafoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(en: 'Pantry', sk: 'Špajza'),
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

class _PantryHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PantryHeaderIconButton({
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
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.92,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          label: context.tr(en: 'Total items', sk: 'Spolu položiek'),
          value: totalItems.toString(),
          background: SafoColors.surface,
          valueColor: SafoColors.textPrimary,
        ),
        _SummaryCard(
          label: context.tr(en: 'Expiring soon', sk: 'Čoskoro sa minie'),
          value: expiringSoonCount.toString(),
          background: SafoColors.dangerSoft,
          valueColor: SafoColors.danger,
        ),
        _SummaryCard(
          label: context.tr(en: 'Low stock', sk: 'Málo zásob'),
          value: lowStockCount.toString(),
          background: SafoColors.warningSoft,
          valueColor: SafoColors.warning,
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

  const _StorageSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: SafoColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: SafoColors.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: SafoColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PantrySubsetScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final String emptyMessage;
  final List<FoodItem> items;
  final Widget Function(FoodItem item) itemBuilder;
  final Future<void> Function() onRefresh;

  const _PantrySubsetScreen({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.emptyMessage,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              SafoSpacing.md,
              SafoSpacing.sm,
              SafoSpacing.md,
              SafoSpacing.xxl,
            ),
            itemCount: items.isEmpty ? 2 : items.length + 2,
            separatorBuilder: (_, index) => SizedBox(
              height: index == 0 ? SafoSpacing.lg : SafoSpacing.sm,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return SafoPageHeader(
                  title: title,
                  subtitle: subtitle,
                  dark: false,
                  onBack: () => Navigator.of(context).maybePop(),
                  badges: [
                    _PantrySubsetBadge(
                      label: badgeLabel,
                      count: items.length,
                    ),
                  ],
                );
              }

              if (index == 1 && items.isEmpty) {
                return AppEmptyState(
                  message: emptyMessage,
                  onRefresh: onRefresh,
                );
              }

              if (index == 1) {
                return Container(
                  padding: const EdgeInsets.all(SafoSpacing.lg),
                  decoration: BoxDecoration(
                    color: SafoColors.surface,
                    borderRadius: BorderRadius.circular(SafoRadii.xl),
                    border: Border.all(color: SafoColors.border),
                  ),
                  child: Text(
                    '${items.length} ${context.tr(en: 'items', sk: 'položiek')}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              return itemBuilder(items[index - 2]);
            },
          ),
        ),
      ),
    );
  }
}

class _PantrySubsetBadge extends StatelessWidget {
  final String label;
  final int count;

  const _PantrySubsetBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SafoSpacing.sm,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: SafoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
        border: Border.all(color: SafoColors.border),
      ),
      child: Text(
        '$label • $count',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OpenedBadge extends StatelessWidget {
  final String label;

  const _OpenedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8D8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF8A4B00),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color valueColor;

  const _SummaryCard({
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
    final prefix = isAllergy
        ? context.tr(en: 'Allergy warning', sk: 'Upozornenie na alergiu')
        : context.tr(
            en: 'Intolerance warning',
            sk: 'Upozornenie na intoleranciu',
          );
    final labels = warning.matches.map(_warningLabel).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$prefix: ${context.tr(en: 'contains', sk: 'obsahuje')} $labels',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _warningLabel(String signal) {
    return switch (signal) {
      'lactose' => 'laktóza/mliečne',
      'gluten' => 'lepok',
      'eggs' => 'vajcia',
      'peanuts' => 'arašidy',
      'tree nuts' => 'orechy',
      'soy' => 'sója',
      'fish' => 'ryby',
      'shellfish' => 'morské plody',
      'sesame' => 'sezam',
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
            hintText: context.tr(
              en: 'Search pantry items',
              sk: 'Hľadať položky v špajzi',
            ),
            hintStyle: const TextStyle(
              color: SafoColors.textMuted,
              fontWeight: FontWeight.w500,
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PantryFilterChip(
              label: context.tr(en: 'All', sk: 'Všetko'),
              selected: selectedFilter == PantryFilter.all,
              onTap: () => onFilterChanged(PantryFilter.all),
            ),
            _PantryFilterChip(
              label: context.tr(en: 'No expiry', sk: 'Bez expirácie'),
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
          color: selected ? SafoColors.primary : SafoColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? SafoColors.primary : SafoColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : SafoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PantryActionChip extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;

  const _PantryActionChip({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: iconColor, size: 18),
      label: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: SafoColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: tint,
        side: BorderSide(color: tint),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SafoRadii.lg),
        ),
      ),
    );
  }
}
