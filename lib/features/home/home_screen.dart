import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/api/cached_api_repository.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/cover_art.dart';
import 'package:funkwhale/core/widgets/track_list_tile.dart';
import 'package:funkwhale/core/widgets/shimmer_loading.dart';
import 'package:funkwhale/features/player/player_provider.dart';

// ── Data providers ──────────────────────────────────────────────────────

final recentAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getAlbums(
    ordering: '-creation_date',
    pageSize: 10,
  );
  return response.results;
});

final randomAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getAlbums(ordering: 'random', pageSize: 10);
  return response.results;
});

final recentTracksProvider = FutureProvider<List<Track>>((ref) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getTracks(
    ordering: '-creation_date',
    pageSize: 15,
  );
  return response.results;
});

// ── Home Screen ─────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surfaceContainer,
        onRefresh: () async {
          ref.invalidate(recentAlbumsProvider);
          ref.invalidate(randomAlbumsProvider);
          ref.invalidate(recentTracksProvider);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Top safe area padding
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),

            // Greeting header with subtle gradient background
            SliverToBoxAdapter(child: _GreetingHeader()),

            // Recently Added albums
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Recently Added'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _AlbumCarousel(provider: recentAlbumsProvider),
            ),

            // Random Picks albums
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'Random Picks'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _AlbumCarousel(provider: randomAlbumsProvider),
            ),

            // New Tracks vertical list
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(
              child: _SectionHeader(title: 'New Tracks'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const _TrackListSection(),

            // Bottom padding for mini player clearance
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ── Greeting Header ─────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = _getGreeting();

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.subtleFade),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Discover something new',
                  style: TextStyle(
                    color: AppTheme.onBackgroundMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: AppTheme.onBackgroundMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Section Header ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Album Carousel (horizontal scroll) ──────────────────────────────────

class _AlbumCarousel extends ConsumerWidget {
  final FutureProvider<List<Album>> provider;

  const _AlbumCarousel({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(provider);

    return albumsAsync.when(
      loading: () => const ShimmerGrid(itemCount: 5, itemSize: 150),
      error:
          (error, _) => _ErrorCard(
            message: 'Could not load albums',
            onRetry: () => ref.invalidate(provider),
          ),
      data: (albums) {
        if (albums.isEmpty) {
          return const SizedBox(
            height: 150,
            child: Center(
              child: Text(
                'No albums found',
                style: TextStyle(color: AppTheme.onBackgroundSubtle),
              ),
            ),
          );
        }

        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < albums.length - 1 ? 14 : 0,
                ),
                child: _AlbumCard(album: albums[index]),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Single Album Card ───────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final Album album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 150;
    const double artSize = 150;

    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album art with gradient overlay
            Stack(
              children: [
                CoverArtWidget(
                  imageUrl: album.coverUrl,
                  size: artSize,
                  borderRadius: 10,
                  shadow: BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ),
                // Subtle gradient overlay on the bottom of the art
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: artSize * 0.45,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Album title
            Text(
              album.title,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Artist name
            Text(
              album.artist?.name ?? 'Unknown Artist',
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tracks Vertical List Section ────────────────────────────────────────

class _TrackListSection extends ConsumerWidget {
  const _TrackListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(recentTracksProvider);

    return tracksAsync.when(
      loading:
          () => SliverToBoxAdapter(
            child: SizedBox(height: 400, child: ShimmerList(itemCount: 6)),
          ),
      error:
          (error, _) => SliverToBoxAdapter(
            child: _ErrorCard(
              message: 'Could not load tracks',
              onRetry: () => ref.invalidate(recentTracksProvider),
            ),
          ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No tracks found',
                  style: TextStyle(color: AppTheme.onBackgroundSubtle),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final track = tracks[index];
            return TrackListTile(
              track: track,
              onTap:
                  () => ref
                      .read(playerProvider.notifier)
                      .playTracks(tracks, startIndex: index),
            );
          }, childCount: tracks.length),
        );
      },
    );
  }
}

// ── Error Card with Retry ───────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: AppTheme.error.withValues(alpha: 0.7),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
