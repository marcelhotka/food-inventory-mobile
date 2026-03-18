class MealPlanEntry {
  final String id;
  final String householdId;
  final String userId;
  final String? recipeId;
  final String recipeName;
  final DateTime scheduledFor;
  final String mealType;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealPlanEntry({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.recipeId,
    required this.recipeName,
    required this.scheduledFor,
    required this.mealType,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealPlanEntry.fromMap(Map<String, dynamic> map) {
    return MealPlanEntry(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      userId: map['user_id'] as String,
      recipeId: map['recipe_id'] as String?,
      recipeName: map['recipe_name'] as String,
      scheduledFor: DateTime.parse(map['scheduled_for'] as String),
      mealType: (map['meal_type'] as String?) ?? 'dinner',
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  MealPlanEntry copyWith({
    String? id,
    String? householdId,
    String? userId,
    String? recipeId,
    bool clearRecipeId = false,
    String? recipeName,
    DateTime? scheduledFor,
    String? mealType,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPlanEntry(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      recipeId: clearRecipeId ? null : (recipeId ?? this.recipeId),
      recipeName: recipeName ?? this.recipeName,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      mealType: mealType ?? this.mealType,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
