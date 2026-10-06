import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayra/core/widgets/dialog_utils.dart';

void main() {
  /// Pumps a screen with a button that opens the prompt and records what it
  /// returned.
  Future<List<String?>> pumpPrompt(
    WidgetTester tester, {
    String initialText = '',
    bool allowEmpty = false,
  }) async {
    final results = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    results.add(
                      await showTextPromptDialog(
                        context: context,
                        title: 'New Playlist',
                        hintText: 'Playlist name',
                        confirmLabel: 'Create',
                        initialText: initialText,
                        allowEmpty: allowEmpty,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  TextButton confirmButton(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Create'));

  testWidgets('returns the trimmed text', (tester) async {
    final results = await pumpPrompt(tester);

    await tester.enterText(find.byType(TextField), '  Road trip  ');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(results, ['Road trip']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirm stays disabled while the field is blank', (
    tester,
  ) async {
    final results = await pumpPrompt(tester);
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    // Submitting from the keyboard must not get around it either.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(results, isEmpty);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('cancel returns null', (tester) async {
    final results = await pumpPrompt(tester, initialText: 'Old name');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggested text starts selected so typing replaces it', (
    tester,
  ) async {
    await pumpPrompt(tester, initialText: 'Old name');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Old name');
    expect(
      field.controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 8),
    );
  });

  testWidgets('an empty answer can be allowed', (tester) async {
    final results = await pumpPrompt(
      tester,
      initialText: 'Old name',
      allowEmpty: true,
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(results, ['']);
  });
}
