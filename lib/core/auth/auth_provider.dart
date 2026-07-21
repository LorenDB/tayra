import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/http_client_factory.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/pending_favorite_ops.dart';
import 'package:tayra/features/player/queue_persistence_service.dart';
import 'package:tayra/features/year_review/listen_history_service.dart';
import 'package:tayra/features/settings/settings_provider.dart';
import 'package:tayra/features/home/home_screen.dart';
import 'package:tayra/features/browse/albums_screen.dart';
import 'package:tayra/features/browse/artists_screen.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/favorites/favorites_provider.dart';

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

  /// When the app is logged out automatically (e.g. token refresh failed), this
  /// holds the server URL the user was previously connected to. The login screen
  /// uses this to pre-populate the server field and to detect a same-server
  /// re-login so cached data can be preserved.
  final String? pendingServerUrl;

  const AuthState({
    this.serverUrl,
    this.accessToken,
    this.refreshTokenValue,
    this.clientId,
    this.clientSecret,
    this.isLoading = false,
    this.isCheckingAuth = false,
    this.error,
    this.pendingServerUrl,
  });

  bool get isAuthenticated => accessToken != null && serverUrl != null;

  /// True when the user was automatically logged out and still needs to
  /// re-authenticate (as opposed to having deliberately logged out).
  bool get wasAutoLoggedOut => pendingServerUrl != null;

  // Sentinel used by copyWith so that passing error: null explicitly clears
  // the error, while omitting the parameter preserves the current error.
  static const _kNoError = Object();

  AuthState copyWith({
    String? serverUrl,
    String? accessToken,
    String? refreshTokenValue,
    String? clientId,
    String? clientSecret,
    bool? isLoading,
    bool? isCheckingAuth,
    Object? error = _kNoError,
    String? pendingServerUrl,
    bool clearPendingServerUrl = false,
  }) {
    return AuthState(
      serverUrl: serverUrl ?? this.serverUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshTokenValue: refreshTokenValue ?? this.refreshTokenValue,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      isLoading: isLoading ?? this.isLoading,
      isCheckingAuth: isCheckingAuth ?? this.isCheckingAuth,
      error: identical(error, _kNoError) ? this.error : error as String?,
      pendingServerUrl:
          clearPendingServerUrl
              ? null
              : (pendingServerUrl ?? this.pendingServerUrl),
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

// ── Auth state listener ─────────────────────────────────────────────────
// This provider watches auth state and invalidates all cached data providers
// when the user signs out. This ensures a fresh start when signing into
// a different server.

final authStateListenerProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    if (previous != null && previous.isAuthenticated && !next.isAuthenticated) {
      ref.invalidate(recentAlbumsProvider);
      ref.invalidate(randomAlbumsProvider);
      ref.invalidate(recentTracksProvider);
      ref.invalidate(albumsPageProvider(1));
      ref.invalidate(artistsPageProvider(1));
      ref.invalidate(playlistsProvider);
      ref.invalidate(favoriteTrackIdsProvider);
    }
  });
});

class AuthNotifier extends Notifier<AuthState> {
  /// In-flight token refresh future. If a refresh is already in progress,
  /// concurrent callers share this future instead of launching a second one.
  Future<bool>? _refreshFuture;

  /// In-flight automatic logout (multiple concurrent 401s share one).
  Future<void>? _autoLogoutFuture;

  /// Single Dio for all OAuth calls (app registration, code exchange, token
  /// refresh) so they reuse one connection pool instead of opening a fresh
  /// socket — and DNS lookup — per call.
  final Dio _dio = createDio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

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

  // On macOS the sandboxed Keychain requires a provisioning profile to persist
  // items across launches, so we fall back to SharedPreferences for all auth
  // fields on desktop. Android keeps using FlutterSecureStorage.
  static bool get _useSecureStorage => Platform.isAndroid;

  Future<String> _getAppName() async {
    String deviceName;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      deviceName = '${info.manufacturer} ${info.model}';
    } else {
      deviceName = Platform.localHostname;
    }
    return 'Tayra ($deviceName)';
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

      final String? accessToken;
      final String? refreshToken;
      final String? clientId;
      final String? clientSecret;

