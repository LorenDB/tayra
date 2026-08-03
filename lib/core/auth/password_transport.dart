import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Client-side password transport for first-party login (H2).
///
/// Must stay in sync with
/// `api/funkwhale_api/users/password_transport.py` on the server.
///
/// Login uses a SCRAM-like per-request proof over an instance-bound PBKDF2
/// secret so a static digest is never a reusable password-equivalent.
/// Password-confirmation endpoints still send the hex transport secret
/// (not the account password).

// Domain separation for the instance-bound transport secret (v2).
const _domainV2 = 'tayra-login-v2\x00';

// Legacy v1 static digest (migration / legacy_v1 challenge scheme only).
const _domainV1 = 'tayra-login-v1\x00';

const transportIterations = 210000;
const _keyLen = 32;

/// Upper bound for server-advertised PBKDF2 iteration counts.
///
/// Prevents a hostile/misconfigured pod (or MITM rewriting the challenge JSON)
/// from freezing the UI with multi-million-iteration PBKDF2. Production uses
/// 210_000; allow a modest headroom for future raises.
const maxTransportIterations = 1_000_000;

const _clientKeyLabel = 'Client Key';

/// Clamp a server-supplied iteration count into a safe range.
///
/// Values below 1 fall back to [transportIterations]. Values above
/// [maxTransportIterations] are rejected with [ArgumentError] so login fails
/// closed rather than running unbounded work.
int clampTransportIterations(int? value) {
  if (value == null || value < 1) return transportIterations;
  if (value > maxTransportIterations) {
    throw ArgumentError(
      'PBKDF2 iteration count $value exceeds safe maximum '
      '($maxTransportIterations)',
    );
  }
  return value;
}

// ── PBKDF2-HMAC-SHA256 ──────────────────────────────────────────────────

/// PBKDF2-HMAC-SHA256 (RFC 8018).
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int length = _keyLen,
}) {
  final hmac = Hmac(sha256, password);
  final blockCount = (length + 31) ~/ 32;
  final out = BytesBuilder(copy: false);

  for (var block = 1; block <= blockCount; block++) {
    final blockSalt = BytesBuilder(copy: false)
      ..add(salt)
      ..add([
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ]);
    var u = hmac.convert(blockSalt.toBytes()).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.add(t);
  }
  return Uint8List.fromList(out.toBytes().sublist(0, length));
}

// ── Transport secret ────────────────────────────────────────────────────

/// Instance binding bytes from the hex advertised by the login challenge.
Uint8List instanceBindingFromHex(String hex) {
  final cleaned = hex.trim().toLowerCase();
  if (cleaned.length != 32 || !RegExp(r'^[0-9a-f]+$').hasMatch(cleaned)) {
    throw ArgumentError('Invalid instance_binding');
  }
  final out = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    out[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Same derivation as server ``get_instance_binding()`` from FUNKWHALE_URL.
Uint8List instanceBindingForServerUrl(String serverUrl) {
  final url = serverUrl.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
  final digest = sha256.convert(utf8.encode('tayra-instance\x00$url'));
  return Uint8List.fromList(digest.bytes.sublist(0, 16));
}

/// Instance-bound PBKDF2 secret derived from the account password.
Uint8List transportSecret(
  String password,
  List<int> instanceBinding, {
  int iterations = transportIterations,
}) {
  final salt = <int>[
    ...utf8.encode(_domainV2),
    ...instanceBinding,
  ];
  return pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: salt,
    iterations: iterations,
    length: _keyLen,
  );
}

/// Hex form of [transportSecret] for password-confirmation API bodies.
///
/// Prefer [serverUrl] (the connected pod URL) so the binding matches the
/// server's ``FUNKWHALE_URL``. [instanceBindingHex] from a login challenge
/// may be passed instead when available.
String hashPasswordForTransport(
  String password, {
  String? serverUrl,
  String? instanceBindingHex,
  int iterations = transportIterations,
}) {
  final Uint8List binding;
  if (instanceBindingHex != null && instanceBindingHex.isNotEmpty) {
    binding = instanceBindingFromHex(instanceBindingHex);
  } else if (serverUrl != null && serverUrl.trim().isNotEmpty) {
    binding = instanceBindingForServerUrl(serverUrl);
  } else {
    // Last resort: zero binding (will only work if the server URL is empty
    // too — callers should always pass serverUrl).
    binding = Uint8List(16);
  }
  return _toHex(
    transportSecret(password, binding, iterations: iterations),
  );
}

/// Legacy v1 static digest (only for legacy_v1 login challenges).
String legacyTransportDigest(String password) {
  final bytes = utf8.encode('$_domainV1$password');
  return sha256.convert(bytes).toString();
}

// ── SCRAM-like client proof ─────────────────────────────────────────────

/// URL-safe base64 without padding (matches Python helper).
Uint8List b64UrlDecode(String data) {
  var s = data.replaceAll('-', '+').replaceAll('_', '/');
  switch (s.length % 4) {
    case 2:
      s += '==';
      break;
    case 3:
      s += '=';
      break;
  }
  return Uint8List.fromList(base64.decode(s));
}

String _toHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

List<int> _hmacSha256(List<int> key, List<int> message) {
  return Hmac(sha256, key).convert(message).bytes;
}

/// Build the SCRAM-like client_proof hex for token login.
String computeClientProof({
  required List<int> secret,
  required List<int> salt,
  required int iterations,
  required String username,
  required String clientNonce,
  required String serverNonce,
}) {
  final salted = pbkdf2HmacSha256(
    password: secret,
    salt: salt,
    iterations: iterations,
    length: _keyLen,
  );
  final clientKey = _hmacSha256(salted, utf8.encode(_clientKeyLabel));
  final storedKey = sha256.convert(clientKey).bytes;
  final authMsg = utf8.encode(
    'n=$username,r=$clientNonce,s=$serverNonce',
  );
  final clientSignature = _hmacSha256(storedKey, authMsg);
  final clientProof = List<int>.generate(
    clientKey.length,
    (i) => clientKey[i] ^ clientSignature[i],
  );
  return _toHex(clientProof);
}

/// Cryptographically random client nonce for SCRAM login.
String newClientNonce({int bytes = 24}) {
  final rnd = Random.secure();
  final buf = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64Url.encode(buf).replaceAll('=', '');
}

/// Cryptographically random SSO transaction binding for native OIDC.
String newOidcTxBinding({int bytes = 32}) {
  final rnd = Random.secure();
  final buf = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64Url.encode(buf).replaceAll('=', '');
}

/// OAuth/OIDC `state` parameter (login CSRF protection — M3).
String newOidcClientState({int bytes = 32}) => newOidcTxBinding(bytes: bytes);

// ── PKCE (RFC 7636) ─────────────────────────────────────────────────────

/// High-entropy `code_verifier` for OAuth PKCE (M2).
String newPkceCodeVerifier({int bytes = 32}) {
  final rnd = Random.secure();
  final buf = List<int>.generate(bytes, (_) => rnd.nextInt(256));
  return base64Url.encode(buf).replaceAll('=', '');
}

/// S256 `code_challenge` for [codeVerifier].
String pkceCodeChallengeS256(String codeVerifier) {
  final digest = sha256.convert(utf8.encode(codeVerifier));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
