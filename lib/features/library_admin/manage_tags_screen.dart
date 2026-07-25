import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/features/library_admin/library_admin_provider.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Screen ──────────────────────────────────────────────────────────────

class ManageTagsScreen extends ConsumerStatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  ConsumerState<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends ConsumerState<ManageTagsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ManageTag> _items = [];
  int _page = 1;
  int _count = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _creating = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_items.length >= _count) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final api = ref.read(funkwhaleApiProvider);
      final res = await api.getManageTags(
        page: 1,
        pageSize: 50,
        q: _query.isEmpty ? null : _query,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.results);
        _count = res.count;
        _page = 1;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final api = ref.read(funkwhaleApiProvider);
      final res = await api.getManageTags(
        page: next,
        pageSize: 50,
        q: _query.isEmpty ? null : _query,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(res.results);
        _count = res.count;
        _page = next;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final created = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Create tag',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: AppTheme.onBackgroundMuted),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).pop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (created != true || name.isEmpty || !mounted) return;

    setState(() => _creating = true);
    try {
      final tag = await ref.read(funkwhaleApiProvider).createManageTag(name);
      if (!mounted) return;
      setState(() {
        _items.insert(0, tag);
        _count += 1;
        _creating = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Created tag “${tag.name}”')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create failed: ${_friendlyError(e)}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(ManageTag tag) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete tag?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Text(
              'Delete tag “${tag.name}”? Tagged items lose this label.',
              style: const TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(funkwhaleApiProvider).deleteManageTag(tag.name);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((t) => t.name == tag.name);
        _count = (_count - 1).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted “${tag.name}”')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: ${_friendlyError(e)}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageLibraryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tags'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            tooltip: 'Create tag',
            onPressed: _creating ? null : _createTag,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _creating ? null : _createTag,
        backgroundColor: AppTheme.primary,
        child:
            _creating
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: canManage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => LibraryAdminDeniedBody(
              message: 'Could not verify library permissions.\n$error',
              onRetry: () => ref.invalidate(meUserProvider),
            ),
        data: (allowed) {
          if (!allowed) {
            return const LibraryAdminDeniedBody(
              message: 'You do not have permission to manage tags.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.onBackground),
                  decoration: InputDecoration(
                    hintText: 'Search tags…',
                    hintStyle: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.onBackgroundSubtle,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    _query = v.trim();
                    _load(reset: true);
                  },
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return InlineErrorState(
        message: _error!,
        onRetry: () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            EmptyState(
              icon: Icons.label_outline_rounded,
              title: 'No tags',
              subtitle: 'Create a tag or refine your search',
              action: FilledButton.icon(
                onPressed: _createTag,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create tag'),
              ),
            ),
          ],
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final tag = _items[index];
          final counts =
              '${tag.tracksCount} tracks · ${tag.albumsCount} albums · '
              '${tag.artistsCount} artists';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: const Icon(Icons.label_rounded, color: AppTheme.primary),
              title: Text(
                tag.name,
                style: const TextStyle(
                  color: AppTheme.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                counts,
                style: const TextStyle(
                  color: AppTheme.onBackgroundMuted,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(tag),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) return 'Permission denied (403)';
    if (code == 400) {
      final data = error.response?.data;
      if (data is Map && data['name'] != null) {
        return data['name'].toString();
      }
    }
    return error.message ?? error.toString();
  }
  return error.toString();
}
