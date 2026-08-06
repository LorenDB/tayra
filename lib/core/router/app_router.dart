import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/features/auth/presentation/email_confirm_screen.dart';
import 'package:tayra/features/auth/presentation/login_screen.dart';
import 'package:tayra/features/auth/presentation/oauth_authorize_screen.dart';
import 'package:tayra/features/auth/presentation/oidc_callback_screen.dart';
import 'package:tayra/features/auth/presentation/password_reset_confirm_screen.dart';
import 'package:tayra/features/auth/presentation/password_reset_request_screen.dart';
import 'package:tayra/features/auth/presentation/signup_screen.dart';
import 'package:tayra/features/home/home_screen.dart';
import 'package:tayra/features/browse/browse_screen.dart';
import 'package:tayra/features/radios/radios_screen.dart';
import 'package:tayra/features/radios/radio_edit_screen.dart';
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/features/podcasts/podcasts_screen.dart';
import 'package:tayra/features/podcasts/podcast_detail_screen.dart';
import 'package:tayra/features/browse/artist_detail_screen.dart';
import 'package:tayra/features/browse/album_detail_screen.dart';
import 'package:tayra/features/browse/album_edit_screen.dart';
import 'package:tayra/features/settings/settings_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/settings/totp_settings_screen.dart';
import 'package:tayra/features/favorites/favorites_screen.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/playlists/playlist_detail_screen.dart';
import 'package:tayra/features/playlists/playlist_edit_screen.dart';
import 'package:tayra/features/player/now_playing_screen.dart';
import 'package:tayra/features/player/queue_screen.dart';
import 'package:tayra/features/year_review/year_review_screen.dart';
import 'package:tayra/features/year_review/year_review_settings_screen.dart';
import 'package:tayra/features/settings/appearance_settings_screen.dart';
import 'package:tayra/features/settings/developer_settings_screen.dart';
import 'package:tayra/features/settings/playback_settings_screen.dart';
import 'package:tayra/features/settings/storage_settings_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/features/share/public_share_screen.dart';
import 'package:tayra/features/upload/upload_screen.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/library_admin/manage_libraries_screen.dart';
import 'package:tayra/features/library_admin/manage_library_detail_screen.dart';
import 'package:tayra/features/library_admin/manage_uploads_screen.dart';
import 'package:tayra/features/library_admin/manage_tags_screen.dart';
import 'package:tayra/features/library_admin/manage_channels_screen.dart';
import 'package:tayra/features/library_admin/manage_channel_detail_screen.dart';
import 'package:tayra/features/instance_settings/instance_settings_screen.dart';
import 'package:tayra/features/user_admin/manage_users_screen.dart';
import 'package:tayra/features/user_admin/manage_user_detail_screen.dart';
import 'package:tayra/features/user_admin/manage_invitations_screen.dart';
import 'package:tayra/core/widgets/app_shell.dart';

class NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _logScreenView(previousRoute.settings.name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logScreenView(newRoute?.settings.name);
  }

  void _logScreenView(String? routeName) {
    if (routeName != null && routeName.isNotEmpty) {
      // Route names are developer-controlled and safe; pass through wrapper
      // to enforce sanitisation rules consistently.
      Analytics.track('screen_view', {'screen': routeName});
    }
  }
}

final navigationObserverProvider = Provider<NavigationObserver>((ref) {
  return NavigationObserver();
});

/// Navigator key for the main shell route. Exposed so [AppShell] can attach
/// a [NavigatorPopHandler] that intercepts Android back presses and redirects
/// non-home tabs to the home tab rather than immediately exiting the app.
final shellNavigatorKey = GlobalKey<NavigatorState>();

/// SharedPreferences key for the post-login path after OIDC (full page leave).
const kPostLoginRedirectKey = 'post_login_redirect';

/// Allow only same-app relative paths (blocks open redirects via `from=`).
///
/// Query strings may legitimately contain `https://…` (OAuth `redirect_uri`);
/// only the path / host are validated, not the raw string.
///
/// Rejects `/login` and `/splash` so auth bounce loops cannot nest `from=`.
String? safeInternalPath(String? from) {
  if (from == null || from.isEmpty) return null;
  final uri = Uri.tryParse(from);
  if (uri == null) return null;
  // Reject absolute URLs (open redirect).
  if (uri.hasScheme || uri.host.isNotEmpty) return null;
  if (!uri.path.startsWith('/') || uri.path.startsWith('//')) return null;
  final path = _normalizePath(uri.path);
  if (path == '/login' || path == '/splash') return null;
  // Re-serialize so query values are correctly encoded for go_router.
  return uri.toString();
}

