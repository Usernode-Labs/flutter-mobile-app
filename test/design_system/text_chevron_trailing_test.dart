import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('TextChevronTrailing', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(wrap(
        const TextChevronTrailing(text: '10,000 pts'),
      ));

      expect(find.text('10,000 pts'), findsOneWidget);
    });

    testWidgets('renders chevron_right icon', (tester) async {
      await tester.pumpWidget(wrap(
        const TextChevronTrailing(text: 'Value'),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsOneWidget);
    });

    testWidgets('icon uses onSurfaceVariant color', (tester) async {
      await tester.pumpWidget(wrap(
        const TextChevronTrailing(text: 'Value'),
      ));

      final theme = themeWithExtensions();
      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.chevron_right_sharp),
      );
      expect(icon.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('icon uses iconSmall size', (tester) async {
      await tester.pumpWidget(wrap(
        const TextChevronTrailing(text: 'Value'),
      ));

      final icon = tester.widget<Icon>(
        find.byIcon(Symbols.chevron_right_sharp),
      );
      expect(icon.size, 20.0); // iconSmall
    });

    testWidgets('works as ListTile trailing', (tester) async {
      await tester.pumpWidget(wrap(
        const ListTile(
          title: Text('Leaderboard'),
          trailing: TextChevronTrailing(text: '#5'),
        ),
      ));

      expect(find.byType(TextChevronTrailing), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
    });
  });
}
