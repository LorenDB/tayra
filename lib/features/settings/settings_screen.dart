import 'dart:async';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/core/widgets/app_shell.dart';
import 'package:tayra/features/year_review/listen_history_import_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authStateProvider);
    final dntEnv = AppPlatform.doNotTrackEnv?.trim().toLowerCase();
    final showAnalyticsToggle = !(dntEnv == '1' || dntEnv == 'true');
    final cacheStatsAsync = ref.watch(cacheStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Account section ───────────────────────────────────────────
          SettingsSectionHeader(title: 'Account'),
          if (authState.serverUrl != null)
            SettingsInfoTile(
              icon: Icons.dns_outlined,
              title: 'Server',
              subtitle: authState.serverUrl!,
            ),
          SettingsActionTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Account settings',
            subtitle: 'Profile, security, and account deactivation',
            onTap: () => context.push('/settings/account'),
          ),
          SettingsActionTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: 'Sign out and return to the login screen',
            iconColor: AppTheme.error,
            onTap: () async {
              final confirmed = await showShellDialog<bool>(
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

          // ── Library section ───────────────────────────────────────────
          SettingsSectionHeader(title: 'Library'),
          SettingsActionTile(
            icon: Icons.upload_rounded,
            title: 'Upload music',
            subtitle: 'Upload audio files to your Funkwhale library',
            onTap: () => context.push('/upload'),
          ),
          // Library admin — only when me.permissions.library (or superuser).
          if (ref
              .watch(meUserProvider)
              .maybeWhen(
                data: (me) => me.canManageLibrary,
                orElse: () => false,
              ))
            SettingsActionTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Library admin',
              subtitle: 'Manage libraries, uploads, and tags',
              onTap: () => context.push('/manage/library'),
            ),
          // Instance settings — only when me.permissions.settings (or superuser).
          if (ref
              .watch(meUserProvider)
              .maybeWhen(
                data: (me) => me.canManageSettings,
                orElse: () => false,
              ))
            SettingsActionTile(
              icon: Icons.tune_rounded,
              title: 'Instance settings',
              subtitle: 'Edit pod-wide Funkwhale preferences',
              onTap: () => context.push('/manage/settings'),
            ),
          // User management — only when me.permissions.settings (or superuser).
          if (ref
              .watch(meUserProvider)
              .maybeWhen(data: (me) => me.canManageUsers, orElse: () => false))
            SettingsActionTile(
              icon: Icons.manage_accounts_outlined,
              title: 'User management',
              subtitle: 'Manage local users and invitations',
              onTap: () => context.push('/manage/users'),
            ),

          if (AppPlatform.supportsOfflineCache) ...[
            const SizedBox(height: 24),

            // ── Network section ──────────────────────────────────────────
            SettingsSectionHeader(title: 'Network'),
            SettingsSwitchTile(
              icon: Icons.cloud_off_rounded,
              title: 'Force offline mode',
              subtitle: 'Only show cached content; disable network access',
              value: settings.forceOfflineMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setForceOfflineMode(value);
              },
            ),
          ],

          const SizedBox(height: 24),

          // ── Playback section ─────────────────────────────────────────
          SettingsSectionHeader(title: 'Playback'),
          SettingsSwitchTile(
            icon: Icons.music_note_outlined,
            title: 'Gapless playback',
            subtitle: 'Eliminate silence between tracks',
            value: settings.gaplessPlayback,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setGaplessPlayback(value);
            },
          ),

          const SizedBox(height: 24),

          // ── Appearance section ────────────────────────────────────────
          SettingsSectionHeader(title: 'Appearance'),
          SettingsSwitchTile(
            icon: Icons.format_paint_outlined,
            title: 'Album accent colors',
            subtitle: 'Use album cover art to tint UI accents',
            value: settings.useDynamicAlbumAccent,
            onChanged: (value) {
              Analytics.track('dynamic_album_accent_toggled', {
                'enabled': value,
              });
              ref
                  .read(settingsProvider.notifier)
                  .setUseDynamicAlbumAccent(value);
            },
          ),
          SettingsSwitchTile(
            icon: Icons.album_outlined,
            title: 'Continuous disc numbering',
            subtitle:
                'Number tracks across all discs in one unbroken sequence; '
                'otherwise disc labels are shown between sections',
            value:
                settings.multiDiscDisplayMode ==
                MultiDiscDisplayMode.continuousNumbers,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setMultiDiscDisplayMode(
                    value
                        ? MultiDiscDisplayMode.continuousNumbers
                        : MultiDiscDisplayMode.discSections,
                  );
            },
          ),

          // ── Navigation section ────────────────────────────────────────
          const SizedBox(height: 24),
          SettingsSectionHeader(title: 'Navigation'),
          _NavBarSettingsTile(pinnedIndices: settings.mobilePinnedTabIndices),

          // Year Review — own section
          const SizedBox(height: 24),
          SettingsSectionHeader(title: 'Year in Review'),
          _YearReviewTile(),
          SettingsActionTile(
            icon: Icons.settings_rounded,
            title: 'Year in Review settings',
            subtitle: 'Control year-end prompts and related options',
            onTap: () => context.push('/settings/year-review-settings'),
          ),
          const SizedBox(height: 24),

          // ── Server history import (native only) ───────────────────────
          if (AppPlatform.supportsOfflineCache) ...[
            SettingsSectionHeader(title: 'Listen History'),
            const _ServerHistoryImportTile(),
            const SizedBox(height: 24),
          ],

          // ── AI section ────────────────────────────────────────────────
          SettingsSectionHeader(title: 'AI'),
          SettingsSwitchTile(
            icon: Icons.auto_awesome_rounded,
            title: 'AI features',
            subtitle: 'Enable AI-powered features',
            value: settings.aiEnabled,
            onChanged: (value) {
              Analytics.track('ai_features_toggled', {'enabled': value});
              ref.read(settingsProvider.notifier).setAiEnabled(value);
            },
          ),
          if (settings.aiEnabled)
            _AiProviderTile(currentProvider: settings.aiProviderType),
          const SizedBox(height: 24),

          // ── Downloads / cache (native offline features) ───────────────
          if (AppPlatform.supportsOfflineCache) ...[
            SettingsSectionHeader(title: 'Downloads'),
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
                Analytics.track('download_wifi_only_toggled', {
                  'enabled': value,
                });
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

            const SizedBox(height: 24),

            // ── Cache section ─────────────────────────────────────────────
            SettingsSectionHeader(title: 'Cache'),
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
                      (context) => _ConfirmDialog(
                        title: 'Clear audio cache?',
                        message:
                            'All downloaded audio files will be deleted. Album and artist info will be kept.',
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
                      (context) => _ConfirmDialog(
                        title: 'Clear all cache?',
                        message:
                            'All cached data including album info, cover art, audio files, and listening history from other devices will be deleted.\n\nYour local listening history will be kept.',
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

          const SizedBox(height: 24),

          // ── About section ─────────────────────────────────────────────
          SettingsSectionHeader(title: 'About'),
          _AboutTile(),
          // Analytics moved here from General
          // Hide the analytics toggle entirely when DO_NOT_TRACK=1 is set in
          // the environment. This prevents the setting from appearing in
          // environments that require telemetry to be disabled.
          if (showAnalyticsToggle)
            SettingsSwitchTile(
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              subtitle: 'Allow anonymous usage analytics',
              value: settings.analyticsEnabled,
              onChanged: (value) async {
                // Persist setting and apply immediately.
                try {
                  // If disabling, set Analytics to disabled first to avoid sending
                  // an event about the change. If enabling, persist then enable.
                  if (!value) {
                    await ref
                        .read(settingsProvider.notifier)
                        .setAnalyticsEnabled(false);
                    await Analytics.setEnabled(false);
                  } else {
                    await ref
                        .read(settingsProvider.notifier)
                        .setAnalyticsEnabled(true);
                    await Analytics.setEnabled(true);
                    Analytics.track('analytics_enabled');
                  }
                } catch (_) {}
              },
            ),
          _DonationTile(),
          SettingsActionTile(
            icon: Icons.balance_outlined,
            title: 'Licenses',
            subtitle: 'View open-source licenses',
            onTap: () => {showLicensePage(context: context)},
          ),
          if (settings.developerModeUnlocked) ...[
            const SizedBox(height: 24),
            SettingsSectionHeader(title: 'Developer'),
            SettingsActionTile(
              icon: Icons.code_rounded,
              title: 'Developer settings',
              subtitle: 'Tools for testing and development',
              onTap: () => context.push('/settings/developer'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── AI provider tile ───────────────────────────────────────────────────────

class _AiProviderTile extends StatelessWidget {
  final AiProviderType currentProvider;

  const _AiProviderTile({required this.currentProvider});

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
          onTap: () => context.push('/settings/ai-provider'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.smart_toy_outlined,
                  color: AppTheme.onBackgroundSubtle,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI provider',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentProvider.displayName,
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

// ── AI model status tile ────────────────────────────────────────────────

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

// ── Upload listen history to Funkwhale server (bulk enrich_or_create) ─────

class _ServerHistoryImportTile extends ConsumerStatefulWidget {
  const _ServerHistoryImportTile();

  @override
  ConsumerState<_ServerHistoryImportTile> createState() =>
      _ServerHistoryImportTileState();
}

class _ServerHistoryImportTileState
    extends ConsumerState<_ServerHistoryImportTile> {
  bool? _supported;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_probe());
  }

  Future<void> _probe() async {
    final ok =
        await ref.read(listenHistoryImportServiceProvider).isRichSupported();
    if (mounted) setState(() => _supported = ok);
  }

  Future<void> _runImport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result =
          await ref
              .read(listenHistoryImportServiceProvider)
              .importLocalHistory();
      if (!mounted) return;
      final msg =
          result.totalProcessed == 0 && result.errors.isEmpty
              ? 'No listening history to upload (or server does not support it).'
              : 'Uploaded history: ${result.created} new, '
                  '${result.enriched} enriched, '
                  '${result.skippedDuplicate} already present'
                  '${result.errors.isEmpty ? '' : ', ${result.errors.length} errors'}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide when server has no client-data / bulk API.
    if (_supported == false) return const SizedBox.shrink();

    final subtitle =
        _busy
            ? 'Uploading…'
            : (_supported == null
                ? 'Checking server support…'
                : 'Upload local history to this Funkwhale server '
                    '(safe to re-run)');

    return SettingsActionTile(
      icon: Icons.cloud_upload_rounded,
      title: 'Upload listen history to server',
      subtitle: subtitle,
      onTap: () async {
        if (_busy || _supported != true) return;
        final confirmed = await showShellDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: AppTheme.surfaceContainerHigh,
                title: const Text('Upload listen history'),
                content: const Text(
                  'Upload local listening history to the server via '
                  'bulk import (enrich or create). Safe to run more '
                  'than once.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Upload'),
                  ),
                ],
              ),
        );
        if (confirmed == true && mounted) {
          await _runImport();
        }
      },
    );
  }
}

// ── About tile (long-press easter egg) ───────────────────────────────────────

/// Long-pressing the About tile 3 times unlocks Developer mode.
class _AboutTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends ConsumerState<_AboutTile> {
  int _tapCount = 0;
  static const int _tapsRequired = 3;

  void _onLongPress() {
    final alreadyUnlocked = ref.read(settingsProvider).developerModeUnlocked;
    if (alreadyUnlocked) return;
    setState(() => _tapCount++);
    if (_tapCount >= _tapsRequired) {
      _tapCount = 0;
      ref.read(settingsProvider.notifier).setDeveloperModeUnlocked(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer mode enabled'),
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
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
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

class _NavBarSettingsTile extends ConsumerWidget {
  final Set<int> pinnedIndices;

  const _NavBarSettingsTile({required this.pinnedIndices});

  // Non-home tab indices (1–6 in AppShell.tabs).
  static const _configurableIndices = [1, 2, 3, 4, 5, 6];

  String get _subtitle {
    final names =
        _configurableIndices
            .where((i) => pinnedIndices.contains(i))
            .map((i) => AppShell.tabs[i].label)
            .toList();
    return names.isEmpty ? 'None' : names.join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showSheet(context, ref),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.tune_rounded,
              color: AppTheme.onBackgroundSubtle,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigation bar items',
                    style: TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
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
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => _NavBarSheet(
            initialPinned: pinnedIndices,
            onChanged:
                (updated) => ref
                    .read(settingsProvider.notifier)
                    .setMobilePinnedTabIndices(updated),
          ),
    );
  }
}

class _NavBarSheet extends StatefulWidget {
  final Set<int> initialPinned;
  final ValueChanged<Set<int>> onChanged;

  const _NavBarSheet({required this.initialPinned, required this.onChanged});

  @override
  State<_NavBarSheet> createState() => _NavBarSheetState();
}

class _NavBarSheetState extends State<_NavBarSheet> {
  late Set<int> _pinned;

  static const _configurableIndices = [1, 2, 3, 4, 5, 6];
  static const _maxPinned = 4;

  @override
  void initState() {
    super.initState();
    _pinned = Set.from(widget.initialPinned);
  }

  void _toggle(int index, bool value) {
    if (value && _pinned.length >= _maxPinned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpin another item first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      if (value) {
        _pinned.add(index);
      } else {
        _pinned.remove(index);
      }
    });
    widget.onChanged(Set.from(_pinned));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onBackgroundMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Navigation bar items',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Choose up to 4 items to pin to the bottom nav bar when the narrow layout is active. Unpinned items appear on the home screen.',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 13),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ..._configurableIndices.map((i) {
            final tab = AppShell.tabs[i];
            final isPinned = _pinned.contains(i);
            return SwitchListTile(
              secondary: Icon(tab.icon, color: AppTheme.onBackgroundSubtle),
              title: Text(
                tab.label,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 15,
                ),
              ),
              value: isPinned,
              onChanged: (v) => _toggle(i, v),
              activeThumbColor: AppTheme.primary,
            );
          }),
          const SizedBox(height: 8),
        ],
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
          const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
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
                          Analytics.track('donation_link_tapped', {
                            'platform': 'liberapay',
                          });
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
                          Analytics.track('donation_link_tapped', {
                            'platform': 'paypal',
                          });
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
