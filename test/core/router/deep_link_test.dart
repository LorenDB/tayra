import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';

void main() {
  group('safeInternalPath', () {
    test('accepts relative app paths', () {
      expect(safeInternalPath('/browse/album/5'), '/browse/album/5');
      expect(safeInternalPath('/playlists/12'), '/playlists/12');
      expect(safeInternalPath('/year-review/2025'), '/year-review/2025');
      expect(safeInternalPath('/search?q=beatles'), '/search?q=beatles');
    });

    test('accepts authorize with query (spaces re-encoded)', () {
      const from =
          '/authorize?response_type=code&client_id=abc&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read write';
      final safe = safeInternalPath(from);
      expect(safe, isNotNull);
      expect(safe, startsWith('/authorize?'));
      expect(safe, isNot(contains('read write')));
    });

    test('rejects absolute / open redirects', () {
      expect(safeInternalPath('https://evil.example/phish'), isNull);
      expect(safeInternalPath('//evil.example/phish'), isNull);
      expect(safeInternalPath('browse/album/5'), isNull);
    });

    test('rejects login and splash (auth loop guards)', () {
      expect(safeInternalPath('/login'), isNull);
      expect(safeInternalPath('/login?from=/browse'), isNull);
      expect(safeInternalPath('/splash'), isNull);
      expect(safeInternalPath('/splash?from=/browse'), isNull);
    });

    test('rejects empty / null', () {
      expect(safeInternalPath(null), isNull);
      expect(safeInternalPath(''), isNull);
    });
  });

  group('deep link auth bounce', () {
    /// Minimal router mirroring app redirect rules for deep-link preservation.
    GoRouter buildRouter({
      required ValueNotifier<({bool checking, bool auth})> auth,
    }) {
      final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');
      return GoRouter(
        navigatorKey: rootKey,
        initialLocation: '/splash',
        refreshListenable: auth,
        redirect: (context, state) {
          final path =
              state.uri.path.length > 1 && state.uri.path.endsWith('/')
                  ? state.uri.path.substring(0, state.uri.path.length - 1)
                  : state.uri.path;
          final isLogin = path == '/login';
          final isSplash = path == '/splash';
          final isPublic = isPublicAuthPath(path);
          final from = state.uri.queryParameters['from'];

          if (auth.value.checking) {
            if (isPublic || isSplash) return null;
            final safe = safeInternalPath(
              state.uri.hasQuery
                  ? '${state.uri.path}?${state.uri.query}'
                  : state.uri.path,
            );
            if (safe == null) return '/splash';
            return Uri(
              path: '/splash',
              queryParameters: {'from': safe},
            ).toString();
          }

          if (isSplash) {
            final safe = safeInternalPath(from);
            if (auth.value.auth) return safe ?? '/';
            if (safe != null) {
              return Uri(
                path: '/login',
                queryParameters: {'from': safe},
              ).toString();
            }
            return '/login';
          }

          if (!auth.value.auth) {
            if (isPublic) return null;
            final safe = safeInternalPath(
              state.uri.hasQuery
                  ? '${state.uri.path}?${state.uri.query}'
                  : state.uri.path,
            );
            if (safe == null) return '/login';
            return Uri(
              path: '/login',
              queryParameters: {'from': safe},
            ).toString();
          }

          if (isLogin) {
            final safe = safeInternalPath(from);
            return safe ?? '/';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/splash',
            parentNavigatorKey: rootKey,
            builder: (_, _) => const Text('splash'),
          ),
          GoRoute(
            path: '/login',
            parentNavigatorKey: rootKey,
            builder:
                (_, state) =>
                    Text('login:${state.uri.queryParameters['from'] ?? ''}'),
          ),
          GoRoute(
            path: '/authorize',
            parentNavigatorKey: rootKey,
            builder: (_, _) => const Text('authorize'),
          ),
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Text('home'),
                routes: [
                  GoRoute(
                    path: 'browse/album/:id',
                    builder:
                        (_, state) =>
                            Text('album:${state.pathParameters['id']}'),
                  ),
                  GoRoute(
                    path: 'search',
                    builder:
                        (_, state) => Text(
                          'search:${state.uri.queryParameters['q'] ?? ''}',
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    testWidgets('preserves deep link through splash after auth restore', (
      tester,
    ) async {
      final auth = ValueNotifier((checking: true, auth: false));
      final router = buildRouter(auth: auth);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/browse/album/42');
      await tester.pumpAndSettle();
      // Parked on splash with from= while checking auth.
      expect(router.state.uri.path, '/splash');
      expect(router.state.uri.queryParameters['from'], '/browse/album/42');

      auth.value = (checking: false, auth: true);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/browse/album/42');
      expect(find.text('album:42'), findsOneWidget);
    });

    testWidgets('sends unauthenticated deep link to login with from=', (
      tester,
    ) async {
      final auth = ValueNotifier((checking: false, auth: false));
      final router = buildRouter(auth: auth);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/browse/album/7');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(router.state.uri.queryParameters['from'], '/browse/album/7');

      auth.value = (checking: false, auth: true);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/browse/album/7');
      expect(find.text('album:7'), findsOneWidget);
    });

    testWidgets('keeps authorize mounted while checking auth', (tester) async {
      final auth = ValueNotifier((checking: true, auth: false));
      final router = buildRouter(auth: auth);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/authorize?client_id=abc');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/authorize');
      expect(find.text('authorize'), findsOneWidget);
    });

    testWidgets('search query deep link path is matchable', (tester) async {
      final auth = ValueNotifier((checking: false, auth: true));
      final router = buildRouter(auth: auth);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/search?q=radiohead');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/search');
      expect(router.state.uri.queryParameters['q'], 'radiohead');
      expect(find.text('search:radiohead'), findsOneWidget);
    });
  });
}
