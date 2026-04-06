enum QuickCommandIntent {
  addToPantry,
  addToShoppingList,
  consumeFromPantry,
  markOpened,
}

class QuickCommandItem {
  final String name;
  final double quantity;
  final String unit;
  final String? storageLocation;
  final DateTime? expirationDate;

  const QuickCommandItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    required this.expirationDate,
  });
}

class QuickCommandParseResult {
  final QuickCommandIntent intent;
  final List<QuickCommandItem> items;

  const QuickCommandParseResult({required this.intent, required this.items});
}

class QuickCommandExecutionResult {
  final String summary;
  final List<String> details;
  final bool changedPantry;
  final bool changedShoppingList;

  const QuickCommandExecutionResult({
    required this.summary,
    required this.details,
    required this.changedPantry,
    required this.changedShoppingList,
  });
}
