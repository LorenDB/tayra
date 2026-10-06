import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/auth/password_transport.dart';

void main() {
  _offThreadTests();

  test('clampTransportIterations accepts normal values and rejects extremes', () {
    expect(clampTransportIterations(null), transportIterations);
    expect(clampTransportIterations(0), transportIterations);
    expect(clampTransportIterations(210000), 210000);
    expect(clampTransportIterations(maxTransportIterations), maxTransportIterations);
    expect(
      () => clampTransportIterations(maxTransportIterations + 1),
      throwsArgumentError,
    );
  });

  test('computeLegacyClientProof is stable and challenge-bound', () {
    final digest = legacyTransportDigest('s3cret-pass');
    final a = computeLegacyClientProof(
      digestHex: digest,
      username: 'legacy',
      clientNonce: 'cn',
      serverNonce: 'sn',
      challengeId: 'ch1',
    );
    final b = computeLegacyClientProof(
      digestHex: digest,
      username: 'legacy',
      clientNonce: 'cn',
      serverNonce: 'sn',
      challengeId: 'ch1',
    );
    expect(a, b);
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      computeLegacyClientProof(
        digestHex: digest,
        username: 'legacy',
        clientNonce: 'cn',
        serverNonce: 'sn',
        challengeId: 'ch2',
      ),
      isNot(a),
    );
  });

  test('legacyTransportDigest is stable hex and domain-separated', () {
    final a = legacyTransportDigest('s3cret-pass');
    final b = legacyTransportDigest('s3cret-pass');
    expect(a, b);
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(legacyTransportDigest('other'), isNot(a));
    final bare = sha256.convert(utf8.encode('s3cret-pass')).toString();
    expect(a, isNot(bare));
  });

  test('legacyTransportDigest matches Python v1 reference vector', () {
    final expected =
        sha256.convert(utf8.encode('tayra-login-v1\x00s3cret-pass')).toString();
    expect(legacyTransportDigest('s3cret-pass'), expected);
  });

  test('instanceBindingForServerUrl is stable 16 bytes', () {
    final a = instanceBindingForServerUrl('https://music.example.org');
    final b = instanceBindingForServerUrl('https://music.example.org/');
    expect(a, b);
    expect(a.length, 16);
    expect(
      instanceBindingForServerUrl('https://other.example.org'),
      isNot(a),
    );
  });

  test('transportSecret is 32 bytes and password-dependent', () {
    final binding = instanceBindingForServerUrl('http://funkwhale.dev');
    final a = transportSecret('s3cret-pass', binding);
    final b = transportSecret('s3cret-pass', binding);
    expect(a, b);
    expect(a.length, 32);
    expect(transportSecret('other', binding), isNot(a));
  });

  test('hashPasswordForTransport uses serverUrl binding', () {
    final hex = hashPasswordForTransport(
      's3cret-pass',
      serverUrl: 'http://funkwhale.dev',
    );
    expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    final binding = instanceBindingForServerUrl('http://funkwhale.dev');
    final expected = transportSecret('s3cret-pass', binding)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(hex, expected);
  });

  test('computeClientProof is deterministic for fixed inputs', () {
    final secret = List<int>.generate(32, (i) => i);
    final salt = List<int>.generate(16, (i) => 100 + i);
    final a = computeClientProof(
      secret: secret,
      salt: salt,
      iterations: 1000, // low for unit-test speed
      username: 'alice',
      clientNonce: 'cn',
      serverNonce: 'sn',
    );
    final b = computeClientProof(
      secret: secret,
      salt: salt,
      iterations: 1000,
      username: 'alice',
      clientNonce: 'cn',
      serverNonce: 'sn',
    );
    expect(a, b);
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      computeClientProof(
        secret: secret,
        salt: salt,
        iterations: 1000,
        username: 'alice',
        clientNonce: 'cn',
        serverNonce: 'other',
      ),
      isNot(a),
    );
  });

  test('newClientNonce and newOidcTxBinding are non-empty', () {
    expect(newClientNonce().length, greaterThan(10));
    expect(newOidcTxBinding().length, greaterThan(10));
    expect(newClientNonce(), isNot(newClientNonce()));
  });

  test('PKCE S256 challenge is stable and non-empty', () {
    final verifier = newPkceCodeVerifier();
    expect(verifier.length, greaterThan(20));
    final challenge = pkceCodeChallengeS256(verifier);
    expect(challenge.length, greaterThan(20));
    expect(pkceCodeChallengeS256(verifier), challenge);
    expect(pkceCodeChallengeS256(newPkceCodeVerifier()), isNot(challenge));
  });
}

// ── Off-UI-thread derivation ────────────────────────────────────────────

ClientProofRequest _proofRequest({int transportIters = 300, int iters = 500}) {
  return ClientProofRequest(
    password: 'correct horse battery staple',
    instanceBinding: instanceBindingForServerUrl('https://pod.example'),
    transportIterations: transportIters,
    salt: List<int>.generate(16, (i) => i * 7 + 1),
    iterations: iters,
    username: 'alice',
    clientNonce: 'client-nonce',
    serverNonce: 'server-nonce',
  );
}

String _referenceProof(ClientProofRequest r) {
  return computeClientProof(
    secret: transportSecret(
      r.password,
      r.instanceBinding,
      iterations: r.transportIterations,
    ),
    salt: r.salt,
    iterations: r.iterations,
    username: r.username,
    clientNonce: r.clientNonce,
    serverNonce: r.serverNonce,
  );
}

void _offThreadTests() {
  test('yielding PBKDF2 matches the reference at chunk boundaries', () async {
    final password = utf8.encode('pw');
    final salt = utf8.encode('salt');
    // Below, exactly at, and just past a yield point, plus a second block.
    for (final iterations in [1, 2, 7, 8, 9, 64]) {
      for (final length in [32, 48]) {
        final expected = pbkdf2HmacSha256(
          password: password,
          salt: salt,
          iterations: iterations,
          length: length,
        );
        final actual = await pbkdf2HmacSha256Yielding(
          password: password,
          salt: salt,
          iterations: iterations,
          length: length,
          yieldEvery: 8,
        );
        expect(actual, expected, reason: 'iterations=$iterations len=$length');
      }
    }
  });

  test('background and yielding proofs equal the synchronous one', () async {
    final request = _proofRequest();
    final expected = _referenceProof(request);

    expect(await deriveClientProofYielding(request), expected);
    expect(await deriveClientProof(request), expected);
  });

  test('proof depends on both iteration counts', () async {
    final base = await deriveClientProofYielding(_proofRequest());
    expect(
      await deriveClientProofYielding(_proofRequest(transportIters: 301)),
      isNot(base),
    );
    expect(
      await deriveClientProofYielding(_proofRequest(iters: 501)),
      isNot(base),
    );
  });
}
