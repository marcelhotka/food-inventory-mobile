import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../../food_items/data/food_items_repository.dart';
import '../../food_items/domain/food_item.dart';
import '../../food_items/domain/opened_food_guidance.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/domain/shopping_list_item.dart';
import '../domain/quick_command_models.dart';

class QuickCommandService {
  QuickCommandService({
    required String householdId,
    FoodItemsRepository? foodItemsRepository,
    ShoppingListRepository? shoppingListRepository,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _foodItemsRepository =
           foodItemsRepository ?? FoodItemsRepository(householdId: householdId),
       _shoppingListRepository =
           shoppingListRepository ??
           ShoppingListRepository(householdId: householdId),
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final FoodItemsRepository _foodItemsRepository;
  final ShoppingListRepository _shoppingListRepository;
  final SupabaseClient? _client;

  QuickCommandPreview preview(String rawCommand) {
    final parsedCommands = _parseMany(rawCommand);
    if (parsedCommands.isEmpty ||
        parsedCommands.every((parsed) => parsed.items.isEmpty)) {
      throw const QuickCommandException(
        'V tomto príkaze sa mi nepodarilo rozpoznať žiadnu potravinu.',
      );
    }

    return QuickCommandPreview(commands: parsedCommands);
  }

  Future<QuickCommandExecutionResult> execute(String rawCommand) async {
    final user = _client?.auth.currentUser;
    if (user == null) {
      throw const QuickCommandException('Musíš byť prihlásený.');
    }

    final parsedCommands = preview(rawCommand).commands;

    final details = <String>[];
    var changedPantry = false;
    var changedShoppingList = false;

    for (final parsed in parsedCommands) {
      if (parsed.items.isEmpty) {
        continue;
      }
      final result = await switch (parsed.intent) {
        QuickCommandIntent.addToPantry => _addToPantry(user.id, parsed.items),
        QuickCommandIntent.addToShoppingList => _addToShoppingList(
          user.id,
          parsed.items,
        ),
        QuickCommandIntent.consumeFromPantry => _consumeFromPantry(
          parsed.items,
        ),
        QuickCommandIntent.markOpened => _markOpened(parsed.items),
      };
      details.addAll(result.details);
      changedPantry = changedPantry || result.changedPantry;
      changedShoppingList = changedShoppingList || result.changedShoppingList;
    }

    return QuickCommandExecutionResult(
      summary: parsedCommands.length > 1
          ? 'Príkaz bol vykonaný vo viacerých krokoch.'
          : (changedShoppingList && !changedPantry
                ? 'Príkaz bol vykonaný pre nákupný zoznam.'
                : changedPantry && !changedShoppingList
                ? 'Príkaz bol vykonaný pre špajzu.'
                : 'Príkaz bol úspešne vykonaný.'),
      details: details,
      changedPantry: changedPantry,
      changedShoppingList: changedShoppingList,
    );
  }

  List<QuickCommandParseResult> _parseMany(String rawCommand) {
    final commandWithBoundaries = rawCommand.replaceAllMapped(
      RegExp(
        r'\s+(?:a|and)\s+(?=pridaj|kup|dokup|minuli sa|minulo sa|minul sa|dosli|došli|otvoril som|otvorila som|otvorene je)',
        caseSensitive: false,
      ),
      (_) => '; ',
    );
    final clauses = commandWithBoundaries
        .split(RegExp(r'\s*(?:;|\.|\n|\s+potom\s+)\s*', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    return clauses.map(_parse).toList();
  }

  QuickCommandParseResult _parse(String rawCommand) {
    final normalized = rawCommand.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw const QuickCommandException('Najprv zadaj príkaz.');
    }

    final prefixes = <String, QuickCommandIntent>{
      'pridaj do shopping list': QuickCommandIntent.addToShoppingList,
      'pridaj do shoppingu': QuickCommandIntent.addToShoppingList,
      'pridaj na nakupny zoznam': QuickCommandIntent.addToShoppingList,
      'pridaj na nákupný zoznam': QuickCommandIntent.addToShoppingList,
      'kup': QuickCommandIntent.addToShoppingList,
      'dokup': QuickCommandIntent.addToShoppingList,
      'minuli sa': QuickCommandIntent.consumeFromPantry,
      'minulo sa': QuickCommandIntent.consumeFromPantry,
      'minul sa': QuickCommandIntent.consumeFromPantry,
      'dosli': QuickCommandIntent.consumeFromPantry,
      'došli': QuickCommandIntent.consumeFromPantry,
      'otvoril som': QuickCommandIntent.markOpened,
      'otvorila som': QuickCommandIntent.markOpened,
      'otvorene je': QuickCommandIntent.markOpened,
      'pridaj': QuickCommandIntent.addToPantry,
    };

    for (final entry in prefixes.entries) {
      if (normalized.startsWith(entry.key)) {
        final body = rawCommand.trim().substring(entry.key.length).trim();
        return QuickCommandParseResult(
          intent: entry.value,
          items: _parseItems(body),
        );
      }
    }

    throw const QuickCommandException(
      'Skús príkaz ako „pridaj 2 jogurty a mlieko“, „minuli sa vajcia“ alebo „otvoril som syr“.',
    );
  }

  List<QuickCommandItem> _parseItems(String rawBody) {
    final body = rawBody.trim();
    if (body.isEmpty) {
      return const [];
    }

    final parts = body
        .split(
          RegExp(r'\s*(?:,|\sa\s|\saj\s|\sand\s)\s*', caseSensitive: false),
        )
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    final items = <QuickCommandItem>[];
    for (final part in parts) {
      final trailingQuantityItem = _parseTrailingQuantityItem(part);
      if (trailingQuantityItem != null) {
        items.add(trailingQuantityItem);
        continue;
      }

      final wordMatch = RegExp(
        r'^(pol|jeden|jedna|jedno|dva|dve|tri|styri|štyri|pat|päť|sest|šesť|sedem|osem|devat|deväť|desat|desať)\s+([^\d\s]+)?\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(part);
      if (wordMatch != null) {
        final quantity = _wordQuantity(wordMatch.group(1)!);
        final unitOrName = (wordMatch.group(2) ?? '').trim();
        final trailing = (wordMatch.group(3) ?? '').trim();
        final parsedUnit = _normalizeUnit(unitOrName);
        if (_looksLikeKnownUnit(parsedUnit)) {
          final expiration = _extractExpiration(trailing);
          final cleanedTrailing = _removeExpirationPhrase(trailing);
          items.add(
            QuickCommandItem(
              name: _extractStorage(_cleanItemName(cleanedTrailing)).itemName,
              quantity: quantity,
              unit: parsedUnit,
              expirationDate: expiration,
              storageLocation: _extractStorage(
                _cleanItemName(cleanedTrailing),
              ).storage,
            ),
          );
        } else {
          final combined = '$unitOrName $trailing';
          final expiration = _extractExpiration(combined);
          final cleanedCombined = _removeExpirationPhrase(combined);
          final extracted = _extractStorage(_cleanItemName(cleanedCombined));
          items.add(
            QuickCommandItem(
              name: extracted.itemName,
              quantity: quantity,
              unit: 'pcs',
              storageLocation: extracted.storage,
              expirationDate: expiration,
            ),
          );
        }
        continue;
      }

      final match = RegExp(
        r'^(\d+(?:[.,]\d+)?)\s*([^\d\s]+)?\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(part);

      if (match != null) {
        final quantity = double.parse(match.group(1)!.replaceAll(',', '.'));
        final unitOrName = (match.group(2) ?? '').trim();
        final trailing = match.group(3)!.trim();
        final parsedUnit = _normalizeUnit(unitOrName);
        if (_looksLikeKnownUnit(parsedUnit)) {
          final expiration = _extractExpiration(trailing);
          final cleanedTrailing = _removeExpirationPhrase(trailing);
          final extracted = _extractStorage(_cleanItemName(cleanedTrailing));
          items.add(
            QuickCommandItem(
              name: extracted.itemName,
              quantity: quantity,
              unit: parsedUnit,
              storageLocation: extracted.storage,
              expirationDate: expiration,
            ),
          );
        } else {
          final combined = '$unitOrName $trailing';
          final expiration = _extractExpiration(combined);
          final cleanedCombined = _removeExpirationPhrase(combined);
          final extracted = _extractStorage(_cleanItemName(cleanedCombined));
          items.add(
            QuickCommandItem(
              name: extracted.itemName,
              quantity: quantity,
              unit: 'pcs',
              storageLocation: extracted.storage,
              expirationDate: expiration,
            ),
          );
        }
        continue;
      }

      final expiration = _extractExpiration(part);
      final cleanedPart = _removeExpirationPhrase(part);
      final extracted = _extractStorage(_cleanItemName(cleanedPart));
      items.add(
        QuickCommandItem(
          name: extracted.itemName,
          quantity: 1,
          unit: _defaultUnitForName(extracted.itemName),
          storageLocation: extracted.storage,
          expirationDate: expiration,
        ),
      );
    }

    return items;
  }

  QuickCommandItem? _parseTrailingQuantityItem(String part) {
    final numericMatch = RegExp(
      r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*([^\d\s]+)?$',
      caseSensitive: false,
    ).firstMatch(part);
    if (numericMatch != null) {
      final rawName = numericMatch.group(1)!.trim();
      final quantity = double.parse(
        numericMatch.group(2)!.replaceAll(',', '.'),
      );
      final unit = _normalizeUnit((numericMatch.group(3) ?? '').trim());
      if (_looksLikeKnownUnit(unit)) {
        return _buildCommandItem(
          rawName: rawName,
          quantity: quantity,
          unit: unit,
        );
      }
    }

    final wordMatch = RegExp(
      r'^(.+?)\s+(pol|jeden|jedna|jedno|dva|dve|tri|styri|štyri|pat|päť|sest|šesť|sedem|osem|devat|deväť|desat|desať)\s+([^\d\s]+)?$',
      caseSensitive: false,
    ).firstMatch(part);
    if (wordMatch != null) {
      final rawName = wordMatch.group(1)!.trim();
      final quantity = _wordQuantity(wordMatch.group(2)!);
      final unit = _normalizeUnit((wordMatch.group(3) ?? '').trim());
      if (_looksLikeKnownUnit(unit)) {
        return _buildCommandItem(
          rawName: rawName,
          quantity: quantity,
          unit: unit,
        );
      }
    }

    return null;
  }

  QuickCommandItem _buildCommandItem({
    required String rawName,
    required double quantity,
    required String unit,
  }) {
    final expiration = _extractExpiration(rawName);
    final cleanedName = _removeExpirationPhrase(rawName);
    final extracted = _extractStorage(_cleanItemName(cleanedName));
    return QuickCommandItem(
      name: extracted.itemName,
      quantity: quantity,
      unit: unit,
      storageLocation: extracted.storage,
      expirationDate: expiration,
    );
  }

  Future<QuickCommandExecutionResult> _addToPantry(
    String userId,
    List<QuickCommandItem> items,
  ) async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
    final now = DateTime.now().toUtc();
    final details = <String>[];
    var changedShoppingList = false;

    for (final commandItem in items) {
      final existing = _findMatchingPantryItem(pantryItems, commandItem);
      if (existing == null) {
        final created = await _foodItemsRepository.addFoodItem(
          FoodItem(
            id: '',
            userId: userId,
            householdId: _householdId,
            name: commandItem.name.trim(),
            barcode: null,
            category: 'other',
            storageLocation: commandItem.storageLocation ?? 'pantry',
            quantity: commandItem.quantity,
            lowStockThreshold: null,
            unit: commandItem.unit,
            expirationDate: commandItem.expirationDate,
            openedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        pantryItems.add(created);
        details.add(
          'Pridané do ${_storageLabel(commandItem.storageLocation ?? 'pantry')}: ${_formatQuantity(commandItem.quantity)} ${commandItem.unit} ${commandItem.name}${commandItem.expirationDate != null ? ' (${_formatDate(commandItem.expirationDate!)})' : ''}.',
        );
        final shoppingAdjusted = await _adjustShoppingAgainstPantry(
          shoppingItems,
          commandItem,
        );
        changedShoppingList = changedShoppingList || shoppingAdjusted;
        continue;
      }

      final incomingInExistingUnit = _convertQuantity(
        quantity: commandItem.quantity,
        fromUnit: commandItem.unit,
        toUnit: existing.unit,
      );
      if (incomingInExistingUnit == null) {
        throw QuickCommandException(
          'Položku ${commandItem.name} sa nepodarilo zlúčiť, pretože jednotky ${commandItem.unit} a ${existing.unit} nie sú kompatibilné.',
        );
      }

      final updated = await _foodItemsRepository.editFoodItem(
        existing.copyWith(
          quantity: existing.quantity + incomingInExistingUnit,
          expirationDate: commandItem.expirationDate ?? existing.expirationDate,
          updatedAt: now,
        ),
      );
      final index = pantryItems.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        pantryItems[index] = updated;
      }
      details.add(
        'Aktualizované ${updated.name} na ${_formatQuantity(updated.quantity)} ${updated.unit} v ${_storageLabel(updated.storageLocation)}.',
      );
      final shoppingAdjusted = await _adjustShoppingAgainstPantry(
        shoppingItems,
        commandItem,
      );
      changedShoppingList = changedShoppingList || shoppingAdjusted;
    }

    return QuickCommandExecutionResult(
      summary: 'Príkaz bol vykonaný pre špajzu.',
      details: details,
      changedPantry: true,
      changedShoppingList: changedShoppingList,
    );
  }

  Future<QuickCommandExecutionResult> _addToShoppingList(
    String userId,
    List<QuickCommandItem> items,
  ) async {
    final shoppingItems = await _shoppingListRepository.getShoppingListItems();
    final now = DateTime.now().toUtc();
    final details = <String>[];

    for (final commandItem in items) {
      final existing = _findMatchingShoppingItem(shoppingItems, commandItem);
      if (existing == null) {
        final created = await _shoppingListRepository.addShoppingListItem(
          ShoppingListItem(
            id: '',
            userId: userId,
            householdId: _householdId,
            name: commandItem.name.trim(),
            quantity: commandItem.quantity,
            unit: commandItem.unit,
            source: ShoppingListItem.sourceManual,
            isBought: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        shoppingItems.add(created);
        details.add(
          'Pridané do nákupného zoznamu: ${_formatQuantity(commandItem.quantity)} ${commandItem.unit} ${commandItem.name}.',
        );
        continue;
      }

      final incomingInExistingUnit = _convertQuantity(
        quantity: commandItem.quantity,
        fromUnit: commandItem.unit,
        toUnit: existing.unit,
      );
      if (incomingInExistingUnit == null) {
        throw QuickCommandException(
          'Položku ${commandItem.name} sa nepodarilo zlúčiť v nákupnom zozname, pretože jednotky ${commandItem.unit} a ${existing.unit} nie sú kompatibilné.',
        );
      }

      final updated = await _shoppingListRepository.editShoppingListItem(
        existing.copyWith(
          quantity: existing.quantity + incomingInExistingUnit,
          updatedAt: now,
        ),
      );
      final index = shoppingItems.indexWhere((item) => item.id == existing.id);
      if (index >= 0) {
        shoppingItems[index] = updated;
      }
      details.add(
        'Aktualizované ${updated.name} na ${_formatQuantity(updated.quantity)} ${updated.unit} v nákupnom zozname.',
      );
    }

    return QuickCommandExecutionResult(
      summary: 'Príkaz bol vykonaný pre nákupný zoznam.',
      details: details,
      changedPantry: false,
      changedShoppingList: true,
    );
  }

  Future<QuickCommandExecutionResult> _consumeFromPantry(
    List<QuickCommandItem> items,
  ) async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final details = <String>[];
    final now = DateTime.now().toUtc();

    for (final commandItem in items) {
      var remaining = commandItem.quantity;
      final matches =
          pantryItems
              .where((item) => _matchesCommandItem(item.name, commandItem.name))
              .toList()
            ..sort((a, b) {
              if (a.openedAt != null && b.openedAt == null) return -1;
              if (a.openedAt == null && b.openedAt != null) return 1;
              final aExpiry = a.expirationDate;
              final bExpiry = b.expirationDate;
              if (aExpiry == null && bExpiry == null) return 0;
              if (aExpiry == null) return 1;
              if (bExpiry == null) return -1;
              return aExpiry.compareTo(bExpiry);
            });

      if (matches.isEmpty) {
        details.add('V špajzi sa nenašla zhoda pre ${commandItem.name}.');
        continue;
      }

      for (final item in matches) {
        if (remaining <= 0.0001) {
          break;
        }

        final availableInCommandUnit = _convertQuantity(
          quantity: item.quantity,
          fromUnit: item.unit,
          toUnit: commandItem.unit,
        );
        if (availableInCommandUnit == null || availableInCommandUnit <= 0) {
          continue;
        }

        final consumedInCommandUnit = remaining < availableInCommandUnit
            ? remaining
            : availableInCommandUnit;
        final consumedInItemUnit = _convertQuantity(
          quantity: consumedInCommandUnit,
          fromUnit: commandItem.unit,
          toUnit: item.unit,
        );
        if (consumedInItemUnit == null) {
          continue;
        }

        final nextQuantity = item.quantity - consumedInItemUnit;
        if (nextQuantity <= 0.0001) {
          await _foodItemsRepository.removeFoodItem(item.id);
          pantryItems.removeWhere((candidate) => candidate.id == item.id);
        } else {
          final updated = await _foodItemsRepository.editFoodItem(
            item.copyWith(quantity: nextQuantity, updatedAt: now),
          );
          final index = pantryItems.indexWhere(
            (candidate) => candidate.id == item.id,
          );
          if (index >= 0) {
            pantryItems[index] = updated;
          }
        }
        remaining -= consumedInCommandUnit;
      }

      if (remaining > 0.0001) {
        details.add(
          'Used ${_formatQuantity(commandItem.quantity - remaining)} ${commandItem.unit} ${commandItem.name}, but some amount was missing.',
        );
      } else {
        details.add(
          'Použité zo špajze: ${_formatQuantity(commandItem.quantity)} ${commandItem.unit} ${commandItem.name}.',
        );
      }
    }

    return QuickCommandExecutionResult(
      summary: 'Príkaz bol vykonaný pre spotrebu zo špajze.',
      details: details,
      changedPantry: true,
      changedShoppingList: false,
    );
  }

  Future<QuickCommandExecutionResult> _markOpened(
    List<QuickCommandItem> items,
  ) async {
    final pantryItems = await _foodItemsRepository.getFoodItems();
    final details = <String>[];
    final now = DateTime.now().toUtc();

    for (final commandItem in items) {
      final match = pantryItems.firstWhere(
        (item) =>
            item.openedAt == null &&
            _matchesCommandItem(item.name, commandItem.name),
        orElse: () => FoodItem(
          id: '',
          userId: '',
          householdId: null,
          name: '',
          barcode: null,
          category: 'other',
          storageLocation: 'pantry',
          quantity: 0,
          lowStockThreshold: null,
          unit: 'pcs',
          expirationDate: null,
          openedAt: null,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      if (match.id.isEmpty) {
        details.add('Nenašla sa neotvorená položka pre ${commandItem.name}.');
        continue;
      }

      if (_isPieceUnit(match.unit) &&
          match.quantity > commandItem.quantity &&
          commandItem.quantity > 0.0001) {
        final openedItem = await _foodItemsRepository.addFoodItem(
          match.copyWith(
            id: '',
            quantity: commandItem.quantity,
            expirationDate: adjustedExpirationAfterOpening(
              match,
              openedDate: now,
            ),
            openedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final remainingItem = await _foodItemsRepository.editFoodItem(
          match.copyWith(
            quantity: match.quantity - commandItem.quantity,
            updatedAt: now,
          ),
        );
        pantryItems
          ..removeWhere((item) => item.id == match.id)
          ..addAll([openedItem, remainingItem]);
        details.add(
          'Označené ako otvorené: ${_formatQuantity(commandItem.quantity)} ${match.unit} z ${match.name}.',
        );
        continue;
      }

      final updated = await _foodItemsRepository.editFoodItem(
        match.copyWith(
          expirationDate: adjustedExpirationAfterOpening(
            match,
            openedDate: now,
          ),
          openedAt: now,
          updatedAt: now,
        ),
      );
      final index = pantryItems.indexWhere((item) => item.id == match.id);
      if (index >= 0) {
        pantryItems[index] = updated;
      }
      details.add('Označené ako otvorené: ${match.name}.');
    }

    return QuickCommandExecutionResult(
      summary: 'Príkaz bol vykonaný pre otvorené položky.',
      details: details,
      changedPantry: true,
      changedShoppingList: false,
    );
  }

  FoodItem? _findMatchingPantryItem(
    List<FoodItem> items,
    QuickCommandItem commandItem,
  ) {
    for (final item in items) {
      if (item.openedAt != null) {
        continue;
      }
      if (commandItem.storageLocation != null &&
          item.storageLocation != commandItem.storageLocation) {
        continue;
      }
      if (!_matchesCommandItem(item.name, commandItem.name)) {
        continue;
      }
      if (_convertQuantity(
            quantity: commandItem.quantity,
            fromUnit: commandItem.unit,
            toUnit: item.unit,
          ) !=
          null) {
        return item;
      }
    }
    return null;
  }

  ShoppingListItem? _findMatchingShoppingItem(
    List<ShoppingListItem> items,
    QuickCommandItem commandItem,
  ) {
    for (final item in items) {
      if (!_matchesCommandItem(item.name, commandItem.name)) {
        continue;
      }
      if (_convertQuantity(
            quantity: commandItem.quantity,
            fromUnit: commandItem.unit,
            toUnit: item.unit,
          ) !=
          null) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _adjustShoppingAgainstPantry(
    List<ShoppingListItem> shoppingItems,
    QuickCommandItem commandItem,
  ) async {
    final now = DateTime.now().toUtc();
    var changed = false;

    for (final item in [...shoppingItems]) {
      if (!_matchesCommandItem(item.name, commandItem.name)) {
        continue;
      }

      final addedInShoppingUnit = _convertQuantity(
        quantity: commandItem.quantity,
        fromUnit: commandItem.unit,
        toUnit: item.unit,
      );
      if (addedInShoppingUnit == null) {
        continue;
      }

      changed = true;
      final nextQuantity = item.quantity - addedInShoppingUnit;
      if (nextQuantity <= 0.0001) {
        await _shoppingListRepository.removeShoppingListItem(item.id);
        shoppingItems.removeWhere((candidate) => candidate.id == item.id);
      } else {
        final updated = await _shoppingListRepository.editShoppingListItem(
          item.copyWith(quantity: nextQuantity, updatedAt: now),
        );
        final index = shoppingItems.indexWhere(
          (candidate) => candidate.id == item.id,
        );
        if (index >= 0) {
          shoppingItems[index] = updated;
        }
      }
    }

    return changed;
  }

  bool _matchesCommandItem(String existingName, String commandName) {
    if (_canonicalFoodKey(existingName) != _canonicalFoodKey(commandName)) {
      return false;
    }

    return _dietaryModifierKey(existingName) ==
        _dietaryModifierKey(commandName);
  }

  String _canonicalFoodKey(String value) {
    final normalized = _normalizeName(value);
    const aliases = {
      'vajce': 'eggs',
      'vajcia': 'eggs',
      'vajec': 'eggs',
      'egg': 'eggs',
      'eggs': 'eggs',
      'mlieko': 'milk',
      'mlieka': 'milk',
      'milk': 'milk',
      'syr': 'cheese',
      'syra': 'cheese',
      'syru': 'cheese',
      'cheese': 'cheese',
      'jogurt': 'yogurt',
      'jogurty': 'yogurt',
      'jogurtu': 'yogurt',
      'jogurtov': 'yogurt',
      'jogurtybiele': 'yogurt',
      'fazula': 'beans',
      'fazule': 'beans',
      'fazulu': 'beans',
      'konzervafazule': 'beans',
      'konzervyfazule': 'beans',
      'beans': 'beans',
      'vodu': 'water',
      'voda': 'water',
      'water': 'water',
      'olej': 'oil',
      'oleja': 'oil',
      'oil': 'oil',
      'dzus': 'juice',
      'dzusu': 'juice',
      'juice': 'juice',
      'chlieb': 'bread',
      'chleba': 'bread',
      'bread': 'bread',
      'pecivo': 'bread',
    };
    final exactMatch = aliases[normalized];
    if (exactMatch != null) {
      return exactMatch;
    }

    if (normalized.contains('chlieb') ||
        normalized.contains('chleba') ||
        normalized.contains('pecivo') ||
        normalized.contains('baget') ||
        normalized.contains('bread')) {
      return 'bread';
    }
    if (normalized.contains('mlieko') || normalized.contains('mlieka')) {
      return 'milk';
    }
    if (normalized.contains('syr') || normalized.contains('syra')) {
      return 'cheese';
    }

    return normalized;
  }

  String _dietaryModifierKey(String value) {
    final normalized = _normalizeName(value);
    final modifiers = <String>[];
    if (normalized.contains('bezlepk') ||
        normalized.contains('glutenfree') ||
        normalized.contains('glutenfrei')) {
      modifiers.add('gluten_free');
    }
    if (normalized.contains('bezlakt') || normalized.contains('lactosefree')) {
      modifiers.add('lactose_free');
    }
    if (normalized.contains('bezvajec') ||
        normalized.contains('nahradavajec')) {
      modifiers.add('egg_free');
    }
    return modifiers.join('|');
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
    if (const {
      'pcs',
      'pc',
      'piece',
      'pieces',
      'ks',
      'kus',
      'kusy',
      'kusov',
      'balenie',
      'balenia',
      'balicek',
      'balicky',
      'konzerva',
      'konzervy',
      'konzerv',
      'plechovka',
      'plechovky',
      'flasa',
      'flase',
      'flas',
      'flias',
    }.contains(normalized)) {
      return 'pcs';
    }
    if (const {'g', 'gram', 'gramy', 'gramov', 'gramu'}.contains(normalized)) {
      return 'g';
    }
    if (const {
      'kg',
      'kilo',
      'kilogram',
      'kilogramy',
      'kilogramov',
      'kil',
    }.contains(normalized)) {
      return 'kg';
    }
    if (const {
      'ml',
      'mililiter',
      'mililitre',
      'mililitrov',
      'mililitru',
    }.contains(normalized)) {
      return 'ml';
    }
    if (const {'l', 'liter', 'litra', 'litre', 'litrov'}.contains(normalized)) {
      return 'l';
    }
    return normalized;
  }

  DateTime? _extractExpiration(String value) {
    final normalized = _normalizeName(value);
    if (normalized.contains('dnes')) {
      return _dateFromToday(0);
    }
    if (normalized.contains('zajtra')) {
      return _dateFromToday(1);
    }

    final inDaysMatch = RegExp(
      r'(?:expiracia|expiraciu)?(?:o|na)(\d+)d(?:ni|en|na)?',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (inDaysMatch != null) {
      final days = int.tryParse(inDaysMatch.group(1) ?? '');
      if (days != null) {
        return _dateFromToday(days);
      }
    }

    return null;
  }

  String _removeExpirationPhrase(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\bexpir(?:a|á)c(?:ia|iu)\s*(?:dnes|zajtra|(?:o|na)\s*\d+\s*d(?:ni|en|na)?)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\b(?:dnes|zajtra|(?:o|na)\s*\d+\s*d(?:ni|en|na)?)\b'),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  DateTime _dateFromToday(int days) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  bool _looksLikeKnownUnit(String unit) {
    return const {'pcs', 'g', 'kg', 'ml', 'l'}.contains(unit);
  }

  String _defaultUnitForName(String name) {
    final normalized = _canonicalFoodKey(name);
    if (const {
      'milk',
      'water',
      'juice',
      'olej',
      'oil',
      'voda',
    }.contains(normalized)) {
      return 'l';
    }
    return 'pcs';
  }

  bool _isPieceUnit(String unit) {
    return _normalizeUnit(unit) == 'pcs';
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

  String _formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  double _wordQuantity(String value) {
    switch (_normalizeName(value)) {
      case 'pol':
        return 0.5;
      case 'jeden':
      case 'jedna':
      case 'jedno':
        return 1;
      case 'dva':
      case 'dve':
        return 2;
      case 'tri':
        return 3;
      case 'styri':
        return 4;
      case 'pat':
        return 5;
      case 'sest':
        return 6;
      case 'sedem':
        return 7;
      case 'osem':
        return 8;
      case 'devat':
        return 9;
      case 'desat':
        return 10;
      default:
        return 1;
    }
  }

  String _cleanItemName(String value) {
    final trimmed = value.trim();
    return trimmed
        .replaceFirst(
          RegExp(r'^(sa|si|som|je|su|sú)\s+', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'\bklasick(?:y|ý|a|á|e|é)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  ({String itemName, String? storage}) _extractStorage(String value) {
    final normalized = value.trim();
    final patterns = <Pattern, String>{
      RegExp(r'\s+do\s+chladnicky$', caseSensitive: false): 'fridge',
      RegExp(r'\s+do\s+chladničky$', caseSensitive: false): 'fridge',
      RegExp(r'\s+do\s+mraznicky$', caseSensitive: false): 'freezer',
      RegExp(r'\s+do\s+mrazničky$', caseSensitive: false): 'freezer',
      RegExp(r'\s+do\s+spajze$', caseSensitive: false): 'pantry',
      RegExp(r'\s+do\s+špajze$', caseSensitive: false): 'pantry',
      RegExp(r'\s+do\s+komory$', caseSensitive: false): 'pantry',
    };

    for (final entry in patterns.entries) {
      final pattern = entry.key;
      if (pattern is RegExp && pattern.hasMatch(normalized)) {
        return (
          itemName: normalized.replaceFirst(pattern, '').trim(),
          storage: entry.value,
        );
      }
    }

    return (itemName: normalized, storage: null);
  }

  String _storageLabel(String storageLocation) {
    switch (storageLocation) {
      case 'fridge':
        return 'chladničky';
      case 'freezer':
        return 'mrazničky';
      case 'pantry':
      default:
        return 'špajze';
    }
  }
}

class QuickCommandException implements Exception {
  final String message;

  const QuickCommandException(this.message);

  @override
  String toString() => message;
}
