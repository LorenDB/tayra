import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';

/// Shows a bottom sheet listing user playlists to add one or more tracks to.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref, {
  required List<int> trackIds,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _AddToPlaylistSheet(trackIds: trackIds);
    },
  );
}

class _AddToPlaylistSheet extends ConsumerStatefulWidget {
  final List<int> trackIds;

  const _AddToPlaylistSheet({required this.trackIds});

  @override
  ConsumerState<_AddToPlaylistSheet> createState() =>
      _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<_AddToPlaylistSheet> {
  bool _isCreating = false;
  int? _addingToPlaylistId;
  String? _successMessage;

  @override
  Widget build(BuildContext context) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.onBackgroundSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                const Text(
                  'Add to Playlist',
                  style: TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: AppTheme.onBackgroundMuted,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Success message
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(color: AppTheme.divider, height: 1),

          // New Playlist button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isCreating ? null : () => _showCreateDialog(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'New Playlist',
                      style: TextStyle(
                        color: AppTheme.onBackground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(color: AppTheme.divider, height: 1),

          // Playlist list
          Flexible(
            child: playlistsAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
              error:
                  (_, __) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Could not load playlists',
                        style: TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              data: (playlists) {
                if (playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No playlists yet.\nCreate one above!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.onBackgroundSubtle,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final isAdding = _addingToPlaylistId == playlist.id;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAdding ? null : () => _addToPlaylist(playlist),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Playlist icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.queue_music_rounded,
                                  color: AppTheme.onBackgroundSubtle,
                                  size: 22,
                                ),
                              ),
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${playlist.tracksCount} ${playlist.tracksCount == 1 ? 'track' : 'tracks'}',
                                      style: const TextStyle(
                                        color: AppTheme.onBackgroundMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAdding)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToPlaylist(Playlist playlist) async {
    setState(() {
      _addingToPlaylistId = playlist.id;
      _successMessage = null;
    });

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.addTracksToPlaylist(playlist.id, widget.trackIds);

      if (!mounted) return;

      // Invalidate playlists to refresh track counts.
      ref.invalidate(playlistsProvider);

      setState(() {
        _addingToPlaylistId = null;
        _successMessage = 'Added to "${playlist.name}"';
      });

      // Auto-dismiss after showing success briefly.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _addingToPlaylistId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add to playlist')),
      );
    }
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'New Playlist',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              filled: true,
              fillColor: AppTheme.surfaceContainer,
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _createAndAdd(nameController, dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.onBackgroundMuted),
              ),
            ),
            TextButton(
              onPressed: () => _createAndAdd(nameController, dialogContext),
              child: const Text(
                'Create & Add',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createAndAdd(
    TextEditingController controller,
    BuildContext dialogContext,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;

    Navigator.of(dialogContext).pop();

    setState(() => _isCreating = true);

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final playlist = await api.createPlaylist(name: name);
      await api.addTracksToPlaylist(playlist.id, widget.trackIds);

      if (!mounted) return;

      ref.invalidate(playlistsProvider);

      setState(() {
        _isCreating = false;
        _successMessage = 'Created "${playlist.name}" and added tracks';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create playlist')),
      );
    }
  }
}
