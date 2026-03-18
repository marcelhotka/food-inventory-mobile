class StapleFood {
  final String id;
  final String householdId;
  final String userId;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StapleFood({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StapleFood.fromMap(Map<String, dynamic> map) {
    return StapleFood(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      quantity: _toDouble(map['quantity']),
      unit: (map['unit'] as String?) ?? 'pcs',
      category: (map['category'] as String?) ?? 'other',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'household_id': householdId,
      'user_id': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StapleFood copyWith({
    String? id,
    String? householdId,
    String? userId,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StapleFood(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
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
