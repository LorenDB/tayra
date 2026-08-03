import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/auth/password_transport.dart';
import 'package:tayra/core/platform/app_platform.dart';
import 'package:tayra/core/router/app_router.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _totpController = TextEditingController();

  /// 0 = credentials (password login), 1 = OAuth/OIDC code paste, 2 = TOTP
  int _step = 0;
  bool _initializedFromAutoLogout = false;
  bool _obscurePassword = true;

  /// When true, code-paste step exchanges via OIDC one-time code endpoint.
  bool _ssoOob = false;

  /// SSO transaction binding for native OOB (must match login start + redeem).
  String? _ssoTxBinding;

  AuthMethods _authMethods = AuthMethods.disabled;
  bool _authMethodsLoading = false;
  String? _lastAuthMethodsServer;

  /// Match [OauthAuthorizeScreen] so login fields stay readable on wide web.
  static const double _formMaxWidth = 440;

  bool get _hardcodedPod => AppPlatform.hasHardcodedPodUrl;

  @override
  void initState() {
    super.initState();
    if (_hardcodedPod) {
      _serverController.text = AppPlatform.hardcodedPodUrl!;
    }
    _serverController.addListener(_onServerUrlChanged);
    // Defer discovery until after first frame (ref available).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAuthMethods());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromAutoLogout && !_hardcodedPod) {
      final authState = ref.read(authStateProvider);
      if (authState.wasAutoLoggedOut && authState.pendingServerUrl != null) {
        _serverController.text = authState.pendingServerUrl!;
        _initializedFromAutoLogout = true;
        _refreshAuthMethods();
      }
    }
  }

  @override
  void dispose() {
    _serverController.removeListener(_onServerUrlChanged);
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  void _onServerUrlChanged() {
    // Debounce-ish: only refetch when field loses focus via submit paths;
    // also refetch when value stabilizes after paste — simple delayed call.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _refreshAuthMethods();
    });
  }

  String _currentServer() {
    if (_hardcodedPod) return AppPlatform.hardcodedPodUrl ?? '';
    return _serverController.text.trim();
  }

  Future<void> _refreshAuthMethods() async {
    final server = _currentServer();
    if (server.isEmpty) {
      if (mounted) {
        setState(() {
          _authMethods = AuthMethods.disabled;
          _lastAuthMethodsServer = null;
        });
      }
      return;
    }
    if (_authMethodsLoading && _lastAuthMethodsServer == server) return;
    _authMethodsLoading = true;
    _lastAuthMethodsServer = server;
    final methods = await ref
        .read(authStateProvider.notifier)
        .fetchAuthMethods(server);
    if (!mounted) return;
    // Ignore stale responses if the user changed the URL mid-flight.
    if (_currentServer() != server) {
      _authMethodsLoading = false;
      return;
    }
    setState(() {
      _authMethods = methods;
      _authMethodsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
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
                  Text('Tayra', style: textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    _hardcodedPod
                        ? 'Sign in to your music library'
                        : 'Connect to your Funkwhale server',
                    style: textTheme.bodyMedium,
                  ),
                  if (_hardcodedPod && AppPlatform.hardcodedPodUrl != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      AppPlatform.hardcodedPodUrl!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.onBackgroundMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 48),

                  if (_step == 2) ...[
                    // ── TOTP second factor ─────────────────────────────
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
                            Icons.security_outlined,
                            color: AppTheme.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Two-factor authentication',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit code from your authenticator '
                            'app, or a recovery code.',
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _totpController,
                      autofocus: true,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        color: AppTheme.onBackground,
                        letterSpacing: 2,
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        hintText: '123456 or recovery code',
                        prefixIcon: Icon(
                          Icons.pin_outlined,
                          color: AppTheme.onBackgroundSubtle,
                        ),
                      ),
                      autofillHints: const [AutofillHints.oneTimeCode],
                      onSubmitted: (_) => _submitTotp(),
                    ),
                    const SizedBox(height: 16),
                    if (authState.error != null) ...[
                      Text(
                        authState.error!,
                        style: TextStyle(color: AppTheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _submitTotp,
                        child:
                            authState.isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () {
                                ref
                                    .read(authStateProvider.notifier)
                                    .cancelTotpChallenge();
                                setState(() {
                                  _step = 0;
                                  _totpController.clear();
                                });
                              },
                      child: const Text(
                        'Back to password login',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    ),
                  ] else if (_step == 0) ...[
                    if (authState.wasAutoLoggedOut) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Your session expired. Sign back in to continue where you left off.',
                          style: textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // AutofillGroup groups fields so password managers treat
                    // username + password (and server URL) as one login form.
                    AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_hardcodedPod) ...[
                            TextField(
                              controller: _serverController,
                              decoration: const InputDecoration(
                                hintText: 'https://your.funkwhale.server',
                                prefixIcon: Icon(
                                  Icons.dns_outlined,
                                  color: AppTheme.onBackgroundSubtle,
                                ),
                              ),
                              style: const TextStyle(
                                color: AppTheme.onBackground,
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [AutofillHints.url],
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Username',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: AppTheme.onBackgroundSubtle,
                              ),
                            ),
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                            ),
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            autofillHints: const [AutofillHints.username],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
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
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              ),
                            ),
                            style: const TextStyle(
                              color: AppTheme.onBackground,
                            ),
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.go,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submitPasswordLogin(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (authState.error != null) ...[
                      Text(
                        authState.error!,
                        style: TextStyle(color: AppTheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            authState.isLoading ? null : _submitPasswordLogin,
                        child:
                            authState.isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Sign In'),
                      ),
                    ),
                    if (_authMethods.oidcEnabled) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppTheme.divider),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.onBackgroundMuted,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppTheme.divider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authState.isLoading ? null : _startSso,
                          icon: const Icon(Icons.login, size: 18),
                          label: Text(
                            'Sign in with ${_authMethods.oidcDisplayName}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () {
                                final server = _currentServer();
                                final uri = Uri(
                                  path: '/auth/password/reset',
                                  queryParameters:
                                      server.isEmpty
                                          ? null
                                          : {'server': server},
                                );
                                context.go(uri.toString());
                              },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          authState.isLoading
                              ? null
                              : () {
                                final server = _currentServer();
                                final uri = Uri(
                                  path: '/signup',
                                  queryParameters:
                                      server.isEmpty
                                          ? null
                                          : {'server': server},
                                );
                                context.go(uri.toString());
                              },
                      child: const Text(
                        'Create account',
                        style: TextStyle(color: AppTheme.onBackgroundMuted),
                      ),
                    ),
                    if (!_hardcodedPod) ...[
                      TextButton(
                        onPressed:
                            authState.isLoading
                                ? null
                                : () async {
                                  await ref
                                      .read(authStateProvider.notifier)
                                      .registerApp(_serverController.text);
                                  if (!mounted) return;
                                  final s = ref.read(authStateProvider);
                                  if (s.clientId != null && s.error == null) {
                                    setState(() {
                                      _step = 1;
                                      _ssoOob = false;
                                    });
                                    _openAuthUrl();
                                  }
                                },
                        child: const Text(
                          'Use browser authorization instead',
                          style: TextStyle(color: AppTheme.onBackgroundMuted),
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.open_in_browser_rounded,
                            color: AppTheme.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _ssoOob
                                ? 'Sign in with SSO in your browser'
                                : 'Authorize in your browser',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ssoOob
                                ? 'Complete SSO in the browser, then paste the sign-in code below.'
                                : 'Log in and authorize the app, then paste the code below.',
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _ssoOob ? _startSso : _openAuthUrl,
                              icon: const Icon(Icons.launch, size: 18),
                              label: Text(
                                _ssoOob ? 'Open SSO' : 'Open Browser',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText:
                            _ssoOob
                                ? 'Paste sign-in code'
                                : 'Paste authorization code',
                        prefixIcon: const Icon(
                          Icons.key,
                          color: AppTheme.onBackgroundSubtle,
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.onBackground),
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _submitCode(),
                    ),
                    const SizedBox(height: 16),
                    if (authState.error != null) ...[
                      Text(
                        authState.error!,
                        style: TextStyle(color: AppTheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _submitCode,
                        child:
                            authState.isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          () => setState(() {
                            _step = 0;
                            _ssoOob = false;
                          }),
                      child: const Text(
                        'Back to password login',
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

  Future<void> _submitPasswordLogin() async {
    final server = _currentServer();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (server.isEmpty || username.isEmpty || password.isEmpty) return;

    final ok = await ref
        .read(authStateProvider.notifier)
        .loginWithPassword(
          serverUrl: server,
          username: username,
          password: password,
        );
    if (!mounted) return;

    if (ok) {
      // Persist credentials into the platform password manager when offered.
      TextInput.finishAutofillContext(shouldSave: true);
      Analytics.track('login_password_success');
      return;
    }

    final authState = ref.read(authStateProvider);
    // Password OK but TOTP required.
    if (authState.needsTotp) {
      setState(() {
        _step = 2;
        _totpController.clear();
      });
      return;
    }

    // Endpoint missing (stock Funkwhale) → OAuth OOB fallback.
    if (authState.error != null) return;

    await ref.read(authStateProvider.notifier).registerApp(server);
    if (!mounted) return;
    final after = ref.read(authStateProvider);
    if (after.clientId != null && after.error == null) {
      setState(() {
        _step = 1;
        _ssoOob = false;
      });
      _openAuthUrl();
    }
  }

  Future<void> _submitTotp() async {
    final code = _totpController.text.trim();
    if (code.isEmpty) return;
    final ok = await ref
        .read(authStateProvider.notifier)
        .completeTotpLogin(totpCode: code);
    if (!mounted) return;
    if (ok) {
      Analytics.track('login_password_success');
    }
  }

  Future<void> _startSso() async {
    final server = _currentServer();
    if (server.isEmpty) return;

    // Persist server URL so OOB exchange / native callback can find it.
    // Also stash any deep-link `from=` so the OIDC return path can restore it
    // after the full-page IdP round-trip on web.
    final prefsServer = server.startsWith('http') ? server : 'https://$server';
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    final safeFrom = safeInternalPath(from);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'server_url',
        prefsServer.replaceAll(RegExp(r'/$'), ''),
      );
      if (safeFrom != null) {
        await prefs.setString(kPostLoginRedirectKey, safeFrom);
      } else {
        await prefs.remove(kPostLoginRedirectKey);
      }
    } catch (_) {}

    final notifier = ref.read(authStateProvider.notifier);
    final clientRedirect =
        kIsWeb ? _webSsoCallbackUrl() : 'urn:ietf:wg:oauth:2.0:oob';

    // Native OOB must prove the same tx binding when redeeming the code (H3).
    // Web relies on the HttpOnly oidc_tx cookie set by the API.
    final txBinding = kIsWeb ? null : newOidcTxBinding();

    final loginPath = _authMethods.oidcLoginPath;
    var loginUrl = notifier.buildOidcLoginUrl(
      serverUrl: server,
      clientRedirect: clientRedirect,
      loginPath: loginPath,
      txBinding: txBinding,
    );

    // On web, relative paths must become absolute for navigation.
    if (kIsWeb && loginUrl.startsWith('/')) {
      final base = Uri.base;
      loginUrl =
          '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}$loginUrl';
    } else if (!loginUrl.startsWith('http')) {
      final normalized = server.startsWith('http') ? server : 'https://$server';
      final origin = normalized.replaceAll(RegExp(r'/$'), '');
      loginUrl = '$origin$loginUrl';
    }

    if (!kIsWeb) {
      setState(() {
        _step = 1;
        _ssoOob = true;
        _ssoTxBinding = txBinding;
      });
    }

    await launchUrl(
      Uri.parse(loginUrl),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
  }

  String _webSsoCallbackUrl() {
    final base = Uri.base;
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    return '$origin/auth/sso/callback';
  }

  void _openAuthUrl() async {
    final url = ref.read(authStateProvider.notifier).getAuthorizationUrl();
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;
    if (_ssoOob) {
      final server = _currentServer();
      if (server.isEmpty) return;
      await ref.read(authStateProvider.notifier).completeOidcLogin(
            serverUrl: server,
            code: _codeController.text,
            txBinding: _ssoTxBinding,
          );
      return;
    }
    await ref
        .read(authStateProvider.notifier)
        .exchangeCode(_codeController.text);
  }
}
