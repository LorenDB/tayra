// Desktop-only loopback redirect server so web conditional imports resolve.
// Call sites are guarded with AppPlatform.isDesktop; the class name and API
// mirror LoopbackRedirectServer so web builds compile against this stub.

class LoopbackRedirectServer {
  const LoopbackRedirectServer();

  Future<String?> start() async => null;

  Future<Uri> wait({Duration timeout = const Duration(minutes: 10)}) {
    throw UnsupportedError('Loopback redirects are desktop-only');
  }

  Future<void> close() async {}
}
