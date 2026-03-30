import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_async_state_widgets.dart';
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
      appBar: AppBar(
        title: Text(context.tr(en: 'Scan history', sk: 'História scanov')),
      ),
      body: FutureBuilder<List<ScanSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: context.tr(
                en: 'Failed to load scan history.',
                sk: 'Históriu scanov sa nepodarilo načítať.',
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

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final selectedCount = session.candidates
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE6DDCF)),
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
                        const SizedBox(height: 8),
                        Text(
                          '${_formatDateTime(session.createdAt)} • $selectedCount ${context.tr(en: 'selected', sk: 'vybrané')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
      appBar: AppBar(
        title: Text(context.tr(en: 'Scan detail', sk: 'Detail scanu')),
      ),
      body: FutureBuilder<ScanSession>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
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
                        session.imageLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDateTime(session.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...session.candidates.map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: candidate.isSelected
              ? const Color(0xFFC7D7C3)
              : const Color(0xFFE6DDCF),
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
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (prefill.barcode != null && prefill.barcode!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr(en: 'Code', sk: 'Kód')} ${prefill.barcode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (prefill.expirationDate != null) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr(en: 'Expires', sk: 'Spotreba do')} ${_formatDate(prefill.expirationDate!)}',
              style: Theme.of(context).textTheme.bodySmall,
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
    final color = isSelected
        ? const Color(0xFFDDEBD7)
        : const Color(0xFFF1E2D1);
    final text = isSelected
        ? context.tr(en: 'Confirmed', sk: 'Potvrdené')
        : context.tr(en: 'Rejected', sk: 'Odmietnuté');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
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
        color: const Color(0xFFF5F1E7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
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
