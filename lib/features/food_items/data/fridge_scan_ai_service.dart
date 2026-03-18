import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';
import '../domain/scan_candidate.dart';

class FridgeScanAiService {
  FridgeScanAiService({SupabaseClient? client})
    : _client = client ?? tryGetSupabaseClient();

  final SupabaseClient? _client;

  Future<List<ScanCandidate>> analyzeScanSession({
    required String scanSessionId,
    required String userId,
  }) async {
    final client = _requireClient();
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    if (supabaseUrl.isEmpty) {
      throw const FridgeScanAiException('Supabase URL is missing.');
    }
    final functionUrl = '$supabaseUrl/functions/v1/analyze-fridge-scan';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (anonKey.isEmpty) {
      throw const FridgeScanAiException('Supabase anon key is missing.');
    }
    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const FridgeScanAiException('User session is missing.');
    }

    final response = await http.post(
      Uri.parse(functionUrl),
      headers: {
        'Content-Type': 'application/json',
        'apikey': anonKey,
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'scanSessionId': scanSessionId, 'userId': userId}),
    );

    final rawBody = response.body;
    dynamic data;
    try {
      data = rawBody.isEmpty ? null : jsonDecode(rawBody);
    } catch (_) {
      data = null;
    }

    if (response.statusCode >= 400) {
      throw FridgeScanAiException(
        data is Map<String, dynamic>
            ? 'HTTP ${response.statusCode}: ${(data['details'] ?? data['error'] ?? rawBody).toString()}'
            : 'HTTP ${response.statusCode}: ${rawBody.isEmpty ? 'AI scan failed.' : rawBody}',
      );
    }

    if (data is! Map<String, dynamic>) {
      throw FridgeScanAiException(
        'AI scan returned invalid data. Raw response: ${rawBody.isEmpty ? '<empty>' : rawBody}',
      );
    }

    final candidates = (data['candidates'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ScanCandidate.fromMap)
        .toList();

    return candidates;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const FridgeScanAiException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }
}

class FridgeScanAiException implements Exception {
  final String message;

  const FridgeScanAiException(this.message);

  @override
  String toString() => message;
}
