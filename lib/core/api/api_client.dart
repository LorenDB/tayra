import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:tayra/core/auth/auth_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.options.connectTimeout = const Duration(seconds: 15);
  dio.options.receiveTimeout = const Duration(seconds: 30);
  dio.options.headers['Accept'] = 'application/json';

  dio.interceptors.add(AuthInterceptor(ref));
  dio.interceptors.add(AnalyticsInterceptor());
  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (o) {}, // silent in release
    ),
  );

  return dio;
});

class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final authState = _ref.read(authStateProvider);
    if (authState.accessToken != null) {
      options.headers['Authorization'] = 'Bearer ${authState.accessToken}';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh the token
      final authNotifier = _ref.read(authStateProvider.notifier);
      final success = await authNotifier.refreshToken();
      if (success) {
        // Retry the request with the new token
        final authState = _ref.read(authStateProvider);
        err.requestOptions.headers['Authorization'] =
            'Bearer ${authState.accessToken}';
        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          // Fall through to the error handler
        }
      }
    }
    handler.next(err);
  }
}

class AnalyticsInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Aptabase.instance.trackEvent('api_call', {
      'method': response.requestOptions.method,
      'status': response.statusCode,
      'endpoint': _extractEndpoint(response.requestOptions.path),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Aptabase.instance.trackEvent('api_error', {
      'method': err.requestOptions.method,
      'status': err.response?.statusCode,
      'endpoint': _extractEndpoint(err.requestOptions.path),
      'error_type': err.type.name,
      'error_message': err.message,
    });
    handler.next(err);
  }

  String _extractEndpoint(String path) {
    // Extract endpoint without query params or IDs for privacy
    final uri = Uri.parse(path);
    return uri.pathSegments.take(2).join('/'); // e.g., 'api/v1/albums'
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
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse<T>(
      count: json['count'] as int? ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results:
          (json['results'] as List<dynamic>?)?.map((e) {
            if (e is Map<String, dynamic>) return fromJsonT(e);
            if (e is String) {
              try {
                final parsed = e is String ? e : e.toString();
                // Attempt to decode JSON string
                final decoded = parsed.isNotEmpty ? parsed : null;
                if (decoded != null) return fromJsonT({});
              } catch (_) {}
            }
            return fromJsonT({});
          }).toList() ??
          [],
    );
  }
}
