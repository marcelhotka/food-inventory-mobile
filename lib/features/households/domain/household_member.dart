class HouseholdMember {
  final String id;
  final String householdId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> map) {
    return HouseholdMember(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
