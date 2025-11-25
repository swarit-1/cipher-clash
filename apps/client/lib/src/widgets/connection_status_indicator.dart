import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Real-time connection status indicator
/// Shows connection state with animated dot
class ConnectionStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final VoidCallback? onTap;

  const ConnectionStatusIndicator({
    Key? key,
    required this.isConnected,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isConnected
              ? AppTheme.electricGreen.withValues(alpha: 0.1)
              : AppTheme.neonRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected ? AppTheme.electricGreen : AppTheme.neonRed,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? AppTheme.electricGreen : AppTheme.neonRed,
                boxShadow: [
                  BoxShadow(
                    color: (isConnected
                            ? AppTheme.electricGreen
                            : AppTheme.neonRed)
                        .withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(),
                )
                .fadeIn(duration: 500.ms)
                .then()
                .fadeOut(duration: 500.ms),
            const SizedBox(width: 8),
            Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isConnected
                        ? AppTheme.electricGreen
                        : AppTheme.neonRed,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
