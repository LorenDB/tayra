import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';

/// Completes OIDC SSO after the API redirects back with `?code=` or `?error=`.
///
/// Web path: `/auth/sso/callback?code=…`
class OidcCallbackScreen extends ConsumerStatefulWidget {
  const OidcCallbackScreen({super.key});

  @override
  ConsumerState<OidcCallbackScreen> createState() => _OidcCallbackScreenState();
}

class _OidcCallbackScreenState extends ConsumerState<OidcCallbackScreen> {
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _complete();
  }

  Future<void> _complete() async {
    final uri = GoRouterState.of(context).uri;
    final error = uri.queryParameters['error'];
    final code = uri.queryParameters['code'];

    if (error != null && error.isNotEmpty) {
      setState(() => _error = _humanizeError(error));
      return;
    }
    if (code == null || code.isEmpty) {
      setState(() => _error = 'Missing sign-in code. Try SSO again.');
      return;
    }

    final server = await _resolveServerUrl();
    if (server == null || server.isEmpty) {
      setState(
        () =>
            _error =
                'Could not determine server URL for SSO. Sign in from the login page.',
      );
      return;
    }

    final ok = await ref
        .read(authStateProvider.notifier)
        .completeOidcLogin(serverUrl: server, code: code);
    if (!mounted) return;
    if (ok) {
      // Restore deep link saved before the IdP full-page redirect, if any.
      var dest = '/';
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(kPostLoginRedirectKey);
        await prefs.remove(kPostLoginRedirectKey);
        final safe = safeInternalPath(saved);
        if (safe != null) dest = safe;
      } catch (_) {}
      if (!mounted) return;
      context.go(dest);
      return;
    }
    final authError = ref.read(authStateProvider).error;
    setState(() => _error = authError ?? 'SSO login failed.');
  }

  Future<String?> _resolveServerUrl() async {
    if (AppPlatform.hasHardcodedPodUrl) {
      return AppPlatform.hardcodedPodUrl;
    }
    if (kIsWeb) {
      // Same-origin SPA: origin is the pod.
      final base = Uri.base;
      return '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    if (saved != null && saved.isNotEmpty) return saved;
    final pending = ref.read(authStateProvider).pendingServerUrl;
    return pending;
  }

  static String _humanizeError(String code) {
    switch (code) {
      case 'user_not_found':
        return 'No local account matches this SSO user.';
      case 'inactive':
        return 'This account was disabled.';
      case 'access_denied':
        return 'SSO sign-in was cancelled or denied.';
      case 'invalid_id_token':
      case 'token_exchange_failed':
        return 'Identity provider authentication failed.';
      default:
        return 'SSO login failed ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child:
                _error == null
                    ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          'Completing sign-in…',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppTheme.error,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SSO sign-in failed',
                          style: textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onBackgroundMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
