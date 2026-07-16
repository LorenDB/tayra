import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/core/cache/auto_offline_coordinator.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/pill_action_button.dart';
import 'package:tayra/core/widgets/popup_menu_row.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/podcasts/podcast_progress_provider.dart';
import 'package:tayra/features/podcasts/podcast_progress_service.dart';
import 'package:tayra/features/settings/settings_provider.dart';

enum _EpisodeFilter { all, unplayed }

class PodcastDetailScreen extends ConsumerStatefulWidget {
  final String channelUuid;
  final models.Channel? channel;
  final bool? initiallySubscribed;

  const PodcastDetailScreen({
    super.key,
    required this.channelUuid,
    this.channel,
    this.initiallySubscribed,
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
  bool _isSubscribed = false;
  bool _subscribeBusy = false;
  _EpisodeFilter _filter = _EpisodeFilter.all;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _isSubscribed = widget.initiallySubscribed ?? false;
    _loadEpisodes();
  }

  Future<void> _loadEpisodes({bool forceRefresh = false}) async {
    setState(() {
      if (!forceRefresh || _episodes.isEmpty) _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);

      final futures = <Future>[
        _fetchAllEpisodes(api, forceRefresh: forceRefresh),
        if (_channel == null) api.getChannel(widget.channelUuid),
      ];
      final results = await Future.wait(futures);

      if (!mounted) return;
      final episodes = results[0] as List<models.Track>;
      setState(() {
        _episodes = episodes;
        if (_channel == null && results.length > 1) {
          _channel = results[1] as models.Channel;
        }
        _isLoading = false;
      });

      // Auto-download latest N when subscribed.
      if (_isSubscribed) {
        unawaited(
          ref
              .read(autoOfflineCoordinatorProvider)
              .enqueueLatestPodcastEpisodes(
                channelUuid: widget.channelUuid,
                episodesNewestFirst: episodes,
              ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_episodes.isEmpty) _error = 'Failed to load episodes: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<models.Track>> _fetchAllEpisodes(
    cached_api.CachedFunkwhaleApi api, {
    bool forceRefresh = false,
  }) {
    return fetchAllPages(
      (page) => api.getChannelTracks(
        channelUuid: widget.channelUuid,
        page: page,
        pageSize: 100,
        forceRefresh: forceRefresh,
      ),
    );
  }

  List<models.Track> _visibleEpisodes(
    Map<int, PodcastEpisodeProgress> progress,
  ) {
    if (_filter == _EpisodeFilter.all) return _episodes;
    return _episodes
        .where((e) => progress[e.id]?.completed != true)
        .toList(growable: false);
  }

  Future<void> _shuffleAll(List<models.Track> episodes) async {
    if (episodes.isEmpty || _isShuffling) return;
    setState(() => _isShuffling = true);
    try {
      await ref
          .read(playerProvider.notifier)
          .playTracks(episodes, shuffle: true, source: 'podcast');
      Analytics.track('podcast_shuffle_all', {
        'episode_count': episodes.length,
      });
    } finally {
      if (mounted) setState(() => _isShuffling = false);
    }
  }

  Future<void> _playAll(List<models.Track> episodes) async {
    if (episodes.isEmpty || _isPlayingAll) return;
    setState(() => _isPlayingAll = true);
    try {
      await ref
          .read(playerProvider.notifier)
          .playTracks(episodes, source: 'podcast');
      Analytics.track('podcast_play_all', {'episode_count': episodes.length});
    } finally {
      if (mounted) setState(() => _isPlayingAll = false);
    }
  }

  Future<void> _playEpisode(
    List<models.Track> allVisible,
    int index, {
    bool fromBeginning = false,
  }) async {
    final episode = allVisible[index];
    Duration? initialPosition;
    if (!fromBeginning) {
      final progress = await ref
          .read(podcastProgressServiceProvider)
          .getProgress(episode.id);
      if (progress != null && progress.hasResumePosition) {
        initialPosition = progress.position;
        Analytics.track('podcast_episode_resumed');
      }
    }
    await ref
        .read(playerProvider.notifier)
        .playTracks(
          allVisible,
          startIndex: index,
          initialPosition: initialPosition,
          source: 'podcast',
        );
    Analytics.track('podcast_episode_played');
  }

  Future<void> _toggleSubscribe() async {
    if (_subscribeBusy) return;
    setState(() => _subscribeBusy = true);
    final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
    try {
      if (_isSubscribed) {
        await api.unsubscribeChannel(widget.channelUuid);
        Analytics.track('podcast_unsubscribed');
        if (mounted) setState(() => _isSubscribed = false);
      } else {
        await api.subscribeChannel(widget.channelUuid);
        Analytics.track('podcast_subscribed');
        if (mounted) setState(() => _isSubscribed = true);
        if (ref.read(settingsProvider).autoDownloadPodcastEpisodes) {
          unawaited(
            ref
                .read(autoOfflineCoordinatorProvider)
                .enqueueLatestPodcastEpisodes(
                  channelUuid: widget.channelUuid,
                  episodesNewestFirst: _episodes,
                ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update subscription: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _subscribeBusy = false);
    }
  }

  Future<void> _downloadLatest() async {
    final n = ref.read(settingsProvider).autoDownloadPodcastEpisodeCount;
    final slice = _episodes.take(n).map((e) => e.id).toList();
    await ref
        .read(autoOfflineCoordinatorProvider)
        .enqueueTracksForOffline(slice, source: 'podcast_manual');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading latest ${slice.length} episode${slice.length == 1 ? '' : 's'}',
        ),
      ),
    );
  }

  Future<void> _markPlayed(models.Track episode) async {
    await ref
        .read(podcastProgressServiceProvider)
        .markPlayed(
          trackId: episode.id,
          channelUuid: widget.channelUuid,
          durationMs:
              episode.duration != null ? episode.duration! * 1000 : null,
        );
    ref.invalidate(channelEpisodeProgressProvider(widget.channelUuid));
    Analytics.track('podcast_marked_played');
  }

  Future<void> _markUnplayed(models.Track episode) async {
    await ref.read(podcastProgressServiceProvider).markUnplayed(episode.id);
    ref.invalidate(channelEpisodeProgressProvider(widget.channelUuid));
  }

  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    final progressAsync = ref.watch(
      channelEpisodeProgressProvider(widget.channelUuid),
    );
    final progress = progressAsync.asData?.value ?? const {};
    final visible = _visibleEpisodes(progress);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AppRefreshIndicator(
        onRefresh: () => _loadEpisodes(forceRefresh: true),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(channel),
            if (!_isLoading && _episodes.isNotEmpty)
              SliverToBoxAdapter(child: _buildActions(visible)),
            if (!_isLoading && _episodes.isNotEmpty)
              SliverToBoxAdapter(child: _buildFilterRow()),
            if (_isLoading)
              const SliverFillRemaining(child: ShimmerList(itemCount: 8))
            else if (_error != null)
              SliverFillRemaining(
                child: InlineErrorState(
                  message: _error!,
                  onRetry: _loadEpisodes,
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _filter == _EpisodeFilter.unplayed
                        ? 'No unplayed episodes'
                        : 'No episodes yet',
                    style: const TextStyle(color: AppTheme.onBackgroundMuted),
                  ),
                ),
              )
            else
              // Variable height: progress bar can add a few px.
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _EpisodeTile(
                    episode: visible[i],
                    progress: progress[visible[i].id],
                    onTap: () => _playEpisode(visible, i),
                    onPlayFromBeginning:
                        () => _playEpisode(visible, i, fromBeginning: true),
                    onMarkPlayed: () => _markPlayed(visible[i]),
                    onMarkUnplayed: () => _markUnplayed(visible[i]),
                  ),
                  childCount: visible.length,
                  addAutomaticKeepAlives: false,
                ),
              ),
          ],
        ),
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
      actions: [
        IconButton(
          tooltip: _isSubscribed ? 'Unsubscribe' : 'Subscribe',
          onPressed: _subscribeBusy ? null : _toggleSubscribe,
          icon:
              _subscribeBusy
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(
                    _isSubscribed
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color:
                        _isSubscribed
                            ? AppTheme.primary
                            : AppTheme.onBackgroundMuted,
                  ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppTheme.onBackgroundMuted,
          ),
          color: AppTheme.surfaceContainerHigh,
          onSelected: (value) {
            if (value == 'download_latest') unawaited(_downloadLatest());
          },
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'download_latest',
                  child: PopupMenuRow(
                    icon: Icons.download_rounded,
                    label:
                        'Download latest ${ref.read(settingsProvider).autoDownloadPodcastEpisodeCount}',
                  ),
                ),
              ],
        ),
      ],
      flexibleSpace:
          hasCover
              ? FlexibleSpaceBar(
                background: _PodcastCoverBackground(channel: channel!),
              )
              : null,
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<_EpisodeFilter>(
        segments: const [
          ButtonSegment(value: _EpisodeFilter.all, label: Text('All')),
          ButtonSegment(
            value: _EpisodeFilter.unplayed,
            label: Text('Unplayed'),
          ),
        ],
        selected: {_filter},
        onSelectionChanged: (sel) {
          setState(() => _filter = sel.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.onBackground;
            }
            return AppTheme.onBackgroundMuted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.surfaceContainerHigh;
            }
            return AppTheme.surfaceContainer;
          }),
        ),
      ),
    );
  }

  Widget _buildActions(List<models.Track> visible) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PillActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play All',
                  onPressed: _isPlayingAll ? null : () => _playAll(visible),
                  iconWidget:
                      _isPlayingAll
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillActionButton(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  onPressed: _isShuffling ? null : () => _shuffleAll(visible),
                  isPrimary: false,
                  iconWidget:
                      _isShuffling
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          )
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _filter == _EpisodeFilter.unplayed
                ? '${visible.length} unplayed of ${_episodes.length}'
                : '${_episodes.length} episode${_episodes.length == 1 ? '' : 's'}',
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
  final PodcastEpisodeProgress? progress;
  final VoidCallback onTap;
  final VoidCallback onPlayFromBeginning;
  final VoidCallback onMarkPlayed;
  final VoidCallback onMarkUnplayed;

  const _EpisodeTile({
    required this.episode,
    required this.progress,
    required this.onTap,
    required this.onPlayFromBeginning,
    required this.onMarkPlayed,
    required this.onMarkUnplayed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentTrack =
        ref.watch(currentPlayingTrackIdProvider) == episode.id;

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

    final completed = progress?.completed == true;
    final resume = progress?.hasResumePosition == true;
    final fraction = completed ? 1.0 : (progress?.progressFraction ?? 0.0);

    final titleColor =
        isCurrentTrack
            ? AppTheme.primary
            : completed
            ? AppTheme.onBackgroundSubtle
            : AppTheme.onBackground;
    final subtitleColor =
        isCurrentTrack
            ? AppTheme.primary.withValues(alpha: 0.7)
            : AppTheme.onBackgroundMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showEpisodeMenu(context),
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
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        decorationColor: AppTheme.onBackgroundSubtle,
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
                          if (resume) ...[
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
                            Text(
                              'Resume',
                              style: TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (fraction > 0 && !completed) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 3,
                          backgroundColor: AppTheme.surfaceContainerHighest,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (completed)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppTheme.secondary,
                  ),
                )
              else if (isCurrentTrack)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.equalizer_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppTheme.onBackgroundSubtle,
                ),
                color: AppTheme.surfaceContainerHigh,
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  switch (value) {
                    case 'play':
                      onTap();
                    case 'from_start':
                      onPlayFromBeginning();
                    case 'played':
                      onMarkPlayed();
                    case 'unplayed':
                      onMarkUnplayed();
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: PopupMenuRow(
                          icon: Icons.play_arrow_rounded,
                          label: 'Play',
                        ),
                      ),
                      if (resume)
                        const PopupMenuItem(
                          value: 'from_start',
                          child: PopupMenuRow(
                            icon: Icons.replay_rounded,
                            label: 'Play from beginning',
                          ),
                        ),
                      if (!completed)
                        const PopupMenuItem(
                          value: 'played',
                          child: PopupMenuRow(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Mark played',
                          ),
                        )
                      else
                        const PopupMenuItem(
                          value: 'unplayed',
                          child: PopupMenuRow(
                            icon: Icons.radio_button_unchecked_rounded,
                            label: 'Mark unplayed',
                          ),
                        ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEpisodeMenu(BuildContext context) {
    // Long-press opens the same menu via the popup button pattern is awkward;
    // show a simple bottom sheet instead.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Play'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onTap();
                  },
                ),
                if (progress?.hasResumePosition == true)
                  ListTile(
                    leading: const Icon(Icons.replay_rounded),
                    title: const Text('Play from beginning'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onPlayFromBeginning();
                    },
                  ),
                if (progress?.completed != true)
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline_rounded),
                    title: const Text('Mark played'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onMarkPlayed();
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.radio_button_unchecked_rounded),
                    title: const Text('Mark unplayed'),
                    onTap: () {
                      Navigator.pop(ctx);
                      onMarkUnplayed();
                    },
                  ),
              ],
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
