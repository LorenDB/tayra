import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';
import 'package:tayra/features/auth/oauth_authorize_service.dart';
import 'package:tayra/features/auth/oauth_scopes.dart';

// ── Screen ──────────────────────────────────────────────────────────────

/// Third-party OAuth 2.0 authorization consent UI at `/authorize`.
///
/// Query params match the Funkwhale / RFC 6749 authorization request:
/// `response_type`, `client_id`, `redirect_uri`, `scope`, `state`.
///
/// On Allow, POSTs to `/api/v1/oauth/authorize` (AJAX) and either redirects
/// the browser to the client `redirect_uri` or shows an out-of-band code.
class OAuthAuthorizeScreen extends ConsumerStatefulWidget {
  const OAuthAuthorizeScreen({super.key, required this.query});

  /// Full query map from the router (`GoRouterState.uri.queryParameters`).
  final Map<String, String> query;

  @override
  ConsumerState<OAuthAuthorizeScreen> createState() =>
      _OAuthAuthorizeScreenState();
}

class _OAuthAuthorizeScreenState extends ConsumerState<OAuthAuthorizeScreen> {
  OAuthApplicationInfo? _app;
  String? _loadError;
  bool _loadingApp = true;
  bool _submitting = false;
  String? _actionError;
  String? _issuedCode;
  String? _issuedRedirect;

  String get _clientId => widget.query['client_id'] ?? '';
  String get _redirectUri => widget.query['redirect_uri'] ?? '';
  String get _responseType => widget.query['response_type'] ?? 'code';
  String get _scope => widget.query['scope'] ?? 'read';
  String? get _state => widget.query['state'];

  bool get _paramsValid =>
      _clientId.isNotEmpty &&
      _redirectUri.isNotEmpty &&
      _responseType.isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadApp);
  }

  Future<void> _loadApp() async {
    if (!_paramsValid) {
      setState(() {
        _loadingApp = false;
        _loadError =
            'Missing required OAuth parameters (client_id, redirect_uri).';
      });
      return;
    }

    setState(() {
      _loadingApp = true;
      _loadError = null;
    });

    try {
      final app = await ref
          .read(oauthAuthorizeServiceProvider)
          .fetchApplication(_clientId);
      if (!mounted) return;
      setState(() {
        _app = app;
        _loadingApp = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingApp = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _onAllow() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _actionError = null;
    });

    final result = await ref
        .read(oauthAuthorizeServiceProvider)
        .authorize(
          allow: true,
          clientId: _clientId,
          redirectUri: _redirectUri,
          responseType: _responseType,
          // Prefer scopes registered on the app when the request was broad.
          scope: _scope.isNotEmpty ? _scope : (_app?.scopes ?? 'read'),
          state: _state,
        );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _actionError = result.errorDetail ?? 'Authorization failed.';
      });
      Analytics.track('oauth_authorize_denied_or_failed');
      return;
    }

    Analytics.track('oauth_authorize_allowed');

    final code = result.code;
    final redirect = result.redirectUri;

    if (isOobRedirectUri(_redirectUri) ||
        (redirect != null && isOobRedirectUri(redirect))) {
      setState(() {
        _submitting = false;
        _issuedCode = code;
        _issuedRedirect = redirect;
      });
      return;
    }

    if (redirect != null && redirect.isNotEmpty) {
      final ok = await _navigateToClient(redirect);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _submitting = false;
          _issuedCode = code;
          _issuedRedirect = redirect;
          _actionError =
              'Could not open the application redirect. Copy the code below.';
        });
      }
      // Leave _submitting true while the page navigates away on web.
      return;
    }

    setState(() {
      _submitting = false;
      _issuedCode = code;
      _actionError = 'No redirect URI returned. Copy the code if shown.';
    });
  }

  Future<void> _onDeny() async {
    if (_submitting) return;
    Analytics.track('oauth_authorize_denied');

    // Client-side access_denied avoids a DOT AJAX path that only parses `code`.
    if (isOobRedirectUri(_redirectUri)) {
      if (mounted) context.go('/');
      return;
    }

    final denied = Uri.parse(_redirectUri).replace(
      queryParameters: {
        'error': 'access_denied',
        if (_state != null && _state!.isNotEmpty) 'state': _state!,
      },
    );

    final ok = await _navigateToClient(denied.toString());
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _actionError = 'Could not return to the application.';
      });
    }
  }

  Future<bool> _navigateToClient(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      if (kIsWeb) {
        // Same-tab navigation so the third-party app receives the callback
        // in the window that started the flow.
        return launchUrl(uri, webOnlyWindowName: '_self');
      }
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Authorization code copied')));
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoWidget(size: 64, borderRadius: 16),
                  const SizedBox(height: 20),
                  Text('Authorize application', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'A third-party app wants access to your Funkwhale account',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onBackgroundMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_loadingApp)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )
                  else if (_loadError != null)
                    _ErrorCard(message: _loadError!, onRetry: _loadApp)
                  else if (_issuedCode != null)
                    _CodeCard(
                      code: _issuedCode!,
                      redirectUri: _issuedRedirect,
                      onCopy: () => _copyCode(_issuedCode!),
                      onDone: () => context.go('/'),
                    )
                  else if (_app != null)
                    _ConsentCard(
                      app: _app!,
                      requestScope: _scope,
                      redirectUri: _redirectUri,
                      submitting: _submitting,
                      error: _actionError,
                      onAllow: _onAllow,
                      onDeny: _onDeny,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Consent card ────────────────────────────────────────────────────────

class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.app,
    required this.requestScope,
    required this.redirectUri,
    required this.submitting,
    required this.onAllow,
    required this.onDeny,
    this.error,
  });

  final OAuthApplicationInfo app;
  final String requestScope;
  final String redirectUri;
  final bool submitting;
  final String? error;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Show request scopes when provided; otherwise app-registered scopes.
    final scopeSource = requestScope.trim().isNotEmpty
        ? requestScope
        : app.scopes;
    final scopes = expandOAuthScopes(scopeSource);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            app.name,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'wants to access your account',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.onBackgroundMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'This will allow the application to:',
            style: textTheme.labelLarge?.copyWith(
              color: AppTheme.onBackgroundMuted,
            ),
          ),
          const SizedBox(height: 12),
          ...scopes.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.label, style: textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
          if (!isOobRedirectUri(redirectUri)) ...[
            const SizedBox(height: 8),
            Text(
              'Redirect: $redirectUri',
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.onBackgroundSubtle,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: textTheme.bodySmall?.copyWith(color: AppTheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: submitting ? null : onAllow,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Allow'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: submitting ? null : onDeny,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.onBackgroundMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }
}

// ── OOB code card ───────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.onCopy,
    required this.onDone,
    this.redirectUri,
  });

  final String code;
  final String? redirectUri;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle, color: AppTheme.secondary, size: 40),
          const SizedBox(height: 12),
          Text(
            'Authorization granted',
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Copy this code and paste it into the application:',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.onBackgroundMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SelectableText(
            code,
            style: textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy code'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onDone, child: const Text('Done')),
          if (redirectUri != null && !isOobRedirectUri(redirectUri)) ...[
            const SizedBox(height: 8),
            Text(
              redirectUri!,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.onBackgroundSubtle,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error card ──────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: AppTheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Go home'),
          ),
        ],
      ),
    );
  }
}
