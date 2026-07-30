import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/api_repository.dart';
import 'package:tayra/core/api/models.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/auth/password_transport.dart';
import 'package:tayra/core/router/navigation_utils.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';
import 'package:tayra/core/widgets/settings_tiles.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';

// ── Providers ───────────────────────────────────────────────────────────

final totpStatusProvider = FutureProvider.autoDispose<TotpStatus>((ref) async {
  return ref.watch(funkwhaleApiProvider).getTotpStatus();
});

// ── Screen ──────────────────────────────────────────────────────────────

/// Manage TOTP 2FA from Account settings (`/settings/account/2fa`).
///
/// Also used as the forced-setup destination when the instance requires 2FA
/// (`/auth/2fa/setup`, [mandatory] true).
class TotpSettingsScreen extends ConsumerStatefulWidget {
  const TotpSettingsScreen({super.key, this.mandatory = false});

  /// When true, user cannot leave until 2FA is enabled (instance force_2fa).
  final bool mandatory;

  @override
  ConsumerState<TotpSettingsScreen> createState() => _TotpSettingsScreenState();
}

class _TotpSettingsScreenState extends ConsumerState<TotpSettingsScreen> {
  TotpSetup? _setup;
  List<String>? _recoveryCodes;
  bool _busy = false;
  String? _error;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(totpStatusProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.mandatory ? 'Set up 2FA' : 'Two-factor authentication',
        ),
        backgroundColor: AppTheme.background,
        // Hide back when mandatory so users must finish setup.
        leading:
            widget.mandatory
                ? const SizedBox.shrink()
                : const AppBackButton(fallbackLocation: '/settings/account'),
        automaticallyImplyLeading: !widget.mandatory,
        actions: [
          if (widget.mandatory)
            TextButton(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _friendlyError(e),
                  style: TextStyle(color: AppTheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (status) {
          if (_recoveryCodes != null) {
            return _RecoveryCodesView(
              codes: _recoveryCodes!,
              onDone: () {
                setState(() => _recoveryCodes = null);
                ref.invalidate(totpStatusProvider);
                ref.invalidate(meUserProvider);
                ref.read(authStateProvider.notifier).clearTotpSetupRequired();
                if (widget.mandatory && mounted) {
                  context.go('/');
                }
              },
            );
          }

          if (_setup != null) {
            return _SetupConfirmView(
              setup: _setup!,
              codeController: _codeController,
              busy: _busy,
              error: _error,
              onConfirm: _confirmSetup,
              onCancel:
                  widget.mandatory
                      ? null
                      : () => setState(() {
                        _setup = null;
                        _error = null;
                        _codeController.clear();
                      }),
            );
          }

          if (!status.isPasswordUser) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.info_outline,
                  size: 40,
                  color: AppTheme.onBackgroundMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'This account signs in with single sign-on and has no '
                  'local password. Authenticator 2FA applies to password '
                  'login only.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (widget.mandatory) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'This server requires two-factor authentication for '
                      'password accounts. Scan the QR code with an '
                      'authenticator app to continue.',
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
              SettingsSectionHeader(title: 'Authenticator app'),
              SettingsInfoTile(
                icon: Icons.security_outlined,
                title: status.enabled ? '2FA is enabled' : '2FA is off',
                subtitle:
                    status.enabled
                        ? (status.recoveryCodesRemaining > 0
                            ? '${status.recoveryCodesRemaining} recovery codes remaining'
                            : 'Protects password sign-in')
                        : 'Add an authenticator app for stronger security',
              ),
              if (status.force2fa && status.enabled)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'This instance requires 2FA. You cannot disable it while '
                    'that setting is on.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.onBackgroundMuted,
                    ),
                  ),
                ),
              if (!status.enabled)
                SettingsActionTile(
                  icon: Icons.add_moderator_outlined,
                  title: 'Set up authenticator',
                  subtitle: 'Use Google Authenticator, 1Password, Authy, etc.',
                  onTap: _busy ? () {} : _startSetup,
                )
              else if (!status.force2fa)
                SettingsActionTile(
                  icon: Icons.remove_moderator_outlined,
                  title: 'Disable 2FA',
                  subtitle: 'Requires your password and a current code',
                  onTap: _busy ? () {} : () => _disable(status),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startSetup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final setup = await ref.read(funkwhaleApiProvider).setupTotp();
      if (!mounted) return;
      setState(() {
        _setup = setup;
        _busy = false;
        _codeController.clear();
      });
      Analytics.track('totp_setup_started');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _confirmSetup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(funkwhaleApiProvider).confirmTotp(code);
      if (!mounted) return;
      setState(() {
        _setup = null;
        _recoveryCodes = result.recoveryCodes;
        _busy = false;
      });
      Analytics.track('totp_enabled');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _disable(TotpStatus status) async {
    final passwordCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
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
              'Disable two-factor authentication',
              style: TextStyle(color: AppTheme.onBackground),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.onBackground),
                    decoration: const InputDecoration(
                      labelText: 'Authenticator or recovery code',
                    ),
                    validator:
                        (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Disable'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) {
      passwordCtrl.dispose();
      codeCtrl.dispose();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(funkwhaleApiProvider)
          .disableTotp(
            passwordDigest: hashPasswordForTransport(passwordCtrl.text),
            code: codeCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _busy = false);
      ref.invalidate(totpStatusProvider);
      ref.invalidate(meUserProvider);
      Analytics.track('totp_disabled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _friendlyError(e);
      });
    } finally {
      passwordCtrl.dispose();
      codeCtrl.dispose();
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final detail = data['detail']?.toString();
        if (detail != null && detail.isNotEmpty) return detail;
        final err = data['error']?.toString();
        if (err == 'invalid_totp') {
          return 'Invalid authenticator or recovery code.';
        }
        if (err == 'invalid_password') return 'Invalid password.';
        if (err == 'force_2fa') {
          return 'This instance requires 2FA; it cannot be disabled.';
        }
        if (err == 'already_enabled') {
          return 'Two-factor authentication is already enabled.';
        }
        if (err != null && err.isNotEmpty) return err;
      }
      return 'Request failed (${error.response?.statusCode ?? 'network'}).';
    }
    return error.toString();
  }
}

