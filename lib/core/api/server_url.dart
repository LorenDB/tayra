/// Canonical form of a server address typed by the user (or baked into a
/// build): trimmed, with a scheme (https unless one was given) and without
/// trailing slashes.
///
/// The scheme test looks for `http://` / `https://` rather than a bare
/// `http` prefix, so a host such as `httpd.example.org` still gets one.
String normalizeServerUrl(String serverUrl) {
  var url = serverUrl.trim();
  if (url.isEmpty) return url;
  if (!_hasHttpScheme.hasMatch(url)) url = 'https://$url';
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

final _hasHttpScheme = RegExp(r'^https?://', caseSensitive: false);
