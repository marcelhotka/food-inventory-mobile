import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/supabase.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../household_activity/data/household_activity_repository.dart';
import '../../household_activity/domain/household_activity_event.dart';
import '../../recipes/presentation/recipe_display_text.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../data/household_repository.dart';
import '../domain/household.dart';
import '../domain/household_member.dart';

class HouseholdScreen extends StatefulWidget {
  final Household household;

  const HouseholdScreen({super.key, required this.household});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  late final HouseholdRepository _repository = HouseholdRepository();
  late final FoodItemsRepository _foodItemsRepository = FoodItemsRepository(
    householdId: widget.household.id,
  );
  late final ShoppingListRepository _shoppingListRepository =
      ShoppingListRepository(householdId: widget.household.id);
  late final HouseholdActivityRepository _activityRepository =
      HouseholdActivityRepository(householdId: widget.household.id);
  late Future<_HouseholdViewData> _viewFuture = _loadViewData();

  String? get _currentUserId => tryGetSupabaseClient()?.auth.currentUser?.id;

  Future<void> _reload() async {
    setState(() {
      _viewFuture = _loadViewData();
    });
    await _viewFuture;
  }

  Future<_HouseholdViewData> _loadViewData() async {
    final members = await _repository.getMembers(widget.household.id);
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
    List<HouseholdActivityEvent> events;
    try {
      events = await _activityRepository.getRecentEvents();
    } catch (_) {
      events = const <HouseholdActivityEvent>[];
    }
    return _HouseholdViewData(
      members: members,
      events: events,
      pantryItems: pantryItems,
      shoppingItems: shoppingItems,
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.household.id));
    if (!mounted) return;
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Household code copied.',
        sk: 'Kód domácnosti bol skopírovaný.',
      ),
    );
  }

  Future<void> _addKeepAtHomeToShopping(_HabitItem item) async {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }

    final now = DateTime.now();
    final shoppingItem = ShoppingListItem(
      id: '',
      userId: userId,
      householdId: widget.household.id,
      name: item.displayName,
      quantity: item.suggestedQuantity,
      unit: item.suggestedUnit,
      source: ShoppingListItem.sourceManual,
      isBought: false,
      createdAt: now,
      updatedAt: now,
    );

    await _shoppingListRepository.addShoppingListItem(shoppingItem);
    if (!mounted) {
      return;
    }
    showSuccessFeedback(
      context,
      context.tr(
        en: 'Added to shopping list.',
        sk: 'Pridané do nákupného zoznamu.',
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: context.tr(en: 'Back', sk: 'Späť'),
        ),
        title: Text(context.tr(en: 'Household', sk: 'Domácnosť')),
      ),
      body: FutureBuilder<_HouseholdViewData>(
        future: _viewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: context.tr(
                en: 'Failed to load household members.',
                sk: 'Nepodarilo sa načítať členov domácnosti.',
              ),
              onRetry: _reload,
            );
          }

          final viewData =
              snapshot.data ??
              const _HouseholdViewData(
                members: <HouseholdMember>[],
                events: <HouseholdActivityEvent>[],
                pantryItems: <FoodItem>[],
                shoppingItems: <ShoppingListItem>[],
              );
          final members = viewData.members;
          final events = viewData.events;
          final pantryItems = viewData.pantryItems;
          final shoppingItems = viewData.shoppingItems;
          final topBought = _topHabitItems(
            events,
            matchingTypes: const {
              'shopping_added',
              'shopping_increased',
              'shopping_bought',
            },
          );
          final topUsed = _topHabitItems(
            events,
            matchingTypes: const {'pantry_used', 'pantry_opened'},
          );
          final wasteRisk = _wasteRiskItems(pantryItems);
          final keepAtHome = _keepAtHomeItems(
            events,
            pantryItems,
            shoppingItems,
          );
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.household.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr(
                            en: 'Share this household code with another family member so they can join the same pantry and shopping list.',
                            sk: 'Zdieľaj tento kód domácnosti s ďalším členom rodiny, aby sa pripojil do rovnakej špajze a nákupného zoznamu.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EEE4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            widget.household.id,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(
                            context.tr(en: 'Copy code', sk: 'Kopírovať kód'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(en: 'Members', sk: 'Členovia'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.group_outlined, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(
                              en: 'No household members visible yet.',
                              sk: 'Zatiaľ tu nevidno žiadnych členov domácnosti.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              en: 'Try pulling to refresh after another user joins with your household code.',
                              sk: 'Skús potiahnuť na obnovenie po tom, ako sa ďalší používateľ pripojí cez kód tvojej domácnosti.',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(member.role == 'owner' ? 'O' : 'M'),
                          ),
                          title: Text(
                            member.role == 'owner'
                                ? context.tr(en: 'Owner', sk: 'Vlastník')
                                : context.tr(en: 'Member', sk: 'Člen'),
                          ),
                          subtitle: Text(member.userId),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  context.tr(en: 'Household habits', sk: 'Návyky domácnosti'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _HabitSummaryCard(
                  title: context.tr(en: 'Bought often', sk: 'Často kupované'),
                  emptyMessage: context.tr(
                    en: 'No buying patterns yet.',
                    sk: 'Zatiaľ nemáme nákupné návyky.',
                  ),
                  items: topBought,
                ),
                const SizedBox(height: 12),
                _HabitSummaryCard(
                  title: context.tr(en: 'Used often', sk: 'Často používané'),
                  emptyMessage: context.tr(
                    en: 'No usage patterns yet.',
                    sk: 'Zatiaľ nemáme spotrebné návyky.',
                  ),
                  items: topUsed,
                ),
                const SizedBox(height: 12),
                _HabitSummaryCard(
                  title: context.tr(
                    en: 'Waste risk now',
                    sk: 'Riziko odpadu teraz',
                  ),
                  emptyMessage: context.tr(
                    en: 'No risky pantry items right now.',
                    sk: 'Momentálne tu nie sú rizikové pantry položky.',
                  ),
                  items: wasteRisk,
                ),
                const SizedBox(height: 12),
                _HabitSummaryCard(
                  title: context.tr(
                    en: 'Worth keeping at home',
                    sk: 'Oplatí sa držať doma',
                  ),
                  emptyMessage: context.tr(
                    en: 'No regular staples suggested yet.',
                    sk: 'Zatiaľ nemáme odporúčané pravidelné zásoby.',
                  ),
                  items: keepAtHome,
                  actionLabel: context.tr(
                    en: 'Add to shopping',
                    sk: 'Do nákupu',
                  ),
                  onAction: _addKeepAtHomeToShopping,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(en: 'Recent activity', sk: 'Posledná aktivita'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (events.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.history_outlined, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(
                              en: 'No household activity yet.',
                              sk: 'Zatiaľ tu nie je žiadna aktivita domácnosti.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              en: 'Activity will appear here when someone adds, updates, opens, uses, or buys items.',
                              sk: 'Aktivita sa tu zobrazí, keď niekto pridá, upraví, otvorí, použije alebo kúpi položky.',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...events
                      .take(8)
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.bolt_outlined),
                              title: Text(_eventTitle(event)),
                              subtitle: Text(_eventSubtitle(event)),
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

  String _eventTitle(HouseholdActivityEvent event) {
    final action = switch (event.eventType) {
      'pantry_added' => context.tr(
        en: 'Added to pantry',
        sk: 'Pridané do špajze',
      ),
      'pantry_increased' => context.tr(
        en: 'Added more to pantry',
        sk: 'Pridané viac do špajze',
      ),
      'pantry_updated' => context.tr(
        en: 'Updated pantry item',
        sk: 'Upravená položka v špajzi',
      ),
      'pantry_used' => context.tr(
        en: 'Used from pantry',
        sk: 'Použité zo špajze',
      ),
      'pantry_opened' => context.tr(
        en: 'Marked as opened',
        sk: 'Označené ako otvorené',
      ),
      'pantry_deleted' => context.tr(
        en: 'Deleted from pantry',
        sk: 'Zmazané zo špajze',
      ),
      'shopping_added' => context.tr(
        en: 'Added to shopping list',
        sk: 'Pridané do nákupného zoznamu',
      ),
      'shopping_increased' => context.tr(
        en: 'Added more to shopping list',
        sk: 'Pridané viac do nákupného zoznamu',
      ),
      'shopping_updated' => context.tr(
        en: 'Updated shopping item',
        sk: 'Upravená nákupná položka',
      ),
      'shopping_bought' => context.tr(
        en: 'Marked as bought',
        sk: 'Označené ako kúpené',
      ),
      'shopping_assigned' => context.tr(
        en: 'Assigned shopping item',
        sk: 'Priradená nákupná položka',
      ),
      'shopping_unassigned' => context.tr(
        en: 'Cleared shopping assignment',
        sk: 'Zrušené priradenie nákupnej položky',
      ),
      'shopping_unbought' => context.tr(
        en: 'Marked as not bought',
        sk: 'Označené ako nekúpené',
      ),
      'shopping_deleted' => context.tr(
        en: 'Deleted from shopping list',
        sk: 'Zmazané z nákupného zoznamu',
      ),
      _ => context.tr(
        en: 'Updated household item',
        sk: 'Upravená položka domácnosti',
      ),
    };
    return '$action: ${event.itemName}';
  }

  String _eventSubtitle(HouseholdActivityEvent event) {
    final parts = <String>[
      _actorLabel(event.userId),
      if (event.quantity != null && event.unit != null)
        '${_formatCompactNumber(event.quantity!)} ${event.unit}',
      _formatDateTime(event.createdAt),
      if (event.details != null && event.details!.trim().isNotEmpty)
        event.details!.trim(),
    ];
    return parts.join(' • ');
  }

  String _actorLabel(String userId) {
    if (userId == _currentUserId) {
      return context.tr(en: 'You', sk: 'Ty');
    }
    return _shortUserId(userId);
  }

  String _shortUserId(String userId) {
    if (userId.length <= 8) {
      return userId;
    }
    return '${userId.substring(0, 8)}...';
  }

  String _formatCompactNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  List<_HabitItem> _topHabitItems(
    List<HouseholdActivityEvent> events, {
    required Set<String> matchingTypes,
  }) {
    final counts = <String, int>{};

    for (final event in events) {
      if (!matchingTypes.contains(event.eventType)) {
        continue;
      }
      final key = event.itemName.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }

    final items =
        counts.entries
            .map(
              (entry) => _HabitItem(
                nameKey: entry.key,
                displayName: localizedIngredientDisplayName(context, entry.key),
                count: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) {
              return byCount;
            }
            return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
          });

    return items.take(3).toList();
  }

  List<_HabitItem> _wasteRiskItems(List<FoodItem> pantryItems) {
    final items =
        pantryItems
            .map((item) {
              final score = _wasteRiskScore(item);
              if (score <= 0) {
                return null;
              }
              return _HabitItem(
                nameKey: item.name.toLowerCase(),
                displayName: localizedIngredientDisplayName(context, item.name),
                count: score,
                detail: _wasteRiskLabel(item),
              );
            })
            .whereType<_HabitItem>()
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) {
              return byCount;
            }
            return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
          });

    return items.take(3).toList();
  }

  List<_HabitItem> _keepAtHomeItems(
    List<HouseholdActivityEvent> events,
    List<FoodItem> pantryItems,
    List<ShoppingListItem> shoppingItems,
  ) {
    final behaviorScores = <String, int>{};
    final displayNames = <String, String>{};

    for (final event in events) {
      final key = deriveFoodSignalInfo(event.itemName).itemKey;
      if (key.isEmpty) {
        continue;
      }
      displayNames.putIfAbsent(
        key,
        () => localizedIngredientDisplayName(context, event.itemName),
      );
      switch (event.eventType) {
        case 'shopping_added':
        case 'shopping_increased':
        case 'shopping_bought':
          behaviorScores.update(key, (value) => value + 2, ifAbsent: () => 2);
          break;
        case 'pantry_used':
        case 'pantry_opened':
          behaviorScores.update(key, (value) => value + 3, ifAbsent: () => 3);
          break;
      }
    }

    final pantryCoverage = <String, double>{};
    for (final item in pantryItems) {
      final key = deriveFoodSignalInfo(item.name).itemKey;
      if (key.isEmpty) {
        continue;
      }
      pantryCoverage.update(
        key,
        (value) => value + item.quantity,
        ifAbsent: () => item.quantity,
      );
      displayNames.putIfAbsent(
        key,
        () => localizedIngredientDisplayName(context, item.name),
      );
    }

    final shoppingKeys = shoppingItems
        .map((item) => deriveFoodSignalInfo(item.name).itemKey)
        .where((key) => key.isNotEmpty)
        .toSet();

    final suggestions =
        behaviorScores.entries
            .map((entry) {
              if (shoppingKeys.contains(entry.key)) {
                return null;
              }
              final onHand = pantryCoverage[entry.key] ?? 0;
              final stockPenalty = onHand <= 0
                  ? 4
                  : onHand <= 1
                  ? 2
                  : 0;
              final score = entry.value + stockPenalty;
              if (score < 4) {
                return null;
              }

              final detail = onHand <= 0
                  ? context.tr(
                      en: 'Shows up often, but you do not have it in pantry now.',
                      sk: 'Objavuje sa často, ale momentálne ju nemáš v špajzi.',
                    )
                  : onHand <= 1
                  ? context.tr(
                      en: 'Shows up often and you are running low.',
                      sk: 'Objavuje sa často a zásoba je už nízka.',
                    )
                  : context.tr(
                      en: 'Common item in your household routine.',
                      sk: 'Bežná položka v rytme vašej domácnosti.',
                    );

              return _HabitItem(
                nameKey: entry.key,
                displayName:
                    displayNames[entry.key] ??
                    localizedIngredientDisplayName(context, entry.key),
                count: score,
                detail: detail,
                suggestedQuantity: _suggestedPurchaseForItem(
                  entry.key,
                ).quantity,
                suggestedUnit: _suggestedPurchaseForItem(entry.key).unit,
              );
            })
            .whereType<_HabitItem>()
            .toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) {
              return byCount;
            }
            return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
          });

    return suggestions.take(3).toList();
  }

  _SuggestedPurchase _suggestedPurchaseForItem(String itemKey) {
    switch (itemKey) {
      case 'milk':
        return const _SuggestedPurchase(quantity: 1, unit: 'l');
      case 'cheese':
        return const _SuggestedPurchase(quantity: 200, unit: 'g');
      case 'yogurt':
        return const _SuggestedPurchase(quantity: 4, unit: 'pcs');
      case 'cream':
        return const _SuggestedPurchase(quantity: 1, unit: 'pcs');
      case 'butter':
        return const _SuggestedPurchase(quantity: 250, unit: 'g');
      case 'eggs':
        return const _SuggestedPurchase(quantity: 10, unit: 'pcs');
      case 'pasta':
        return const _SuggestedPurchase(quantity: 500, unit: 'g');
      case 'bread':
        return const _SuggestedPurchase(quantity: 1, unit: 'pcs');
      case 'flour':
        return const _SuggestedPurchase(quantity: 1, unit: 'kg');
      default:
        return const _SuggestedPurchase(quantity: 1, unit: 'pcs');
    }
  }

  int _wasteRiskScore(FoodItem item) {
    var score = 0;
    final daysToExpiry = _daysUntil(item.expirationDate);
    if (item.openedAt != null) {
      score += 3;
    }
    if (item.expirationDate != null) {
      if (daysToExpiry <= 0) {
        score += 4;
      } else if (daysToExpiry <= 2) {
        score += 3;
      } else if (daysToExpiry <= 5) {
        score += 1;
      }
    }
    return score;
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

  String _wasteRiskLabel(FoodItem item) {
    final daysToExpiry = _daysUntil(item.expirationDate);
    if (item.openedAt != null && daysToExpiry <= 0) {
      return context.tr(
        en: 'Opened and should be used immediately',
        sk: 'Otvorené a treba spotrebovať hneď',
      );
    }
    if (item.openedAt != null && daysToExpiry <= 2) {
      return context.tr(
        en: 'Opened and expiring soon',
        sk: 'Otvorené a čoskoro sa minie',
      );
    }
    if (item.openedAt != null) {
      return context.tr(
        en: 'Opened item to use soon',
        sk: 'Otvorená položka na skoré použitie',
      );
    }
    if (daysToExpiry <= 0) {
      return context.tr(en: 'Expired', sk: 'Po záruke');
    }
    return context.tr(
      en: 'Expires in $daysToExpiry days',
      sk: 'O $daysToExpiry dní',
    );
  }
}

