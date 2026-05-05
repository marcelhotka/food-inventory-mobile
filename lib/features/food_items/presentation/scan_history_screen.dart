import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../app/theme/safo_tokens.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/safo_logo.dart';
import '../data/scan_sessions_repository.dart';
import '../domain/scan_candidate.dart';
import '../domain/scan_session.dart';

class ScanHistoryScreen extends StatefulWidget {
  final String householdId;

  const ScanHistoryScreen({super.key, required this.householdId});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  late final ScanSessionsRepository _repository = ScanSessionsRepository(
    householdId: widget.householdId,
  );

  late Future<List<ScanSession>> _sessionsFuture = _repository
      .getScanSessions();

  Future<void> _reload() async {
    setState(() {
      _sessionsFuture = _repository.getScanSessions();
    });
    await _sessionsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<ScanSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              kind: inferAppErrorKind(
                snapshot.error,
                fallback: AppErrorKind.sync,
              ),
              title: context.tr(
                en: 'Scan history is unavailable',
                sk: 'História scanov nie je k dispozícii',
              ),
              message: context.tr(
                en: 'Failed to load scan history.',
                sk: 'Históriu scanov sa nepodarilo načítať.',
              ),
              hint: context.tr(
                en: 'Safo could not load previous fridge scans right now.',
                sk: 'Safo teraz nedokázalo načítať predchádzajúce scany chladničky.',
              ),
              onRetry: _reload,
            );
          }

          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return AppEmptyState(
              message: context.tr(
                en: 'No fridge scans yet.',
                sk: 'Zatiaľ nemáš žiadne scany chladničky.',
              ),
              onRefresh: _reload,
            );
          }

          final selectedCount = sessions.fold<int>(
            0,
            (sum, session) =>
                sum +
                session.candidates.where((item) => item.isSelected).length,
          );
          final latestScan = sessions.first.createdAt;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                SafoSpacing.md,
                SafoSpacing.sm,
                SafoSpacing.md,
                SafoSpacing.xxl,
              ),
              itemCount: sessions.length + 2,
              separatorBuilder: (_, index) => SizedBox(
                height: index == 0 ? SafoSpacing.lg : SafoSpacing.sm,
              ),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ScanHistoryHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                  );
                }

                if (index == 1) {
                  return _ScanHistorySummary(
                    sessionCount: sessions.length,
                    selectedCount: selectedCount,
                    latestScan: latestScan,
                  );
                }

                final session = sessions[index - 2];
                final selectedCountForSession = session.candidates
                    .where((item) => item.isSelected)
                    .length;

                return InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ScanSessionDetailScreen(
                          householdId: widget.householdId,
                          sessionId: session.id,
                          initialSession: session,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(SafoSpacing.lg),
                    decoration: BoxDecoration(
                      color: SafoColors.surface,
                      borderRadius: BorderRadius.circular(SafoRadii.xl),
                      border: Border.all(color: SafoColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120F172A),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.imageLabel,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        const SizedBox(height: SafoSpacing.xs),
                        Text(
                          '${_formatDateTime(session.createdAt)} • $selectedCountForSession ${context.tr(en: 'selected', sk: 'vybrané')}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: SafoColors.textSecondary),
                        ),
                        const SizedBox(height: SafoSpacing.sm),
                        Wrap(
                          spacing: SafoSpacing.xs,
                          runSpacing: SafoSpacing.xs,
                          children: [
                            _HistoryChip(
                              icon: Icons.inventory_2_outlined,
                              label:
                                  '${session.candidates.length} ${context.tr(en: 'detected', sk: 'rozpoznané')}',
                            ),
                            _HistoryChip(
                              icon: Icons.check_circle_outline_rounded,
                              label:
                                  '$selectedCountForSession ${context.tr(en: 'confirmed', sk: 'potvrdené')}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ScanSessionDetailScreen extends StatefulWidget {
  final String householdId;
  final String sessionId;
  final ScanSession? initialSession;

  const ScanSessionDetailScreen({
    super.key,
    required this.householdId,
    required this.sessionId,
    this.initialSession,
  });

  @override
  State<ScanSessionDetailScreen> createState() =>
      _ScanSessionDetailScreenState();
}

class _ScanSessionDetailScreenState extends State<ScanSessionDetailScreen> {
  late final ScanSessionsRepository _repository = ScanSessionsRepository(
    householdId: widget.householdId,
  );

  late Future<ScanSession> _sessionFuture = widget.initialSession == null
      ? _repository.getScanSession(widget.sessionId)
      : Future.value(widget.initialSession!);

  Future<void> _reload() async {
    setState(() {
      _sessionFuture = _repository.getScanSession(widget.sessionId);
    });
    await _sessionFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ScanSession>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              kind: inferAppErrorKind(
                snapshot.error,
                fallback: AppErrorKind.sync,
              ),
              message: context.tr(
                en: 'Failed to load scan detail.',
                sk: 'Detail scanu sa nepodarilo načítať.',
              ),
              onRetry: _reload,
            );
          }

          final session = snapshot.data;
          if (session == null) {
            return AppEmptyState(
              message: context.tr(
                en: 'This scan is no longer available.',
                sk: 'Tento scan už nie je dostupný.',
              ),
              onRefresh: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SafoSpacing.md,
                SafoSpacing.sm,
                SafoSpacing.md,
                SafoSpacing.xxl,
              ),
              children: [
                _ScanHistoryDetailHeader(
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: SafoSpacing.lg),
                _ScanSessionOverview(session: session),
                const SizedBox(height: SafoSpacing.md),
                ...session.candidates.map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: SafoSpacing.sm),
                    child: _CandidateCard(candidate: candidate),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  final ScanCandidate candidate;

  const _CandidateCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final prefill = candidate.prefill;

    return Container(
      padding: const EdgeInsets.all(SafoSpacing.lg),
      decoration: BoxDecoration(
        color: SafoColors.surface,
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        border: Border.all(
          color: candidate.isSelected
              ? SafoColors.primary.withValues(alpha: 0.25)
              : SafoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prefill.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(isSelected: candidate.isSelected),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatQuantity(prefill.quantity)} ${prefill.unit} • ${_labelize(context, prefill.storageLocation)} • ${_labelize(context, prefill.category)}',
          ),
          const SizedBox(height: 6),
          Text(
            '${context.tr(en: 'Confidence', sk: 'Istota')} ${(candidate.confidence * 100).round()}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: SafoColors.textSecondary),
          ),
          if (prefill.barcode != null && prefill.barcode!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr(en: 'Code', sk: 'Kód')} ${prefill.barcode}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SafoColors.textSecondary),
            ),
          ],
          if (prefill.expirationDate != null) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr(en: 'Expires', sk: 'Spotreba do')} ${_formatDate(prefill.expirationDate!)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SafoColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isSelected;

  const _StatusChip({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? SafoColors.primarySoft : SafoColors.warningSoft;
    final text = isSelected
        ? context.tr(en: 'Confirmed', sk: 'Potvrdené')
        : context.tr(en: 'Rejected', sk: 'Odmietnuté');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SafoRadii.pill),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HistoryChip({required this.icon, required this.label});

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

class _ScanHistoryHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ScanHistoryHeader({required this.onBack});

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
            context.tr(
              en: 'Fridge scan history',
              sk: 'História scanov chladničky',
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            context.tr(
              en: 'Review previous scans, confirmed items, and quick fridge captures in one place.',
              sk: 'Pozri si predchádzajúce scany, potvrdené položky a rýchle snímky chladničky na jednom mieste.',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistorySummary extends StatelessWidget {
  final int sessionCount;
  final int selectedCount;
  final DateTime latestScan;

  const _ScanHistorySummary({
    required this.sessionCount,
    required this.selectedCount,
    required this.latestScan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScanHistorySummaryCard(
            label: context.tr(en: 'Scans', sk: 'Scany'),
            value: '$sessionCount',
            tone: SafoColors.primarySoft,
            accent: SafoColors.primary,
          ),
        ),
        const SizedBox(width: SafoSpacing.sm),
        Expanded(
          child: _ScanHistorySummaryCard(
            label: context.tr(en: 'Confirmed', sk: 'Potvrdené'),
            value: '$selectedCount',
            tone: SafoColors.accentSoft,
            accent: SafoColors.accent,
          ),
        ),
        const SizedBox(width: SafoSpacing.sm),
        Expanded(
          child: _ScanHistorySummaryCard(
            label: context.tr(en: 'Latest', sk: 'Posledný'),
            value: _formatShortDate(latestScan),
            tone: SafoColors.warningSoft,
            accent: SafoColors.warning,
          ),
        ),
      ],
    );
  }
}

class _ScanHistorySummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color tone;
  final Color accent;

  const _ScanHistorySummaryCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SafoSpacing.md),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(SafoRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: SafoColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistoryDetailHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ScanHistoryDetailHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          style: IconButton.styleFrom(
            foregroundColor: SafoColors.textPrimary,
            backgroundColor: SafoColors.surface,
            side: const BorderSide(color: SafoColors.border),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: SafoSpacing.sm),
        const SafoLogo(variant: SafoLogoVariant.pill, width: 82),
      ],
    );
  }
}

