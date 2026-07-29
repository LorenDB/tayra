import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/platform/app_platform.dart';
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

  /// 0 = credentials (password login), 1 = OAuth code fallback
  int _step = 0;
  bool _initializedFromAutoLogout = false;
  bool _obscurePassword = true;

  /// Match [OauthAuthorizeScreen] so login fields stay readable on wide web.
  static const double _formMaxWidth = 440;

  bool get _hardcodedPod => AppPlatform.hasHardcodedPodUrl;

  @override
  void initState() {
    super.initState();
    if (_hardcodedPod) {
      _serverController.text = AppPlatform.hardcodedPodUrl!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromAutoLogout && !_hardcodedPod) {
      final authState = ref.read(authStateProvider);
      if (authState.wasAutoLoggedOut && authState.pendingServerUrl != null) {
        _serverController.text = authState.pendingServerUrl!;
        _initializedFromAutoLogout = true;
      }
    }
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
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

                  if (_step == 0) ...[
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
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
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
                        onPressed: authState.isLoading
                            ? null
                            : _submitPasswordLogin,
                        child: authState.isLoading
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
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              final server = _hardcodedPod
                                  ? (AppPlatform.hardcodedPodUrl ?? '')
                                  : _serverController.text.trim();
                              final uri = Uri(
                                path: '/auth/password/reset',
                                queryParameters: server.isEmpty
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
                      onPressed: authState.isLoading
                          ? null
                          : () {
                              final server = _hardcodedPod
                                  ? (AppPlatform.hardcodedPodUrl ?? '')
                                  : _serverController.text.trim();
                              final uri = Uri(
                                path: '/signup',
                                queryParameters: server.isEmpty
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
                        onPressed: authState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(authStateProvider.notifier)
                                    .registerApp(_serverController.text);
                                if (!mounted) return;
                                final s = ref.read(authStateProvider);
                                if (s.clientId != null && s.error == null) {
                                  setState(() => _step = 1);
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
                            'Authorize in your browser',
                            style: textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Log in and authorize the app, then paste the code below.',
                            style: textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openAuthUrl,
                              icon: const Icon(Icons.launch, size: 18),
                              label: const Text('Open Browser'),
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
                      decoration: const InputDecoration(
                        hintText: 'Paste authorization code',
                        prefixIcon: Icon(
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
                        child: authState.isLoading
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
                      onPressed: () => setState(() => _step = 0),
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
    final server = _hardcodedPod
        ? (AppPlatform.hardcodedPodUrl ?? '')
        : _serverController.text.trim();
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

    // Endpoint missing (stock Funkwhale) → OAuth OOB fallback.
    final authState = ref.read(authStateProvider);
    if (authState.error != null) return;

    await ref.read(authStateProvider.notifier).registerApp(server);
    if (!mounted) return;
    final after = ref.read(authStateProvider);
    if (after.clientId != null && after.error == null) {
      setState(() => _step = 1);
      _openAuthUrl();
    }
  }

  void _openAuthUrl() async {
    final url = ref.read(authStateProvider.notifier).getAuthorizationUrl();
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;
    await ref
        .read(authStateProvider.notifier)
        .exchangeCode(_codeController.text);
  }
}
