import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/features/auth/oauth_scopes.dart';

void main() {
  group('expandOAuthScopes', () {
    test('defaults when empty', () {
      final scopes = expandOAuthScopes(null);
      expect(scopes, isNotEmpty);
      expect(scopes.first.id, 'read');
    });

    test('splits and de-duplicates', () {
      final scopes = expandOAuthScopes('read write read');
      expect(scopes.map((s) => s.id).toList(), ['read', 'write']);
    });

    test('uses known labels', () {
      final scopes = expandOAuthScopes('read:favorites');
      expect(scopes.single.label, contains('favorites'));
    });
  });

  group('isOobRedirectUri', () {
    test('detects oob urns', () {
      expect(isOobRedirectUri('urn:ietf:wg:oauth:2.0:oob'), isTrue);
      expect(isOobRedirectUri('urn:ietf:wg:oauth:2.0:oob:auto'), isTrue);
      expect(isOobRedirectUri('https://app.example/callback'), isFalse);
      expect(isOobRedirectUri(null), isFalse);
    });
  });
}
