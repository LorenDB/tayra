import 'package:flutter/material.dart';

/// Helpers to present dialogs/sheets above all routes (including full-screen
/// routes like /queue and /now-playing that live outside the ShellRoute).
/// Using useRootNavigator: true ensures the overlay is always on top of the
/// entire navigator stack regardless of which navigator the caller belongs to.
Future<T?> showShellDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
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
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    shape: shape,
    builder: builder,
  );
}
