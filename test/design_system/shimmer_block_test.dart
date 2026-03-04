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

  group('ShimmerBlock', () {
    testWidgets('renders with specified dimensions', (tester) async {
      await tester.pumpWidget(wrap(
        const Center(child: ShimmerBlock(width: 180, height: 36)),
      ));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 180);
      expect(sizedBox.height, 36);
    });

    testWidgets('uses ShaderMask for animation', (tester) async {
      await tester.pumpWidget(wrap(
        const Center(child: ShimmerBlock(width: 100, height: 20)),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('renders static block when animations disabled',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeWithExtensions(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: ShimmerBlock(width: 100, height: 20)),
            ),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(DecoratedBox), findsOneWidget);
    });

    testWidgets('accepts custom borderRadius', (tester) async {
      await tester.pumpWidget(wrap(
        const Center(
          child: ShimmerBlock(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ));

      expect(find.byType(ShimmerBlock), findsOneWidget);
    });
  });
}
