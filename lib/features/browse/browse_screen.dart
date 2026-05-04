import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/cached_api_repository.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/browse/albums_screen.dart';
import 'package:tayra/features/browse/artists_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/core/layout/responsive.dart';

// ── Tags provider ────────────────────────────────────────────────────────

final albumTagsProvider = FutureProvider<List<String>>((ref) async {
  final api = ref.watch(cachedFunkwhaleApiProvider);
  final response = await api.getTags(pageSize: 200, ordering: 'name');
  return response.results.map((t) => t.name).toList();
});

// ── Screen ───────────────────────────────────────────────────────────────

/// Browse tab wrapper that switches between Albums and Artists views
/// based on the user's setting in [settingsProvider].
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browseMode = ref.watch(settingsProvider).browseMode;
    final isAlbums = browseMode == BrowseMode.albums;
    final filter = ref.watch(albumsFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isAlbums ? 'Albums' : 'Artists'),
        backgroundColor: AppTheme.background,
        actions: [
          if (isAlbums)
            _FilterButton(isActive: filter.isActive),
          if (!Responsive.useSideNavigation(context))
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => SearchScreen.show(context),
            ),
        ],
      ),
      body: isAlbums ? const AlbumsScreen() : const ArtistsScreen(),
    );
  }
}

// ── Filter button ────────────────────────────────────────────────────────

class _FilterButton extends ConsumerWidget {
  final bool isActive;

  const _FilterButton({required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Badge(
        isLabelVisible: isActive,
        smallSize: 8,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.tune_rounded),
      ),
      tooltip: 'Filter & sort',
      onPressed: () => _showFilterSheet(context, ref),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showShellModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _AlbumFilterSheet(),
      ),
    );
  }
}

// ── Filter bottom sheet ──────────────────────────────────────────────────

class _AlbumFilterSheet extends ConsumerStatefulWidget {
  const _AlbumFilterSheet();

  @override
  ConsumerState<_AlbumFilterSheet> createState() => _AlbumFilterSheetState();
}

class _AlbumFilterSheetState extends ConsumerState<_AlbumFilterSheet> {
  late AlbumSortMode _sortMode;
  late Set<String> _selectedTags;
  String _tagSearch = '';

  @override
  void initState() {
    super.initState();
    final filter = ref.read(albumsFilterProvider);
    _sortMode = filter.sortMode;
    _selectedTags = Set.from(filter.tags);
  }

  void _apply() {
    final notifier = ref.read(albumsFilterProvider.notifier);
    notifier.setSortMode(_sortMode);
    notifier.setTags(_selectedTags.toList());
    Navigator.of(context).pop();
  }

  void _reset() {
    ref.read(albumsFilterProvider.notifier).reset();
    Navigator.of(context).pop();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(albumTagsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.onBackgroundMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'Filter & Sort',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surface),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Sort section ───────────────────────────────────
                  const Text(
                    'Sort by',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackgroundMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AlbumSortMode.values.map((mode) {
                      final selected = _sortMode == mode;
                      return ChoiceChip(
                        label: Text(mode.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _sortMode = mode),
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.onBackgroundMuted
                                  .withValues(alpha: 0.3),
                        ),
                        labelStyle: TextStyle(
                          color: selected ? AppTheme.primary : null,
                          fontWeight:
                              selected ? FontWeight.w600 : null,
                        ),
                        backgroundColor: Colors.transparent,
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // ── Tags section ───────────────────────────────────
                  const Text(
                    'Filter by tag',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onBackgroundMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  tagsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    error: (e, _) => Text(
                      'Could not load tags',
                      style: TextStyle(color: AppTheme.onBackgroundMuted),
                    ),
                    data: (tags) {
                      final filtered = _tagSearch.isEmpty
                          ? tags
                          : tags
                              .where(
                                (t) => t.toLowerCase().contains(
                                      _tagSearch.toLowerCase(),
                                    ),
                              )
                              .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (tags.length > 10)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search tags…',
                                  hintStyle: TextStyle(
                                    color: AppTheme.onBackgroundMuted
                                        .withValues(alpha: 0.5),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    size: 20,
                                    color: AppTheme.onBackgroundMuted,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (v) =>
                                    setState(() => _tagSearch = v),
                              ),
                            ),
                          if (filtered.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No tags found',
                                style: TextStyle(
                                  color: AppTheme.onBackgroundMuted,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: filtered.map((tag) {
                                final selected = _selectedTags.contains(tag);
                                return FilterChip(
                                  label: Text(tag),
                                  selected: selected,
                                  onSelected: (_) => _toggleTag(tag),
                                  selectedColor:
                                      AppTheme.primary.withValues(alpha: 0.2),
                                  checkmarkColor: AppTheme.primary,
                                  side: BorderSide(
                                    color: selected
                                        ? AppTheme.primary
                                        : AppTheme.onBackgroundMuted
                                            .withValues(alpha: 0.3),
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected ? AppTheme.primary : null,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                  backgroundColor: Colors.transparent,
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Apply', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
