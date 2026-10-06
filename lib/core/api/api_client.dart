import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/api/http_client_factory.dart';
import 'package:tayra/core/auth/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = createDio();
  dio.options.connectTimeout = const Duration(seconds: 15);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  dio.options.headers['Accept'] = 'application/json';

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(AnalyticsInterceptor());

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  /// Long-lived Dio for retrying requests after a token refresh. Kept as a
  /// field (rather than constructed per 401) so its connection pool — and
  /// the DNS/TCP/TLS work behind it — is reused across retries.
  final Dio _retryDio;

  AuthInterceptor(this._ref, {Dio? retryDio})
    : _retryDio =
          retryDio ??
          createDio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Public share resolve and similar must not send Bearer tokens.
    if (options.extra['skip_auth'] == true) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }
    // A token already known to be expired would only earn a 401 and a
    // replay. Refresh it first; if that is not possible the request goes out
    // as it is and the 401 path below decides what happens.
    try {
      await _ref.read(authStateProvider.notifier).ensureFreshAccessToken();
    } catch (_) {}
    final authState = _ref.read(authStateProvider);
    if (authState.accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${authState.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.requestOptions.extra['skip_auth'] == true ||
        err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final currentToken = _ref.read(authStateProvider).accessToken;
    // Not signed in (or signed out while the request was in flight): there
    // is no session to refresh or to end.
    if (currentToken == null) {
      handler.next(err);
      return;
    }

    final authNotifier = _ref.read(authStateProvider.notifier);
    if (!wasSentWithToken(err.requestOptions, currentToken)) {
      // Another request refreshed the token while this one was in flight.
      // Replay with the token now in use; refreshing again would rotate
      // (and revoke) a token other requests are relying on.
    } else {
      switch (await authNotifier.refreshAccessToken()) {
        case TokenRefreshOutcome.refreshed:
          break;
        case TokenRefreshOutcome.rejected:
          await authNotifier.logoutAutomatically();
          handler.next(err);
          return;
        case TokenRefreshOutcome.unavailable:
          // The token endpoint could not be reached. Fail this request, but
          // keep the session: it is probably still valid.
          handler.next(err);
          return;
      }
    }

    final accessToken = _ref.read(authStateProvider).accessToken;
    if (accessToken == null) {
      handler.next(err);
      return;
    }
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer $accessToken';
    try {
      // FormData streams can only be finalized once. Clone before retry so
      // multipart uploads (attachments, audio) survive token refresh.
      if (opts.data is FormData) {
        opts.data = (opts.data as FormData).clone();
      }
      final response = await _retryDio.fetch(opts);
      handler.resolve(response);
    } catch (e) {
      // Surface the retry failure (not the original 401) so callers and
      // analytics see the real error after a successful token rotation.
      handler.next(e is DioException ? e : err);
    }
  }

  /// Whether [options] went out carrying [accessToken] as its Bearer token.
  @visibleForTesting
  static bool wasSentWithToken(RequestOptions options, String accessToken) {
    return options.headers['Authorization'] == 'Bearer $accessToken';
  }
}

class AnalyticsInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Analytics.track('api_call', {
      'method': response.requestOptions.method,
      'status': response.statusCode,
      'endpoint': _extractEndpoint(response.requestOptions.path),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Only record high-level error metadata to avoid sending potentially
    // sensitive server responses or request bodies to the analytics backend.
    Analytics.track('api_error', {
      'method': err.requestOptions.method,
      'status': err.response?.statusCode,
      'endpoint': _extractEndpoint(err.requestOptions.path),
      'error_type': err.type.name,
      // Avoid logging raw error messages or response bodies which may
      // contain PII. Instead, surface whether a response was present.
      'had_response': err.response != null,
    });
    handler.next(err);
  }

  String _extractEndpoint(String path) {
    // Extract a short, non-identifying endpoint name for analytics.
    // We try to skip common prefixes like `api` and version segments
    // (e.g. `v1`) and return the next path segment (the resource name)
    // so we don't include numeric IDs or query params in events.
    try {
      final uri = Uri.parse(path);
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      var i = 0;
      // Skip common prefixes like `api` and version segments (`v1`, `v2`, ...)
      while (i < segs.length &&
          (segs[i] == 'api' ||
              RegExp(r'^v\d+$').hasMatch(segs[i]) ||
              RegExp(r'^v\d+$').hasMatch(segs[i].toLowerCase()))) {
        i++;
      }
      if (i < segs.length) return segs[i];
      // If we couldn't extract a safe segment, return a generic placeholder
      // instead of the full path which might contain numeric IDs.
      return 'unknown_endpoint';
    } catch (_) {
      // If parsing fails, return a generic placeholder.
      return 'unknown_endpoint';
    }
  }
}

/// Paginated response wrapper
class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT, {

    /// When true, skip individual results that fail to parse instead of
    /// failing the whole page (e.g. listenings with a missing nested track).
    bool skipMalformed = false,
  }) {
    final raw = json['results'] as List<dynamic>? ?? const [];
    final results = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map =
          item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);
      if (!skipMalformed) {
        results.add(fromJsonT(map));
        continue;
      }
      try {
        results.add(fromJsonT(map));
      } catch (_) {
        // Best-effort: one bad row should not blank a whole list UI.
      }
    }
    return PaginatedResponse<T>(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: results,
    );
  }
}
