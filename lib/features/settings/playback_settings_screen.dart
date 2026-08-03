import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Playback preferences (gapless and related audio options).
class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Playback'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const SettingsSectionHeader(title: 'Audio'),
          // just_audio has no gapless support on web; multi-source playlists
          // there can stick on the same audio after a few tracks.
          if (!AppPlatform.isWeb)
            SettingsSwitchTile(
              icon: Icons.music_note_outlined,
              title: 'Gapless playback',
              subtitle: 'Eliminate silence between tracks',
              value: settings.gaplessPlayback,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setGaplessPlayback(value);
              },
            )
          else
            const SettingsInfoTile(
              icon: Icons.music_note_outlined,
              title: 'Gapless playback',
              subtitle: 'Not available on web',
            ),
        ],
      ),
    );
  }
}
