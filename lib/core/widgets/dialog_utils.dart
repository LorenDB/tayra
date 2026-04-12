import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tayra/core/router/app_router.dart';

/// Helpers to present dialogs/sheets attached to the app shell's nested
/// navigator so PopScope and nested back handling work consistently.
Future<T?> showShellDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final ctx = shellNavigatorKey.currentContext ?? context;
  if (kDebugMode)
    debugPrint(
      'showShellDialog attached to ${ctx == context ? 'local' : 'shell'} context',
    );
  return showDialog<T>(
    context: ctx,
    useRootNavigator: false,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

Future<T?> showShellModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  ShapeBorder? shape,
}) {
  final ctx = shellNavigatorKey.currentContext ?? context;
  if (kDebugMode)
    debugPrint(
      'showShellModalBottomSheet attached to ${ctx == context ? 'local' : 'shell'} context',
    );
  return showModalBottomSheet<T>(
    context: ctx,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    shape: shape,
    builder: builder,
  );
}
