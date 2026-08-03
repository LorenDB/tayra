import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/library_admin/library_admin_provider.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Hub for library admin (`/manage/library`).
///
/// Links to libraries, uploads, tags, and channels. Unauthorized users see a
/// denied state.
class LibraryAdminScreen extends ConsumerWidget {
  const LibraryAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canManageLibraryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Library admin'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: canManage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => LibraryAdminDeniedBody(
              message: 'Could not verify library permissions.\n$error',
              onRetry: () => ref.invalidate(meUserProvider),
            ),
        data: (allowed) {
          if (!allowed) {
            return const LibraryAdminDeniedBody(
              message:
                  'You do not have permission to manage the instance library. '
                  'Ask an administrator to grant the library permission.',
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // Instance-wide tools — distinct from personal "Your library"
              // upload under Settings.
              const SettingsSectionHeader(title: 'Instance library'),
              SettingsActionTile(
                icon: Icons.library_music_rounded,
                title: 'All libraries',
                subtitle: 'Browse, edit, and delete libraries across the pod',
                onTap: () => context.push('/manage/library/libraries'),
              ),
              SettingsActionTile(
                icon: Icons.cloud_upload_rounded,
                title: 'Uploads',
                subtitle: 'Browse and delete uploads by import status',
                onTap: () => context.push('/manage/library/uploads'),
              ),
              SettingsActionTile(
                icon: Icons.label_rounded,
                title: 'Tags',
                subtitle: 'Create and delete tags',
                onTap: () => context.push('/manage/library/tags'),
              ),
              SettingsActionTile(
                icon: Icons.podcasts_rounded,
                title: 'Channels',
                subtitle: 'Browse and delete podcast / artist channels',
                onTap: () => context.push('/manage/library/channels'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Denied body ─────────────────────────────────────────────────────────

/// Clear access-denied state for deep links when the user lacks permission.
class LibraryAdminDeniedBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const LibraryAdminDeniedBody({
    super.key,
    required this.message,
    this.onRetry,
  });

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
                onPressed:
                    () => popPage(context, fallbackLocation: '/settings'),
                child: const Text('Back to settings'),
              ),
          ],
        ),
      ),
    );
  }
}
