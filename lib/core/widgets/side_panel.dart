import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/player/now_playing_content.dart';
import 'package:tayra/features/player/player_provider.dart';
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
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );

    // Collapse back to the now-playing view when playback stops.
    ref.listen(playerProvider.select((s) => s.currentTrack), (prev, next) {
      if (prev != null && next == null && _showQueue) {
        setState(() => _showQueue = false);
      }
    });

    // When nothing is playing, show the stash inbox directly in the panel.
    if (!hasTrack) {
      return Container(
        color: AppTheme.surface,
        child: _StashInboxPanel(key: const ValueKey('stash_inbox')),
      );
    }

    return Container(
      color: AppTheme.surface,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child:
            _showQueue
                ? QueueScreen(
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

// ── Stash Inbox Panel ────────────────────────────────────────────────────

/// Shown in the side panel when nothing is playing. Displays stashed queues
/// inline so they remain accessible without needing active playback.
class _StashInboxPanel extends ConsumerWidget {
  const _StashInboxPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashes = ref.watch(stashedQueuesProvider).asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.inbox_outlined,
                color: AppTheme.onBackgroundMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'STASHED QUEUES',
                style: TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (stashes.isNotEmpty)
                Text(
                  '${stashes.length}',
                  style: const TextStyle(
                    color: AppTheme.onBackgroundSubtle,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: AppTheme.divider, height: 1),
        Expanded(
          child:
              stashes.isEmpty
                  ? const Center(
                    child: Text(
                      'No stashed queues',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 14,
                      ),
                    ),
                  )
                  : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: stashes.length,
                    itemBuilder:
                        (context, index) =>
                            StashedQueueTile(stash: stashes[index]),
                  ),
        ),
      ],
    );
  }
}
