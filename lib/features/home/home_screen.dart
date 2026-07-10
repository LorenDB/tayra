import 'dart:ui' as ui;

import 'package:tayra/core/analytics/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/layout/responsive.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/album_card.dart';
import 'package:tayra/core/widgets/content_section_header.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/player/player_provider.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart'
    show WeeklyStats;
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/core/widgets/app_shell.dart';

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
  final response = await api.getListenings(ordering: '-created', pageSize: 15);
  // Deduplicate tracks by ID, preserving listening order
  final seen = <int>{};
  return response.results
      .where((l) => seen.add(l.track.id))
      .map((l) => l.track)
      .toList();
});

// ── Home Screen ─────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = Responsive.isExpanded(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AppRefreshIndicator(
        onRefresh: () async {
          // Perform a network refresh via the cached API with forceRefresh=true
          // so the cache is updated from the network (pull-to-refresh should
          // fetch fresh data, not just return a cached hit).
          final api = ref.read(cachedFunkwhaleApiProvider);
          try {
            await Future.wait([
              api.getAlbums(
                ordering: '-creation_date',
                pageSize: 10,
                forceRefresh: true,
              ),
              api.getAlbums(
                ordering: 'random',
                pageSize: 10,
                forceRefresh: true,
              ),
              api.getListenings(
                ordering: '-created',
                pageSize: 15,
                forceRefresh: true,
              ),
            ]);
          } catch (_) {
            // Ignore network errors here; providers will fall back to stale
            // cache or show error states. We still invalidate so UI updates.
          }

          // Invalidate the providers so UI picks up the fresh cache data.
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
            // Desktop: greeting in left column, banner in right column
            if (isWide)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _GreetingHeader(horizontalPadding: 0)),
                      const SizedBox(width: 24),
                      Expanded(child: _YearReviewBannerPadded(isWide: isWide)),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(child: _GreetingHeader()),

            // Year in Review seasonal banner (Dec 15–31 or when force-shown)
            // Mobile only - desktop shows it in the header row above
            if (!isWide) const SliverToBoxAdapter(child: _YearReviewBanner()),

            // Weekly listening stats
            const SliverToBoxAdapter(child: _WeeklyStatsSection()),

            // ── Desktop: album grids side by side ──
            if (isWide) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _AlbumGridSection(
                          title: 'Recently Added',
                          provider: recentAlbumsProvider,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _AlbumGridSection(
                          title: 'Random Picks',
                          provider: randomAlbumsProvider,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // ── Mobile: horizontal carousels ──
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              const SliverToBoxAdapter(
                child: ContentSectionHeader(title: 'Recently Added'),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _AlbumCarousel(provider: recentAlbumsProvider),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
              const SliverToBoxAdapter(
                child: ContentSectionHeader(title: 'Random Picks'),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _AlbumCarousel(provider: randomAlbumsProvider),
              ),
            ],

            // Overflow nav destinations (mobile only, when tabs are unpinned)
            if (!isWide) const SliverToBoxAdapter(child: _OverflowNavSection()),

            // Recently Played Tracks vertical list
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            const SliverToBoxAdapter(
              child: ContentSectionHeader(title: 'Recently Played Tracks'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const _TrackListSection(),

            // Bottom padding for mini player clearance
            SliverToBoxAdapter(child: SizedBox(height: isWide ? 32 : 120)),
          ],
        ),
      ),
    );
  }
}

// ── Greeting Header ─────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader({this.horizontalPadding = 20});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = _getGreeting();

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.subtleFade),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        20,
        horizontalPadding,
        16,
      ),
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
          // Action buttons (hidden on desktop - available in nav rail)
          if (!Responsive.useSideNavigation(context)) ...[
            // Search button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => SearchScreen.show(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.onBackgroundMuted,
                    size: 20,
                  ),
                ),
              ),
            ),
            // Settings button
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

// ── Album Carousel (horizontal scroll) ──────────────────────────────────

class _AlbumCarousel extends ConsumerWidget {
  final FutureProvider<List<Album>> provider;

