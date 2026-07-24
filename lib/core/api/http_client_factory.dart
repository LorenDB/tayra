import 'package:dio/dio.dart';

import 'package:tayra/core/api/http_client_adapter_io.dart'
    if (dart.library.html) 'package:tayra/core/api/http_client_adapter_web.dart'
    as adapter;

/// Create a [Dio] instance with a platform-appropriate HTTP adapter.
///
/// All Dio instances in the app should be created through this factory and
/// kept long-lived (fields/singletons), never constructed per request:
/// each raw `Dio()` owns its own connection pool, so per-call instances
/// defeat keep-alive entirely (on native).
Dio createDio([BaseOptions? options]) {
  final dio = options != null ? Dio(options) : Dio();
  adapter.configureHttpClient(dio);
  return dio;
}
