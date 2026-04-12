import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tayra/core/api/api_utils.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/year_review/ai_summary_provider.dart';

class PlaylistEditScreen extends ConsumerStatefulWidget {
  final int playlistId;

  const PlaylistEditScreen({super.key, required this.playlistId});

  @override
  ConsumerState<PlaylistEditScreen> createState() => _PlaylistEditScreenState();
}

class _PlaylistEditScreenState extends ConsumerState<PlaylistEditScreen> {
  Playlist? _playlist;
  List<PlaylistTrack> _tracks = [];
  bool _isLoading = true;
  String? _loadError;

  late TextEditingController _nameController;
  String _privacyLevel = 'me';
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_onNameChanged);
    _loadData();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    if (_playlist == null) return;
    final dirty =
        _nameController.text.trim() != _playlist!.name ||
        _privacyLevel != (_playlist!.privacyLevel ?? 'me');
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final results = await Future.wait([
        api.getPlaylist(widget.playlistId),
        fetchAllPages(
          (page) => api.getPlaylistTracks(
            widget.playlistId,
            page: page,
            pageSize: 100,
          ),
        ),
      ]);

      final playlist = results[0] as Playlist;
      final tracks = results[1] as List<PlaylistTrack>;

      if (!mounted) return;
      setState(() {
        _playlist = playlist;
        _nameController.text = playlist.name;
        _privacyLevel = playlist.privacyLevel ?? 'me';
        _tracks = tracks;
        _isDirty = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load playlist';
        _isLoading = false;
      });
    }
  }

  Future<bool> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;

    setState(() => _isSaving = true);

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.patchPlaylist(widget.playlistId, {
        'name': name,
        'privacy_level': _privacyLevel,
      });
      try {
        Aptabase.instance.trackEvent('playlist_edited', {
          'playlist_id': widget.playlistId,
        });
      } catch (_) {}
      ref.invalidate(playlistsProvider);
      if (!mounted) return false;
      setState(() {
        _isDirty = false;
        _isSaving = false;
        _playlist = _playlist?.copyWith(
          name: name,
          privacyLevel: _privacyLevel,
        );
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save changes')));
      return false;
    }
  }

  Future<void> _removeTrack(int index) async {
    final removed = _tracks.removeAt(index);
    setState(() {});

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.removeTrackFromPlaylist(widget.playlistId, index);
      try {
        Aptabase.instance.trackEvent('playlist_track_removed');
      } catch (_) {}
      ref.invalidate(playlistsProvider);
    } catch (e) {
      _tracks.insert(index, removed);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove track')));
      }
    }
  }

  Future<void> _reorderTrack(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final moved = _tracks.removeAt(oldIndex);
    _tracks.insert(newIndex, moved);
    setState(() {});

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.moveTrackInPlaylist(widget.playlistId, oldIndex, newIndex);
      try {
        Aptabase.instance.trackEvent('playlist_track_reordered');
      } catch (_) {}
    } catch (e) {
      _tracks.removeAt(newIndex);
      _tracks.insert(oldIndex, moved);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reorder track')),
        );
      }
    }
  }

  Future<void> _onPopRequested() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final discard = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Unsaved changes',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: const Text(
              'Save your changes before leaving?',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Save',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
    );

    if (discard == false) {
      final saved = await _save();
      if (saved && mounted) Navigator.of(context).pop();
    } else if (discard == true) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── AI name generation ──────────────────────────────────────────────

  Future<void> _generateName() async {
    final playlist = _playlist;
    if (playlist == null) return;

    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final name = await MethodChannel(
        'dev.lorendb.tayra/genai_prompt',
      ).invokeMethod<String>('generatePlaylistName', {
        'playlist_id': playlist.id,
        'current_name': playlist.name,
      });
      if (name != null && name.isNotEmpty && mounted) {
        _nameController.text = name.trim();
      } else if (mounted) {
        // Provide feedback when AI returns empty
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI did not suggest a name')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg =
          e is MissingPluginException
              ? 'AI not available on this device'
              : 'AI failed to generate name';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopRequested();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.onBackground,
            ),
            onPressed: _onPopRequested,
          ),
          title: const Text(
            'Edit Playlist',
            style: TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _onPopRequested,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                      : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body:
            _isLoading
                ? const ShimmerList(itemCount: 8)
                : _loadError != null
                ? InlineErrorState(message: _loadError!, onRetry: _loadData)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Metadata section ──────────────────────────────────────────
        _buildMetadataSection(),

        const Divider(color: AppTheme.divider, height: 1),

        // ── Tracks header ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              Text(
                pluralizeTrack(_tracks.length),
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_tracks.isNotEmpty)
                Row(
                  children: [
                    const SizedBox(width: 4),
                    // Clear all tracks (moved here)
                    TextButton.icon(
                      onPressed: () async {
                        final ok = await showShellDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                backgroundColor: AppTheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: const Text(
                                  'Clear playlist',
                                  style: TextStyle(
                                    color: AppTheme.onBackground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                content: const Text(
                                  'Remove all tracks from this playlist? This cannot be undone.',
                                  style: TextStyle(
                                    color: AppTheme.onBackgroundMuted,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppTheme.onBackgroundMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(color: AppTheme.error),
                                    ),
                                  ),
                                ],
                              ),
                        );

                        if (ok != true) return;

                        // Optimistic UI
                        final backup = List<PlaylistTrack>.from(_tracks);
                        setState(() => _tracks = []);
                        try {
                          final api = ref.read(cachedFunkwhaleApiProvider);
                          await api.clearPlaylist(widget.playlistId);
                          try {
                            Aptabase.instance.trackEvent('playlist_cleared');
                          } catch (_) {}
                          ref.invalidate(playlistsProvider);
                        } catch (e) {
                          setState(() => _tracks = backup);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to clear playlist'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.playlist_remove_rounded,
                        size: 14,
                        color: AppTheme.onBackground,
                      ),
                      label: const Text(
                        'Clear all tracks',
                        style: TextStyle(
                          color: AppTheme.onBackground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // ── Track list ────────────────────────────────────────────────
        Expanded(child: _buildTrackList()),
      ],
    );
  }

  Widget _buildMetadataSection() {
    final settings = ref.watch(settingsProvider);
    final modelStatusAsync =
        defaultTargetPlatform == TargetPlatform.android
            ? ref.watch(genaiModelStatusProvider)
            : const AsyncValue.data(0);
    final hasLocalAi =
        settings.aiEnabled &&
        defaultTargetPlatform == TargetPlatform.android &&
        (modelStatusAsync.asData?.value ?? 0) == 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  onChanged: (_) {
                    _onNameChanged();
                    // Force a rebuild to ensure app bar actions update on some devices
                    if (mounted) setState(() {});
                  },
                  style: const TextStyle(
                    color: AppTheme.onBackground,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(labelText: 'Playlist name'),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              if (hasLocalAi) ...[
                const SizedBox(width: 8),
                _isGenerating
                    ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                    : IconButton(
                      tooltip: 'Generate name with AI',
                      color: AppTheme.primary,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      onPressed: _generateName,
                    ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Privacy
          const Text(
            'Visibility',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _PrivacySelector(
            value: _privacyLevel,
            onChanged: (v) {
              setState(() {
                _privacyLevel = v;
                _isDirty =
                    _nameController.text.trim() != (_playlist?.name ?? '') ||
                    v != (_playlist?.privacyLevel ?? 'me');
              });
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTrackList() {
    if (_tracks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tracks in this playlist',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 14),
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      buildDefaultDragHandles: false,
      itemCount: _tracks.length,
      itemBuilder: (context, index) {
        final pt = _tracks[index];
        return _EditTrackTile(
          key: ValueKey('edit_pt_${index}_${pt.track.id}'),
          track: pt.track,
          index: index,
          onRemove: () => _removeTrack(index),
        );
      },
      onReorder: _reorderTrack,
    );
  }
}

// ── Playlist model copyWith extension ───────────────────────────────────

extension _PlaylistCopyWith on Playlist {
  Playlist copyWith({String? name, String? privacyLevel}) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      tracksCount: tracksCount,
      duration: duration,
      isPlayable: isPlayable,
      albumCovers: albumCovers,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      creationDate: creationDate,
      modificationDate: modificationDate,
    );
  }
}

// ── Edit Track Tile ─────────────────────────────────────────────────────

class _EditTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final VoidCallback onRemove;

  const _EditTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Cover art
            CoverArtWidget(
              imageUrl: track.coverUrl,
              cacheKey: track.album?.coverUrl ?? track.coverUrl,
              size: 44,
              borderRadius: 6,
            ),
            const SizedBox(width: 12),

            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
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
                    track.artistName,
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

            // Drag handle
            Listener(
              onPointerDown: (_) {
                // Provide a small haptic feedback when user starts dragging
                try {
                  HapticFeedback.lightImpact();
                } catch (_) {}
              },
              child: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: AppTheme.onBackgroundSubtle,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Remove button (right side)
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                color: AppTheme.error,
                size: 22,
              ),
              onPressed: onRemove,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Privacy Selector ────────────────────────────────────────────────────

class _PrivacySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PrivacySelector({required this.value, required this.onChanged});

  static const _options = [
    ('me', Icons.lock_rounded, 'Only me'),
    ('followers', Icons.group_rounded, 'Followers'),
    ('instance', Icons.dns_rounded, 'Instance'),
    ('everyone', Icons.public_rounded, 'Everyone'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _options.map((opt) {
            final (level, icon, label) = opt;
            final selected = value == level;
            return GestureDetector(
              onTap: () => onChanged(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        selected
                            ? AppTheme.primary
                            : AppTheme.onBackgroundSubtle.withValues(
                              alpha: 0.3,
                            ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color:
                          selected
                              ? AppTheme.primary
                              : AppTheme.onBackgroundMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            selected
                                ? AppTheme.primary
                                : AppTheme.onBackgroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}
