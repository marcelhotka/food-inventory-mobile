import 'dart:typed_data';

import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';
import 'fridge_scan_ai_service.dart';
import 'fridge_scan_mock_service.dart';
import 'scan_image_upload_service.dart';
import 'scan_sessions_remote_data_source.dart';

class FridgeScanPipelineService {
  FridgeScanPipelineService({
    required String householdId,
    FridgeScanAiService? analysisService,
    FridgeScanMockService? fallbackService,
    ScanImageUploadService? uploadService,
    ScanSessionsRemoteDataSource? remoteDataSource,
  }) : _analysisService = analysisService ?? FridgeScanAiService(),
       _fallbackService = fallbackService ?? const FridgeScanMockService(),
       _uploadService = uploadService ?? ScanImageUploadService(),
       _remoteDataSource =
           remoteDataSource ??
           ScanSessionsRemoteDataSource(householdId: householdId);

  final FridgeScanAiService _analysisService;
  final FridgeScanMockService _fallbackService;
  final ScanImageUploadService _uploadService;
  final ScanSessionsRemoteDataSource _remoteDataSource;

  Future<ScanSession> startPhotoScan({
    required String userId,
    required String householdId,
    required Uint8List imageBytes,
    required String imageLabel,
  }) async {
    final imagePath = await _uploadService.uploadScanImage(
      householdId: householdId,
      userId: userId,
      bytes: imageBytes,
      fileName: imageLabel,
    );

    final session = await _remoteDataSource.createScanSession(
      userId: userId,
      imageLabel: imageLabel,
      imagePath: imagePath,
      status: 'analyzing',
    );

    try {
      List<ScanCandidate> candidates;
      String? analysisError;

      try {
        candidates = await _analysisService.analyzeScanSession(
          scanSessionId: session.id,
          userId: userId,
        );
      } catch (error) {
        analysisError = error.toString();
        candidates = await _fallbackService.analyzePhoto(
          imageLabel: imageLabel,
        );
      }

      await _remoteDataSource.replaceScanResults(
        scanSessionId: session.id,
        candidates: candidates,
        isConfirmed: false,
      );

      await _remoteDataSource.updateScanSession(
        sessionId: session.id,
        status: 'review_ready',
        analysisError: analysisError,
      );

      return _remoteDataSource.getScanSession(session.id);
    } catch (error) {
      await _remoteDataSource.updateScanSession(
        sessionId: session.id,
        status: 'failed',
        analysisError: error.toString(),
      );
      rethrow;
    }
  }

  Future<ScanSession> confirmScanSession({
    required String sessionId,
    required List<ScanCandidate> candidates,
  }) async {
    await _remoteDataSource.replaceScanResults(
      scanSessionId: sessionId,
      candidates: candidates,
      isConfirmed: true,
    );
    await _remoteDataSource.updateScanSession(
      sessionId: sessionId,
      status: 'confirmed',
      analysisError: null,
    );
    return _remoteDataSource.getScanSession(sessionId);
  }
}
