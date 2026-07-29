import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/auth/password_transport.dart';

void main() {
  test('hashPasswordForTransport is stable hex digest', () {
    final a = hashPasswordForTransport('s3cret-pass');
    final b = hashPasswordForTransport('s3cret-pass');
    expect(a, b);
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(hashPasswordForTransport('other'), isNot(a));
  });

  test('hash is domain-separated (not bare SHA-256)', () {
    final bare = sha256.convert(utf8.encode('s3cret-pass')).toString();
    expect(hashPasswordForTransport('s3cret-pass'), isNot(bare));
  });

  test('matches Python reference vector', () {
    // hashlib.sha256(b"tayra-login-v1\0" + b"s3cret-pass").hexdigest()
    // Computed independently so client and server stay aligned.
    final expected =
        sha256.convert(utf8.encode('tayra-login-v1\x00s3cret-pass')).toString();
    expect(hashPasswordForTransport('s3cret-pass'), expected);
  });
}
