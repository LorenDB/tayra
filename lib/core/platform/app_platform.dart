import 'package:flutter/foundation.dart';

import 'package:tayra/core/platform/app_platform_io.dart'
    if (dart.library.html) 'package:tayra/core/platform/app_platform_web.dart'
    as impl;

/// Cross-platform helpers that compile on web and native.
///
/// Prefer this over raw `dart:io` [Platform] so web builds stay clean and
/// runtime paths do not touch unsupported APIs.
abstract final class AppPlatform {
  static bool get isWeb => kIsWeb;

  static bool get isAndroid => !kIsWeb && impl.isAndroid;
  static bool get isIOS => !kIsWeb && impl.isIOS;
  static bool get isLinux => !kIsWeb && impl.isLinux;
  static bool get isMacOS => !kIsWeb && impl.isMacOS;
  static bool get isWindows => !kIsWeb && impl.isWindows;

  static bool get isDesktop => isLinux || isMacOS || isWindows;
  static bool get isMobile => isAndroid || isIOS;

  /// Web builds are online-only: no local audio cache / download queue.
  static bool get supportsOfflineCache => !kIsWeb;

  /// Prefer platform secure storage for secrets (OAuth tokens, API keys).
  ///
  /// Enabled on all **native** platforms (Android Keystore, iOS/macOS Keychain,
  /// Linux libsecret, Windows Credential Manager / DPAPI). Web has no
  /// equivalent that survives XSS, so it still uses SharedPreferences
  /// (localStorage); keep the SPA CSP tight and treat web tokens as
  /// browser-compromisable.
  static bool get useSecureStorage => !isWeb;

  /// Compile-time pod URL for branded web builds.
  ///
  /// Pass at build time:
  /// `flutter build web --dart-define=FUNKWHALE_URL=https://music.example.com`
  static const String funkwhaleUrl = String.fromEnvironment(
    'FUNKWHALE_URL',
    defaultValue: '',
  );

  /// True when web should skip the multi-server URL field.
  static bool get hasHardcodedPodUrl =>
      kIsWeb && funkwhaleUrl.trim().isNotEmpty;

  static String? get hardcodedPodUrl {
    final url = funkwhaleUrl.trim();
    if (url.isEmpty) return null;
    var normalized = url;
    if (!normalized.startsWith('http')) normalized = 'https://$normalized';
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// Device / host name for OAuth app registration labels.
  static Future<String> deviceLabel() => impl.deviceLabel();

  /// Optional DO_NOT_TRACK env (native only).
  static String? get doNotTrackEnv => impl.doNotTrackEnv;

  /// Exit the process (native). No-op on web.
  static void tryExitProcess() => impl.tryExitProcess();
}
