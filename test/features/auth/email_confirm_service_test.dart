import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/auth/email_confirm_service.dart';

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
  late EmailConfirmService service;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    service = EmailConfirmService(dio: dio);
  });

  test('confirmEmail posts key to verify-email endpoint', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"detail":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    await service.confirmEmail(
      key: ' abc-def-key ',
      serverUrl: 'https://music.example.com',
    );

    final opts = adapter.lastOptions!;
    expect(opts.method, 'POST');
    expect(
      opts.uri.toString(),
      'https://music.example.com/api/v1/auth/registration/verify-email/',
    );
    expect(opts.data, {'key': 'abc-def-key'});
  });

  test('confirmEmail throws EmailConfirmException on 400', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{"key":["Invalid key"]}',
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.confirmEmail(
        key: 'bad-key',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<EmailConfirmException>().having(
          (e) => e.message,
          'message',
          contains('Invalid key'),
        ),
      ),
    );
  });

  test('confirmEmail throws friendly message on 404', () async {
    adapter.nextResponse = ResponseBody.fromString(
      '{}',
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    expect(
      () => service.confirmEmail(
        key: 'missing',
        serverUrl: 'https://music.example.com',
      ),
      throwsA(
        isA<EmailConfirmException>().having(
          (e) => e.message,
          'message',
          contains('invalid'),
        ),
      ),
    );
  });
}
