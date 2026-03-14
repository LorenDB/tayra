import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/theme/app_theme.dart';

// ── Inline error state ───────────────────────────────────────────────────

/// Compact centered error widget used inside a screen body.
///
/// Shows an error icon, [message], and a Retry button.
class InlineErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const InlineErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppTheme.error.withValues(alpha: 0.7),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Centered error view (with title) ────────────────────────────────────

/// Full-width centered error used in list/grid screens that have no back
/// button (e.g. Albums, Artists).
class CenteredErrorView extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const CenteredErrorView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail page error body ───────────────────────────────────────────────

/// Full-page error used in detail screens that require a back button.
///
/// Wraps in [SafeArea] and renders a transparent [AppBar] with a back button
/// so the user can navigate away even when the load failed.
class DetailPageErrorBody extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const DetailPageErrorBody({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
