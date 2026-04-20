import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum SafoLogoVariant {
  horizontalDark,
  horizontalLight,
  icon,
  iconTransparent,
  pill,
  stacked,
}

class SafoLogo extends StatelessWidget {
  final SafoLogoVariant variant;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafoLogo({
    super.key,
    this.variant = SafoLogoVariant.horizontalLight,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  String get _assetPath {
    return switch (variant) {
      SafoLogoVariant.horizontalDark =>
        'assets/branding/safo-horizontal-dark.svg',
      SafoLogoVariant.horizontalLight =>
        'assets/branding/safo-horizontal-light.svg',
      SafoLogoVariant.icon => 'assets/branding/safo-icon.svg',
      SafoLogoVariant.iconTransparent =>
        'assets/branding/safo-icon-transparent.svg',
      SafoLogoVariant.pill => 'assets/branding/safo-pill.svg',
      SafoLogoVariant.stacked => 'assets/branding/safo-stacked.svg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
