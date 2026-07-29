import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/error_state.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/user_admin/user_admin_denied.dart';
import 'package:tayra/features/user_admin/user_admin_provider.dart';

// ── Providers ───────────────────────────────────────────────────────────

final manageUserDetailProvider = FutureProvider.autoDispose
    .family<ManageUser, int>((ref, id) async {
      // Wait for permission before hitting manage APIs (avoids 403 on denied deep-links).
      final allowed = await ref.watch(canManageUsersProvider.future);
      if (!allowed) {
        throw StateError('Missing settings permission for user management');
      }
      return ref.watch(funkwhaleApiProvider).getManageUser(id);
    });

// ── Screen ──────────────────────────────────────────────────────────────

class ManageUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;

  const ManageUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<ManageUserDetailScreen> createState() =>
      _ManageUserDetailScreenState();
}

class _ManageUserDetailScreenState
    extends ConsumerState<ManageUserDetailScreen> {
  bool _saving = false;
  bool _initialized = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _quotaCtrl;
  bool _isActive = true;
  bool _isStaff = false;
  bool _isSuperuser = false;
  bool _permLibrary = false;
  bool _permModeration = false;
  bool _permSettings = false;

  @override
  void dispose() {
    if (_initialized) {
      _nameCtrl.dispose();
      _quotaCtrl.dispose();
    }
    super.dispose();
  }

  void _hydrate(ManageUser user, {bool force = false}) {
    if (_initialized && !force) return;
    if (_initialized) {
      _nameCtrl.text = user.name;
      _quotaCtrl.text = user.uploadQuota?.toString() ?? '';
    } else {
      _nameCtrl = TextEditingController(text: user.name);
      _quotaCtrl = TextEditingController(
        text: user.uploadQuota?.toString() ?? '',
      );
    }
    _isActive = user.isActive;
    _isStaff = user.isStaff;
    _isSuperuser = user.isSuperuser;
    _permLibrary = user.permissionLibrary;
    _permModeration = user.permissionModeration;
    _permSettings = user.permissionSettings;
    _initialized = true;
  }

  bool _hasStaffSuperuserChanges(ManageUser original) {
    return _isStaff != original.isStaff || _isSuperuser != original.isSuperuser;
  }

  Future<bool> _confirmStaffChange(ManageUser user) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change staff privileges?',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: Text(
          'You are changing staff/superuser flags for “${user.username}”. '
          'This affects who can access Django admin and elevated tools.',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<bool> _confirmSelfDeactivate(ManageUser user) async {
    final confirmed = await showShellDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Deactivate your own account?',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: const Text(
          'You are about to deactivate yourself. You may lose access '
          'immediately and need another admin to re-enable the account.',
          style: TextStyle(color: AppTheme.onBackgroundMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Deactivate me'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    // Second confirmation for self-deactivation.
    final again = await showShellDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Are you sure?',
          style: TextStyle(color: AppTheme.onBackground),
        ),
        content: Text(
          'Really deactivate “${user.username}”? This cannot be undone '
          'from this session.',
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
            child: const Text('Yes, deactivate'),
          ),
        ],
      ),
    );
    return again == true;
  }

  Future<void> _save(ManageUser original) async {
    final me = await ref.read(meUserProvider.future);
    if (!mounted) return;
    final deactivating = original.isActive && !_isActive;
    final isSelf = me.id == original.id;

    if (deactivating && isSelf) {
      final ok = await _confirmSelfDeactivate(original);
      if (!ok || !mounted) return;
    }

    if (_hasStaffSuperuserChanges(original)) {
      final ok = await _confirmStaffChange(original);
      if (!ok || !mounted) return;
    }

    final name = _nameCtrl.text.trim();
    final quotaText = _quotaCtrl.text.trim();
    int? uploadQuota;
    var clearQuota = false;
    if (quotaText.isEmpty) {
      if (original.uploadQuota != null) clearQuota = true;
    } else {
      uploadQuota = int.tryParse(quotaText);
      if (uploadQuota == null || uploadQuota < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload quota must be a non-negative integer'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(funkwhaleApiProvider)
          .updateManageUser(
            widget.userId,
            name: name,
            isActive: _isActive,
            isStaff: _isStaff,
            isSuperuser: _isSuperuser,
            uploadQuota: uploadQuota,
            clearUploadQuota: clearQuota,
            permissions: {
              'library': _permLibrary,
              'moderation': _permModeration,
              'settings': _permSettings,
            },
          );
      ref.invalidate(manageUserDetailProvider(widget.userId));
      if (mounted) {
        setState(() => _hydrate(updated, force: true));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: ${_friendlyError(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageUsersProvider);
    final allowed = canManage.valueOrNull == true;
    final detailAsync = ref.watch(manageUserDetailProvider(widget.userId));

    // Hydrate edit form once data arrives (not during pure build side-effects).
    ref.listen<AsyncValue<ManageUser>>(
      manageUserDetailProvider(widget.userId),
      (prev, next) {
        next.whenData((user) {
          if (!_initialized && mounted) {
            setState(() => _hydrate(user));
          }
        });
      },
    );
    // First frame when already loaded (listen may miss if value is ready).
    if (!_initialized && detailAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_initialized && detailAsync.hasValue) {
          setState(() => _hydrate(detailAsync.requireValue));
        }
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          detailAsync.maybeWhen(
            data: (u) => u.displayName,
            orElse: () => 'User',
          ),
        ),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/manage/users'),
        actions: [
          if (allowed && detailAsync.hasValue)
            TextButton(
              onPressed: _saving || !_initialized
                  ? null
                  : () => _save(detailAsync.requireValue),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
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
              message: 'You do not have permission to manage instance users.',
            );
          }
          return detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => InlineErrorState(
              message: _friendlyError(error),
              onRetry: () =>
                  ref.invalidate(manageUserDetailProvider(widget.userId)),
            ),
            data: (user) {
              if (!_initialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_saving) const LinearProgressIndicator(minHeight: 2),
                  SettingsSectionHeader(title: 'Identity'),
                  SettingsInfoTile(
                    icon: Icons.badge_outlined,
                    title: 'Username',
                    subtitle: user.username,
                  ),
                  SettingsInfoTile(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: user.email.isEmpty ? '—' : user.email,
                  ),
                  if (user.fullUsername != null &&
                      user.fullUsername!.isNotEmpty)
                    SettingsInfoTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'Full username',
                      subtitle: user.fullUsername!,
                    ),
                  SettingsInfoTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Joined',
                    subtitle: _formatDate(user.dateJoined),
                  ),
                  SettingsInfoTile(
                    icon: Icons.history_rounded,
                    title: 'Last activity',
                    subtitle: _formatDate(user.lastActivity),
                  ),
                  SettingsInfoTile(
                    icon: Icons.visibility_outlined,
                    title: 'Privacy',
                    subtitle: user.privacyLevel,
                  ),
                  const SizedBox(height: 8),
                  SettingsSectionHeader(title: 'Editable'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        labelStyle: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _quotaCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: InputDecoration(
                        labelText: 'Upload quota (MB)',
                        hintText: 'Empty = unlimited / default',
                        hintStyle: const TextStyle(
                          color: AppTheme.onBackgroundSubtle,
                        ),
                        labelStyle: const TextStyle(
                          color: AppTheme.onBackgroundMuted,
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceContainer,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Active',
                    subtitle: 'Inactive users cannot sign in',
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Staff',
                    subtitle: 'Can log into Django admin',
                    value: _isStaff,
                    onChanged: (v) => setState(() => _isStaff = v),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.security_rounded,
                    title: 'Superuser',
                    subtitle: 'All permissions without explicit grants',
                    value: _isSuperuser,
                    onChanged: (v) => setState(() => _isSuperuser = v),
                  ),
                  const SizedBox(height: 8),
                  SettingsSectionHeader(title: 'Permissions'),
                  SettingsSwitchTile(
                    icon: Icons.library_music_rounded,
                    title: 'Library',
                    subtitle: 'Manage libraries, uploads, tags, channels',
                    value: _permLibrary,
                    onChanged: (v) => setState(() => _permLibrary = v),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.gavel_rounded,
                    title: 'Moderation',
                    subtitle: 'Reports, domains, account requests',
                    value: _permModeration,
                    onChanged: (v) => setState(() => _permModeration = v),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Instance settings and user management',
                    value: _permSettings,
                    onChanged: (v) => setState(() => _permSettings = v),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
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
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $h:$min';
}

String _friendlyError(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) return 'Permission denied (403)';
    if (code == 401) return 'Not authenticated (401)';
    if (code == 404) return 'User not found (404)';
    return error.message ?? error.toString();
  }
  return error.toString();
}
