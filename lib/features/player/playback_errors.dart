import 'package:just_audio/just_audio.dart';

/// True when [error] is a browser / just_audio interruption, not a hard
/// decode or network failure.
///
/// Chrome rejects `HTMLMediaElement.play()` with `AbortError` when the
/// element is paused, reloaded, or detached mid-promise — including the
/// "media was removed from the document" variant. just_audio surfaces
/// overlapping loads as [PlayerInterruptedException]. These are expected
/// when replacing the current source on web and must not be treated as
/// "unable to load this track".
bool isPlayInterruptedError(Object error) {
  if (error is PlayerInterruptedException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('aborterror') ||
      msg.contains('interrupted') ||
      msg.contains('removed from the document');
}
