import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/supabase.dart';

class ScanImageUploadService {
  ScanImageUploadService({SupabaseClient? client})
    : _client = client ?? tryGetSupabaseClient();

  final SupabaseClient? _client;
  static const bucketName = 'scan-images';

  Future<String> uploadScanImage({
    required String householdId,
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final client = _requireClient();
    final sanitizedFileName = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$householdId/$userId/$timestamp-$sanitizedFileName';

    await client.storage
        .from(bucketName)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _guessContentType(sanitizedFileName),
          ),
        );

    return objectPath;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const ScanImageUploadConfigException(
        'Supabase is not configured. Add values to mobile/.env first.',
      );
    }
    return client;
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'fridge-photo.jpg';
    }

    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}

class ScanImageUploadConfigException implements Exception {
  final String message;

  const ScanImageUploadConfigException(this.message);

  @override
  String toString() => message;
}
