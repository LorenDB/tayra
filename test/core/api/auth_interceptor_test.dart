import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/auth/auth_provider.dart';

import '../../support/scripted_http_adapter.dart';

/// Auth notifier with a scripted refresh, so the interceptor's decisions can
/// be observed without a token endpoint.
class _ScriptedAuth extends AuthNotifier {
  _ScriptedAuth(this._initial, this.refreshOutcome);

  final AuthState _initial;
  TokenRefreshOutcome refreshOutcome;

  int refreshCalls = 0;
  int autoLogouts = 0;

  @override
  AuthState build() => _initial;

  @override
  Future<void> ensureFreshAccessToken() async {}

  @override
  Future<TokenRefreshOutcome> refreshAccessToken() async {
    refreshCalls++;
    if (refreshOutcome == TokenRefreshOutcome.refreshed) {
      state = state.copyWith(accessToken: 'fresh-token');
    }
    return refreshOutcome;
  }

  @override
  Future<void> logoutAutomatically() async {
    autoLogouts++;
    state = const AuthState();
  }
}

void main() {
  late _ScriptedAuth auth;
  late ScriptedHttpAdapter api;
  late ScriptedHttpAdapter replay;
  late Dio dio;

  /// Wire a Dio with the interceptor against [initial] auth state. The first
  /// attempt of every request is rejected with 401; the replay succeeds.
  void wire({
    required AuthState initial,
    TokenRefreshOutcome refreshOutcome = TokenRefreshOutcome.refreshed,
  }) {
    auth = _ScriptedAuth(initial, refreshOutcome);
    api = ScriptedHttpAdapter(
      (_) async => jsonBody({'detail': 'expired'}, 401),
    );
    replay = ScriptedHttpAdapter((_) async => jsonBody({'ok': true}));

    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith(() => auth)],
    );
    addTearDown(container.dispose);

    final dioProvider = Provider<Dio>((ref) {
      final dio = Dio()..httpClientAdapter = api;
      dio.interceptors.add(
        AuthInterceptor(ref, retryDio: Dio()..httpClientAdapter = replay),
      );
      return dio;
    });
    dio = container.read(dioProvider);
  }

  const signedIn = AuthState(
    serverUrl: 'https://pod.example',
    accessToken: 'stale-token',
    refreshTokenValue: 'refresh-1',
  );

  String? bearer(RequestOptions options) =>
      options.headers['Authorization'] as String?;

  test('a 401 refreshes the token and replays the request with it', () async {
    wire(initial: signedIn);

    final response = await dio.get<dynamic>('https://pod.example/api/v1/x/');

    expect(response.data, {'ok': true});
    expect(auth.refreshCalls, 1);
    expect(auth.autoLogouts, 0);
    expect(bearer(api.requests.single), 'Bearer stale-token');
    expect(bearer(replay.requests.single), 'Bearer fresh-token');
  });

  test('a rejected refresh ends the session', () async {
    wire(initial: signedIn, refreshOutcome: TokenRefreshOutcome.rejected);

    await expectLater(
      dio.get<dynamic>('https://pod.example/api/v1/x/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );

    expect(auth.autoLogouts, 1);
    expect(replay.requests, isEmpty);
  });

  test('a refresh that could not be attempted keeps the session', () async {
    wire(initial: signedIn, refreshOutcome: TokenRefreshOutcome.unavailable);

    await expectLater(
      dio.get<dynamic>('https://pod.example/api/v1/x/'),
      throwsA(isA<DioException>()),
    );

    expect(auth.refreshCalls, 1);
    expect(auth.autoLogouts, 0, reason: 'a network blip must not sign out');
    expect(auth.state.accessToken, 'stale-token');
    expect(replay.requests, isEmpty);
  });

  test(
    'a request overtaken by a refresh is replayed without another',
    () async {
      wire(initial: signedIn);
      // The request leaves with the stale token; by the time its 401 comes
      // back, a concurrent request has already refreshed.
      api.handler = (_) async {
        auth.state = auth.state.copyWith(accessToken: 'already-rotated');
        return jsonBody({'detail': 'expired'}, 401);
      };

      final response = await dio.get<dynamic>('https://pod.example/api/v1/x/');

      expect(response.data, {'ok': true});
      expect(auth.refreshCalls, 0, reason: 'refreshing again would revoke it');
      expect(bearer(replay.requests.single), 'Bearer already-rotated');
    },
  );

  test('a 401 while signed out neither refreshes nor signs out', () async {
    wire(initial: const AuthState());

    await expectLater(
      dio.get<dynamic>('https://pod.example/api/v1/x/'),
      throwsA(isA<DioException>()),
    );

    expect(bearer(api.requests.single), isNull);
    expect(auth.refreshCalls, 0);
    expect(auth.autoLogouts, 0);
  });

  test('skip_auth requests carry no token and are never replayed', () async {
    wire(initial: signedIn);

    await expectLater(
      dio.get<dynamic>(
        'https://pod.example/api/v1/share/abc/',
        options: Options(extra: {'skip_auth': true}),
      ),
      throwsA(isA<DioException>()),
    );

    expect(bearer(api.requests.single), isNull);
    expect(auth.refreshCalls, 0);
    expect(replay.requests, isEmpty);
  });

  test('other errors pass through untouched', () async {
    wire(initial: signedIn);
    api.handler = (_) async => jsonBody({'detail': 'nope'}, 404);

    await expectLater(
      dio.get<dynamic>('https://pod.example/api/v1/x/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );

    expect(auth.refreshCalls, 0);
    expect(auth.autoLogouts, 0);
  });
}
