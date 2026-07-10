import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayra/core/analytics/analytics.dart';
import 'package:tayra/core/auth/auth_provider.dart'
    show secureStorageProvider, authStateProvider;
import 'package:tayra/features/year_review/listen_history_service.dart';
import 'package:tayra/features/year_review/listen_history_provider.dart';

// ── Device / server naming ───────────────────────────────────────────────

/// Returns a sanitized device identifier safe for use in filenames.
Future<String> getDeviceIdentifier() async {
  try {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final name = '${info.manufacturer}_${info.model}'.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      return name.toLowerCase();
    } else {
      return Platform.localHostname
          .replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_')
          .toLowerCase();
    }
  } catch (_) {
    return 'device';
  }
}

/// Returns a human-readable device name suitable for display in the
/// year-review screen (e.g. "Samsung SM-S908U" or "loren-desktop").  This
/// is stored alongside the sanitized device id in backups so other devices
/// can render it verbatim instead of guessing from the filename.
Future<String> getDeviceDisplayName() async {
  try {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = _titleCaseWord(info.manufacturer);
      final model = info.model.trim();
      return model.isEmpty ? manufacturer : '$manufacturer $model';
    }
    final host = Platform.localHostname;
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
// wipe resets it).  The UUID replaces the sanitized deviceId in backup
// filenames so two physically-identical devices no longer collide on the
// same backup file, and lets the rectifier reliably recognize this
// device's own backups.

const _deviceUuidKey = 'tayra_device_uuid';

final _uuidV4Regex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Returns this device's stable UUID v4, generating and persisting it on
/// first use.  Used as the unique device identifier in backup filenames and
/// to tag remote-device listen records.
Future<String> getDeviceUuid() async {
  final prefs = await SharedPreferences.getInstance();
  var uuid = prefs.getString(_deviceUuidKey);
  if (uuid == null || !_uuidV4Regex.hasMatch(uuid)) {
    uuid = _generateUuidV4();
    await prefs.setString(_deviceUuidKey, uuid);
  }
  return uuid;
}

String _generateUuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
}

/// Extract hostname from a server URL (funkwhale or nextcloud), sanitized.
String extractSanitizedHostname(String url) {
  try {
    String u = url.trim();
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.parse(u);
    String host = uri.host;
    return host.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_').toLowerCase();
  } catch (_) {
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_').toLowerCase();
  }
}

// ── Nextcloud state ──────────────────────────────────────────────────────

class NextcloudState {
  final String? serverUrl;
  final String? username;
  final String?
  appPassword; // stored only in memory after login; persist separately
  final bool isLoading;
  final bool isConnected;
  final String? error;
  final bool autoBackupEnabled;

  const NextcloudState({
    this.serverUrl,
    this.username,
    this.appPassword,
    this.isLoading = false,
    this.isConnected = false,
    this.error,
    this.autoBackupEnabled = true,
  });

  NextcloudState copyWith({
    String? serverUrl,
    String? username,
    String? appPassword,
    bool? isLoading,
    bool? isConnected,
    Object? error = const _Sentinel(),
    bool? autoBackupEnabled,
    bool clearAuth = false,
  }) {
    if (clearAuth) {
      return NextcloudState(
        isLoading: isLoading ?? this.isLoading,
        autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      );
    }
    return NextcloudState(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      appPassword: appPassword ?? this.appPassword,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      error:
          identical(error, const _Sentinel()) ? this.error : error as String?,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    );
  }
}

class _Sentinel {
  const _Sentinel();
}

// ── Providers ───────────────────────────────────────────────────────────

final nextcloudBackupProvider =
    NotifierProvider<NextcloudBackupNotifier, NextcloudState>(
      NextcloudBackupNotifier.new,
    );

class NextcloudBackupNotifier extends Notifier<NextcloudState> {
  static const _keyNcServer = 'nc_server_url';
  static const _keyNcUser = 'nc_username';
  static const _keyNcAuto = 'nc_auto_backup';
  static const _secureTokenKey = 'nc_app_password';

  static bool get _useSecure => Platform.isAndroid;

