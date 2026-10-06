import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/api/api_errors.dart';
import 'package:tayra/core/api/cached_api_repository.dart';

DioException _dio(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/api/v1/albums/');
  return DioException(
    requestOptions: options,
    type: type,
    response:
        status == null
            ? null
            : Response<dynamic>(requestOptions: options, statusCode: status),
    error: 'SocketException: Failed host lookup: pod.example (OS Error: …)',
  );
}

void main() {
  test('network failures do not leak exception text', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.unknown,
    ]) {
      final message = describeLoadError(_dio(type));
      expect(message, "Can't reach the server. Check your connection.");
    }
    expect(
      describeLoadError(_dio(DioExceptionType.receiveTimeout)),
      'The server took too long to respond.',
    );
  });

  test('HTTP statuses are explained', () {
    String forStatus(int status) =>
        describeLoadError(_dio(DioExceptionType.badResponse, status: status));

    expect(forStatus(403), "You don't have access to this.");
    expect(forStatus(404), 'This could not be found on the server.');
    expect(forStatus(429), 'Too many requests. Try again in a moment.');
    expect(forStatus(502), 'The server ran into a problem (502).');
    expect(forStatus(400), 'The server refused the request (400).');
  });

  test('the offline cache miss keeps its own wording', () {
    expect(
      describeLoadError(OfflineCacheMissException('albums_p1')),
      'Not available offline',
    );
  });

  test('plain exception messages pass through without the type prefix', () {
    expect(
      describeLoadError(Exception('Album has no tracks')),
      'Album has no tracks',
    );
  });

  test('long or multi-line errors are replaced', () {
    expect(describeLoadError(StateError('x' * 200)), 'Something went wrong.');
    expect(describeLoadError(Exception('a\nb')), 'Something went wrong.');
    expect(
      describeLoadError(const FormatException('Unexpected character')),
      'The server sent data this app could not read.',
    );
  });
}
