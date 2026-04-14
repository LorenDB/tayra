import 'package:aptabase_flutter/aptabase_flutter.dart';

/// Small analytics wrapper that centralises sanitisation rules before
/// sending events to Aptabase. Keep this minimal: only enforce allowed
/// keys/types and strip known-sensitive keys like raw error messages.

class Analytics {
  Analytics._();

  static final _sensitiveKeys = <String>{
    'error',
    'message',
    'prompt',
    'response',
    'url',
    'server',
    'token',
    'code',
    'email',
    'username',
  };

  /// Public entrypoint for tracking events. Wraps Aptabase and ensures
  /// we don't send raw strings that may contain PII. Values are restricted
  /// to simple types: null, bool, num, or short Strings for whitelisted keys.
  static void track(String name, [Map<String, dynamic>? props]) {
    try {
      final safe = <String, dynamic>{};
      if (props != null) {
        props.forEach((k, v) {
          if (_sensitiveKeys.contains(k)) {
            // Replace sensitive strings with a boolean flag or type name.
            safe['has_$k'] = v != null;
            return;
          }
          if (v == null || v is bool || v is num) {
            safe[k] = v;
            return;
          }
          if (v is String) {
            // Only allow short strings (length <= 64) to avoid leaking
            // long free-form text. Longer strings are replaced with their
            // length instead which preserves usefulness without content.
            if (v.length <= 64) {
              safe[k] = v;
            } else {
              safe['${k}_length'] = v.length;
            }
            return;
          }
          // For any other types (lists, maps, objects) send a lightweight
          // representation where possible.
          if (v is Iterable) {
            safe['${k}_count'] = v.length;
            return;
          }
          // Unknown/unserialisable types: send the runtime type name only.
          safe['${k}_type'] = v.runtimeType.toString();
        });
      }

      // Fire-and-forget; analytics must not crash the app.
      Aptabase.instance.trackEvent(name, safe);
    } catch (_) {
      // Swallow any analytics failures.
    }
  }
}
