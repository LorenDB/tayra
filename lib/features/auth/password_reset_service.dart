import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayra/core/api/http_client_factory.dart';

/// Unauthenticated password-reset API calls for the first-party login UI.
class PasswordResetService {
  PasswordResetService({Dio? dio}) : _dio = dio ?? createDio();

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

  /// POST `/api/v1/auth/password/reset/` — send reset email if the address exists.
  ///
  /// The server always returns 200 for valid-shaped requests (no email enumeration).
  Future<void> requestReset({required String email, String? serverUrl}) async {
    final base = _apiBase(serverUrl);
    final response = await _dio.post(
      '$base/api/v1/auth/password/reset/',
      data: {'email': email.trim()},
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
    throw PasswordResetException(
      _formatError(response.data, response.statusCode) ??
          'Could not request a password reset.',
      statusCode: response.statusCode,
    );
  }

  /// POST `/api/v1/auth/password/reset/confirm/` — set a new password from email link.
  ///
  /// [newPassword1] / [newPassword2] are the real passwords (plaintext). The
  /// API runs them through Django's password forms / [User.set_password], which
  /// applies the transport pre-hash for first-party login storage.
  Future<void> confirmReset({
    required String uid,
    required String token,
    required String newPassword1,
    required String newPassword2,
    String? serverUrl,
  }) async {
    final base = _apiBase(serverUrl);
    final response = await _dio.post(
      '$base/api/v1/auth/password/reset/confirm/',
      data: {
        'uid': uid,
        'token': token,
        'new_password1': newPassword1,
        'new_password2': newPassword2,
      },
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
    throw PasswordResetException(
      _formatError(response.data, response.statusCode) ??
          'Could not reset password. The link may be invalid or expired.',
      statusCode: response.statusCode,
    );
  }

  static String? _formatError(dynamic data, int? status) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in [
        'detail',
        'email',
        'uid',
        'token',
        'new_password1',
        'new_password2',
        'non_field_errors',
      ]) {
        final v = map[key];
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    }
    if (status == 400) {
      return 'Invalid request. Check the form and try again.';
    }
    if (status == 429) {
      return 'Too many attempts. Please wait and try again.';
    }
    return null;
  }
}

class PasswordResetException implements Exception {
  PasswordResetException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final passwordResetServiceProvider = Provider<PasswordResetService>((ref) {
  return PasswordResetService();
});
