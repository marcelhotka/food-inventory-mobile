import 'package:flutter/material.dart';

import '../../app/theme/safo_tokens.dart';

class SafoAlertDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget? content;
  final List<Widget> actions;
  final String? badge;

  const SafoAlertDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.content,
    this.actions = const <Widget>[],
    this.badge,
    this.icon = Icons.info_outline_rounded,
    this.iconColor = SafoColors.primary,
    this.iconBackgroundColor = SafoColors.primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: SafoSpacing.lg,
        vertical: SafoSpacing.xl,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(SafoSpacing.lg),
        decoration: BoxDecoration(
          color: SafoColors.surface,
          borderRadius: BorderRadius.circular(SafoRadii.xl),
          border: Border.all(color: SafoColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SafoSpacing.sm,
                  vertical: SafoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: SafoColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(SafoRadii.pill),
                  border: Border.all(color: SafoColors.border),
                ),
                child: Text(
                  badge!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: SafoSpacing.md),
            ],
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(SafoRadii.md),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: SafoSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: SafoSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SafoColors.textSecondary,
                ),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: SafoSpacing.lg),
              content!,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: SafoSpacing.lg),
              Wrap(
                spacing: SafoSpacing.sm,
                runSpacing: SafoSpacing.sm,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
