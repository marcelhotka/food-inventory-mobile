class HouseholdActivityEvent {
  final String id;
  final String householdId;
  final String userId;
  final String eventType;
  final String itemName;
  final double? quantity;
  final String? unit;
  final String? details;
  final DateTime createdAt;

  const HouseholdActivityEvent({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.eventType,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.details,
    required this.createdAt,
  });

  factory HouseholdActivityEvent.fromMap(Map<String, dynamic> map) {
    return HouseholdActivityEvent(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] == null ? null : _toDouble(map['quantity']),
      unit: map['unit'] as String?,
      details: map['details'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'household_id': householdId,
      'user_id': userId,
      'event_type': eventType,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'details': details,
    };
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
