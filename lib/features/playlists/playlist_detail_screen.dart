import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/manual_download_actions.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/pill_action_button.dart';
import 'package:tayra/core/widgets/popup_menu_row.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/player/queue_actions.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final int playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  Playlist? _playlist;
  List<PlaylistTrack> _playlistTracks = [];
  bool _isLoading = true;
  String? _error;
  // Guard against concurrent track removals, which would cause list-index
  // drift between the local list and the server's ordering.
  bool _isRemovingTrack = false;

  /// Bumped on each [_loadData] so background page appends from an older
  /// load cannot interleave with a newer refresh.
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _confirmRemoveTrack(
    BuildContext context,
    int playlistId,
    int listIndex,
  ) async {
    if (_isRemovingTrack) return;
    if (!context.mounted) return;

    final ok = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Remove track',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Remove this track from the playlist?',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
    );

    if (ok != true) return;
    if (!context.mounted) return;

    // Optimistic UI update: remove locally then call API.
    final removed = _playlistTracks.removeAt(listIndex);
    setState(() {
      _isRemovingTrack = true;
    });
    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      // Funkwhale v1.4.0: remove by list position (0-based)
      await api.removeTrackFromPlaylist(playlistId, listIndex);
      Analytics.track('playlist_track_removed');
      // Invalidate playlist metadata so counts update elsewhere.
      ref.invalidate(playlistsProvider);
    } catch (e) {
      // Revert on error
      _playlistTracks.insert(listIndex, removed);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove track')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingTrack = false;
        });
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    // Only show the full loading skeleton on first load (no data yet).
    if (_playlist == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);

      // Metadata + first track page first so the UI paints quickly; remaining
      // track pages append in the background.
      final results = await Future.wait([
        api.getPlaylist(widget.playlistId, forceRefresh: forceRefresh),
        api.getPlaylistTracks(
          widget.playlistId,
          page: 1,
          pageSize: 100,
          forceRefresh: forceRefresh,
        ),
      ]);

      if (!mounted || generation != _loadGeneration) return;

      final playlist = results[0] as Playlist;
      final firstPage = results[1] as PaginatedResponse<PlaylistTrack>;
      final allTracks = List<PlaylistTrack>.from(firstPage.results);

      setState(() {
        _playlist = playlist;
        _playlistTracks = allTracks;
        _isLoading = false;
        _error = null;
      });

      if (firstPage.next != null) {
        unawaited(
          _loadRemainingTrackPages(
            api,
            startPage: 2,
            forceRefresh: forceRefresh,
            seed: allTracks,
            generation: generation,
          ),
        );
      }
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      // If we already have data loaded (e.g. pull-to-refresh failed), keep
      // showing it rather than replacing the screen with an error state.
      if (_playlist != null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh — showing cached data'),
          ),
        );
      } else {
        setState(() {
          _error = 'Failed to load playlist';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRemainingTrackPages(
    CachedFunkwhaleApi api, {
    required int startPage,
    required bool forceRefresh,
    required List<PlaylistTrack> seed,
    required int generation,
  }) async {
    try {
      final accumulated = List<PlaylistTrack>.from(seed);
      var page = startPage;
      while (true) {
        if (!mounted || generation != _loadGeneration) return;
        final response = await api.getPlaylistTracks(
          widget.playlistId,
          page: page,
          pageSize: 100,
          forceRefresh: forceRefresh,
        );
        if (!mounted || generation != _loadGeneration) return;
        accumulated.addAll(response.results);
        setState(() => _playlistTracks = List<PlaylistTrack>.from(accumulated));
        if (response.next == null) break;
        page++;
      }
    } catch (e) {
      debugPrint('Playlist remaining pages failed: $e');
    }
  }

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    Playlist playlist,
  ) async {
    if (!context.mounted) return;

    final ok = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Delete playlist',
              style: TextStyle(
                color: AppTheme.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'Delete this playlist? This cannot be undone.',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
    );

    if (ok != true) return;
    if (!context.mounted) return;

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.deletePlaylist(playlist.id);
      // Force refresh the playlists cache so the list doesn't show the deleted
      // playlist when we return to the playlists screen.
      try {
        await api.getPlaylists(scope: 'me', forceRefresh: true);
      } catch (_) {}
      Analytics.track('playlist_deleted');
      ref.invalidate(playlistsProvider);

      if (context.mounted) {
        // Ensure any open popup routes (confirmation dialogs, sheets)
        // are dismissed before popping the playlist route so they don't
        // remain visible after navigation.
        shellNavigatorKey.currentState?.popUntil(
          (route) => route is! PopupRoute,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete playlist')),
      );
    }
  }

  List<Track> get _tracks => _playlistTracks.map((pt) => pt.track).toList();

  void _playAll() {
    if (_tracks.isEmpty) return;
    Analytics.track('playlist_play_all', {'track_count': _tracks.length});
    ref
        .read(playerProvider.notifier)
        .playTracks(_tracks, source: 'playlist_detail_play_all');
  }

  void _shuffleAll() {
    if (_tracks.isEmpty) return;
    Analytics.track('playlist_shuffle_all', {'track_count': _tracks.length});
    ref
        .read(playerProvider.notifier)
        .playTracks(_tracks, source: 'playlist_detail_shuffle', shuffle: true);
  }

  void _playFromIndex(int index) {
    ref
        .read(playerProvider.notifier)
        .playTracks(
          _tracks,
          startIndex: index,
          source: 'playlist_detail_from_track',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body:
          _isLoading
              ? _buildLoading()
              : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(title: 'Loading...'),
          const Expanded(child: ShimmerList(itemCount: 10)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(title: 'Playlist'),
          Expanded(
            child: InlineErrorState(message: _error!, onRetry: _loadData),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final playlist = _playlist!;
    // Whether this playlist is currently marked as manually downloaded.
    final isManual = ref.watch(isManualPlaylistProvider(playlist.id));

    // Toggle download state (extracted from the old inline IconButton handler).
    Future<void> toggleDownload() async {
      if (_tracks.isEmpty) return;
      try {
        final current = ref.read(isManualPlaylistProvider(playlist.id));
        final enabled = await toggleCollectionManualDownload(
          ref: ref,
          parentType: CacheType.playlist,
          parentId: playlist.id,
          trackIds: _tracks.map((t) => t.id).toList(),
          enqueueTrackIds:
              _tracks
                  .where((t) => t.listenUrl != null)
                  .map((t) => t.id)
                  .toList(),
          currentlyManual: current,
        );
        // Omit playlist ID; keep counts and booleans only.
        Analytics.track('playlist_download_toggled', {
          'enabled': enabled,
          'track_count': _tracks.length,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Download queued for "${playlist.name}"'
                  : 'Download removed for "${playlist.name}"',
            ),
          ),
        );
      } catch (e, st) {
        debugPrint('Playlist toggle manual failed: $e');
        debugPrintStack(stackTrace: st);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update download flag')),
          );
        }
      }
    }

    return AppRefreshIndicator(
      onRefresh: () => _loadData(forceRefresh: true),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // App bar with overflow menu (download moved into menu)
          SliverAppBar(
            backgroundColor: AppTheme.background,
            pinned: true,
            title: Text(
              playlist.name,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.onBackground,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.onBackground,
                ),
                color: AppTheme.surfaceContainer,
                onSelected: (value) {
                  if (value == 'download') unawaited(toggleDownload());
                  if (value == 'play_next') {
                    final message = insertTracksToPlayNext(ref, _tracks);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                  if (value == 'add_queue') {
                    final message = addTracksToQueue(ref, _tracks);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                  if (value == 'edit') {
                    context
                        .push('/playlists/${playlist.id}/edit')
                        .then((_) => _loadData(forceRefresh: true));
                  }
                  if (value == 'delete') {
                    unawaited(_confirmDeletePlaylist(context, playlist));
                  }
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(
                        value: 'play_next',
                        child: PopupMenuRow(
                          icon: Icons.queue_play_next,
                          label: 'Play next',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_queue',
                        child: PopupMenuRow(
                          icon: Icons.playlist_add,
                          label: 'Add to queue',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'download',
                        child: PopupMenuRow(
                          icon:
                              isManual
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                          label: isManual ? 'Remove download' : 'Download',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: PopupMenuRow(
                          icon: Icons.edit_rounded,
                          label: 'Edit playlist',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: PopupMenuRow(
                          icon: Icons.delete_rounded,
                          label: 'Delete playlist',
                          destructive: true,
                        ),
                      ),
                    ],
              ),
            ],
          ),

          // Header with info and action buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Playlist stats
                  Text(
                    _buildStatsText(playlist),
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      // Play All button
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Play All',
                          onPressed: _tracks.isNotEmpty ? _playAll : null,
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Shuffle button
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.shuffle_rounded,
                          label: 'Shuffle',
                          onPressed: _tracks.isNotEmpty ? _shuffleAll : null,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Divider
          const SliverToBoxAdapter(
            child: Divider(
              color: AppTheme.divider,
              height: 1,
              indent: 16,
              endIndent: 16,
            ),
          ),

          // Empty state for tracks
          if (_playlistTracks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.music_note_rounded,
                title: 'No tracks in this playlist',
                subtitle: 'Add tracks from the search or library',
                iconSize: 48,
                titleFontSize: 14,
              ),
            ),

          // Track list — fixed extent for cheaper scroll layout.
          if (_playlistTracks.isNotEmpty)
            SliverFixedExtentList(
              itemExtent: kTrackListTileExtent,
              delegate: SliverChildBuilderDelegate((context, index) {
                final playlistTrack = _playlistTracks[index];
                return TrackListTile(
                  track: playlistTrack.track,
                  onTap: () => _playFromIndex(index),
                  // Provide a callback so the per-track popup menu can show
                  // "Remove from playlist" and delegate confirmation +
                  // removal to this screen (which owns the list state).
                  onRemoveFromPlaylist: () async {
                    await _confirmRemoveTrack(context, playlist.id, index);
                  },
                );
              }, childCount: _playlistTracks.length),
            ),

          // Bottom padding for mini player
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildAppBar({required String title}) {
    return AppBar(
      backgroundColor: AppTheme.background,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppTheme.onBackground,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  String _buildStatsText(Playlist playlist) {
    final parts = <String>[];
    parts.add(pluralizeTrack(playlist.tracksCount));
    if (playlist.duration != null && playlist.duration! > 0) {
      parts.add(playlist.formattedDuration);
    }
    return parts.join(' · ');
  }
}

// ── Action Button ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return PillActionButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
      isPrimary: isPrimary,
      // Primary Play All keeps the gradient fill used before pill unification.
      useGradient: isPrimary,
    );
  }
}
