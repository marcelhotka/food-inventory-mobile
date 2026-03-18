class FoodItemPrefill {
  final String name;
  final String? barcode;
  final String category;
  final String storageLocation;
  final double quantity;
  final String unit;
  final DateTime? expirationDate;
  final double? lowStockThreshold;

  const FoodItemPrefill({
    required this.name,
    this.barcode,
    this.category = 'other',
    this.storageLocation = 'pantry',
    required this.quantity,
    required this.unit,
    this.expirationDate,
    this.lowStockThreshold,
  });
}
