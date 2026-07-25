import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayra/core/api/api_client.dart';
import 'package:tayra/core/auth/auth_provider.dart';

// ── Models ──────────────────────────────────────────────────────────────

class OAuthApplicationInfo {
  final String clientId;
  final String name;
  final String scopes;

  const OAuthApplicationInfo({
    required this.clientId,
    required this.name,
    required this.scopes,
  });

  factory OAuthApplicationInfo.fromJson(Map<String, dynamic> json) {
    return OAuthApplicationInfo(
      clientId: json['client_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown application',
      scopes: json['scopes']?.toString() ?? json['scope']?.toString() ?? '',
    );
  }
}

class OAuthAuthorizeResult {
  final String? redirectUri;
  final String? code;
  final String? errorDetail;

  const OAuthAuthorizeResult({this.redirectUri, this.code, this.errorDetail});

  bool get isSuccess =>
      errorDetail == null && (code != null || redirectUri != null);
}

// ── Provider ────────────────────────────────────────────────────────────

final oauthAuthorizeServiceProvider = Provider<OAuthAuthorizeService>((ref) {
  return OAuthAuthorizeService(ref.watch(dioProvider), ref);
});

// ── Service ─────────────────────────────────────────────────────────────

/// Client for third-party OAuth authorize flows against Funkwhale's
/// `/api/v1/oauth/*` endpoints (not first-party Tayra login).
class OAuthAuthorizeService {
  final Dio _dio;
  final Ref _ref;

  OAuthAuthorizeService(this._dio, this._ref);

  String get _baseUrl {
    final serverUrl = _ref.read(authStateProvider).serverUrl ?? '';
    if (serverUrl.isEmpty) return '';
    return serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
  }

  /// Prefer same-origin relative paths on web so a mismatched baked
  /// FUNKWHALE_URL still hits the nginx that serves this SPA.
  String _url(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    if (kIsWeb) return p;
    final base = _baseUrl;
    if (base.isEmpty) return p;
    return '$base$p';
  }

  /// `GET /api/v1/oauth/apps/{client_id}/` — public retrieve of app metadata.
  Future<OAuthApplicationInfo> fetchApplication(String clientId) async {
    final response = await _dio.get(
      _url('/api/v1/oauth/apps/${Uri.encodeComponent(clientId)}/'),
      options: Options(
        validateStatus: (s) => s != null && s < 500,
        responseType: ResponseType.json,
      ),
    );
    if (response.statusCode != 200 || response.data is! Map) {
      throw OAuthAuthorizeException(
        _detailFromBody(response.data) ??
            'Could not load application (HTTP ${response.statusCode}).',
      );
    }
    return OAuthApplicationInfo.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// `POST /api/v1/oauth/authorize` with AJAX headers so the server returns
  /// JSON `{redirect_uri, code}` instead of a 302.
  Future<OAuthAuthorizeResult> authorize({
    required bool allow,
    required String clientId,
    required String redirectUri,
    required String responseType,
    required String scope,
    String? state,
  }) async {
    final form = <String, dynamic>{
      'allow': allow ? 'true' : 'false',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': responseType,
      'scope': scope,
      if (state != null && state.isNotEmpty) 'state': state,
    };

    try {
      final response = await _dio.post(
        _url('/api/v1/oauth/authorize/'),
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/json',
          },
          validateStatus: (s) => s != null && s < 500,
          // Do not follow redirects if the server forgets AJAX handling.
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final map = Map<String, dynamic>.from(response.data as Map);
        return OAuthAuthorizeResult(
          redirectUri: map['redirect_uri']?.toString(),
          code: map['code']?.toString(),
        );
      }

      // Some stacks return 302 even for AJAX; pull code from Location.
      if (response.statusCode == 302) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          final uri = Uri.tryParse(location);
          final code = uri?.queryParameters['code'];
          return OAuthAuthorizeResult(redirectUri: location, code: code);
        }
      }

      return OAuthAuthorizeResult(
        errorDetail:
            _detailFromBody(response.data) ??
            'Authorization failed (HTTP ${response.statusCode}).',
      );
    } on DioException catch (e) {
      return OAuthAuthorizeResult(
        errorDetail:
            _detailFromBody(e.response?.data) ??
            'Could not reach the authorization server.',
      );
    }
  }

  static String? _detailFromBody(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final detail = map['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    final nonField = map['non_field_errors'];
    if (nonField is List && nonField.isNotEmpty) {
      return nonField.first.toString();
    }
    // Field errors: {redirect_uri: ["..."]}
    for (final entry in map.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty) {
        return '${entry.key}: ${v.first}';
      }
      if (v is String && v.isNotEmpty && entry.key != 'code') {
        return v;
      }
    }
    return null;
  }
}

class OAuthAuthorizeException implements Exception {
  final String message;
  OAuthAuthorizeException(this.message);

  @override
  String toString() => message;
}
