import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:funkwhale/core/api/api_repository.dart';
import 'package:funkwhale/core/api/models.dart';
import 'package:funkwhale/core/theme/app_theme.dart';
import 'package:funkwhale/core/widgets/cover_art.dart';
import 'package:funkwhale/core/widgets/track_list_tile.dart';
import 'package:funkwhale/features/player/player_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  SearchResult? _result;
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _result = null;
        _isLoading = false;
        _error = null;
        _lastQuery = '';
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(funkwhaleApiProvider);
      final result = await api.search(query);
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
        _lastQuery = query;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [_buildSearchField(), Expanded(child: _buildBody())],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.onBackground, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search artists, albums, tracks...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppTheme.onBackgroundSubtle,
          ),
          suffixIcon:
              _controller.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: AppTheme.onBackgroundSubtle,
                      size: 20,
                    ),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  )
                  : null,
        ),
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (query) {
          _debounce?.cancel();
          final trimmed = query.trim();
          if (trimmed.isNotEmpty) _performSearch(trimmed);
        },
      ),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
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
            TextButton(
              onPressed: () => _performSearch(_lastQuery),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Empty query - show initial state
    if (_lastQuery.isEmpty || _result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
              size: 72,
            ),
            const SizedBox(height: 16),
            const Text(
              'Search for music',
              style: TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find artists, albums, tracks, and tags',
              style: TextStyle(
                color: AppTheme.onBackgroundSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // No results
    if (_result!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              color: AppTheme.onBackgroundSubtle.withValues(alpha: 0.5),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_lastQuery"',
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different search term',
              style: TextStyle(
                color: AppTheme.onBackgroundSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Results
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (_result!.artists.isNotEmpty) _buildArtistsSection(_result!.artists),
        if (_result!.albums.isNotEmpty) _buildAlbumsSection(_result!.albums),
        if (_result!.tracks.isNotEmpty) _buildTracksSection(_result!.tracks),
        if (_result!.tags.isNotEmpty) _buildTagsSection(_result!.tags),
      ],
    );
  }

  // ── Artists section: horizontal chips/cards ───────────────────────────

  Widget _buildArtistsSection(List<Artist> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Artists',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < artists.length - 1 ? 12 : 0,
                ),
                child: _ArtistChip(
                  artist: artist,
                  onTap: () => context.push('/search/artist/${artist.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Albums section: horizontal scroll cards ───────────────────────────

  Widget _buildAlbumsSection(List<Album> albums) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Albums',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < albums.length - 1 ? 14 : 0,
                ),
                child: _AlbumCard(
                  album: album,
                  onTap: () => context.push('/search/album/${album.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tracks section: vertical list ─────────────────────────────────────

  Widget _buildTracksSection(List<Track> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Tracks',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...tracks.asMap().entries.map((entry) {
          final index = entry.key;
          final track = entry.value;
          return TrackListTile(
            track: track,
            onTap: () {
              ref
                  .read(playerProvider.notifier)
                  .playTracks(tracks, startIndex: index);
            },
          );
        }),
      ],
    );
  }

  // ── Tags section: wrap of chips ───────────────────────────────────────

  Widget _buildTagsSection(List<Tag> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Tags',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                tags.map((tag) {
                  return ActionChip(
                    label: Text(
                      '#${tag.name}',
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: AppTheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    onPressed: () {
                      // Search for the tag name
                      _controller.text = tag.name;
                      _onQueryChanged(tag.name);
                    },
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Artist Chip ─────────────────────────────────────────────────────────

class _ArtistChip extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;

  const _ArtistChip({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverArtWidget(
              imageUrl: artist.coverUrl,
              size: 64,
              borderRadius: 32,
              placeholderIcon: Icons.person_rounded,
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              style: const TextStyle(
                color: AppTheme.onBackground,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Album Card ──────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 140;
    const double artSize = 140;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArtWidget(
              imageUrl: album.coverUrl,
              size: artSize,
              borderRadius: 10,
              shadow: BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ),
            const SizedBox(height: 8),
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
            Text(
              album.artist?.name ?? 'Unknown Artist',
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 12,
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
