import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';

// ── Month name helper ───────────────────────────────────────────────────

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// ── Year Review Screen ──────────────────────────────────────────────────

class YearReviewScreen extends ConsumerStatefulWidget {
  final int year;

  const YearReviewScreen({super.key, required this.year});

  @override
  ConsumerState<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends ConsumerState<YearReviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  ui.FragmentProgram? _magicProgram;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/magic_sparks.frag',
      );
      if (mounted) {
        setState(() => _magicProgram = program);
      }
    } catch (e) {
      debugPrint('Error loading shader: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(yearReviewProvider(widget.year));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: statsAsync.when(
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      // Surface the actual error message to help debugging.
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        () => ref.invalidate(yearReviewProvider(widget.year)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        data: (stats) {
          if (stats.isEmpty) {
            return _EmptyState(year: widget.year);
          }
          return _ReviewContent(
            stats: stats,
            animController: _animController,
            magicProgram: _magicProgram,
          );
        },
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final int year;

  const _EmptyState({required this.year});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _AppBarRow(title: '$year'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_off_rounded,
                      color: AppTheme.onBackgroundSubtle,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No listening data for $year',
                      style: const TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start playing music to build your year in review.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.onBackgroundSubtle,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App bar row ─────────────────────────────────────────────────────────

class _AppBarRow extends StatelessWidget {
  final String title;

  const _AppBarRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppTheme.onBackground,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review content ──────────────────────────────────────────────────────

class _ReviewContent extends StatelessWidget {
  final YearReviewStats stats;
  final AnimationController animController;
  final ui.FragmentProgram? magicProgram;

  const _ReviewContent({
    required this.stats,
    required this.animController,
    this.magicProgram,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _AppBarRow(title: 'Year in Review')),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Hero card with year + total stats
          SliverToBoxAdapter(
            child: _HeroCard(
              stats: stats,
              animController: animController,
              magicProgram: magicProgram,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Stats grid
          SliverToBoxAdapter(child: _StatsGrid(stats: stats)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Top track spotlight
          if (stats.topTrack != null) ...[
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'Your #1 Track'),
            ),
            SliverToBoxAdapter(
              child: _SpotlightCard(
                item: stats.topTrack!,
                icon: Icons.music_note_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF3B35CC)],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Top artist spotlight
          if (stats.topArtist != null) ...[
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'Your #1 Artist'),
            ),
            SliverToBoxAdapter(
              child: _SpotlightCard(
                item: stats.topArtist!,
                icon: Icons.person_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00D4AA), Color(0xFF009977)],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],

          // Top album spotlight
          if (stats.topAlbum != null) ...[
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'Your #1 Album'),
            ),
            SliverToBoxAdapter(
              child: _SpotlightCard(
                item: stats.topAlbum!,
                icon: Icons.album_rounded,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B6B), Color(0xFFCC3535)],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],

          // Monthly chart
          const SliverToBoxAdapter(
            child: _SectionTitle(title: 'Month by Month'),
          ),
          SliverToBoxAdapter(
            child: _MonthlyChart(monthly: stats.monthlyBreakdown),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // Top tracks list
          if (stats.topTracks.length > 1) ...[
            const SliverToBoxAdapter(child: _SectionTitle(title: 'Top Tracks')),
            SliverToBoxAdapter(
              child: _RankedList(items: stats.topTracks, type: 'track'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],

          // Top artists list
          if (stats.topArtists.length > 1) ...[
            const SliverToBoxAdapter(
              child: _SectionTitle(title: 'Top Artists'),
            ),
            SliverToBoxAdapter(
              child: _RankedList(items: stats.topArtists, type: 'artist'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],

          // Top albums list
          if (stats.topAlbums.length > 1) ...[
            const SliverToBoxAdapter(child: _SectionTitle(title: 'Top Albums')),
            SliverToBoxAdapter(
              child: _RankedList(items: stats.topAlbums, type: 'album'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ── Hero card ───────────────────────────────────────────────────────────

class _HeroCard extends StatefulWidget {
  final YearReviewStats stats;
  final AnimationController animController;
  final ui.FragmentProgram? magicProgram;

  const _HeroCard({
    required this.stats,
    required this.animController,
    this.magicProgram,
  });

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsedSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() {
        _elapsedSeconds = elapsed.inMicroseconds / 1e6;
      });
    });
    _checkTicker();
  }

  @override
  void didUpdateWidget(_HeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkTicker();
  }

  void _checkTicker() {
    if (widget.magicProgram != null && !_ticker.isActive) {
      _ticker.start();
    } else if (widget.magicProgram == null && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    Widget card = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.stats.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Year in Review',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.headphones_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.stats.formattedTotalTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'of listening',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );

    if (widget.magicProgram != null) {
      card = ShaderMask(
        shaderCallback: (bounds) {
          final shader = widget.magicProgram!.fragmentShader();
          // Pass physical pixels to match FlutterFragCoord()
          shader.setFloat(0, _elapsedSeconds);
          shader.setFloat(1, bounds.width * devicePixelRatio * 0.85);
          shader.setFloat(2, bounds.height * devicePixelRatio * 0.92);
          return shader;
        },
        blendMode: BlendMode.plus,
        child: card,
      );
    }

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: widget.animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: widget.animController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: card,
        ),
      ),
    );
  }
}

// ── Stats grid ──────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final YearReviewStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              value: '${stats.totalListens}',
              label: 'Listens',
              icon: Icons.play_circle_filled_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              value: '${stats.uniqueTracks}',
              label: 'Tracks',
              icon: Icons.music_note_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              value: '${stats.uniqueArtists}',
              label: 'Artists',
              icon: Icons.person_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              value: '${stats.uniqueAlbums}',
              label: 'Albums',
              icon: Icons.album_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Spotlight card (for #1 track/artist/album) ──────────────────────────

class _SpotlightCard extends StatelessWidget {
  final TopItem item;
  final IconData icon;
  final LinearGradient gradient;

  const _SpotlightCard({
    required this.item,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Cover art
            CoverArtWidget(
              imageUrl: item.coverUrl,
              size: 80,
              borderRadius: 12,
              placeholderIcon: icon,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.count} ${item.count == 1 ? 'play' : 'plays'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Monthly chart ───────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<MonthlyListens> monthly;

  const _MonthlyChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    // Find max for scaling
    final maxCount = monthly.fold<int>(
      1,
      (max, m) => m.count > max ? m.count : max,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (i) {
                final data = monthly[i];
                final fraction = data.count / maxCount;
                final isTop = data.count == maxCount && data.count > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isTop)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${data.count}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Flexible(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height:
                                data.count > 0
                                    ? (fraction * 100).clamp(4.0, 100.0)
                                    : 4.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient:
                                  data.count > 0
                                      ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppTheme.primary,
                                          AppTheme.secondary,
                                        ],
                                      )
                                      : null,
                              color:
                                  data.count == 0
                                      ? AppTheme.surfaceContainerHigh
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(12, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    _monthNames[i],
                    style: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Ranked list (top tracks/artists/albums) ─────────────────────────────

class _RankedList extends StatelessWidget {
  final List<TopItem> items;
  final String type;

  const _RankedList({required this.items, required this.type});

  IconData get _placeholderIcon {
    switch (type) {
      case 'artist':
        return Icons.person_rounded;
      case 'album':
        return Icons.album_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            _RankedItem(
              rank: i + 1,
              item: items[i],
              placeholderIcon: _placeholderIcon,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _RankedItem extends StatelessWidget {
  final int rank;
  final TopItem item;
  final IconData placeholderIcon;
  final bool isLast;

  const _RankedItem({
    required this.rank,
    required this.item,
    required this.placeholderIcon,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : const Border(
                  bottom: BorderSide(color: AppTheme.divider, width: 0.5),
                ),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                color:
                    rank <= 3 ? AppTheme.primary : AppTheme.onBackgroundSubtle,
                fontSize: rank <= 3 ? 18 : 16,
                fontWeight: rank <= 3 ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Cover art
          CoverArtWidget(
            imageUrl: item.coverUrl,
            size: 44,
            borderRadius: 8,
            placeholderIcon: placeholderIcon,
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.subtitle!,
                    style: const TextStyle(
                      color: AppTheme.onBackgroundMuted,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Play count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${item.count}',
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Year selector screen (entry point) ──────────────────────────────────

class YearReviewSelectorScreen extends ConsumerWidget {
  const YearReviewSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearsAsync = ref.watch(availableYearsProvider);
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _AppBarRow(title: 'Year in Review'),
            Expanded(
              child: yearsAsync.when(
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                error:
                    (error, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Could not load data',
                            style: TextStyle(
                              color: AppTheme.onBackgroundMuted,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => ref.invalidate(availableYearsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                data: (years) {
                  // Always show current year, even if no data yet
                  final allYears =
                      {currentYear, ...years}.toList()
                        ..sort((a, b) => b.compareTo(a));

                  if (allYears.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.music_off_rounded,
                              color: AppTheme.onBackgroundSubtle,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No listening data yet',
                              style: TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start playing music to build your year in review.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.onBackgroundSubtle,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: allYears.length,
                    itemBuilder: (context, index) {
                      final year = allYears[index];
                      final hasData = years.contains(year);
                      return _YearCard(
                        year: year,
                        isCurrent: year == currentYear,
                        hasData: hasData,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  final int year;
  final bool isCurrent;
  final bool hasData;

  const _YearCard({
    required this.year,
    required this.isCurrent,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            try {
              Aptabase.instance.trackEvent('year_review_opened', {
                'year': year,
                'is_current_year': isCurrent,
                'has_data': hasData,
              });
            } catch (_) {}
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => YearReviewScreen(year: year)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient:
                  isCurrent
                      ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1A1540), Color(0xFF0D2A2A)],
                      )
                      : null,
              color: isCurrent ? null : AppTheme.surfaceContainer,
              border:
                  isCurrent
                      ? Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      )
                      : null,
            ),
            child: Row(
              children: [
                // Year
                Text(
                  '$year',
                  style: TextStyle(
                    color: isCurrent ? AppTheme.primary : AppTheme.onBackground,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrent ? 'This Year' : 'Year in Review',
                        style: const TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? isCurrent
                                ? 'In progress - see your stats so far'
                                : 'View your listening recap'
                            : 'No data yet',
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color:
                      isCurrent
                          ? AppTheme.primary
                          : AppTheme.onBackgroundSubtle,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
