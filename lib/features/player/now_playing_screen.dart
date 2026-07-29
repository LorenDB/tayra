import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/now_playing_content.dart';
import 'package:tayra/features/player/player_provider.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When the window is resized to desktop width, the side panel takes over —
    // pop the full-screen route so the sidebar version is shown instead.
    if (Responsive.isExpanded(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) popPage(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-pop when playback is stopped (e.g. after stashing the queue) so the
    // user is never left on a "nothing playing" screen with no escape.
    ref.listen(playerProvider.select((s) => s.currentTrack), (previous, next) {
      if (previous != null && next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) popPage(context);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        // SafeArea is applied inside NowPlayingContent so the accent
        // background tint can extend edge-to-edge under the status bar.
        child: const NowPlayingContent(layout: NowPlayingLayout.screen),
      ),
    );
  }
}
