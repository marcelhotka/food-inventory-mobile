import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_async_state_widgets.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/household_repository.dart';
import '../domain/household.dart';
import '../domain/household_member.dart';

class HouseholdScreen extends StatefulWidget {
  final Household household;

  const HouseholdScreen({super.key, required this.household});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  late final HouseholdRepository _repository = HouseholdRepository();
  late Future<List<HouseholdMember>> _membersFuture = _repository.getMembers(
    widget.household.id,
  );

  Future<void> _reload() async {
    setState(() {
      _membersFuture = _repository.getMembers(widget.household.id);
    });
    await _membersFuture;
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.household.id));
    if (!mounted) return;
    showSuccessFeedback(context, 'Household code copied.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        title: const Text('Household'),
      ),
      body: FutureBuilder<List<HouseholdMember>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingState();
          }

          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Failed to load household members.',
              onRetry: _reload,
            );
          }

          final members = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.household.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Share this household code with another family member so they can join the same pantry and shopping list.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EEE4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(
                            widget.household.id,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy code'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Members',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (members.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          const Icon(Icons.group_outlined, size: 36),
                          const SizedBox(height: 12),
                          const Text(
                            'No household members visible yet.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try pulling to refresh after another user joins with your household code.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(member.role == 'owner' ? 'O' : 'M'),
                          ),
                          title: Text(
                            member.role == 'owner' ? 'Owner' : 'Member',
                          ),
                          subtitle: Text(member.userId),
                        ),
                      ),
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
