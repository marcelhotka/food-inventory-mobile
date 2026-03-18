import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/scan_sessions_repository.dart';
import '../domain/food_item.dart';
import '../domain/food_item_prefill.dart';
import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';
import 'food_item_form_screen.dart';

class FridgeScanScreen extends StatefulWidget {
  final String householdId;

  const FridgeScanScreen({super.key, required this.householdId});

  @override
  State<FridgeScanScreen> createState() => _FridgeScanScreenState();
}

class _FridgeScanScreenState extends State<FridgeScanScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late final ScanSessionsRepository _scanSessionsRepository =
      ScanSessionsRepository(householdId: widget.householdId);

  Future<ScanSession>? _scanFuture;
  Uint8List? _photoBytes;
  String? _imageLabel;
  bool _isPickingImage = false;

  Future<void> _reload() async {
    final imageLabel = _imageLabel;
    final photoBytes = _photoBytes;
    if (imageLabel == null || photoBytes == null) {
      return;
    }

    setState(() {
      _scanFuture = _startPhotoScan(
        imageBytes: photoBytes,
        imageLabel: imageLabel,
      );
    });
    await _scanFuture;
  }

  Future<ScanSession> _startPhotoScan({
    required Uint8List imageBytes,
    required String imageLabel,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('You need to be signed in.');
    }

    return _scanSessionsRepository.startPhotoScan(
      userId: user.id,
      imageLabel: imageLabel,
      imageBytes: imageBytes,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (file == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isPickingImage = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _photoBytes = bytes;
        _imageLabel = file.name.isEmpty ? 'Fridge photo' : file.name;
        _scanFuture = _startPhotoScan(
          imageBytes: bytes,
          imageLabel: _imageLabel!,
        );
        _isPickingImage = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPickingImage = false;
      });
      showErrorFeedback(context, 'Failed to load photo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanFuture = _scanFuture;

    if (scanFuture == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan fridge')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE6DDCF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload one fridge photo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose or take a single photo of your fridge. We will run the current scan review flow on that image, then later replace the mock detection with real AI.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        _photoBytes!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isPickingImage
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _isPickingImage ? 'Opening camera...' : 'Take photo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isPickingImage
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose photo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan fridge')),
      body: FutureBuilder<ScanSession>(
        future: scanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Failed to analyze fridge photo.',
              onRetry: _reload,
            );
          }

          final session = snapshot.data;
          if (session == null || session.candidates.isEmpty) {
            return AppEmptyState(
              message: 'No items were detected in this scan.',
              onRefresh: _reload,
            );
          }

          return _FridgeScanReview(
            session: session,
            householdId: widget.householdId,
            photoBytes: _photoBytes,
            onPickAnotherPhoto: () {
              setState(() {
                _scanFuture = null;
              });
            },
          );
        },
      ),
    );
  }
}

class _FridgeScanReview extends StatefulWidget {
  final ScanSession session;
  final String householdId;
  final Uint8List? photoBytes;
  final VoidCallback onPickAnotherPhoto;

  const _FridgeScanReview({
    required this.session,
    required this.householdId,
    required this.photoBytes,
    required this.onPickAnotherPhoto,
  });

  @override
  State<_FridgeScanReview> createState() => _FridgeScanReviewState();
}

class _FridgeScanReviewState extends State<_FridgeScanReview> {
  late List<ScanCandidate> _candidates = widget.session.candidates;
  late final ScanSessionsRepository _scanSessionsRepository =
      ScanSessionsRepository(householdId: widget.householdId);
  bool _isSaving = false;

  Future<void> _editCandidate(ScanCandidate candidate) async {
    final edited = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodItemFormScreen(
          householdId: widget.householdId,
          prefill: candidate.prefill,
        ),
      ),
    );

    if (edited == null) {
      return;
    }

    setState(() {
      _candidates = _candidates
          .map(
            (item) => item.id == candidate.id
                ? item.copyWith(
                    prefill: FoodItemPrefill(
                      name: edited.name,
                      barcode: edited.barcode,
                      category: edited.category,
                      storageLocation: edited.storageLocation,
                      quantity: edited.quantity,
                      unit: edited.unit,
                      expirationDate: edited.expirationDate,
                      lowStockThreshold: edited.lowStockThreshold,
                    ),
                  )
                : item,
          )
          .toList();
    });
  }

  void _toggleSelection(String id, bool value) {
    setState(() {
      _candidates = _candidates
          .map(
            (item) => item.id == id ? item.copyWith(isSelected: value) : item,
          )
          .toList();
    });
  }

  void _removeCandidate(String id) {
    setState(() {
      _candidates = _candidates.where((item) => item.id != id).toList();
    });
  }

  Future<void> _addManualCandidate() async {
    final created = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute(
        builder: (_) => FoodItemFormScreen(householdId: widget.householdId),
      ),
    );

    if (created == null) {
      return;
    }

    setState(() {
      _candidates = [
        ..._candidates,
        ScanCandidate(
          id: 'manual-${DateTime.now().microsecondsSinceEpoch}',
          confidence: 1,
          prefill: FoodItemPrefill(
            name: created.name,
            barcode: created.barcode,
            category: created.category,
            storageLocation: created.storageLocation,
            quantity: created.quantity,
            unit: created.unit,
            expirationDate: created.expirationDate,
            lowStockThreshold: created.lowStockThreshold,
          ),
        ),
      ];
    });
  }

  Future<void> _finish() async {
    final selectedCandidates = _candidates
        .where((item) => item.isSelected)
        .toList();

    if (selectedCandidates.isEmpty) {
      showErrorFeedback(context, 'Select at least one item to continue.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _scanSessionsRepository.confirmScanSession(
        sessionId: widget.session.id,
        candidates: _candidates,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pop(selectedCandidates.map((item) => item.prefill).toList());
    } catch (_) {
      if (!mounted) {
        return;
      }
      showErrorFeedback(context, 'Failed to save scan session.');
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _candidates.where((item) => item.isSelected).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6DDCF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review detected items',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This is the scan confirmation flow. Later we will replace the mock results with real AI detection from one fridge photo.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (widget.photoBytes != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    widget.photoBytes!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ScanMetaChip(
                    label: widget.session.imageLabel,
                    icon: Icons.image_outlined,
                  ),
                  _ScanMetaChip(
                    label: '$selectedCount selected',
                    icon: Icons.checklist_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: widget.onPickAnotherPhoto,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Use another photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _addManualCandidate,
            icon: const Icon(Icons.add),
            label: const Text('Add missing item manually'),
          ),
        ),
        const SizedBox(height: 16),
        ..._candidates.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Checkbox(
                  value: candidate.isSelected,
                  onChanged: (value) {
                    _toggleSelection(candidate.id, value ?? false);
                  },
                ),
                title: Text(candidate.prefill.name),
                subtitle: Text(
                  '${candidate.prefill.quantity} ${candidate.prefill.unit} • ${candidate.prefill.storageLocation} • ${(candidate.confidence * 100).round()}%',
                ),
                trailing: SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _editCandidate(candidate),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        onPressed: () => _removeCandidate(candidate.id),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _finish,
            child: Text(
              _isSaving ? 'Saving scan...' : 'Add selected items to pantry',
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanMetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ScanMetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}
