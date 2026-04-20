import 'package:flutter/material.dart';

import '../../app/localization/app_locale.dart';

enum AppErrorKind { generic, connection, sync, setup, permission, camera }

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
  final AppErrorKind kind;
  final String? title;
  final String? hint;
  final String? actionLabel;

  const AppErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.kind = AppErrorKind.generic,
    this.title,
    this.hint,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? _defaultErrorTitle(context, kind);
    final resolvedHint = hint ?? _defaultErrorHint(context, kind);
    final resolvedActionLabel =
        actionLabel ?? context.tr(en: 'Retry', sk: 'Skúsiť znova');

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
              Icon(
                _defaultErrorIcon(kind),
                size: 40,
                color: _defaultErrorColor(kind),
              ),
              const SizedBox(height: 12),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (resolvedHint != null) ...[
                const SizedBox(height: 8),
                Text(
                  resolvedHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child: Text(resolvedActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _defaultErrorTitle(BuildContext context, AppErrorKind kind) {
  return switch (kind) {
    AppErrorKind.connection => context.tr(
      en: 'Connection problem',
      sk: 'Problém s pripojením',
    ),
    AppErrorKind.sync => context.tr(
      en: 'Unable to sync data',
      sk: 'Nepodarilo sa zosynchronizovať dáta',
    ),
    AppErrorKind.setup => context.tr(
      en: 'Setup needed',
      sk: 'Treba nastavenie',
    ),
    AppErrorKind.permission => context.tr(
      en: 'Permission needed',
      sk: 'Treba povolenie',
    ),
    AppErrorKind.camera => context.tr(
      en: 'Camera problem',
      sk: 'Problém s kamerou',
    ),
    AppErrorKind.generic => context.tr(
      en: 'Something went wrong',
      sk: 'Niečo sa pokazilo',
    ),
  };
}

String? _defaultErrorHint(BuildContext context, AppErrorKind kind) {
  return switch (kind) {
    AppErrorKind.connection => context.tr(
      en: 'Check internet access and try again.',
      sk: 'Skontroluj internetové pripojenie a skús to znova.',
    ),
    AppErrorKind.sync => context.tr(
      en: 'Safo could not refresh the latest household data right now.',
      sk: 'Safo teraz nedokázalo obnoviť najnovšie dáta domácnosti.',
    ),
    AppErrorKind.setup => context.tr(
      en: 'The app still needs configuration before this screen can work.',
      sk: 'Aplikácia ešte potrebuje nastavenie, aby táto obrazovka fungovala.',
    ),
    AppErrorKind.permission => context.tr(
      en: 'Allow the needed access in system settings and try again.',
      sk: 'Povoľ potrebný prístup v systémových nastaveniach a skús to znova.',
    ),
    AppErrorKind.camera => context.tr(
      en: 'Check camera access or try another photo.',
      sk: 'Skontroluj prístup ku kamere alebo skús inú fotku.',
    ),
    AppErrorKind.generic => null,
  };
}

IconData _defaultErrorIcon(AppErrorKind kind) {
  return switch (kind) {
    AppErrorKind.connection => Icons.wifi_off_rounded,
    AppErrorKind.sync => Icons.cloud_off_rounded,
    AppErrorKind.setup => Icons.settings_suggest_rounded,
    AppErrorKind.permission => Icons.lock_outline_rounded,
    AppErrorKind.camera => Icons.camera_alt_outlined,
    AppErrorKind.generic => Icons.error_outline_rounded,
  };
}

Color _defaultErrorColor(AppErrorKind kind) {
  return switch (kind) {
    AppErrorKind.connection => const Color(0xFF1B2A41),
    AppErrorKind.sync => const Color(0xFFE07A5F),
    AppErrorKind.setup => const Color(0xFF4C6FFF),
    AppErrorKind.permission => const Color(0xFF8A4B00),
    AppErrorKind.camera => const Color(0xFFDD8B52),
    AppErrorKind.generic => const Color(0xFFE07A5F),
  };
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
