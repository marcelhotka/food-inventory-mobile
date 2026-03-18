import 'recipe_ingredient.dart';

class Recipe {
  final String id;
  final String? householdId;
  final String? createdByUserId;
  final String name;
  final String description;
  final bool isPublic;
  final bool isFavorite;
  final List<RecipeIngredient> ingredients;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Recipe({
    required this.id,
    required this.householdId,
    required this.createdByUserId,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.isFavorite,
    required this.ingredients,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    final ingredients =
        ((map['recipe_ingredients'] as List<dynamic>?) ?? [])
            .map(
              (item) => RecipeIngredient.fromMap(item as Map<String, dynamic>),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Recipe(
      id: map['id'] as String,
      householdId: map['household_id'] as String?,
      createdByUserId: map['created_by_user_id'] as String?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      isPublic: (map['is_public'] as bool?) ?? false,
      isFavorite: (map['is_favorite'] as bool?) ?? false,
      ingredients: ingredients,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.parse(map['updated_at'] as String),
    );
  }

  Recipe copyWith({
    String? id,
    String? householdId,
    String? createdByUserId,
    String? name,
    String? description,
    bool? isPublic,
    bool? isFavorite,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      name: name ?? this.name,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      isFavorite: isFavorite ?? this.isFavorite,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
