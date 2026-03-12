import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/browse/albums_screen.dart';
import 'package:tayra/features/browse/artists_screen.dart';

/// Browse tab wrapper that switches between Albums and Artists views
/// based on the user's setting in [settingsProvider].
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseMode = ref.watch(settingsProvider).browseMode;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(browseMode == BrowseMode.albums ? 'Albums' : 'Artists'),
        backgroundColor: AppTheme.background,
      ),
      body:
          browseMode == BrowseMode.albums
              ? const AlbumsScreen()
              : const ArtistsScreen(),
    );
  }
}
