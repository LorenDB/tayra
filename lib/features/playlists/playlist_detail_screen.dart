import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funkwhale/core/api/cached_api_repository.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/track_list_tile.dart';
import 'package:funkwhale/core/widgets/shimmer_loading.dart';
import 'package:funkwhale/features/player/player_provider.dart';

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final results = await Future.wait([
        api.getPlaylist(widget.playlistId),
        api.getPlaylistTracks(widget.playlistId),
      ]);

      if (!mounted) return;

      setState(() {
        _playlist = results[0] as Playlist;
        final tracksResponse = results[1] as dynamic;
        _playlistTracks =
            (tracksResponse.results as List<dynamic>).cast<PlaylistTrack>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load playlist';
        _isLoading = false;
      });
    }
  }

  List<Track> get _tracks => _playlistTracks.map((pt) => pt.track).toList();

  void _playAll() {
    if (_tracks.isEmpty) return;
    ref.read(playerProvider.notifier).playTracks(_tracks);
  }

  void _shuffleAll() {
    if (_tracks.isEmpty) return;
    final shuffled = List<Track>.from(_tracks)..shuffle();
    ref.read(playerProvider.notifier).playTracks(shuffled);
  }

  void _playFromIndex(int index) {
    ref.read(playerProvider.notifier).playTracks(_tracks, startIndex: index);
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
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error.withValues(alpha: 0.7),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _loadData, child: const Text('Retry')),
                ],
              ),
            ),
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
      onRefresh: _loadData,
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
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No tracks in this playlist',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add tracks from the search or library',
                      style: TextStyle(
                        color: AppTheme.onBackgroundSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
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
    parts.add(
      '${playlist.tracksCount} ${playlist.tracksCount == 1 ? 'track' : 'tracks'}',
    );
    if (playlist.duration != null && playlist.duration! > 0) {
      final hours = playlist.duration! ~/ 3600;
      final minutes = (playlist.duration! % 3600) ~/ 60;
      if (hours > 0) {
        parts.add('${hours}h ${minutes}m');
      } else {
        parts.add('$minutes min');
      }
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
