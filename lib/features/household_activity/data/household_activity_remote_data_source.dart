import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/household_activity_event.dart';

class HouseholdActivityRemoteDataSource {
  HouseholdActivityRemoteDataSource({
    required String householdId,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<List<HouseholdActivityEvent>> fetchRecentEvents() async {
    final client = _requireClient();
    final response = await client
        .from('household_activity_events')
        .select()
        .eq('household_id', _householdId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List<dynamic>)
        .map(
          (row) => HouseholdActivityEvent.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<HouseholdActivityEvent> createEvent(
    HouseholdActivityEvent event,
  ) async {
    final client = _requireClient();
    final response = await client
        .from('household_activity_events')
        .insert(event.toInsertMap())
        .select()
        .single();

    return HouseholdActivityEvent.fromMap(response);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const HouseholdActivityConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class HouseholdActivityConfigException implements Exception {
  final String message;

  const HouseholdActivityConfigException(this.message);

  @override
  String toString() => message;
}
