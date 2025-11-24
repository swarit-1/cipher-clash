import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum CyberpunkButtonVariant {
  primary,
  secondary,
  success,
  danger,
  ghost,
}

class CyberpunkButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final CyberpunkButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;

  const CyberpunkButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.variant = CyberpunkButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.padding,
  }) : super(key: key);

  @override
  State<CyberpunkButton> createState() => _CyberpunkButtonState();
}

class _CyberpunkButtonState extends State<CyberpunkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.variant) {
      case CyberpunkButtonVariant.primary:
        return AppTheme.cyberBlue;
      case CyberpunkButtonVariant.secondary:
        return AppTheme.neonPurple;
      case CyberpunkButtonVariant.success:
        return AppTheme.electricGreen;
      case CyberpunkButtonVariant.danger:
        return AppTheme.neonRed;
      case CyberpunkButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    if (widget.variant == CyberpunkButtonVariant.ghost) {
      return AppTheme.cyberBlue;
    }
    return Colors.black;
  }

  List<BoxShadow> get _glowEffect {
    if (widget.variant == CyberpunkButtonVariant.ghost) return [];

    switch (widget.variant) {
      case CyberpunkButtonVariant.primary:
        return AppTheme.glowCyberBlue();
      case CyberpunkButtonVariant.secondary:
        return AppTheme.glowNeonPurple();
      case CyberpunkButtonVariant.success:
        return AppTheme.glowElectricGreen();
      case CyberpunkButtonVariant.danger:
        return AppTheme.glowNeonRed();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: AppTheme.spacing1),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          );

    return SizedBox(
      width: widget.fullWidth ? double.infinity : null,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              boxShadow: widget.onPressed != null && !widget.isLoading
                  ? _glowEffect
                      .map((shadow) => BoxShadow(
                            color: shadow.color.withValues(
                              alpha: shadow.color.a * _glowAnimation.value,
                            ),
                            blurRadius: shadow.blurRadius,
                            spreadRadius: shadow.spreadRadius,
                            offset: shadow.offset,
                          ))
                      .toList()
                  : null,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed != null && !widget.isLoading
                    ? () {
                        HapticFeedback.mediumImpact();
                        widget.onPressed!();
                      }
                    : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Container(
                  padding: widget.padding ??
                      const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing3,
                        vertical: AppTheme.spacing2,
                      ),
                  decoration: BoxDecoration(
                    color: widget.onPressed != null && !widget.isLoading
                        ? _backgroundColor
                        : AppTheme.textDisabled,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: widget.variant == CyberpunkButtonVariant.ghost
                        ? Border.all(color: AppTheme.cyberBlue, width: 2)
                        : null,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: content,
      ),
    );
  }
}
