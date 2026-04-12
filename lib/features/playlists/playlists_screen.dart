import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/connectivity/connectivity_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/core/layout/responsive.dart';

final playlistsProvider = FutureProvider.autoDispose<List<Playlist>>((
  ref,
) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getPlaylists(scope: 'me');
  return response.results;
});

// ── Playlists Screen ────────────────────────────────────────────────────

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final offlineFilterActive = ref.watch(offlineFilterActiveProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Playlists',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!Responsive.useSideNavigation(context))
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => SearchScreen.show(context),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.onBackground),
            onPressed: () => _showCreatePlaylistDialog(context, ref),
          ),
        ],
      ),
      body: playlistsAsync.when(
        loading: () => const ShimmerList(itemCount: 6, itemHeight: 80),
        error:
            (error, _) => InlineErrorState(
              message: 'Could not load playlists',
              onRetry: () => ref.invalidate(playlistsProvider),
            ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              subtitle: 'Create a playlist to organize your music',
              action: ElevatedButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context, ref),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create Playlist'),
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surfaceContainer,
            onRefresh: () async {
              final api = ref.read(cachedFunkwhaleApiProvider);
              try {
                await api.getPlaylists(scope: 'me', forceRefresh: true);
              } catch (_) {
                // If the network request fails, we still invalidate so the
                // provider can serve stale cached data rather than hanging.
              }
              ref.invalidate(playlistsProvider);
            },
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: playlists.length + (offlineFilterActive ? 1 : 0),
              itemBuilder: (context, index) {
                if (offlineFilterActive && index == 0) {
                  return _OfflinePlaylistsNote();
                }
                final playlistIndex = offlineFilterActive ? index - 1 : index;
                return _PlaylistCard(playlist: playlists[playlistIndex]);
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => _CreatePlaylistDialog(
            onCreated: () => ref.invalidate(playlistsProvider),
            ref: ref,
          ),
    );
  }
}

// ── Offline note banner ─────────────────────────────────────────────────

class _OfflinePlaylistsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppTheme.primary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline filter is active. Only downloaded tracks inside '
              'each playlist will be playable.',
              style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Playlist Card ───────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/playlists/${playlist.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Mosaic cover art (up to 4 album covers)
                _PlaylistMosaic(covers: playlist.albumCovers, size: 64),
                const SizedBox(width: 14),
                // Playlist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildSubtitle(),
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Privacy badge
                if (playlist.privacyLevel != null &&
                    playlist.privacyLevel != 'me')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      playlist.privacyLevel == 'everyone'
                          ? Icons.public_rounded
                          : Icons.group_rounded,
                      color: AppTheme.onBackgroundSubtle,
                      size: 16,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    parts.add(pluralizeTrack(playlist.tracksCount));
    if (playlist.duration != null && playlist.duration! > 0) {
      parts.add(formatTotalDuration(playlist.duration!));
    }
    return parts.join(' · ');
  }
}

// ── Playlist Mosaic (up to 4 covers) ────────────────────────────────────

class _PlaylistMosaic extends StatelessWidget {
  final List<String> covers;
  final double size;

  const _PlaylistMosaic({required this.covers, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          covers.isEmpty
              ? Center(
                child: Icon(
                  Icons.queue_music_rounded,
                  color: AppTheme.onBackgroundSubtle,
                  size: size * 0.4,
                ),
              )
              : covers.length == 1
              ? _coverImage(covers[0], size, size)
              : covers.length < 4
              ? _coverImage(covers[0], size, size)
              : _buildMosaic(),
    );
  }

  Widget _buildMosaic() {
    final halfSize = size / 2;
    return Column(
      children: [
        Row(
          children: [
            _coverImage(covers[0], halfSize, halfSize),
            _coverImage(covers[1], halfSize, halfSize),
          ],
        ),
        Row(
          children: [
            _coverImage(covers[2], halfSize, halfSize),
            _coverImage(covers[3], halfSize, halfSize),
          ],
        ),
      ],
    );
  }

  Widget _coverImage(String url, double w, double h) {
    return CachedNetworkImage(
      imageUrl: url,
      width: w,
      height: h,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => Container(
            width: w,
            height: h,
            color: AppTheme.surfaceContainerHigh,
          ),
      errorWidget:
          (context, url, error) => Container(
            width: w,
            height: h,
            color: AppTheme.surfaceContainerHigh,
            child: Icon(
              Icons.album_rounded,
              color: AppTheme.onBackgroundSubtle,
              size: w * 0.4,
            ),
          ),
    );
  }
}

// ── Create Playlist Dialog ──────────────────────────────────────────────

class _CreatePlaylistDialog extends StatefulWidget {
  final VoidCallback onCreated;
  final WidgetRef ref;

  const _CreatePlaylistDialog({required this.onCreated, required this.ref});

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final api = widget.ref.read(cachedFunkwhaleApiProvider);
      await api.createPlaylist(name: name);
      if (!mounted) return;
      try {
        Aptabase.instance.trackEvent('playlist_created');
      } catch (_) {}
      widget.onCreated();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to create playlist';
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'New Playlist',
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              filled: true,
              fillColor: AppTheme.surfaceContainer,
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.onBackgroundMuted),
          ),
        ),
        TextButton(
          onPressed: _isCreating ? null : _create,
          child:
              _isCreating
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                  : const Text(
                    'Create',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ],
    );
  }
}
