import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';
import 'package:tayra/features/auth/password_reset_service.dart';

/// Request a password-reset email (`POST /api/v1/auth/password/reset/`).
///
/// Opened from the login screen ("Forgot password?") or `/auth/password/reset`.
class PasswordResetRequestScreen extends ConsumerStatefulWidget {
  const PasswordResetRequestScreen({super.key, this.initialServerUrl});

  /// Pre-filled server URL when navigating from multi-server login.
  final String? initialServerUrl;

  @override
  ConsumerState<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends ConsumerState<PasswordResetRequestScreen> {
  final _serverController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  static const double _formMaxWidth = 440;

  bool get _hardcodedPod => AppPlatform.hasHardcodedPodUrl;

  @override
  void initState() {
    super.initState();
    if (_hardcodedPod) {
      _serverController.text = AppPlatform.hardcodedPodUrl!;
    } else if (widget.initialServerUrl != null &&
        widget.initialServerUrl!.trim().isNotEmpty) {
      _serverController.text = widget.initialServerUrl!.trim();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _formMaxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoWidget(size: 80, borderRadius: 20),
                    const SizedBox(height: 24),
                    Text('Reset password', style: textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      _sent
                          ? 'Check your inbox for a reset link.'
                          : 'Enter the email address for your account. '
                              'If it exists on this server, we will send a reset link.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_sent) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              color: AppTheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'If an account exists for that address, '
                              'you will receive an email with a link to choose a new password.',
                              style: textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to sign in'),
                        ),
                      ),
                    ] else ...[
                      if (!_hardcodedPod) ...[
                        TextFormField(
                          controller: _serverController,
                          decoration: const InputDecoration(
                            hintText: 'https://your.funkwhale.server',
                            prefixIcon: Icon(
                              Icons.dns_outlined,
                              color: AppTheme.onBackgroundSubtle,
                            ),
                          ),
                          style: const TextStyle(color: AppTheme.onBackground),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Server URL is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppTheme.onBackgroundSubtle,
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.onBackground),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          final email = v?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child:
                              _loading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Text('Send reset link'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text(
                          'Back to sign in',
                          style: TextStyle(color: AppTheme.onBackgroundMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final email = _emailController.text.trim();
    final server =
        _hardcodedPod
            ? (AppPlatform.hardcodedPodUrl ?? '')
            : _serverController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(passwordResetServiceProvider)
          .requestReset(email: email, serverUrl: server);
      if (!mounted) return;
      Analytics.track('password_reset_requested');
      setState(() {
        _loading = false;
        _sent = true;
      });
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check the URL and try again.';
      });
      assert(() {
        debugPrint('password reset request failed: $e');
        return true;
      }());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }
}
