import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
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
          ),
        );
      }
    }

    for (final item in shoppingItems.where((item) => !item.isBought).take(6)) {
      notifications.add(
        _AppNotificationItem(
          title: item.name,
          subtitle: context.tr(
            en: 'Buy ${_formatQuantity(item.quantity)} ${item.unit}',
            sk: 'Kúp ${_formatQuantity(item.quantity)} ${item.unit}',
          ),
          kind: _NotificationKind.shopping,
          priority: 6,
        ),
      );
    }

    for (final entry in mealPlanEntries) {
      final days = _daysUntil(entry.scheduledFor);
      if (days > 1) {
        continue;
      }

      notifications.add(
        _AppNotificationItem(
          title: entry.recipeName,
          subtitle: days == 0
              ? context.tr(
                  en: 'Planned for today • ${entry.servings} servings',
                  sk: 'Naplánované na dnes • ${entry.servings} porcie',
                )
              : context.tr(
                  en: 'Planned for tomorrow • ${entry.servings} servings',
                  sk: 'Naplánované na zajtra • ${entry.servings} porcie',
                ),
          kind: _NotificationKind.mealPlan,
          priority: days,
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
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  child: ListTile(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}

enum _NotificationKind { expiringSoon, opened, lowStock, shopping, mealPlan }

class _AppNotificationItem {
  final String title;
  final String subtitle;
  final _NotificationKind kind;
  final int priority;

  const _AppNotificationItem({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.priority,
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
    return context.tr(
      en: 'Use as soon as possible',
      sk: 'Použi čo najskôr',
    );
  }
  if (daysLeft == 0) {
    return context.tr(
      en: 'Use today after opening',
      sk: 'Použi dnes po otvorení',
    );
  }
  if (daysLeft == 1) {
    return context.tr(
      en: 'Use within 1 day',
      sk: 'Použi do 1 dňa',
    );
  }
  return context.tr(
    en: 'Use within $daysLeft days',
    sk: 'Použi do $daysLeft dní',
  );
}
