import 'package:crypto_mobile_app/core/widgets/app_progress_bar.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: child,
    );
  }

  List<EpochMetricData> buildMetrics({
    VoidCallback? onCheckedSlots,
    VoidCallback? onProduced,
    VoidCallback? onMissed,
    VoidCallback? onUpcoming,
  }) {
    return [
      EpochMetricData(
        icon: Symbols.search_sharp,
        title: 'Checked Slots',
        subtitle: 'Evaluated 240 of 240',
        trailingValue: '100%',
        onTap: onCheckedSlots ?? () {},
        showChevron: true,
      ),
      EpochMetricData(
        icon: Symbols.check_box_sharp,
        title: 'Produced Blocks',
        subtitle: '16 of 21 won slots',
        trailingValue: '16',
        onTap: onProduced ?? () {},
        showChevron: true,
      ),
      const EpochMetricData(
        icon: Symbols.disabled_by_default_sharp,
        title: 'Missed Blocks',
        subtitle: '0 of 21 won slots missed',
        trailingValue: '0',
      ),
      EpochMetricData(
        icon: Symbols.schedule_sharp,
        title: 'Upcoming Blocks',
        subtitle: '3 upcoming this epoch',
        trailingValue: '3',
        onTap: onUpcoming ?? () {},
        showChevron: true,
      ),
    ];
  }

  EpochPerformancePage buildPage({
    String epochLabel = 'Epoch 176',
    double progress = 0.72,
    List<EpochMetricData>? metrics,
    VoidCallback? onPrev,
    VoidCallback? onNext,
    VoidCallback? onBackTap,
  }) {
    return EpochPerformancePage(
      epochLabel: epochLabel,
      progress: progress,
      progressLeftLabel: '12,442 / 17,280 slots',
      progressRightLabel: '7h 14min left',
      performanceLabel: 'Epoch Performance',
      performanceValue: '95.2%',
      metrics: metrics ?? buildMetrics(),
      onPrev: onPrev,
      onNext: onNext,
      onPickEpoch: (_) {},
      maxEpoch: 200,
      selectedEpoch: 176,
      onBackTap: onBackTap,
    );
  }

  group('EpochPerformancePage', () {
    testWidgets('renders epoch label in AppBar', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.text('Epoch 176'), findsWidgets);
    });

    testWidgets('renders progress bar', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.byType(AppProgressBar), findsOneWidget);
    });

    testWidgets('renders slot progress labels', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.text('12,442 / 17,280 slots'), findsOneWidget);
      expect(find.text('7h 14min left'), findsOneWidget);
    });

    testWidgets('renders performance heading', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.text('Epoch Performance'), findsOneWidget);
      expect(find.text('95.2%'), findsOneWidget);
    });

    testWidgets('renders 4 ListTile metrics', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.text('Checked Slots'), findsOneWidget);
      expect(find.text('Produced Blocks'), findsOneWidget);
      expect(find.text('Missed Blocks'), findsOneWidget);
      expect(find.text('Upcoming Blocks'), findsOneWidget);
    });

    testWidgets('renders metric subtitles', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.text('Evaluated 240 of 240'), findsOneWidget);
      expect(find.text('16 of 21 won slots'), findsOneWidget);
    });

    testWidgets('renders All filter chip', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    });

    testWidgets('prev button fires callback', (tester) async {
      var prevTapped = false;
      await tester.pumpWidget(wrap(buildPage(
        onPrev: () => prevTapped = true,
      )));

      await tester.tap(find.byIcon(Symbols.chevron_left_sharp));
      expect(prevTapped, isTrue);
    });

    testWidgets('next button fires callback', (tester) async {
      var nextTapped = false;
      await tester.pumpWidget(wrap(buildPage(
        onNext: () => nextTapped = true,
      )));

      // Find the IconButton.filledTonal with chevron_right (not the metric trailing)
      final nextButtons = find.ancestor(
        of: find.byIcon(Symbols.chevron_right_sharp),
        matching: find.byType(IconButton),
      );
      await tester.tap(nextButtons.first);
      expect(nextTapped, isTrue);
    });

    testWidgets('prev/next buttons disabled when callbacks null',
        (tester) async {
      await tester.pumpWidget(wrap(buildPage(
        onPrev: null,
        onNext: null,
      )));

      final prevButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Symbols.chevron_left_sharp),
      );
      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Symbols.chevron_right_sharp),
      );
      expect(prevButton.onPressed, isNull);
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('metric tile onTap fires', (tester) async {
      var checkedSlotsTapped = false;
      await tester.pumpWidget(wrap(buildPage(
        metrics: buildMetrics(
          onCheckedSlots: () => checkedSlotsTapped = true,
        ),
      )));

      await tester.tap(find.text('Checked Slots'));
      expect(checkedSlotsTapped, isTrue);
    });

    testWidgets('back button fires callback', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(wrap(buildPage(
        onBackTap: () => backTapped = true,
      )));

      await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
      expect(backTapped, isTrue);
    });

    testWidgets('renders leading icon containers for metrics', (tester) async {
      await tester.pumpWidget(wrap(buildPage()));

      // Each metric tile has a leading icon container (4 metrics)
      expect(find.byType(ListTile), findsNWidgets(4));
    });

    testWidgets('metric with showChevron shows chevron icon', (tester) async {
      await tester.pumpWidget(wrap(buildPage(
        metrics: [
          EpochMetricData(
            icon: Symbols.search_sharp,
            title: 'With Chevron',
            subtitle: 'Has chevron',
            trailingValue: '100%',
            onTap: () {},
            showChevron: true,
          ),
          const EpochMetricData(
            icon: Symbols.block_sharp,
            title: 'Without Chevron',
            subtitle: 'No chevron',
            trailingValue: '0',
          ),
        ],
      )));

      // One chevron_right in the epoch panel next button + one in the metric trailing
      // Verify the metric-specific chevron by finding it within a ListTile
      final metricChevrons = find.descendant(
        of: find.byType(ListTile),
        matching: find.byIcon(Symbols.chevron_right_sharp),
      );
      expect(metricChevrons, findsOneWidget);
    });
  });
}