  const _AlbumCarousel({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(provider);
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final offlineAlbumIdsAsync = ref.watch(offlineAlbumIdsProvider);

    return albumsAsync.when(
      loading: () => const ShimmerGrid(itemCount: 5, itemSize: 150),
      error:
          (error, _) => _ErrorCard(
            message: 'Could not load albums',
            onRetry: () => ref.invalidate(provider),
          ),
      data: (albums) {
        final displayAlbums =
            offlineFilterActive
                ? offlineAlbumIdsAsync.when(
                  data:
                      (offlineIds) =>
                          albums
                              .where((a) => offlineIds.contains(a.id))
                              .toList(),
                  loading: () => albums,
                  error: (_, e) => albums,
                )
                : albums;

        if (displayAlbums.isEmpty) {
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

        // itemExtent = card width + gap so the viewport can skip measure.
        const cardWidth = 150.0;
        const gap = 14.0;
        return SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemExtent: cardWidth + gap,
            itemCount: displayAlbums.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: gap),
                child: RepaintBoundary(
                  child: AlbumCard(
                    album: displayAlbums[index],
                    onTap:
                        () => context.push('/album/${displayAlbums[index].id}'),
                    width: cardWidth,
                    // Shadows are costly while scrolling carousels.
                    showShadow: false,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Album Grid Section (desktop) ────────────────────────────────────────

class _AlbumGridSection extends ConsumerWidget {
  final String title;
  final FutureProvider<List<Album>> provider;

  const _AlbumGridSection({required this.title, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(provider);
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final offlineAlbumIdsAsync = ref.watch(offlineAlbumIdsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        albumsAsync.when(
          loading:
              () => const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
          error:
              (error, _) => _ErrorCard(
                message: 'Could not load albums',
                onRetry: () => ref.invalidate(provider),
              ),
          data: (albums) {
            final displayAlbums =
                offlineFilterActive
                    ? offlineAlbumIdsAsync.when(
                      data:
                          (offlineIds) =>
                              albums
                                  .where((a) => offlineIds.contains(a.id))
                                  .toList(),
                      loading: () => albums,
                      error: (_, e) => albums,
                    )
                    : albums;

            if (displayAlbums.isEmpty) {
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

            // Use a LayoutBuilder to rely on the actual incoming width and
            // defensively handle very small or unusual constraints that can
            // occur when the sidebar collapses or during breakpoint
            // transitions. This avoids producing negative BoxConstraints.
            // Constrain this section to the available width computed from
            // MediaQuery to avoid malformed constraints during sidebar
            // collapse / breakpoint transitions. Render a shrink-wrapped
            // GridView so Flutter provides normalized constraints to grid
            // children and avoids negative min-widths.
            final mqWidth = MediaQuery.sizeOf(context).width;
            final navWidth = Responsive.useSideNavigation(context) ? 80.0 : 0.0;
            const horizontalPadding = 20.0; // parent Padding symmetric
            final totalAvailable = (mqWidth - navWidth - horizontalPadding * 2)
                .clamp(0.0, double.infinity);
            final sectionAvailable = ((totalAvailable - 24) / 2).clamp(
              0.0,
              totalAvailable,
            );

            const double minItemWidth = 140.0;
            const double spacing = 14.0;
            final rawColumns =
                ((sectionAvailable + spacing) / (minItemWidth + spacing))
                    .floor();
            final columns = rawColumns.clamp(1, 5);

            // Manual row layout instead of shrinkWrap GridView (which lays
            // out all children eagerly inside the outer CustomScrollView).
            final rowCount = (displayAlbums.length / columns).ceil();
            final rows = <Widget>[];
            for (var r = 0; r < rowCount; r++) {
              final cells = <Widget>[];
              for (var c = 0; c < columns; c++) {
                final index = r * columns + c;
                if (c > 0) cells.add(const SizedBox(width: spacing));
                if (index < displayAlbums.length) {
                  final album = displayAlbums[index];
                  cells.add(
                    Expanded(
                      child: RepaintBoundary(
                        child: AlbumCard(
                          album: album,
                          onTap: () => context.push('/album/${album.id}'),
                          showShadow: false,
                        ),
                      ),
                    ),
                  );
                } else {
                  cells.add(const Expanded(child: SizedBox.shrink()));
                }
              }
              rows.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cells,
                ),
              );
              if (r < rowCount - 1) {
                rows.add(const SizedBox(height: 16));
              }
            }

            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 0,
                maxWidth: sectionAvailable,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── Tracks Vertical List Section ────────────────────────────────────────

class _TrackListSection extends ConsumerWidget {
  const _TrackListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(recentTracksProvider);
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final offlineTrackIds =
        offlineFilterActive ? ref.watch(offlineTrackIdsProvider) : null;

    return tracksAsync.when(
      loading:
          () => SliverToBoxAdapter(
            child: SizedBox(height: 400, child: ShimmerList(itemCount: 6)),
          ),
      error:
          (error, _) => SliverToBoxAdapter(
            child: _ErrorCard(
              message: 'Could not load recent listens',
              onRetry: () => ref.invalidate(recentTracksProvider),
            ),
          ),
      data: (tracks) {
        final displayTracks =
            offlineTrackIds != null
                ? tracks.where((t) => offlineTrackIds.contains(t.id)).toList()
                : tracks;

        if (displayTracks.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No recent listens',
                  style: TextStyle(color: AppTheme.onBackgroundSubtle),
                ),
              ),
            ),
          );
        }

        return SliverFixedExtentList(
          itemExtent: kTrackListTileExtent,
          delegate: SliverChildBuilderDelegate((context, index) {
            final track = displayTracks[index];
            return RepaintBoundary(
              child: TrackListTile(
                track: track,
                onTap:
                    () => ref
                        .read(playerProvider.notifier)
                        .playTracks(
                          displayTracks,
                          startIndex: index,
                          source: 'recent_listenings',
                        ),
              ),
            );
          }, childCount: displayTracks.length),
        );
      },
    );
  }
}

// ── Year Review Banner ───────────────────────────────────────────────

class _YearReviewBanner extends ConsumerStatefulWidget {
  const _YearReviewBanner({this.horizontalPadding = 16});

  final double horizontalPadding;

  @override
  ConsumerState<_YearReviewBanner> createState() => _YearReviewBannerState();
}

class _YearReviewBannerState extends ConsumerState<_YearReviewBanner>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  // Drive the shader without setState — a full rebuild every frame was the
  // main source of home-page scroll hitch near the top of the screen.
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier(0.0);

  // Darkened gradient colours for better contrast against white text
  static const _colorA = Color(0xFF4C45B2); // darkened purple (was 0xFF6C63FF)
  static const _colorB = Color(0xFF009477); // darkened teal   (was 0xFF00D4AA)

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _elapsedSeconds.value = elapsed.inMicroseconds / 1e6;
    });
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/ripple.frag',
      );
      if (mounted) {
        setState(() => _shader = program.fragmentShader());
        _ticker.start();
      }
    } catch (_) {
      // Shader failed to load — banner falls back to plain gradient
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsedSeconds.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(yearReviewBannerVisibleProvider);
    if (!visible) {
      if (_ticker.isActive) _ticker.stop();
      return const SizedBox.shrink();
    }
    if (_shader != null && !_ticker.isActive) _ticker.start();

    final shader = _shader;

    // RepaintBoundary keeps the continuous shader paint off the home
    // CustomScrollView's layer so scrolling albums/tracks isn't dirtied.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        12,
        widget.horizontalPadding,
        4,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Animated backdrop only — content row below is static.
              Positioned.fill(
                child:
                    shader != null
                        ? ListenableBuilder(
                          listenable: _elapsedSeconds,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _RipplePainter(
                                shader: shader,
                                time: _elapsedSeconds.value,
                                colorA: _colorA,
                                colorB: _colorB,
                              ),
                            );
                          },
                        )
                        : const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_colorA, _colorB],
                            ),
                          ),
                        ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Analytics.track('year_review_banner_tapped');

                    try {
                      await ref
                          .read(yearReviewBannerVisibleProvider.notifier)
                          .dismiss();
                    } catch (_) {}

                    if (!context.mounted) return;
                    context.pushNamed(
                      'year_review_detail',
                      pathParameters: {'year': '${DateTime.now().year}'},
                      extra: {'startInStory': true},
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.white.withValues(alpha: 0.1),
                  highlightColor: Colors.white.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Year in Review is ready',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'See your top tracks, artists & more',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Analytics.track('year_review_banner_dismissed');
                            ref
                                .read(yearReviewBannerVisibleProvider.notifier)
                                .dismiss();
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Year Review Banner Padded Wrapper ───────────────────────────────────

class _YearReviewBannerPadded extends StatelessWidget {
  const _YearReviewBannerPadded({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return _YearReviewBanner(horizontalPadding: isWide ? 0 : 16);
  }
}

// ── Ripple shader painter ────────────────────────────────────────────

class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.shader,
    required this.time,
    required this.colorA,
    required this.colorB,
  });

  final ui.FragmentShader shader;
  final double time;
  final Color colorA;
  final Color colorB;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniforms must match the order declared in ripple.frag:
    //   0: uTime       (float)
    //   1,2: uResolution (vec2 → two floats)
    //   3,4,5,6: uColorA   (vec4 → four floats, r g b a)
    //   7,8,9,10: uColorB  (vec4 → four floats, r g b a)
    shader
      ..setFloat(0, time)
      ..setFloat(1, size.width)
      ..setFloat(2, size.height)
      ..setFloat(3, colorA.r)
      ..setFloat(4, colorA.g)
      ..setFloat(5, colorA.b)
      ..setFloat(6, colorA.a)
      ..setFloat(7, colorB.r)
      ..setFloat(8, colorB.g)
      ..setFloat(9, colorB.b)
      ..setFloat(10, colorB.a);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.time != time || old.shader != shader;
}

