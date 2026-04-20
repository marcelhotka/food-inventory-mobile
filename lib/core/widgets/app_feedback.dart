import 'package:flutter/material.dart';

enum AppFeedbackKind { success, error, warning, info }

void showSuccessFeedback(BuildContext context, String message) {
  showAppFeedback(
    context,
    message: message,
    kind: AppFeedbackKind.success,
  );
}

void showErrorFeedback(
  BuildContext context,
  String message, {
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  showAppFeedback(
    context,
    message: message,
    kind: AppFeedbackKind.error,
    title: title,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

void showAppFeedback(
  BuildContext context, {
  required String message,
  AppFeedbackKind kind = AppFeedbackKind.info,
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final backgroundColor = switch (kind) {
    AppFeedbackKind.success => const Color(0xFF244D36),
    AppFeedbackKind.error => colorScheme.error,
    AppFeedbackKind.warning => const Color(0xFF8A5A00),
    AppFeedbackKind.info => const Color(0xFF2F4858),
  };
  final icon = switch (kind) {
    AppFeedbackKind.success => Icons.check_circle_outline_rounded,
    AppFeedbackKind.error => Icons.error_outline_rounded,
    AppFeedbackKind.warning => Icons.warning_amber_rounded,
    AppFeedbackKind.info => Icons.info_outline_rounded,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.trim().isNotEmpty) ...[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
}
