import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/shopping_list_item.dart';

class ShoppingListRemoteDataSource {
  ShoppingListRemoteDataSource({
    required String householdId,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<List<ShoppingListItem>> fetchShoppingListItems() async {
    final client = _requireClient();

    final response = await client
        .from('shopping_list_items')
        .select()
        .eq('household_id', _householdId)
        .order('is_bought', ascending: true)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => ShoppingListItem.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShoppingListItem> createShoppingListItem(ShoppingListItem item) async {
    final client = _requireClient();
    final payload = {
      'user_id': item.userId,
      'household_id': item.householdId,
      'name': item.name,
      'quantity': item.quantity,
      'unit': item.unit,
      'source': item.source,
      'assigned_to_user_id': item.assignedToUserId,
      'is_bought': item.isBought,
    };
    final response = await client
        .from('shopping_list_items')
        .insert(payload)
        .select()
        .single();

    return ShoppingListItem.fromMap(response);
  }

  Future<ShoppingListItem> updateShoppingListItem(ShoppingListItem item) async {
    final client = _requireClient();
    final payload = {
      'name': item.name,
      'household_id': item.householdId,
      'quantity': item.quantity,
      'unit': item.unit,
      'source': item.source,
      'assigned_to_user_id': item.assignedToUserId,
      'is_bought': item.isBought,
      'updated_at': item.updatedAt.toIso8601String(),
    };
    final response = await client
        .from('shopping_list_items')
        .update(payload)
        .eq('id', item.id)
        .select()
        .single();

    return ShoppingListItem.fromMap(response);
  }

  Future<void> deleteShoppingListItem(String id) async {
    final client = _requireClient();
    await client.from('shopping_list_items').delete().eq('id', id);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const ShoppingListConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class ShoppingListConfigException implements Exception {
  final String message;

  const ShoppingListConfigException(this.message);

  @override
  String toString() => message;
}

class ShoppingListAuthException implements Exception {
  final String message;

  const ShoppingListAuthException(this.message);

  @override
  String toString() => message;
}