// ── Overflow Nav Section ────────────────────────────────────────────────

/// Shows nav destinations that aren't pinned to the mobile nav bar.
/// Hidden on desktop (side rail shows all destinations).
class _OverflowNavSection extends ConsumerWidget {
  const _OverflowNavSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedIndices = ref.watch(
      settingsProvider.select((s) => s.mobilePinnedTabIndices),
    );

    // All non-home tab indices (1–6) that aren't pinned.
    final overflowIndices =
        List.generate(
          AppShell.tabs.length - 1,
          (i) => i + 1,
        ).where((i) => !pinnedIndices.contains(i)).toList();

    if (overflowIndices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Text(
            'Explore more',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (int pos = 0; pos < overflowIndices.length; pos++) ...[
                if (pos > 0) const SizedBox(width: 12),
                Expanded(
                  child: _OverflowNavTile(tabIndex: overflowIndices[pos]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverflowNavTile extends StatelessWidget {
  final int tabIndex;

  const _OverflowNavTile({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final tab = AppShell.tabs[tabIndex];
    final path = AppShell.paths[tabIndex];

    return Material(
      color: AppTheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, color: AppTheme.onBackgroundSubtle, size: 24),
              const SizedBox(height: 6),
              Text(
                tab.label,
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Weekly Stats Section ────────────────────────────────────────────────

class _WeeklyStatsSection extends ConsumerStatefulWidget {
  const _WeeklyStatsSection();

  @override
  ConsumerState<_WeeklyStatsSection> createState() =>
      _WeeklyStatsSectionState();
}

class _WeeklyStatsSectionState extends ConsumerState<_WeeklyStatsSection> {
  bool _markedShown = false;

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(saturdayStatsVisibleProvider);
    if (!visible) return const SizedBox.shrink();

    final statsAsync = ref.watch(weeklyStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (stats) {
        if (!stats.hasData) return const SizedBox.shrink();

        if (!_markedShown) {
          _markedShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(saturdayStatsVisibleProvider.notifier).markShown();
          });
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      icon: Icons.headphones_rounded,
                      value: '${stats.playCount}',
                      label: stats.playCount == 1 ? 'play' : 'plays',
                      accentColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      icon: Icons.timer_rounded,
                      value: stats.formattedTime,
                      label: 'listened',
                      accentColor: AppTheme.secondary,
                    ),
                  ),
                  if (stats.topArtistName != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatChip(
                        icon: Icons.person_rounded,
                        value: stats.topArtistName!,
                        label: 'top artist',
                        accentColor: const Color(0xFFFF9A3C),
                      ),
                    ),
                  ],
                ],
              ),
              if (stats.topTrackTitle != null) ...[
                const SizedBox(height: 10),
                _TopTrackRow(stats: stats),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accentColor;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTrackRow extends StatelessWidget {
  const _TopTrackRow({required this.stats});

  final WeeklyStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.music_note_rounded,
            color: AppTheme.onBackgroundSubtle,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.topTrackTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stats.topTrackArtist != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    stats.topTrackArtist!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'top track',
            style: TextStyle(
              color: AppTheme.onBackgroundSubtle,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
