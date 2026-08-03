import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/user_admin/user_admin_denied.dart';
import 'package:tayra/features/user_admin/user_admin_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ManageUser> _items = [];
  int _page = 1;
  int _count = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadStarted = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _ensureLoaded(bool allowed) {
    if (!allowed || _loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
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
      final res = await api.getManageUsers(
        page: 1,
        pageSize: 25,
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
      final res = await api.getManageUsers(
        page: next,
        pageSize: 25,
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

  void _onSearchSubmitted(String value) {
    _query = value.trim();
    _load(reset: true);
  }

  /// Opens the user detail route and, after a successful delete, removes the
  /// entry from the in-memory list so the UI updates without leaving the page.
  Future<void> _openUserDetail(ManageUser user) async {
    final deleted = await context.push<bool>('/manage/users/${user.id}');
    if (!mounted || deleted != true) return;
    setState(() {
      final before = _items.length;
      _items.removeWhere((u) => u.id == user.id);
      final removed = before - _items.length;
      if (removed > 0) {
        _count = _count > removed ? _count - removed : 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageUsersProvider);
    final allowed = canManage.asData?.value == true;
    _ensureLoaded(allowed);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Users'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
        actions: [
          if (allowed)
            IconButton(
              tooltip: 'Invitations',
              onPressed: () => context.push('/manage/users/invitations'),
              icon: const Icon(Icons.mail_outline_rounded),
            ),
        ],
      ),
      body: canManage.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => UserAdminDeniedBody(
          message: 'Could not verify user-management permissions.\n$error',
          onRetry: () => ref.invalidate(meUserProvider),
        ),
        data: (allowed) {
          if (!allowed) {
            return const UserAdminDeniedBody(
              message:
                  'You do not have permission to manage instance users. '
                  'Ask an administrator to grant the settings permission.',
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
                    hintText: 'Search users…',
                    hintStyle: const TextStyle(
                      color: AppTheme.onBackgroundSubtle,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.onBackgroundSubtle,
                    ),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchSubmitted('');
                            },
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
                  onSubmitted: _onSearchSubmitted,
                  onChanged: (_) => setState(() {}),
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
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.people_outline_rounded,
              title: 'No users',
              subtitle: 'No users match your search',
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
          final user = _items[index];
          return _UserTile(
            user: user,
            onTap: () => _openUserDetail(user),
          );
        },
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final ManageUser user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (user.email.isNotEmpty) user.email,
      user.statusLabel,
      if (user.fullUsername != null && user.fullUsername!.isNotEmpty)
        user.fullUsername!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  user.isActive
                      ? Icons.person_rounded
                      : Icons.person_off_outlined,
                  color: user.isActive
                      ? AppTheme.primary
                      : AppTheme.onBackgroundSubtle,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          color: user.isActive
                              ? AppTheme.onBackground
                              : AppTheme.onBackgroundMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.onBackgroundSubtle,
                ),
              ],
            ),
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
    if (code == 401) return 'Not authenticated (401)';
    return error.message ?? error.toString();
  }
  return error.toString();
}
