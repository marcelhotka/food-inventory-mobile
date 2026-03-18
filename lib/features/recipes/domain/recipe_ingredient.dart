class RecipeIngredient {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final int sortOrder;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.sortOrder,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: _toDouble(map['quantity']),
      unit: (map['unit'] as String?) ?? 'pcs',
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.parse(value.toString());
  }
}
