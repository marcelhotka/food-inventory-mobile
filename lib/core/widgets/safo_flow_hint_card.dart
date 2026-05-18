import 'package:flutter/material.dart';

import '../../app/theme/safo_tokens.dart';

class SafoFlowHintCard extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final List<String> highlights;

  const SafoFlowHintCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.highlights = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(SafoSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FBFF), Color(0xFFF1F7F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFE2EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: SafoColors.accentSoft,
              borderRadius: BorderRadius.circular(SafoRadii.lg),
            ),
            child: Icon(icon, color: SafoColors.accent),
          ),
          const SizedBox(height: SafoSpacing.md),
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: SafoColors.accent,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: SafoColors.textPrimary,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SafoColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: SafoSpacing.md),
            Wrap(
              spacing: SafoSpacing.sm,
              runSpacing: SafoSpacing.sm,
              children: highlights
                  .map(
                    (highlight) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SafoSpacing.sm,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(SafoRadii.pill),
                        border: Border.all(color: const Color(0xFFDCE6F1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: SafoColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            highlight,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: SafoColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
