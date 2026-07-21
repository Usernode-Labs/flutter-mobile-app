import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/presentation/activity_presentation.dart';
import 'package:crypto_mobile_app/features/activity/presentation/screens/activity_screen.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_feed_provider.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';

import '../../../design_system/helpers/ds_test_helpers.dart';
import '../activity_test_fixtures.dart';

void main() {
  test('English relative-time copy handles singular units', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    expect(l10n.timeMinutesAgo(1), '1 minute ago');
    expect(l10n.timeHoursAgo(1), '1 hour ago');
    expect(l10n.timeDaysAgo(1), '1 day ago');
  });

  testWidgets('renders the Activity loading state', (tester) async {
    final loading = _FakeActivityFeedController(
      const ActivityFeedState.loading(),
    );
    await tester.pumpWidget(_app(loading));
    expect(find.byType(ShimmerListTile), findsNWidgets(4));
  });

  testWidgets('renders a localized error and retries', (tester) async {
    final error = _FakeActivityFeedController(
      const ActivityFeedState(phase: ActivityFeedPhase.error),
    );
    await tester.pumpWidget(_app(error));
    expect(find.text("Couldn't load activity"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(error.refreshCalls, 1);
  });

  testWidgets('renders the localized empty state', (tester) async {
    final empty = _FakeActivityFeedController(
      const ActivityFeedState(phase: ActivityFeedPhase.ready),
    );
    await tester.pumpWidget(_app(empty));
    expect(find.text('No activity yet'), findsOneWidget);
    expect(
      find.text('Important Usernode events will appear here'),
      findsOneWidget,
    );
  });

  testWidgets('renders validated local copy and unread semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final entry = _entry();
    final controller = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [entry],
      ),
    );

    await tester.pumpWidget(_app(controller));

    expect(find.text('Activity'), findsWidgets);
    expect(find.text('Social • Just now'), findsOneWidget);
    expect(find.text('Build completed'), findsOneWidget);
    expect(find.text('The run produced code'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Unread')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping an unread row marks it read once', (tester) async {
    final entry = _entry();
    final controller = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [entry],
      ),
    );
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.text('Build completed'));
    await tester.pump();

    expect(controller.markedRead, [entry.inboxSequence]);
  });

  testWidgets('renders and marks read a privacy-safe generic row',
      (tester) async {
    final entry = ActivityFeedEntry.fromItem(
      ActivityItem.fromJson(validGenericActivityItemJson()),
    );
    final controller = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [entry],
      ),
    );
    await tester.pumpWidget(_app(controller));

    expect(find.text('Activity • Just now'), findsOneWidget);
    expect(find.text('Activity update'), findsOneWidget);
    expect(find.text('Open the source app to view details'), findsOneWidget);
    expect(find.textContaining('must never be rendered'), findsNothing);

    await tester.tap(find.text('Activity update'));
    await tester.pump();

    expect(controller.markedRead, [entry.inboxSequence]);
  });

  testWidgets('shows generic feedback when mark-read fails', (tester) async {
    final controller = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [_entry()],
      ),
      markReadError: StateError('private backend detail'),
    );
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.text('Build completed'));
    await tester.pump();

    expect(find.text("Couldn't mark activity as read"), findsOneWidget);
    expect(find.textContaining('private backend detail'), findsNothing);
  });

  testWidgets('receipt rows are informational', (tester) async {
    final receipt = _entry(status: 'cancelled');
    final receiptController = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [receipt],
      ),
    );
    await tester.pumpWidget(_app(receiptController));
    await tester.tap(find.text('Build cancelled'));
    await tester.pump();
    expect(receiptController.markedRead, isEmpty);
  });

  testWidgets('VIEW_ONLY rows are informational', (tester) async {
    final unreadController = _FakeActivityFeedController(
      ActivityFeedState(
        phase: ActivityFeedPhase.ready,
        entries: [_entry()],
      ),
    );
    await tester.pumpWidget(_app(unreadController, writesEnabled: false));
    await tester.tap(find.text('Build completed'));
    await tester.pump();
    expect(unreadController.markedRead, isEmpty);
  });

  testWidgets('pull-to-refresh delegates to the feed controller',
      (tester) async {
    final controller = _FakeActivityFeedController(
      const ActivityFeedState(phase: ActivityFeedPhase.ready),
    );
    await tester.pumpWidget(_app(controller));

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(controller.refreshCalls, 1);
  });
}

Widget _app(
  _FakeActivityFeedController controller, {
  bool writesEnabled = true,
}) {
  return ProviderScope(
    overrides: [
      activityFeedProvider.overrideWith(() => controller),
      activityWritesEnabledProvider.overrideWithValue(writesEnabled),
      activityClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 7, 17, 12, 5, 30),
      ),
      topStatusChromeRawNodeStatusProvider.overrideWithValue(
        TopStatusNodeStatus.synced,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeWithExtensions(),
      home: const ActivityScreen(),
    ),
  );
}

ActivityFeedEntry _entry({String status = 'succeeded'}) {
  return ActivityFeedEntry.fromItem(
    ActivityItem.fromJson(validActivityItemJson(status: status)),
  );
}

class _FakeActivityFeedController extends ActivityFeedController {
  _FakeActivityFeedController(
    this.initialState, {
    this.markReadError,
  });

  final ActivityFeedState initialState;
  final Object? markReadError;
  int refreshCalls = 0;
  final List<String> markedRead = [];

  @override
  ActivityFeedState build() => initialState;

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    return true;
  }

  @override
  Future<void> markRead(ActivityFeedEntry entry) async {
    final error = markReadError;
    if (error != null) throw error;
    markedRead.add(entry.inboxSequence);
  }
}
