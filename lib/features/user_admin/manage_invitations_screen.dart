import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/empty_state.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/user_admin/user_admin_denied.dart';
import 'package:tayra/features/user_admin/user_admin_provider.dart';

// ── Screen ──────────────────────────────────────────────────────────────

class ManageInvitationsScreen extends ConsumerStatefulWidget {
  const ManageInvitationsScreen({super.key});

  @override
  ConsumerState<ManageInvitationsScreen> createState() =>
      _ManageInvitationsScreenState();
}

class _ManageInvitationsScreenState
    extends ConsumerState<ManageInvitationsScreen> {
  final _scrollController = ScrollController();
  final List<ManageInvitation> _items = [];
  int _page = 1;
  int _count = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _creating = false;
  bool _loadStarted = false;
  String? _error;

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
      final res = await api.getManageInvitations(page: 1, pageSize: 25);
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
      final res = await api.getManageInvitations(page: next, pageSize: 25);
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

  Future<void> _createInvitation() async {
    setState(() => _creating = true);
    try {
      final created = await ref
          .read(funkwhaleApiProvider)
          .createManageInvitation();
      if (!mounted) return;
      final code = created.code ?? '';
      if (code.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: code));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            code.isEmpty
                ? 'Invitation created'
                : 'Invitation created — code copied: $code',
          ),
        ),
      );
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Create failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _copyCode(ManageInvitation invitation) async {
    final code = invitation.code;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied: $code')));
  }

  Future<void> _deleteOpen(ManageInvitation invitation) async {
    if (!invitation.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only open invitations can be deleted')),
      );
      return;
    }
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete invitation?',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: Text(
          'Delete open invitation code “${invitation.code ?? invitation.id}”?',
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
      await ref
          .read(funkwhaleApiProvider)
          .manageInvitationAction(action: 'delete', ids: [invitation.id]);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation deleted')));
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageUsersProvider);
    final allowed = canManage.valueOrNull == true;
    _ensureLoaded(allowed);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Invitations'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/manage/users'),
        actions: [
          if (allowed)
            IconButton(
              tooltip: 'Create invitation',
              onPressed: _creating ? null : _createInvitation,
              icon: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
            ),
        ],
      ),
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: _creating ? null : _createInvitation,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New invitation'),
            )
          : null,
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
                  'You do not have permission to manage invitations. '
                  'Ask an administrator to grant the settings permission.',
            );
          }
          return _buildBody();
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
              icon: Icons.mail_outline_rounded,
              title: 'No invitations',
              subtitle: 'Create an invitation to let someone join',
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
          final inv = _items[index];
          return _InvitationTile(
            invitation: inv,
            onCopy: () => _copyCode(inv),
            onDelete: inv.isOpen ? () => _deleteOpen(inv) : null,
          );
        },
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────

class _InvitationTile extends StatelessWidget {
  final ManageInvitation invitation;
  final VoidCallback onCopy;
  final VoidCallback? onDelete;

  const _InvitationTile({
    required this.invitation,
    required this.onCopy,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final code = invitation.code?.isNotEmpty == true
        ? invitation.code!
        : '#${invitation.id}';
    final subtitle = [
      if (invitation.isOpen) 'Open' else 'Used / expired',
      if (invitation.ownerUsername != null) 'by ${invitation.ownerUsername}',
      if (invitation.expirationDate != null)
        'exp ${_formatDate(invitation.expirationDate)}',
      if (invitation.invitedUsername != null) '→ ${invitation.invitedUsername}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              invitation.isOpen
                  ? Icons.mark_email_unread_outlined
                  : Icons.mark_email_read_outlined,
              color: invitation.isOpen
                  ? AppTheme.primary
                  : AppTheme.onBackgroundSubtle,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: AppTheme.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
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
            IconButton(
              tooltip: 'Copy code',
              onPressed: invitation.code?.isNotEmpty == true ? onCopy : null,
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: AppTheme.error.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
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
