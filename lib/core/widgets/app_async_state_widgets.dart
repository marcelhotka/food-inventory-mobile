import 'package:flutter/material.dart';

import '../../app/localization/app_locale.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE6DDCF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr(
                en: 'Loading your items...',
                sk: 'Načítavam tvoje položky...',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE6DDCF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.tr(en: 'Retry', sk: 'Skúsiť znova')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRefresh;

  const AppEmptyState({
    super.key,
    required this.message,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 120),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DDCF)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 42,
                  color: Color(0xFF4E7A51),
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(
                    en: 'Nothing here yet',
                    sk: 'Zatiaľ tu nič nie je',
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 10),
          Center(
            child: Text(
              context.tr(
                en: 'Pull down to refresh.',
                sk: 'Potiahni nadol pre obnovenie.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
