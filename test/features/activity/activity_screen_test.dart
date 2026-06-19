import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';
import 'package:crypto_mobile_app/features/activity/screens/activity_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders seeded activity feed records', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityNotificationPresenterProvider.overrideWithValue(
            const _NoopPresenter(),
          ),
        ],
        child: MaterialApp(
          theme: ColorIsExpensiveTheme(ThemeData.light().textTheme)
              .light()
              .copyWith(
                extensions: DesignSystemTheme.standardExtensions(
                  semanticColors: AppSemanticColors.light(),
                ),
              ),
          darkTheme: ColorIsExpensiveTheme(ThemeData.dark().textTheme)
              .dark()
              .copyWith(
                extensions: DesignSystemTheme.standardExtensions(
                  semanticColors: AppSemanticColors.dark(),
                ),
              ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ActivityScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Echo transaction settled'), findsOneWidget);
    expect(find.text('Your move is ready'), findsOneWidget);
    expect(find.textContaining('Echo Diagnostic'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').contains('Unread') &&
            (widget.properties.label ?? '').contains(
              'Echo transaction settled',
            ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Last One Wins'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Identity proof is ready'), 220);
    expect(find.text('Identity proof is ready'), findsOneWidget);
    expect(find.textContaining('dApps,'), findsNothing);
    expect(find.textContaining('info only'), findsNothing);
  });

  testWidgets('pushes source-available card taps so back returns to Activity', (
    tester,
  ) async {
    final record = ActivityRecord(
      id: 'dapp-transaction',
      source: ActivitySource.dapp,
      category: ActivityCategory.dappTransaction,
      eventType: 'transaction_confirmed',
      title: 'Transaction confirmed',
      body: 'Your dApp transaction was confirmed on Usernode.',
      createdAt: DateTime(2026, 1, 1),
      priority: ActivityPriority.attention,
      pinned: false,
      targetRoute: '/challenges',
      dedupeKey: 'dapp:transaction:confirmed',
    );
    SharedPreferences.setMockInitialValues({
      NetworkPrefs.prefixKey('activity:records'): [record.encode()],
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const ActivityScreen()),
        GoRoute(
          path: '/challenges',
          builder: (context, state) =>
              const Scaffold(body: Text('Challenges destination')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityNotificationPresenterProvider.overrideWithValue(
            const _NoopPresenter(),
          ),
        ],
        child: MaterialApp.router(
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Challenges'), findsOneWidget);

    await tester.tap(find.text('Transaction confirmed'));
    await tester.pumpAndSettle();

    expect(find.text('Challenges destination'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Transaction confirmed'), findsOneWidget);
  });
}

ThemeData _lightTheme() {
  return ColorIsExpensiveTheme(ThemeData.light().textTheme).light().copyWith(
    extensions: DesignSystemTheme.standardExtensions(
      semanticColors: AppSemanticColors.light(),
    ),
  );
}

ThemeData _darkTheme() {
  return ColorIsExpensiveTheme(ThemeData.dark().textTheme).dark().copyWith(
    extensions: DesignSystemTheme.standardExtensions(
      semanticColors: AppSemanticColors.dark(),
    ),
  );
}

class _NoopPresenter implements ActivityNotificationPresenter {
  const _NoopPresenter();

  @override
  Future<void> show(ActivityRecord record) async {}

  @override
  Future<void> cancel(ActivityRecord record) async {}
}
