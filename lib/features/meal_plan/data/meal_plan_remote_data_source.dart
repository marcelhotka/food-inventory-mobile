import '../../../app/supabase.dart';
import '../domain/meal_plan_entry.dart';

class MealPlanRemoteDataSource {
  MealPlanRemoteDataSource({required String householdId})
    : _householdId = householdId;

  final String _householdId;

  Future<List<MealPlanEntry>> fetchEntries() async {
    final client = tryGetSupabaseClient();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await client
        .from('meal_plan_entries')
        .select()
        .eq('household_id', _householdId)
        .order('scheduled_for', ascending: true)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((item) => MealPlanEntry.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<MealPlanEntry> createEntry(MealPlanEntry entry) async {
    final client = tryGetSupabaseClient();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await client
        .from('meal_plan_entries')
        .insert(_toPayload(entry))
        .select()
        .single();

    return MealPlanEntry.fromMap(response);
  }

  Future<MealPlanEntry> updateEntry(MealPlanEntry entry) async {
    final client = tryGetSupabaseClient();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    final response = await client
        .from('meal_plan_entries')
        .update(_toPayload(entry))
        .eq('id', entry.id)
        .select()
        .single();

    return MealPlanEntry.fromMap(response);
  }

  Future<void> deleteEntry(String id) async {
    final client = tryGetSupabaseClient();
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    await client.from('meal_plan_entries').delete().eq('id', id);
  }

  Map<String, dynamic> _toPayload(MealPlanEntry entry) {
    return {
      'household_id': entry.householdId,
      'user_id': entry.userId,
      'recipe_id': entry.recipeId,
      'recipe_name': entry.recipeName,
      'scheduled_for': entry.scheduledFor.toIso8601String().split('T').first,
      'meal_type': entry.mealType,
      'note': entry.note,
      'updated_at': entry.updatedAt.toIso8601String(),
    };
  }
}
