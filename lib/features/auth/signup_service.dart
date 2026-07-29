import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayra/core/api/http_client_factory.dart';

/// Unauthenticated account registration (`POST /api/v1/auth/registration/`).
///
/// Passwords are sent as real passwords (not the first-party transport digest)
/// so Django's [User.set_password] stores them correctly for later login.
class SignupService {
  SignupService({Dio? dio}) : _dio = dio ?? createDio();

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

  /// POST `/api/v1/auth/registration/` — create a user account.
  ///
  /// Returns 201 on success. When open registration is disabled, [invitation]
  /// must be a valid open invite code (otherwise the server returns 403).
  Future<void> register({
    required String username,
    required String email,
    required String password1,
    required String password2,
    String? invitation,
    String? serverUrl,
  }) async {
    final base = _apiBase(serverUrl);
    final body = <String, dynamic>{
      'username': username.trim(),
      'email': email.trim(),
      'password1': password1,
      'password2': password2,
    };
    final invite = invitation?.trim();
    if (invite != null && invite.isNotEmpty) {
      body['invitation'] = invite;
    }

    final response = await _dio.post(
      '$base/api/v1/auth/registration/',
      data: body,
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
    if (response.statusCode == 201) return;
    throw SignupException(
      _formatError(response.data, response.statusCode) ??
          'Could not create account.',
      statusCode: response.statusCode,
    );
  }

  static String? _formatError(dynamic data, int? status) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in [
        'detail',
        'username',
        'email',
        'password1',
        'password2',
        'invitation',
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
    if (status == 403) {
      return 'Registration has been disabled. An invitation code may be required.';
    }
    if (status == 429) {
      return 'Too many attempts. Please wait and try again.';
    }
    return null;
  }
}

class SignupException implements Exception {
  SignupException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final signupServiceProvider = Provider<SignupService>((ref) {
  return SignupService();
});
