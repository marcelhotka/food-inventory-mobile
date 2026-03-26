class UserPreferences {
  final String userId;
  final List<String> favoriteMeals;
  final List<String> favoriteFoods;
  final List<String> allergies;
  final List<String> intolerances;
  final String? dietStyle;
  final String? cookingFrequency;
  final String? preferredLanguage;
  final int? householdSize;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    required this.userId,
    required this.favoriteMeals,
    required this.favoriteFoods,
    required this.allergies,
    required this.intolerances,
    required this.dietStyle,
    required this.cookingFrequency,
    required this.preferredLanguage,
    required this.householdSize,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      userId: map['user_id'] as String,
      favoriteMeals: _toStringList(map['favorite_meals']),
      favoriteFoods: _toStringList(map['favorite_foods']),
      allergies: _toStringList(map['allergies']),
      intolerances: _toStringList(map['intolerances']),
      dietStyle: map['diet_style'] as String?,
      cookingFrequency: map['cooking_frequency'] as String?,
      preferredLanguage: map['preferred_language'] as String?,
      householdSize: map['household_size'] as int?,
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  UserPreferences copyWith({
    String? userId,
    List<String>? favoriteMeals,
    List<String>? favoriteFoods,
    List<String>? allergies,
    List<String>? intolerances,
    String? dietStyle,
    bool clearDietStyle = false,
    String? cookingFrequency,
    bool clearCookingFrequency = false,
    String? preferredLanguage,
    bool clearPreferredLanguage = false,
    int? householdSize,
    bool clearHouseholdSize = false,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      favoriteMeals: favoriteMeals ?? this.favoriteMeals,
      favoriteFoods: favoriteFoods ?? this.favoriteFoods,
      allergies: allergies ?? this.allergies,
      intolerances: intolerances ?? this.intolerances,
      dietStyle: clearDietStyle ? null : (dietStyle ?? this.dietStyle),
      cookingFrequency: clearCookingFrequency
          ? null
          : (cookingFrequency ?? this.cookingFrequency),
      preferredLanguage: clearPreferredLanguage
          ? null
          : (preferredLanguage ?? this.preferredLanguage),
      householdSize: clearHouseholdSize
          ? null
          : (householdSize ?? this.householdSize),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
