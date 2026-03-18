import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/staple_food.dart';

class StapleFoodRemoteDataSource {
  StapleFoodRemoteDataSource({
    required String householdId,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<List<StapleFood>> fetchStapleFoods() async {
    final client = _requireClient();

    final response = await client
        .from('staple_foods')
        .select()
        .eq('household_id', _householdId)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((item) => StapleFood.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<StapleFood> createStapleFood(StapleFood item) async {
    final client = _requireClient();
    final response = await client
        .from('staple_foods')
        .insert({
          'household_id': item.householdId,
          'user_id': item.userId,
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'category': item.category,
        })
        .select()
        .single();

    return StapleFood.fromMap(response);
  }

  Future<StapleFood> updateStapleFood(StapleFood item) async {
    final client = _requireClient();
    final response = await client
        .from('staple_foods')
        .update({
          'name': item.name,
          'quantity': item.quantity,
          'unit': item.unit,
          'category': item.category,
          'updated_at': item.updatedAt.toIso8601String(),
        })
        .eq('id', item.id)
        .select()
        .single();

    return StapleFood.fromMap(response);
  }

  Future<void> deleteStapleFood(String id) async {
    final client = _requireClient();
    await client.from('staple_foods').delete().eq('id', id);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const StapleFoodsConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class StapleFoodsConfigException implements Exception {
  final String message;

  const StapleFoodsConfigException(this.message);

  @override
  String toString() => message;
}
