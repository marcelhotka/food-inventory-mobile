import 'package:flutter/material.dart';

import '../../../app/localization/app_locale.dart';
import '../../../core/widgets/app_feedback.dart';
import '../data/auth_repository.dart';

Future<void> confirmAndSignOut(
  BuildContext context,
  AuthRepository authRepository,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          dialogContext.tr(
            en: 'Sign out and start over?',
            sk: 'Odhlásiť sa a začať odznova?',
          ),
        ),
        content: Text(
          dialogContext.tr(
            en: 'Safo will return to the first welcome screen so you can go through the full setup again.',
            sk: 'Safo ťa vráti na prvú úvodnú obrazovku, aby si mohol prejsť celý setup znova.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr(en: 'Cancel', sk: 'Zrušiť')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr(en: 'Sign out', sk: 'Odhlásiť sa')),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await authRepository.signOut();
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    showErrorFeedback(
      context,
      context.tr(
        en: 'Safo could not sign you out right now.',
        sk: 'Safo ťa teraz nedokázalo odhlásiť.',
      ),
      title: context.tr(
        en: 'Sign-out failed',
        sk: 'Odhlásenie zlyhalo',
      ),
    );
  }
}
