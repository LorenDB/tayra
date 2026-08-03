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

  /// Short-lived MFA challenge token when password login requires TOTP.
  final String? pendingMfaToken;

  /// Instance requires this password user to configure TOTP after login.
  final bool totpSetupRequired;

  /// Ephemeral PKCE code_verifier for the OAuth authorization-code fallback (M2).
  final String? codeVerifier;

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
    this.pendingMfaToken,
    this.totpSetupRequired = false,
    this.codeVerifier,
  });

  bool get isAuthenticated => accessToken != null && serverUrl != null;

  /// True when the user was automatically logged out and still needs to
  /// re-authenticate (as opposed to having deliberately logged out).
  bool get wasAutoLoggedOut => pendingServerUrl != null;

  /// Password verified; waiting for authenticator / recovery code.
  bool get needsTotp => pendingMfaToken != null && !isAuthenticated;

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
    String? pendingMfaToken,
    bool clearPendingMfaToken = false,
    bool? totpSetupRequired,
    String? codeVerifier,
    bool clearCodeVerifier = false,
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
      pendingMfaToken:
          clearPendingMfaToken
              ? null
              : (pendingMfaToken ?? this.pendingMfaToken),
      totpSetupRequired: totpSetupRequired ?? this.totpSetupRequired,
      codeVerifier:
          clearCodeVerifier ? null : (codeVerifier ?? this.codeVerifier),
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
    final wasTotpSetup = _state.totpSetupRequired;
    _state = newState;

    // Notify listeners when authentication status or checking state changes
    // (isCheckingAuth changes trigger router redirects away from the splash screen)
    if (wasAuthenticated != newState.isAuthenticated ||
        wasCheckingAuth != newState.isCheckingAuth ||
        wasTotpSetup != newState.totpSetupRequired) {
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
  /// Prefs key for OIDC login CSRF `state` (M3). Cleared after validation.
  static const keyOidcPendingState = 'oidc_pending_state';
  /// OOB paste-code fallback (still PKCE-bound). Prefer tayra:// when deep links
  /// are wired; OOB remains for the authorization-code paste UX (M2).
  static const _redirectUri = 'urn:ietf:wg:oauth:2.0:oob';
  static const _scopes = 'read write';

  // H5: prefer platform secure storage where it is durable. macOS sandboxed
  // Keychain is not (without keychain-access-groups), so that platform uses
  // SharedPreferences — see AppPlatform.useSecureStorage.
  static bool get _useSecureStorage => AppPlatform.useSecureStorage;

  Future<String> _getAppName() async {
    final deviceName = await AppPlatform.deviceLabel();
    return 'Tayra ($deviceName)';
  }

  /// Refresh the scoped listen token used for `?token=` stream URLs (web).
  ///
  /// Also refreshes [AuthState.totpSetupRequired] from `/users/me/`.
  Future<void> ensureListenToken() async {
    if (!state.isAuthenticated) return;
    try {
      final response = await _dio.get(
        '${state.serverUrl}/api/v1/users/me/',
        options: Options(
          headers: {'Authorization': 'Bearer ${state.accessToken}'},
        ),
      );
      final data = response.data;
      if (data is! Map) return;

      String? listen;
      final tokens = data['tokens'];
      if (tokens is Map) {
        listen = tokens['listen'] as String?;
      }
      final totpRequired = data['totp_required'] == true;

      var next = state.copyWith(totpSetupRequired: totpRequired);
      if (listen != null && listen.isNotEmpty) {
        next = next.copyWith(listenToken: listen);
      }
      state = next;
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

      String? accessToken;
      String? refreshToken;
      String? clientId;
      String? clientSecret;

      if (_useSecureStorage) {
        accessToken = await _storage.read(key: _keyAccessToken);
        refreshToken = await _storage.read(key: _keyRefreshToken);
        clientId = await _storage.read(key: _keyClientId);
        clientSecret = await _storage.read(key: _keyClientSecret);

        // Migrate legacy plaintext prefs → secure storage (pre-H5 desktop).
        var migrated = false;
        if (accessToken == null) {
          accessToken = prefs.getString(_keyAccessToken);
          if (accessToken != null) migrated = true;
        }
        if (refreshToken == null) {
          refreshToken = prefs.getString(_keyRefreshToken);
          if (refreshToken != null) migrated = true;
        }
        if (clientId == null) {
          clientId = prefs.getString(_keyClientId);
          if (clientId != null) migrated = true;
        }
        if (clientSecret == null) {
          clientSecret = prefs.getString(_keyClientSecret);
          if (clientSecret != null) migrated = true;
        }
        if (migrated && accessToken != null) {
          await _storage.write(key: _keyAccessToken, value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: _keyRefreshToken, value: refreshToken);
          }
          if (clientId != null) {
            await _storage.write(key: _keyClientId, value: clientId);
          }
          if (clientSecret != null) {
            await _storage.write(key: _keyClientSecret, value: clientSecret);
          }
          await prefs.remove(_keyAccessToken);
          await prefs.remove(_keyRefreshToken);
          await prefs.remove(_keyClientId);
          await prefs.remove(_keyClientSecret);
        }
      } else {
        accessToken = prefs.getString(_keyAccessToken);
        refreshToken = prefs.getString(_keyRefreshToken);
        clientId = prefs.getString(_keyClientId);
        clientSecret = prefs.getString(_keyClientSecret);

        // Best-effort recovery: a brief window of H5 wrote macOS tokens only
        // into Keychain (which does not survive relaunch without entitlements).
        // If anything is still readable, move it back to SharedPreferences.
        if (AppPlatform.isMacOS && accessToken == null) {
          try {
            final kcAccess = await _storage.read(key: _keyAccessToken);
            if (kcAccess != null && kcAccess.isNotEmpty) {
              accessToken = kcAccess;
              refreshToken ??= await _storage.read(key: _keyRefreshToken);
              clientId ??= await _storage.read(key: _keyClientId);
              clientSecret ??= await _storage.read(key: _keyClientSecret);

              await prefs.setString(_keyAccessToken, accessToken);
              if (refreshToken != null) {
                await prefs.setString(_keyRefreshToken, refreshToken);
              }
              if (clientId != null) {
                await prefs.setString(_keyClientId, clientId);
              }
              if (clientSecret != null) {
                await prefs.setString(_keyClientSecret, clientSecret);
              }
              await _storage.delete(key: _keyAccessToken);
              await _storage.delete(key: _keyRefreshToken);
              await _storage.delete(key: _keyClientId);
              await _storage.delete(key: _keyClientSecret);
            }
          } catch (e, stack) {
            assert(() {
              debugPrint(
                'AuthNotifier: keychain recovery failed: $e\n$stack',
              );
              return true;
            }());
          }
        }
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
  ///
  /// [txBinding] binds the one-time exchange code to this client (H3).
  /// Native/OOB clients must pass the same value to [completeOidcLogin].
  /// Browser flows rely on the HttpOnly ``oidc_tx`` cookie instead.
  String buildOidcLoginUrl({
    required String serverUrl,
    required String clientRedirect,
    required String loginPath,
    String? clientState,
    String? txBinding,
  }) {
    final url = _normalizeServerUrl(serverUrl);
    final path = loginPath.startsWith('/') ? loginPath : '/$loginPath';
    final base = kIsWeb ? path : '$url$path';
    final params = <String, String>{
      'client_redirect': clientRedirect,
      if (clientState != null && clientState.isNotEmpty) 'state': clientState,
      if (txBinding != null && txBinding.isNotEmpty) 'tx': txBinding,
    };
    final uri = Uri.parse(base).replace(queryParameters: params);
    // Relative paths need the current origin for url_launcher / browser nav.
    if (!uri.hasScheme) {
      // Caller on web should prefer full URL; keep path+query usable with go.
      return uri.toString();
    }
    return uri.toString();
  }

  /// Persist OIDC `state` before redirecting to the IdP (M3).
  Future<void> storeOidcPendingState(String stateValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOidcPendingState, stateValue);
  }

  /// Validate callback `state` against the value stored in [storeOidcPendingState].
  ///
  /// Returns false when missing or mismatched (login CSRF). Always clears the
  /// stored value so it cannot be reused.
  Future<bool> validateAndClearOidcState(String? callbackState) async {
    final prefs = await SharedPreferences.getInstance();
    final expected = prefs.getString(keyOidcPendingState);
    await prefs.remove(keyOidcPendingState);
    if (expected == null || expected.isEmpty) {
      // No pending state (stale tab / direct navigation) — reject.
      return false;
    }
    if (callbackState == null || callbackState.isEmpty) {
      return false;
    }
    // Constant-time-ish compare for equal-length tokens.
    if (expected.length != callbackState.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ callbackState.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Complete OIDC SSO by exchanging a one-time code for first-party tokens.
  ///
  /// [txBinding] is required for native/OOB (must match the value passed to
  /// [buildOidcLoginUrl]). On web the session cookie is sent automatically.
  ///
  /// [clientState] must match the value sent to [buildOidcLoginUrl] / stored
  /// via [storeOidcPendingState] (M3 login CSRF).
  Future<bool> completeOidcLogin({
    required String serverUrl,
    required String code,
    String? txBinding,
    String? clientState,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final url = _normalizeServerUrl(serverUrl);
    final endpoint =
        kIsWeb ? '/api/v1/users/oidc/token/' : '$url/api/v1/users/oidc/token/';

    final stateOk = await validateAndClearOidcState(clientState);
    if (!stateOk) {
      state = state.copyWith(
        isLoading: false,
        error: 'SSO session mismatch. Start sign-in again from the login page.',
      );
      Analytics.track('login_sso_failed');
      return false;
    }

    try {
      final body = <String, dynamic>{
        'code': code.trim(),
        if (txBinding != null && txBinding.isNotEmpty) 'tx': txBinding,
      };
      final response = await _dio.post(
        endpoint,
        data: body,
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Accept': 'application/json',
            Headers.contentTypeHeader: Headers.jsonContentType,
          },
          // Include cookies on web so oidc_tx binding is sent (H3).
          extra: const {'withCredentials': true},
          validateStatus: (s) => s != null && s < 500,
          responseType: ResponseType.json,
        ),
      );
      final payload = _asJsonMap(response.data);

      // Confirmed TOTP is required after SSO when the local account has 2FA
      // (same wire shape as password login).
      if (response.statusCode == 401 &&
          payload != null &&
          (payload['error'] == 'totp_required' ||
              payload['code'] == 'totp_required')) {
        final mfa = payload['mfa_token'] as String?;
        if (mfa != null && mfa.isNotEmpty) {
          state = state.copyWith(
            isLoading: false,
            serverUrl: url,
            pendingMfaToken: mfa,
            error: null,
          );
          Analytics.track('login_totp_required');
          return false;
        }
      }

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
        clearPendingMfaToken: true,
        totpSetupRequired: payload['totp_setup_required'] == true,
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

  /// First-party password login (Funkwhale+Tayra fork).
  ///
  /// Flow (H2): `POST /api/v1/users/token/challenge/` then
  /// `POST /api/v1/users/token/` with a per-request SCRAM-like proof (or a
  /// challenge-bound legacy digest). Never sends the account password.
  ///
  /// Returns `true` on full success (tokens stored). Returns `false` on
  /// failure **or** when TOTP is required (see [AuthState.needsTotp] /
  /// [AuthState.pendingMfaToken]). On a 404 (stock Funkwhale without the
  /// endpoint), returns `false` with no error so the caller can fall back
  /// to the OAuth code flow.
  Future<bool> loginWithPassword({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearPendingMfaToken: true,
    );
    final url = _normalizeServerUrl(serverUrl);
    final user = username.trim();

    // On web, prefer same-origin relative URL so a mismatched baked
    // FUNKWHALE_URL still hits the nginx that serves this SPA.
    final challengeEndpoint = kIsWeb
        ? '/api/v1/users/token/challenge/'
        : '$url/api/v1/users/token/challenge/';
    final tokenEndpoint =
        kIsWeb ? '/api/v1/users/token/' : '$url/api/v1/users/token/';

    try {
      final challengeResponse = await _dio.post(
        challengeEndpoint,
        data: {'username': user},
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

      if (challengeResponse.statusCode == 404) {
        state = state.copyWith(isLoading: false, serverUrl: url);
        return false;
      }
      final challenge = _asJsonMap(challengeResponse.data);
      if (challengeResponse.statusCode != 200 || challenge == null) {
        state = state.copyWith(
          isLoading: false,
          error: _formatLoginError(
            challengeResponse.data,
            challengeResponse.statusCode,
          ),
          clearPendingMfaToken: true,
        );
        Analytics.track('login_failed');
        return false;
      }

      final challengeId = challenge['challenge_id'] as String? ?? '';
      final serverNonce = challenge['server_nonce'] as String? ?? '';
      final scheme = challenge['scheme'] as String? ?? 'scram_v2';
      if (challengeId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Server did not return a login challenge.',
          clearPendingMfaToken: true,
        );
        Analytics.track('login_failed');
        return false;
      }

      final Map<String, dynamic> loginBody = {
        'username': user,
        'challenge_id': challengeId,
      };

      if (scheme == 'legacy_v1') {
        // One-shot legacy digest bound to the challenge.
        loginBody['password'] = legacyTransportDigest(password);
      } else {
        final saltB64 = challenge['salt'] as String? ?? '';
        final bindingHex = challenge['instance_binding'] as String? ?? '';
        if (saltB64.isEmpty || serverNonce.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            error: 'Server returned an incomplete login challenge.',
            clearPendingMfaToken: true,
          );
          Analytics.track('login_failed');
          return false;
        }
        final int iterations;
        final int transportIters;
        try {
          iterations = clampTransportIterations(
            (challenge['iterations'] as num?)?.toInt(),
          );
          transportIters = clampTransportIterations(
            (challenge['transport_iterations'] as num?)?.toInt(),
          );
        } on ArgumentError {
          state = state.copyWith(
            isLoading: false,
            error: 'Server returned an invalid login challenge.',
            clearPendingMfaToken: true,
          );
          Analytics.track('login_failed');
          return false;
        }
        final binding = bindingHex.isNotEmpty
            ? instanceBindingFromHex(bindingHex)
            : instanceBindingForServerUrl(url);
        final secret = transportSecret(
          password,
          binding,
          iterations: transportIters,
        );
        final clientNonce = newClientNonce();
        final proof = computeClientProof(
          secret: secret,
          salt: b64UrlDecode(saltB64),
          iterations: iterations,
          username: user,
          clientNonce: clientNonce,
          serverNonce: serverNonce,
        );
        loginBody['client_nonce'] = clientNonce;
        loginBody['client_proof'] = proof;
      }

      final response = await _dio.post(
        tokenEndpoint,
        data: loginBody,
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

      // TOTP second factor required after password verification.
      if (response.statusCode == 401 &&
          payload != null &&
          (payload['error'] == 'totp_required' ||
              payload['code'] == 'totp_required')) {
        final mfa = payload['mfa_token'] as String?;
        if (mfa != null && mfa.isNotEmpty) {
          state = state.copyWith(
            isLoading: false,
            serverUrl: url,
            pendingMfaToken: mfa,
            error: null,
          );
          Analytics.track('login_totp_required');
          return false;
        }
      }

      if (response.statusCode != 200 || payload == null) {
        // Log status only — never dump auth response bodies (may include
        // challenge fragments or account hints) into device logs.
        assert(() {
          debugPrint(
            'loginWithPassword failed status=${response.statusCode}',
          );
          return true;
        }());
        state = state.copyWith(
          isLoading: false,
          error: _formatLoginError(response.data, response.statusCode),
          clearPendingMfaToken: true,
        );
        Analytics.track('login_failed');
        return false;
      }

      return await _applyTokenPayload(url, payload);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        state = state.copyWith(isLoading: false, serverUrl: url);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: _formatLoginError(e.response?.data, status),
        clearPendingMfaToken: true,
      );
      Analytics.track('login_failed');
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not connect to server. Check the URL and try again.',
        clearPendingMfaToken: true,
      );
      Analytics.track('login_failed');
      return false;
    }
  }

  /// Complete password login after TOTP challenge (`POST .../users/token/2fa/`).
  Future<bool> completeTotpLogin({required String totpCode}) async {
    final mfaToken = state.pendingMfaToken;
    final url = state.serverUrl;
    if (mfaToken == null || url == null) {
      state = state.copyWith(
        error: 'Two-factor challenge expired. Sign in again.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    final endpoint =
        kIsWeb ? '/api/v1/users/token/2fa/' : '$url/api/v1/users/token/2fa/';

    try {
      final response = await _dio.post(
        endpoint,
        data: {'mfa_token': mfaToken, 'totp_code': totpCode.trim()},
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
          error: _formatLoginError(response.data, response.statusCode),
        );
        Analytics.track('login_totp_failed');
        return false;
      }
      final ok = await _applyTokenPayload(url, payload);
      if (ok) Analytics.track('login_totp_success');
      return ok;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatLoginError(e.response?.data, e.response?.statusCode),
      );
      Analytics.track('login_totp_failed');
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not verify the authentication code. Try again.',
      );
      Analytics.track('login_totp_failed');
      return false;
    }
  }

  /// Clear a pending MFA challenge (back to password form).
  void cancelTotpChallenge() {
    state = state.copyWith(
      clearPendingMfaToken: true,
      error: null,
      isLoading: false,
    );
  }

  /// Clear the force-2FA setup gate after the user finishes enrollment.
  void clearTotpSetupRequired() {
    state = state.copyWith(totpSetupRequired: false);
  }

  Future<bool> _applyTokenPayload(String url, Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Server did not return an access token.',
        clearPendingMfaToken: true,
      );
      return false;
    }

    final pendingServer = state.pendingServerUrl;
    if (pendingServer != null && pendingServer != url) {
      await _clearAllUserData();
    }

    final setupRequired = data['totp_setup_required'] == true;

    state = state.copyWith(
      serverUrl: url,
      accessToken: accessToken,
      refreshTokenValue: data['refresh_token'] as String?,
      clientId: data['client_id'] as String?,
      clientSecret: data['client_secret'] as String? ?? '',
      listenToken: data['listen_token'] as String?,
      isLoading: false,
      clearPendingServerUrl: true,
      clearPendingMfaToken: true,
      totpSetupRequired: setupRequired,
      error: null,
    );
    await _saveAuth();
    Analytics.track('login_success');
    return true;
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
      if (error == 'missing_challenge' || error == 'invalid_challenge') {
        return 'Login challenge expired. Please try again.';
      }
      if (error == 'missing_proof') {
        return 'Login proof missing. Update Tayra and try again.';
      }
      if (error == 'invalid_totp') {
        return 'Invalid authentication or recovery code.';
      }
      if (error == 'invalid_mfa_token') {
        return 'Two-factor challenge expired. Sign in again.';
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

  /// Step 1: Register a **public** OAuth application (PKCE; no client_secret).
  Future<void> registerApp(String serverUrl) async {
    state = state.copyWith(isLoading: true, error: null);

    final url = _normalizeServerUrl(serverUrl);
    final codeVerifier = newPkceCodeVerifier();

    try {
      final response = await _dio.post(
        '$url/api/v1/oauth/apps/',
        data: {
          'name': await _getAppName(),
          'scopes': _scopes,
          'redirect_uris': _redirectUri,
          'client_type': 'public',
        },
      );

      final clientId = response.data['client_id'] as String;

      state = state.copyWith(
        serverUrl: url,
        clientId: clientId,
        // Public clients must not store a secret (M2).
        clientSecret: '',
        codeVerifier: codeVerifier,
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
  ///
  /// Includes PKCE S256 challenge (M2).
  String? getAuthorizationUrl() {
    final serverUrl = state.serverUrl;
    final clientId = state.clientId;
    final verifier = state.codeVerifier;
    if (serverUrl == null || clientId == null || verifier == null) return null;
    final challenge = pkceCodeChallengeS256(verifier);
    return '$serverUrl/authorize?'
        'response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
        '&scope=${Uri.encodeComponent(_scopes)}'
        '&code_challenge=${Uri.encodeComponent(challenge)}'
        '&code_challenge_method=S256';
  }

  /// Step 2: Exchange the authorization code for tokens (with PKCE verifier).
  Future<bool> exchangeCode(String code) async {
    state = state.copyWith(isLoading: true, error: null);

    final verifier = state.codeVerifier;
    if (verifier == null || verifier.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login session expired. Start authorization again.',
      );
      return false;
    }

    try {
      final response = await _dio.post(
        '${state.serverUrl}/api/v1/oauth/token/',
        data: {
          'grant_type': 'authorization_code',
          'code': code.trim(),
          'client_id': state.clientId,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
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
        clientSecret: '',
        isLoading: false,
        clearPendingServerUrl: true,
        clearListenToken: true,
        clearCodeVerifier: true,
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
      // Public clients refresh without client_secret (M2).
      final data = <String, dynamic>{
        'grant_type': 'refresh_token',
        'refresh_token': state.refreshTokenValue,
        'client_id': state.clientId,
      };
      final secret = state.clientSecret;
      if (secret != null && secret.isNotEmpty) {
        data['client_secret'] = secret;
      }
      final response = await _dio.post(
        '${state.serverUrl}/api/v1/oauth/token/',
        data: data,
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
    // Always clear plaintext prefs (legacy + web) and secure keys when used.
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyClientId);
    await prefs.remove(_keyClientSecret);
    if (_useSecureStorage) {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyClientId);
      await _storage.delete(key: _keyClientSecret);
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
