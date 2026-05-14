import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/household.dart';
import '../domain/household_join_target.dart';
import '../domain/household_member.dart';

class HouseholdRemoteDataSource {
  HouseholdRemoteDataSource({SupabaseClient? client})
    : _client = client ?? tryGetSupabaseClient();

  final SupabaseClient? _client;

  Future<Household?> fetchPrimaryHousehold() async {
    final client = _requireClient();
    final user = _requireUser(client);

    final response = await client
        .from('household_members')
        .select('households!inner(*)')
        .eq('user_id', user.id)
        .limit(1);

    final rows = response as List<dynamic>;
    if (rows.isEmpty) {
      return null;
    }

    final household = rows.first['households'] as Map<String, dynamic>;
    return Household.fromMap(household);
  }

  Future<Household> createHousehold(String name) async {
    final client = _requireClient();
    final user = _requireUser(client);

    final householdResponse = await client
        .from('households')
        .insert({'name': name, 'owner_user_id': user.id})
        .select()
        .single();

    final household = Household.fromMap(householdResponse);

    await client.from('household_members').insert({
      'household_id': household.id,
      'user_id': user.id,
      'role': 'owner',
    });

    await client
        .from('food_items')
        .update({'household_id': household.id})
        .eq('user_id', user.id)
        .isFilter('household_id', null);

    await client
        .from('shopping_list_items')
        .update({'household_id': household.id})
        .eq('user_id', user.id)
        .isFilter('household_id', null);

    return household;
  }

  Future<Household> joinHousehold(String householdId) async {
    final client = _requireClient();
    final user = _requireUser(client);
    final resolvedHouseholdId = await _resolveHouseholdId(
      client,
      householdId.trim(),
    );

    await client.from('household_members').upsert({
      'household_id': resolvedHouseholdId,
      'user_id': user.id,
      'role': 'member',
    });

    await client
        .from('food_items')
        .update({'household_id': resolvedHouseholdId})
        .eq('user_id', user.id)
        .isFilter('household_id', null);

    await client
        .from('shopping_list_items')
        .update({'household_id': resolvedHouseholdId})
        .eq('user_id', user.id)
        .isFilter('household_id', null);

    final householdResponse = await client
        .from('households')
        .select()
        .eq('id', resolvedHouseholdId)
        .single();

    return Household.fromMap(householdResponse);
  }

  Future<Household> updateHouseholdName(String householdId, String name) async {
    final client = _requireClient();
    _requireUser(client);

    final response = await client
        .from('households')
        .update({'name': name})
        .eq('id', householdId)
        .select()
        .single();

    return Household.fromMap(response);
  }

  Future<List<HouseholdMember>> fetchMembers(String householdId) async {
    final client = _requireClient();

    final response = await client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((row) => HouseholdMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> _resolveHouseholdId(
    SupabaseClient client,
    String rawCode,
  ) async {
    final target = _parseJoinTarget(rawCode);
    if (target.isFullHouseholdId) {
      return target.value;
    }

    final rows = await client
        .from('households')
        .select('id')
        .ilike('id', '${target.value}%')
        .limit(2);

    final matches = (rows as List<dynamic>)
        .map((row) => row['id'] as String)
        .toList();

    if (matches.isEmpty) {
      throw const HouseholdJoinCodeException('Household code was not found.');
    }

    if (matches.length > 1) {
      throw const HouseholdJoinCodeException(
        'Household code matched more than one household.',
      );
    }

    return matches.single;
  }

  HouseholdJoinTarget _parseJoinTarget(String rawCode) {
    try {
      return parseHouseholdJoinTarget(rawCode);
    } on HouseholdJoinCodeFormatException catch (error) {
      throw HouseholdJoinCodeException(error.message);
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const HouseholdConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }

  User _requireUser(SupabaseClient client) {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const HouseholdAuthException(
        'No signed-in user. Add auth before loading households.',
      );
    }
    return user;
  }
}

class HouseholdConfigException implements Exception {
  final String message;

  const HouseholdConfigException(this.message);

  @override
  String toString() => message;
}

class HouseholdAuthException implements Exception {
  final String message;

  const HouseholdAuthException(this.message);

  @override
  String toString() => message;
}

class HouseholdJoinCodeException implements Exception {
  final String message;

  const HouseholdJoinCodeException(this.message);

  @override
  String toString() => message;
}
