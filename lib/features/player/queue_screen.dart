import 'package:tayra/core/analytics/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/features/player/player_provider.dart';

import 'package:tayra/features/player/queue_persistence_service.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/features/playlists/add_to_playlist_sheet.dart';
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

  /// Called when the user taps the stashed-queues inbox button in panel mode.
  /// When provided, the parent handles navigation (e.g. SidePanel subpages).
  /// When null, the queue screen handles it inline (full-screen mode fallback).
  final VoidCallback? onOpenInbox;

  const QueueScreen({
    super.key,
    this.scrollController,
    this.onBack,
    this.miniPlayerOnTap,
    this.onOpenInbox,
  });

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  late ScrollController _scrollController;
  bool _hasScrolled = false;
  bool _ownsController = false;
  bool _showInlineStashes = false;

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
      if (!_scrollController.hasClients) return;
      final itemHeight = kQueueTrackRowExtent;
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
    // Auto-navigate away when playback stops (e.g. after clearing the queue)
    // so the user is never stranded on an empty queue screen with no escape.
    ref.listen(playerProvider.select((s) => s.currentTrack), (previous, next) {
      if (previous != null && next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.onBack != null) {
            widget.onBack!();
          } else if (context.canPop()) {
            context.pop();
          }
        });
      }
    });

    final (queue, currentIndex) = ref.watch(
      playerProvider.select((s) => (s.queue, s.currentIndex)),
    );
    final hasCurrentTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack != null),
    );

    if (!_hasScrolled && queue.isNotEmpty) {
      _scrollToCurrentTrack(currentIndex, queue.length);
    }

    final isPanelMode = widget.onBack != null;

    final body = IndexedStack(
      index: _showInlineStashes ? 1 : 0,
      children: [
        _buildBody(context, ref, queue, currentIndex),
        _StashedQueuesInline(
          onRestored: () {
            // Close the inline stashes view when a stash is restored so the
            // user is returned to the main queue / now-playing UI.
            if (mounted) setState(() => _showInlineStashes = false);
          },
        ),
      ],
    );

    final miniPlayer =
        hasCurrentTrack
            ? SafeArea(
              top: false,
              child: MiniPlayer(
                // Priority: explicit prop -> panel onBack (switch panel view)
                // -> close inline stashes -> pop nav if possible -> push now-playing
                onTap:
                    widget.miniPlayerOnTap ??
                    () {
                      if (widget.onBack != null) {
                        // Panel mode: ask parent to switch back to now-playing view.
                        widget.onBack!.call();
                        return;
                      }

                      if (_showInlineStashes) {
                        // If the inline stashes view is open, close it instead of
                        // navigating so the user returns to the queue/now-playing UI.
                        setState(() => _showInlineStashes = false);
                        return;
                      }

                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.push('/now-playing');
                      }
                    },
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
                  onOpenInbox:
                      widget.onOpenInbox ??
                      () => setState(() => _showInlineStashes = true),
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
    return PopScope(
      canPop: !_showInlineStashes,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showInlineStashes = false);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar:
            _showInlineStashes
                ? AppBar(
                  backgroundColor: AppTheme.background,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppTheme.onBackground,
                    ),
                    onPressed: () => setState(() => _showInlineStashes = false),
                  ),
                  title: const Text(
                    'Stashed Queues',
                    style: TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                : AppBar(
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
                    _QueueActions(
                      iconSize: 24,
                      onStash: () => _stashQueue(context, ref),
                      onOpenInbox:
                          () => setState(() => _showInlineStashes = true),
                    ),
                  ],
                ),
        body: body,
        // Show the mini-player fixed at the bottom of the queue screen so
        // playback controls remain available while viewing/manipulating the
        // queue.
        bottomNavigationBar: miniPlayer,
      ),
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
    List<Track> queue,
    int currentIndex,
  ) {
    if (queue.isEmpty) return _buildEmptyState();

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      // Bottom padding / end-of-queue drop zone is built inside the queue
      // slivers so the entire trailing region accepts drops.
      slivers: _buildQueueSlivers(context, ref, queue, currentIndex),
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
    List<Track> queue,
    int currentIndex,
  ) {
    // Do NOT watch isPlaying here — that rebuilt every row on play/pause.
    // The current-track row watches it locally via _PlayingIndicator.
    final hasCurrent =
        currentIndex >= 0 && currentIndex < queue.length;
    final upNextStart = hasCurrent ? currentIndex + 1 : 0;
    final hasUpNext = upNextStart < queue.length;

    Widget queueRow(int index) {
      final track = queue[index];
      return _DraggableQueueItem(
        key: ValueKey('queue_row_${track.id}_$index'),
        track: track,
        index: index,
        isCurrentTrack: index == currentIndex,
        queueLength: queue.length,
        onTap: () {
          ref.read(playerProvider.notifier).jumpTo(index);
        },
        onDismissed: () {
          ref.read(playerProvider.notifier).removeFromQueue(index);
        },
        onReorder: (oldIndex, newIndex) {
          ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
        },
      );
    }

    return [
      // Start-of-queue drop zone (includes the "Now Playing" header when the
      // current track is first). Dropping here inserts at index 0 so tracks
      // can be moved to the front without needing a precise hit on row 0.
      if (queue.isNotEmpty)
        SliverToBoxAdapter(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) {
              final from = details.data;
              return from > 0 && from < queue.length;
            },
            onAcceptWithDetails: (details) {
              ref.read(playerProvider.notifier).reorderQueue(details.data, 0);
            },
            builder: (context, candidateData, rejectedData) {
              final isTarget = candidateData.isNotEmpty;
              final showNowPlayingHeader = hasCurrent;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      isTarget
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                  border:
                      isTarget
                          ? const Border(
                            bottom: BorderSide(
                              color: AppTheme.primary,
                              width: 2,
                            ),
                          )
                          : null,
                ),
                child:
                    showNowPlayingHeader
                        ? const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                          child: Text(
                            'Now Playing',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                        : SizedBox(height: isTarget ? 40 : 16),
              );
            },
          ),
        ),

      // Tracks through the current one (or full queue when no current index).
      if (hasCurrent)
        SliverFixedExtentList(
          itemExtent: kQueueTrackRowExtent,
          delegate: SliverChildBuilderDelegate(
            (context, i) => queueRow(i),
            childCount: currentIndex + 1,
          ),
        )
      else
        SliverFixedExtentList(
          itemExtent: kQueueTrackRowExtent,
          delegate: SliverChildBuilderDelegate(
            (context, i) => queueRow(i),
            childCount: queue.length,
          ),
        ),

      // "Up Next" between current track and the remainder.
      if (hasCurrent && hasUpNext)
        SliverToBoxAdapter(
          child: Padding(
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
        ),

      if (hasCurrent && hasUpNext)
        SliverFixedExtentList(
          itemExtent: kQueueTrackRowExtent,
          delegate: SliverChildBuilderDelegate(
            (context, i) => queueRow(upNextStart + i),
            childCount: queue.length - upNextStart,
          ),
        ),

      // Compact end-of-queue drop zone. Expands while a drag is hovering so
      // "append to end" stays easy without leaving a huge blank tail.
      if (queue.isNotEmpty)
        SliverToBoxAdapter(
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) {
              final from = details.data;
              return from >= 0 && from < queue.length;
            },
            onAcceptWithDetails: (details) {
              ref
                  .read(playerProvider.notifier)
                  .reorderQueue(details.data, queue.length);
            },
            builder: (context, candidateData, rejectedData) {
              final isTarget = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                height: isTarget ? 48 : 24,
                decoration: BoxDecoration(
                  color:
                      isTarget
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                  border:
                      isTarget
                          ? const Border(
                            top: BorderSide(color: AppTheme.primary, width: 2),
                          )
                          : null,
                ),
              );
            },
          ),
        ),
    ];
  }
}

