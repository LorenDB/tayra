import 'package:flutter/material.dart';
import 'package:tayra/features/player/now_playing_content.dart';

class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const NowPlayingContent(layout: NowPlayingLayout.panel);
  }
}
