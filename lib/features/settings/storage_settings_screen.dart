import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Offline mode, downloads, and local cache management (native platforms).
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cacheStatsAsync = ref.watch(cacheStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Downloads & storage'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SettingsSectionHeader(title: 'Network'),
          SettingsSwitchTile(
            icon: Icons.cloud_off_rounded,
            title: 'Force offline mode',
            subtitle: 'Only show cached content; disable network access',
            value: settings.forceOfflineMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setForceOfflineMode(value);
            },
          ),

          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'Downloads'),
          SettingsSwitchTile(
            icon: Icons.favorite_rounded,
            title: 'Auto-download favorites',
            subtitle: 'Keep favorited tracks available offline',
            value: settings.autoDownloadFavorites,
            onChanged: (value) {
              Analytics.track('auto_download_favorites_toggled', {
                'enabled': value,
              });
              ref
                  .read(settingsProvider.notifier)
                  .setAutoDownloadFavorites(value);
            },
          ),
          SettingsSwitchTile(
            icon: Icons.wifi_rounded,
            title: 'Download on Wi‑Fi only',
            subtitle: 'Pause the download queue on mobile data',
            value: settings.downloadWifiOnly,
            onChanged: (value) {
              Analytics.track('download_wifi_only_toggled', {'enabled': value});
              ref.read(settingsProvider.notifier).setDownloadWifiOnly(value);
            },
          ),
          SettingsSwitchTile(
            icon: Icons.podcasts_rounded,
            title: 'Auto-download podcast episodes',
            subtitle: 'Download the latest episodes of subscribed shows',
            value: settings.autoDownloadPodcastEpisodes,
            onChanged: (value) {
              Analytics.track('auto_download_podcasts_toggled', {
                'enabled': value,
              });
              ref
                  .read(settingsProvider.notifier)
                  .setAutoDownloadPodcastEpisodes(value);
            },
          ),
          if (settings.autoDownloadPodcastEpisodes)
            _PodcastEpisodeCountTile(
              current: settings.autoDownloadPodcastEpisodeCount,
              onChanged: (count) {
                ref
                    .read(settingsProvider.notifier)
                    .setAutoDownloadPodcastEpisodeCount(count);
              },
            ),

          const SizedBox(height: 8),
          const SettingsSectionHeader(title: 'Cache'),
          cacheStatsAsync.when(
            loading: () => const _LoadingTile(),
            error:
                (error, stack) =>
                    const _ErrorTile(message: 'Failed to load cache info'),
            data: (stats) => _CacheInfoTile(stats: stats),
          ),
          _CacheSizeLimitTile(
            currentLimitMB: settings.cacheSizeLimitMB,
            onChanged: (sizeMB) {
              // Ensure the preference and cache manager are updated before
              // refreshing the displayed stats to avoid transient mismatches
              // between binary/decimal representations.
              ref
                  .read(settingsProvider.notifier)
                  .setCacheSizeLimit(sizeMB)
                  .then((_) => ref.invalidate(cacheStatsProvider));
            },
          ),
          SettingsActionTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Clear audio cache',
            subtitle: 'Delete all downloaded audio files',
            onTap: () async {
              final confirmed = await showShellDialog<bool>(
                context: context,
                builder:
                    (context) => const _ConfirmDialog(
                      title: 'Clear audio cache?',
                      message:
                          'All downloaded audio files will be deleted. Album '
                          'and artist info will be kept.',
                    ),
              );
              if (confirmed == true) {
                await CacheManager.instance.clearAudio();
                if (!context.mounted) return;
                ref.invalidate(cacheStatsProvider);
                Analytics.track('cache_audio_cleared');
              }
            },
          ),
          SettingsActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Clear all cache',
            subtitle: 'Delete all cached data',
            iconColor: AppTheme.error,
            onTap: () async {
              final confirmed = await showShellDialog<bool>(
                context: context,
                builder:
                    (context) => const _ConfirmDialog(
                      title: 'Clear all cache?',
                      message:
                          'All cached data including album info, cover art, '
                          'audio files, and listening history from other '
                          'devices will be deleted.\n\nYour local listening '
                          'history will be kept.',
                      confirmColor: AppTheme.error,
                    ),
              );
              if (confirmed == true) {
                await CacheManager.instance.clearAll();
                await ListenHistoryService.clearRemote();
                if (!context.mounted) return;
                ref.invalidate(cacheStatsProvider);
                ref.invalidate(availableYearsProvider);
                ref.invalidate(totalListenCountProvider);
                Analytics.track('cache_all_cleared');
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Podcast episode count ───────────────────────────────────────────────

class _PodcastEpisodeCountTile extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _PodcastEpisodeCountTile({
    required this.current,
    required this.onChanged,
  });

  static const _options = [1, 3, 5, 10];

  @override
  Widget build(BuildContext context) {
    return SettingsActionTile(
      icon: Icons.numbers_rounded,
      title: 'Episodes per show',
      subtitle:
          'Download the latest $current episode${current == 1 ? '' : 's'}',
      onTap: () async {
        final selected = await showShellDialog<int>(
          context: context,
          builder:
              (ctx) => SimpleDialog(
                backgroundColor: AppTheme.surfaceContainerHigh,
                title: const Text(
                  'Episodes per show',
                  style: TextStyle(color: AppTheme.onBackground),
                ),
                children: [
                  for (final n in _options)
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(ctx).pop(n),
                      child: Row(
                        children: [
                          Icon(
                            n == current
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color:
                                n == current
                                    ? AppTheme.primary
                                    : AppTheme.onBackgroundMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            n == 1 ? '1 episode' : '$n episodes',
                            style: TextStyle(
                              color: AppTheme.onBackground,
                              fontWeight:
                                  n == current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }
}

// ── Cache management widgets ────────────────────────────────────────────

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.storage_rounded,
            color: AppTheme.onBackgroundSubtle,
            size: 22,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Loading cache info...',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;

  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheInfoTile extends ConsumerWidget {
  final CacheStats stats;

  const _CacheInfoTile({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                color: AppTheme.onBackgroundSubtle,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Storage used',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stats.totalSizeDisplay} of ${formatDecimalMegabytes(settings.cacheSizeLimitMB)}',
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.usedPercentage / 100,
              backgroundColor: AppTheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(
                stats.usedPercentage > 90 ? AppTheme.error : AppTheme.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CacheBreakdownItem(
                  label: 'Audio',
                  size: stats.audioSizeDisplay,
                  count: stats.audioCount,
                ),
              ),
              Expanded(
                child: _CacheBreakdownItem(
                  label: 'Metadata',
                  size: stats.metadataSizeDisplay,
                  count: stats.metadataCount,
                ),
              ),
              Expanded(
                child: _CacheBreakdownItem(
                  label: 'Images',
                  size: stats.imageSizeDisplay,
                  count: stats.imageCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CacheBreakdownItem extends StatelessWidget {
  final String label;
  final String size;
  final int count;

  const _CacheBreakdownItem({
    required this.label,
    required this.size,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          size,
          style: const TextStyle(
            color: AppTheme.onBackground,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$count items',
          style: const TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _CacheSizeLimitTile extends StatefulWidget {
  final int currentLimitMB;
  final ValueChanged<int> onChanged;

  const _CacheSizeLimitTile({
    required this.currentLimitMB,
    required this.onChanged,
  });

  @override
  State<_CacheSizeLimitTile> createState() => _CacheSizeLimitTileState();
}

class _CacheSizeLimitTileState extends State<_CacheSizeLimitTile> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_rounded,
                color: AppTheme.onBackgroundSubtle,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cache size limit',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDecimalMegabytes(widget.currentLimitMB),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: widget.currentLimitMB.toDouble(),
            min: 500,
            max: 5000,
            divisions: 19,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.surfaceContainerHigh,
            onChanged: (value) => widget.onChanged(value.toInt()),
            onChangeEnd: (value) {
              Analytics.track('cache_size_limit_changed', {
                'size_mb': value.toInt(),
              });
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '500 MB',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '5 GB',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final Color? confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(color: AppTheme.onBackground)),
      content: Text(
        message,
        style: const TextStyle(color: AppTheme.onBackgroundMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: confirmColor ?? AppTheme.primary,
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
