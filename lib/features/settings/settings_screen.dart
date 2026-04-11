import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Format MB values (decimal) used by the slider/settings UI so they always
// match what the user selected.
String _formatLimitMB(int mb) {
  if (mb >= 1000) {
    final gb = mb / 1000.0;
    return '${gb.toStringAsFixed(1)} GB';
  }
  return '$mb MB';
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateProvider);
    final cacheStatsAsync = ref.watch(cacheStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account section ───────────────────────────────────────────
          _SectionHeader(title: 'Account'),
          if (authState.serverUrl != null)
            _InfoTile(
              icon: Icons.dns_outlined,
              title: 'Server',
              subtitle: authState.serverUrl!,
            ),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: 'Sign out and return to the login screen',
            iconColor: AppTheme.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      backgroundColor: AppTheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Log out?',
                        style: TextStyle(color: AppTheme.onBackground),
                      ),
                      content: const Text(
                        'You will need to log in again to access your library.',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.error,
                          ),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),

          const SizedBox(height: 24),

          // ── Browse section ────────────────────────────────────────────
          _SectionHeader(title: 'Browse'),
          _BrowseModeTile(
            currentMode: settings.browseMode,
            onChanged: (mode) {
              Aptabase.instance.trackEvent("default_browse_mode_changed", {
                "mode": mode,
              });
              ref.read(settingsProvider.notifier).setBrowseMode(mode);
            },
          ),
          if (defaultTargetPlatform == TargetPlatform.android)
            _SwitchTile(
              icon: Icons.directions_car_outlined,
              title: 'Android Auto recommendations',
              subtitle: 'Show "For you" tab in Android Auto',
              value: settings.showAndroidAutoRecommendations,
              onChanged: (value) {
                try {
                  Aptabase.instance.trackEvent(
                    'android_auto_recommendations_toggled',
                    {'enabled': value},
                  );
                } catch (_) {}
                ref
                    .read(settingsProvider.notifier)
                    .setShowAndroidAutoRecommendations(value);
              },
            ),

          const SizedBox(height: 24),

          // ── Playback section ─────────────────────────────────────────
          _SectionHeader(title: 'Playback'),
          _SwitchTile(
            icon: Icons.music_note_outlined,
            title: 'Gapless playback',
            subtitle: 'Eliminate silence between tracks',
            value: settings.gaplessPlayback,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setGaplessPlayback(value);
            },
          ),

          const SizedBox(height: 24),

          // ── Accessibility section ───────────────────────────────────
          _SectionHeader(title: 'Accessibility'),
          _SwitchTile(
            icon: Icons.format_paint_outlined,
            title: 'Album accent colors',
            subtitle: 'Use album cover art to tint UI accents',
            value: settings.useDynamicAlbumAccent,
            onChanged: (value) {
              try {
                Aptabase.instance.trackEvent('dynamic_album_accent_toggled', {
                  'enabled': value,
                });
              } catch (_) {}
              ref
                  .read(settingsProvider.notifier)
                  .setUseDynamicAlbumAccent(value);
            },
          ),

          const SizedBox(height: 24),

          // ── Year in Review section ────────────────────────────────────
          _SectionHeader(title: 'Year in Review'),
          _YearReviewTile(),

          const SizedBox(height: 24),

          // ── Cache section ─────────────────────────────────────────────
          _SectionHeader(title: 'Cache'),
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
          _ActionTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Clear audio cache',
            subtitle: 'Delete all downloaded audio files',
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => _ConfirmDialog(
                      title: 'Clear audio cache?',
                      message:
                          'All downloaded audio files will be deleted. Album and artist info will be kept.',
                    ),
              );
              if (confirmed == true) {
                await CacheManager.instance.clearAudio();
                ref.invalidate(cacheStatsProvider);
                try {
                  Aptabase.instance.trackEvent('cache_audio_cleared');
                } catch (_) {}
              }
            },
          ),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Clear all cache',
            subtitle: 'Delete all cached data',
            iconColor: AppTheme.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (context) => _ConfirmDialog(
                      title: 'Clear all cache?',
                      message:
                          'All cached data including album info, cover art, and audio files will be deleted.',
                      confirmColor: AppTheme.error,
                    ),
              );
              if (confirmed == true) {
                await CacheManager.instance.clearAll();
                ref.invalidate(cacheStatsProvider);
                try {
                  Aptabase.instance.trackEvent('cache_all_cleared');
                } catch (_) {}
              }
            },
          ),

          const SizedBox(height: 24),

          // ── About section ─────────────────────────────────────────────
          _SectionHeader(title: 'About'),
          _AboutTile(),
          _DonationTile(),
          _ActionTile(
            icon: Icons.balance_outlined,
            title: 'Licenses',
            subtitle: 'View open-source licenses',
            onTap: () => {showLicensePage(context: context)},
          ),
        ],
      ),
    );
  }
}

