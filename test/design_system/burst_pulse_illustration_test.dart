import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  group('BurstPulseIllustration', () {
    testWidgets('renders with empty rings list', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(rings: []),
        ),
      ));

      expect(find.byType(BurstPulseIllustration), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders with succeeded rings', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded, BurstRingOutcome.succeeded],
          ),
        ),
      ));

      expect(find.byType(BurstPulseIllustration), findsOneWidget);

      // Pump a few frames to verify animation runs without errors.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('renders with failed rings', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.failed],
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BurstPulseIllustration), findsOneWidget);
    });

    testWidgets('renders mixed outcomes', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [
              BurstRingOutcome.succeeded,
              BurstRingOutcome.failed,
              BurstRingOutcome.succeeded,
            ],
          ),
        ),
      ));

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BurstPulseIllustration), findsOneWidget);
    });

    testWidgets('handles new rings added via rebuild', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Add another ring.
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded, BurstRingOutcome.failed],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BurstPulseIllustration), findsOneWidget);
    });

    testWidgets('stops animation when active=false and rings expired',
        (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Set active=false — rings should eventually expire.
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded],
            active: false,
          ),
        ),
      ));

      // Pump past the ring lifetime (2.5s).
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BurstPulseIllustration), findsOneWidget);
    });

    testWidgets('disposes cleanly', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 200,
          height: 200,
          child: BurstPulseIllustration(
            rings: [BurstRingOutcome.succeeded],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Remove the widget.
      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      // No exceptions should be thrown.
      expect(tester.takeException(), isNull);
    });
  });
}
