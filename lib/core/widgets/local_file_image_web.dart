import 'package:flutter/material.dart';

/// Web: local files are not used (online-only). Callers should not reach here
/// when [AppPlatform.supportsOfflineCache] is false; return empty as safety.
Widget buildLocalFileImage({
  required String path,
  required double width,
  required double height,
  required int decodePx,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return SizedBox(width: width, height: height);
}
