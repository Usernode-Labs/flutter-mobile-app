import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(title: 'No items'),
      ));

      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(
          icon: Symbols.inbox_sharp,
          title: 'Empty',
        ),
      ));

      expect(find.byIcon(Symbols.inbox_sharp), findsOneWidget);
    });

    testWidgets('hides icon when null', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(title: 'Empty'),
      ));

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(
          title: 'No items',
          subtitle: 'Try again later',
        ),
      ));

      expect(find.text('Try again later'), findsOneWidget);
    });

    testWidgets('hides subtitle when null', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(title: 'No items'),
      ));

      // Only title text present
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(wrap(
        EmptyState(
          title: 'No items',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Retry'),
          ),
        ),
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('hides action when null', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(title: 'No items'),
      ));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('wraps content in Semantics liveRegion', (tester) async {
      await tester.pumpWidget(wrap(
        const EmptyState(title: 'Empty'),
      ));

      expect(
        tester.getSemantics(find.byType(EmptyState)),
        matchesSemantics(isLiveRegion: true),
      );
    });

    testWidgets('renders all elements together', (tester) async {
      await tester.pumpWidget(wrap(
        EmptyState(
          icon: Symbols.search_sharp,
          title: 'No results',
          subtitle: 'Try a different search',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Search'),
          ),
        ),
      ));

      expect(find.byIcon(Symbols.search_sharp), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Try a different search'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });
  });
}
