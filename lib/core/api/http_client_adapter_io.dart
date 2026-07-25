import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// How long idle keep-alive sockets are held open for reuse.
///
/// Dart's default is 15 seconds, which is shorter than a music app's bursty
/// request pattern (scrobbles, page loads, cover art fetches separated by
/// playback). Every expired socket forces a fresh DNS lookup + TCP + TLS
/// handshake on the next request.
///
/// 60 seconds keeps sockets warm across bursts while staying below common
/// reverse-proxy keep-alive limits (nginx defaults to 75 s).
const _idleTimeout = Duration(seconds: 60);

/// Cap on parallel sockets per host so request bursts reuse a small pool.
const _maxConnectionsPerHost = 8;

void configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..idleTimeout = _idleTimeout
      ..maxConnectionsPerHost = _maxConnectionsPerHost,
  );
}
