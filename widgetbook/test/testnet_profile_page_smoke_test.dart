// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_workspace/main.dart';
import 'package:widgetbook_workspace/stories/atomic_challenge_card.stories.dart';
import 'package:widgetbook_workspace/stories/testnet_profile_page.stories.dart';

void main() {
  testWidgets('TestnetProfilePageDemo renders in Widgetbook shell', (
    tester,
  ) async {
    final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);
    final theme = cieTheme.light().copyWith(
      extensions: [
        ...DesignSystemTheme.standardExtensions(
          semanticColors: AppSemanticColors.light(),
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const TestnetProfilePageDemo()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('All Events'), findsOneWidget);
    expect(find.text('Completed Challenges'), findsOneWidget);
    expect(find.text('Produce Blocks'), findsOneWidget);
    expect(find.text('completed 6,500 pts'), findsOneWidget);
    expect(find.byType(AtomicChallengeCard), findsNWidgets(3));
    expect(
      tester
          .widgetList<AtomicChallengeCard>(find.byType(AtomicChallengeCard))
          .map((card) => card.cardTreatment),
      everyElement(AtomicChallengeCardTreatment.listItem),
    );
  });

  testWidgets('TestnetProfilePageDemo route renders in Widgetbook', (
    tester,
  ) async {
    final base = buildWidgetbookConfig();
    final config = Config(
      initialRoute:
          '/?path=prototypes/pages/challenges/TestnetProfilePageDemo/Default',
      components: base.components,
      appBuilder: base.appBuilder,
      home: base.home,
      addons: base.addons,
      integrations: base.integrations,
      lightTheme: base.lightTheme,
      darkTheme: base.darkTheme,
      themeMode: base.themeMode,
      header: base.header,
      scrollBehavior: base.scrollBehavior,
      scenarios: base.scenarios,
      docsBuilder: base.docsBuilder,
    );

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(WidgetbookApp(config: config));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsWidgets);
    expect(find.text('All Events'), findsWidgets);
  });
}
