import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrapWithHost(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: ShimmerHost(child: Center(child: child)),
      ),
    );
  }

  group('ShimmerCardSkeleton', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(wrapWithHost(
        const SizedBox(width: 360, child: ShimmerCardSkeleton()),
      ));
      await tester.pump();

      expect(find.byType(ShimmerCardSkeleton), findsOneWidget);
    });

    testWidgets('contains ShimmerBlock children', (tester) async {
      await tester.pumpWidget(wrapWithHost(
        const SizedBox(width: 360, child: ShimmerCardSkeleton()),
      ));
      await tester.pump();

      // 4 shimmer blocks: header, title, description, reward
      expect(find.byType(ShimmerBlock), findsNWidgets(4));
    });

    testWidgets('has bordered container decoration', (tester) async {
      await tester.pumpWidget(wrapWithHost(
        const SizedBox(width: 360, child: ShimmerCardSkeleton()),
      ));
      await tester.pump();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ShimmerCardSkeleton),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('uses FractionallySizedBox for layout', (tester) async {
      await tester.pumpWidget(wrapWithHost(
        const SizedBox(width: 360, child: ShimmerCardSkeleton()),
      ));
      await tester.pump();

      expect(find.byType(FractionallySizedBox), findsNWidgets(4));
    });
  });
}
