import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  group('ShimmerListTile', () {
    testWidgets('renders ShimmerBlock children for three-line with trailing',
        (tester) async {
      await tester.pumpWidget(wrap(const ShimmerListTile()));

      // Leading circle + title + subtitle1 + subtitle2 + 2 trailing = 6 blocks
      expect(find.byType(ShimmerBlock), findsNWidgets(6));
    });

    testWidgets('renders fewer blocks when isThreeLine is false',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ShimmerListTile(isThreeLine: false),
      ));

      // Leading + title + subtitle1 + 2 trailing = 5 blocks (no subtitle2)
      expect(find.byType(ShimmerBlock), findsNWidgets(5));
    });

    testWidgets('renders without trailing block when hasTrailing is false',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ShimmerListTile(hasTrailing: false),
      ));

      // Leading + title + subtitle1 + subtitle2 = 4 blocks (no trailing)
      expect(find.byType(ShimmerBlock), findsNWidgets(4));
    });

    testWidgets('two-line without trailing renders 3 blocks', (tester) async {
      await tester.pumpWidget(wrap(
        const ShimmerListTile(isThreeLine: false, hasTrailing: false),
      ));

      // Leading + title + subtitle1 = 3 blocks
      expect(find.byType(ShimmerBlock), findsNWidgets(3));
    });
  });
}
