import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';
import 'package:tayra/features/auth/signup_service.dart';

/// Create a new account (`POST /api/v1/auth/registration/`).
///
/// Opened from the login screen ("Create account") or `/signup`.
/// Query `?invitation=CODE` prefills the invitation field for invite deep links.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({
    super.key,
    this.initialServerUrl,
    this.initialInvitation,
  });

  /// Pre-filled server URL when navigating from multi-server login.
  final String? initialServerUrl;

  /// Pre-filled invitation code from `?invitation=` deep links.
  final String? initialInvitation;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _invitationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _done = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  static const double _formMaxWidth = 440;

  /// ASCII letters, digits, underscore — matches server [ASCIIUsernameValidator].
  static final RegExp _usernameCharset = RegExp(r'^[A-Za-z0-9_]+$');

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
    if (widget.initialInvitation != null &&
        widget.initialInvitation!.trim().isNotEmpty) {
      _invitationController.text = widget.initialInvitation!.trim();
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _invitationController.dispose();
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
                    Text('Create account', style: textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      _done
                          ? 'Your account is ready.'
                          : 'Sign up for this music library. '
                                'An invitation code may be required.',
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    if (_done) ...[
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
                              Icons.check_circle_outline,
                              color: AppTheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Account created successfully. '
                              'You can sign in with your new credentials.',
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
                          child: const Text('Go to sign in'),
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
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Username',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.onBackgroundSubtle,
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.onBackground),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.username],
                        validator: (v) {
                          final username = v?.trim() ?? '';
                          if (username.isEmpty) return 'Username is required';
                          if (!_usernameCharset.hasMatch(username)) {
                            return 'Letters, numbers, and _ only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
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
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          final email = v?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppTheme.onBackgroundSubtle,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.onBackgroundSubtle,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.onBackground),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        decoration: InputDecoration(
                          hintText: 'Confirm password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppTheme.onBackgroundSubtle,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.onBackgroundSubtle,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.onBackground),
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _invitationController,
                        decoration: const InputDecoration(
                          hintText: 'Invitation code (if required)',
                          prefixIcon: Icon(
                            Icons.card_giftcard_outlined,
                            color: AppTheme.onBackgroundSubtle,
                          ),
                        ),
                        style: const TextStyle(color: AppTheme.onBackground),
                        textInputAction: TextInputAction.go,
                        autocorrect: false,
                        enableSuggestions: false,
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
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text(
                          'Already have an account? Sign in',
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

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password1 = _passwordController.text;
    final password2 = _confirmController.text;
    final invitation = _invitationController.text.trim();
    final server = _hardcodedPod
        ? (AppPlatform.hardcodedPodUrl ?? '')
        : _serverController.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(signupServiceProvider)
          .register(
            username: username,
            email: email,
            password1: password1,
            password2: password2,
            invitation: invitation.isEmpty ? null : invitation,
            serverUrl: server,
          );
      if (!mounted) return;
      Analytics.track('signup_succeeded');
      setState(() {
        _loading = false;
        _done = true;
      });
    } on SignupException catch (e) {
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
        debugPrint('signup failed: $e');
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
