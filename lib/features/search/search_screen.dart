import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/cache/cache_provider.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/album_card.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/track_list_tile.dart';
import 'package:tayra/features/player/player_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static Future<void> show(BuildContext context) {
    // Navigate to a full-screen search route so search appears as a page
    // (works consistently on mobile and desktop).
    return Future<void>.microtask(() => context.push('/search'));
  }

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

    Aptabase.instance.trackEvent('search', {'query_length': query.length});

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
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
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: Column(
        children: [_buildSearchField(), Expanded(child: _buildResults())],
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

  Widget _buildResults() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    // Error state
    if (_error != null) {
      return InlineErrorState(
        message: _error!,
        onRetry: () => _performSearch(_lastQuery),
      );
    }

    // Empty query - show initial state
    if (_lastQuery.isEmpty || _result == null) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for music',
        subtitle: 'Find artists, albums, tracks, and tags',
        iconSize: 72,
      );
    }

    // No results
    if (_result!.isEmpty) {
      return EmptyState(
        icon: Icons.music_off_rounded,
        title: 'No results for "$_lastQuery"',
        subtitle: 'Try a different search term',
        iconSize: 56,
        titleFontSize: 15,
      );
    }

    // Results — apply offline filter when active
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);
    final offlineTrackIds =
        offlineFilterActive
            ? ref
                .watch(offlineTrackIdsProvider)
                .maybeWhen(data: (ids) => ids, orElse: () => const <int>{})
            : null;
    final offlineAlbumIds =
        offlineFilterActive
            ? ref
                .watch(offlineAlbumIdsProvider)
                .maybeWhen(data: (ids) => ids, orElse: () => const <int>{})
            : null;
    final offlineArtistIds =
        offlineFilterActive
            ? ref
                .watch(offlineArtistIdsProvider)
                .maybeWhen(data: (ids) => ids, orElse: () => const <int>{})
            : null;

    final artists =
        offlineArtistIds != null
            ? _result!.artists
                .where((a) => offlineArtistIds.contains(a.id))
                .toList()
            : _result!.artists;
    final albums =
        offlineAlbumIds != null
            ? _result!.albums
                .where((a) => offlineAlbumIds.contains(a.id))
                .toList()
            : _result!.albums;
    final tracks =
        offlineTrackIds != null
            ? _result!.tracks
                .where((t) => offlineTrackIds.contains(t.id))
                .toList()
            : _result!.tracks;

    final hasAnyResults =
        artists.isNotEmpty ||
        albums.isNotEmpty ||
        tracks.isNotEmpty ||
        _result!.tags.isNotEmpty;

    if (offlineFilterActive && !hasAnyResults) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No offline results for "$_lastQuery"',
        subtitle: 'Download content to search while offline',
        iconSize: 56,
        titleFontSize: 15,
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        if (offlineFilterActive && _result!.tags.isNotEmpty)
          const _OfflineSearchNote(),
        if (artists.isNotEmpty) _buildArtistsSection(artists),
        if (albums.isNotEmpty) _buildAlbumsSection(albums),
        if (tracks.isNotEmpty) _buildTracksSection(tracks),
        if (_result!.tags.isNotEmpty) _buildTagsSection(_result!.tags),
      ],
    );
  }

  // ── Artists section: horizontal chips/cards ───────────────────────────

  Widget _buildArtistsSection(List<Artist> artists) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Artists', topPadding: 16),
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
        const _SectionHeader(label: 'Albums'),
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
                child: AlbumCard(
                  album: album,
                  onTap: () => context.push('/search/album/${album.id}'),
                  width: 140,
                  showGradientOverlay: false,
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
        const _SectionHeader(label: 'Tracks', bottomPadding: 8),
        ...tracks.asMap().entries.map((entry) {
          final index = entry.key;
          final track = entry.value;
          return TrackListTile(
            track: track,
            onTap: () {
              ref
                  .read(playerProvider.notifier)
                  .playTracks(
                    tracks,
                    startIndex: index,
                    source: 'search_results_from_track',
                  );
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
        const _SectionHeader(label: 'Tags'),
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

// ── Offline search note ─────────────────────────────────────────────────

class _OfflineSearchNote extends StatelessWidget {
  const _OfflineSearchNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 14,
            color: AppTheme.onBackgroundMuted,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Showing offline results only. Tags always search the server.',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
            ),
          ),
        ],
      ),
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

// ── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  /// Top padding. Artists use 16; all other sections use 20 (default).
  final double topPadding;

  /// Bottom padding. Tracks use 8; all other sections use 12 (default).
  final double bottomPadding;

  const _SectionHeader({
    required this.label,
    this.topPadding = 20,
    this.bottomPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, bottomPadding),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
