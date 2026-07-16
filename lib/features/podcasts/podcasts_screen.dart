import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/loading_indicator.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/cache/auto_offline_coordinator.dart';
import 'package:tayra/features/settings/settings_provider.dart';

enum _PodcastListFilter { subscribed, all }

class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen> {
  List<models.Channel> _channels = [];
  Set<String> _subscribedUuids = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _nextPage;
  _PodcastListFilter _filter = _PodcastListFilter.subscribed;
  bool _filterResolved = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Prefer subscribed list when the user has subscriptions.
    setState(() => _isLoading = true);
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final subscribed = await api.getChannels(pageSize: 50, subscribed: true);
      if (!mounted) return;
      _subscribedUuids = subscribed.results.map((c) => c.uuid).toSet();
      if (_subscribedUuids.isNotEmpty) {
        _filter = _PodcastListFilter.subscribed;
        setState(() {
          _channels = subscribed.results;
          _nextPage = subscribed.next;
          _isLoading = false;
          _filterResolved = true;
        });
        _maybeAutoDownload(subscribed.results);
      } else {
        _filter = _PodcastListFilter.all;
        setState(() => _filterResolved = true);
        await _loadChannels();
      }
    } catch (_) {
      if (!mounted) return;
      _filter = _PodcastListFilter.all;
      setState(() => _filterResolved = true);
      await _loadChannels();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoadingMore || _nextPage == null) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 200) {
        _loadMore();
      }
    });
  }

  Future<void> _loadChannels({bool forceRefresh = false}) async {
    setState(() {
      if (!forceRefresh || _channels.isEmpty) {
        _isLoading = true;
        _channels = [];
        _nextPage = null;
      }
      _error = null;
    });
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final subscribedOnly = _filter == _PodcastListFilter.subscribed;
      final response = await api.getChannels(
        pageSize: 50,
        subscribed: subscribedOnly ? true : null,
        forceRefresh: forceRefresh,
      );

      // Refresh subscribed UUID set in the background when loading all.
      if (!subscribedOnly) {
        try {
          final sub = await api.getChannels(
            pageSize: 100,
            subscribed: true,
            forceRefresh: forceRefresh,
          );
          _subscribedUuids = sub.results.map((c) => c.uuid).toSet();
        } catch (_) {}
      } else {
        _subscribedUuids = response.results.map((c) => c.uuid).toSet();
      }

      if (!mounted) return;
      setState(() {
        _channels = response.results;
        _nextPage = response.next;
        _isLoading = false;
      });
      _loadMoreIfNeeded();
      if (subscribedOnly) _maybeAutoDownload(response.results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_channels.isEmpty) _error = 'Failed to load podcasts: $e';
        _isLoading = false;
      });
    }
  }

  void _maybeAutoDownload(List<models.Channel> channels) {
    final settings = ref.read(settingsProvider);
    if (!settings.autoDownloadPodcastEpisodes) return;
    // Full reconcile is heavier; kick coordinator once for subscribed set.
    ref.read(autoOfflineCoordinatorProvider).reconcileSubscribedPodcasts();
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPage == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final uri = Uri.parse(_nextPage!);
      final page = int.tryParse(uri.queryParameters['page'] ?? '') ?? 2;
      final subscribedOnly = _filter == _PodcastListFilter.subscribed;
      final response = await api.getChannels(
        page: page,
        pageSize: 50,
        subscribed: subscribedOnly ? true : null,
      );
      if (!mounted) return;
      setState(() {
        _channels.addAll(response.results);
        if (subscribedOnly) {
          _subscribedUuids.addAll(response.results.map((c) => c.uuid));
        }
        _nextPage = response.next;
        _isLoadingMore = false;
      });
      _loadMoreIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more podcasts')),
      );
    }
  }

  Future<void> _showRssSubscribeDialog() async {
    final controller = TextEditingController();
    final url = await showShellDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Subscribe via RSS',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: const InputDecoration(
                hintText: 'https://example.com/feed.xml',
                hintStyle: TextStyle(color: AppTheme.onBackgroundSubtle),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Subscribe'),
              ),
            ],
          ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final channel = await api.subscribeChannelRss(url);
      Analytics.track('podcast_rss_subscribed');
      if (!mounted) return;
      setState(() {
        _subscribedUuids.add(channel.uuid);
        if (_filter == _PodcastListFilter.subscribed ||
            !_channels.any((c) => c.uuid == channel.uuid)) {
          _channels = [
            channel,
            ..._channels.where((c) => c.uuid != channel.uuid),
          ];
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subscribed to ${channel.name}')));
      if (ref.read(settingsProvider).autoDownloadPodcastEpisodes) {
        ref.read(autoOfflineCoordinatorProvider).reconcileSubscribedPodcasts();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not subscribe: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Podcasts'),
        actions: [
          IconButton(
            tooltip: 'Subscribe via RSS',
            icon: const Icon(Icons.add_rounded),
            onPressed: _showRssSubscribeDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filterResolved)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<_PodcastListFilter>(
                segments: const [
                  ButtonSegment(
                    value: _PodcastListFilter.subscribed,
                    label: Text('Subscribed'),
                    icon: Icon(Icons.bookmark_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: _PodcastListFilter.all,
                    label: Text('All'),
                    icon: Icon(Icons.podcasts_rounded, size: 16),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (sel) {
                  final next = sel.first;
                  if (next == _filter) return;
                  setState(() => _filter = next);
                  _loadChannels(forceRefresh: true);
                },
                style: ButtonStyle(
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
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    if (offlineFilterActive) {
      return const EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Podcasts unavailable offline',
        subtitle: 'Podcasts require a server connection to stream',
      );
    }

    if (_isLoading) return const ShimmerList(itemCount: 10);
    if (_error != null) {
      return InlineErrorState(message: _error!, onRetry: _loadChannels);
    }
    if (_channels.isEmpty) {
      return EmptyState(
        icon: Icons.podcasts_rounded,
        title:
            _filter == _PodcastListFilter.subscribed
                ? 'No subscriptions yet'
                : 'No podcasts found',
        subtitle:
            _filter == _PodcastListFilter.subscribed
                ? 'Subscribe via RSS or browse All podcasts on this server'
                : 'No podcast channels are available on this server',
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => _loadChannels(forceRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        itemExtent: 88,
        itemCount: _channels.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _channels.length) {
            return const PaginatedLoadingIndicator();
          }
          final channel = _channels[i];
          return _ChannelTile(
            channel: channel,
            isSubscribed: _subscribedUuids.contains(channel.uuid),
          );
        },
      ),
    );
  }
}

// ── Channel List Tile ────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final models.Channel channel;
  final bool isSubscribed;

  const _ChannelTile({required this.channel, required this.isSubscribed});

  @override
  Widget build(BuildContext context) {
    final coverUrl = channel.coverUrl;
    return ListTile(
      onTap: () {
        Analytics.track('podcast_channel_opened');
        context.push(
          '/podcasts/${channel.uuid}',
          extra: {'channel': channel, 'subscribed': isSubscribed},
        );
      },
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child:
            coverUrl != null
                ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget:
                      (context, error, stack) =>
                          const _PodcastPlaceholder(size: 48),
                )
                : const _PodcastPlaceholder(size: 48),
      ),
      title: Text(
        channel.name,
        style: const TextStyle(color: AppTheme.onBackground),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          channel.description != null && channel.description!.isNotEmpty
              ? Text(
                channel.description!,
                style: const TextStyle(color: AppTheme.onBackgroundMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
              : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSubscribed)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(
                Icons.bookmark_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.onBackgroundSubtle,
          ),
        ],
      ),
    );
  }
}

class _PodcastPlaceholder extends StatelessWidget {
  final double size;

  const _PodcastPlaceholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.surfaceContainer,
      child: Icon(
        Icons.podcasts_rounded,
        size: size * 0.5,
        color: AppTheme.onBackgroundSubtle,
      ),
    );
  }
}
