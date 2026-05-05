import 'package:flutter/material.dart';

import '../../app/localization/app_locale.dart';
import '../../app/theme/safo_tokens.dart';
import 'safo_logo.dart';

enum AppErrorKind { generic, connection, sync, setup, permission, camera }

AppErrorKind inferAppErrorKind(
  Object? error, {
  AppErrorKind fallback = AppErrorKind.generic,
}) {
  if (error == null) {
    return fallback;
  }

  final message = error.toString().toLowerCase();

  const connectionHints = [
    'socketexception',
    'failed host lookup',
    'network',
    'connection',
    'internet',
    'offline',
    'timed out',
    'timeout',
    'clientexception',
  ];
  if (connectionHints.any(message.contains)) {
    return AppErrorKind.connection;
  }

  const permissionHints = [
    'permission',
    'not allowed',
    'denied',
    'forbidden',
    'unauthorized',
  ];
  if (permissionHints.any(message.contains)) {
    return AppErrorKind.permission;
  }

  const cameraHints = ['camera', 'photo library', 'gallery', 'image picker'];
  if (cameraHints.any(message.contains)) {
    return AppErrorKind.camera;
  }

  const setupHints = [
    'config',
    'configuration',
    'missing',
    'not set',
    'setup',
    'supabase',
    'anon key',
    'url',
  ];
  if (setupHints.any(message.contains)) {
    return AppErrorKind.setup;
  }

  return fallback;
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.all(SafoSpacing.lg),
        padding: const EdgeInsets.all(SafoSpacing.xl),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const SafoLogo(
              variant: SafoLogoVariant.iconTransparent,
              width: 52,
              height: 52,
            ),
            const SizedBox(height: SafoSpacing.md),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SafoColors.primarySoft,
                borderRadius: BorderRadius.circular(SafoRadii.lg),
              ),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: SafoSpacing.md),
            Text(
              context.tr(
                en: 'Loading your items...',
                sk: 'Načítavam tvoje položky...',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SafoSpacing.xs),
            Text(
              context.tr(
                en: 'Safo is preparing the latest view for your kitchen.',
                sk: 'Safo pripravuje najnovší pohľad na tvoju kuchyňu.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SafoColors.textSecondary,
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

    if (kind == AppErrorKind.connection) {
      return AppOfflineState(
        title: resolvedTitle,
        message: message,
        hint: resolvedHint,
        actionLabel: resolvedActionLabel,
        onRetry: onRetry,
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SafoSpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(SafoSpacing.xl),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _defaultErrorColor(kind).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SafoRadii.lg),
                ),
                child: Icon(
                  _defaultErrorIcon(kind),
                  size: 28,
                  color: _defaultErrorColor(kind),
                ),
              ),
              const SizedBox(height: SafoSpacing.md),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: SafoSpacing.sm),
              Text(message, textAlign: TextAlign.center),
              if (resolvedHint != null) ...[
                const SizedBox(height: SafoSpacing.sm),
                Text(
                  resolvedHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: SafoSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(resolvedActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppOfflineState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final String? title;
  final String? hint;
  final String? actionLabel;

  const AppOfflineState({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.hint,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SafoSpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(SafoSpacing.xl),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: SafoColors.primarySoft,
                  borderRadius: BorderRadius.circular(SafoRadii.xl),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 30,
                  color: SafoColors.primary,
                ),
              ),
              const SizedBox(height: SafoSpacing.md),
              Text(
                title ??
                    context.tr(
                      en: 'You are offline',
                      sk: 'Si offline',
                    ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SafoSpacing.sm),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: SafoSpacing.sm),
              Text(
                hint ??
                    context.tr(
                      en: 'Check your internet connection and try again in a moment.',
                      sk: 'Skontroluj internetové pripojenie a skús to znova o chvíľu.',
                    ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SafoColors.textSecondary,
                ),
              ),
              const SizedBox(height: SafoSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  actionLabel ?? context.tr(en: 'Try again', sk: 'Skúsiť znova'),
                ),
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
        padding: const EdgeInsets.fromLTRB(
          SafoSpacing.lg,
          120,
          SafoSpacing.lg,
          SafoSpacing.xxl,
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(SafoSpacing.xl),
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
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: SafoColors.primarySoft,
                    borderRadius: BorderRadius.circular(SafoRadii.lg),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 28,
                    color: SafoColors.primary,
                  ),
                ),
                const SizedBox(height: SafoSpacing.md),
                Text(
                  context.tr(
                    en: 'Nothing here yet',
                    sk: 'Zatiaľ tu nič nie je',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: SafoSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SafoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SafoSpacing.md),
          Center(
            child: Text(
              context.tr(
                en: 'Pull down to refresh.',
                sk: 'Potiahni nadol pre obnovenie.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: SafoColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppEmptyCard extends StatelessWidget {
  final String message;
  final String? title;

  const AppEmptyCard({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(SafoSpacing.xl),
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
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: SafoColors.primarySoft,
              borderRadius: BorderRadius.circular(SafoRadii.lg),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 28,
              color: SafoColors.primary,
            ),
          ),
          const SizedBox(height: SafoSpacing.md),
          Text(
            title ??
                context.tr(
                  en: 'Nothing here yet',
                  sk: 'Zatiaľ tu nič nie je',
                ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SafoSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SafoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
