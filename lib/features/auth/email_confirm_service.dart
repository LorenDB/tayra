import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayra/core/api/http_client_factory.dart';

/// Unauthenticated email-verification API calls for the first-party login UI.
class EmailConfirmService {
  EmailConfirmService({Dio? dio}) : _dio = dio ?? createDio();

  final Dio _dio;

  String _normalizeServerUrl(String serverUrl) {
    var url = serverUrl.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  /// Base URL for API paths. Web prefers same-origin relative URLs.
  String _apiBase(String? serverUrl) {
    if (kIsWeb) return '';
    if (serverUrl == null || serverUrl.trim().isEmpty) {
      throw ArgumentError('serverUrl is required on non-web platforms');
    }
    return _normalizeServerUrl(serverUrl);
  }

  /// POST `/api/v1/auth/registration/verify-email/` — confirm email from link key.
  Future<void> confirmEmail({required String key, String? serverUrl}) async {
    final base = _apiBase(serverUrl);
    final response = await _dio.post(
      '$base/api/v1/auth/registration/verify-email/',
      data: {'key': key.trim()},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'Accept': 'application/json',
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
        validateStatus: (s) => s != null && s < 500,
        responseType: ResponseType.json,
      ),
    );
    if (response.statusCode == 200) return;
    throw EmailConfirmException(
      _formatError(response.data, response.statusCode) ??
          'Could not verify email. The link may be invalid or expired.',
      statusCode: response.statusCode,
    );
  }

  static String? _formatError(dynamic data, int? status) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in ['detail', 'key', 'non_field_errors']) {
        final v = map[key];
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    }
    if (status == 400) {
      return 'This verification link is invalid or has already been used.';
    }
    if (status == 404) {
      return 'This verification link is invalid or has already been used.';
    }
    if (status == 429) {
      return 'Too many attempts. Please wait and try again.';
    }
    return null;
  }
}

class EmailConfirmException implements Exception {
  EmailConfirmException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final emailConfirmServiceProvider = Provider<EmailConfirmService>((ref) {
  return EmailConfirmService();
});
