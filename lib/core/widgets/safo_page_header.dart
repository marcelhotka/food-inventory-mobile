import 'package:flutter/material.dart';

import '../../app/theme/safo_tokens.dart';
import 'safo_logo.dart';

class SafoPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final List<Widget> badges;
  final bool dark;

  const SafoPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
    this.trailing,
    this.badges = const <Widget>[],
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = dark ? Colors.white : SafoColors.textPrimary;
    final subtitleColor = dark
        ? Colors.white.withValues(alpha: 0.82)
        : SafoColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(SafoSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SafoRadii.xl),
        color: dark ? null : SafoColors.surface,
        border: dark ? null : Border.all(color: SafoColors.border),
        gradient: dark
            ? const LinearGradient(
                colors: [Color(0xFF1E2D4E), Color(0xFF2F4858)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    foregroundColor: dark
                        ? Colors.white
                        : SafoColors.textPrimary,
                    backgroundColor: dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : SafoColors.surfaceSoft,
                    side: dark
                        ? null
                        : const BorderSide(color: SafoColors.border),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const SafoLogo(
                  variant: SafoLogoVariant.iconTransparent,
                  width: 44,
                  height: 44,
                ),
              const Spacer(),
              trailing ??
                  SafoLogo(
                    variant: dark
                        ? SafoLogoVariant.horizontalLight
                        : SafoLogoVariant.pill,
                    width: dark ? 84 : 88,
                  ),
            ],
          ),
          const SizedBox(height: SafoSpacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: SafoSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: SafoSpacing.md),
            Wrap(
              spacing: SafoSpacing.xs,
              runSpacing: SafoSpacing.xs,
              children: badges,
            ),
          ],
        ],
      ),
    );
  }
}
