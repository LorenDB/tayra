import 'package:dio/dio.dart';

/// Web: HTTP probe (no dart:io sockets).
Future<bool> checkServerReachability(String serverUrl) async {
  try {
    final base = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (_) => true,
      ),
    );
    final response = await dio.get('$base/api/v1/instance/nodeinfo/2.0/');
    return response.statusCode != null && response.statusCode! < 500;
  } catch (_) {
    return false;
  }
}
