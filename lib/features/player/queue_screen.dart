import 'package:tayra/core/analytics/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/player/queue_persistence_service.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/player/mini_player.dart';

class QueueScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  /// When non-null the screen renders in "panel" mode: no Scaffold AppBar,
  /// instead a compact header with a back arrow and small-caps "QUEUE" label.
  /// The callback is invoked when the user taps the back arrow or stashes the
  /// queue (which leaves nothing to show).
  final VoidCallback? onBack;

  /// Called when the user taps the mini-player at the bottom of the queue.
  /// If null, the mini-player navigates to the full-screen now-playing route.
  final VoidCallback? miniPlayerOnTap;

  const QueueScreen({
    super.key,
    this.scrollController,
    this.onBack,
    this.miniPlayerOnTap,
  });

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  late ScrollController _scrollController;
  bool _hasScrolled = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollToCurrentTrack(int currentIndex, int queueLength) {
    if (_hasScrolled || currentIndex < 0 || currentIndex >= queueLength) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemHeight = 64.0;
      final offset = currentIndex * itemHeight;
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        offset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _hasScrolled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;
    final currentIndex = playerState.currentIndex;

    if (!_hasScrolled && queue.isNotEmpty) {
      _scrollToCurrentTrack(currentIndex, queue.length);
    }

    final isPanelMode = widget.onBack != null;

    final body = _buildBody(context, ref, queue, currentIndex);

    final miniPlayer =
        playerState.currentTrack != null
            ? SafeArea(
              top: false,
              child: MiniPlayer(
                onTap:
                    widget.miniPlayerOnTap ??
                    () =>
                        context.canPop()
                            ? context.pop()
                            : context.push('/now-playing'),
              ),
            )
            : null;

    // ── Panel mode (sidebar) ────────────────────────────────────────────
    // Render a compact header instead of a Scaffold AppBar so the widget
    // can live inside the side panel Column without nesting Scaffolds.
    if (isPanelMode) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  color: AppTheme.onBackgroundMuted,
                  onPressed: widget.onBack,
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
                const Spacer(),
                _QueueActions(
                  iconSize: 20,
                  onStash: () {
                    ref.read(playerProvider.notifier).stashQueue();
                    // Nothing left to show after stashing — go back.
                    widget.onBack?.call();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: body),
          if (miniPlayer != null) miniPlayer,
        ],
      );
    }

    // ── Full-screen mode ────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.onBackground,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Queue',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          _QueueActions(iconSize: 24, onStash: () => _stashQueue(context, ref)),
        ],
      ),
      body: body,
      // Show the mini-player fixed at the bottom of the queue screen so
      // playback controls remain available while viewing/manipulating the
      // queue.
      bottomNavigationBar: miniPlayer,
    );
  }

  Future<void> _stashQueue(BuildContext context, WidgetRef ref) async {
    await ref.read(playerProvider.notifier).stashQueue();
    // Pop back after stashing — the queue is now empty so there's nothing to
    // show, and the user can retrieve the stash via the inbox button later.
    if (context.mounted && context.canPop()) context.pop();
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List queue,
    int currentIndex,
  ) {
    if (queue.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        ..._buildQueueSlivers(context, ref, queue, currentIndex),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.queue_music_rounded,
      title: 'Queue is empty',
      subtitle: 'Play some music to fill the queue',
    );
  }

  List<Widget> _buildQueueSlivers(
    BuildContext context,
    WidgetRef ref,
    List queue,
    int currentIndex,
  ) {
    final playerState = ref.watch(playerProvider);
    return [
      // Now playing header
      if (currentIndex >= 0 && currentIndex < queue.length)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Now Playing',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final track = queue[index];
          final isCurrentTrack = index == currentIndex;
          final showUpNextHeader =
              index == currentIndex + 1 && currentIndex >= 0;

          return Column(
            key: ValueKey('queue_section_$index'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showUpNextHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      const Text(
                        'Up Next',
                        style: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${queue.length - currentIndex - 1} tracks',
                        style: const TextStyle(
                          color: AppTheme.onBackgroundSubtle,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              _DraggableQueueItem(
                track: track,
                index: index,
                isCurrentTrack: isCurrentTrack,
                isPlaying: playerState.isPlaying,
                queueLength: queue.length,
                onTap: () {
                  ref.read(playerProvider.notifier).jumpTo(index);
                },
                onDismissed: () {
                  ref.read(playerProvider.notifier).removeFromQueue(index);
                },
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(playerProvider.notifier)
                      .reorderQueue(oldIndex, newIndex);
                },
              ),
            ],
          );
        }, childCount: queue.length),
      ),
    ];
  }
}

