import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GlowCardVariant {
  primary,
  secondary,
  success,
  none,
}

class GlowCard extends StatelessWidget {
  final Widget child;
  final GlowCardVariant glowVariant;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool enableGlow;

  const GlowCard({
    Key? key,
    required this.child,
    this.glowVariant = GlowCardVariant.none,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.backgroundColor,
    this.enableGlow = true,
  }) : super(key: key);

  List<BoxShadow> get _glowEffect {
    if (!enableGlow || glowVariant == GlowCardVariant.none) {
      return AppTheme.cardShadow;
    }

    switch (glowVariant) {
      case GlowCardVariant.primary:
        return AppTheme.glowCyberBlue(intensity: 0.6);
      case GlowCardVariant.secondary:
        return AppTheme.glowNeonPurple(intensity: 0.6);
      case GlowCardVariant.success:
        return AppTheme.glowElectricGreen(intensity: 0.6);
      default:
        return AppTheme.cardShadow;
    }
  }

  Color get _borderColor {
    switch (glowVariant) {
      case GlowCardVariant.primary:
        return AppTheme.cyberBlue;
      case GlowCardVariant.secondary:
        return AppTheme.neonPurple;
      case GlowCardVariant.success:
        return AppTheme.electricGreen;
      default:
        return AppTheme.cyberBlue.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppTheme.spacing2),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.darkNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _borderColor,
          width: glowVariant != GlowCardVariant.none ? 1.5 : 1,
        ),
        boxShadow: _glowEffect,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
