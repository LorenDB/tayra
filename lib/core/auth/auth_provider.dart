import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// ── Secure storage ──────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// ── Auth state ──────────────────────────────────────────────────────────

class AuthState {
  final String? serverUrl;
  final String? accessToken;
  final String? refreshTokenValue;
  final String? clientId;
  final String? clientSecret;
  final bool isLoading;
  final bool isCheckingAuth;
  final String? error;

  const AuthState({
    this.serverUrl,
    this.accessToken,
    this.refreshTokenValue,
    this.clientId,
    this.clientSecret,
    this.isLoading = false,
    this.isCheckingAuth = false,
    this.error,
  });

  bool get isAuthenticated => accessToken != null && serverUrl != null;

  AuthState copyWith({
    String? serverUrl,
    String? accessToken,
    String? refreshTokenValue,
    String? clientId,
    String? clientSecret,
    bool? isLoading,
    bool? isCheckingAuth,
    String? error,
  }) {
    return AuthState(
      serverUrl: serverUrl ?? this.serverUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshTokenValue: refreshTokenValue ?? this.refreshTokenValue,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      error: error,
    );
  }
}

// ── Auth change notifier for router ─────────────────────────────────────

/// A ChangeNotifier that wraps auth state for use with go_router's refreshListenable.
/// This allows the router to listen for auth changes without rebuilding the entire router.
class AuthChangeNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();

  AuthState get state => _state;

  void updateState(AuthState newState) {
    final wasAuthenticated = _state.isAuthenticated;
    final wasCheckingAuth = _state.isCheckingAuth;
    _state = newState;

    // Notify listeners when authentication status or checking state changes
    // (isCheckingAuth changes trigger router redirects away from the splash screen)
    if (wasAuthenticated != newState.isAuthenticated ||
        wasCheckingAuth != newState.isCheckingAuth) {
      notifyListeners();
    }
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();

  // Keep the change notifier in sync with auth state
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    notifier.updateState(next);
  });

  // Initialize with current state
  notifier.updateState(ref.read(authStateProvider));

  return notifier;
});

// ── Auth notifier ───────────────────────────────────────────────────────

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _loadSavedAuth());
    return const AuthState(isCheckingAuth: true);
  }

  static const _keyServerUrl = 'server_url';
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyClientId = 'client_id';
  static const _keyClientSecret = 'client_secret';
  static const _redirectUri = 'urn:ietf:wg:oauth:2.0:oob';
  static const _scopes = 'read write';

  Future<String> _getAppName() async {
    return 'Tayra (${Platform.localHostname})';
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString(_keyServerUrl);
      if (serverUrl == null) {
        state = const AuthState();
        return;
      }

      final accessToken = await _storage.read(key: _keyAccessToken);
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      final clientId = await _storage.read(key: _keyClientId);
      final clientSecret = await _storage.read(key: _keyClientSecret);

      if (accessToken != null) {
        state = AuthState(
          serverUrl: serverUrl,
          accessToken: accessToken,
          refreshTokenValue: refreshToken,
          clientId: clientId,
          clientSecret: clientSecret,
        );
      } else {
        state = const AuthState();
      }
    } catch (_) {
      // Ignore errors on initial load
      state = const AuthState();
    }
  }

  /// Step 1: Register an OAuth application on the server.
  Future<void> registerApp(String serverUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    // Normalize URL
    String url = serverUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    try {
      final dio = Dio();
      final response = await dio.post(
        '$url/api/v1/oauth/apps/',
        data: {
          'name': await _getAppName(),
          'scopes': _scopes,
          'redirect_uris': _redirectUri,
        },
      );

      final clientId = response.data['client_id'] as String;
      final clientSecret = response.data['client_secret'] as String?;

      state = state.copyWith(
        serverUrl: url,
        clientId: clientId,
        clientSecret: clientSecret ?? '',
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not connect to server. Check the URL and try again.',
      );
    }
  }

  /// Returns the authorization URL for the user to visit.
  String getAuthorizationUrl() {
    final serverUrl = state.serverUrl!;
    final clientId = state.clientId!;
    return '$serverUrl/authorize?'
        'response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&scope=${Uri.encodeComponent(_scopes)}';
  }

  /// Step 2: Exchange the authorization code for tokens.
  Future<bool> exchangeCode(String code) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final dio = Dio();
      final response = await dio.post(
        '${state.serverUrl}/api/v1/oauth/token/',
        data: {
          'grant_type': 'authorization_code',
          'code': code.trim(),
          'client_id': state.clientId,
          'client_secret': state.clientSecret,
          'redirect_uri': _redirectUri,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final accessToken = response.data['access_token'] as String;
      final refreshToken = response.data['refresh_token'] as String?;

      state = state.copyWith(
        accessToken: accessToken,
        refreshTokenValue: refreshToken,
        isLoading: false,
      );

      await _saveAuth();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to authenticate. Check the code and try again.',
      );
      return false;
    }
  }

  /// Refresh the access token using the refresh token.
  Future<bool> refreshToken() async {
    if (state.refreshTokenValue == null) return false;

    try {
      final dio = Dio();
      final response = await dio.post(
        '${state.serverUrl}/api/v1/oauth/token/',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': state.refreshTokenValue,
          'client_id': state.clientId,
          'client_secret': state.clientSecret,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final accessToken = response.data['access_token'] as String;
      final refreshTokenNew = response.data['refresh_token'] as String?;

      state = state.copyWith(
        accessToken: accessToken,
        refreshTokenValue: refreshTokenNew ?? state.refreshTokenValue,
      );

      await _saveAuth();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyClientId);
    await _storage.delete(key: _keyClientSecret);
    state = const AuthState();
  }

  Future<void> _saveAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, state.serverUrl!);
    await _storage.write(key: _keyAccessToken, value: state.accessToken);
    if (state.refreshTokenValue != null) {
      await _storage.write(
        key: _keyRefreshToken,
        value: state.refreshTokenValue,
      );
    }
    if (state.clientId != null) {
      await _storage.write(key: _keyClientId, value: state.clientId);
    }
    if (state.clientSecret != null) {
      await _storage.write(key: _keyClientSecret, value: state.clientSecret);
    }
  }
}
