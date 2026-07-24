// Stubs for desktop-only plugins so web conditional imports resolve.
// Call sites are guarded with AppPlatform.isDesktop / isLinux.

void sqfliteFfiInit() {}

// sqflite globals; unused on web (call sites are desktop-only).
// ignore: non_constant_identifier_names
dynamic databaseFactory;

// ignore: non_constant_identifier_names
dynamic databaseFactoryFfi;

class JustAudioMediaKit {
  static void ensureInitialized() {}
}

class AudioServiceMpris {
  static void registerWith() {}
}

// window_size API — accept Flutter geometry types without depending on them.
void setWindowMinSize(Object size) {}

void setWindowFrame(Object frame) {}

class FakeWindowFrame {
  double get left => 0;
  double get top => 0;
  double get width => 0;
  double get height => 0;
}

class FakeWindowInfo {
  FakeWindowFrame get frame => FakeWindowFrame();
}

Future<FakeWindowInfo> getWindowInfo() async => FakeWindowInfo();