/// Location string for [uri] suitable as a `from=` deep-link target.
String _locationOf(Uri uri) {
  if (uri.hasQuery) return '${uri.path}?${uri.query}';
  return uri.path.isEmpty ? '/' : uri.path;
}

/// Build `/path?from=…` when [intended] is a safe in-app location.
String _withFrom(String path, Uri intended) {
  final safe = safeInternalPath(_locationOf(intended));
  if (safe == null) return path;
  // Already on the target path with no useful destination.
  if (_normalizePath(intended.path) == path && !intended.hasQuery) {
    return path;
  }
  return Uri(path: path, queryParameters: {'from': safe}).toString();
}

/// Root navigator for routes outside [ShellRoute] (login, OAuth consent, …).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Paths that must work while logged out (and during auth restore).
///
/// Email password-reset links land on `/auth/password/reset/confirm?…`.
/// Email verification links land on `/auth/email/confirm?key=…`.
/// Invite deep links land on `/signup?invitation=…`.
bool isPublicAuthPath(String path) {
  final p = _normalizePath(path);
  if (p == '/login' || p == '/splash' || p == '/authorize' || p == '/signup') {
    return true;
  }
  if (p == '/auth/password/reset' || p == '/auth/password/reset/confirm') {
    return true;
  }
  // Path-style confirm: /auth/password/reset/confirm/<uid>/<token>
  if (p.startsWith('/auth/password/reset/confirm/')) return true;
  if (p == '/auth/email/confirm') return true;
  // Path-style confirm: /auth/email/confirm/<key>
  if (p.startsWith('/auth/email/confirm/')) return true;
  // OIDC SSO return path (web)
  if (p == '/auth/sso/callback') return true;
  // Secret share links for albums / playlists (listen-only visitors)
  if (p.startsWith('/share/')) return true;
  // Player surfaces used by share visitors (and harmless when empty while logged out)
  if (p == '/now-playing' || p == '/queue') return true;
  return false;
}

String _normalizePath(String path) {
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}

/// Strip a trailing slash from the browser URL so go_router matches cleanly.
String? _trailingSlashRedirect(GoRouterState state) {
  final path = state.uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    final normalized = path.substring(0, path.length - 1);
    if (state.uri.hasQuery) {
      return '$normalized?${state.uri.query}';
    }
    return normalized;
  }
  return null;
}

/// Build the password-reset confirm screen from query and/or path params.
Widget _passwordResetConfirmFromState(GoRouterState state) {
  final q = state.uri.queryParameters;
  final uid = q['uid'] ?? state.pathParameters['uid'] ?? '';
  final token = q['token'] ?? state.pathParameters['token'] ?? '';
  return PasswordResetConfirmScreen(uid: uid, token: token);
}

