import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
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
          SettingsSectionHeader(title: 'Developer mode'),
          SettingsActionTile(
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
          SettingsSectionHeader(title: 'Cache'),
          SettingsSwitchTile(
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
          SettingsSectionHeader(title: 'Year in Review'),
          SettingsActionTile(
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
            SettingsSectionHeader(title: 'File Locations'),
            SettingsActionTile(
              icon: Icons.folder_open_rounded,
              title: 'Open cache directory',
              subtitle: 'Open the audio and image cache folder',
              onTap: () async {
                Analytics.track('dev_open_cache_dir');
                final dir = await getApplicationCacheDirectory();
                await launchUrl(
                  Uri.directory(dir.path),
                  mode: LaunchMode.platformDefault,
                );
              },
            ),
            SettingsActionTile(
              icon: Icons.folder_open_rounded,
              title: 'Open app data directory',
              subtitle: 'Open the settings and database folder',
              onTap: () async {
                Analytics.track('dev_open_data_dir');
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
