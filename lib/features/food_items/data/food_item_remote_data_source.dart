import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/food_item.dart';

class FoodItemRemoteDataSource {
  FoodItemRemoteDataSource({
    required String householdId,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<List<FoodItem>> fetchFoodItems() async {
    final client = _requireClient();

    final response = await client
        .from('food_items')
        .select()
        .eq('household_id', _householdId)
        .order('expiration_date', ascending: true)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => FoodItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<FoodItem> createFoodItem(FoodItem item) async {
    final client = _requireClient();
    final payload = {
      'user_id': item.userId,
      'household_id': item.householdId,
      'name': item.name,
      'barcode': item.barcode,
      'category': item.category,
      'storage_location': item.storageLocation,
      'quantity': item.quantity,
      'low_stock_threshold': item.lowStockThreshold,
      'unit': item.unit,
      'expiration_date': item.expirationDate
          ?.toIso8601String()
          .split('T')
          .first,
    };
    final response = await client
        .from('food_items')
        .insert(payload)
        .select()
        .single();

    return FoodItem.fromMap(response);
  }

  Future<FoodItem> updateFoodItem(FoodItem item) async {
    final client = _requireClient();
    final payload = {
      'name': item.name,
      'household_id': item.householdId,
      'barcode': item.barcode,
      'category': item.category,
      'storage_location': item.storageLocation,
      'quantity': item.quantity,
      'low_stock_threshold': item.lowStockThreshold,
      'unit': item.unit,
      'expiration_date': item.expirationDate
          ?.toIso8601String()
          .split('T')
          .first,
      'updated_at': item.updatedAt.toIso8601String(),
    };
    final response = await client
        .from('food_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();

    return FoodItem.fromMap(response);
  }

  Future<void> deleteFoodItem(String id) async {
    final client = _requireClient();
    await client.from('food_items').delete().eq('id', id);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const FoodItemsConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class FoodItemsConfigException implements Exception {
  final String message;

  const FoodItemsConfigException(this.message);

  @override
  String toString() => message;
}

class FoodItemsAuthException implements Exception {
  final String message;

  const FoodItemsAuthException(this.message);

  @override
  String toString() => message;
}
