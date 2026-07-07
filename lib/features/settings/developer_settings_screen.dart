import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';

class DeveloperSettingsScreen extends ConsumerWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Developer'),
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Developer mode ─────────────────────────────────────────────
          _SectionHeader(title: 'Developer mode'),
          _DevActionTile(
            icon: Icons.no_accounts_rounded,
            title: 'Disable developer mode',
            subtitle:
                'Turn off developer mode and reset all developer settings',
            iconColor: AppTheme.error,
            onTap: () async {
              await ref.read(settingsProvider.notifier).disableDeveloperMode();
              if (context.mounted) context.pop();
            },
          ),

          // ── Cache section ──────────────────────────────────────────────
          const SizedBox(height: 8),
          _SectionHeader(title: 'Cache'),
          _DevSwitchTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Show purge cache option in menus',
            subtitle:
                'Adds a "Purge and refetch" entry to album, track, and artist menus',
            value: settings.showPurgeCacheOption,
            onChanged: (value) {
              ref
                  .read(settingsProvider.notifier)
                  .setShowPurgeCacheOption(value);
            },
          ),

          // ── Year in Review section ─────────────────────────────────────
          const SizedBox(height: 8),
          _SectionHeader(title: 'Year in Review'),
          _DevActionTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Trigger year review banner',
            subtitle: 'Force-show the Year in Review banner on the home screen',
            onTap: () {
              ref.read(yearReviewBannerVisibleProvider.notifier).forceShow();
              Analytics.track('manual_yearend_banner_triggered');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Year in Review banner unlocked'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),

          // ── File Locations section (desktop only) ────────────────────
          if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) ...[
            const SizedBox(height: 8),
            _SectionHeader(title: 'File Locations'),
            _DevActionTile(
              icon: Icons.folder_open_rounded,
              title: 'Open cache directory',
              subtitle: 'Open the audio and image cache folder',
              onTap: () async {
                try {
                  Analytics.track('dev_open_cache_dir');
                } catch (_) {}
                final dir = await getApplicationCacheDirectory();
                await launchUrl(
                  Uri.directory(dir.path),
                  mode: LaunchMode.platformDefault,
                );
              },
            ),
            _DevActionTile(
              icon: Icons.folder_open_rounded,
              title: 'Open app data directory',
              subtitle: 'Open the settings and database folder',
              onTap: () async {
                try {
                  Analytics.track('dev_open_data_dir');
                } catch (_) {}
                final dir = await getApplicationSupportDirectory();
                await launchUrl(
                  Uri.directory(dir.path),
                  mode: LaunchMode.platformDefault,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

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

class _DevActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _DevActionTile({
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DevSwitchTile({
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
