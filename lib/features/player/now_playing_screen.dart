import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/now_playing_content.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
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
