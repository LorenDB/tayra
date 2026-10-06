import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/auth/auth_provider.dart';

import '../../support/scripted_http_adapter.dart';

const _server = 'https://pod.example';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScriptedHttpAdapter adapter;
  late ProviderContainer container;

  /// A container whose auth notifier has loaded a saved session.
  Future<AuthNotifier> signedIn({
    String? refreshToken = 'refresh-1',
    DateTime? expiresAt,
  }) async {
    SharedPreferences.setMockInitialValues({
      'server_url': _server,
      if (expiresAt != null)
        'access_token_expires_at': expiresAt.millisecondsSinceEpoch,
    });
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-1',
      if (refreshToken != null) 'refresh_token': refreshToken,
      'client_id': 'client-1',
    });
    container = ProviderContainer(
      overrides: [
        authHttpClientProvider.overrideWithValue(
          Dio()..httpClientAdapter = adapter,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authStateProvider.notifier);
    await pumpEventQueue();
    expect(container.read(authStateProvider).accessToken, 'access-1');
    adapter.requests.clear();
    return notifier;
  }

  setUp(() {
    // The listen token lookup that follows a load or refresh.
    adapter = ScriptedHttpAdapter(
      (options) async => jsonBody({
        'tokens': {'listen': 'listen-1'},
      }),
    );
  });

  void answerTokenEndpointWith(
    Future<ResponseBody> Function(RequestOptions options) answer,
  ) {
    adapter.handler = (options) async {
      if (options.uri.path.endsWith('/oauth/token/')) return answer(options);
      return jsonBody({
        'tokens': {'listen': 'listen-1'},
      });
    };
  }

  test(
    'a successful refresh installs the new tokens and their expiry',
    () async {
      final notifier = await signedIn();
      answerTokenEndpointWith(
        (_) async => jsonBody({
          'access_token': 'access-2',
          'refresh_token': 'refresh-2',
          'expires_in': 36000,
        }),
      );

      final before = DateTime.now();
      expect(
        await notifier.refreshAccessToken(),
        TokenRefreshOutcome.refreshed,
      );

      final state = container.read(authStateProvider);
      expect(state.accessToken, 'access-2');
      expect(state.refreshTokenValue, 'refresh-2');
      expect(state.isAuthenticated, isTrue);
      final expiresAt = state.accessTokenExpiresAt!;
      expect(
        expiresAt.difference(before).inSeconds,
        inInclusiveRange(35990, 36010),
      );

      final sent = adapter.requestsTo('/oauth/token/').single;
      expect(sent.data, containsPair('refresh_token', 'refresh-1'));
      expect(sent.data, containsPair('grant_type', 'refresh_token'));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('access_token_expires_at'),
        expiresAt.millisecondsSinceEpoch,
      );
    },
  );

  test('the server refusing the refresh token is a rejection', () async {
    for (final status in [400, 401, 403]) {
      final notifier = await signedIn();
      answerTokenEndpointWith(
        (_) async => jsonBody({'error': 'invalid_grant'}, status),
      );

      expect(
        await notifier.refreshAccessToken(),
        TokenRefreshOutcome.rejected,
        reason: 'status $status',
      );
    }
  });

  test(
    'an unreachable or overloaded token endpoint keeps the session',
    () async {
      final failures = <Future<ResponseBody> Function(RequestOptions)>[
        (options) async => throw connectionFailure(options),
        (_) async => jsonBody({'detail': 'throttled'}, 429),
        (_) async => jsonBody({'detail': 'oops'}, 500),
        (_) async => jsonBody({'detail': 'bad gateway'}, 502),
        (_) async => jsonBody({'detail': 'unavailable'}, 503),
        // A 200 that is not a token response (captive portal, proxy page).
        (_) async => jsonBody({'hello': 'world'}),
      ];

      for (final failure in failures) {
        final notifier = await signedIn();
        answerTokenEndpointWith(failure);

        expect(
          await notifier.refreshAccessToken(),
          TokenRefreshOutcome.unavailable,
        );
        final state = container.read(authStateProvider);
        expect(state.accessToken, 'access-1');
        expect(state.refreshTokenValue, 'refresh-1');
        expect(state.isAuthenticated, isTrue);
      }
    },
  );

  test('without a refresh token there is nothing to ask the server', () async {
    final notifier = await signedIn(refreshToken: null);

    expect(await notifier.refreshAccessToken(), TokenRefreshOutcome.rejected);
    expect(adapter.requestsTo('/oauth/token/'), isEmpty);
  });

  test('concurrent refreshes share one request', () async {
    final notifier = await signedIn();
    answerTokenEndpointWith((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return jsonBody({'access_token': 'access-2', 'refresh_token': 'r2'});
    });

    final results = await Future.wait([
      notifier.refreshAccessToken(),
      notifier.refreshAccessToken(),
      notifier.refreshToken(),
    ]);

    expect(results, [
      TokenRefreshOutcome.refreshed,
      TokenRefreshOutcome.refreshed,
      true,
    ]);
    expect(adapter.requestsTo('/oauth/token/'), hasLength(1));
  });

  group('ensureFreshAccessToken', () {
    void answerWithNewToken() {
      answerTokenEndpointWith(
        (_) async => jsonBody({'access_token': 'access-2', 'expires_in': 600}),
      );
    }

    test('refreshes a token that has expired', () async {
      final notifier = await signedIn(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      answerWithNewToken();

      await notifier.ensureFreshAccessToken();

      expect(container.read(authStateProvider).accessToken, 'access-2');
    });

    test('refreshes a token about to expire', () async {
      final notifier = await signedIn(
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );
      answerWithNewToken();

      await notifier.ensureFreshAccessToken();

      expect(container.read(authStateProvider).accessToken, 'access-2');
    });

    test('leaves a token with time left alone', () async {
      final notifier = await signedIn(
        expiresAt: DateTime.now().add(const Duration(hours: 5)),
      );
      answerWithNewToken();

      await notifier.ensureFreshAccessToken();

      expect(adapter.requestsTo('/oauth/token/'), isEmpty);
      expect(container.read(authStateProvider).accessToken, 'access-1');
    });

    test('does not retry on every call while the endpoint is down', () async {
      final notifier = await signedIn(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      answerTokenEndpointWith(
        (options) async => throw connectionFailure(options),
      );

      await notifier.ensureFreshAccessToken();
      await notifier.ensureFreshAccessToken();
      await notifier.ensureFreshAccessToken();

      expect(adapter.requestsTo('/oauth/token/'), hasLength(1));
      // An explicit refresh (the 401 path) is not held back.
      await notifier.refreshAccessToken();
      expect(adapter.requestsTo('/oauth/token/'), hasLength(2));
    });

    test('does nothing when the expiry is unknown', () async {
      final notifier = await signedIn();
      answerWithNewToken();

      await notifier.ensureFreshAccessToken();

      expect(adapter.requestsTo('/oauth/token/'), isEmpty);
    });
  });
}