      if (_useSecureStorage) {
        accessToken = await _storage.read(key: _keyAccessToken);
        refreshToken = await _storage.read(key: _keyRefreshToken);
        clientId = await _storage.read(key: _keyClientId);
        clientSecret = await _storage.read(key: _keyClientSecret);
      } else {
        accessToken = prefs.getString(_keyAccessToken);
        refreshToken = prefs.getString(_keyRefreshToken);
        clientId = prefs.getString(_keyClientId);
        clientSecret = prefs.getString(_keyClientSecret);
      }

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
    } catch (e, stack) {
      // A storage read failure is not the same as being logged out.
      // Retrying is not meaningful here, but we should not silently treat
      // a keystore/IO error as "no credentials". Log the error in debug
      // mode and leave state as unauthenticated so the user can log in again
      // rather than getting stuck on the splash screen.
      assert(() {
        debugPrint('AuthNotifier: error loading saved auth: $e\n$stack');
        return true;
      }());
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
      final response = await _dio.post(
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

  /// Returns the authorization URL for the user to visit, or null if
  /// [registerApp] has not completed yet (serverUrl / clientId not set).
  String? getAuthorizationUrl() {
    final serverUrl = state.serverUrl;
    final clientId = state.clientId;
    if (serverUrl == null || clientId == null) return null;
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
      final response = await _dio.post(
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

      // If we were auto-logged-out and the user is signing into a different
      // server, clear the stale cache from the previous server before
      // completing the new login.
      final pendingServer = state.pendingServerUrl;
      final newServer = state.serverUrl;
      if (pendingServer != null && pendingServer != newServer) {
        await _clearAllUserData();
      }

      state = state.copyWith(
        accessToken: accessToken,
        refreshTokenValue: refreshToken,
        isLoading: false,
        clearPendingServerUrl: true,
      );

      await _saveAuth();
      Analytics.track('login_success');
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to authenticate. Check the code and try again.',
      );
      Analytics.track('login_failed');
      return false;
    }
  }

  /// Refresh the access token using the refresh token.
  ///
  /// If a refresh is already in flight (e.g. from a concurrent 401), the
  /// existing future is returned so that only one refresh request is made.
  Future<bool> refreshToken() {
    _refreshFuture ??= _doRefreshToken().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _doRefreshToken() async {
    if (state.refreshTokenValue == null) return false;

    try {
      final response = await _dio.post(
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

  /// Manual logout triggered by the user. Clears all cached data immediately.
  Future<void> logout() async {
    Analytics.track('logout');
    await _clearAllUserData();
    await _deleteAuthCredentials();
    state = const AuthState();
  }

  /// Automatic logout triggered by the system (e.g. token refresh failure).
  ///
  /// Unlike [logout], this preserves all cached data and remembers the server
  /// URL so that re-authenticating to the same server can resume seamlessly
  /// without discarding the cache.
  ///
  /// Concurrent callers share a single in-flight future so a burst of 401s
  /// does not thrash credential storage.
  Future<void> logoutAutomatically() {
    _autoLogoutFuture ??= _doLogoutAutomatically().whenComplete(() {
      _autoLogoutFuture = null;
    });
    return _autoLogoutFuture!;
  }

  Future<void> _doLogoutAutomatically() async {
    Analytics.track('logout_automatic');
    final previousServerUrl = state.serverUrl;
    await _deleteAuthCredentials();
    state = AuthState(
      pendingServerUrl: previousServerUrl,
      error: 'Your session expired. Please sign in again.',
    );
  }

  Future<void> _deleteAuthCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerUrl);
    if (_useSecureStorage) {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyClientId);
      await _storage.delete(key: _keyClientSecret);
    } else {
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyClientId);
      await prefs.remove(_keyClientSecret);
    }
  }

  Future<void> _clearAllUserData() async {
    // Wipe files + favorites + download queue so the next account cannot
    // inherit hearts, offline stubs, or pending downloads from this user.
    await CacheManager.instance.clearAll(clearUserData: true);
    await PendingFavoriteOps.clear();
    await QueuePersistenceService.clearQueue();
    await ListenHistoryService.clearAll();
    await SettingsNotifier.clearSettings();
  }

  Future<void> logoutAndClearData() async {
    await logout();
  }

  Future<void> _saveAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, state.serverUrl!);
    if (_useSecureStorage) {
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
    } else {
      if (state.accessToken != null) {
        await prefs.setString(_keyAccessToken, state.accessToken!);
      }
      if (state.refreshTokenValue != null) {
        await prefs.setString(_keyRefreshToken, state.refreshTokenValue!);
      }
      if (state.clientId != null) {
        await prefs.setString(_keyClientId, state.clientId!);
      }
      if (state.clientSecret != null) {
        await prefs.setString(_keyClientSecret, state.clientSecret!);
      }
    }
  }
}
