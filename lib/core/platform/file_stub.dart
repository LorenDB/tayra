/// Minimal [File] stand-in for web conditional imports.
///
/// Call sites that resolve local cover art are skipped when
/// [AppPlatform.supportsOfflineCache] is false.
class File {
  File(this.path);
  final String path;

  Future<bool> exists() async => false;

  Uri get uri => Uri.parse(path);
}
