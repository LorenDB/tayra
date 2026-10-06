import 'package:flutter/material.dart';
import 'package:tayra/core/theme/app_theme.dart';

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

/// Ask for one line of text in the app's standard dialog style.
///
/// Returns the trimmed text, or null when the dialog was cancelled. Unless
/// [allowEmpty] is set, the confirm action stays disabled while the field is
/// blank.
///
/// The text controller lives in the dialog's own state, so it is disposed
/// together with the dialog instead of while the exit animation is still
/// building the field.
Future<String?> showTextPromptDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String hintText = '',
  String initialText = '',
  bool allowEmpty = false,
  TextCapitalization textCapitalization = TextCapitalization.none,
}) {
  return showShellDialog<String>(
    context: context,
    builder:
        (_) => _TextPromptDialog(
          title: title,
          confirmLabel: confirmLabel,
          hintText: hintText,
          initialText: initialText,
          allowEmpty: allowEmpty,
          textCapitalization: textCapitalization,
        ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String hintText;
  final String initialText;
  final bool allowEmpty;
  final TextCapitalization textCapitalization;

  const _TextPromptDialog({
    required this.title,
    required this.confirmLabel,
    required this.hintText,
    required this.initialText,
    required this.allowEmpty,
    required this.textCapitalization,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Start with any suggested text selected so typing replaces it.
    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.initialText,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialText.length,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      widget.allowEmpty || _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: AppTheme.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: AppTheme.onBackground),
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          hintText: widget.hintText,
          filled: true,
          fillColor: AppTheme.surfaceContainer,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.onBackgroundMuted),
          ),
        ),
        // Rebuilds only the confirm action as the text changes.
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final enabled = _canSubmit;
            return TextButton(
              onPressed: enabled ? _submit : null,
              child: Text(
                widget.confirmLabel,
                style: TextStyle(
                  color:
                      enabled ? AppTheme.primary : AppTheme.onBackgroundSubtle,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
