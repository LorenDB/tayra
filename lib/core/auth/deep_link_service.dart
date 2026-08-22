import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart';

/// Dispatches inbound `tayra://` deep links to SSO completion.
///
/// Android declares the intent filter (see AndroidManifest.xml) and the pod's
/// OIDC login endpoint allowlists the scheme, so a native sign-in can finish
/// with `tayra://sso/callback?code=…&state=…` instead of a pasted code.
///
/// Web never starts this service; desktop uses loopback redirects instead.
class DeepLinkService {
  DeepLinkService(this._auth);

  final AuthNotifier _auth;
  StreamSubscription<Uri>? _sub;

  /// Whether the service is active (never true on web).
  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      final links = AppLinks();
      // Cold start: app launched directly by the callback link.
      unawaited(_handle(links.getInitialLink()));
      // Warm start: link arrives while the app is running.
      _sub = links.uriLinkStream.listen(
        _onLink,
        onError: (Object e) {
          assert(() {
            debugPrint('DeepLinkService stream error: $e');
            return true;
          }());
        },
      );
    } catch (e) {
      assert(() {
        debugPrint('DeepLinkService init failed: $e');
        return true;
      }());
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _onLink(Uri uri) {
    unawaited(_handle(Future.value(uri)));
  }

  Future<void> _handle(Future<Uri?> uriFuture) async {
    final Uri? link;
    try {
      link = await uriFuture;
    } catch (_) {
      return;
    }
    if (link == null || link.scheme != 'tayra') return;

    final host = link.host.toLowerCase();
    if (host == 'sso') {
      await _completeSso(link);
    }
  }

  Future<void> _completeSso(Uri uri) async {
    final error = uri.queryParameters['error'];
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (error != null && error.isNotEmpty) {
      Analytics.track('login_sso_failed');
      return;
    }
    if (code == null || code.isEmpty) return;

    // Server URL / tx binding are restored from the values persisted at SSO
    // start, so this works even after Android killed the backgrounded app.
    await _auth.completeOidcLogin(
      code: code,
      clientState: state,
      allowRestore: true,
    );
  }
}
