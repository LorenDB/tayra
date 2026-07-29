import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tayra/core/router/app_router.dart';

void main() {
  group('isPublicAuthPath', () {
    test('login splash authorize', () {
      expect(isPublicAuthPath('/login'), isTrue);
      expect(isPublicAuthPath('/splash'), isTrue);
      expect(isPublicAuthPath('/authorize'), isTrue);
    });

    test('password reset request and confirm', () {
      expect(isPublicAuthPath('/auth/password/reset'), isTrue);
      expect(isPublicAuthPath('/auth/password/reset/'), isTrue);
      expect(isPublicAuthPath('/auth/password/reset/confirm'), isTrue);
      expect(isPublicAuthPath('/auth/password/reset/confirm/'), isTrue);
      expect(
        isPublicAuthPath('/auth/password/reset/confirm/MQ/abc-def'),
        isTrue,
      );
    });

    test('non-auth paths', () {
      expect(isPublicAuthPath('/'), isFalse);
      expect(isPublicAuthPath('/settings'), isFalse);
      expect(isPublicAuthPath('/auth/other'), isFalse);
    });
  });

  group('deep link routing', () {
    GoRouter buildRouter({required String initial}) {
      final rootKey = GlobalKey<NavigatorState>(debugLabel: 'test-root');
      return GoRouter(
        navigatorKey: rootKey,
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/login',
            parentNavigatorKey: rootKey,
            builder: (_, __) => const Text('login'),
          ),
          GoRoute(
            path: '/auth/password/reset/confirm/:uid/:token',
            parentNavigatorKey: rootKey,
            builder:
                (_, state) => Text(
                  'path:${state.pathParameters['uid']}:${state.pathParameters['token']}',
                ),
          ),
          GoRoute(
            path: '/auth/password/reset/confirm',
            parentNavigatorKey: rootKey,
            builder:
                (_, state) => Text(
                  'query:${state.uri.queryParameters['uid']}:${state.uri.queryParameters['token']}',
                ),
          ),
          GoRoute(
            path: '/auth/password/reset',
            parentNavigatorKey: rootKey,
            builder: (_, __) => const Text('request'),
          ),
          ShellRoute(
            builder: (_, __, child) => child,
            routes: [
              GoRoute(path: '/', builder: (_, __) => const Text('home')),
            ],
          ),
        ],
        errorBuilder: (_, state) => Text('error:${state.uri.path}'),
        redirect: (context, state) {
          // Mirror production: strip trailing slash, allow public auth paths.
          final path = state.uri.path;
          if (path.length > 1 && path.endsWith('/')) {
            final n = path.substring(0, path.length - 1);
            return state.uri.hasQuery ? '$n?${state.uri.query}' : n;
          }
          if (!isPublicAuthPath(path) && path != '/') {
            return '/login';
          }
          return null;
        },
      );
    }

    testWidgets('email query-param link (primary)', (tester) async {
      final router = buildRouter(
        initial: '/auth/password/reset/confirm?uid=MQ&token=abc-def',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('query:MQ:abc-def'), findsOneWidget);
    });

    testWidgets('email link with trailing slash', (tester) async {
      final router = buildRouter(
        initial: '/auth/password/reset/confirm/?uid=MQ&token=abc-def',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('query:MQ:abc-def'), findsOneWidget);
    });

    testWidgets('path-param confirm form', (tester) async {
      final router = buildRouter(
        initial: '/auth/password/reset/confirm/MQ/abc-def',
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('path:MQ:abc-def'), findsOneWidget);
    });

    testWidgets('request form', (tester) async {
      final router = buildRouter(initial: '/auth/password/reset');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('request'), findsOneWidget);
    });
  });
}
