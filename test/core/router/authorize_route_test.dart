import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const Text('splash')),
        GoRoute(path: '/login', builder: (_, __) => const Text('login')),
        GoRoute(
          path: '/authorize',
          builder: (_, state) =>
              Text('auth:${state.uri.queryParameters['client_id']}'),
        ),
        ShellRoute(
          builder: (_, __, child) => child,
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('home')),
          ],
        ),
      ],
    );
  }

  testWidgets('authorize with encoded scope matches', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.go(
      '/authorize?response_type=code&client_id=abc&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read%20write',
    );
    await tester.pumpAndSettle();
    expect(find.text('auth:abc'), findsOneWidget);
  });

  testWidgets('authorize with RAW space in scope (post-login from= bug)', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    // Simulates returning an unencoded `from` value after login.
    const from =
        '/authorize?response_type=code&client_id=abc&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read write';
    router.go(from);
    await tester.pumpAndSettle();
    expect(find.text('auth:abc'), findsOneWidget);
  });

  testWidgets('authorize with https redirect_uri in query matches', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    const loc =
        '/authorize?response_type=code&client_id=abc&redirect_uri=https://example.com/cb&scope=read%20write';
    router.go(loc);
    await tester.pumpAndSettle();
    expect(find.text('auth:abc'), findsOneWidget);
  });

  test('Uri re-serialize encodes spaces in query', () {
    const from =
        '/authorize?response_type=code&client_id=abc&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=read write';
    final uri = Uri.parse(from);
    expect(uri.path, '/authorize');
    expect(uri.queryParameters['scope'], 'read write');
    // toString should percent-encode the space in the query
    expect(uri.toString(), isNot(contains('read write')));
    expect(uri.toString(), contains('read'));
  });
}
