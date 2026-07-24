import 'dart:io';

/// Native: lightweight TCP connection attempt (no HTTP side-effects).
Future<bool> checkServerReachability(String serverUrl) async {
  try {
    final uri = Uri.parse(serverUrl);
    final host = uri.host;
    if (host.isEmpty) return false;
    final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
