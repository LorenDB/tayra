import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/http_client_factory.dart';
import 'package:tayra/core/auth/password_transport.dart';
import 'package:tayra/core/cache/cache_manager.dart';
import 'package:tayra/core/cache/pending_favorite_ops.dart';
import 'package:tayra/core/platform/app_platform.dart';
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

// ── Auth methods discovery ──────────────────────────────────────────────

/// Public auth-methods payload from `GET /api/v1/users/auth-methods/`.
class AuthMethods {
  final bool password;
  final bool oidcEnabled;
  final String oidcDisplayName;
  final String oidcLoginPath;

  const AuthMethods({
    this.password = true,
    this.oidcEnabled = false,
    this.oidcDisplayName = 'SSO',
    this.oidcLoginPath = '/api/v1/users/oidc/login/',
  });

  factory AuthMethods.fromJson(Map<String, dynamic> json) {
    final oidc = json['oidc'];
    final Map<String, dynamic> oidcMap =
        oidc is Map
            ? Map<String, dynamic>.from(oidc)
            : const <String, dynamic>{};
    final display = (oidcMap['display_name'] as String?)?.trim() ?? '';
    final loginPath = (oidcMap['login_path'] as String?)?.trim() ?? '';
    return AuthMethods(
      password: json['password'] != false,
      oidcEnabled: oidcMap['enabled'] == true,
      oidcDisplayName: display.isNotEmpty ? display : 'SSO',
      oidcLoginPath:
          loginPath.isNotEmpty ? loginPath : '/api/v1/users/oidc/login/',
    );
  }

