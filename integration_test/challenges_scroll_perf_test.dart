/// Scroll performance integration test for the Challenges screen.
///
/// Run with:
/// ```bash
/// flutter drive --profile --driver=test_driver/perf_driver.dart \
///   --target=integration_test/challenges_scroll_perf_test.dart
/// ```
///
/// Outputs frame build/raster timeline JSON for CI regression detection.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('challenges screen scroll performance', (tester) async {
    // TODO: Replace with the actual app bootstrap that sets up mock providers
    // for challenges, ranking, breakdown, and seasons data.
    //
    // Example:
    //   await tester.pumpWidget(
    //     ProviderScope(
    //       overrides: [ ... mock overrides ... ],
    //       child: const MyApp(),
    //     ),
    //   );
    //   await tester.pumpAndSettle();

    // Navigate to the challenges screen if needed.
    // await tester.tap(find.text('Challenges'));
    // await tester.pumpAndSettle();

    // Record timeline during fling scrolls.
    await binding.traceAction(
      () async {
        for (var i = 0; i < 5; i++) {
          await tester.fling(
            find.byType(ListView).first,
            const Offset(0, -500),
            1500,
          );
          await tester.pumpAndSettle();

          await tester.fling(
            find.byType(ListView).first,
            const Offset(0, 500),
            1500,
          );
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'challenges_scroll_timeline',
    );
  });
}
