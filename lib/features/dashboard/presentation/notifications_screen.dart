import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/supabase.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../households/domain/household.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';

class NotificationsScreen extends StatefulWidget {
  final Household household;
  final VoidCallback onOpenPantry;
  final VoidCallback onOpenShoppingList;
  final VoidCallback onOpenMealPlan;

  const NotificationsScreen({
    super.key,
    required this.household,
    required this.onOpenPantry,
    required this.onOpenShoppingList,
    required this.onOpenMealPlan,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );

  late Future<List<_AppNotificationItem>> _notificationsFuture =
      _loadNotifications();

  String? get _currentUserId => tryGetSupabaseClient()?.auth.currentUser?.id;

  Future<void> _reload() async {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
    await _notificationsFuture;
  }

  Future<List<_AppNotificationItem>> _loadNotifications() async {
    final results = await Future.wait<dynamic>([
      _foodItemsRepository.getFoodItems(),
      _shoppingListRepository.getShoppingListItems(),
      _mealPlanRepository.getEntries(),
    ]);

    final pantryItems = results[0] as List<FoodItem>;
    final shoppingItems = results[1] as List<ShoppingListItem>;
    final mealPlanEntries = results[2] as List<MealPlanEntry>;
    final notifications = <_AppNotificationItem>[];

    for (final item in pantryItems) {
      final daysUntilExpiry = _daysUntil(item.expirationDate);
      if (item.expirationDate != null && daysUntilExpiry <= 3) {
        notifications.add(
          _AppNotificationItem(
            title: item.name,
            subtitle:
                '${_expiryLabel(context, item.expirationDate)} • ${_formatQuantity(item.quantity)} ${item.unit}',
            kind: _NotificationKind.expiringSoon,
            priority: daysUntilExpiry < 0 ? 0 : daysUntilExpiry,
            pantryItem: item,
          ),
        );
      }

      if (item.openedAt != null) {
        final openedDaysLeft = _openedDaysLeft(item);
        notifications.add(
          _AppNotificationItem(
            title: item.name,
            subtitle:
                '${context.tr(en: 'Opened', sk: 'Otvorené')} ${_formatDate(item.openedAt!)} • ${_openedUseSoonLabel(context, item)}',
            kind: _NotificationKind.opened,
            priority: openedDaysLeft,
            pantryItem: item,
          ),
        );
      }

      if (_isLowStock(item)) {
        notifications.add(
          _AppNotificationItem(
            title: item.name,
            subtitle: context.tr(
              en: '${_formatQuantity(item.quantity)} ${item.unit} left • limit ${_formatQuantity(item.lowStockThreshold!)} ${item.unit}',
              sk: 'Zostáva ${_formatQuantity(item.quantity)} ${item.unit} • limit ${_formatQuantity(item.lowStockThreshold!)} ${item.unit}',
            ),
            kind: _NotificationKind.lowStock,
            priority: 5,
            pantryItem: item,
          ),
        );
      }
    }

    final activeShoppingItems = shoppingItems.where((item) => !item.isBought);
    final assignedToMe = activeShoppingItems
        .where((item) => item.assignedToUserId == _currentUserId)
        .toList();
    final generalShopping = activeShoppingItems
        .where((item) => item.assignedToUserId != _currentUserId)
        .take(6)
        .toList();

    for (final item in [...assignedToMe, ...generalShopping].take(8)) {
      final isAssignedToMe = item.assignedToUserId == _currentUserId;
      notifications.add(
        _AppNotificationItem(
          title: item.name,
          subtitle: isAssignedToMe
              ? context.tr(
                  en: 'Your shopping task • ${_formatQuantity(item.quantity)} ${item.unit}',
                  sk: 'Tvoja nákupná úloha • ${_formatQuantity(item.quantity)} ${item.unit}',
                )
              : context.tr(
                  en: 'Buy ${_formatQuantity(item.quantity)} ${item.unit}',
                  sk: 'Kúp ${_formatQuantity(item.quantity)} ${item.unit}',
                ),
          kind: _NotificationKind.shopping,
          priority: isAssignedToMe ? 4 : 6,
          shoppingItem: item,
        ),
      );
    }

    for (final entry in mealPlanEntries) {
      final days = _daysUntil(entry.scheduledFor);
      if (days > 1) {
        continue;
      }
      final isAssignedToMe = entry.assignedCookUserId == _currentUserId;

      notifications.add(
        _AppNotificationItem(
          title: entry.recipeName,
          subtitle: _mealPlanNotificationSubtitle(
            entry,
            days: days,
            isAssignedToMe: isAssignedToMe,
          ),
          kind: _NotificationKind.mealPlan,
          priority: isAssignedToMe ? days : days + 1,
          mealPlanEntry: entry,
        ),
      );
    }

    notifications.sort((a, b) {
      final priorityComparison = a.priority.compareTo(b.priority);
      if (priorityComparison != 0) {
        return priorityComparison;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return notifications;
  }

  String _mealPlanNotificationSubtitle(
    MealPlanEntry entry, {
    required int days,
    required bool isAssignedToMe,
  }) {
    if (isAssignedToMe && days == 0) {
      return context.tr(
        en: 'Your cooking task today • ${entry.servings} servings',
        sk: 'Tvoje varenie dnes • ${entry.servings} porcie',
      );
    }
    if (isAssignedToMe) {
      return context.tr(
        en: 'Your cooking task tomorrow • ${entry.servings} servings',
        sk: 'Tvoje varenie zajtra • ${entry.servings} porcie',
      );
    }
    return days == 0
        ? context.tr(
            en: 'Planned for today • ${entry.servings} servings',
            sk: 'Naplánované na dnes • ${entry.servings} porcie',
          )
        : context.tr(
            en: 'Planned for tomorrow • ${entry.servings} servings',
            sk: 'Naplánované na zajtra • ${entry.servings} porcie',
          );
  }

  void _openNotificationTarget(_NotificationKind kind) {
    Navigator.of(context).pop();
    switch (kind) {
      case _NotificationKind.expiringSoon:
      case _NotificationKind.opened:
      case _NotificationKind.lowStock:
        widget.onOpenPantry();
        break;
      case _NotificationKind.shopping:
        widget.onOpenShoppingList();
        break;
      case _NotificationKind.mealPlan:
        widget.onOpenMealPlan();
        break;
    }
  }

  Future<void> _markShoppingAsBought(_AppNotificationItem notification) async {
    final item = notification.shoppingItem;
    if (item == null) {
      return;
    }

    try {
      final pantryDetails = await _confirmBoughtPantryDetails(item);
      if (pantryDetails == null) {
        return;
      }
      await _addBoughtItemToPantry(
        item,
        storageLocation: pantryDetails.storageLocation,
        expirationDate: pantryDetails.expirationDate,
      );
      await _shoppingListRepository.removeShoppingListItem(item.id);
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Moved to pantry and removed from shopping list.',
          sk: 'Presunuté do špajze a odstránené z nákupného zoznamu.',
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

  Future<void> _markPantryItemAsUsed(_AppNotificationItem notification) async {
    final item = notification.pantryItem;
    if (item == null) {
      return;
    }

    final controller = TextEditingController(text: '1');
    final usedQuantity = await showDialog<double>(
      context: context,
      builder: (context) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              context.tr(
                en: 'Use ${localizedIngredientDisplayName(context, item.name)}',
                sk: 'Použiť ${localizedIngredientDisplayName(context, item.name)}',
              ),
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
        await _foodItemsRepository.removeFoodItem(item.id);
      } else {
        await _foodItemsRepository.editFoodItem(
          item.copyWith(
            quantity: remainingQuantity,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }
      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        remainingQuantity <= 0.000001
            ? context.tr(
                en: 'Item used up and removed.',
                sk: 'Položka sa spotrebovala a bola odstránená.',
              )
            : context.tr(
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

  Future<void> _addLowStockToShopping(_AppNotificationItem notification) async {
    final pantryItem = notification.pantryItem;
    if (pantryItem == null) {
      return;
    }

    try {
      final shoppingItems = await _shoppingListRepository
          .getShoppingListItems();
      final existing = shoppingItems.cast<ShoppingListItem?>().firstWhere(
        (candidate) =>
            candidate != null &&
            _itemKey(candidate.name, candidate.unit) ==
                _itemKey(pantryItem.name, pantryItem.unit),
        orElse: () => null,
      );
      final now = DateTime.now().toUtc();
      final targetQuantity =
          pantryItem.lowStockThreshold ?? pantryItem.quantity;

      if (existing == null) {
        await _shoppingListRepository.addShoppingListItem(
          ShoppingListItem(
            id: '',
            userId: pantryItem.userId,
            householdId: pantryItem.householdId,
            name: pantryItem.name,
            quantity: targetQuantity,
            unit: pantryItem.unit,
            source: ShoppingListItem.sourceLowStock,
            isBought: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        final addedInExistingUnit = _convertQuantity(
          quantity: targetQuantity,
          fromUnit: pantryItem.unit,
          toUnit: existing.unit,
        );
        await _shoppingListRepository.editShoppingListItem(
          existing.copyWith(
            quantity:
                existing.quantity + (addedInExistingUnit ?? targetQuantity),
            isBought: false,
            source: ShoppingListItem.mergeSource(
              existing.source,
              ShoppingListItem.sourceLowStock,
            ),
            updatedAt: now,
          ),
        );
      }

      await _reload();
      if (!mounted) return;
      showSuccessFeedback(
        context,
        context.tr(
          en: 'Added to shopping list.',
          sk: 'Pridané do nákupného zoznamu.',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to add item to shopping list.',
          sk: 'Položku sa nepodarilo pridať do nákupného zoznamu.',
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
                  if (value == null) return;
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
                  if (picked == null) return;
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
        quantity: matching.quantity + incomingInExistingUnit,
        storageLocation: storageLocation,
        expirationDate: expirationDate ?? matching.expirationDate,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(en: 'Notifications', sk: 'Upozornenia')),
      ),
      body: FutureBuilder<List<_AppNotificationItem>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: context.tr(
                en: 'Failed to load notifications.',
                sk: 'Upozornenia sa nepodarilo načítať.',
              ),
              onRetry: _reload,
            );
          }

          final notifications = snapshot.data ?? const <_AppNotificationItem>[];
          if (notifications.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No urgent notifications right now.',
                sk: 'Momentálne nemáš žiadne urgentné upozornenia.',
              ),
              onRefresh: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _openNotificationTarget(item.kind),
                          leading: CircleAvatar(
                            backgroundColor: _notificationColor(item.kind),
                            child: Icon(
                              _notificationIcon(item.kind),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            localizedIngredientDisplayName(context, item.title),
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (item.kind == _NotificationKind.shopping)
                                FilledButton.tonal(
                                  onPressed: () => _markShoppingAsBought(item),
                                  child: Text(
                                    context.tr(en: 'Bought', sk: 'Kúpené'),
                                  ),
                                )
                              else if (item.kind == _NotificationKind.lowStock)
                                FilledButton.tonal(
                                  onPressed: () => _addLowStockToShopping(item),
                                  child: Text(
                                    context.tr(
                                      en: 'Add to shopping',
                                      sk: 'Do nákupu',
                                    ),
                                  ),
                                )
                              else if (item.kind ==
                                      _NotificationKind.expiringSoon ||
                                  item.kind == _NotificationKind.opened)
                                FilledButton.tonal(
                                  onPressed: () => _markPantryItemAsUsed(item),
                                  child: Text(
                                    context.tr(en: 'Used', sk: 'Použité'),
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: () =>
                                      _openNotificationTarget(item.kind),
                                  child: Text(_actionLabel(context, item.kind)),
                                ),
                            ],
                          ),
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
}

double? _parseQuantity(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _actionLabel(BuildContext context, _NotificationKind kind) {
  return switch (kind) {
    _NotificationKind.shopping => context.tr(
      en: 'Open shopping list',
      sk: 'Otvoriť nákupný zoznam',
    ),
    _NotificationKind.mealPlan => context.tr(
      en: 'Open meal plan',
      sk: 'Otvoriť jedálniček',
    ),
    _ => context.tr(en: 'Open pantry', sk: 'Otvoriť špajzu'),
  };
}

String _itemKey(String name, String unit) {
  return '${_normalizeValue(name)}|${_normalizeUnit(unit)}';
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
    'kusov',
  }.contains(normalized)) {
    return 'pcs';
  }
  if (const {'g', 'gram', 'grams', 'gramy', 'gramov'}.contains(normalized)) {
    return 'g';
  }
  if (const {'kg', 'kilogram', 'kilograms', 'kilo'}.contains(normalized)) {
    return 'kg';
  }
  if (const {
    'ml',
    'milliliter',
    'milliliters',
    'mililitre',
  }.contains(normalized)) {
    return 'ml';
  }
  if (const {'l', 'liter', 'liters', 'litre', 'litra'}.contains(normalized)) {
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
    return quantity;
  }
  return null;
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

enum _NotificationKind { expiringSoon, opened, lowStock, shopping, mealPlan }

class _AppNotificationItem {
  final String title;
  final String subtitle;
  final _NotificationKind kind;
  final int priority;
  final FoodItem? pantryItem;
  final ShoppingListItem? shoppingItem;
  final MealPlanEntry? mealPlanEntry;

  const _AppNotificationItem({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.priority,
    this.pantryItem,
    this.shoppingItem,
    this.mealPlanEntry,
  });
}

IconData _notificationIcon(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.expiringSoon:
      return Icons.schedule_rounded;
    case _NotificationKind.opened:
      return Icons.inventory_2_outlined;
    case _NotificationKind.lowStock:
      return Icons.warning_amber_rounded;
    case _NotificationKind.shopping:
      return Icons.shopping_cart_outlined;
    case _NotificationKind.mealPlan:
      return Icons.event_note_rounded;
  }
}

Color _notificationColor(_NotificationKind kind) {
  switch (kind) {
    case _NotificationKind.expiringSoon:
      return const Color(0xFFE07A5F);
    case _NotificationKind.opened:
      return const Color(0xFF8A4B00);
    case _NotificationKind.lowStock:
      return const Color(0xFF2ECC71);
    case _NotificationKind.shopping:
      return const Color(0xFF1B2A41);
    case _NotificationKind.mealPlan:
      return const Color(0xFF4C6FFF);
  }
}

bool _isLowStock(FoodItem item) {
  final threshold = item.lowStockThreshold;
  if (threshold == null) {
    return false;
  }
  return item.quantity <= threshold;
}

int _daysUntil(DateTime? value) {
  if (value == null) {
    return 9999;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  return target.difference(today).inDays;
}

String _expiryLabel(BuildContext context, DateTime? value) {
  final days = _daysUntil(value);
  if (days < 0) {
    return context.tr(en: 'Expired', sk: 'Po záruke');
  }
  if (days == 0) {
    return context.tr(en: 'Today', sk: 'Dnes');
  }
  if (days == 1) {
    return context.tr(en: 'Tomorrow', sk: 'Zajtra');
  }
  return context.tr(en: 'In $days days', sk: 'O $days dní');
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

int _openedUseWithinDays(FoodItem item) {
  switch (item.category) {
    case 'dairy':
      return 3;
    case 'meat':
      return 2;
    case 'produce':
      return 3;
    case 'canned':
      return 4;
    case 'frozen':
      return 2;
    case 'beverages':
      return 5;
    case 'grains':
      return 7;
    default:
      return 3;
  }
}

int _daysSinceOpened(DateTime? value) {
  if (value == null) {
    return 0;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final opened = DateTime(value.year, value.month, value.day);
  return today.difference(opened).inDays;
}

int _openedDaysLeft(FoodItem item) {
  if (item.openedAt == null) {
    return 9999;
  }
  return _openedUseWithinDays(item) - _daysSinceOpened(item.openedAt);
}

String _openedUseSoonLabel(BuildContext context, FoodItem item) {
  final daysLeft = _openedDaysLeft(item);
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
