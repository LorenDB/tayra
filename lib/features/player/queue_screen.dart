import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/features/player/player_provider.dart';

class QueueScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  final bool showAppBar;

  const QueueScreen({super.key, this.scrollController, this.showAppBar = true});

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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar:
          widget.showAppBar
              ? AppBar(
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
                  if (queue.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _showClearConfirmation(context, ref);
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              )
              : null,
      body:
          queue.isEmpty
              ? _buildEmptyState()
              : _buildQueueList(context, ref, queue, currentIndex),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Queue is empty',
            style: TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Play some music to fill the queue',
            style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    WidgetRef ref,
    List queue,
    int currentIndex,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Now playing header
        if (currentIndex >= 0 && currentIndex < queue.length)
          Padding(
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

        // Queue list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final track = queue[index];
              final isCurrentTrack = index == currentIndex;

              // Section divider between "now playing" and "up next"
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
            },
          ),
        ),
      ],
    );
  }

  void _showClearConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
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
}

// ── Queue Track Row ─────────────────────────────────────────────────────

class _QueueTrackRow extends StatelessWidget {
  final dynamic track;
  final int index;
  final bool isCurrentTrack;
  final VoidCallback onTap;
  final bool showDragHandle;
  final bool isDragging;

  const _QueueTrackRow({
    required this.track,
    required this.index,
    required this.isCurrentTrack,
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
                        ? const _PlayingIndicator()
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
                    _formatDuration(track.duration!),
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Playing Indicator (animated bars) ───────────────────────────────────

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

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
    )..repeat(reverse: true);
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
  final int queueLength;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DraggableQueueItem({
    required this.track,
    required this.index,
    required this.isCurrentTrack,
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
