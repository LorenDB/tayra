import 'dart:async';
import 'dart:convert';
import 'dart:io' show ContentType, HttpServer, InternetAddress;

/// RFC 8252 §7.3 loopback redirect receiver for desktop SSO.
///
/// Binds an ephemeral port on 127.0.0.1 and answers exactly one request: the
/// pod's browser redirect carrying `?code=` (or `?error=`). Any other local
/// process could hit the port too — the one-time exchange code alone is not
/// usable without the client's tx binding, and a hostile local page can only
/// burn the code, never steal tokens. The server-side allowlist accepts any
/// loopback port for this reason.
class LoopbackRedirectServer {
  HttpServer? _server;
  final _completer = Completer<Uri>();
  bool _answered = false;
  bool _waiting = false;

  /// Bound callback URL (`http://127.0.0.1:<port>/sso/callback`), or null on
  /// bind failure (firewall, missing loopback support, …).
  Future<String?> start() async {
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        v6Only: false,
      );
      unawaited(_serve());
      return 'http://127.0.0.1:${_server!.port}/sso/callback';
    } catch (_) {
      return null;
    }
  }

  /// Resolves with the first request URL (query included) or times out.
  Future<Uri> wait({Duration timeout = const Duration(minutes: 10)}) {
    _waiting = true;
    return _completer.future.timeout(timeout);
  }

  Future<void> _serve() async {
    final server = _server;
    if (server == null) return;
    try {
      await for (final req in server) {
        if (!_answered) {
          _answered = true;
          _completer.complete(req.uri);
          req.response.statusCode = 200;
        } else {
          // Late duplicate tabs / prefetches after completion.
          req.response.statusCode = 410;
        }
        req.response.headers.contentType = ContentType.html;
        req.response.write(_page);
        await req.response.close();
        if (_answered) {
          await close();
          break;
        }
      }
    } catch (_) {}
  }

  static const _page =
      '<!DOCTYPE html><html><head><meta charset="utf-8"/>'
      '<meta name="viewport" content="width=device-width, initial-scale=1"/>'
      '<title>Tayra</title></head>'
      '<body style="font-family:system-ui,sans-serif;background:#000;'
      'color:#eee;max-width:32rem;margin:3rem auto;padding:0 1rem;">'
      '<h1>Signing you in…</h1>'
      '<p>You can close this tab and return to Tayra.</p>'
      '</body></html>';

  Future<void> close() async {
    final server = _server;
    _server = null;
    if (_waiting && !_completer.isCompleted) {
      _completer.completeError(StateError('closed'));
    }
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  /// Convenience for tests: parse `code` / `error` / `state` out of a
  /// callback URI.
  static Map<String, String> params(Uri uri) {
    const keys = ['code', 'error', 'state'];
    return {
      for (final k in keys)
        if ((uri.queryParameters[k] ?? '').isNotEmpty)
          k: uri.queryParameters[k]!,
    };
  }

  /// JSON-encode [value] so it can be embedded in generated HTML/JS above.
  static String jsonEscape(String value) => jsonEncode(value);
}
