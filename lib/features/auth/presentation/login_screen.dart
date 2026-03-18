import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/core/theme/app_theme.dart';
import 'package:tayra/core/widgets/logo_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverController = TextEditingController();
  final _codeController = TextEditingController();
  int _step = 0; // 0 = server URL, 1 = auth code

  @override
  void dispose() {
    _serverController.dispose();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / branding area
                const LogoWidget(size: 80, borderRadius: 20),
                const SizedBox(height: 24),
                Text('Tayra', style: textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Connect to your Funkwhale server',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),

                if (_step == 0) ...[
                  // Step 1: Server URL
                  TextField(
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
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _connectToServer(),
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
                      onPressed: authState.isLoading ? null : _connectToServer,
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
                              : const Text('Connect'),
                    ),
                  ),
                ] else ...[
                  // Step 2: Authorization code
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
                          'A browser window will open. Log in and authorize the app, then paste the code below.',
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    onPressed: () {
                      setState(() => _step = 0);
                    },
                    child: const Text(
                      'Use a different server',
                      style: TextStyle(color: AppTheme.onBackgroundMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _connectToServer() async {
    if (_serverController.text.trim().isEmpty) return;
    await ref
        .read(authStateProvider.notifier)
        .registerApp(_serverController.text);

    // Check if widget is still mounted after async operation
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    if (authState.clientId != null && authState.error == null) {
      setState(() => _step = 1);
    }
  }

  void _openAuthUrl() async {
    final url = ref.read(authStateProvider.notifier).getAuthorizationUrl();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;
    await ref
        .read(authStateProvider.notifier)
        .exchangeCode(_codeController.text);
    // Note: No mounted check needed here because exchangeCode returning true
    // will trigger router redirect via authStateProvider which properly handles navigation
  }
}