class _ScanSessionOverview extends StatelessWidget {
  final ScanSession session;

  const _ScanSessionOverview({required this.session});

  @override
  Widget build(BuildContext context) {
    final selectedCount = session.candidates
        .where((item) => item.isSelected)
        .length;

    return Container(
      padding: const EdgeInsets.all(SafoSpacing.lg),
      decoration: BoxDecoration(
        color: SafoColors.surface,
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        border: Border.all(color: SafoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.imageLabel,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            _formatDateTime(session.createdAt),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: SafoColors.textSecondary),
          ),
          const SizedBox(height: SafoSpacing.md),
          Wrap(
            spacing: SafoSpacing.xs,
            runSpacing: SafoSpacing.xs,
            children: [
              _HistoryChip(
                icon: Icons.inventory_2_outlined,
                label:
                    '${session.candidates.length} ${context.tr(en: 'detected', sk: 'rozpoznané')}',
              ),
              _HistoryChip(
                icon: Icons.check_circle_outline_rounded,
                label:
                    '$selectedCount ${context.tr(en: 'confirmed', sk: 'potvrdené')}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  return '$day.$month.$year';
}

String _formatShortDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.';
}

String _formatQuantity(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _labelize(BuildContext context, String value) {
  if (value.isEmpty) {
    return value;
  }

  switch (value) {
    case 'fridge':
      return context.tr(en: 'Fridge', sk: 'Chladnička');
    case 'freezer':
      return context.tr(en: 'Freezer', sk: 'Mraznička');
    case 'pantry':
      return context.tr(en: 'Pantry', sk: 'Špajza');
    case 'produce':
      return context.tr(en: 'Produce', sk: 'Ovocie a zelenina');
    case 'dairy':
      return context.tr(en: 'Dairy', sk: 'Mliečne výrobky');
    case 'meat':
      return context.tr(en: 'Meat', sk: 'Mäso');
    case 'grains':
      return context.tr(en: 'Grains', sk: 'Obilniny');
    case 'canned':
      return context.tr(en: 'Canned', sk: 'Konzervy');
    case 'frozen':
      return context.tr(en: 'Frozen', sk: 'Mrazené');
    case 'beverages':
      return context.tr(en: 'Beverages', sk: 'Nápoje');
    case 'other':
      return context.tr(en: 'Other', sk: 'Ostatné');
  }

  final words = value.split('_');
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