// ── Queue Action Buttons ─────────────────────────────────────────────────

/// Stash-inbox / stash / clear buttons, shared by both the full-screen app bar
/// and the panel-mode compact header inside QueueScreen.
class _QueueActions extends ConsumerWidget {
  final double iconSize;
  final VoidCallback? onStash;
  const _QueueActions({super.key, this.iconSize = 24, this.onStash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(stashedQueuesProvider).asData?.value.length ?? 0;
    final queue = ref.watch(playerProvider).queue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Stashed queues',
          iconSize: iconSize,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: AppTheme.primary,
            child: const Icon(
              Icons.inbox_outlined,
              color: AppTheme.onBackgroundMuted,
            ),
          ),
          onPressed: () => showStashedQueuesSheet(context, ref),
        ),
        if (queue.isNotEmpty)
          IconButton(
            tooltip: 'Stash queue',
            iconSize: iconSize,
            icon: const Icon(
              Icons.save_outlined,
              color: AppTheme.onBackgroundMuted,
            ),
            onPressed:
                onStash ?? () => ref.read(playerProvider.notifier).stashQueue(),
          ),
        if (queue.isNotEmpty)
          IconButton(
            tooltip: 'Clear queue',
            iconSize: iconSize,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.error,
            ),
            onPressed: () => showClearQueueConfirmation(context, ref),
          ),
      ],
    );
  }
}

/// Show the clear-queue confirmation dialog. Public so other UI (eg. side
/// panel) can invoke it without duplicating logic.
void showClearQueueConfirmation(BuildContext context, WidgetRef ref) {
  showShellDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Clear Queue',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Remove all tracks from the queue? This will stop playback.',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.onBackgroundMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                try {
                  Analytics.track('queue_cleared');
                } catch (_) {}
                ref.read(playerProvider.notifier).playTracks([]);
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
  );
}

// ── Queue Track Row ─────────────────────────────────────────────────────

class _QueueTrackRow extends StatelessWidget {
  final dynamic track;
  final int index;
  final bool isCurrentTrack;
  final bool isPlaying;
  final VoidCallback onTap;
  final bool showDragHandle;
  final bool isDragging;

