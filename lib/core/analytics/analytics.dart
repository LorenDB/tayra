import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Preference key used to persist the user's analytics choice.
const _prefsKeyAnalyticsEnabled = 'analytics_enabled';

/// Small analytics wrapper that centralises sanitisation rules before
/// sending events to Aptabase. Keep this minimal: only enforce allowed
/// keys/types and strip known-sensitive keys like raw error messages.

class Analytics {
  Analytics._();

  static bool _enabled = true;
  static bool get enabled => _enabled;

  // Track whether we've initialised Aptabase to avoid re-initialising.
  static bool _aptabaseInitialised = false;

  /// Load persisted analytics preference from shared preferences.
  static Future<void> loadEnabledFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKeyAnalyticsEnabled) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  /// Persist and apply an enabled/disabled value. When enabling, this will
  /// initialise Aptabase if not already initialised.
  static Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAnalyticsEnabled, enabled);
    } catch (_) {}
    _enabled = enabled;

    if (_enabled) {
      await initializeIfEnabled();
    }
  }

  /// Initialise Aptabase if analytics are enabled and we haven't initialised
  /// it yet. This centralises the init parameters so callers don't need to
  /// duplicate them.
  static Future<void> initializeIfEnabled() async {
    if (!_enabled || _aptabaseInitialised) return;
    try {
      // Keep the same key/host used elsewhere in the app.
      await Aptabase.init(
        "A-SH-1447414969",
        InitOptions(host: "https://aptabase.lorendb.dev"),
      );
      _aptabaseInitialised = true;
    } catch (_) {
      // Swallow init failures; analytics must not crash the app.
    }
  }

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
    if (!_enabled) return;
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
      // If Aptabase wasn't initialised earlier (e.g. user enabled analytics at
      // runtime but init hasn't completed), attempt to initialise quickly.
      if (!_aptabaseInitialised) {
        // don't await - best-effort init
        initializeIfEnabled();
      }
      Aptabase.instance.trackEvent(name, safe);
    } catch (_) {
      // Swallow any analytics failures.
    }
  }
}
