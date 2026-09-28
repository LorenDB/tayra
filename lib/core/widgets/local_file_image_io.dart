import 'dart:io';

import 'package:flutter/material.dart';

/// Native: load a cover (or other image) from a filesystem path.
///
/// Cached covers are already the 200px or 600px rendition. Scaling them
/// again in the JPEG codec (cacheWidth and cacheHeight together) paints
/// some files gray, so this decodes the file as stored.
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
    gaplessPlayback: true,
    filterQuality: FilterQuality.low,
    errorBuilder: errorBuilder,
  );
}
