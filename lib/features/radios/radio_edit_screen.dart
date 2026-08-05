import 'dart:async';

import 'package:flutter/material.dart' hide Radio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/cover_art_editor.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/shimmer_loading.dart';

// ── Draft models ────────────────────────────────────────────────────────

enum _FilterKind { artist, tag }

/// One filter row in the radio builder (artist or tag, include/exclude).
class _FilterDraft {
  _FilterKind kind;
  bool exclude;

  /// Artist selections: id → display name.
  final Map<int, String> artists;

  /// Tag names (API key is the name itself).
  final Set<String> tags;

  _FilterDraft({
    this.kind = _FilterKind.artist,
    this.exclude = false,
    Map<int, String>? artists,
    Set<String>? tags,
  }) : artists = artists ?? {},
       tags = tags ?? {};

  factory _FilterDraft.fromConfig(Map<String, dynamic> config) {
    final type = config['type'] as String? ?? 'artist';
    final exclude = config['not'] == true;
    if (type == 'tag') {
      final names = <String>{};
      final raw = config['names'];
      if (raw is List) {
        for (final n in raw) {
          if (n != null && n.toString().isNotEmpty) names.add(n.toString());
        }
      }
      return _FilterDraft(kind: _FilterKind.tag, exclude: exclude, tags: names);
    }

    final artists = <int, String>{};
    final ids = config['ids'];
    final names = config['names'];
    final idList = ids is List
        ? ids
              .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
              .whereType<int>()
              .toList()
        : <int>[];
    final nameList = names is List
        ? names.map((e) => e?.toString() ?? '').toList()
        : <String>[];
    for (var i = 0; i < idList.length; i++) {
      final name = i < nameList.length && nameList[i].isNotEmpty
          ? nameList[i]
          : 'Artist #${idList[i]}';
      artists[idList[i]] = name;
    }
    return _FilterDraft(
      kind: _FilterKind.artist,
      exclude: exclude,
      artists: artists,
    );
  }

  bool get hasSelection =>
      kind == _FilterKind.artist ? artists.isNotEmpty : tags.isNotEmpty;

  Map<String, dynamic> toConfig() {
    final base = <String, dynamic>{
      'type': kind == _FilterKind.artist ? 'artist' : 'tag',
      if (exclude) 'not': true,
    };
    if (kind == _FilterKind.artist) {
      base['ids'] = artists.keys.toList()..sort();
    } else {
      base['names'] = tags.toList()..sort();
    }
    return base;
  }

  String get summary {
    if (kind == _FilterKind.artist) {
      if (artists.isEmpty) return 'No artists selected';
      return artists.values.join(', ');
    }
    if (tags.isEmpty) return 'No tags selected';
    return tags.join(', ');
  }
}

// ── Screen ──────────────────────────────────────────────────────────────

/// Create or edit a user-owned custom radio (filters, metadata, cover).
///
/// Pass [radioId] `null` for create mode; a positive id loads that radio for
/// editing. Only radios owned by the current user can be saved or deleted.
class RadioEditScreen extends ConsumerStatefulWidget {
  final int? radioId;

  /// Optional seed when navigating from the list (avoids a flash of empty form).
  final Radio? initialRadio;

  const RadioEditScreen({super.key, this.radioId, this.initialRadio});

  bool get isCreate => radioId == null;

  @override
  ConsumerState<RadioEditScreen> createState() => _RadioEditScreenState();
}