  @override
  NextcloudState build() {
    Future.microtask(_load);
    return const NextcloudState();
  }

  FlutterSecureStorage get _secure => ref.read(secureStorageProvider);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString(_keyNcServer);
      final user = prefs.getString(_keyNcUser);
      final auto = prefs.getBool(_keyNcAuto) ?? true;

      String? token;
      if (server != null && user != null) {
        if (_useSecure) {
          token = await _secure.read(key: _secureTokenKey);
        } else {
          token = prefs.getString(_secureTokenKey);
        }
      }

      if (server != null && user != null && token != null && token.isNotEmpty) {
        state = NextcloudState(
          serverUrl: server,
          username: user,
          appPassword: token,
          isConnected: true,
          autoBackupEnabled: auto,
        );
      } else {
        state = NextcloudState(autoBackupEnabled: auto);
      }
    } catch (e) {
      state = const NextcloudState(error: 'Failed to load Nextcloud settings');
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    state = state.copyWith(autoBackupEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNcAuto, enabled);
    Analytics.track('nextcloud_auto_backup_toggled', {'enabled': enabled});
  }

  /// Initiate Nextcloud Login Flow v2. Returns the login URL for browser.
  Future<String?> startLoginFlow(String ncServer) async {
    state = state.copyWith(isLoading: true, error: null, clearAuth: true);
    Analytics.track('nextcloud_connect_started');
    String url = ncServer.trim();
    if (!url.startsWith('http')) url = 'https://$url';
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    try {
      final dio = Dio();
      final resp = await dio.post(
        '$url/index.php/login/v2',
        options: Options(
          validateStatus: (_) => true,
          headers: {'User-Agent': 'Tayra (dev.lorendb.tayra)'},
        ),
      );
      if (resp.statusCode != 200 || resp.data is! Map) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to start login flow.',
        );
        return null;
      }
      final data = resp.data as Map<String, dynamic>;
      final loginUrl = data['login'] as String?;
      final pollData = data['poll'] as Map?;
      if (loginUrl == null || pollData == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid response from server.',
        );
        return null;
      }
      _pendingPollEndpoint = pollData['endpoint'] as String?;
      _pendingPollToken = pollData['token'] as String?;
      if (_pendingPollEndpoint == null || _pendingPollToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid response from server.',
        );
        return null;
      }
      state = state.copyWith(serverUrl: url, isLoading: false);
      return loginUrl;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not connect to Nextcloud.',
      );
      return null;
    }
  }

  // Temporary storage for poll details during login (not serialized).
  String? _pendingPollEndpoint;
  String? _pendingPollToken;

  /// Continues poll... use internally.
  Future<bool> completeLoginFlow({
    required String pollEndpoint,
    required String pollToken,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = Dio();
      for (int i = 0; i < 90; i++) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          final r = await dio.post(
            pollEndpoint,
            data: {'token': pollToken},
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              validateStatus: (_) => true,
            ),
          );
          if (r.statusCode == 200 && r.data is Map) {
            final d = r.data as Map<String, dynamic>;
            final uname = d['loginName'] as String?;
            final pw = d['appPassword'] as String?;
            final server = state.serverUrl;
            if (uname != null && pw != null && server != null) {
              await _persist(server, uname, pw);
              Analytics.track('nextcloud_connected');
              state = NextcloudState(
                serverUrl: server,
                username: uname,
                appPassword: pw,
                isConnected: true,
                autoBackupEnabled: state.autoBackupEnabled,
              );
              return true;
            }
          }
        } catch (_) {}
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Login timed out. Try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to complete login.',
      );
      return false;
    }
  }

  Future<void> _persist(String server, String user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNcServer, server);
    await prefs.setString(_keyNcUser, user);
    if (_useSecure) {
      await _secure.write(key: _secureTokenKey, value: token);
    } else {
      await prefs.setString(_secureTokenKey, token);
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNcServer);
    await prefs.remove(_keyNcUser);
    if (_useSecure) {
      await _secure.delete(key: _secureTokenKey);
    } else {
      await prefs.remove(_secureTokenKey);
    }
    _pendingPollEndpoint = null;
    _pendingPollToken = null;
    Analytics.track('nextcloud_disconnected');
    state = NextcloudState(autoBackupEnabled: state.autoBackupEnabled);
  }

  /// Start login flow for SSO; returns the loginUrl to open in browser.
  /// After opening, UI should call pollForAppPassword() .
  /// Call this repeatedly or once after user has authenticated in the browser during login flow.
  Future<bool> pollForAppPassword() async {
    final endpoint = _pendingPollEndpoint;
    final token = _pendingPollToken;
    if (endpoint == null || token == null) {
      state = state.copyWith(isLoading: false, error: 'No pending login flow.');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = Dio();
      for (int i = 0; i < 90; i++) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          final r = await dio.post(
            endpoint,
            data: {'token': token},
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              validateStatus: (_) => true,
            ),
          );
          if (r.statusCode == 200 && r.data is Map<String, dynamic>) {
            final d = r.data as Map<String, dynamic>;
            final uname = d['loginName'] as String?;
            final pw = d['appPassword'] as String?;
            final srv = state.serverUrl;
            if (uname != null && pw != null && srv != null) {
              await _persist(srv, uname, pw);
              _pendingPollEndpoint = null;
              _pendingPollToken = null;
              Analytics.track('nextcloud_connected');
              state = NextcloudState(
                serverUrl: srv,
                username: uname,
                appPassword: pw,
                isConnected: true,
                autoBackupEnabled: state.autoBackupEnabled,
              );
              return true;
            }
          }
        } catch (_) {}
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Timed out waiting for Nextcloud.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Poll failed.');
      return false;
    }
  }

  /// Trigger a backup if connected and auto is on (or force). Calls service.
  Future<bool> backupNow({bool force = false}) async {
    final cur = state;
    if (!cur.isConnected ||
        cur.serverUrl == null ||
        cur.username == null ||
        cur.appPassword == null)
      return false;
    if (!force && !cur.autoBackupEnabled) return false;
    final authS = ref.read(authStateProvider).serverUrl;
    state = state.copyWith(isLoading: true);
    final trigger = force ? 'manual' : 'auto';
    Analytics.track('nextcloud_backup_requested', {'trigger': trigger});
    try {
      final ok = await NextcloudBackupService.performBackup(
        ncServer: cur.serverUrl!,
        ncUsername: cur.username!,
        ncAppPassword: cur.appPassword!,
        funkServerUrl: authS,
      );
      if (ok) {
        Analytics.track('nextcloud_backup_succeeded');
        // Pull in remote-device history after a successful upload so the
        // year-review always has fresh cross-device data.
        unawaited(syncNow().then((_) {}).catchError((_) {}));
      } else {
        Analytics.track('nextcloud_backup_failed');
      }
      state = state.copyWith(isLoading: false);
      return ok;
    } catch (_) {
      Analytics.track('nextcloud_backup_failed');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// List remote backup files for UI.
  Future<List<String>> listRemoteBackups() async {
    final cur = state;
    if (cur.serverUrl == null ||
        cur.username == null ||
        cur.appPassword == null)
      return [];
    return NextcloudBackupService.listBackupFiles(
      server: cur.serverUrl!,
      username: cur.username!,
      appPassword: cur.appPassword!,
    );
  }

  /// List available settings backup files with parsed metadata for the
  /// currently-connected Funkwhale server.  Each entry contains the raw
  /// filename and a human-readable device label.
  ///
  /// Filenames are keyed by per-device UUID (new format) or, for legacy
  /// pre-UUID backups, the sanitized deviceId.  Because a UUID is not
  /// human-readable, the label is resolved from the cached device-name
  /// map (populated by history sync); if a device isn't cached yet its
  /// settings file is downloaded once to read the `deviceName` field.
  Future<List<({String filename, String deviceLabel})>>
  listSettingsFiles() async {
    final cur = state;
    if (cur.serverUrl == null ||
        cur.username == null ||
        cur.appPassword == null)
      return [];
    final auth = ref.read(authStateProvider);
    final srvH =
        auth.serverUrl != null
            ? extractSanitizedHostname(auth.serverUrl!)
            : null;
    final allFiles = await listRemoteBackups();
    await ListenHistoryService.loadDeviceDisplayNames();
    final result = <({String filename, String deviceLabel})>[];
    for (final f in allFiles) {
      if (!f.startsWith('tayra-settings-')) continue;
      if (srvH != null && !f.contains('-$srvH.')) continue;

      // Parse device id: tayra-settings-{device}-{host}.json
      final deviceId =
          srvH != null
              ? f.substring('tayra-settings-'.length, f.indexOf('-$srvH.'))
              : f.substring('tayra-settings-'.length).replaceAll('.json', '');

      // Resolve the display name.  If the cache already has it (e.g. from
      // history sync or a previous lookup) use it; otherwise fetch the
      // settings file content once to read deviceName/deviceUuid.
      final cached = ListenHistoryService.getCachedDeviceDisplayName(deviceId);
      var label = cached;
      if (label == null) {
        // Not in cache — fetch the settings file to get the real name.
        final content = await NextcloudBackupService.downloadFile(
          server: cur.serverUrl!,
          username: cur.username!,
          appPassword: cur.appPassword!,
          filename: f,
        );
        String? fetched;
        if (content != null) {
          try {
            final data = jsonDecode(content);
            if (data is Map<String, dynamic>) {
              fetched = data['deviceName'] as String?;
              final uuid = data['deviceUuid'] as String?;
              if (fetched != null && fetched.isNotEmpty) {
                final key = (uuid != null && uuid.isNotEmpty) ? uuid : deviceId;
                await ListenHistoryService.setDeviceDisplayName(key, fetched);
              }
            }
          } catch (_) {}
        }
        label =
            fetched ?? ListenHistoryService.resolveDeviceDisplayName(deviceId);
      }
      result.add((filename: f, deviceLabel: label));
    }
    return result;
  }

  /// Restore from backup files: downloads and applies settings or history.
  ///
  /// If [settingsFile] is provided, that specific file is used for settings
  /// restore instead of auto-picking the first match.
  Future<bool> restoreFromFiles({
    bool includeSettings = true,
    bool includeHistory = true,
    String? settingsFile,
    bool reuseDeviceUuid = false,
  }) async {
    final cur = state;
    if (cur.serverUrl == null ||
        cur.username == null ||
        cur.appPassword == null)
      return false;
    state = state.copyWith(isLoading: true);
    Analytics.track('nextcloud_restore_requested', {
      'include_settings': includeSettings,
      'include_history': includeHistory,
      'reuse_device_uuid': reuseDeviceUuid,
    });
    try {
      final files = await listRemoteBackups();
      bool ok = true;
      final auth = ref.read(authStateProvider);
      final srvH =
          auth.serverUrl != null
              ? extractSanitizedHostname(auth.serverUrl!)
              : null;
      String? chosenSettingsFile = settingsFile;
      final histFilesForRestore = <String>[];
      for (final f in files..sort((a, b) => b.compareTo(a))) {
        if (includeSettings &&
            chosenSettingsFile == null &&
            f.startsWith('tayra-settings-') &&
            (srvH == null || f.contains('-$srvH.'))) {
          chosenSettingsFile = f;
        }
        if (includeHistory &&
            f.startsWith('tayra-history-') &&
            (srvH == null || f.contains('-$srvH-'))) {
          histFilesForRestore.add(f);
        }
      }
      if (includeSettings && chosenSettingsFile != null) {
        final content = await NextcloudBackupService.downloadFile(
          server: cur.serverUrl!,
          username: cur.username!,
          appPassword: cur.appPassword!,
          filename: chosenSettingsFile,
        );
        if (content != null) {
          ok =
              await NextcloudBackupService.restoreSettings(
                content,
                reuseDeviceUuid: reuseDeviceUuid,
              ) &&
              ok;
        }
      }
      if (includeHistory) {
        for (final hf in histFilesForRestore) {
          final content = await NextcloudBackupService.downloadFile(
            server: cur.serverUrl!,
            username: cur.username!,
            appPassword: cur.appPassword!,
            filename: hf,
          );
          if (content != null) {
            final rok = await NextcloudBackupService.restoreHistory(content);
            if (!rok) ok = false;
          }
        }
      }
      state = state.copyWith(isLoading: false);
      // Invalidate relevant providers so year review and total picks up restored listens
      try {
        ref.invalidate(availableYearsProvider);
        ref.invalidate(totalListenCountProvider);
      } catch (_) {}
      Analytics.track(
        ok ? 'nextcloud_restore_succeeded' : 'nextcloud_restore_failed',
      );
      return ok;
    } catch (e) {
      Analytics.track('nextcloud_restore_failed');
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  /// Sync remote listening history from Nextcloud into the local DB.
  /// Returns the number of new records inserted (deduped).
  Future<int> syncNow() async {
    final cur = state;
    if (!cur.isConnected ||
        cur.serverUrl == null ||
        cur.username == null ||
        cur.appPassword == null)
      return 0;
    final auth = ref.read(authStateProvider);
    final funkHost = auth.serverUrl ?? '';
    if (funkHost.isEmpty) return 0;
    final count = await NextcloudBackupService.syncRemoteHistory(
      ncServer: cur.serverUrl!,
      ncUser: cur.username!,
      ncAppPassword: cur.appPassword!,
      funkServerHost: funkHost,
    );
    Analytics.track('nextcloud_sync_completed', {'record_count': count});
    return count;
  }
}

// ── Backup service (static ops) ──────────────────────────────────────────

class NextcloudBackupService {
  static final Dio _dio = Dio();

  static Future<String> _buildWebDavUrl(String server, String user) async {
    final s =
        server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    return '$s/remote.php/dav/files/${Uri.encodeComponent(user)}/.tayra/backups';
  }

  /// Upload a file to Nextcloud. Uses basic auth with app password.
  static Future<bool> _uploadFile({
    required String server,
    required String username,
    required String appPassword,
    required String filename,
    required String content,
  }) async {
    try {
      final base = await _buildWebDavUrl(server, username);
      final folderUri = Uri.parse(base);

      // MKCOL the parent folder first (.tayra), then the backups folder.
      // MKCOL only creates a single level — skipping the parent causes a
      // 409 Conflict that we tolerate, but then the PUT fails because the
      // full path doesn't exist.
      final parentUri = Uri.parse(base.substring(0, base.lastIndexOf('/')));
      for (final uri in [parentUri, folderUri]) {
        await _dio.request(
          uri.toString(),
          options: Options(
            method: 'MKCOL',
            headers: _davHeaders(username, appPassword),
            validateStatus:
                (s) => s != null && (s < 300 || s == 405 || s == 409),
          ),
        );
      }

      final putUrl = '$base/$filename';
      final resp = await _dio.put(
        putUrl,
        data: content,
        options: Options(
          headers: {
            ..._davHeaders(username, appPassword),
            'Content-Type': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );
      return resp.statusCode != null && resp.statusCode! < 300;
    } catch (e) {
      debugPrint('Nextcloud upload failed for $filename: $e');
      return false;
    }
  }

  static Map<String, String> _davHeaders(String user, String pass) {
    final auth = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $auth', 'OCS-APIRequest': 'true'};
  }

  /// List files in backup dir.
  static Future<List<String>> listBackupFiles({
    required String server,
    required String username,
    required String appPassword,
  }) async {
    try {
      final base = await _buildWebDavUrl(server, username);
      final resp = await _dio.request(
        base,
        options: Options(
          method: 'PROPFIND',
          headers: {
            ..._davHeaders(username, appPassword),
            'Depth': '1',
            'Content-Type': 'application/xml',
          },
          validateStatus: (_) => true,
        ),
        data: '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>''',
      );
      if (resp.statusCode != 207) return [];
      final body = resp.data.toString();
      final RegExp reg = RegExp(r'<d:href>([^<]+)</d:href>');
      final matches = reg.allMatches(body);
      final files = <String>[];
      for (final m in matches) {
        final href = m.group(1)!;
        if (!href.endsWith('/')) {
          final name = href.split('/').last;
          if (name.startsWith('tayra-')) files.add(name);
        }
      }
      return files;
    } catch (e) {
      return [];
    }
  }

  /// Download a file content.
  static Future<String?> downloadFile({
    required String server,
    required String username,
    required String appPassword,
    required String filename,
  }) async {
    try {
      final base = await _buildWebDavUrl(server, username);
      final url = '$base/$filename';
      final resp = await _dio.get(
        url,
        options: Options(
          headers: _davHeaders(username, appPassword),
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      if (resp.statusCode == 200) return resp.data as String?;
    } catch (_) {}
    return null;
  }

  /// Perform backup: settings + listens split by year.
  /// Server info is the current Funkwhale server info + device id.
  static Future<bool> performBackup({
    required String ncServer,
    required String ncUsername,
    required String ncAppPassword,
    String? funkServerUrl,
  }) async {
    if (ncServer.isEmpty || ncUsername.isEmpty || ncAppPassword.isEmpty) {
      return false;
    }
    final deviceId = await getDeviceIdentifier();
    final deviceUuid = await getDeviceUuid();
    final deviceName = await getDeviceDisplayName();
    final serverHost =
        (funkServerUrl != null && funkServerUrl.isNotEmpty)
            ? extractSanitizedHostname(funkServerUrl)
            : 'no-server';

    // Export settings snapshot + server info (sanitized, no user tokens)
    final settingsJson = await _exportSettingsAndServerInfo(
      funkServerUrl,
      serverHost,
      deviceName,
      deviceUuid,
    );

    // Filenames are keyed by the per-device UUID (not the legacy sanitized
    // deviceId) so two identical-model devices can't clobber each other's
    // backups on the shared Nextcloud storage.
    final settingsFile = 'tayra-settings-$deviceUuid-$serverHost.json';
    final okSettings = await _uploadFile(
      server: ncServer,
      username: ncUsername,
      appPassword: ncAppPassword,
      filename: settingsFile,
      content: jsonEncode(settingsJson),
    );

    // Export listens: per year so load available and bucket.  Each file is
    // a wrapper object carrying the human-readable device name so other
    // devices can render it in the year-review without guessing from the
    // sanitized filename id.
    final years = await ListenHistoryService.getAvailableYears();
    bool allOk = okSettings;
    for (final y in years) {
      final yearListens = await ListenHistoryService.getListensForYear(y);
      // Only back up this device's own listens; skip remote-device data
      // that was synced in from other backups — its source of truth is
      // the original device's backup file.
      final localOnly =
          yearListens.where((r) {
            final s = r.sourceDevice;
            return s == null || s == 'local';
          }).toList();
      if (localOnly.isEmpty) continue;
      final fn = 'tayra-history-$deviceUuid-$serverHost-$y.json';
      final listensJson = {
        'version': 2,
        'device': deviceId,
        'deviceUuid': deviceUuid,
        'deviceName': deviceName,
        'records': localOnly.map((r) => r.toMapForBackup()).toList(),
      };
      final ok = await _uploadFile(
        server: ncServer,
        username: ncUsername,
        appPassword: ncAppPassword,
        filename: fn,
        content: jsonEncode(listensJson),
      );
      if (!ok) allOk = false;
    }

    // If no years, still upload empty marker for current year?
    if (years.isEmpty) {
      final y = DateTime.now().year;
      final fn = 'tayra-history-$deviceUuid-$serverHost-$y.json';
      await _uploadFile(
        server: ncServer,
        username: ncUsername,
        appPassword: ncAppPassword,
        filename: fn,
        content: jsonEncode({
          'version': 2,
          'device': deviceId,
          'deviceUuid': deviceUuid,
          'deviceName': deviceName,
          'records': const [],
        }),
      );
    }

    return allOk;
  }

  static Future<Map<String, dynamic>> _exportSettingsAndServerInfo(
    String? funkServerUrl,
    String serverHostSanitized,
    String deviceName,
    String deviceUuid,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final allPrefs = <String, dynamic>{};
    for (final k in prefs.getKeys()) {
      final v = prefs.get(k);
      allPrefs[k] = v;
    }

    // server info for relogin (NOT the session tokens, just enough)
    final serverInfo = {
      'serverUrl': funkServerUrl,
      'clientId':
          null, // client creds are per device, not portable easily; server url sufficient for "relogin"
      'clientSecret': null,
    };

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'device': await getDeviceIdentifier(),
      'deviceUuid': deviceUuid,
      'deviceName': deviceName,
      'serverHostname': serverHostSanitized,
      'settings': allPrefs,
      'serverInfo': serverInfo,
    };
  }

  /// Restore settings from a backup JSON.
  ///
  /// If [reuseDeviceUuid] is true, the backed-up device UUID is restored so
  /// this device retains its old identity (useful when recovering a wiped
  /// install on the same physical device).  When false (default), the
  /// current device's UUID is preserved so each device keeps a unique
  /// identifier.
  static Future<bool> restoreSettings(
    String jsonStr, {
    bool merge = true,
    bool reuseDeviceUuid = false,
  }) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final settings =
          (data['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      final prefs = await SharedPreferences.getInstance();
      for (final entry in settings.entries) {
        final k = entry.key;
        if (k.contains('token') ||
            k.contains('password') ||
            k == 'server_url') {
          continue;
        }
        if (!reuseDeviceUuid && k == _deviceUuidKey) {
          continue;
        }
        final v = entry.value;
        if (v is String) {
          await prefs.setString(k, v);
        } else if (v is int) {
          await prefs.setInt(k, v);
        } else if (v is bool) {
          await prefs.setBool(k, v);
        } else if (v is double) {
          await prefs.setDouble(k, v);
        }
      }
      return true;
    } catch (e) {
      debugPrint('restoreSettings: $e');
      return false;
    }
  }

  /// Restore listens from a history JSON (per year file contents). Merges without dedup.
  static Future<bool> restoreHistory(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      // Support v2 wrapper object and legacy bare-list format.
      final List list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final r = decoded['records'];
        if (r is! List) return false;
        list = r;
      } else {
        return false;
      }
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final rec = ListenRecord.fromBackupMap(item);
        await ListenHistoryService.insertRawListen(rec);
      }
      return true;
    } catch (e) {
      debugPrint('restoreHistory: $e');
      return false;
    }
  }

  /// Load all listening history records for a given year, from all device backups
  /// for the CURRENT Funkwhale server only (sanity filter).
  static Future<List<ListenRecord>> loadAllHistoryForYearFromBackups({
    required String ncServer,
    required String ncUser,
    required String ncAppPassword,
    required String funkServerHost,
    required int year,
  }) async {
    final records = <ListenRecord>[];
    if (ncServer.isEmpty ||
        ncUser.isEmpty ||
        ncAppPassword.isEmpty ||
        funkServerHost.isEmpty) {
      return records;
    }
    final srvHost = extractSanitizedHostname(funkServerHost);

    try {
      final allFiles = await listBackupFiles(
        server: ncServer,
        username: ncUser,
        appPassword: ncAppPassword,
      );
      final yearSuffix = '-$year.json';
      final relevant = allFiles.where(
        (f) =>
            f.startsWith('tayra-history-') &&
            f.endsWith(yearSuffix) &&
            f.contains('-$srvHost-'),
      );
      for (final fn in relevant) {
        if (!fn.contains('-$srvHost-')) continue;
        final content = await downloadFile(
          server: ncServer,
          username: ncUser,
          appPassword: ncAppPassword,
          filename: fn,
        );
        if (content == null) continue;
        try {
          final decoded = jsonDecode(content);
          // Support v2 wrapper object and legacy bare-list format.
          List items;
          if (decoded is List) {
            items = decoded;
          } else if (decoded is Map<String, dynamic>) {
            final r = decoded['records'];
            items = r is List ? r : const [];
          } else {
            continue;
          }
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final r = ListenRecord.fromBackupMap(item);
              if (r.listenedAt.year == year) records.add(r);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return records;
  }

  /// Background sync + rectifier.  Fetches all history backups from
  /// Nextcloud for the current Funkwhale server and merges them into the
  /// local listen_history table (with dedup):
  ///
  /// • **Remote devices** — their records are tagged with the source
  ///   device's UUID (or, for legacy pre-UUID backups, the sanitized
  ///   deviceId parsed from the filename).  The device display name is
  ///   cached so the year-review can render it.
  /// • **This device** — its own backup is re-ingested tagged as `'local'`.
  ///   This is the *rectifier*: if local listening history was lost (e.g.
  ///   by a cache clear that over-deleted, or an app reinstall), the
  ///   device's cloud backup restores it.  When local data is intact every
  ///   record is a duplicate and the dedup skips it, so this is a no-op.
  ///
  /// Both the v2 wrapper object (`{version, deviceUuid, deviceName,
  /// records}`) and the legacy bare-list format are accepted.
  static Future<int> syncRemoteHistory({
    required String ncServer,
    required String ncUser,
    required String ncAppPassword,
    required String funkServerHost,
  }) async {
    if (ncServer.isEmpty || ncUser.isEmpty || ncAppPassword.isEmpty) {
      return 0;
    }
    final srvHost = extractSanitizedHostname(funkServerHost);
    final myUuid = await getDeviceUuid();
    final myLegacyDeviceId = await getDeviceIdentifier();
    int totalInserted = 0;
    try {
      final allFiles = await listBackupFiles(
        server: ncServer,
        username: ncUser,
        appPassword: ncAppPassword,
      );
      final historyFiles = allFiles.where(
        (f) => f.startsWith('tayra-history-') && f.contains('-$srvHost-'),
      );
      for (final fn in historyFiles) {
        if (!fn.contains('-$srvHost-')) continue;

        // Parse the device part from the filename:
        // tayra-history-{devicePart}-{srvHost}-{year}.json
        // {devicePart} is either a UUID v4 (new format) or a sanitized
        // deviceId (legacy format).
        final devicePart =
            fn.startsWith('tayra-history-')
                ? fn
                    .substring('tayra-history-'.length)
                    .split('-$srvHost-')
                    .first
                : 'remote';

        // Is this the current device's own backup?  Match on UUID (new
        // format) or, for legacy backups created before UUIDs, the
        // sanitized deviceId.
        final isMine = devicePart == myUuid || devicePart == myLegacyDeviceId;

        final content = await downloadFile(
          server: ncServer,
          username: ncUser,
          appPassword: ncAppPassword,
          filename: fn,
        );
        if (content == null) continue;
        try {
          final decoded = jsonDecode(content);
          // Support v2 wrapper object and legacy bare-list format.
          List recordsList;
          String? deviceName;
          String? contentDeviceUuid;
          String? legacyDeviceId;
          if (decoded is List) {
            recordsList = decoded;
          } else if (decoded is Map<String, dynamic>) {
            final r = decoded['records'];
            recordsList = r is List ? r : const [];
            deviceName = decoded['deviceName'] as String?;
            contentDeviceUuid = decoded['deviceUuid'] as String?;
            legacyDeviceId = decoded['device'] as String?;
          } else {
            continue;
          }
          final records =
              recordsList
                  .whereType<Map<String, dynamic>>()
                  .map(ListenRecord.fromBackupMap)
                  .toList();

          if (isMine) {
            // Rectifier: this device's own backup.  Tag as 'local' so
            // cache-clear preserves it and the year-review groups it
            // under "This Device".  Dedup skips records already present.
            if (records.isNotEmpty) {
              totalInserted += await ListenHistoryService.insertRemoteRecords(
                records,
                sourceDevice: 'local',
              );
            }
          } else {
            // Remote device.  Prefer the UUID from the content; fall back
            // to the filename device part for legacy bare-list backups.
            final sourceDevice =
                (contentDeviceUuid != null && contentDeviceUuid.isNotEmpty)
                    ? contentDeviceUuid
                    : (legacyDeviceId ?? devicePart);
            if (deviceName != null && deviceName.isNotEmpty) {
              await ListenHistoryService.setDeviceDisplayName(
                sourceDevice,
                deviceName,
              );
            }
            if (records.isNotEmpty) {
              totalInserted += await ListenHistoryService.insertRemoteRecords(
                records,
                sourceDevice: sourceDevice,
              );
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return totalInserted;
  }
}