/// Fixed height for a queue row (cover + vertical padding). Used with
/// [SliverFixedExtentList] and scroll-to-current math.
const double kQueueTrackRowExtent = 64.0;

// ── Queue Action Buttons ─────────────────────────────────────────────────

/// Stash-inbox / stash / clear buttons, shared by both the full-screen app bar
/// and the panel-mode compact header inside QueueScreen.
class _QueueActions extends ConsumerWidget {
  final double iconSize;
  final VoidCallback? onStash;
  final VoidCallback? onOpenInbox;
  const _QueueActions({this.iconSize = 24, this.onStash, this.onOpenInbox});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(stashedQueuesProvider).asData?.value.length ?? 0;
    final queue = ref.watch(playerProvider.select((s) => s.queue));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (queue.isNotEmpty)
          IconButton(
            tooltip: 'Save as playlist',
            iconSize: iconSize,
            icon: const Icon(
              Icons.playlist_add_rounded,
              color: AppTheme.onBackgroundMuted,
            ),
            onPressed: () => _saveQueueAsPlaylist(context, ref, queue),
          ),
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
          onPressed: () {
            // If a parent provided an inline-open handler (QueueScreen), use it;
            // otherwise fall back to the modal bottom sheet used elsewhere.
            if (onOpenInbox != null) {
              onOpenInbox!.call();
            } else {
              showStashedQueuesSheet(context, ref);
            }
          },
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

Future<void> _saveQueueAsPlaylist(
  BuildContext context,
  WidgetRef ref,
  List queue,
) async {
  final nameController = TextEditingController();
  final name = await showShellDialog<String?>(
    context: context,
    builder:
        (d) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Save Queue as Playlist',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.onBackground),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              filled: true,
              fillColor: AppTheme.surfaceContainer,
            ),
            onSubmitted: (_) => Navigator.of(d).pop(nameController.text.trim()),
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
              onPressed: () => Navigator.of(d).pop(nameController.text.trim()),
              child: const Text(
                'Create',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
  );
  nameController.dispose();

  if (name == null || name.isEmpty) return;

  final api = ref.read(cachedFunkwhaleApiProvider);
  try {
    final playlist = await api.createPlaylist(name: name);
    final trackIds = queue.map((t) => t.id).whereType<int>().toList();
    if (trackIds.isNotEmpty) {
      await api.addTracksToPlaylist(playlist.id, trackIds);
    }
    ref.invalidate(playlistsProvider);
    try {
      Analytics.track('queue_saved_as_playlist', {
        'track_count': trackIds.length,
      });
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created "${playlist.name}"')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create playlist')),
      );
    }
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