// ── Year in Review tile ─────────────────────────────────────────────────

class _YearReviewTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listenCountAsync = ref.watch(totalListenCountProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/year-review'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Year in Review',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      listenCountAsync.when(
                        loading:
                            () => const Text(
                              'Loading...',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                        error:
                            (error, stack) => const Text(
                              'See your listening recap',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                        data:
                            (count) => Text(
                              count > 0
                                  ? '$count total listens tracked'
                                  : 'Start listening to build your recap',
                              style: const TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── About tile (long-press easter egg) ───────────────────────────────────────

/// Long-pressing the About tile 3 times force-shows the Year in Review banner on
/// the home screen, regardless of the current date. Useful for testing.
class _AboutTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends ConsumerState<_AboutTile> {
  int _tapCount = 0;
  static const int _tapsRequired = 3;

  void _onLongPress() {
    setState(() => _tapCount++);
    if (_tapCount >= _tapsRequired) {
      _tapCount = 0;
      ref.read(yearReviewBannerVisibleProvider.notifier).forceShow();
      Aptabase.instance.trackEvent("manual_yearend_banner_triggered");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Year in Review banner unlocked'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: _onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.onBackgroundSubtle,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tayra',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Copyright Loren Burkholder | Licensed MIT',
                        style: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ── Info tile (non-interactive) ─────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
          Icon(icon, color: AppTheme.onBackgroundSubtle, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action tile (tappable) ──────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ?? AppTheme.onBackgroundSubtle,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Switch tile ─────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.onBackgroundSubtle, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withAlpha(100),
          ),
        ],
      ),
    );
  }
}

// ── Browse mode tile ────────────────────────────────────────────────────

class _BrowseModeTile extends StatelessWidget {
  final BrowseMode currentMode;
  final ValueChanged<BrowseMode> onChanged;

  const _BrowseModeTile({required this.currentMode, required this.onChanged});

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
          const Icon(
            Icons.library_music_outlined,
            color: AppTheme.onBackgroundSubtle,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default browse view',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Choose what the Browse tab shows',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _ModeToggle(currentMode: currentMode, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Segmented toggle for browse mode ────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final BrowseMode currentMode;
  final ValueChanged<BrowseMode> onChanged;

  const _ModeToggle({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleChip(
            label: 'Albums',
            isSelected: currentMode == BrowseMode.albums,
            onTap: () => onChanged(BrowseMode.albums),
          ),
          _ToggleChip(
            label: 'Artists',
            isSelected: currentMode == BrowseMode.artists,
            onTap: () => onChanged(BrowseMode.artists),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.onBackgroundMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
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
                      '${stats.totalSizeDisplay} of ${_formatLimitMB(settings.cacheSizeLimitMB)}',
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
          // Progress bar
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
          // Breakdown
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
                      _formatLimitDisplay(widget.currentLimitMB),
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
              try {
                Aptabase.instance.trackEvent('cache_size_limit_changed', {
                  'size_mb': value.toInt(),
                });
              } catch (_) {}
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '500 MB',
                  style: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '5 GB',
                  style: const TextStyle(
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

  // Format the slider value using decimal units (MB/GB) to match CacheManager
  String _formatLimitDisplay(int mb) {
    if (mb >= 1000) {
      final gb = mb / 1000.0;
      return '${gb.toStringAsFixed(1)} GB';
    }
    return '$mb MB';
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

// ── Donation buttons tile ─────────────────────────────────────────────────

class _DonationTile extends StatelessWidget {
  static const _liberapayUrl = 'https://liberapay.com/LorenDB/donate';
  static const _paypalUrl =
      'https://www.paypal.com/donate/?business=LSTPU6GJTKCQE&no_recurring=0&item_name=Thank+you+for+supporting+continued+development+of+Tayra.&currency_code=USD';

  const _DonationTile();

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppTheme.onBackgroundSubtle,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tayra is free and open-source. If you enjoy using it, consider supporting its development!',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DonationButton(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Liberapay',
                        onTap: () {
                          try {
                            Aptabase.instance.trackEvent(
                              'donation_link_tapped',
                              {'platform': 'liberapay'},
                            );
                          } catch (_) {}
                          _openUrl(_liberapayUrl);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DonationButton(
                        icon: Icons.payments_outlined,
                        label: 'PayPal',
                        onTap: () {
                          try {
                            Aptabase.instance.trackEvent(
                              'donation_link_tapped',
                              {'platform': 'paypal'},
                            );
                          } catch (_) {}
                          _openUrl(_paypalUrl);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DonationButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