  const _QueueTrackRow({
    required this.track,
    required this.index,
    required this.isCurrentTrack,
    this.isPlaying = false,
    required this.onTap,
    this.showDragHandle = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          isCurrentTrack
              ? AppTheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Playing indicator or track number
              SizedBox(
                width: 32,
                child:
                    isCurrentTrack
                        ? _PlayingIndicator(isPlaying: isPlaying)
                        : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppTheme.onBackgroundSubtle,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
              ),
              const SizedBox(width: 12),
              // Cover art
              CoverArtWidget(
                imageUrl: track.coverUrl,
                size: 44,
                borderRadius: 6,
              ),
              const SizedBox(width: 12),
              // Track info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color:
                            isCurrentTrack
                                ? AppTheme.primary
                                : AppTheme.onBackground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistName,
                      style: TextStyle(
                        color:
                            isCurrentTrack
                                ? AppTheme.primaryLight
                                : AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Duration
              if (track.duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    formatTrackDuration(track.duration!),
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (showDragHandle)
                AnimatedOpacity(
                  opacity: isDragging ? 0.5 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: AppTheme.onBackgroundSubtle,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Playing Indicator (animated bars) ───────────────────────────────────

class _PlayingIndicator extends StatefulWidget {
  final bool isPlaying;

  const _PlayingIndicator({required this.isPlaying});

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      // Set a neutral value so the static bars look balanced
      _controller.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant _PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0.5;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _bar(0.3 + _controller.value * 0.7),
            const SizedBox(width: 2),
            _bar(0.5 + (1 - _controller.value) * 0.5),
            const SizedBox(width: 2),
            _bar(0.2 + _controller.value * 0.8),
          ],
        );
      },
    );
  }

  Widget _bar(double heightFactor) {
    return Container(
      width: 3,
      height: 16 * heightFactor,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

class _DraggableQueueItem extends StatefulWidget {
  final dynamic track;
  final int index;
  final bool isCurrentTrack;
  final bool isPlaying;
  final int queueLength;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DraggableQueueItem({
    required this.track,
    required this.index,
    required this.isCurrentTrack,
    required this.isPlaying,
    required this.queueLength,
    required this.onTap,
    required this.onDismissed,
    required this.onReorder,
  });

  @override
  State<_DraggableQueueItem> createState() => _DraggableQueueItemState();
}

class _DraggableQueueItemState extends State<_DraggableQueueItem> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCurrentTrack) {
      return Dismissible(
        key: ValueKey('queue_${widget.index}_${widget.track.id}'),
        direction: DismissDirection.none,
        child: _QueueTrackRow(
          track: widget.track,
          index: widget.index,
          isCurrentTrack: true,
          onTap: widget.onTap,
          isPlaying: widget.isPlaying,
          showDragHandle: false,
        ),
      );
    }

    return LongPressDraggable<int>(
      data: widget.index,
      delay: const Duration(milliseconds: 200),
      onDragStarted: () {
        setState(() => _isDragging = true);
      },
      onDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: MediaQuery.of(context).size.width - 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: _QueueTrackRow(
            track: widget.track,
            index: widget.index,
            isCurrentTrack: false,
            onTap: () {},
            showDragHandle: false,
          ),
        ),
      ),
      childWhenDragging: Container(
        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
        height: 64,
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != widget.index,
        onAcceptWithDetails: (details) {
          widget.onReorder(details.data, widget.index);
        },
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color:
                  isTarget
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
            ),
            child: Dismissible(
              key: ValueKey('queue_${widget.index}_${widget.track.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: AppTheme.error.withValues(alpha: 0.2),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error,
                  size: 22,
                ),
              ),
              onDismissed: (_) => widget.onDismissed(),
              child: _QueueTrackRow(
                track: widget.track,
                index: widget.index,
                isCurrentTrack: false,
                onTap: widget.onTap,
                isPlaying: widget.isPlaying,
                showDragHandle: true,
                isDragging: _isDragging,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Stashed Queues Sheet ─────────────────────────────────────────────────

/// Show a modal bottom sheet listing all stashed queues.
/// Can be called from both the queue screen and the side panel.
void showStashedQueuesSheet(BuildContext context, WidgetRef ref) {
  showShellModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) => _StashedQueuesSheet(parentRef: ref),
  );
}

class _StashedQueuesSheet extends ConsumerWidget {
  final WidgetRef parentRef;

