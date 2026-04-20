import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';
import 'package:tayra/core/widgets/error_state.dart';

// ── Screen ──────────────────────────────────────────────────────────────

class AlbumEditScreen extends ConsumerStatefulWidget {
  final int albumId;

  const AlbumEditScreen({super.key, required this.albumId});

  @override
  ConsumerState<AlbumEditScreen> createState() => _AlbumEditScreenState();
}

class _AlbumEditScreenState extends ConsumerState<AlbumEditScreen> {
  Album? _album;
  bool _isLoading = true;
  String? _loadError;

  final _titleController = TextEditingController();
  final _releaseDateController = TextEditingController();
  final _mbidController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();

  late List<String> _tags;
  bool _isSaving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _tags = [];
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _releaseDateController.dispose();
    _mbidController.dispose();
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      final album = await api.getAlbum(widget.albumId);
      if (!mounted) return;
      _titleController.text = album.title;
      _releaseDateController.text = album.releaseDate ?? '';
      _mbidController.text = album.mbid ?? '';
      setState(() {
        _album = album;
        _tags = List<String>.from(album.tags);
        _isDirty = false;
        _isLoading = false;
      });
      _titleController.addListener(_onFieldChanged);
      _releaseDateController.addListener(_onFieldChanged);
      _mbidController.addListener(_onFieldChanged);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load album';
        _isLoading = false;
      });
    }
  }

  void _onFieldChanged() {
    final album = _album;
    if (album == null) return;
    final dirty =
        _titleController.text.trim() != album.title ||
        _releaseDateController.text.trim() != (album.releaseDate ?? '') ||
        _mbidController.text.trim() != (album.mbid ?? '') ||
        !_listsEqual(_tags, album.tags);
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  void _addTag(String value) {
    final tag = value.trim().toLowerCase();
    if (tag.isEmpty || _tags.contains(tag)) {
      _tagInputController.clear();
      return;
    }
    setState(() {
      _tags = [..._tags, tag];
      _isDirty = true;
    });
    _tagInputController.clear();
    _tagFocusNode.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags = _tags.where((t) => t != tag).toList();
    });
    _onFieldChanged();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = Set<String>.from(a);
    final sb = Set<String>.from(b);
    return sa.containsAll(sb) && sb.containsAll(sa);
  }

  Future<void> _pickReleaseDate() async {
    DateTime initial;
    try {
      final text = _releaseDateController.text.trim();
      initial = text.isNotEmpty ? DateTime.parse(text) : DateTime.now();
    } catch (_) {
      initial = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.primary,
                surface: AppTheme.surfaceContainerHigh,
                onSurface: AppTheme.onBackground,
              ),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _releaseDateController.text = formatted;
    }
  }

  Future<bool> _save() async {
    final album = _album;
    if (album == null) return false;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title cannot be empty')));
      return false;
    }

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{};
    if (title != album.title) payload['title'] = title;
    final releaseDate = _releaseDateController.text.trim();
    if (releaseDate != (album.releaseDate ?? '')) {
      payload['release_date'] = releaseDate.isEmpty ? null : releaseDate;
    }
    final mbid = _mbidController.text.trim();
    if (mbid != (album.mbid ?? '')) {
      payload['mbid'] = mbid.isEmpty ? null : mbid;
    }
    if (!_listsEqual(_tags, album.tags)) payload['tags'] = _tags;

    if (payload.isEmpty) {
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      return true;
    }

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      await api.createAlbumMutation(widget.albumId, payload);
      try {
        Analytics.track('album_edited');
      } catch (_) {}
      if (!mounted) return false;
      setState(() {
        _isDirty = false;
        _isSaving = false;
        _album = album._copyWith(
          title: title,
          releaseDate: releaseDate.isEmpty ? null : releaseDate,
          mbid: mbid.isEmpty ? null : mbid,
          tags: _tags,
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

  Future<void> _onPopRequested() async {
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final discard = await showDialog<bool>(
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
            'Edit Album',
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
              onPressed: (_isSaving || !_isDirty) ? null : _save,
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
                      : Text(
                        'Save',
                        style: TextStyle(
                          color:
                              _isDirty
                                  ? AppTheme.primary
                                  : AppTheme.onBackgroundSubtle,
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
                ? const ShimmerList(itemCount: 6)
                : _loadError != null
                ? InlineErrorState(message: _loadError!, onRetry: _loadData)
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Title ────────────────────────────────────────────────────
        _SectionLabel('Title'),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
          decoration: const InputDecoration(hintText: 'Album title'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),

        // ── Release date ─────────────────────────────────────────────
        _SectionLabel('Release date'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _releaseDateController,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primary,
              ),
              onPressed: _pickReleaseDate,
              tooltip: 'Pick date',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── MusicBrainz ID ───────────────────────────────────────────
        _SectionLabel('MusicBrainz ID'),
        const SizedBox(height: 8),
        TextField(
          controller: _mbidController,
          style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          ),
          autocorrect: false,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 24),

        // ── Tags ─────────────────────────────────────────────────────
        _SectionLabel('Tags'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputController,
                focusNode: _tagFocusNode,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 15,
                ),
                decoration: const InputDecoration(hintText: 'Add a tag'),
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                onSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
              onPressed: () => _addTag(_tagInputController.text),
              tooltip: 'Add tag',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tags.isEmpty)
          const Text(
            'No tags yet',
            style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _tags.map((tag) {
                  return _TagChip(tag: tag, onRemove: () => _removeTag(tag));
                }).toList(),
          ),
        const SizedBox(height: 24),

        // ── Note ─────────────────────────────────────────────────────
        const Text(
          'Changes are submitted as a mutation proposal. If you own the library, changes are applied immediately.',
          style: TextStyle(color: AppTheme.onBackgroundSubtle, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.onBackgroundMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Tag chip with remove button ─────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4, right: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
              color: AppTheme.onBackgroundMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppTheme.onBackgroundSubtle,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Album copyWith extension ────────────────────────────────────────────

extension _AlbumEdit on Album {
  Album _copyWith({
    required String title,
    required String? releaseDate,
    required String? mbid,
    required List<String> tags,
  }) {
    return Album(
      id: id,
      title: title,
      artist: artist,
      cover: cover,
      releaseDate: releaseDate,
      tracksCount: tracksCount,
      duration: duration,
      isPlayable: isPlayable,
      tags: tags,
      creationDate: creationDate,
      tracks: tracks,
      mbid: mbid,
    );
  }
}
