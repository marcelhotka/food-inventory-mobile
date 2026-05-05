import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/supabase.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../food_items/domain/opened_food_guidance.dart';
import '../../household_activity/data/household_activity_repository.dart';
import '../../household_activity/domain/household_activity_event.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../../meal_plan/domain/meal_plan_entry.dart';
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
  late final MealPlanRepository _mealPlanRepository = MealPlanRepository(
    householdId: widget.household.id,
  );
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
    final mealPlanEntries = await _mealPlanRepository.getEntries();
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
      mealPlanEntries: mealPlanEntries,
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
      body: FutureBuilder<_HouseholdViewData>(
        future: _viewFuture,
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
                mealPlanEntries: <MealPlanEntry>[],
              );
          final members = viewData.members;
          final events = viewData.events;
          final pantryItems = viewData.pantryItems;
          final shoppingItems = viewData.shoppingItems;
          final mealPlanEntries = viewData.mealPlanEntries;
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
          final todayEvents = _todayHouseholdEvents(events);
          final todayContributors = _todayContributors(todayEvents);
          final personalTasks = _personalTasks(
            shoppingItems: shoppingItems,
            mealPlanEntries: mealPlanEntries,
            pantryItems: pantryItems,
          );
          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _HouseholdHeader(
                  householdName: widget.household.name,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 18),
                _HouseholdSummary(
                  memberCount: members.length,
                  todayEventsCount: todayEvents.length,
                  waitingCount: personalTasks.length,
                ),
                const SizedBox(height: 14),
                _HouseholdCodeCard(
                  householdId: widget.household.id,
                  onCopyCode: _copyCode,
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
                    (member) {
                      final isCurrentUser = member.userId == _currentUserId;
                      final roleLabel = member.role == 'owner'
                          ? context.tr(en: 'Owner', sk: 'Vlastník')
                          : context.tr(en: 'Member', sk: 'Člen');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(member.role == 'owner' ? 'O' : 'M'),
                            ),
                            title: Text(_actorLabel(member.userId)),
                            subtitle: Text(roleLabel),
                            trailing: isCurrentUser
                                ? _contextBadge(
                                    context,
                                    context.tr(en: 'You', sk: 'Ty'),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Text(
                  context.tr(en: 'Today in household', sk: 'Dnes v domácnosti'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (todayEvents.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.groups_2_outlined, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(
                              en: 'Nothing happened in the household yet today.',
                              sk: 'Dnes sa v domácnosti ešte nič neudialo.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: todayContributors
                                .map(
                                  (entry) => Chip(
                                    label: Text(
                                      '${_actorLabel(entry.userId)}: ${entry.count}',
                                    ),
                                    backgroundColor:
                                        entry.userId == _currentUserId
                                        ? const Color(0xFFE8EEF8)
                                        : null,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          ...todayEvents
                              .take(6)
                              .map(
                                (event) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3EEE4),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _todayEventIcon(event.eventType),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _actorLabel(event.userId),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (event.userId ==
                                                    _currentUserId)
                                                  _contextBadge(
                                                    context,
                                                    context.tr(
                                                      en: 'You',
                                                      sk: 'Ty',
                                                    ),
                                                  ),
                                                if (_isForCurrentUser(event))
                                                  _contextBadge(
                                                    context,
                                                    context.tr(
                                                      en: 'For you',
                                                      sk: 'Pre teba',
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (event.userId ==
                                                    _currentUserId ||
                                                _isForCurrentUser(event))
                                              const SizedBox(height: 4),
                                            const SizedBox(height: 2),
                                            Text(_todayEventText(event)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _relativeTimeLabel(
                                                event.createdAt,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  context.tr(en: 'Waiting for you', sk: 'Na teba čaká'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (personalTasks.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(
                              en: 'Nothing is waiting for you right now.',
                              sk: 'Momentálne na teba nič nečaká.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              en: 'Assigned shopping, cooking, or opened items to use soon will show up here.',
                              sk: 'Tu sa zobrazí priradený nákup, varenie alebo otvorené veci na skoré použitie.',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: personalTasks
                            .map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3EEE4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(task.icon, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              _contextBadge(
                                                context,
                                                context.tr(
                                                  en: 'For you',
                                                  sk: 'Pre teba',
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _urgencyBadge(context, task),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(task.subtitle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
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

  List<HouseholdActivityEvent> _todayHouseholdEvents(
    List<HouseholdActivityEvent> events,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return events
        .where((event) => event.createdAt.toLocal().isAfter(todayStart))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<_ContributorCount> _todayContributors(
    List<HouseholdActivityEvent> events,
  ) {
    final counts = <String, int>{};
    for (final event in events) {
      counts.update(event.userId, (value) => value + 1, ifAbsent: () => 1);
    }
    final items =
        counts.entries
            .map(
              (entry) =>
                  _ContributorCount(userId: entry.key, count: entry.value),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(3).toList();
  }

  IconData _todayEventIcon(String eventType) {
    switch (eventType) {
      case 'pantry_added':
      case 'pantry_increased':
      case 'pantry_updated':
        return Icons.inventory_2_outlined;
      case 'pantry_used':
        return Icons.restaurant_outlined;
      case 'pantry_opened':
        return Icons.lock_open_rounded;
      case 'shopping_added':
      case 'shopping_increased':
      case 'shopping_updated':
      case 'shopping_deleted':
        return Icons.shopping_cart_outlined;
      case 'shopping_bought':
        return Icons.shopping_bag_outlined;
      case 'shopping_assigned':
      case 'shopping_unassigned':
        return Icons.assignment_ind_outlined;
      default:
        return Icons.bolt_outlined;
    }
  }

  String _todayEventText(HouseholdActivityEvent event) {
    final quantityLabel = event.quantity != null && event.unit != null
        ? ' ${_formatCompactNumber(event.quantity!)} ${event.unit}'
        : '';
    switch (event.eventType) {
      case 'pantry_added':
      case 'pantry_increased':
        return context.tr(
          en: 'added to pantry: ${event.itemName}$quantityLabel',
          sk: 'pridal do špajze: ${event.itemName}$quantityLabel',
        );
      case 'pantry_used':
        return context.tr(
          en: 'used from pantry: ${event.itemName}$quantityLabel',
          sk: 'minul zo špajze: ${event.itemName}$quantityLabel',
        );
      case 'pantry_opened':
        return context.tr(
          en: 'opened: ${event.itemName}$quantityLabel',
          sk: 'otvoril: ${event.itemName}$quantityLabel',
        );
      case 'shopping_added':
      case 'shopping_increased':
        return context.tr(
          en: 'added to shopping: ${event.itemName}$quantityLabel',
          sk: 'pridal do nákupu: ${event.itemName}$quantityLabel',
        );
      case 'shopping_bought':
        return context.tr(
          en: 'marked as bought: ${event.itemName}',
          sk: 'označil ako kúpené: ${event.itemName}',
        );
      case 'shopping_assigned':
        return context.tr(
          en: 'assigned task: ${event.itemName}',
          sk: 'priradil úlohu: ${event.itemName}',
        );
      case 'shopping_unassigned':
        return context.tr(
          en: 'cleared assignment: ${event.itemName}',
          sk: 'zrušil priradenie: ${event.itemName}',
        );
      default:
        return _eventTitle(event);
    }
  }

  String _relativeTimeLabel(DateTime value) {
    final local = value.toLocal();
    final difference = DateTime.now().difference(local);
    if (difference.inMinutes < 1) {
      return context.tr(en: 'just now', sk: 'práve teraz');
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return context.tr(en: '$minutes min ago', sk: 'pred $minutes min');
    }
    if (difference.inHours < 12) {
      final hours = difference.inHours;
      return context.tr(en: '$hours h ago', sk: 'pred $hours h');
    }
    return context.tr(
      en: 'today at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
      sk: 'dnes o ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
    );
  }

  bool _isForCurrentUser(HouseholdActivityEvent event) {
    if (_currentUserId == null) {
      return false;
    }
    final details = event.details?.toLowerCase().trim() ?? '';
    return details.contains('assigned to me') ||
        details.contains('priradené mne') ||
        details.contains('priradene mne');
  }

  Widget _contextBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
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

  List<_PersonalTaskItem> _personalTasks({
    required List<ShoppingListItem> shoppingItems,
    required List<MealPlanEntry> mealPlanEntries,
    required List<FoodItem> pantryItems,
  }) {
    final tasks =
        <_PersonalTaskItem>[
          ..._shoppingTasks(shoppingItems),
          ..._mealPlanTasks(mealPlanEntries),
          ..._openedFoodTasks(pantryItems),
        ]..sort((a, b) {
          final byPriority = a.priority.compareTo(b.priority);
          if (byPriority != 0) {
            return byPriority;
          }
          return a.sortDate.compareTo(b.sortDate);
        });
    return tasks.take(4).toList();
  }

  List<_PersonalTaskItem> _shoppingTasks(List<ShoppingListItem> shoppingItems) {
    if (_currentUserId == null) {
      return const <_PersonalTaskItem>[];
    }
    return shoppingItems
        .where(
          (item) => !item.isBought && item.assignedToUserId == _currentUserId,
        )
        .map(
          (item) => _PersonalTaskItem(
            priority: 0,
            sortDate: item.updatedAt,
            icon: Icons.shopping_cart_outlined,
            title: context.tr(
              en: 'Buy: ${localizedIngredientDisplayName(context, item.name)}',
              sk: 'Kúpiť: ${localizedIngredientDisplayName(context, item.name)}',
            ),
            subtitle: context.tr(
              en: '${_formatCompactNumber(item.quantity)} ${item.unit} waiting in shopping list',
              sk: '${_formatCompactNumber(item.quantity)} ${item.unit} čaká v nákupnom zozname',
            ),
            urgency: _shoppingTaskUrgency(item),
          ),
        )
        .toList();
  }

  List<_PersonalTaskItem> _mealPlanTasks(List<MealPlanEntry> mealPlanEntries) {
    if (_currentUserId == null) {
      return const <_PersonalTaskItem>[];
    }
    return mealPlanEntries
        .where(
          (entry) =>
              !_isPastMeal(entry) && entry.assignedCookUserId == _currentUserId,
        )
        .map(
          (entry) => _PersonalTaskItem(
            priority: 1,
            sortDate: entry.scheduledFor,
            icon: Icons.restaurant_menu_outlined,
            title: context.tr(
              en: 'Cook: ${entry.recipeName}',
              sk: 'Variť: ${entry.recipeName}',
            ),
            subtitle: context.tr(
              en: '${_mealTypeLabel(entry.mealType)} • ${_formatScheduledDay(entry.scheduledFor)} • ${entry.servings} servings',
              sk: '${_mealTypeLabel(entry.mealType)} • ${_formatScheduledDay(entry.scheduledFor)} • ${entry.servings} porcie',
            ),
            urgency: _dateUrgency(entry.scheduledFor),
          ),
        )
        .toList();
  }

  List<_PersonalTaskItem> _openedFoodTasks(List<FoodItem> pantryItems) {
    return pantryItems
        .where((item) => item.openedAt != null && openedDaysLeft(item) <= 1)
        .map(
          (item) => _PersonalTaskItem(
            priority: openedDaysLeft(item) <= 0 ? 0 : 2,
            sortDate: adjustedExpirationAfterOpening(item) ?? item.updatedAt,
            icon: Icons.timelapse_outlined,
            title: context.tr(
              en: 'Use soon: ${localizedIngredientDisplayName(context, item.name)}',
              sk: 'Minúť čoskoro: ${localizedIngredientDisplayName(context, item.name)}',
            ),
            subtitle: _openedTaskSubtitle(item),
            urgency: _openedFoodUrgency(item),
          ),
        )
        .toList();
  }

  _TaskUrgency _shoppingTaskUrgency(ShoppingListItem item) {
    final anchor = DateTime(
      item.updatedAt.year,
      item.updatedAt.month,
      item.updatedAt.day,
    );
    return _dateUrgency(anchor);
  }

  _TaskUrgency _openedFoodUrgency(FoodItem item) {
    final daysLeft = openedDaysLeft(item);
    if (daysLeft <= 0) {
      return _TaskUrgency.today;
    }
    if (daysLeft == 1) {
      return _TaskUrgency.tomorrow;
    }
    return _TaskUrgency.upcoming;
  }

  _TaskUrgency _dateUrgency(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final difference = target.difference(today).inDays;
    if (difference < 0) {
      return _TaskUrgency.overdue;
    }
    if (difference == 0) {
      return _TaskUrgency.today;
    }
    if (difference == 1) {
      return _TaskUrgency.tomorrow;
    }
    return _TaskUrgency.upcoming;
  }

  bool _isPastMeal(MealPlanEntry entry) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduled = DateTime(
      entry.scheduledFor.year,
      entry.scheduledFor.month,
      entry.scheduledFor.day,
    );
    return scheduled.isBefore(today);
  }

  String _mealTypeLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return context.tr(en: 'Breakfast', sk: 'Raňajky');
      case 'lunch':
        return context.tr(en: 'Lunch', sk: 'Obed');
      case 'dinner':
        return context.tr(en: 'Dinner', sk: 'Večera');
      case 'snack':
        return context.tr(en: 'Snack', sk: 'Desiata');
      default:
        return mealType;
    }
  }

  String _formatScheduledDay(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final dayDifference = target.difference(today).inDays;
    if (dayDifference == 0) {
      return context.tr(en: 'today', sk: 'dnes');
    }
    if (dayDifference == 1) {
      return context.tr(en: 'tomorrow', sk: 'zajtra');
    }
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.';
  }

  String _openedTaskSubtitle(FoodItem item) {
    final daysLeft = openedDaysLeft(item);
    final useBy = adjustedExpirationAfterOpening(item);
    final dateLabel = useBy == null
        ? null
        : '${useBy.day.toString().padLeft(2, '0')}.${useBy.month.toString().padLeft(2, '0')}.';
    if (daysLeft <= 0) {
      return context.tr(
        en: 'Opened item should be used today${dateLabel == null ? '' : ' • by $dateLabel'}',
        sk: 'Otvorenú položku treba minúť dnes${dateLabel == null ? '' : ' • do $dateLabel'}',
      );
    }
    return context.tr(
      en: 'Opened item should be used tomorrow${dateLabel == null ? '' : ' • by $dateLabel'}',
      sk: 'Otvorenú položku treba minúť zajtra${dateLabel == null ? '' : ' • do $dateLabel'}',
    );
  }

  Widget _urgencyBadge(BuildContext context, _PersonalTaskItem task) {
    final (label, color) = switch (task.urgency) {
      _TaskUrgency.overdue => (
        context.tr(en: 'Overdue', sk: 'Mešká'),
        const Color(0xFFF7D9D6),
      ),
      _TaskUrgency.today => (
        context.tr(en: 'Today', sk: 'Dnes'),
        const Color(0xFFF6E7C8),
      ),
      _TaskUrgency.tomorrow => (
        context.tr(en: 'Tomorrow', sk: 'Zajtra'),
        const Color(0xFFE8EEF8),
      ),
      _TaskUrgency.upcoming => (
        context.tr(en: 'Soon', sk: 'Čoskoro'),
        const Color(0xFFE7F2E8),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HouseholdViewData {
  final List<HouseholdMember> members;
  final List<HouseholdActivityEvent> events;
  final List<FoodItem> pantryItems;
  final List<ShoppingListItem> shoppingItems;
  final List<MealPlanEntry> mealPlanEntries;

  const _HouseholdViewData({
    required this.members,
    required this.events,
    required this.pantryItems,
    required this.shoppingItems,
    required this.mealPlanEntries,
  });
}

class _HouseholdHeader extends StatelessWidget {
  final String householdName;
  final VoidCallback onBack;

  const _HouseholdHeader({
    required this.householdName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: SafoColors.surface,
              borderRadius: BorderRadius.circular(SafoRadii.pill),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(SafoRadii.pill),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: SafoColors.surface,
                    borderRadius: BorderRadius.circular(SafoRadii.pill),
                    border: Border.all(color: SafoColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: SafoColors.textPrimary,
                  ),
                ),
              ),
            ),
            const Spacer(),
            const SafoLogo(
              variant: SafoLogoVariant.pill,
              height: 28,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          context.tr(en: 'Shared home flow', sk: 'Spoločný flow domácnosti'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: SafoColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr(en: 'Household', sk: 'Domácnosť'),
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

class _HouseholdSummary extends StatelessWidget {
  final int memberCount;
  final int todayEventsCount;
  final int waitingCount;

  const _HouseholdSummary({
    required this.memberCount,
    required this.todayEventsCount,
    required this.waitingCount,
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
        _HouseholdSummaryCard(
          label: context.tr(en: 'Members', sk: 'Členovia'),
          value: memberCount.toString(),
          background: SafoColors.surface,
          valueColor: SafoColors.textPrimary,
        ),
        _HouseholdSummaryCard(
          label: context.tr(en: 'Today', sk: 'Dnes'),
          value: todayEventsCount.toString(),
          background: SafoColors.primarySoft,
          valueColor: SafoColors.primary,
        ),
        _HouseholdSummaryCard(
          label: context.tr(en: 'For you', sk: 'Pre teba'),
          value: waitingCount.toString(),
          background: SafoColors.accentSoft,
          valueColor: SafoColors.accent,
        ),
      ],
    );
  }
}

class _HouseholdSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color background;
  final Color valueColor;

  const _HouseholdSummaryCard({
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

class _HouseholdCodeCard extends StatelessWidget {
  final String householdId;
  final VoidCallback onCopyCode;

  const _HouseholdCodeCard({
    required this.householdId,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                en: 'Invite another member',
                sk: 'Pozvi ďalšieho člena',
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                en: 'Share this household code with your family so they can join the same pantry, shopping list, and meal plan.',
                sk: 'Zdieľaj tento kód domácnosti s rodinou, aby sa pripojili do rovnakej špajze, nákupu a jedálnička.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SafoColors.textSecondary,
                height: 1.45,
              ),
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
                householdId,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onCopyCode,
              icon: const Icon(Icons.copy_outlined),
              label: Text(
                context.tr(en: 'Copy code', sk: 'Kopírovať kód'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributorCount {
  final String userId;
  final int count;

  const _ContributorCount({required this.userId, required this.count});
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

class _PersonalTaskItem {
  final int priority;
  final DateTime sortDate;
  final IconData icon;
  final String title;
  final String subtitle;
  final _TaskUrgency urgency;

  const _PersonalTaskItem({
    required this.priority,
    required this.sortDate,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.urgency,
  });
}

enum _TaskUrgency { overdue, today, tomorrow, upcoming }

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
