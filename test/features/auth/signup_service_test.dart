import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/auth/signup_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  late ResponseBody nextResponse;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return nextResponse;
  }
}

void main() {
  late Dio dio;
  late _RecordingAdapter adapter;
  late SignupService service;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    service = SignupService(dio: dio);
  });

  test('register posts credentials as plaintext passwords', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"username":"alice","email":"alice@example.com"}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.register(
      username: ' alice ',
      email: ' alice@example.com ',
      password1: 'real-password-1',
      password2: 'real-password-1',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.method, 'POST');
    expect(
      opts.uri.toString(),
      'https://music.example.com/api/v1/auth/registration/',
    );
    expect(opts.data, {
      'username': 'alice',
      'email': 'alice@example.com',
      'password1': 'real-password-1',
      'password2': 'real-password-1',
    });
  });

  test('register includes invitation when provided', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"username":"bob","email":"bob@example.com"}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.register(
      username: 'bob',
      email: 'bob@example.com',
      password1: 'secret',
      password2: 'secret',
      invitation: '  INVITE123  ',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.data['invitation'], 'INVITE123');
  });

  test('register omits blank invitation', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"username":"carol","email":"carol@example.com"}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.register(
      username: 'carol',
      email: 'carol@example.com',
      password1: 'secret',
      password2: 'secret',
      invitation: '   ',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.data.containsKey('invitation'), isFalse);
  });

  test('register throws SignupException on 403 detail', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"detail":"Registration has been disabled"}',
      403,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.register(
        username: 'dave',
        email: 'dave@example.com',
        password1: 'secret',
        password2: 'secret',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<SignupException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having(
              (e) => e.message,
              'message',
              contains('Registration has been disabled'),
            ),
      ),
    );
  });

  test('register throws SignupException on invalid invitation field', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"invitation":["Invalid invitation code"]}',
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.register(
        username: 'erin',
        email: 'erin@example.com',
        password1: 'secret',
        password2: 'secret',
        invitation: 'bad',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<SignupException>().having(
          (e) => e.message,
          'message',
          contains('Invalid invitation'),
        ),
      ),
    );
  });

  test('register throws SignupException on 429', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{}',
      429,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.register(
        username: 'frank',
        email: 'frank@example.com',
        password1: 'secret',
        password2: 'secret',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<SignupException>().having(
          (e) => e.message,
          'message',
          contains('Too many attempts'),
        ),
      ),
    );
  });
}
