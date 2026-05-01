import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/food/food_signal_catalog.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/safo_logo.dart';
import '../data/fridge_scan_ai_service.dart';
import '../data/scan_sessions_repository.dart';
import '../data/scan_sessions_remote_data_source.dart';
import '../domain/food_item.dart';
import '../domain/food_item_prefill.dart';
import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';
import 'food_item_form_screen.dart';
import '../../recipes/presentation/recipe_display_text.dart';

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
      throw StateError(
        context.tr(
          en: 'You need to be signed in.',
          sk: 'Musíš byť prihlásený.',
        ),
      );
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
        _imageLabel = file.name.isEmpty
            ? context.tr(en: 'Fridge photo', sk: 'Fotka chladničky')
            : file.name;
        _scanFuture = _startPhotoScan(
          imageBytes: bytes,
          imageLabel: _imageLabel!,
        );
        _isPickingImage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPickingImage = false;
      });
      final isPermissionIssue =
          error is PlatformException &&
          (error.code.toLowerCase().contains('camera_access_denied') ||
              error.code.toLowerCase().contains('photo_access_denied') ||
              error.code.toLowerCase().contains('permission'));
      showErrorFeedback(
        context,
        _pickerErrorMessage(error),
        title: context.tr(
          en: isPermissionIssue ? 'Photo access blocked' : 'Photo not loaded',
          sk: isPermissionIssue
              ? 'Prístup k fotkám je blokovaný'
              : 'Fotku sa nepodarilo načítať',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanFuture = _scanFuture;

    if (scanFuture == null) {
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SafoSpacing.md,
            SafoSpacing.sm,
            SafoSpacing.md,
            SafoSpacing.xxl,
          ),
          children: [
            SafeArea(
              bottom: false,
              child: _ScanScreenHeader(
                title: context.tr(
                  en: 'Scan your fridge',
                  sk: 'Naskenuj svoju chladničku',
                ),
                subtitle: context.tr(
                  en: 'Take one clear photo and let Safo prepare detected pantry items for review.',
                  sk: 'Sprav jednu jasnú fotku a Safo pripraví rozpoznané položky na kontrolu.',
                ),
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: SafoSpacing.lg),
            Container(
              padding: const EdgeInsets.all(SafoSpacing.lg),
              decoration: BoxDecoration(
                color: SafoColors.surface,
                borderRadius: BorderRadius.circular(SafoRadii.xl),
                border: Border.all(color: SafoColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SafoSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(SafoRadii.lg),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF5EE), Color(0xFFF3F8F4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            en: 'Upload one fridge photo',
                            sk: 'Nahraj jednu fotku chladničky',
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: SafoSpacing.xs),
                        Text(
                          context.tr(
                            en: 'We will show you detected items, let you correct them, and then save selected ones to pantry.',
                            sk: 'Ukážeme rozpoznané položky, necháme ťa ich opraviť a potom uložíme vybrané do špajze.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: SafoColors.textSecondary),
                        ),
                        const SizedBox(height: SafoSpacing.md),
                        Wrap(
                          spacing: SafoSpacing.xs,
                          runSpacing: SafoSpacing.xs,
                          children: [
                            _ScanMetaChip(
                              label: context.tr(
                                en: '1 clear photo',
                                sk: '1 jasná fotka',
                              ),
                              icon: Icons.photo_camera_outlined,
                            ),
                            _ScanMetaChip(
                              label: context.tr(
                                en: 'Review before save',
                                sk: 'Kontrola pred uložením',
                              ),
                              icon: Icons.rule_folder_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.lg),
                  Text(
                    context.tr(en: 'Best results', sk: 'Najlepšie výsledky'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.sm),
                  Text(
                    context.tr(
                      en: 'Use good light, include the full shelf view, and avoid blurry photos.',
                      sk: 'Použi dobré svetlo, zachyť celý pohľad na poličky a vyhni sa rozmazanej fotke.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SafoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.lg),
                  if (_photoBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(SafoRadii.lg),
                      child: Image.memory(
                        _photoBytes!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: SafoSpacing.md),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isPickingImage
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(
                        _isPickingImage
                            ? context.tr(
                                en: 'Opening camera...',
                                sk: 'Otváram fotoaparát...',
                              )
                            : context.tr(en: 'Take photo', sk: 'Odfotiť'),
                      ),
                    ),
                  ),
                  const SizedBox(height: SafoSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isPickingImage
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(
                        context.tr(en: 'Choose photo', sk: 'Vybrať fotku'),
                      ),
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
      body: FutureBuilder<ScanSession>(
        future: scanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SafoSpacing.md,
                      SafoSpacing.sm,
                      SafoSpacing.md,
                      SafoSpacing.md,
                    ),
                    child: _ScanScreenHeader(
                      title: context.tr(
                        en: 'Scan your fridge',
                        sk: 'Naskenuj svoju chladničku',
                      ),
                      subtitle: context.tr(
                        en: 'Something went wrong while preparing your fridge scan.',
                        sk: 'Pri príprave scanu chladničky sa niečo pokazilo.',
                      ),
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: AppErrorState(
                      kind: _scanErrorKind(snapshot.error),
                      title: _scanErrorTitle(context, snapshot.error),
                      message: _scanErrorMessage(context, snapshot.error),
                      hint: _scanErrorHint(context, snapshot.error),
                      onRetry: _reload,
                    ),
                  ),
                ],
              ),
            );
          }

          final session = snapshot.data;
          if (session == null || session.candidates.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No items were detected in this scan.',
                sk: 'V tomto scane sa nepodarilo rozpoznať žiadne položky.',
              ),
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

  String _pickerErrorMessage(Object error) {
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      if (code.contains('camera_access_denied') ||
          code.contains('photo_access_denied') ||
          code.contains('permission')) {
        return context.tr(
          en: 'Camera or photo access is blocked. Allow access in system settings and try again.',
          sk: 'Prístup ku kamere alebo fotkám je zablokovaný. Povoľ ho v systémových nastaveniach a skús to znova.',
        );
      }
    }
    return context.tr(
      en: 'Failed to load photo.',
      sk: 'Fotku sa nepodarilo načítať.',
    );
  }

  AppErrorKind _scanErrorKind(Object? error) {
    if (error is ScanSessionsConfigException) {
      return AppErrorKind.setup;
    }
    if (error is FridgeScanAiException ||
        error.toString().toLowerCase().contains('configured')) {
      return AppErrorKind.setup;
    }
    return AppErrorKind.camera;
  }

  String _scanErrorTitle(BuildContext context, Object? error) {
    return switch (_scanErrorKind(error)) {
      AppErrorKind.setup => context.tr(
        en: 'Scan setup is incomplete',
        sk: 'Sken ešte nie je kompletne nastavený',
      ),
      AppErrorKind.camera => context.tr(
        en: 'Fridge scan failed',
        sk: 'Sken chladničky zlyhal',
      ),
      _ => context.tr(en: 'Scan problem', sk: 'Problém so skenom'),
    };
  }

  String _scanErrorMessage(BuildContext context, Object? error) {
    if (error is ScanSessionsConfigException ||
        error is FridgeScanAiException) {
      return error.toString();
    }
    return context.tr(
      en: 'Failed to analyze fridge photo.',
      sk: 'Fotku chladničky sa nepodarilo analyzovať.',
    );
  }

  String? _scanErrorHint(BuildContext context, Object? error) {
    if (_scanErrorKind(error) == AppErrorKind.setup) {
      return context.tr(
        en: 'Safo scan needs backend configuration before this feature can work fully.',
        sk: 'Sken v Safo potrebuje backend nastavenie, aby táto funkcia fungovala naplno.',
      );
    }
    return context.tr(
      en: 'Try another photo with better light and a clearer fridge view.',
      sk: 'Skús inú fotku s lepším svetlom a jasnejším pohľadom do chladničky.',
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
  late List<ScanCandidate> _candidates = widget.session.candidates
      .map(_applySuggestedDefaults)
      .toList();
  late final ScanSessionsRepository _scanSessionsRepository =
      ScanSessionsRepository(householdId: widget.householdId);
  bool _isSaving = false;

  ScanCandidate _applySuggestedDefaults(ScanCandidate candidate) {
    final prefill = candidate.prefill;
    final info = deriveFoodSignalInfo(prefill.name);
    final suggestion = _suggestedScanDefaults(info.itemKey);

    return candidate.copyWith(
      prefill: FoodItemPrefill(
        name: prefill.name,
        barcode: prefill.barcode,
        category: prefill.category == 'other'
            ? suggestion.category
            : prefill.category,
        storageLocation:
            prefill.storageLocation == 'pantry' &&
                suggestion.storageLocation != 'pantry'
            ? suggestion.storageLocation
            : prefill.storageLocation,
        quantity: prefill.quantity,
        unit: prefill.unit == 'pcs' && suggestion.unit != 'pcs'
            ? suggestion.unit
            : prefill.unit,
        expirationDate: prefill.expirationDate ?? suggestion.expirationDate,
        lowStockThreshold:
            prefill.lowStockThreshold ?? suggestion.lowStockThreshold,
      ),
    );
  }

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

  void _setCandidateStorage(String id, String storageLocation) {
    setState(() {
      _candidates = _candidates
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    prefill: FoodItemPrefill(
                      name: item.prefill.name,
                      barcode: item.prefill.barcode,
                      category: item.prefill.category,
                      storageLocation: storageLocation,
                      quantity: item.prefill.quantity,
                      unit: item.prefill.unit,
                      expirationDate: item.prefill.expirationDate,
                      lowStockThreshold: item.prefill.lowStockThreshold,
                    ),
                  )
                : item,
          )
          .toList();
    });
  }

  void _setCandidateExpiration(String id, DateTime? expirationDate) {
    setState(() {
      _candidates = _candidates
          .map(
            (item) => item.id == id
                ? item.copyWith(
                    prefill: FoodItemPrefill(
                      name: item.prefill.name,
                      barcode: item.prefill.barcode,
                      category: item.prefill.category,
                      storageLocation: item.prefill.storageLocation,
                      quantity: item.prefill.quantity,
                      unit: item.prefill.unit,
                      expirationDate: expirationDate,
                      lowStockThreshold: item.prefill.lowStockThreshold,
                    ),
                  )
                : item,
          )
          .toList();
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
      showErrorFeedback(
        context,
        context.tr(
          en: 'Select at least one item to continue.',
          sk: 'Vyber aspoň jednu položku, aby si mohol pokračovať.',
        ),
        title: context.tr(en: 'Nothing selected', sk: 'Nič nie je vybrané'),
      );
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
      showErrorFeedback(
        context,
        context.tr(
          en: 'Failed to save scan session.',
          sk: 'Scan sa nepodarilo uložiť.',
        ),
        title: context.tr(en: 'Scan not saved', sk: 'Scan sa neuložil'),
        actionLabel: context.tr(en: 'Retry', sk: 'Skúsiť znova'),
        onAction: _finish,
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _candidates.where((item) => item.isSelected).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SafoSpacing.md,
        SafoSpacing.sm,
        SafoSpacing.md,
        SafoSpacing.xxl,
      ),
      children: [
        SafeArea(
          bottom: false,
          child: _ScanScreenHeader(
            title: context.tr(
              en: 'Review detected items',
              sk: 'Skontroluj rozpoznané položky',
            ),
            subtitle: context.tr(
              en: 'Confirm what Safo found before anything is saved to your pantry.',
              sk: 'Potvrď, čo Safo našlo, ešte pred uložením do špajze.',
            ),
            onBack: () => Navigator.of(context).maybePop(),
          ),
        ),
        const SizedBox(height: SafoSpacing.lg),
        Container(
          padding: const EdgeInsets.all(SafoSpacing.lg),
          decoration: BoxDecoration(
            color: SafoColors.surface,
            borderRadius: BorderRadius.circular(SafoRadii.xl),
            border: Border.all(color: SafoColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  en: 'This is the scan confirmation flow. Later we will replace the mock results with real AI detection from one fridge photo.',
                  sk: 'Toto je potvrdzovací flow scanu. Neskôr nahradíme mock výsledky reálnou AI detekciou z jednej fotky chladničky.',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SafoColors.textSecondary,
                ),
              ),
              if (widget.photoBytes != null) ...[
                const SizedBox(height: SafoSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(SafoRadii.lg),
                  child: Image.memory(
                    widget.photoBytes!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: SafoSpacing.md),
              Wrap(
                spacing: SafoSpacing.xs,
                runSpacing: SafoSpacing.xs,
                children: [
                  _ScanMetaChip(
                    label: widget.session.imageLabel,
                    icon: Icons.image_outlined,
                  ),
                  _ScanMetaChip(
                    label:
                        '$selectedCount ${context.tr(en: 'selected', sk: 'vybrané')}',
                    icon: Icons.checklist_rounded,
                  ),
                ],
              ),
              const SizedBox(height: SafoSpacing.md),
              TextButton.icon(
                onPressed: widget.onPickAnotherPhoto,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(
                  context.tr(en: 'Use another photo', sk: 'Použiť inú fotku'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SafoSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _addManualCandidate,
            icon: const Icon(Icons.add),
            label: Text(
              context.tr(
                en: 'Add missing item manually',
                sk: 'Pridať chýbajúcu položku ručne',
              ),
            ),
          ),
        ),
        const SizedBox(height: SafoSpacing.md),
        ..._candidates.map(
          (candidate) => Padding(
            padding: const EdgeInsets.only(bottom: SafoSpacing.sm),
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
                title: Text(
                  localizedIngredientDisplayName(
                    context,
                    candidate.prefill.name,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${candidate.prefill.quantity} ${candidate.prefill.unit} • ${_storageLabel(context, candidate.prefill.storageLocation)} • ${(candidate.confidence * 100).round()}%',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _QuickSelectChip(
                          label: context.tr(en: 'Fridge', sk: 'Chladnička'),
                          selected:
                              candidate.prefill.storageLocation == 'fridge',
                          onTap: () =>
                              _setCandidateStorage(candidate.id, 'fridge'),
                        ),
                        _QuickSelectChip(
                          label: context.tr(en: 'Freezer', sk: 'Mraznička'),
                          selected:
                              candidate.prefill.storageLocation == 'freezer',
                          onTap: () =>
                              _setCandidateStorage(candidate.id, 'freezer'),
                        ),
                        _QuickSelectChip(
                          label: context.tr(en: 'Pantry', sk: 'Špajza'),
                          selected:
                              candidate.prefill.storageLocation == 'pantry',
                          onTap: () =>
                              _setCandidateStorage(candidate.id, 'pantry'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _QuickSelectChip(
                          label: context.tr(
                            en: 'No expiry',
                            sk: 'Bez expirácie',
                          ),
                          selected: candidate.prefill.expirationDate == null,
                          onTap: () =>
                              _setCandidateExpiration(candidate.id, null),
                        ),
                        _QuickSelectChip(
                          label: context.tr(en: 'Tomorrow', sk: 'Zajtra'),
                          selected: _isSameDayOffset(
                            candidate.prefill.expirationDate,
                            1,
                          ),
                          onTap: () => _setCandidateExpiration(
                            candidate.id,
                            _dateFromToday(1),
                          ),
                        ),
                        _QuickSelectChip(
                          label: context.tr(en: '3 days', sk: '3 dni'),
                          selected: _isSameDayOffset(
                            candidate.prefill.expirationDate,
                            3,
                          ),
                          onTap: () => _setCandidateExpiration(
                            candidate.id,
                            _dateFromToday(3),
                          ),
                        ),
                        _QuickSelectChip(
                          label: context.tr(en: '7 days', sk: '7 dní'),
                          selected: _isSameDayOffset(
                            candidate.prefill.expirationDate,
                            7,
                          ),
                          onTap: () => _setCandidateExpiration(
                            candidate.id,
                            _dateFromToday(7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _editCandidate(candidate),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: context.tr(en: 'Edit', sk: 'Upraviť'),
                      ),
                      IconButton(
                        onPressed: () => _removeCandidate(candidate.id),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: context.tr(en: 'Remove', sk: 'Odstrániť'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: SafoSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isSaving ? null : _finish,
            child: Text(
              _isSaving
                  ? context.tr(en: 'Saving scan...', sk: 'Ukladám scan...')
                  : context.tr(
                      en: 'Add selected items to pantry',
                      sk: 'Pridať vybrané položky do špajze',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _ScanScreenHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SafoSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2D4E), Color(0xFF2F4858)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              const SafoLogo(
                variant: SafoLogoVariant.horizontalLight,
                width: 84,
              ),
            ],
          ),
          const SizedBox(height: SafoSpacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanDefaultsSuggestion {
  final String category;
  final String storageLocation;
  final String unit;
  final DateTime? expirationDate;
  final double? lowStockThreshold;

  const _ScanDefaultsSuggestion({
    required this.category,
    required this.storageLocation,
    required this.unit,
    this.expirationDate,
    this.lowStockThreshold,
  });
}

_ScanDefaultsSuggestion _suggestedScanDefaults(String itemKey) {
  final now = DateTime.now();
  switch (itemKey) {
    case 'milk':
      return _ScanDefaultsSuggestion(
        category: 'dairy',
        storageLocation: 'fridge',
        unit: 'l',
        expirationDate: now.add(const Duration(days: 5)),
        lowStockThreshold: 1,
      );
    case 'cheese':
    case 'yogurt':
    case 'butter':
      return _ScanDefaultsSuggestion(
        category: 'dairy',
        storageLocation: 'fridge',
        unit: itemKey == 'butter' ? 'g' : 'pcs',
        expirationDate: now.add(const Duration(days: 5)),
        lowStockThreshold: itemKey == 'butter' ? 200 : 2,
      );
    case 'eggs':
      return _ScanDefaultsSuggestion(
        category: 'dairy',
        storageLocation: 'fridge',
        unit: 'pcs',
        expirationDate: now.add(const Duration(days: 7)),
        lowStockThreshold: 6,
      );
    case 'bread':
      return _ScanDefaultsSuggestion(
        category: 'grains',
        storageLocation: 'pantry',
        unit: 'pcs',
        expirationDate: now.add(const Duration(days: 3)),
        lowStockThreshold: 1,
      );
    case 'pasta':
    case 'rice':
    case 'flour':
      return _ScanDefaultsSuggestion(
        category: 'grains',
        storageLocation: 'pantry',
        unit: itemKey == 'rice' || itemKey == 'flour' ? 'kg' : 'g',
        expirationDate: now.add(const Duration(days: 30)),
        lowStockThreshold: itemKey == 'pasta' ? 500 : 1,
      );
    default:
      return const _ScanDefaultsSuggestion(
        category: 'other',
        storageLocation: 'pantry',
        unit: 'pcs',
      );
  }
}

DateTime _dateFromToday(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: days));
}

bool _isSameDayOffset(DateTime? date, int days) {
  if (date == null) {
    return false;
  }
  final target = _dateFromToday(days);
  return date.year == target.year &&
      date.month == target.month &&
      date.day == target.day;
}

String _storageLabel(BuildContext context, String value) {
  return switch (value) {
    'fridge' => context.tr(en: 'Fridge', sk: 'Chladnička'),
    'freezer' => context.tr(en: 'Freezer', sk: 'Mraznička'),
    'pantry' => context.tr(en: 'Pantry', sk: 'Špajza'),
    _ => value,
  };
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickSelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
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
        color: SafoColors.surfaceSoft,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: SafoColors.textSecondary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
