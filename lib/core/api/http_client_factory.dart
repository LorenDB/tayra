import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// How long idle keep-alive sockets are held open for reuse.
///
/// Dart's default is 15 seconds, which is shorter than a music app's bursty
/// request pattern (scrobbles, page loads, cover art fetches separated by
/// playback). Every expired socket forces a fresh DNS lookup + TCP + TLS
/// handshake on the next request, which shows up as repeated `getaddrinfo`
/// calls in Android system logs (e.g. `DNS_CACHE` spam on ColorOS devices).
///
/// 60 seconds keeps sockets warm across bursts while staying below common
/// reverse-proxy keep-alive limits (nginx defaults to 75 s), so we do not
/// try to reuse sockets the server has already closed.
const _idleTimeout = Duration(seconds: 60);

/// Cap on parallel sockets per host so request bursts (album pages, cover
/// art grids) reuse a small pool instead of opening one socket — and one
/// DNS lookup — per request.
const _maxConnectionsPerHost = 8;

/// Create a [Dio] instance backed by an [HttpClient] tuned for connection
/// reuse.
///
/// All Dio instances in the app should be created through this factory and
/// kept long-lived (fields/singletons), never constructed per request:
/// each raw `Dio()` owns its own connection pool, so per-call instances
/// defeat keep-alive entirely.
Dio createDio([BaseOptions? options]) {
  final dio = options != null ? Dio(options) : Dio();
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient:
        () =>
            HttpClient()
              ..idleTimeout = _idleTimeout
              ..maxConnectionsPerHost = _maxConnectionsPerHost,
  );
  return dio;
}