// ── Setup confirm ───────────────────────────────────────────────────────

class _SetupConfirmView extends StatelessWidget {
  const _SetupConfirmView({
    required this.setup,
    required this.codeController,
    required this.busy,
    required this.error,
    required this.onConfirm,
    this.onCancel,
  });

  final TotpSetup setup;
  final TextEditingController codeController;
  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Scan this QR code with your authenticator app, then enter the '
          '6-digit code it shows.',
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: setup.otpauthUri,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Or enter this key manually:',
          style: textTheme.bodySmall?.copyWith(
            color: AppTheme.onBackgroundMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SelectableText(
          setup.secret,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 1.2,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: setup.secret));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Secret copied')));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy secret'),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 8,
          autofocus: true,
          style: const TextStyle(
            color: AppTheme.onBackground,
            letterSpacing: 4,
            fontSize: 20,
          ),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
            prefixIcon: Icon(
              Icons.pin_outlined,
              color: AppTheme.onBackgroundSubtle,
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => busy ? null : onConfirm(),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: AppTheme.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: busy ? null : onConfirm,
            child:
                busy
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Confirm and enable'),
          ),
        ),
        if (onCancel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.onBackgroundMuted),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Recovery codes ──────────────────────────────────────────────────────

class _RecoveryCodesView extends StatelessWidget {
  const _RecoveryCodesView({required this.codes, required this.onDone});

  final List<String> codes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final joined = codes.join('\n');
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AppTheme.primary,
          size: 40,
        ),
        const SizedBox(height: 16),
        Text(
          '2FA is enabled',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Save these recovery codes in a safe place. Each can be used once '
          'if you lose access to your authenticator. They will not be shown again.',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            joined,
            style: textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.6,
              color: AppTheme.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: joined));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recovery codes copied')),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copy codes'),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ),
      ],
    );
  }
}
