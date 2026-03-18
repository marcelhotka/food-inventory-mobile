import 'dart:typed_data';

import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';
import 'fridge_scan_pipeline_service.dart';
import 'scan_sessions_remote_data_source.dart';

class ScanSessionsRepository {
  ScanSessionsRepository({
    required String householdId,
    ScanSessionsRemoteDataSource? remoteDataSource,
    FridgeScanPipelineService? pipelineService,
  }) : _householdId = householdId,
       _remoteDataSource =
           remoteDataSource ??
           ScanSessionsRemoteDataSource(householdId: householdId),
       _pipelineService =
           pipelineService ??
           FridgeScanPipelineService(
             householdId: householdId,
             remoteDataSource:
                 remoteDataSource ??
                 ScanSessionsRemoteDataSource(householdId: householdId),
           );

  final String _householdId;
  final ScanSessionsRemoteDataSource _remoteDataSource;
  final FridgeScanPipelineService _pipelineService;

  Future<ScanSession> startPhotoScan({
    required String userId,
    required String imageLabel,
    required Uint8List imageBytes,
  }) {
    return _pipelineService.startPhotoScan(
      userId: userId,
      householdId: _householdId,
      imageBytes: imageBytes,
      imageLabel: imageLabel,
    );
  }

  Future<ScanSession> confirmScanSession({
    required String sessionId,
    required List<ScanCandidate> candidates,
  }) {
    return _pipelineService.confirmScanSession(
      sessionId: sessionId,
      candidates: candidates,
    );
  }

  Future<List<ScanSession>> getScanSessions() {
    return _remoteDataSource.getScanSessions();
  }

  Future<ScanSession> getScanSession(String sessionId) {
    return _remoteDataSource.getScanSession(sessionId);
  }
}
