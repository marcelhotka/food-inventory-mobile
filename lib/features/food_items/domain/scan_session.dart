import 'scan_candidate.dart';

class ScanSession {
  final String id;
  final String imageLabel;
  final String? imagePath;
  final String status;
  final String? analysisError;
  final DateTime createdAt;
  final List<ScanCandidate> candidates;

  const ScanSession({
    required this.id,
    required this.imageLabel,
    required this.imagePath,
    required this.status,
    required this.analysisError,
    required this.createdAt,
    required this.candidates,
  });

  factory ScanSession.fromMap(Map<String, dynamic> map) {
    final candidateRows = (map['scan_result_items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return ScanSession(
      id: map['id'] as String,
      imageLabel: map['image_label'] as String,
      imagePath: map['image_path'] as String?,
      status: (map['status'] as String?) ?? 'confirmed',
      analysisError: map['analysis_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      candidates: candidateRows.map(ScanCandidate.fromMap).toList()
        ..sort((a, b) => a.id.compareTo(b.id)),
    );
  }
}
