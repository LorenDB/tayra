import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isLinux => Platform.isLinux;
bool get isMacOS => Platform.isMacOS;
bool get isWindows => Platform.isWindows;

Future<String> deviceLabel() async {
  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}';
  }
  return Platform.localHostname;
}

String? get doNotTrackEnv {
  try {
    return Platform.environment['DO_NOT_TRACK'];
  } catch (_) {
    return null;
  }
}

void tryExitProcess() {
  exit(0);
}
