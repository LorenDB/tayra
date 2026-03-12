import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/auth/auth_provider.dart';
import 'package:tayra/features/auth/presentation/login_screen.dart';
import 'package:tayra/features/home/home_screen.dart';
import 'package:tayra/features/browse/browse_screen.dart';
import 'package:tayra/features/browse/artist_detail_screen.dart';
import 'package:tayra/features/browse/album_detail_screen.dart';
import 'package:tayra/features/settings/settings_screen.dart';
import 'package:tayra/features/search/search_screen.dart';
import 'package:tayra/features/favorites/favorites_screen.dart';
import 'package:tayra/features/playlists/playlists_screen.dart';
import 'package:tayra/features/playlists/playlist_detail_screen.dart';
import 'package:tayra/features/player/now_playing_screen.dart';
import 'package:tayra/features/player/queue_screen.dart';
import 'package:tayra/core/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    initialLocation: authChangeNotifier.state.isAuthenticated ? '/' : '/login',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final isAuth = authChangeNotifier.state.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder:
                (context, state) => const NoTransitionPage(child: HomeScreen()),
            routes: [
              GoRoute(
                path: 'album/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
              GoRoute(
                path: 'artist/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/browse',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: BrowseScreen()),
            routes: [
              GoRoute(
                path: 'artist/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
              GoRoute(
                path: 'album/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/search',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
            routes: [
              GoRoute(
                path: 'album/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AlbumDetailScreen(albumId: id);
                },
              ),
              GoRoute(
                path: 'artist/:id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ArtistDetailScreen(artistId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/favorites',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: FavoritesScreen()),
          ),
          GoRoute(
            path: '/playlists',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: PlaylistsScreen()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return PlaylistDetailScreen(playlistId: id);
                },
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (overlay the shell)
      GoRoute(
        path: '/now-playing',
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
