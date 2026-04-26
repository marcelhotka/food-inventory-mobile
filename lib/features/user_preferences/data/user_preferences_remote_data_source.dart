import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/user_preferences.dart';

class UserPreferencesRemoteDataSource {
  UserPreferencesRemoteDataSource({SupabaseClient? client})
    : _client = client ?? tryGetSupabaseClient();

  final SupabaseClient? _client;

  Future<UserPreferences?> fetchCurrentUserPreferences() async {
    final client = _requireClient();
    final user = client.auth.currentUser;
    if (user == null) {
      throw const UserPreferencesConfigException('No signed-in user.');
    }

    try {
      final response = await client
          .from('user_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserPreferences.fromMap(response);
    } on PostgrestException catch (error) {
      if (_isMissingPreferencesSetup(error)) {
        throw const UserPreferencesConfigException(
          'Preferences setup is not ready yet. Run backend migration 0014_user_preferences.sql first.',
        );
      }
      rethrow;
    }
  }

  Future<UserPreferences> upsertPreferences(UserPreferences preferences) async {
    final client = _requireClient();
    try {
      final response = await client
          .from('user_preferences')
        .upsert({
            'user_id': preferences.userId,
            'favorite_meals': preferences.favoriteMeals,
            'favorite_foods': preferences.favoriteFoods,
            'allergies': preferences.allergies,
            'intolerances': preferences.intolerances,
            'diet_style': preferences.dietStyles.join(','),
            'cooking_frequency': preferences.cookingFrequency,
            'preferred_language': preferences.preferredLanguage,
            'household_size': preferences.householdSize,
            'onboarding_completed': preferences.onboardingCompleted,
            'updated_at': preferences.updatedAt.toIso8601String(),
          })
          .select()
          .single();

      return UserPreferences.fromMap(response);
    } on PostgrestException catch (error) {
      if (_isMissingPreferencesSetup(error)) {
        throw const UserPreferencesConfigException(
          'Preferences setup is not ready yet. Run backend migration 0014_user_preferences.sql first.',
        );
      }
      rethrow;
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const UserPreferencesConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }

  bool _isMissingPreferencesSetup(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    return code == '42P01' ||
        code == 'PGRST205' ||
        message.contains('relation') && message.contains('user_preferences') ||
        message.contains('schema cache') &&
            message.contains('user_preferences');
  }
}

class UserPreferencesConfigException implements Exception {
  final String message;

  const UserPreferencesConfigException(this.message);

  @override
  String toString() => message;
}
