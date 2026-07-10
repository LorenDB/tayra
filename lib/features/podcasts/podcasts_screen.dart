import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart' as cached_api;
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/loading_indicator.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';

class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen> {
  List<models.Channel> _channels = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String? _nextPage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadChannels({bool forceRefresh = false}) async {
    setState(() {
      // Only show full-screen shimmer on initial load; keep existing list
      // visible when refreshing so offline stale data isn't hidden.
      if (!forceRefresh || _channels.isEmpty) {
        _isLoading = true;
        _channels = [];
        _nextPage = null;
      }
      _error = null;
    });
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      final response = await api.getChannels(
        pageSize: 50,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _channels = response.results;
        _nextPage = response.next;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_channels.isEmpty) _error = 'Failed to load podcasts: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPage == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final api = ref.read(cached_api.cachedFunkwhaleApiProvider);
      // Extract page number from the next URL
      final uri = Uri.parse(_nextPage!);
      final page = int.tryParse(uri.queryParameters['page'] ?? '') ?? 2;
      final response = await api.getChannels(page: page, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _channels.addAll(response.results);
        _nextPage = response.next;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more podcasts')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Podcasts'),
      ),
      body: _buildBody(),
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
      return const EmptyState(
        icon: Icons.podcasts_rounded,
        title: 'No podcasts found',
        subtitle: 'No podcast channels are available on this server',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadChannels(forceRefresh: true),
      color: AppTheme.primary,
      backgroundColor: AppTheme.surfaceContainer,
      child: ListView.builder(
        controller: _scrollController,
        // Fixed extent for channel rows (48px art + optional 2-line subtitle).
        itemExtent: 88,
        itemCount: _channels.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _channels.length) {
            return const PaginatedLoadingIndicator();
          }
          return _ChannelTile(channel: _channels[i]);
        },
      ),
    );
  }
}

// ── Channel List Tile ────────────────────────────────────────────────────

class _ChannelTile extends StatelessWidget {
  final models.Channel channel;

  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    final coverUrl = channel.coverUrl;
    return ListTile(
      onTap: () {
        Analytics.track('podcast_channel_opened');
        context.push('/podcasts/${channel.uuid}', extra: channel);
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
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.onBackgroundSubtle,
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
