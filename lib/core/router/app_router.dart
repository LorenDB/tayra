import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/features/auth/presentation/login_screen.dart';
import 'package:tayra/features/home/home_screen.dart';
import 'package:tayra/features/browse/browse_screen.dart';
import 'package:tayra/features/radios/radios_screen.dart';
import 'package:tayra/features/browse/artist_detail_screen.dart';
import 'package:tayra/features/browse/album_detail_screen.dart';
import 'package:tayra/features/settings/settings_screen.dart';
import 'package:tayra/features/favorites/favorites_screen.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/playlists/playlist_detail_screen.dart';
import 'package:tayra/features/playlists/playlist_edit_screen.dart';
import 'package:tayra/features/player/now_playing_screen.dart';
import 'package:tayra/features/player/queue_screen.dart';
import 'package:tayra/features/year_review/year_review_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
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
      Aptabase.instance.trackEvent('screen_view', {'screen': routeName});
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

final appRouterProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,
    observers: [ref.watch(navigationObserverProvider)],
    redirect: (context, state) {
      final authState = authChangeNotifier.state;

      // While the initial auth check is in progress, stay on the splash screen.
      if (authState.isCheckingAuth) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isAuth = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';
      final isSplashRoute = state.matchedLocation == '/splash';

      if (isSplashRoute) return isAuth ? '/' : '/login';
      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder:
            (context, state) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Main shell with bottom nav
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
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
              GoRoute(
                path: 'artist/:id',
                name: 'artist_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
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
                      final year = int.parse(state.pathParameters['year']!);
                      return YearReviewScreen(year: year);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/browse',
            name: 'browse',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: BrowseScreen()),
            routes: [
              GoRoute(
                path: 'artist/:id',
                name: 'browse_artist_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
              GoRoute(
                path: 'album/:id',
                name: 'browse_album_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/radios',
            name: 'radios',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: RadiosScreen()),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
            routes: [
              GoRoute(
                path: 'album/:id',
                name: 'search_album_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
              GoRoute(
                path: 'artist/:id',
                name: 'search_artist_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/favorites',
            name: 'favorites',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: FavoritesScreen()),
          ),
          GoRoute(
            path: '/playlists',
            name: 'playlists',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: PlaylistsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'playlist_detail',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return PlaylistDetailScreen(playlistId: id);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'playlist_edit',
                    builder: (context, state) {
                      final id = int.parse(state.pathParameters['id']!);
                      return PlaylistEditScreen(playlistId: id);
                    },
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
