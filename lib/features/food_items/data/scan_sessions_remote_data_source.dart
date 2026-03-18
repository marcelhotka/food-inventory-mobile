import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';

class ScanSessionsRemoteDataSource {
  ScanSessionsRemoteDataSource({
    required String householdId,
    SupabaseClient? client,
  }) : _householdId = householdId,
       _client = client ?? tryGetSupabaseClient();

  final String _householdId;
  final SupabaseClient? _client;

  Future<ScanSession> createScanSession({
    required String userId,
    required String imageLabel,
    required String imagePath,
    required String status,
  }) async {
    final client = _requireClient();

    final sessionResponse = await client
        .from('scan_sessions')
        .insert({
          'household_id': _householdId,
          'created_by_user_id': userId,
          'image_label': imageLabel,
          'image_path': imagePath,
          'status': status,
        })
        .select()
        .single();

    return ScanSession.fromMap(sessionResponse);
  }

  Future<void> replaceScanResults({
    required String scanSessionId,
    required List<ScanCandidate> candidates,
    required bool isConfirmed,
  }) async {
    final client = _requireClient();

    await client
        .from('scan_result_items')
        .delete()
        .eq('scan_session_id', scanSessionId);

    if (candidates.isEmpty) {
      return;
    }

    await client.from('scan_result_items').insert([
      for (var index = 0; index < candidates.length; index++)
        candidates[index].toInsertMap(
          scanSessionId: scanSessionId,
          sortOrder: index,
          isConfirmed: isConfirmed,
        ),
    ]);
  }

  Future<void> updateScanSession({
    required String sessionId,
    required String status,
    required String? analysisError,
  }) async {
    final client = _requireClient();

    await client
        .from('scan_sessions')
        .update({
          'status': status,
          'analysis_error': analysisError,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  Future<List<ScanSession>> getScanSessions() async {
    final client = _requireClient();

    final response = await client
        .from('scan_sessions')
        .select('*, scan_result_items(*)')
        .eq('household_id', _householdId)
        .order('created_at', ascending: false);

    return response
        .cast<Map<String, dynamic>>()
        .map(ScanSession.fromMap)
        .toList();
  }

  Future<ScanSession> getScanSession(String sessionId) async {
    final client = _requireClient();

    final response = await client
        .from('scan_sessions')
        .select('*, scan_result_items(*)')
        .eq('id', sessionId)
        .single();

    return ScanSession.fromMap(response);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const ScanSessionsConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class ScanSessionsConfigException implements Exception {
  final String message;

  const ScanSessionsConfigException(this.message);

  @override
  String toString() => message;
}
