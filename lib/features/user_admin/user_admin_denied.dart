import 'package:flutter/material.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';

// ── Denied body ─────────────────────────────────────────────────────────

/// Clear access-denied state for deep links when the user lacks permission.
class UserAdminDeniedBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const UserAdminDeniedBody({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: AppTheme.error.withValues(alpha: 0.85),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Access denied',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry'))
            else
              FilledButton(
                onPressed: () =>
                    popPage(context, fallbackLocation: '/settings'),
                child: const Text('Back to settings'),
              ),
          ],
        ),
      ),
    );
  }
}
