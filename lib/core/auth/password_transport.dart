import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Domain-separated SHA-256 transport hash for first-party password login.
///
/// Must stay in sync with
/// `api/funkwhale_api/users/password_transport.py` on the server.
/// The real account password is never put on the wire for
/// `POST /api/v1/users/token/`.
const _domainPrefix = 'tayra-login-v1\x00';

/// Returns the lowercase hex digest the API expects in the `password` field.
String hashPasswordForTransport(String password) {
  final bytes = utf8.encode('$_domainPrefix$password');
  return sha256.convert(bytes).toString();
}
