class ShoppingListItem {
  static const sourceManual = 'manual';
  static const sourceLowStock = 'low_stock';
  static const sourceRecipeMissing = 'recipe_missing';
  static const sourceMultiple = 'multiple';

  final String id;
  final String userId;
  final String? householdId;
  final String name;
  final double quantity;
  final String unit;
  final String source;
  final bool isBought;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingListItem({
    required this.id,
    required this.userId,
    required this.householdId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.source,
    required this.isBought,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      householdId: map['household_id'] as String?,
      name: map['name'] as String,
      quantity: _toDouble(map['quantity']),
      unit: (map['unit'] as String?) ?? 'pcs',
      source: (map['source'] as String?) ?? 'manual',
      isBought: (map['is_bought'] as bool?) ?? false,
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
      'quantity': quantity,
      'unit': unit,
      'source': source,
      'is_bought': isBought,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ShoppingListItem copyWith({
    String? id,
    String? userId,
    String? householdId,
    String? name,
    double? quantity,
    String? unit,
    String? source,
    bool? isBought,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      source: source ?? this.source,
      isBought: isBought ?? this.isBought,
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

  static String mergeSource(String existing, String incoming) {
    if (existing == incoming) {
      return existing;
    }
    if (existing == sourceMultiple || incoming == sourceMultiple) {
      return sourceMultiple;
    }
    return sourceMultiple;
  }
}
