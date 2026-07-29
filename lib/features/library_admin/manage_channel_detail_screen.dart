import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/library_admin/library_admin_provider.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Providers ───────────────────────────────────────────────────────────

final manageChannelDetailProvider = FutureProvider.autoDispose
    .family<ManageChannel, String>((ref, uuid) async {
      return ref.watch(funkwhaleApiProvider).getManageChannel(uuid);
    });

final manageChannelStatsProvider = FutureProvider.autoDispose
    .family<ManageChannelStats, String>((ref, uuid) async {
      return ref.watch(funkwhaleApiProvider).getManageChannelStats(uuid);
    });

// ── Screen ──────────────────────────────────────────────────────────────

class ManageChannelDetailScreen extends ConsumerStatefulWidget {
  final String uuid;

  const ManageChannelDetailScreen({super.key, required this.uuid});

  @override
  ConsumerState<ManageChannelDetailScreen> createState() =>
      _ManageChannelDetailScreenState();
}

class _ManageChannelDetailScreenState
    extends ConsumerState<ManageChannelDetailScreen> {
  bool _deleting = false;

  Future<void> _confirmDelete(ManageChannel channel) async {
    final label = channel.name.isEmpty ? channel.uuid : channel.name;
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete channel?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Text(
              'This permanently deletes “$label” and its associated content. '
              'This cannot be undone.',
              style: const TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(funkwhaleApiProvider).deleteManageChannel(widget.uuid);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Channel deleted')));
      popPage(context, fallbackLocation: '/manage/library/channels');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageLibraryProvider);
    final detailAsync = ref.watch(manageChannelDetailProvider(widget.uuid));
    final statsAsync = ref.watch(manageChannelStatsProvider(widget.uuid));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          detailAsync.maybeWhen(
            data: (c) => c.name.isEmpty ? 'Channel' : c.name,
            orElse: () => 'Channel',
          ),
        ),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(
          fallbackLocation: '/manage/library/channels',
        ),
        actions: [
          if (detailAsync.hasValue)
            IconButton(
              tooltip: 'Delete',
              onPressed:
                  _deleting
                      ? null
                      : () => _confirmDelete(detailAsync.requireValue),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.error.withValues(alpha: 0.9),
              ),
            ),
        ],
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
                  'You do not have permission to manage instance channels.',
            );
          }
          return detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => InlineErrorState(
                  message: _friendlyError(error),
                  onRetry:
                      () => ref.invalidate(
                        manageChannelDetailProvider(widget.uuid),
                      ),
                ),
            data: (channel) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_deleting) const LinearProgressIndicator(minHeight: 2),
                  SettingsSectionHeader(title: 'Details'),
                  SettingsInfoTile(
                    icon: Icons.podcasts_rounded,
                    title: 'Name',
                    subtitle: channel.name.isEmpty ? '—' : channel.name,
                  ),
                  SettingsInfoTile(
                    icon: Icons.category_outlined,
                    title: 'Category',
                    subtitle: channel.categoryLabel,
                  ),
                  SettingsInfoTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Owner / actor',
                    subtitle: channel.ownerLabel,
                  ),
                  if (channel.attributedTo != null &&
                      channel.attributedTo!.displayLabel != channel.ownerLabel)
                    SettingsInfoTile(
                      icon: Icons.badge_outlined,
                      title: 'Attributed to',
                      subtitle: channel.attributedTo!.displayLabel,
                    ),
                  SettingsInfoTile(
                    icon: Icons.public_rounded,
                    title: 'Domain',
                    subtitle: channel.domain ?? '—',
                  ),
                  SettingsInfoTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'UUID',
                    subtitle: channel.uuid,
                  ),
                  if (channel.rssUrl != null && channel.rssUrl!.isNotEmpty)
                    SettingsInfoTile(
                      icon: Icons.rss_feed_rounded,
                      title: 'RSS URL',
                      subtitle: channel.rssUrl!,
                    ),
                  if (channel.tracksCount != null)
                    SettingsInfoTile(
                      icon: Icons.music_note_outlined,
                      title: 'Tracks',
                      subtitle: '${channel.tracksCount}',
                    ),
                  if (channel.albumsCount != null)
                    SettingsInfoTile(
                      icon: Icons.album_outlined,
                      title: 'Albums',
                      subtitle: '${channel.albumsCount}',
                    ),
                  const SizedBox(height: 8),
                  SettingsSectionHeader(title: 'Stats'),
                  statsAsync.when(
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (error, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Stats unavailable: ${_friendlyError(error)}',
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    data: (stats) {
                      return Column(
                        children: [
                          SettingsInfoTile(
                            icon: Icons.cloud_upload_outlined,
                            title: 'Uploads',
                            subtitle: '${stats.uploads}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.headphones_outlined,
                            title: 'Listenings',
                            subtitle: '${stats.listenings}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.favorite_outline,
                            title: 'Favorites',
                            subtitle: '${stats.trackFavorites}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.queue_music_outlined,
                            title: 'Playlists',
                            subtitle: '${stats.playlists}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.people_outline,
                            title: 'Follows',
                            subtitle: '${stats.follows}',
                          ),
                          SettingsInfoTile(
                            icon: Icons.report_outlined,
                            title: 'Reports',
                            subtitle: '${stats.reports}',
                          ),
                          if (stats.mediaTotalSize != null)
                            SettingsInfoTile(
                              icon: Icons.storage_outlined,
                              title: 'Media size',
                              subtitle: _formatBytes(stats.mediaTotalSize!),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed:
                          _deleting ? null : () => _confirmDelete(channel),
                      icon: const Icon(Icons.delete_outline_rounded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.5),
                        ),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      label: const Text('Delete channel'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) return 'Permission denied (403)';
    if (code == 404) return 'Channel not found';
    return error.message ?? error.toString();
  }
  return error.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