/// Build the email-confirm screen from query and/or path params.
Widget _emailConfirmFromState(GoRouterState state) {
  final q = state.uri.queryParameters;
  final key = q['key'] ?? state.pathParameters['key'] ?? '';
  return EmailConfirmScreen(keyToken: key);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,
    observers: [ref.watch(navigationObserverProvider)],
    // Surface a recoverable page instead of a raw GoException dump when a
    // deep link fails to match (helps diagnose deploy/stale-build issues).
    errorBuilder: (context, state) {
      final path = state.uri.path;
      // Near-miss auth URLs → send people to a useful recovery page.
      final normalized = _normalizePath(path);
      if (normalized.startsWith('/auth/password')) {
        return const PasswordResetRequestScreen();
      }
      if (normalized.startsWith('/auth/email')) {
        return const EmailConfirmScreen(keyToken: '');
      }
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, color: Colors.white54, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  path.isEmpty ? state.uri.toString() : path,
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${state.error}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => GoRouter.of(context).go('/login'),
                  child: const Text('Go to sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    redirect: (context, state) {
      final slash = _trailingSlashRedirect(state);
      if (slash != null) return slash;

      final authState = authChangeNotifier.state;
      // Prefer uri.path over matchedLocation so query-bearing OAuth URLs are
      // classified correctly even mid-redirect.
      final path = _normalizePath(state.uri.path);
      final isLoginRoute = path == '/login';
      final isSplashRoute = path == '/splash';
      final isPublicAuth = isPublicAuthPath(path);
      final fromParam = state.uri.queryParameters['from'];

      // While restoring session, keep auth-related surfaces mounted so
      // `/authorize?…` / email reset links are not stripped by a bounce through
      // `/splash` → `/` or `/login`. For all other deep links, park on splash
      // with `from=` so the original path is restored after auth settles.
      if (authState.isCheckingAuth) {
        if (isPublicAuth || isSplashRoute) return null;
        return _withFrom('/splash', state.uri);
      }

      final isAuth = authState.isAuthenticated;

      if (isSplashRoute) {
        final safe = safeInternalPath(fromParam);
        if (isAuth) return safe ?? '/';
        if (safe != null) {
          return Uri(
            path: '/login',
            queryParameters: {'from': safe},
          ).toString();
        }
        return '/login';
      }

      if (!isAuth) {
        if (isPublicAuth) return null;
        // Preserve deep link (and OAuth authorize query) across login.
        return _withFrom('/login', state.uri);
      }

      if (isLoginRoute) {
        // Force 2FA setup before landing on the main app when required.
        if (authState.totpSetupRequired) return '/auth/2fa/setup';
        final safe = safeInternalPath(fromParam);
        if (safe != null) return safe;
        return '/';
      }

      // Instance requires TOTP for this password user — only allow the setup
      // screen (and logout via settings is not needed; setup is mandatory).
      if (authState.totpSetupRequired && path != '/auth/2fa/setup') {
        return '/auth/2fa/setup';
      }

      // Allow finishing reset/confirm while already signed in (rare email reopen).
      if (isPublicAuthPath(path) &&
          (path.startsWith('/auth/password') ||
              path.startsWith('/auth/email'))) {
        return null;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        parentNavigatorKey: rootNavigatorKey,
        builder:
            (context, state) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      // Mandatory TOTP enrollment when users__force_2fa is on.
      GoRoute(
        path: '/auth/2fa/setup',
        name: 'totp_forced_setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TotpSettingsScreen(mandatory: true),
      ),
      // OIDC SSO callback (must stay outside ShellRoute; public while logged out).
      GoRoute(
        path: '/auth/sso/callback',
        name: 'oidc_sso_callback',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OidcCallbackScreen(),
      ),
      // Account registration (must stay outside ShellRoute).
      // Invite deep links: /signup?invitation=CODE
      GoRoute(
        path: '/signup',
        name: 'signup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return SignupScreen(
            initialServerUrl: q['server'],
            initialInvitation: q['invitation'],
          );
        },
      ),
      // Secret share links (listen-only visitors; outside ShellRoute).
      GoRoute(
        path: '/share/:token',
        name: 'public_share',
        parentNavigatorKey: rootNavigatorKey,
        builder:
            (context, state) =>
                PublicShareScreen(token: state.pathParameters['token'] ?? ''),
      ),
      // Password reset deep links (must stay outside ShellRoute).
      // Email template: {url}/auth/password/reset/confirm?uid=…&token=…
      GoRoute(
        path: '/auth/password/reset/confirm/:uid/:token',
        name: 'password_reset_confirm_path',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _passwordResetConfirmFromState(state),
      ),
      GoRoute(
        path: '/auth/password/reset/confirm',
        name: 'password_reset_confirm',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _passwordResetConfirmFromState(state),
      ),
      GoRoute(
        path: '/auth/password/reset',
        name: 'password_reset_request',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final server = state.uri.queryParameters['server'];
          return PasswordResetRequestScreen(initialServerUrl: server);
        },
      ),
      // Email verification deep links (must stay outside ShellRoute).
      // Email template: {url}/auth/email/confirm?key=…
      GoRoute(
        path: '/auth/email/confirm/:key',
        name: 'email_confirm_path',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _emailConfirmFromState(state),
      ),
      GoRoute(
        path: '/auth/email/confirm',
        name: 'email_confirm',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _emailConfirmFromState(state),
      ),
      // Third-party OAuth consent (outside the main shell).
      GoRoute(
        path: '/authorize',
        name: 'oauth-authorize',
        parentNavigatorKey: rootNavigatorKey,
        builder:
            (context, state) =>
                OAuthAuthorizeScreen(query: state.uri.queryParameters),
      ),
      // Main shell with bottom nav.  All tab routes are nested under the
      // home route ("/") so that navigating to a tab (via context.go) pushes
      // the tab page on top of home rather than replacing it.  This keeps the
      // home page mounted in the stack, preserving its state, and lets the
      // system back button pop naturally back to home instead of exiting.
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder:
                (context, state) => const NoTransitionPage(child: HomeScreen()),
            routes: [
              GoRoute(
                path: 'album/:id',
                name: 'album_detail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) return const HomeScreen();
                  return AlbumDetailScreen(albumId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'album_edit',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const HomeScreen();
                      return AlbumEditScreen(albumId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'artist/:id',
                name: 'artist_detail',
                builder: (context, state) {
                  final id = int.tryParse(state.pathParameters['id'] ?? '');
                  if (id == null) return const HomeScreen();
                  return ArtistDetailScreen(artistId: id);
                },
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'account',
                    name: 'account_settings',
                    builder: (context, state) => const AccountSettingsScreen(),
                    routes: [
                      GoRoute(
                        path: '2fa',
                        name: 'totp_settings',
                        builder: (context, state) => const TotpSettingsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'playback',
                    name: 'playback_settings',
                    builder: (context, state) => const PlaybackSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'appearance',
                    name: 'appearance_settings',
                    builder:
                        (context, state) => const AppearanceSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'storage',
                    name: 'storage_settings',
                    builder: (context, state) => const StorageSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'year-review-settings',
                    name: 'year_review_settings',
                    builder:
                        (context, state) => const YearReviewSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'developer',
                    name: 'developer_settings',
                    builder:
                        (context, state) => const DeveloperSettingsScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'year-review',
                name: 'year_review',
                builder: (context, state) => const YearReviewSelectorScreen(),
                routes: [
                  GoRoute(
                    path: ':year',
                    name: 'year_review_detail',
                    builder: (context, state) {
                      final year = int.tryParse(
                        state.pathParameters['year'] ?? '',
                      );
                      if (year == null) return const HomeScreen();
                      final extra = state.extra;
                      final startInStory =
                          extra is Map ? extra['startInStory'] == true : false;
                      return YearReviewScreen(
                        year: year,
                        startInStory: startInStory,
                      );
                    },
                  ),
                ],
              ),
              // ── Tab routes ──
              GoRoute(
                path: 'artists',
                name: 'artists',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: ArtistsTabScreen()),
                routes: [
                  GoRoute(
                    path: 'artist/:id',
                    name: 'artists_artist_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const ArtistsTabScreen();
                      return ArtistDetailScreen(artistId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'browse',
                name: 'browse',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: BrowseScreen()),
                routes: [
                  GoRoute(
                    path: 'artist/:id',
                    name: 'browse_artist_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const BrowseScreen();
                      return ArtistDetailScreen(artistId: id);
                    },
                  ),
                  GoRoute(
                    path: 'album/:id',
                    name: 'browse_album_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const BrowseScreen();
                      return AlbumDetailScreen(albumId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'browse_album_edit',
                        builder: (context, state) {
                          final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          );
                          if (id == null) return const BrowseScreen();
                          return AlbumEditScreen(albumId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'radios',
                name: 'radios',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: RadiosScreen()),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'radio_create',
                    builder: (context, state) => const RadioEditScreen(),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    name: 'radio_edit',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const RadiosScreen();
                      final extra = state.extra;
                      final seed = extra is models.Radio ? extra : null;
                      return RadioEditScreen(radioId: id, initialRadio: seed);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'podcasts',
                name: 'podcasts',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: PodcastsScreen()),
                routes: [
                  GoRoute(
                    path: ':uuid',
                    name: 'podcast_detail',
                    builder: (context, state) {
                      final uuid = state.pathParameters['uuid']!;
                      final extra = state.extra;
                      models.Channel? channel;
                      bool? initiallySubscribed;
                      if (extra is models.Channel) {
                        channel = extra;
                      } else if (extra is Map) {
                        final c = extra['channel'];
                        if (c is models.Channel) channel = c;
                        final s = extra['subscribed'];
                        if (s is bool) initiallySubscribed = s;
                      }
                      return PodcastDetailScreen(
                        channelUuid: uuid,
                        channel: channel,
                        initiallySubscribed: initiallySubscribed,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'search',
                name: 'search',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: SearchScreen()),
                routes: [
                  GoRoute(
                    path: 'album/:id',
                    name: 'search_album_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const SearchScreen();
                      return AlbumDetailScreen(albumId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'search_album_edit',
                        builder: (context, state) {
                          final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          );
                          if (id == null) return const SearchScreen();
                          return AlbumEditScreen(albumId: id);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'artist/:id',
                    name: 'search_artist_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const SearchScreen();
                      return ArtistDetailScreen(artistId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'favorites',
                name: 'favorites',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: FavoritesScreen()),
              ),
              GoRoute(
                path: 'playlists',
                name: 'playlists',
                pageBuilder:
                    (context, state) =>
                        const NoTransitionPage(child: PlaylistsScreen()),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'playlist_detail',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      if (id == null) return const PlaylistsScreen();
                      return PlaylistDetailScreen(playlistId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'playlist_edit',
                        builder: (context, state) {
                          final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          );
                          if (id == null) return const PlaylistsScreen();
                          return PlaylistEditScreen(playlistId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'upload',
                name: 'upload',
                builder: (context, state) => const UploadScreen(),
              ),
              GoRoute(
                path: 'manage/library',
                name: 'library_admin',
                builder: (context, state) => const LibraryAdminScreen(),
                routes: [
                  GoRoute(
                    path: 'libraries',
                    name: 'manage_libraries',
                    builder: (context, state) => const ManageLibrariesScreen(),
                    routes: [
                      GoRoute(
                        path: ':uuid',
                        name: 'manage_library_detail',
                        builder: (context, state) {
                          final uuid = state.pathParameters['uuid'] ?? '';
                          if (uuid.isEmpty)
                            return const ManageLibrariesScreen();
                          return ManageLibraryDetailScreen(uuid: uuid);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'uploads',
                    name: 'manage_uploads',
                    builder: (context, state) => const ManageUploadsScreen(),
                  ),
                  GoRoute(
                    path: 'tags',
                    name: 'manage_tags',
                    builder: (context, state) => const ManageTagsScreen(),
                  ),
                  GoRoute(
                    path: 'channels',
                    name: 'manage_channels',
                    builder: (context, state) => const ManageChannelsScreen(),
                    routes: [
                      GoRoute(
                        path: ':uuid',
                        name: 'manage_channel_detail',
                        builder: (context, state) {
                          final uuid = state.pathParameters['uuid'] ?? '';
                          if (uuid.isEmpty) {
                            return const ManageChannelsScreen();
                          }
                          return ManageChannelDetailScreen(uuid: uuid);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'manage/settings',
                name: 'instance_settings',
                builder: (context, state) => const InstanceSettingsScreen(),
              ),
              GoRoute(
                path: 'manage/users',
                name: 'manage_users',
                builder: (context, state) => const ManageUsersScreen(),
                routes: [
                  // Registered before :id so "invitations" is not captured as an id.
                  GoRoute(
                    path: 'invitations',
                    name: 'manage_invitations',
                    builder:
                        (context, state) => const ManageInvitationsScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: 'manage_user_detail',
                    builder: (context, state) {
                      final raw = state.pathParameters['id'] ?? '';
                      final id = int.tryParse(raw);
                      if (id == null) return const ManageUsersScreen();
                      return ManageUserDetailScreen(userId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (overlay the shell — and share visitor stack)
      GoRoute(
        path: '/now-playing',
        name: 'now_playing',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              child: const NowPlayingScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                );
              },
            ),
      ),
      GoRoute(
        path: '/queue',
        name: 'queue',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              child: const QueueScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                );
              },
            ),
      ),
    ],
  );
});