class _RadioEditScreenState extends ConsumerState<RadioEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isPublic = false;
  CoverArtSelection? _coverSelection;
  Cover? _currentCover;
  final List<_FilterDraft> _filters = [];

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _loadError;
  bool _isDirty = false;
  bool _seeded = false;

  /// Optional live validation hint (candidate counts).
  String? _validationHint;
  bool _isValidating = false;
  Timer? _validateDebounce;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_markDirty);
    _descriptionController.addListener(_markDirty);

    final seed = widget.initialRadio;
    if (seed != null && seed.id == widget.radioId) {
      _applyRadio(seed);
      _seeded = true;
    }

    if (!widget.isCreate) {
      _loadRadio();
    } else if (_filters.isEmpty) {
      // Start create mode with one empty artist filter for discoverability.
      _filters.add(_FilterDraft());
    }
  }

  @override
  void dispose() {
    _validateDebounce?.cancel();
    _nameController.removeListener(_markDirty);
    _descriptionController.removeListener(_markDirty);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
    _scheduleValidation();
  }

  void _applyRadio(Radio radio) {
    _nameController.text = radio.name;
    _descriptionController.text = radio.description ?? '';
    _isPublic = radio.isPublic ?? false;
    _currentCover = radio.cover;
    _coverSelection = null;
    _filters
      ..clear()
      ..addAll(
        (radio.config ?? const <Map<String, dynamic>>[]).map(
          _FilterDraft.fromConfig,
        ),
      );
    if (_filters.isEmpty) _filters.add(_FilterDraft());
    _isDirty = false;
  }

  Future<void> _loadRadio() async {
    final id = widget.radioId;
    if (id == null) return;

    setState(() {
      // Keep seeded UI visible; only shimmer when we have nothing.
      if (!_seeded) _isLoading = true;
      _loadError = null;
    });

    try {
      final radio = await ref.read(cachedFunkwhaleApiProvider).getRadio(id);
      if (!mounted) return;
      setState(() {
        _applyRadio(radio);
        _isLoading = false;
        _seeded = true;
      });
      _scheduleValidation();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Failed to load radio';
        _isLoading = false;
      });
    }
  }

  void _scheduleValidation() {
    _validateDebounce?.cancel();
    _validateDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_runValidation());
    });
  }

  Future<void> _runValidation() async {
    final configs = _filters
        .where((f) => f.hasSelection)
        .map((f) => f.toConfig())
        .toList();
    if (configs.isEmpty) {
      if (mounted) {
        setState(() {
          _validationHint = null;
          _isValidating = false;
        });
      }
      return;
    }

    setState(() => _isValidating = true);
    try {
      final results = await ref
          .read(cachedFunkwhaleApiProvider)
          .validateRadioFilters(configs);
      if (!mounted) return;

      final errors = <String>[];
      var total = 0;
      var anyCount = false;
      for (final r in results) {
        errors.addAll(r.errors);
        if (r.candidateCount != null) {
          anyCount = true;
          total += r.candidateCount!;
        }
      }

      setState(() {
        _isValidating = false;
        if (errors.isNotEmpty) {
          _validationHint = errors.first;
        } else if (anyCount) {
          // Per-filter counts are not a true intersection; still useful as a
          // rough signal that filters match library content.
          _validationHint = total == 1
              ? 'About 1 track matches the filters'
              : 'About $total tracks match the filters';
        } else {
          _validationHint = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        // Validation is advisory — don't block save on network hiccups.
        _validationHint = null;
      });
    }
  }

  Future<bool> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required')));
      return false;
    }

    final configs = _filters
        .where((f) => f.hasSelection)
        .map((f) => f.toConfig())
        .toList();
    if (configs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one filter with a selection'),
        ),
      );
      return false;
    }

    setState(() => _isSaving = true);

    final body = <String, dynamic>{
      'name': name,
      'description': _descriptionController.text.trim(),
      'is_public': _isPublic,
      'config': configs,
    };
    final coverSel = _coverSelection;
    if (coverSel != null && coverSel.hasChange) {
      body['cover'] = coverSel.uploaded?.uuid;
    }

    try {
      final api = ref.read(cachedFunkwhaleApiProvider);
      if (widget.isCreate) {
        await api.createRadio(body: body);
        Analytics.track('radio_created');
      } else {
        // PATCH so omitted fields (e.g. cover when unchanged) stay intact.
        await api.patchRadio(widget.radioId!, body);
        Analytics.track('radio_edited');
      }
      if (!mounted) return false;
      setState(() {
        _isSaving = false;
        _isDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isCreate ? 'Radio created' : 'Radio saved'),
        ),
      );
      popPage(context, result: true, fallbackLocation: '/radios');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save radio')));
      return false;
    }
  }

  Future<void> _delete() async {
    final id = widget.radioId;
    if (id == null) return;

    final confirmed = await showShellDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete radio?',
          style: TextStyle(
            color: AppTheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete “${_nameController.text.trim().isEmpty ? 'this radio' : _nameController.text.trim()}”? '
          'Anyone with access will lose it. This cannot be undone.',
          style: const TextStyle(color: AppTheme.onBackgroundMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete radio',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(cachedFunkwhaleApiProvider).deleteRadio(id);
      Analytics.track('radio_deleted');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Radio deleted')));
      popPage(context, result: true, fallbackLocation: '/radios');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete radio')));
    }
  }

  Future<void> _onPopRequested() async {
    if (!_isDirty) {
      if (mounted) popPage(context, fallbackLocation: '/radios');
      return;
    }

    final discard = await showShellDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      if (saved && mounted) {
        // _save already pops on success
      }
    } else if (discard == true) {
      if (mounted) popPage(context, fallbackLocation: '/radios');
    }
  }

  Future<void> _pickForFilter(int index) async {
    final draft = _filters[index];
    if (draft.kind == _FilterKind.artist) {
      final picked = await showShellDialog<_ArtistPick?>(
        context: context,
        builder: (ctx) => _ArtistSearchDialog(alreadySelected: draft.artists),
      );
      if (picked == null || !mounted) return;
      setState(() {
        draft.artists[picked.id] = picked.name;
        _isDirty = true;
      });
      _scheduleValidation();
    } else {
      final name = await showShellDialog<String?>(
        context: context,
        builder: (ctx) => _TagSearchDialog(alreadySelected: draft.tags),
      );
      if (name == null || name.isEmpty || !mounted) return;
      setState(() {
        draft.tags.add(name);
        _isDirty = true;
      });
      _scheduleValidation();
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
          title: Text(
            widget.isCreate ? 'New radio' : 'Edit radio',
            style: const TextStyle(
              color: AppTheme.onBackground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (!widget.isCreate)
              IconButton(
                tooltip: 'Delete radio',
                onPressed: _isDeleting || _isSaving ? null : _delete,
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.error,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
              ),
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
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
        body: _isLoading
            ? const ShimmerList(itemCount: 8)
            : _loadError != null
            ? InlineErrorState(message: _loadError!, onRetry: _loadRadio)
            : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // ── Cover ────────────────────────────────────────────────────
        Center(
          child: CoverArtEditor(
            currentCover: _currentCover,
            placeholderIcon: Icons.radio_rounded,
            selection: _coverSelection,
            onChanged: (sel) {
              setState(() {
                _coverSelection = sel;
                _isDirty = true;
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        // ── Name ─────────────────────────────────────────────────────
        const _SectionLabel('Name'),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
          textCapitalization: TextCapitalization.sentences,
          decoration: _fieldDecoration(hint: 'Radio name'),
        ),
        const SizedBox(height: 16),

        // ── Description ──────────────────────────────────────────────
        const _SectionLabel('Description'),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          style: const TextStyle(color: AppTheme.onBackground, fontSize: 15),
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
          decoration: _fieldDecoration(hint: 'Optional description'),
        ),
        const SizedBox(height: 8),

        // ── Public ───────────────────────────────────────────────────
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Display publicly',
            style: TextStyle(color: AppTheme.onBackground, fontSize: 15),
          ),
          subtitle: const Text(
            'Other users on this instance can see and play this radio',
            style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
          ),
          value: _isPublic,
          activeThumbColor: AppTheme.primary,
          onChanged: (v) {
            setState(() {
              _isPublic = v;
              _isDirty = true;
            });
          },
        ),
        const SizedBox(height: 8),
        const Divider(color: AppTheme.divider),
        const SizedBox(height: 12),

        // ── Filters ──────────────────────────────────────────────────
        Row(
          children: [
            const Expanded(child: _SectionLabel('Filters')),
            if (_isValidating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Include or exclude tracks by artist or tag. Filters are combined '
          'with AND.',
          style: TextStyle(color: AppTheme.onBackgroundMuted, fontSize: 12),
        ),
        if (_validationHint != null) ...[
          const SizedBox(height: 8),
          Text(
            _validationHint!,
            style: TextStyle(
              color:
                  _validationHint!.toLowerCase().contains('no ') ||
                      _validationHint!.toLowerCase().contains('invalid') ||
                      _validationHint!.toLowerCase().contains('must')
                  ? AppTheme.error
                  : AppTheme.secondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 12),

        for (var i = 0; i < _filters.length; i++) ...[
          _FilterCard(
            draft: _filters[i],
            onKindChanged: (kind) {
              setState(() {
                _filters[i].kind = kind;
                _filters[i].artists.clear();
                _filters[i].tags.clear();
                _isDirty = true;
              });
              _scheduleValidation();
            },
            onExcludeChanged: (v) {
              setState(() {
                _filters[i].exclude = v;
                _isDirty = true;
              });
              _scheduleValidation();
            },
            onAddSelection: () => _pickForFilter(i),
            onRemoveSelection: (label) {
              setState(() {
                final d = _filters[i];
                if (d.kind == _FilterKind.artist) {
                  d.artists.removeWhere((_, name) => name == label);
                } else {
                  d.tags.remove(label);
                }
                _isDirty = true;
              });
              _scheduleValidation();
            },
            onRemoveArtistId: (id) {
              setState(() {
                _filters[i].artists.remove(id);
                _isDirty = true;
              });
              _scheduleValidation();
            },
            onRemove: _filters.length <= 1
                ? null
                : () {
                    setState(() {
                      _filters.removeAt(i);
                      _isDirty = true;
                    });
                    _scheduleValidation();
                  },
          ),
          const SizedBox(height: 10),
        ],

        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _filters.add(_FilterDraft());
              _isDirty = true;
            });
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add filter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

// ── Small widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.onBackgroundMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final _FilterDraft draft;
  final ValueChanged<_FilterKind> onKindChanged;
  final ValueChanged<bool> onExcludeChanged;
  final VoidCallback onAddSelection;
  final ValueChanged<String> onRemoveSelection;
  final ValueChanged<int> onRemoveArtistId;
  final VoidCallback? onRemove;

  const _FilterCard({
    required this.draft,
    required this.onKindChanged,
    required this.onExcludeChanged,
    required this.onAddSelection,
    required this.onRemoveSelection,
    required this.onRemoveArtistId,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_FilterKind>(
                  segments: const [
                    ButtonSegment(
                      value: _FilterKind.artist,
                      label: Text('Artist'),
                      icon: Icon(Icons.person_outline_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: _FilterKind.tag,
                      label: Text('Tag'),
                      icon: Icon(Icons.tag_rounded, size: 16),
                    ),
                  ],
                  selected: {draft.kind},
                  onSelectionChanged: (s) => onKindChanged(s.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.onBackground;
                      }
                      return AppTheme.onBackgroundMuted;
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.primary.withValues(alpha: 0.25);
                      }
                      return AppTheme.surfaceContainerHigh;
                    }),
                  ),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove filter',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.onBackgroundSubtle,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Exclude',
              style: TextStyle(color: AppTheme.onBackground, fontSize: 14),
            ),
            subtitle: Text(
              draft.exclude
                  ? 'Tracks matching this filter are left out'
                  : 'Only tracks matching this filter are included',
              style: const TextStyle(
                color: AppTheme.onBackgroundMuted,
                fontSize: 11,
              ),
            ),
            value: draft.exclude,
            activeThumbColor: AppTheme.error,
            onChanged: onExcludeChanged,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (draft.kind == _FilterKind.artist)
                ...draft.artists.entries.map(
                  (e) => InputChip(
                    label: Text(e.value),
                    onDeleted: () => onRemoveArtistId(e.key),
                    deleteIconColor: AppTheme.onBackgroundMuted,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    labelStyle: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 13,
                    ),
                    side: BorderSide.none,
                  ),
                )
              else
                ...draft.tags.map(
                  (t) => InputChip(
                    label: Text(t),
                    onDeleted: () => onRemoveSelection(t),
                    deleteIconColor: AppTheme.onBackgroundMuted,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    labelStyle: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 13,
                    ),
                    side: BorderSide.none,
                  ),
                ),
              ActionChip(
                avatar: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                label: Text(
                  draft.kind == _FilterKind.artist ? 'Add artist' : 'Add tag',
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13),
                ),
                onPressed: onAddSelection,
                backgroundColor: AppTheme.surfaceContainerHigh,
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Artist / tag pickers ────────────────────────────────────────────────

class _ArtistPick {
  final int id;
  final String name;
  const _ArtistPick({required this.id, required this.name});
}

class _ArtistSearchDialog extends ConsumerStatefulWidget {
  final Map<int, String> alreadySelected;
  const _ArtistSearchDialog({required this.alreadySelected});

  @override
  ConsumerState<_ArtistSearchDialog> createState() =>
      _ArtistSearchDialogState();
}

class _ArtistSearchDialogState extends ConsumerState<_ArtistSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Artist> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(cachedFunkwhaleApiProvider)
          .getArtists(page: 1, pageSize: 30, q: q.isEmpty ? null : q);
      if (!mounted) return;
      setState(() {
        _results = res.results
            .where((a) => !widget.alreadySelected.containsKey(a.id))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add artist',
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: InputDecoration(
                hintText: 'Search artists',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.onBackgroundMuted,
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    )
                  : _results.isEmpty
                  ? const Center(
                      child: Text(
                        'No artists found',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final a = _results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            a.name,
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                            ),
                          ),
                          subtitle: a.tracksCount > 0
                              ? Text(
                                  '${a.tracksCount} tracks',
                                  style: const TextStyle(
                                    color: AppTheme.onBackgroundMuted,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_ArtistPick(id: a.id, name: a.name)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.onBackgroundMuted),
          ),
        ),
      ],
    );
  }
}

class _TagSearchDialog extends ConsumerStatefulWidget {
  final Set<String> alreadySelected;
  const _TagSearchDialog({required this.alreadySelected});

  @override
  ConsumerState<_TagSearchDialog> createState() => _TagSearchDialogState();
}

class _TagSearchDialogState extends ConsumerState<_TagSearchDialog> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Tag> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(cachedFunkwhaleApiProvider)
          .getTags(page: 1, pageSize: 50, q: q.isEmpty ? null : q);
      if (!mounted) return;
      setState(() {
        _results = res.results
            .where((t) => !widget.alreadySelected.contains(t.name))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _controller.text.trim();
    final canUseTyped =
        typed.isNotEmpty && !widget.alreadySelected.contains(typed);

    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add tag',
        style: TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: InputDecoration(
                hintText: 'Search tags',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.onBackgroundMuted,
                ),
                filled: true,
                fillColor: AppTheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (q) {
                setState(() {});
                _onQueryChanged(q);
              },
              onSubmitted: (q) {
                final t = q.trim();
                if (t.isNotEmpty) Navigator.of(context).pop(t);
              },
            ),
            if (canUseTyped) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(typed),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Use “$typed”'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    )
                  : _results.isEmpty
                  ? const Center(
                      child: Text(
                        'No tags found',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final t = _results[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            t.name,
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(t.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.onBackgroundMuted),
          ),
        ),
      ],
    );
  }
}
