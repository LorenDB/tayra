import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/audio/audio_quality.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/settings_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Playback preferences (gapless, streaming quality, related audio options).
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
          const SettingsSectionHeader(title: 'Streaming quality'),
          SettingsActionTile(
            icon: Icons.high_quality_outlined,
            title: 'Streaming quality',
            subtitle: settings.streamingQuality.subtitle,
            onTap:
                () => _pickQuality(
                  context,
                  ref,
                  title: 'Streaming quality',
                  current: settings.streamingQuality,
                  options: AudioQuality.values,
                  onSelected: (q) {
                    ref.read(settingsProvider.notifier).setStreamingQuality(q);
                  },
                ),
          ),
          SettingsSwitchTile(
            icon: Icons.speed_outlined,
            title: 'Auto quality fallback',
            subtitle: 'Lower quality when the network struggles (buffering)',
            value: settings.autoQualityFallback,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setAutoQualityFallback(value);
            },
          ),
          if (AppPlatform.supportsOfflineCache) ...[
            const SettingsSectionHeader(title: 'Downloads'),
            SettingsActionTile(
              icon: Icons.download_outlined,
              title: 'Download quality',
              subtitle: settings.downloadQuality.subtitle,
              onTap:
                  () => _pickQuality(
                    context,
                    ref,
                    title: 'Download quality',
                    current: settings.downloadQuality,
                    // Downloads should be a concrete tier.
                    options:
                        AudioQuality.values
                            .where((q) => q != AudioQuality.auto)
                            .toList(),
                    onSelected: (q) {
                      ref.read(settingsProvider.notifier).setDownloadQuality(q);
                    },
                  ),
            ),
          ],
        ],
      ),
    );
  }

  void _pickQuality(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AudioQuality current,
    required List<AudioQuality> options,
    required ValueChanged<AudioQuality> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // Cap height on short viewports (phones / non-desktop shell) so the
        // option list scrolls instead of overflowing the modal.
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.7;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
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
                      color: AppTheme.onBackgroundSubtle.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final q in options)
                        ListTile(
                          title: Text(
                            q.label,
                            style: TextStyle(
                              color: AppTheme.onBackground,
                              fontWeight:
                                  q == current
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            q.subtitle,
                            style: const TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 12,
                            ),
                          ),
                          trailing:
                              q == current
                                  ? const Icon(
                                    Icons.check_rounded,
                                    color: AppTheme.primary,
                                  )
                                  : null,
                          onTap: () {
                            onSelected(q);
                            Navigator.of(ctx).pop();
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