/// Visual content for a queue row (no Material/InkWell — the parent paints
/// hover/press ink across content + drag handle as one surface).
class _QueueTrackRow extends StatelessWidget {
  final Track track;
  final int index;
  final bool isCurrentTrack;

  /// When true, right padding is tightened because a drag handle sits beside
  /// this row as a sibling widget.
  final bool compactTrailing;

  const _QueueTrackRow({
    required this.track,
    required this.index,
    required this.isCurrentTrack,
    this.compactTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, compactTrailing ? 4 : 16, 10),
      child: Row(
        children: [
          // Playing indicator or track number. Indicator watches isPlaying
          // locally so the whole queue list does not rebuild on play/pause.
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
          // Cover art — thumb crop + decode-at-display-size.
          CoverArtWidget(
            imageUrl: track.thumbCoverUrl,
            cacheKey: track.thumbCoverUrl,
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
        ],
      ),
    );
  }
}

// ── Queue item context menu ─────────────────────────────────────────────

Future<void> _showQueueTrackMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Track track,
  required int index,
  Offset? globalPosition,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;

  // Prefer the pointer position (right-click); fall back to row center (long-press).
  final RelativeRect position;
  if (globalPosition != null) {
    final local = globalPosition;
    position = RelativeRect.fromLTRB(
      local.dx,
      local.dy,
      overlay.size.width - local.dx,
      overlay.size.height - local.dy,
    );
  } else {
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final center = topLeft + box.size.center(Offset.zero);
    position = RelativeRect.fromRect(
      Rect.fromCenter(center: center, width: 1, height: 1),
      Offset.zero & overlay.size,
    );
  }

  final albumAvailable = track.album != null;
  final artistAvailable = track.artist != null;

  final value = await showMenu<String>(
    context: context,
    position: position,
    color: AppTheme.surfaceContainerHighest,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      PopupMenuItem(
        value: 'go_to_album',
        enabled: albumAvailable,
        child: Row(
          children: [
            Icon(
              Icons.album,
              size: 20,
              color:
                  albumAvailable
                      ? AppTheme.onBackground
                      : AppTheme.onBackgroundMuted,
            ),
            const SizedBox(width: 12),
            const Text('Go to album'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'go_to_artist',
        enabled: artistAvailable,
        child: Row(
          children: [
            Icon(
              Icons.person,
              size: 20,
              color:
                  artistAvailable
                      ? AppTheme.onBackground
                      : AppTheme.onBackgroundMuted,
            ),
            const SizedBox(width: 12),
            const Text('Go to artist'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'add_playlist',
        child: Row(
          children: [
            Icon(
              Icons.playlist_add_rounded,
              size: 20,
              color: AppTheme.onBackground,
            ),
            const SizedBox(width: 12),
            const Text('Add to playlist'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'remove_from_queue',
        child: Row(
          children: [
            Icon(
              Icons.playlist_remove_rounded,
              size: 20,
              color: AppTheme.error,
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove from queue',
              style: TextStyle(color: AppTheme.error),
            ),
          ],
        ),
      ),
    ],
  );

  if (value == null || !context.mounted) return;

  switch (value) {
    case 'go_to_album':
      if (albumAvailable) {
        context.push('/album/${track.album!.id}');
      }
      break;
    case 'go_to_artist':
      if (artistAvailable) {
        context.push('/artist/${track.artist!.id}');
      }
      break;
    case 'add_playlist':
      showAddToPlaylistSheet(context, ref, trackIds: [track.id]);
      break;
    case 'remove_from_queue':
      ref.read(playerProvider.notifier).removeFromQueue(index);
      break;
  }
}

// ── Playing Indicator (animated bars) ───────────────────────────────────

/// Watches [playerProvider.isPlaying] itself so only this tiny widget rebuilds
/// on play/pause — not every queue row.
class _PlayingIndicator extends ConsumerStatefulWidget {
  const _PlayingIndicator();

  @override
  ConsumerState<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends ConsumerState<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.value = 0.5;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPlaying(bool isPlaying) {
    if (isPlaying == _wasPlaying) return;
    _wasPlaying = isPlaying;
    if (isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));
    // Schedule controller changes after this frame to avoid side-effects
    // during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyPlaying(isPlaying);
    });

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

class _DraggableQueueItem extends ConsumerStatefulWidget {
  final Track track;
  final int index;
  final bool isCurrentTrack;
  final int queueLength;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DraggableQueueItem({
    super.key,
    required this.track,
    required this.index,
    required this.isCurrentTrack,
    required this.queueLength,
    required this.onTap,
    required this.onDismissed,
    required this.onReorder,
  });

  @override
  ConsumerState<_DraggableQueueItem> createState() =>
      _DraggableQueueItemState();
}

class _DraggableQueueItemState extends ConsumerState<_DraggableQueueItem> {
  bool _isDragging = false;

  void _onOpenMenu(Offset? globalPosition) {
    _showQueueTrackMenu(
      context: context,
      ref: ref,
      track: widget.track,
      index: widget.index,
      globalPosition: globalPosition,
    );
  }

  static const double _dragFeedbackSize = 72;

  Widget _buildDragHandle() {
    // LongPressDraggable (not immediate Draggable) is required inside a
    // scroll view: an immediate multi-drag loses the gesture arena to the
    // CustomScrollView's vertical drag recognizer.
    return LongPressDraggable<int>(
      data: widget.index,
      delay: const Duration(milliseconds: 150),
      hapticFeedbackOnStart: true,
      // Anchor so the square tile is centered under the pointer rather than
      // offset from the handle's top-left (which would clip a full-width row).
      dragAnchorStrategy: (draggable, context, position) {
        return const Offset(_dragFeedbackSize / 2, _dragFeedbackSize / 2);
      },
      onDragStarted: () {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
        setState(() => _isDragging = true);
      },
      onDragEnd: (_) {
        if (mounted) setState(() => _isDragging = false);
      },
      feedback: Material(
        elevation: 10,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: CoverArtWidget(
          imageUrl: widget.track.coverUrl,
          size: _dragFeedbackSize,
          borderRadius: 10,
        ),
      ),
      // Keep a same-size placeholder so the row layout doesn't jump while
      // the elevated feedback follows the finger.
      childWhenDragging: const SizedBox(
        width: 44,
        child: Center(
          child: Icon(
            Icons.drag_handle_rounded,
            color: AppTheme.onBackgroundSubtle,
            size: 20,
          ),
        ),
      ),
      child: const SizedBox(
        width: 44,
        child: Center(
          child: Icon(
            Icons.drag_handle_rounded,
            color: AppTheme.onBackgroundSubtle,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDropHighlight({required bool isTarget, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color:
            isTarget
                ? AppTheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
        border:
            isTarget
                ? const Border(
                  top: BorderSide(color: AppTheme.primary, width: 2),
                )
                : null,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // One Material + InkWell spans content + drag handle so hover/press ink
    // is not clipped at the grip. Drag stays scoped to the handle widget.
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != widget.index,
      onAcceptWithDetails: (details) {
        widget.onReorder(details.data, widget.index);
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        final row = _QueueTrackRow(
          track: widget.track,
          index: widget.index,
          isCurrentTrack: widget.isCurrentTrack,
          compactTrailing: true,
        );

        final inkRow = Material(
          color:
              widget.isCurrentTrack
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
          child: AnimatedOpacity(
            opacity: _isDragging ? 0.35 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: InkWell(
              onTap: widget.onTap,
              // Long-press (touch) and right-click (mouse) both open the menu.
              // The handle's LongPressDraggable wins over long-press on the grip.
              onLongPress: () => _onOpenMenu(null),
              onSecondaryTapDown:
                  (details) => _onOpenMenu(details.globalPosition),
              // Fixed-height row: no IntrinsicHeight (expensive during scroll).
              child: SizedBox(
                height: kQueueTrackRowExtent,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [Expanded(child: row), _buildDragHandle()],
                ),
              ),
            ),
          ),
        );

        // Now-playing stays non-dismissible (removing it would skip playback).
        final body =
            widget.isCurrentTrack
                ? inkRow
                : Dismissible(
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
                  child: inkRow,
                );

        return _buildDropHighlight(isTarget: isTarget, child: body);
      },
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

/// Inline variant of the stashed-queues UI that renders inside the Queue
/// screen body (full-screen/mobile mode). The AppBar is handled by the parent
/// Scaffold so this widget only contains the list content.
class _StashedQueuesInline extends ConsumerWidget {
  final VoidCallback? onRestored;
  const _StashedQueuesInline({this.onRestored});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stashes = ref.watch(stashedQueuesProvider).asData?.value ?? [];

    if (stashes.isEmpty) {
      return const Center(
        child: Text(
          'No stashed queues',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: stashes.length,
      itemBuilder:
          (context, index) =>
              StashedQueueTile(stash: stashes[index], onRestored: onRestored),
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
    ).whenComplete(controller.dispose);
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
    nameController.dispose();

    if (name == null) return;

    final playlistName = name.trim();
    if (playlistName.isEmpty) return;

    final api = ref.read(cachedFunkwhaleApiProvider);
    try {
      final playlist = await api.createPlaylist(name: playlistName);
      final trackIds = stash.queue.map((t) => t.id).whereType<int>().toList();
      if (trackIds.isNotEmpty) {
        await api.addTracksToPlaylist(playlist.id, trackIds);
      }
      ref.invalidate(playlistsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created "${playlist.name}"')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create playlist')),
      );
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    final playerState = ref.read(playerProvider);
    // If queue is empty, or the current queue has finished (not playing,
    // at index 0 and position zero), restore directly without prompting.
    final bool isFinished =
        playerState.queue.isNotEmpty &&
        playerState.currentIndex == 0 &&
        playerState.position == Duration.zero &&
        !playerState.isPlaying;
    if (playerState.queue.isEmpty || isFinished) {
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
                  // Ensure any inline UI is closed by calling the provided
                  // onRestored callback (parent will hide inline UI). Do not
                  // manipulate global providers here.
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