  static const disabled = AuthMethods();
}

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

  /// Scoped listen token from `/users/me/` (`tokens.listen`). Used as `?token=`
  /// on stream URLs so browser media elements can authenticate without headers.
  final String? listenToken;

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
    this.listenToken,
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
    String? listenToken,
    bool clearListenToken = false,
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
      listenToken: clearListenToken ? null : (listenToken ?? this.listenToken),
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
  // fields on desktop/web. Android keeps using FlutterSecureStorage.
  static bool get _useSecureStorage => AppPlatform.useSecureStorage;

  Future<String> _getAppName() async {
    final deviceName = await AppPlatform.deviceLabel();
    return 'Tayra ($deviceName)';
  }

  /// Refresh the scoped listen token used for `?token=` stream URLs (web).
  Future<void> ensureListenToken() async {
    if (!state.isAuthenticated) return;
    if (state.listenToken != null && state.listenToken!.isNotEmpty) return;
    try {
      final response = await _dio.get(
        '${state.serverUrl}/api/v1/users/me/',
        options: Options(
          headers: {'Authorization': 'Bearer ${state.accessToken}'},
        ),
      );
      final data = response.data;
      String? listen;
      if (data is Map) {
        final tokens = data['tokens'];
        if (tokens is Map) {
          listen = tokens['listen'] as String?;
        }
      }
      if (listen != null && listen.isNotEmpty) {
        state = state.copyWith(listenToken: listen);
      }
    } catch (_) {
      // Streaming may still work with Bearer headers on native; web needs this.
    }
  }

  void clearListenToken() {
    state = state.copyWith(clearListenToken: true);
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
        // Fire-and-forget: stream auth for web / gapless sources.
        unawaited(ensureListenToken());
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

  String _normalizeServerUrl(String serverUrl) {
    var url = serverUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  /// Discover available login methods (`GET /api/v1/users/auth-methods/`).
  ///
  /// Returns [AuthMethods.disabled] when the server does not expose the
  /// endpoint (stock Funkwhale) or on network errors.
  Future<AuthMethods> fetchAuthMethods(String serverUrl) async {
    final url = _normalizeServerUrl(serverUrl);
    final endpoint =
        kIsWeb
            ? '/api/v1/users/auth-methods/'
            : '$url/api/v1/users/auth-methods/';
    try {
      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode != 200) return AuthMethods.disabled;
      final map = _asJsonMap(response.data);
      if (map == null) return AuthMethods.disabled;
      return AuthMethods.fromJson(map);
    } catch (_) {
      return AuthMethods.disabled;
    }
  }

  /// Absolute URL that starts the server-side OIDC login redirect.
  ///
  /// [clientRedirect] is where the API sends the browser after IdP auth
  /// (SPA callback URL or OOB URN).
  String buildOidcLoginUrl({
    required String serverUrl,
    required String clientRedirect,
    required String loginPath,
    String? clientState,
  }) {
    final url = _normalizeServerUrl(serverUrl);
    final path = loginPath.startsWith('/') ? loginPath : '/$loginPath';
    final base = kIsWeb ? path : '$url$path';
    final params = <String, String>{
      'client_redirect': clientRedirect,
      if (clientState != null && clientState.isNotEmpty) 'state': clientState,
    };
    final uri = Uri.parse(base).replace(queryParameters: params);
    // Relative paths need the current origin for url_launcher / browser nav.
    if (!uri.hasScheme) {
      // Caller on web should prefer full URL; keep path+query usable with go.
      return uri.toString();
    }
    return uri.toString();
  }

  /// Complete OIDC SSO by exchanging a one-time code for first-party tokens.
  Future<bool> completeOidcLogin({
    required String serverUrl,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final url = _normalizeServerUrl(serverUrl);
    final endpoint =
        kIsWeb ? '/api/v1/users/oidc/token/' : '$url/api/v1/users/oidc/token/';

    try {
      final response = await _dio.post(
        endpoint,
        data: {'code': code.trim()},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            Headers.contentTypeHeader: Headers.jsonContentType,
          },
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.json,
        ),
      );
      final payload = _asJsonMap(response.data);
      if (response.statusCode != 200 || payload == null) {
        state = state.copyWith(
          isLoading: false,
          error: _formatOidcError(payload, response.statusCode),
        );
        Analytics.track('login_sso_failed');
        return false;
      }

      final accessToken = payload['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Server did not return an access token.',
        );
        Analytics.track('login_sso_failed');
        return false;
      }

      final pendingServer = state.pendingServerUrl;
      if (pendingServer != null && pendingServer != url) {
        await _clearAllUserData();
      }

      state = state.copyWith(
        serverUrl: url,
        accessToken: accessToken,
        refreshTokenValue: payload['refresh_token'] as String?,
        clientId: payload['client_id'] as String?,
        clientSecret: payload['client_secret'] as String? ?? '',
        listenToken: payload['listen_token'] as String?,
        isLoading: false,
        clearPendingServerUrl: true,
      );
      await _saveAuth();
      if (state.listenToken == null || state.listenToken!.isEmpty) {
        await ensureListenToken();
      }
      Analytics.track('login_sso_success');
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatOidcError(
          _asJsonMap(e.response?.data),
          e.response?.statusCode,
        ),
      );
      Analytics.track('login_sso_failed');
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not complete SSO login. Try again.',
      );
      Analytics.track('login_sso_failed');
      return false;
    }
  }

  static String _formatOidcError(Map<String, dynamic>? map, int? status) {
    if (map != null) {
      final error = map['error']?.toString();
      final detail = map['detail']?.toString();
      if (error == 'user_not_found') {
        return 'No local account matches this SSO user.';
      }
      if (error == 'inactive' || error == 'account_disabled') {
        return 'This account was disabled.';
      }
      if (error == 'invalid_code' || error == 'missing_code') {
        return 'Invalid or expired sign-in code. Start SSO again.';
      }
      if (detail != null && detail.isNotEmpty) return detail;
      if (error != null && error.isNotEmpty) return error;
    }
    if (status == 404) {
      return 'SSO is not available on this server.';
    }
    return 'SSO login failed. Try again or use password login.';
  }

  /// First-party password login (Funkwhale+Tayra fork: `POST /api/v1/users/token/`).
  ///
  /// Returns `true` on success. On a 404 (stock Funkwhale without the endpoint),
  /// returns `false` so the caller can fall back to the OAuth code flow.
  Future<bool> loginWithPassword({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final url = _normalizeServerUrl(serverUrl);

    // On web, prefer same-origin relative URL so a mismatched baked
    // FUNKWHALE_URL still hits the nginx that serves this SPA.
    final tokenEndpoint =
        kIsWeb ? '/api/v1/users/token/' : '$url/api/v1/users/token/';

    try {
      // Domain-separated SHA-256 digest — never send the account password
      // in plaintext (API rejects non-hex digests). Still use HTTPS.
      final passwordDigest = hashPasswordForTransport(password);
      final response = await _dio.post(
        tokenEndpoint,
        data: {'username': username.trim(), 'password': passwordDigest},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            Headers.contentTypeHeader: Headers.jsonContentType,
          },
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 404) {
        state = state.copyWith(isLoading: false, serverUrl: url);
        return false;
      }
      final payload = _asJsonMap(response.data);
      if (response.statusCode != 200 || payload == null) {
        // Surface the real API body in the browser console (DevTools).
        debugPrint(
          'loginWithPassword failed status=${response.statusCode} '
          'data=${response.data}',
        );
        state = state.copyWith(
          isLoading: false,
          error: _formatLoginError(response.data, response.statusCode),
        );
        Analytics.track('login_failed');
        return false;
      }

      final data = payload;
      final accessToken = data['access_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Server did not return an access token.',
        );
        return false;
      }

      final pendingServer = state.pendingServerUrl;
      if (pendingServer != null && pendingServer != url) {
        await _clearAllUserData();
      }

      state = state.copyWith(
        serverUrl: url,
        accessToken: accessToken,
        refreshTokenValue: data['refresh_token'] as String?,
        clientId: data['client_id'] as String?,
        clientSecret: data['client_secret'] as String? ?? '',
        listenToken: data['listen_token'] as String?,
        isLoading: false,
        clearPendingServerUrl: true,
      );
      await _saveAuth();
      Analytics.track('login_success');
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        state = state.copyWith(isLoading: false, serverUrl: url);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: _formatLoginError(e.response?.data, status),
      );
      Analytics.track('login_failed');
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not connect to server. Check the URL and try again.',
      );
      Analytics.track('login_failed');
      return false;
    }
  }

  /// Coerce Dio response data into a JSON map (web sometimes yields a String).
  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  /// Prefer server-provided detail over a generic message (helps debug 400s).
  static String _formatLoginError(dynamic data, int? status) {
    final map = _asJsonMap(data);
    if (map != null) {
      final code = map['code']?.toString();
      final error = map['error']?.toString();
      if (code == 'email_unverified' ||
          error == 'email_unverified' ||
          (map['non_field_errors'] is List &&
              (map['non_field_errors'] as List).any(
                (e) => e.toString().toLowerCase().contains('verify'),
              ))) {
        return 'Please verify your e-mail address before logging in.';
      }
      if (error == 'account_disabled') {
        return 'This account was disabled.';
      }
      if (error == 'missing_credentials') {
        return 'Both username and password are required.';
      }
      if (error == 'password_not_hashed') {
        return 'This server requires a newer Tayra client for password login.';
      }
      final nonField = map['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }
      final detail = map['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      // DRF field errors: {username: [...], password: [...]}
      for (final key in ['username', 'password', 'error']) {
        final v = map[key];
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    }
    if (status == 400) return 'Invalid username or password.';
    if (status == 403) return 'Login not allowed for this account.';
    return 'Could not connect to server. Check the URL and try again.';
  }

  /// Step 1: Register an OAuth application on the server (fallback / OOB).
  Future<void> registerApp(String serverUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    final url = _normalizeServerUrl(serverUrl);

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
        clearListenToken: true,
      );

      await _saveAuth();
      // Fetch scoped listen token for stream URLs (required on web).
      await ensureListenToken();
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
        clearListenToken: true,
      );

      await _saveAuth();
      await ensureListenToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Manual logout triggered by the user. Clears all cached data immediately.
  ///
  /// Credential wipe and auth-state reset always run, even if local cache
  /// cleanup fails (e.g. SQLite paths that are unavailable on web).
  Future<void> logout() async {
    Analytics.track('logout');
    try {
      await _clearAllUserData();
    } catch (e, st) {
      debugPrint('logout: failed to clear local user data: $e\n$st');
    }
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
    // Each step is isolated so one platform-specific failure cannot leave
    // prefs / queue / credentials half-cleared.
    try {
      await CacheManager.instance.clearAll(clearUserData: true);
    } catch (e, st) {
      debugPrint('logout: CacheManager.clearAll failed: $e\n$st');
    }
    try {
      await PendingFavoriteOps.clear();
    } catch (e, st) {
      debugPrint('logout: PendingFavoriteOps.clear failed: $e\n$st');
    }
    try {
      await QueuePersistenceService.clearQueue();
    } catch (e, st) {
      debugPrint('logout: QueuePersistenceService.clearQueue failed: $e\n$st');
    }
    try {
      await ListenHistoryService.clearAll();
    } catch (e, st) {
      debugPrint('logout: ListenHistoryService.clearAll failed: $e\n$st');
    }
    try {
      await SettingsNotifier.clearSettings();
    } catch (e, st) {
      debugPrint('logout: SettingsNotifier.clearSettings failed: $e\n$st');
    }
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
