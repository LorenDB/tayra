import 'dart:io';

import 'package:flutter/material.dart';

/// Native: load a cover (or other image) from a filesystem path.
Widget buildLocalFileImage({
  required String path,
  required double width,
  required double height,
  required int decodePx,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    width: width,
    height: height,
    cacheWidth: decodePx,
    cacheHeight: decodePx,
    gaplessPlayback: true,
    filterQuality: FilterQuality.low,
    errorBuilder: errorBuilder,
  );
}
