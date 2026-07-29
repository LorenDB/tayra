import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/features/library_admin/library_admin_provider.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Constants ───────────────────────────────────────────────────────────

const _importStatuses = <String?>[
  null,
  'pending',
  'finished',
  'errored',
  'skipped',
  'draft',
];

String _statusLabel(String? status) {
  if (status == null) return 'All statuses';
  return status[0].toUpperCase() + status.substring(1);
}

// ── Screen ──────────────────────────────────────────────────────────────

class ManageUploadsScreen extends ConsumerStatefulWidget {
  const ManageUploadsScreen({super.key});

  @override
  ConsumerState<ManageUploadsScreen> createState() =>
      _ManageUploadsScreenState();
}

class _ManageUploadsScreenState extends ConsumerState<ManageUploadsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ManageUpload> _items = [];
  int _page = 1;
  int _count = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _query = '';
  String? _importStatus;

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
      final res = await api.getManageUploads(
        page: 1,
        pageSize: 25,
        q: _query.isEmpty ? null : _query,
        importStatus: _importStatus,
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
      final res = await api.getManageUploads(
        page: next,
        pageSize: 25,
        q: _query.isEmpty ? null : _query,
        importStatus: _importStatus,
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

  Future<void> _confirmDelete(ManageUpload upload) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete upload?',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Text(
              'Delete “${upload.displayTitle}”? This cannot be undone.',
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
      await ref.read(funkwhaleApiProvider).deleteManageUpload(upload.uuid);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((u) => u.uuid == upload.uuid);
        _count = (_count - 1).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload deleted')));
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
        title: const Text('Uploads'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/manage/library'),
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
              message: 'You do not have permission to manage uploads.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.onBackground),
                  decoration: InputDecoration(
                    hintText: 'Search tracks, artists, files…',
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
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _importStatuses.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final status = _importStatuses[index];
                    final selected = status == _importStatus;
                    return FilterChip(
                      label: Text(_statusLabel(status)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _importStatus = status);
                        _load(reset: true);
                      },
                      selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                      checkmarkColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color:
                            selected
                                ? AppTheme.primary
                                : AppTheme.onBackgroundMuted,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color:
                            selected
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.divider,
                      ),
                      backgroundColor: AppTheme.surfaceContainer,
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
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
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.cloud_upload_outlined,
              title: 'No uploads',
              subtitle: 'No uploads match your filters',
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
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final upload = _items[index];
          return _UploadTile(
            upload: upload,
            onDelete: () => _confirmDelete(upload),
          );
        },
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────

class _UploadTile extends StatelessWidget {
  final ManageUpload upload;
  final VoidCallback onDelete;

  const _UploadTile({required this.upload, required this.onDelete});

  Color _statusColor(String status) {
    switch (status) {
      case 'finished':
        return AppTheme.secondary;
      case 'errored':
        return AppTheme.error;
      case 'pending':
        return AppTheme.primary;
      case 'skipped':
        return AppTheme.onBackgroundSubtle;
      default:
        return AppTheme.onBackgroundMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      upload.importStatus,
      if (upload.artistName != null) upload.artistName!,
      if (upload.libraryName != null) upload.libraryName!,
      if (upload.size != null) _formatBytes(upload.size!),
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          Icons.audio_file_outlined,
          color: _statusColor(upload.importStatus),
        ),
        title: Text(
          upload.displayTitle,
          style: const TextStyle(
            color: AppTheme.onBackground,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.onBackgroundMuted,
            fontSize: 12,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) return 'Permission denied (403)';
    return error.message ?? error.toString();
  }
  return error.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