class _HouseholdViewData {
  final List<HouseholdMember> members;
  final List<HouseholdActivityEvent> events;
  final List<FoodItem> pantryItems;
  final List<ShoppingListItem> shoppingItems;

  const _HouseholdViewData({
    required this.members,
    required this.events,
    required this.pantryItems,
    required this.shoppingItems,
  });
}

class _HabitItem {
  final String nameKey;
  final String displayName;
  final int count;
  final String? detail;
  final double suggestedQuantity;
  final String suggestedUnit;

  const _HabitItem({
    required this.nameKey,
    required this.displayName,
    required this.count,
    this.detail,
    this.suggestedQuantity = 1,
    this.suggestedUnit = 'pcs',
  });
}

class _SuggestedPurchase {
  final double quantity;
  final String unit;

  const _SuggestedPurchase({required this.quantity, required this.unit});
}

class _HabitSummaryCard extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<_HabitItem> items;
  final String? actionLabel;
  final Future<void> Function(_HabitItem item)? onAction;

  const _HabitSummaryCard({
    required this.title,
    required this.emptyMessage,
    required this.items,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyMessage, style: Theme.of(context).textTheme.bodySmall)
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.displayName)),
                          if (actionLabel != null && onAction != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => onAction!(item),
                              child: Text(actionLabel!),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            '${item.count}x',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      if (item.detail != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.detail!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
