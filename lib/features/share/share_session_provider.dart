import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the active secret share-link token for visitor playback.
class ShareSessionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? token) => state = token;

  void clear() => state = null;
}

/// Active secret share-link token for visitor playback.
///
/// When non-null, stream URLs append `?share=` and server-side queue /
/// authenticated stream features should be skipped.
final shareSessionTokenProvider =
    NotifierProvider<ShareSessionNotifier, String?>(ShareSessionNotifier.new);
