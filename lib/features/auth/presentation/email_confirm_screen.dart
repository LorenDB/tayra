import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';
import 'package:tayra/features/auth/email_confirm_service.dart';

/// Confirm an email address from a verification link.
///
/// Email template URL:
/// `{FUNKWHALE_URL}/auth/email/confirm?key=…`
///
/// Posts the key to `/api/v1/auth/registration/verify-email/` automatically
/// when the link is valid (no manual form step).
class EmailConfirmScreen extends ConsumerStatefulWidget {
  const EmailConfirmScreen({super.key, required this.keyToken});

  /// Confirmation key from the email link (`?key=` or path segment).
  final String keyToken;

  @override
  ConsumerState<EmailConfirmScreen> createState() => _EmailConfirmScreenState();
}

class _EmailConfirmScreenState extends ConsumerState<EmailConfirmScreen> {
  bool _loading = false;
  bool _done = false;
  String? _error;

  static const double _formMaxWidth = 440;

  bool get _linkValid => widget.keyToken.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_linkValid) {
      // Auto-confirm on open (matches stock Funkwhale UX).
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoWidget(size: 80, borderRadius: 20),
                  const SizedBox(height: 24),
                  Text('Confirm your email', style: textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (!_linkValid) ...[
                    Text(
                      'This confirmation link is incomplete or invalid. '
                      'Request a new one by signing in or signing up again.',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to sign in'),
                      ),
                    ),
                  ] else if (_done) ...[
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
                            color: AppTheme.secondary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your email address has been verified. '
                            'You can sign in now.',
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
                        child: const Text('Sign in'),
                      ),
                    ),
                  ] else if (_loading) ...[
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verifying…',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.onBackgroundMuted,
                      ),
                    ),
                  ] else if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: const Text('Try again'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
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
    );
  }

  String get _subtitle {
    if (!_linkValid) {
      return 'We could not read a verification key from this link.';
    }
    if (_done) return 'Email confirmed.';
    if (_error != null) return 'Verification failed.';
    return 'Confirming your email address…';
  }

  Future<void> _submit() async {
    if (!_linkValid || _loading || _done) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // On web the SPA is same-origin with the API. On native the email link
      // normally opens the pod in a browser; if we ever land here without a
      // baked URL, fall back to FUNKWHALE_URL when present.
      final serverUrl =
          AppPlatform.hasHardcodedPodUrl
              ? AppPlatform.hardcodedPodUrl
              : (kIsWeb ? null : AppPlatform.hardcodedPodUrl);

      await ref
          .read(emailConfirmServiceProvider)
          .confirmEmail(key: widget.keyToken, serverUrl: serverUrl);
      if (!mounted) return;
      Analytics.track('email_confirmed');
      setState(() {
        _loading = false;
        _done = true;
      });
    } on EmailConfirmException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Please try again.';
      });
      assert(() {
        debugPrint('email confirm failed: $e');
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
