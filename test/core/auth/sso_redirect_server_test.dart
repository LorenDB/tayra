import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayra/core/auth/sso_redirect_server.dart';

void main() {
  test(
    'start() binds a random loopback port and returns a callback URL',
    () async {
      final server = LoopbackRedirectServer();
      final url = await server.start();
      addTearDown(server.close);

      expect(url, isNotNull);
      final uri = Uri.parse(url!);
      expect(uri.scheme, 'http');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, greaterThan(0));
      expect(uri.path, '/sso/callback');
      // Port is ephemeral: two servers must not collide.
      final other = LoopbackRedirectServer();
      final otherUrl = await other.start();
      addTearDown(other.close);
      expect(Uri.parse(otherUrl!).port, isNot(uri.port));
    },
  );

  test(
    'wait() resolves with the redirect URL carrying code and state',
    () async {
      final server = LoopbackRedirectServer();
      final url = await server.start();
      addTearDown(server.close);
      final uri = Uri.parse(url!);

      final client = HttpClient();
      final waitFuture = server.wait();

      // Simulate the pod's browser redirect.
      final req = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${uri.port}/sso/callback',
        ).replace(queryParameters: {'code': 'abc123', 'state': 'xyz'}),
      );
      final resp = await req.close();
      final body = await resp.transform(const Utf8Decoder()).join();

      expect(resp.statusCode, 200);
      expect(body, contains('close this tab'));

      final callback = await waitFuture.timeout(const Duration(seconds: 5));
      expect(callback.queryParameters['code'], 'abc123');
      expect(callback.queryParameters['state'], 'xyz');

      client.close(force: true);
    },
  );

  test('params() extracts code / error / state', () {
    final p = LoopbackRedirectServer.params(
      Uri.parse('http://127.0.0.1:1/sso/callback?code=c&state=s&ignored=1'),
    );
    expect(p, {'code': 'c', 'state': 's'});

    final e = LoopbackRedirectServer.params(
      Uri.parse('tayra://sso/callback?error=access_denied'),
    );
    expect(e, {'error': 'access_denied'});
  });
}
