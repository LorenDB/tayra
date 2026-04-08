import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/now_playing_content.dart';
import 'package:tayra/features/player/queue_screen.dart';

class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child:
            _showQueue
                ? _QueuePanel(
                  key: const ValueKey('queue'),
                  onBack: () => setState(() => _showQueue = false),
                )
                : NowPlayingContent(
                  key: const ValueKey('player'),
                  layout: NowPlayingLayout.panel,
                  onQueuePressed: () => setState(() => _showQueue = true),
                ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  final VoidCallback onBack;

  const _QueuePanel({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                color: AppTheme.onBackgroundMuted,
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const Text(
                'QUEUE',
                style: TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: QueueScreen(showAppBar: false, miniPlayerOnTap: onBack),
        ),
      ],
    );
  }
}
