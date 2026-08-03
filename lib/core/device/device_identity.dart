import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/platform/app_platform.dart';

// ── Device / server naming ───────────────────────────────────────────────

/// Returns a human-readable device name suitable for display (e.g.
/// "Samsung SM-S908U" or "loren-desktop"). Stored with listen history and
/// client-device registration so other devices can render it verbatim.
Future<String> getDeviceDisplayName() async {
  try {
    if (AppPlatform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = _titleCaseWord(info.manufacturer);
      final model = info.model.trim();
      return model.isEmpty ? manufacturer : '$manufacturer $model';
    }
    final host = await AppPlatform.deviceLabel();
    return host.isEmpty ? 'This Device' : host;
  } catch (_) {
    return 'This Device';
  }
}

String _titleCaseWord(String w) {
  if (w.isEmpty) return w;
  return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
}

// ── Per-device UUID ──────────────────────────────────────────────────────
//
// Each install generates a random UUID v4, persisted in SharedPreferences
// (NOT the cache DB, so it survives "clear cache" — only logout / app-data
// wipe resets it). Used for client-device registration and to tag remote
// listen records.

const _deviceUuidKey = 'tayra_device_uuid';

final _uuidV4Regex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Returns this device's stable UUID v4, generating and persisting it on
/// first use.
Future<String> getDeviceUuid() async {
  final prefs = await SharedPreferences.getInstance();
  var uuid = prefs.getString(_deviceUuidKey);
  if (uuid == null || !_uuidV4Regex.hasMatch(uuid)) {
    uuid = generateUuidV4();
    await prefs.setString(_deviceUuidKey, uuid);
  }
  return uuid;
}

/// Cryptographically secure UUID v4 (lowercase hex). Shared by device
/// identity and rich listening `client_session_id` generation.
String generateUuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
}
