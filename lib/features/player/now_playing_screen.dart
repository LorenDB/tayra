import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/layout/responsive.dart';
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
        if (mounted && context.canPop()) {
          context.pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-pop when playback is stopped (e.g. after stashing the queue) so the
    // user is never left on a "nothing playing" screen with no escape.
    ref.listen(playerProvider, (previous, next) {
      if (previous?.currentTrack != null && next.currentTrack == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) context.pop();
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
        child: const SafeArea(
          child: NowPlayingContent(layout: NowPlayingLayout.screen),
        ),
      ),
    );
  }
}
