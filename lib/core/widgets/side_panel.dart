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

enum _PanelView { nowPlaying, queue, stashes }

class _SidePanelState extends ConsumerState<SidePanel> {
  _PanelView _view = _PanelView.nowPlaying;

  @override
  Widget build(BuildContext context) {
    final hasTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );

    // Collapse back to the now-playing view when playback stops.
    ref.listen(playerProvider.select((s) => s.currentTrack), (prev, next) {
      if (prev != null && next == null && _view != _PanelView.nowPlaying) {
        setState(() => _view = _PanelView.nowPlaying);
      }
    });

    // When nothing is playing, show the stash inbox directly in the panel.
    if (!hasTrack) {
      return Container(
        color: AppTheme.surface,
        child: _StashInboxPanel(key: const ValueKey('stash_inbox')),
      );
    }

    final Widget child = switch (_view) {
      _PanelView.stashes => _StashInboxPanel(
        key: const ValueKey('stash_inbox_panel'),
        onBack: () => setState(() => _view = _PanelView.queue),
      ),
      _PanelView.queue => QueueScreen(
        key: const ValueKey('queue'),
        onBack: () => setState(() => _view = _PanelView.nowPlaying),
        onOpenInbox: () => setState(() => _view = _PanelView.stashes),
      ),
      _PanelView.nowPlaying => NowPlayingContent(
        key: const ValueKey('player'),
        layout: NowPlayingLayout.panel,
        onQueuePressed: () => setState(() => _view = _PanelView.queue),
      ),
    };

    return Container(
      color: AppTheme.surface,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }
}

// ── Stash Inbox Panel ────────────────────────────────────────────────────

/// Shown in the side panel for stashed queues. When [onBack] is provided
/// (playback is active and the user navigated here from the queue), a back
/// arrow is shown so the user can return to the queue subpage. When [onBack]
/// is null (nothing is playing), only the label is shown.
class _StashInboxPanel extends ConsumerWidget {
  final VoidCallback? onBack;

  const _StashInboxPanel({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashes = ref.watch(stashedQueuesProvider).asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  color: AppTheme.onBackgroundMuted,
                  onPressed: onBack,
                  tooltip: 'Back',
                )
              else
                const SizedBox(width: 12),
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
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${stashes.length}',
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 12,
                    ),
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
                        (context, index) => StashedQueueTile(
                          stash: stashes[index],
                          onRestored: () {
                            // If a parent provided an onBack handler, invoke it so
                            // the panel returns to the queue view after restoring
                            // a stash.
                            if (onBack != null) onBack!();
                          },
                        ),
                  ),
        ),
      ],
    );
  }
}
