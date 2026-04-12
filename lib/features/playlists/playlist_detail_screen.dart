import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:aptabase_flutter/aptabase_flutter.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/ai_summary_provider.dart';
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

  Future<void> _showRenameDialog(
    BuildContext context,
    Playlist playlist,
  ) async {
    if (!context.mounted) return;

    final settings = ref.read(settingsProvider);
    final aiEnabled = settings.aiEnabled;
    final modelStatus =
        await (defaultTargetPlatform == TargetPlatform.android
            ? ref.read(genaiModelStatusProvider.future)
            : Future.value(0));
    final hasLocalAi =
        aiEnabled &&
        defaultTargetPlatform == TargetPlatform.android &&
        modelStatus == 3;

    final controller = TextEditingController(text: playlist.name);
    String? error;
    bool generating = false;
    // Local flag that can be disabled if the native plugin method is missing
    // (catch MissingPluginException and hide the button for future attempts).
    bool available = hasLocalAi;

    await showDialog<void>(
      context: context,
      // Use the root navigator so the dialog is attached to the same navigator
      // GoRouter and many app-level navigations operate on. This helps avoid
      // dialogs remaining open when the route below is popped.
      useRootNavigator: true,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                backgroundColor: AppTheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text(
                  'Rename playlist',
                  style: TextStyle(color: AppTheme.onBackground),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Playlist name',
                      ),
                      onSubmitted: (_) async {
                        Navigator.of(ctx).pop();
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: TextStyle(color: AppTheme.error)),
                    ],
                  ],
                ),
                actions: [
                  if (available)
                    IconButton(
                      tooltip: 'Generate name',
                      color: AppTheme.primary,
                      icon:
                          generating
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.auto_awesome_rounded),
                      onPressed:
                          generating
                              ? null
                              : () async {
                                setState(() => generating = true);
                                try {
                                  // Ask native plugin for a short playlist name using the same
                                  // genai channel used elsewhere in the app.
                                  final name = await MethodChannel(
                                    'dev.lorendb.tayra/genai_prompt',
                                  ).invokeMethod<String>(
                                    'generatePlaylistName',
                                    {
                                      'playlist_id': playlist.id,
                                      'current_name': playlist.name,
                                    },
                                  );
                                  if (name != null && name.isNotEmpty) {
                                    controller.text = name.trim();
                                  }
                                } catch (e, st) {
                                  // Provide better diagnostics for debugging.
                                  debugPrint('GeneratePlaylistName failed: $e');
                                  debugPrintStack(stackTrace: st);
                                  final msg =
                                      e is MissingPluginException
                                          ? 'AI not available on this device'
                                          : 'AI failed to generate name';
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(msg)));

                                  // If the plugin method isn't implemented the first time
                                  // we try it, hide the button for subsequent attempts so
                                  // users don't repeatedly hit a failing action.
                                  if (e is MissingPluginException) {
                                    setState(() => available = false);
                                  }
                                }
                                setState(() => generating = false);
                              },
                    ),
                  TextButton(
                    onPressed:
                        generating ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed:
                        generating
                            ? null
                            : () async {
                              final newName = controller.text.trim();
                              if (newName.isEmpty) {
                                setState(() => error = 'Name cannot be empty');
                                return;
                              }
                              Navigator.of(ctx).pop();
                              try {
                                final api = ref.read(
                                  cachedFunkwhaleApiProvider,
                                );
                                await api.patchPlaylist(playlist.id, {
                                  'name': newName,
                                });
                                try {
                                  Aptabase.instance.trackEvent(
                                    'playlist_renamed',
                                    {'playlist_id': playlist.id},
                                  );
                                } catch (_) {}
                                // Refresh local data
                                await _loadData(forceRefresh: true);
                                ref.invalidate(playlistsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to rename playlist',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    child: const Text('Rename'),
                  ),
                ],
              );
            },
          ),
    );
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
      try {
        Aptabase.instance.trackEvent('playlist_track_removed');
      } catch (_) {}
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

  Future<void> _confirmDeletePlaylist(
    BuildContext context,
    Playlist playlist,
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
      try {
        Aptabase.instance.trackEvent('playlist_deleted');
      } catch (_) {}
      ref.invalidate(playlistsProvider);

      if (context.mounted) Navigator.of(context).pop();
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
    try {
      Aptabase.instance.trackEvent('playlist_play_all', {
        'track_count': _tracks.length,
      });
    } catch (_) {}
    ref
        .read(playerProvider.notifier)
        .playTracks(_tracks, source: 'playlist_detail_play_all');
  }

  void _shuffleAll() {
    if (_tracks.isEmpty) return;
    try {
      Aptabase.instance.trackEvent('playlist_shuffle_all', {
        'track_count': _tracks.length,
      });
    } catch (_) {}
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
    // Whether this playlist is currently marked as manually downloaded.
    final isManualAsync = ref.watch(isManualPlaylistProvider(playlist.id));
    final isManual = isManualAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    // Toggle download state (extracted from the old inline IconButton handler).
    Future<void> toggleDownload() async {
      if (_tracks.isEmpty) return;
      final mgr = ref.read(cacheManagerProvider);
      try {
        final current = await ref.read(
          isManualPlaylistProvider(playlist.id).future,
        );
        await mgr.setManualDownloaded(
          CacheType.playlist,
          playlist.id,
          !current,
        );
        for (final t in _tracks) {
          try {
            await mgr.setManualDownloaded(CacheType.track, t.id, !current);
            ref.invalidate(isManualTrackProvider(t.id));
          } catch (_) {}
        }
        await mgr.bulkSetFilesProtectedForParent(
          CacheType.playlist,
          playlist.id,
          !current,
        );
        ref.invalidate(isManualPlaylistProvider(playlist.id));
        try {
          Aptabase.instance.trackEvent('playlist_download_toggled', {
            'enabled': !current,
            'track_count': _tracks.length,
          });
        } catch (_) {}

        if (!current) {
          final queue = ref.read(downloadQueueServiceProvider);
          final trackIds =
              _tracks
                  .where((t) => t.listenUrl != null)
                  .map((t) => t.id)
                  .toList();
          unawaited(queue.enqueue(trackIds, ref));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download queued for "${playlist.name}"')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download removed for "${playlist.name}"')),
          );
        }
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

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainer,
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
                  if (value == 'delete')
                    unawaited(_confirmDeletePlaylist(context, playlist));
                  if (value == 'rename')
                    unawaited(_showRenameDialog(context, playlist));
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(
                              isManual
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                              size: 20,
                              color: AppTheme.onBackground,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isManual ? 'Remove download' : 'Download',
                              style: const TextStyle(
                                color: AppTheme.onBackground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: AppTheme.onBackground,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Rename playlist',
                              style: TextStyle(color: AppTheme.onBackground),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.delete_rounded,
                              size: 20,
                              color: AppTheme.error,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Delete playlist',
                              style: TextStyle(color: AppTheme.onBackground),
                            ),
                          ],
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

    // Use platform-styled Elevated/Outlined buttons to match the rest of the
    // app (pill-shaped, 44px height, 22px radius and consistent typography).
    // Primary: use gradient decoration when enabled, else muted surface.
    if (isPrimary) {
      final deco =
          enabled
              ? BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(22),
              )
              : BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
              );

      return Container(
        height: 44,
        decoration: deco,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 20,
          color:
              enabled
                  ? AppTheme.onBackground
                  : AppTheme.onBackgroundSubtle.withValues(alpha: 0.4),
        ),
        label: Text(
          label,
          style: TextStyle(
            color:
                enabled
                    ? AppTheme.onBackground
                    : AppTheme.onBackgroundSubtle.withValues(alpha: 0.4),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color:
                enabled
                    ? AppTheme.onBackground
                    : AppTheme.onBackgroundSubtle.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
