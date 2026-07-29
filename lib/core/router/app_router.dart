import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/features/auth/presentation/login_screen.dart';
import 'package:tayra/features/auth/presentation/oauth_authorize_screen.dart';
import 'package:tayra/features/auth/presentation/password_reset_confirm_screen.dart';
import 'package:tayra/features/auth/presentation/password_reset_request_screen.dart';
import 'package:tayra/features/home/home_screen.dart';
import 'package:tayra/features/browse/browse_screen.dart';
import 'package:tayra/features/radios/radios_screen.dart';
import 'package:tayra/core/api/models.dart' as models;
import 'package:tayra/features/podcasts/podcasts_screen.dart';
import 'package:tayra/features/podcasts/podcast_detail_screen.dart';
import 'package:tayra/features/browse/artist_detail_screen.dart';
import 'package:tayra/features/browse/album_detail_screen.dart';
import 'package:tayra/features/browse/album_edit_screen.dart';
import 'package:tayra/features/settings/settings_screen.dart';
import 'package:tayra/features/settings/account_settings_screen.dart';
import 'package:tayra/features/favorites/favorites_screen.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/playlists/playlist_detail_screen.dart';
import 'package:tayra/features/playlists/playlist_edit_screen.dart';
import 'package:tayra/features/player/now_playing_screen.dart';
import 'package:tayra/features/player/queue_screen.dart';
import 'package:tayra/features/year_review/year_review_screen.dart';
import 'package:tayra/features/year_review/year_review_settings_screen.dart';
import 'package:tayra/features/settings/ai_provider_settings_screen.dart';
import 'package:tayra/features/settings/developer_settings_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/features/upload/upload_screen.dart';
import 'package:tayra/features/library_admin/library_admin_screen.dart';
import 'package:tayra/features/library_admin/manage_libraries_screen.dart';
import 'package:tayra/features/library_admin/manage_library_detail_screen.dart';
import 'package:tayra/features/library_admin/manage_uploads_screen.dart';
import 'package:tayra/features/library_admin/manage_tags_screen.dart';
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

/// Allow only same-app relative paths (blocks open redirects via `from=`).
///
/// Query strings may legitimately contain `https://…` (OAuth `redirect_uri`);
/// only the path / host are validated, not the raw string.
String? _safeInternalPath(String? from) {
  if (from == null || from.isEmpty) return null;
  final uri = Uri.tryParse(from);
  if (uri == null) return null;
  // Reject absolute URLs (open redirect).
  if (uri.hasScheme || uri.host.isNotEmpty) return null;
  if (!uri.path.startsWith('/') || uri.path.startsWith('//')) return null;
  // Re-serialize so query values are correctly encoded for go_router.
  return uri.toString();
}

/// Root navigator for routes outside [ShellRoute] (login, OAuth consent, …).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

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
                  onPressed: () => GoRouter.of(context).go('/'),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      );
    },
    redirect: (context, state) {
      final authState = authChangeNotifier.state;
      // Prefer uri.path over matchedLocation so query-bearing OAuth URLs are
      // classified correctly even mid-redirect.
      final path = state.uri.path;
      final isLoginRoute = path == '/login';
      final isSplashRoute = path == '/splash';
      final isAuthorizeRoute = path == '/authorize';
      final isPasswordResetRoute =
          path == '/auth/password/reset' ||
          path == '/auth/password/reset/confirm';

      // While restoring session, keep auth-related surfaces mounted so
      // `/authorize?…` query params are not stripped by a bounce through
      // `/splash` → `/` or `/login`.
      if (authState.isCheckingAuth) {
        if (isSplashRoute ||
            isLoginRoute ||
            isAuthorizeRoute ||
            isPasswordResetRoute) {
          return null;
        }
        return '/splash';
      }

      final isAuth = authState.isAuthenticated;

      if (isSplashRoute) return isAuth ? '/' : '/login';

      if (!isAuth) {
        if (isLoginRoute || isPasswordResetRoute) return null;
        // Preserve third-party OAuth query string across login.
        if (isAuthorizeRoute) {
          return Uri(
            path: '/login',
            queryParameters: {'from': state.uri.toString()},
          ).toString();
        }
        return '/login';
      }

      if (isLoginRoute) {
        final from = state.uri.queryParameters['from'];
        final safe = _safeInternalPath(from);
        if (safe != null) return safe;
        return '/';
      }
      // Allow finishing a reset while already signed in (rare email reopen).
      if (isPasswordResetRoute) return null;
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
      // Password reset (email link: /auth/password/reset/confirm?uid=&token=).
      // Register confirm before the shorter request path so matching is unambiguous.
      GoRoute(
        path: '/auth/password/reset/confirm',
        name: 'password_reset_confirm',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return PasswordResetConfirmScreen(
            uid: q['uid'] ?? '',
            token: q['token'] ?? '',
          );
        },
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
                  ),
                  GoRoute(
                    path: 'year-review-settings',
                    name: 'year_review_settings',
                    builder:
                        (context, state) => const YearReviewSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'ai-provider',
                    name: 'ai_provider_settings',
                    builder:
                        (context, state) => const AiProviderSettingsScreen(),
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
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (overlay the shell)
      GoRoute(
        path: '/now-playing',
        name: 'now_playing',
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
