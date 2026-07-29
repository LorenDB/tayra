import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/auth/password_reset_service.dart';

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
  late PasswordResetService service;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    service = PasswordResetService(dio: dio);
  });

  test('requestReset posts email to password reset endpoint', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"detail":"Password reset e-mail has been sent."}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.requestReset(
      email: ' user@example.com ',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.method, 'POST');
    expect(
      opts.uri.toString(),
      'https://music.example.com/api/v1/auth/password/reset/',
    );
    expect(opts.data, {'email': 'user@example.com'});
  });

  test('confirmReset posts uid token and passwords', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"detail":"Password has been reset with the new password."}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.confirmReset(
      uid: 'MQ',
      token: 'abc-def',
      newPassword1: 'new-secret-1',
      newPassword2: 'new-secret-1',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.method, 'POST');
    expect(
      opts.uri.toString(),
      'https://music.example.com/api/v1/auth/password/reset/confirm/',
    );
    expect(opts.data, {
      'uid': 'MQ',
      'token': 'abc-def',
      'new_password1': 'new-secret-1',
      'new_password2': 'new-secret-1',
    });
  });

  test('requestReset throws PasswordResetException on 400', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"email":["Enter a valid email address."]}',
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.requestReset(
        email: 'not-an-email',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<PasswordResetException>().having(
          (e) => e.message,
          'message',
          contains('valid email'),
        ),
      ),
    );
  });
}
