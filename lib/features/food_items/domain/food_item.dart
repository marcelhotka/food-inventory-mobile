class FoodItem {
  final String id;
  final String userId;
  final String? householdId;
  final String name;
  final String? barcode;
  final String category;
  final String storageLocation;
  final double quantity;
  final double? lowStockThreshold;
  final String unit;
  final DateTime? expirationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItem({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.name,
    required this.barcode,
    required this.category,
    required this.storageLocation,
    required this.quantity,
    required this.lowStockThreshold,
    required this.unit,
    required this.expirationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      householdId: map['household_id'] as String?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      category: (map['category'] as String?) ?? 'other',
      storageLocation: (map['storage_location'] as String?) ?? 'pantry',
      quantity: _toDouble(map['quantity']),
      lowStockThreshold: map['low_stock_threshold'] == null
          ? null
          : _toDouble(map['low_stock_threshold']),
      unit: (map['unit'] as String?) ?? 'pcs',
      expirationDate: map['expiration_date'] == null
          ? null
          : DateTime.parse(map['expiration_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'household_id': householdId,
      'name': name,
      'barcode': barcode,
      'category': category,
      'storage_location': storageLocation,
      'quantity': quantity,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'expiration_date': expirationDate?.toIso8601String().split('T').first,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FoodItem copyWith({
    String? id,
    String? userId,
    String? householdId,
    String? name,
    String? barcode,
    bool clearBarcode = false,
    String? category,
    String? storageLocation,
    double? quantity,
    double? lowStockThreshold,
    bool clearLowStockThreshold = false,
    String? unit,
    DateTime? expirationDate,
    bool clearExpirationDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      category: category ?? this.category,
      storageLocation: storageLocation ?? this.storageLocation,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: clearLowStockThreshold
          ? null
          : (lowStockThreshold ?? this.lowStockThreshold),
      unit: unit ?? this.unit,
      expirationDate: clearExpirationDate
          ? null
          : (expirationDate ?? this.expirationDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return double.parse(value.toString());
  }
}
