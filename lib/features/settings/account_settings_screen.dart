import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/auth/password_transport.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/app_refresh_indicator.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';

// ── Providers ───────────────────────────────────────────────────────────

final meUserProvider = FutureProvider.autoDispose<MeUser>((ref) async {
  return ref.watch(funkwhaleApiProvider).getMe();
});

// ── Screen ──────────────────────────────────────────────────────────────

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: AppTheme.background,
        leading: const AppBackButton(fallbackLocation: '/settings'),
      ),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _ErrorBody(
              message: _friendlyError(error),
              onRetry: () => ref.invalidate(meUserProvider),
            ),
        data:
            (user) => AppRefreshIndicator(
              onRefresh: () async => ref.invalidate(meUserProvider),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // ── Identity ──────────────────────────────────────────
                  SettingsSectionHeader(title: 'Profile'),
                  SettingsInfoTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Username',
                    subtitle:
                        user.fullUsername?.isNotEmpty == true
                            ? user.fullUsername!
                            : user.username,
                  ),
                  if (user.email != null && user.email!.isNotEmpty)
                    SettingsInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      subtitle: user.email!,
                    ),
                  SettingsActionTile(
                    icon: Icons.badge_outlined,
                    title: 'Display name',
                    subtitle:
                        user.name.trim().isEmpty
                            ? 'Not set — tap to edit'
                            : user.name,
                    onTap: () => _editDisplayName(context, ref, user),
                  ),
                  SettingsActionTile(
                    icon: Icons.visibility_outlined,
                    title: 'Activity visibility',
                    subtitle: user.privacyLevel.label,
                    onTap: () => _editPrivacyLevel(context, ref, user),
                  ),
                  SettingsActionTile(
                    icon: Icons.notes_outlined,
                    title: 'Bio',
                    subtitle:
                        (user.summaryText == null ||
                                user.summaryText!.trim().isEmpty)
                            ? 'Not set — tap to edit'
                            : user.summaryText!,
                    onTap: () => _editBio(context, ref, user),
                  ),

                  const SizedBox(height: 24),

                  // ── Security ──────────────────────────────────────────
                  SettingsSectionHeader(title: 'Security'),
                  SettingsActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    subtitle: 'Update the password for this account',
                    onTap: () => _changePassword(context, ref),
                  ),
                  SettingsActionTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'Change email',
                    subtitle: 'Update the email address for this account',
                    onTap: () => _changeEmail(context, ref, user),
                  ),
                  if (user.hasUsablePassword)
                    SettingsActionTile(
                      icon: Icons.security_outlined,
                      title: 'Two-factor authentication',
                      subtitle:
                          user.totpEnabled
                              ? (user.totpRequired
                                  ? 'Enabled (required by this server)'
                                  : 'Enabled — protect password sign-in')
                              : (user.totpRequired
                                  ? 'Required — set up an authenticator app'
                                  : 'Add an authenticator app (optional)'),
                      onTap: () => context.push('/settings/account/2fa'),
                    ),

                  const SizedBox(height: 24),

                  // ── Danger zone ───────────────────────────────────────
                  SettingsSectionHeader(title: 'Danger zone'),
                  SettingsActionTile(
                    icon: Icons.person_off_outlined,
                    title: 'Deactivate account',
                    subtitle:
                        'Disable your account. An admin can re-enable it later.',
                    iconColor: AppTheme.error,
                    onTap: () => _deactivateAccount(context, ref, user),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
      ),
    );
  }

  // ── Deactivate account ────────────────────────────────────────────────

  Future<void> _deactivateAccount(
    BuildContext context,
    WidgetRef ref,
    MeUser user,
  ) async {
    final result = await showShellDialog<_DeactivateConfirmResult>(
      context: context,
      builder:
          (ctx) => _DeactivateAccountDialog(
            username: user.username,
            requirePassword: user.hasUsablePassword,
          ),
    );
    if (result == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
    );

    try {
      final serverUrl = ref.read(authStateProvider).serverUrl;
      final passwordDigest =
          result.password == null
              ? null
              : hashPasswordForTransport(
                result.password!,
                serverUrl: serverUrl,
              );
      await ref
          .read(funkwhaleApiProvider)
          .deactivateMe(passwordDigest: passwordDigest);
      Analytics.track('account_deactivated');
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // loading
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Your account has been deactivated. Contact an admin to restore it.',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ── Edit display name ─────────────────────────────────────────────────

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    MeUser user,
  ) async {
    final controller = TextEditingController(text: user.name);
    final saved = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Display name',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 255,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: const InputDecoration(
                hintText: 'Your display name',
                counterText: '',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (saved != true || !context.mounted) {
      controller.dispose();
      return;
    }

    final name = controller.text.trim();
    controller.dispose();

    await _runSave(
      context,
      ref,
      action: () {
        return ref
            .read(funkwhaleApiProvider)
            .updateUserProfile(user.username, name: name);
      },
      successMessage: 'Display name updated',
      analyticsEvent: 'account_display_name_updated',
    );
  }

  // ── Edit privacy level ────────────────────────────────────────────────

  Future<void> _editPrivacyLevel(
    BuildContext context,
    WidgetRef ref,
    MeUser user,
  ) async {
    final selected = await showShellDialog<PrivacyLevel>(
      context: context,
      builder:
          (ctx) => SimpleDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            title: const Text(
              'Activity visibility',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            children: [
              for (final level in PrivacyLevel.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(level),
                  child: Row(
                    children: [
                      Icon(
                        level == user.privacyLevel
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color:
                            level == user.privacyLevel
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
                              level.label,
                              style: const TextStyle(
                                color: AppTheme.onBackground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              level.description,
                              style: const TextStyle(
                                color: AppTheme.onBackgroundMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
    );

    if (selected == null || selected == user.privacyLevel || !context.mounted) {
      return;
    }

    await _runSave(
      context,
      ref,
      action: () {
        return ref
            .read(funkwhaleApiProvider)
            .updateUserProfile(user.username, privacyLevel: selected);
      },
      successMessage: 'Activity visibility updated',
      analyticsEvent: 'account_privacy_level_updated',
    );
  }

  // ── Edit bio / summary ────────────────────────────────────────────────

  Future<void> _editBio(
    BuildContext context,
    WidgetRef ref,
    MeUser user,
  ) async {
    final controller = TextEditingController(text: user.summaryText ?? '');
    final saved = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Bio',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 5000,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: const InputDecoration(
                hintText: 'A short bio for your profile',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (saved != true || !context.mounted) {
      controller.dispose();
      return;
    }

    final text = controller.text;
    controller.dispose();

    await _runSave(
      context,
      ref,
      action: () {
        return ref
            .read(funkwhaleApiProvider)
            .updateUserProfile(user.username, summaryText: text);
      },
      successMessage: 'Bio updated',
      analyticsEvent: 'account_bio_updated',
    );
  }

  // ── Change password ───────────────────────────────────────────────────

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Change password',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: oldCtrl,
                      obscureText: true,
                      autofocus: true,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                      validator:
                          (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) return 'At least 8 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != newCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) {
      oldCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
      return;
    }

    final oldPassword = oldCtrl.text;
    final newPassword = newCtrl.text;
    final confirmPassword = confirmCtrl.text;
    oldCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();

    await _runSave(
      context,
      ref,
      action: () async {
        await ref
            .read(funkwhaleApiProvider)
            .changePassword(
              oldPassword: oldPassword,
              newPassword1: newPassword,
              newPassword2: confirmPassword,
            );
      },
      successMessage: 'Password changed',
      analyticsEvent: 'account_password_changed',
      refreshMe: false,
    );
  }

  // ── Change email ──────────────────────────────────────────────────────

  Future<void> _changeEmail(
    BuildContext context,
    WidgetRef ref,
    MeUser user,
  ) async {
    final emailCtrl = TextEditingController(text: user.email ?? '');
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showShellDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Change email',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'A confirmation link will be sent to the new address.',
                      style: TextStyle(
                        color: AppTheme.onBackgroundMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(labelText: 'New email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppTheme.onBackground),
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                      validator:
                          (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
    );

    if (confirmed != true || !context.mounted) {
      emailCtrl.dispose();
      passwordCtrl.dispose();
      return;
    }

    final email = emailCtrl.text.trim();
    final password = passwordCtrl.text;
    emailCtrl.dispose();
    passwordCtrl.dispose();

    await _runSave(
      context,
      ref,
      action: () async {
        await ref
            .read(funkwhaleApiProvider)
            .changeEmail(email: email, password: password);
      },
      successMessage: 'Check your inbox to confirm the new email address',
      analyticsEvent: 'account_email_change_requested',
      refreshMe: false,
    );
  }

  // ── Shared save helper ────────────────────────────────────────────────

  Future<void> _runSave(
    BuildContext context,
    WidgetRef ref, {
    required Future<dynamic> Function() action,
    required String successMessage,
    String? analyticsEvent,
    bool refreshMe = true,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
    );

    try {
      await action();
      if (analyticsEvent != null) {
        Analytics.track(analyticsEvent);
      }
      if (refreshMe) {
        ref.invalidate(meUserProvider);
      }
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

// ── Deactivate confirmation ─────────────────────────────────────────────

class _DeactivateConfirmResult {
  final String? password;
  const _DeactivateConfirmResult({this.password});
}

class _DeactivateAccountDialog extends StatefulWidget {
  final String username;
  final bool requirePassword;

  const _DeactivateAccountDialog({
    required this.username,
    required this.requirePassword,
  });

  @override
  State<_DeactivateAccountDialog> createState() =>
      _DeactivateAccountDialogState();
}

class _DeactivateAccountDialogState extends State<_DeactivateAccountDialog> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _usernameCtrl.addListener(() => setState(() {}));
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _usernameMatches => _usernameCtrl.text.trim() == widget.username;

  bool get _canConfirm {
    if (!_usernameMatches) return false;
    if (widget.requirePassword && _passwordCtrl.text.isEmpty) return false;
    return true;
  }

  void _submit() {
    if (!_canConfirm) return;
    Navigator.of(context).pop(
      _DeactivateConfirmResult(
        password: widget.requirePassword ? _passwordCtrl.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Deactivate account?',
        style: TextStyle(color: AppTheme.onBackground),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your account will be disabled and you will be signed out. '
              'An administrator can re-enable it later. Your data is not '
              'permanently deleted.\n\n'
              'Type your username to confirm:',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameCtrl,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: widget.username,
                labelStyle: const TextStyle(color: AppTheme.onBackgroundMuted),
                hintStyle: const TextStyle(color: AppTheme.onBackgroundSubtle),
                filled: true,
                fillColor: AppTheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction:
                  widget.requirePassword
                      ? TextInputAction.next
                      : TextInputAction.done,
              onSubmitted: (_) {
                if (!widget.requirePassword) _submit();
              },
            ),
            if (widget.requirePassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppTheme.onBackground),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  labelStyle: const TextStyle(
                    color: AppTheme.onBackgroundMuted,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppTheme.onBackgroundSubtle,
                    ),
                    onPressed:
                        () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _canConfirm ? _submit : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Deactivate'),
        ),
      ],
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────

String _friendlyError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      // Collect first validation message from DRF-style errors.
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
      if (data['detail'] != null) return data['detail'].toString();
    }
    if (error.response?.statusCode == 403) {
      return 'You do not have permission to do that';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Could not reach the server';
    }
  }
  return 'Something went wrong. Please try again.';
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.onBackgroundMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