  const _StashedQueuesSheet({required this.parentRef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashesAsync = ref.watch(stashedQueuesProvider);
    final stashes = stashesAsync.asData?.value ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stashed Queues',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (stashes.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showShellDialog<bool>(
                          context: context,
                          builder:
                              (d) => AlertDialog(
                                backgroundColor: AppTheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text(
                                  'Clear All Stashes',
                                  style: TextStyle(
                                    color: AppTheme.onBackground,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: const Text(
                                  'Delete all stashed queues? This cannot be undone.',
                                  style: TextStyle(
                                    color: AppTheme.onBackgroundMuted,
                                    fontSize: 14,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(d).pop(false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppTheme.onBackgroundMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(d).pop(true),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: AppTheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (confirmed == true) {
                          for (final s in stashes) {
                            await ref
                                .read(playerProvider.notifier)
                                .deleteStash(s.id);
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1),
            // List
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
                        controller: scrollController,
                        itemCount: stashes.length,
                        itemBuilder:
                            (context, index) => StashedQueueTile(
                              stash: stashes[index],
                              onRestored: () => Navigator.of(context).pop(),
                            ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stashed Queue Tile ───────────────────────────────────────────────────

class StashedQueueTile extends ConsumerWidget {
  final StashedQueue stash;
  final VoidCallback? onRestored;

  const StashedQueueTile({super.key, required this.stash, this.onRestored});

  String _formatSavedAt(DateTime savedAt) {
    final now = DateTime.now();
    final diff = now.difference(savedAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${savedAt.day}/${savedAt.month}/${savedAt.year}';
  }

  String _formatPosition(Duration position) {
    final m = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return position.inHours > 0 ? '${position.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = stash.currentTrack;
    final trackCount = stash.queue.length;

    return Dismissible(
      key: ValueKey('stash_${stash.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppTheme.error.withValues(alpha: 0.2),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.error,
          size: 22,
        ),
      ),
      onDismissed: (_) {
        ref.read(playerProvider.notifier).deleteStash(stash.id);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _confirmRestore(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Cover art of the current track in the stash
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CoverArtWidget(
                    imageUrl: track?.coverUrl,
                    size: 48,
                    borderRadius: 6,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stash.name != null && stash.name!.isNotEmpty
                            ? stash.name!
                            : (track?.title ?? 'Unknown track'),
                        style: const TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Subtitle: "N tracks · savedAt" (replaces artist line)
                      Text(
                        [
                          '$trackCount track${trackCount == 1 ? '' : 's'}',
                          _formatSavedAt(stash.savedAt),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action menu for stash (rename / save as playlist / delete)
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  color: AppTheme.surfaceContainerHigh,
                  onSelected: (value) async {
                    switch (value) {
                      case 'rename':
                        _showRenameDialog(context, ref);
                        break;
                      case 'save_playlist':
                        await _convertToPlaylist(context, ref);
                        break;
                      case 'delete':
                        await _confirmDelete(context, ref);
                        break;
                    }
                  },
                  itemBuilder:
                      (c) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: const [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'save_playlist',
                          child: Row(
                            children: const [
                              Icon(Icons.queue_music_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Save as playlist'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppTheme.error,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Delete',
                                style: const TextStyle(color: AppTheme.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: AppTheme.onBackgroundSubtle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: stash.name ?? '');
    // Ensure the text is selected when the dialog opens so users can replace
    // the stash name quickly. Use a post-frame callback to run after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      } catch (_) {}
    });
    showShellDialog(
      context: context,
      builder:
          (d) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Rename Stash',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: const InputDecoration(
                hintText: 'Name',
                filled: true,
                fillColor: AppTheme.surfaceContainer,
              ),
              onSubmitted: (_) async {
                Navigator.of(d).pop();
                await QueuePersistenceService.renameStash(
                  stash.id,
                  controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
                );
                ref.invalidate(stashedQueuesProvider);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(d).pop();
                  await QueuePersistenceService.renameStash(
                    stash.id,
                    controller.text.trim().isEmpty
                        ? null
                        : controller.text.trim(),
                  );
                  ref.invalidate(stashedQueuesProvider);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (d) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Stash',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Delete this stashed queue? This cannot be undone.',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(playerProvider.notifier).deleteStash(stash.id);
    }
  }

  Future<void> _convertToPlaylist(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: stash.name ?? '');
    // Preselect the suggested playlist name when the dialog opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        nameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: nameController.text.length,
        );
      } catch (_) {}
    });
    final name = await showShellDialog<String?>(
      context: context,
      builder:
          (d) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Create Playlist',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Playlist name',
                filled: true,
                fillColor: AppTheme.surfaceContainer,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(d).pop(nameController.text.trim()),
                child: const Text(
                  'Create & Add',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (name == null) return;

    final playlistName = name.trim();
    if (playlistName.isEmpty) return;

    final api = ref.read(cachedFunkwhaleApiProvider);
    try {
      final playlist = await api.createPlaylist(name: playlistName);
      final trackIds = stash.queue.map((t) => t.id).whereType<int>().toList();
      if (trackIds.isNotEmpty)
        await api.addTracksToPlaylist(playlist.id, trackIds);
      ref.invalidate(playlistsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created "${playlist.name}"')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create playlist')),
      );
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(playerProvider);
    // If queue is empty, restore directly without a confirmation dialog.
    if (playerState.queue.isEmpty) {
      ref.read(playerProvider.notifier).restoreStash(stash.id);
      onRestored?.call();
      return;
    }

    showShellDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Restore Stash',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Restoring this stash will replace the current queue. Continue?',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ref.read(playerProvider.notifier).restoreStash(stash.id);
                  onRestored?.call();
                },
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
