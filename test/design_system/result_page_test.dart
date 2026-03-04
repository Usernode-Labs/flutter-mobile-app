import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrapFullPage(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  group('ResultPage', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'Transaction Sent',
        ),
      ));

      expect(find.text('Transaction Sent'), findsOneWidget);
    });

    testWidgets('success variant shows check icon', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'Success',
        ),
      ));

      expect(find.byIcon(Symbols.check_sharp), findsOneWidget);
    });

    testWidgets('failure variant shows close icon', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.failure,
          title: 'Failed',
        ),
      ));

      expect(find.byIcon(Symbols.close_sharp), findsOneWidget);
    });

    testWidgets('info variant shows info icon', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.info,
          title: 'Notice',
        ),
      ));

      expect(find.byIcon(Symbols.info_sharp), findsOneWidget);
    });

    testWidgets('custom icon overrides default', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'Sent',
          icon: Symbols.send_sharp,
        ),
      ));

      expect(find.byIcon(Symbols.send_sharp), findsOneWidget);
      expect(find.byIcon(Symbols.check_sharp), findsNothing);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'Sent',
          subtitle: '100 tokens transferred',
        ),
      ));

      expect(find.text('100 tokens transferred'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'Sent',
        ),
      ));

      // Only title text and no subtitle
      expect(find.text('Sent'), findsOneWidget);
    });

    testWidgets('renders primaryAction when provided', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        ResultPage(
          variant: ResultPageVariant.success,
          title: 'Done',
          primaryAction: FilledButton(
            onPressed: () {},
            child: const Text('OK'),
          ),
        ),
      ));

      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('renders both actions when provided', (tester) async {
      await tester.pumpWidget(wrapFullPage(
        ResultPage(
          variant: ResultPageVariant.success,
          title: 'Complete',
          primaryAction: FilledButton(
            onPressed: () {},
            child: const Text('Done'),
          ),
          secondaryAction: TextButton(
            onPressed: () {},
            child: const Text('View Details'),
          ),
        ),
      ));

      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });

    testWidgets('success uses semantic success container color',
        (tester) async {
      await tester.pumpWidget(wrapFullPage(
        const ResultPage(
          variant: ResultPageVariant.success,
          title: 'OK',
        ),
      ));

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, semantic.success.colorContainer);
    });
  });
}
