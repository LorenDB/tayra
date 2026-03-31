import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/download_queue_service.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';

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
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
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
    setState(() {});
    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      // Funkwhale v1.4.0: remove by list position (0-based)
      await api.removeTrackFromPlaylist(playlistId, listIndex);
      // Invalidate playlist metadata so counts update elsewhere.
      ref.invalidate(playlistsProvider);
    } catch (e) {
      // Revert on error
      _playlistTracks.insert(listIndex, removed);
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove track')));
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    // Only show the full loading skeleton on first load (no data yet).
    if (_playlist == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);

      // Fetch playlist metadata and all track pages in parallel.
      final results = await Future.wait([
        api.getPlaylist(widget.playlistId, forceRefresh: forceRefresh),
        fetchAllPages(
          (page) => api.getPlaylistTracks(
            widget.playlistId,
            page: page,
            pageSize: 100,
            forceRefresh: forceRefresh,
          ),
        ),
      ]);

      final playlist = results[0] as Playlist;
      final allTracks = results[1] as List<PlaylistTrack>;

      if (!mounted) return;

      setState(() {
        _playlist = playlist;
        _playlistTracks = allTracks;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
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

  List<Track> get _tracks => _playlistTracks.map((pt) => pt.track).toList();

  void _playAll() {
    if (_tracks.isEmpty) return;
    ref
        .read(playerProvider.notifier)
        .playTracks(_tracks, source: 'playlist_detail_play_all');
  }

  void _shuffleAll() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks)..shuffle();
    ref
        .read(playerProvider.notifier)
        .playTracks(shuffled, source: 'playlist_detail_shuffle');
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

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainer,
      onRefresh: () => _loadData(forceRefresh: true),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // App bar
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
                      // Download toggle for playlist
                      IconButton(
                        onPressed:
                            _tracks.isNotEmpty
                                ? () async {
                                  final mgr = ref.read(cacheManagerProvider);
                                  try {
                                    final isManual = await ref.read(
                                      isManualPlaylistProvider(
                                        playlist.id,
                                      ).future,
                                    );
                                    await mgr.setManualDownloaded(
                                      CacheType.playlist,
                                      playlist.id,
                                      !isManual,
                                    );
                                    // Also mark/unmark each track as manual so the
                                    // per-track UI shows the downloaded accent.
                                    for (final t in _tracks) {
                                      try {
                                        await mgr.setManualDownloaded(
                                          CacheType.track,
                                          t.id,
                                          !isManual,
                                        );
                                        ref.invalidate(
                                          isManualTrackProvider(t.id),
                                        );
                                      } catch (_) {}
                                    }
                                    await mgr.bulkSetFilesProtectedForParent(
                                      CacheType.playlist,
                                      playlist.id,
                                      !isManual,
                                    );
                                    ref.invalidate(
                                      isManualPlaylistProvider(playlist.id),
                                    );

                                    if (!isManual) {
                                      final queue = ref.read(
                                        downloadQueueServiceProvider,
                                      );
                                      final trackIds =
                                          _tracks
                                              .where((t) => t.listenUrl != null)
                                              .map((t) => t.id)
                                              .toList();
                                      unawaited(queue.enqueue(trackIds, ref));
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Download queued for "${playlist.name}"',
                                          ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Download removed for "${playlist.name}"',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e, st) {
                                    debugPrint(
                                      'Playlist toggle manual failed: $e',
                                    );
                                    debugPrintStack(stackTrace: st);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to update download flag',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                                : null,
                        icon: const Icon(Icons.download_rounded),
                        color: AppTheme.onBackground,
                      ),
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

          // Track list
          if (_playlistTracks.isNotEmpty)
            SliverList(
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
    final enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            gradient: isPrimary && enabled ? AppTheme.primaryGradient : null,
            color:
                isPrimary
                    ? (enabled ? null : AppTheme.surfaceContainerHigh)
                    : AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border:
                !isPrimary
                    ? Border.all(color: AppTheme.divider, width: 1)
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color:
                    enabled
                        ? (isPrimary ? Colors.white : AppTheme.onBackground)
                        : AppTheme.onBackgroundSubtle,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color:
                      enabled
                          ? (isPrimary ? Colors.white : AppTheme.onBackground)
                          : AppTheme.onBackgroundSubtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
