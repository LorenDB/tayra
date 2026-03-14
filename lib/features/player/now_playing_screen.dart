import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/now_playing_content.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

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
