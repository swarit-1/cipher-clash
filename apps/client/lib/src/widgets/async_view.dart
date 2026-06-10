import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard loading / error / empty presentation for remote data, so no
/// screen ships a raw spinner or a blank panel.
class AsyncView extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.loading,
    this.error,
    this.empty = false,
    this.emptyIcon = Icons.inbox,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.onRetry,
    required this.child,
  });

  final bool loading;
  final String? error;
  final bool empty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              'Decrypting…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppTheme.neonRed),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                'TRANSMISSION FAILED',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.neonRed,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing1),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppTheme.spacing2),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETRY'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                emptyTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              if (emptyMessage != null) ...[
                const SizedBox(height: AppTheme.spacing1),
                Text(
                  emptyMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return child;
  }
}
