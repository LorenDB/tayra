import 'dart:convert';

import 'package:dio/dio.dart';

/// Answers each request from [handler] and records what was sent.
///
/// Return a [ResponseBody] (see [jsonBody]) or throw a [DioException] to
/// simulate a transport failure.
class ScriptedHttpAdapter implements HttpClientAdapter {
  ScriptedHttpAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;

  final List<RequestOptions> requests = [];

  /// Requests whose path ends with [suffix].
  List<RequestOptions> requestsTo(String suffix) =>
      requests.where((r) => r.uri.path.endsWith(suffix)).toList();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    // Snapshot: a replayed request reuses (and mutates) the same options.
    requests.add(options.copyWith(headers: Map.of(options.headers)));
    return handler(options);
  }
}

ResponseBody jsonBody(Object? body, [int status = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// A failure before any response arrived (DNS, refused connection, timeout).
DioException connectionFailure(RequestOptions options) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: 'connection refused',
  );
}
