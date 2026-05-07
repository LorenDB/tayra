import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';

class PodcastDetailScreen extends ConsumerStatefulWidget {
  final String channelUuid;
  final models.Channel? channel;

  const PodcastDetailScreen({
    super.key,
    required this.channelUuid,
    this.channel,
  });

  @override
  ConsumerState<PodcastDetailScreen> createState() =>
      _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends ConsumerState<PodcastDetailScreen> {
  models.Channel? _channel;
  List<models.Track> _episodes = [];
  bool _isLoading = false;
  String? _error;
  bool _isShuffling = false;
  bool _isPlayingAll = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);

      final futures = <Future>[
        _fetchAllEpisodes(api),
        if (_channel == null) api.getChannel(widget.channelUuid),
      ];
      final results = await Future.wait(futures);

      if (!mounted) return;
      setState(() {
        _episodes = results[0] as List<models.Track>;
        if (_channel == null && results.length > 1) {
          _channel = results[1] as models.Channel;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load episodes: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<models.Track>> _fetchAllEpisodes(
    cached_api.CachedFunkwhaleApi api,
  ) {
    return fetchAllPages(
      (page) => api.getChannelTracks(
        channelUuid: widget.channelUuid,
        page: page,
        pageSize: 100,
      ),
    );
  }

  Future<void> _shuffleAll() async {
    if (_episodes.isEmpty || _isShuffling) return;
    setState(() => _isShuffling = true);
    try {
      final shuffled = List<models.Track>.from(_episodes)..shuffle();
      await ref.read(playerProvider.notifier).playTracks(shuffled);
      Analytics.track('podcast_shuffle_all', {
        'episode_count': _episodes.length,
      });
    } finally {
      if (mounted) setState(() => _isShuffling = false);
    }
  }

  Future<void> _playAll() async {
    if (_episodes.isEmpty || _isPlayingAll) return;
    setState(() => _isPlayingAll = true);
    try {
      await ref.read(playerProvider.notifier).playTracks(_episodes);
      Analytics.track('podcast_play_all', {'episode_count': _episodes.length});
    } finally {
      if (mounted) setState(() => _isPlayingAll = false);
    }
  }

  void _playEpisode(int index) {
    ref.read(playerProvider.notifier).playTracks(_episodes, startIndex: index);
    Analytics.track('podcast_episode_played');
  }

  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(channel),
          if (!_isLoading && _episodes.isNotEmpty)
            SliverToBoxAdapter(child: _buildActions()),
          if (_isLoading)
            const SliverFillRemaining(child: ShimmerList(itemCount: 8))
          else if (_error != null)
            SliverFillRemaining(
              child: InlineErrorState(message: _error!, onRetry: _loadEpisodes),
            )
          else if (_episodes.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No episodes yet',
                  style: TextStyle(color: AppTheme.onBackgroundMuted),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _EpisodeTile(
                  episode: _episodes[i],
                  onTap: () => _playEpisode(i),
                ),
                childCount: _episodes.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(models.Channel? channel) {
    final hasCover = channel?.coverUrl != null;
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      expandedHeight: hasCover ? 280 : null,
      pinned: true,
      title:
          channel != null
              ? Text(
                channel.name,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
              : null,
      flexibleSpace:
          hasCover
              ? FlexibleSpaceBar(
                background: _PodcastCoverBackground(channel: channel!),
              )
              : null,
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: _isPlayingAll ? null : _playAll,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon:
                _isPlayingAll
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Play All'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _isShuffling ? null : _shuffleAll,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.surfaceContainer,
              foregroundColor: AppTheme.onBackground,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon:
                _isShuffling
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                    : const Icon(
                      Icons.shuffle_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
            label: const Text('Shuffle'),
          ),
          const Spacer(),
          Text(
            '${_episodes.length} episode${_episodes.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Episode Tile ────────────────────────────────────────────────────────────

final _episodeDateFormat = DateFormat('MMM d, yyyy');

class _EpisodeTile extends ConsumerWidget {
  final models.Track episode;
  final VoidCallback onTap;

  const _EpisodeTile({required this.episode, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentTrack = ref.watch(
      playerProvider.select((s) => s.currentTrack?.id == episode.id),
    );

    final dateStr =
        episode.creationDate != null
            ? _episodeDateFormat.format(episode.creationDate!.toLocal())
            : null;

    final duration = episode.duration;
    String? durationStr;
    if (duration != null && duration > 0) {
      final h = duration ~/ 3600;
      final m = (duration % 3600) ~/ 60;
      durationStr = h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    final titleColor =
        isCurrentTrack ? AppTheme.primary : AppTheme.onBackground;
    final subtitleColor =
        isCurrentTrack
            ? AppTheme.primary.withValues(alpha: 0.7)
            : AppTheme.onBackgroundMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      episode.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dateStr != null || durationStr != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (dateStr != null)
                            Text(
                              dateStr,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                          if (dateStr != null && durationStr != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (durationStr != null)
                            Text(
                              durationStr,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isCurrentTrack)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.equalizer_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Podcast Cover Background ─────────────────────────────────────────────────

class _PodcastCoverBackground extends StatelessWidget {
  final models.Channel channel;

  const _PodcastCoverBackground({required this.channel});

  @override
  Widget build(BuildContext context) {
    final coverUrl = channel.coverUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null)
          CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            errorWidget:
                (context, error, stack) =>
                    const ColoredBox(color: AppTheme.surfaceContainer),
          )
        else
          const ColoredBox(color: AppTheme.surfaceContainer),
        // Gradient overlay so collapsed toolbar title is legible
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), AppTheme.background],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        if (channel.description != null && channel.description!.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Text(
              channel.description!,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
