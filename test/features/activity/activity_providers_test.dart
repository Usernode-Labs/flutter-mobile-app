import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_fact_sync_service.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/application/mock_activity_event_source.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';
import 'package:crypto_mobile_app/features/dapps/application/dapp_notification_bridge.dart';
import 'package:crypto_mobile_app/features/dapps/application/dapp_notification_web_route.dart';
import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds mock activity into an empty ledger', () async {
    final container = _container();
    addTearDown(container.dispose);

    final records = await container.read(activityControllerProvider.future);

    expect(records, isNotEmpty);
    expect(
      records.every((record) => record.source == ActivitySource.dapp),
      isTrue,
    );
    expect(
      records.every((record) => record.payloadJson['bridgeMethod'] == 'notify'),
      isTrue,
    );
    expect(container.read(activityUnreadCountProvider), records.length);
  });

  test('unread count excludes passive and archived receipts', () async {
    final records = [
      _record(
        id: 'attention',
        title: 'Approval requested',
        priority: ActivityPriority.attention,
      ),
      _record(
        id: 'passive',
        title: 'Canvas changed nearby',
        priority: ActivityPriority.passive,
      ),
      _record(
        id: 'archived',
        title: 'Archived alert',
        priority: ActivityPriority.attention,
        archivedAt: DateTime(2026, 1, 2),
      ),
      _record(
        id: 'read',
        title: 'Read alert',
        priority: ActivityPriority.attention,
        readAt: DateTime(2026, 1, 2),
      ),
    ];
    SharedPreferences.setMockInitialValues({
      NetworkPrefs.prefixKey('activity:records'): [
        for (final record in records) record.encode(),
      ],
    });
    final container = _container();
    addTearDown(container.dispose);

    await container.read(activityControllerProvider.future);

    expect(container.read(activityUnreadCountProvider), 1);
  });

  test('inject presents attention-worthy events through presenter', () async {
    final presenter = _FakePresenter();
    final container = _container(presenter: presenter);
    addTearDown(container.dispose);

    await container.read(activityControllerProvider.future);
    await container
        .read(activityControllerProvider.notifier)
        .inject(
          const ActivityEvent(
            source: ActivitySource.dapp,
            category: ActivityCategory.dappFeedback,
            eventType: 'diagnostic_report_ready',
            title: 'Diagnostic report is ready',
            body: 'Review Echo Diagnostic findings before the next test run.',
            priority: ActivityPriority.attention,
            dedupeKey: 'dapp:echo-diagnostic:report-ready',
            targetRoute: '/dapps/echo-diagnostic',
          ),
        );

    expect(presenter.presented.map((record) => record.title), [
      'Diagnostic report is ready',
    ]);
  });

  test('parsed dApp bridge notification is persisted as activity', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(activityControllerProvider.future);
    await container
        .read(activityControllerProvider.notifier)
        .inject(
          DappNotificationBridgePayload.parse(
            payload: const {
              'method': 'notify',
              'title': 'Dev session finished',
              'body': 'Review the generated proposal.',
              'route': '#app/builder/dev/sessions/abc',
            },
            dappName: 'Social Vibecoding',
            nativeTargetRoute: '/dapps',
          ),
        );

    final records =
        container.read(activityControllerProvider).valueOrNull ?? [];
    final record = records.firstWhere(
      (record) => record.title == 'Dev session finished',
    );

    expect(record.source, ActivitySource.dapp);
    expect(record.category, ActivityCategory.dappFeedback);
    expect(record.targetRoute, '/dapps');
    expect(record.payloadJson['webRoute'], '#app/builder/dev/sessions/abc');
  });

  test(
    'attention-worthy parsed dApp bridge notification reaches presenter',
    () async {
      final presenter = _FakePresenter();
      final container = _container(presenter: presenter);
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);
      await container
          .read(activityControllerProvider.notifier)
          .inject(
            DappNotificationBridgePayload.parse(
              payload: const {
                'method': 'notify',
                'title': 'Approval requested',
                'body': 'A dApp proposal is waiting for review.',
                'category': 'feedback',
                'priority': 'attention',
              },
              dappName: 'Echo Diagnostic',
              nativeTargetRoute: '/dapps/echo-diagnostic',
            ),
          );

      expect(presenter.presented.map((record) => record.title), [
        'Approval requested',
      ]);
      expect(presenter.presented.single.targetRoute, '/dapps/echo-diagnostic');
    },
  );

  test('parsed dApp bridge notifications route by host context', () {
    final hubEvent = DappNotificationBridgePayload.parse(
      payload: const {'method': 'notify', 'title': 'Hub alert'},
      dappName: 'Social Vibecoding',
      nativeTargetRoute: '/dapps',
    );
    final sluggedEvent = DappNotificationBridgePayload.parse(
      payload: const {'method': 'notify', 'title': 'Echo received'},
      dappName: 'Echo',
      nativeTargetRoute: '/dapps/echo',
    );

    expect(hubEvent.targetRoute, '/dapps');
    expect(sluggedEvent.targetRoute, '/dapps/echo');
  });

  test('mock notification scenarios point at known mock dApps', () {
    const source = MockActivityEventSource();
    final mockSlugs = _mockDappSlugs();
    final scenarios = source.notificationScenarios();

    expect(
      scenarios.map((scenario) => scenario.event.source),
      everyElement(ActivitySource.dapp),
    );
    expect(
      scenarios.map((scenario) => scenario.event.payload['bridgeMethod']),
      everyElement('notify'),
    );

    for (final scenario in scenarios) {
      final targetSlug = _dappSlugFromTargetRoute(scenario.event.targetRoute);
      expect(
        targetSlug,
        isIn(mockSlugs),
        reason: '${scenario.key} must target a mocked dApp detail route',
      );
      final webSlug = dappSlugFromNotificationWebRoute(
        scenario.event.payload['webRoute']?.toString(),
      );
      expect(
        webSlug,
        isIn(mockSlugs),
        reason: '${scenario.key} web route must resolve to a mocked dApp',
      );
    }
  });

  test('mock notification scenarios use exact source-detail routing', () {
    const source = MockActivityEventSource();

    expect(
      source.notificationScenarios().map((scenario) => scenario.routingBucket),
      everyElement(MockActivityRoutingBucket.sourceDetail),
    );
  });

  test(
    'mock notification scenarios resolve to their matching dApp fixture',
    () {
      const source = MockActivityEventSource();

      final scenario = source.notificationScenarioByKey('dapp-transaction');

      expect(scenario, isNotNull);
      expect(scenario!.event.targetRoute, '/dapps/echo-diagnostic');
      expect(scenario.event.payload['dappName'], 'Echo Diagnostic');
      expect(scenario.routingBucket, MockActivityRoutingBucket.sourceDetail);
    },
  );

  test(
    'trigger all mock notifications populates every feed scenario',
    () async {
      final presenter = _FakePresenter();
      final container = _container(presenter: presenter);
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);
      final source = container.read(mockActivityEventSourceProvider);
      final scenarioCount = source.notificationScenarios().length;

      final handled = await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(
            MockActivityEventSource.allNotificationScenarioKey,
          );

      expect(handled, isTrue);
      expect(presenter.presented, isEmpty);
      final records =
          container.read(activityControllerProvider).valueOrNull ?? [];
      expect(records, hasLength(scenarioCount));
      expect(records.map((record) => record.category).toSet(), {
        ActivityCategory.dappTransaction,
        ActivityCategory.dappGame,
        ActivityCategory.dappMarket,
        ActivityCategory.dappCanvas,
        ActivityCategory.dappFeedback,
      });
      expect(
        records.map((record) => record.source),
        everyElement(ActivitySource.dapp),
      );
    },
  );

  test(
    'mock dApp detail scenario does not borrow unrelated dApp slugs',
    () async {
      final presenter = _FakePresenter();
      final container = _container(
        presenter: presenter,
        dapps: const [
          DappItem(
            name: 'Unlisted Lab',
            author: 'Usernode Labs',
            url: 'https://example.com/unlisted-lab',
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);
      await container.read(dappsProvider.future);

      final handled = await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario('dapp-transaction');

      expect(handled, isTrue);
      expect(presenter.presented.single.targetRoute, '/dapps/echo-diagnostic');
    },
  );

  test(
    'trigger all mock notifications persists expected target routes',
    () async {
      final container = _container();
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);
      await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(
            MockActivityEventSource.resetNotificationScenarioKey,
          );

      final handled = await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(
            MockActivityEventSource.allNotificationScenarioKey,
          );

      final records =
          container.read(activityControllerProvider).valueOrNull ?? [];
      final routes = {
        for (final record in records) record.dedupeKey: record.targetRoute,
      };

      expect(handled, isTrue);
      expect(
        routes['dapp:Echo Diagnostic:#app/echo-diagnostic/transactions/latest'],
        '/dapps/echo-diagnostic',
      );
      expect(
        routes['dapp:Last One Wins:#app/last-one-wins/rounds/current'],
        '/dapps/last-one-wins',
      );
      expect(
        routes['dapp:Opinion Market:#app/opinion-market/markets/latest'],
        '/dapps/opinion-market',
      );
      expect(
        routes['dapp:Falling Sands:#app/falling-sands/canvas/latest'],
        '/dapps/falling-sands',
      );
      expect(
        routes['dapp:Echo Diagnostic:#app/echo-diagnostic/reports/latest'],
        '/dapps/echo-diagnostic',
      );
      expect(
        routes['dapp:Web3 Trivia Quiz:#app/web3-trivia-quiz/rounds/latest'],
        '/dapps/web3-trivia-quiz',
      );
    },
  );

  test(
    'priority stack mock scenario replaces feed with pinned priority records',
    () async {
      final presenter = _FakePresenter();
      final container = _container(presenter: presenter);
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);

      final handled = await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(
            MockActivityEventSource.priorityStackScenarioKey,
          );

      final records =
          container.read(activityControllerProvider).valueOrNull ?? [];

      expect(handled, isTrue);
      expect(records.map((record) => record.title), [
        'Battery optimization is not set up',
        'Block production needs attention',
        'Diagnostic report is ready',
        'Canvas changed nearby',
        'Block produced',
        'Give Kudos ends soon',
      ]);
      expect(
        records.take(2).map((record) => record.pinned),
        everyElement(true),
      );
      expect(records.take(2).map((record) => record.priority), [
        ActivityPriority.persistent,
        ActivityPriority.persistent,
      ]);
      expect(
        records
            .where(
              (record) =>
                  record.title == 'Canvas changed nearby' ||
                  record.title == 'Block produced',
            )
            .map((record) => record.unread),
        everyElement(false),
      );
      expect(container.read(activityUnreadCountProvider), 4);
      expect(presenter.presented, isEmpty);
      expect(presenter.cancelled, isNotEmpty);
    },
  );

  test(
    'clear mock notification scenario clears presented notifications',
    () async {
      final presenter = _FakePresenter();
      final container = _container(presenter: presenter);
      addTearDown(container.dispose);

      await container.read(activityControllerProvider.future);

      final handled = await container
          .read(activityControllerProvider.notifier)
          .injectMockNotificationScenario(
            MockActivityEventSource.clearNotificationScenarioKey,
          );

      expect(handled, isTrue);
      expect(presenter.cancelled, isNotEmpty);
    },
  );

  test('reset mock notification scenario clears the local ledger', () async {
    final presenter = _FakePresenter();
    final container = _container(presenter: presenter);
    addTearDown(container.dispose);

    expect(await container.read(activityControllerProvider.future), isNotEmpty);

    final handled = await container
        .read(activityControllerProvider.notifier)
        .injectMockNotificationScenario(
          MockActivityEventSource.resetNotificationScenarioKey,
        );

    expect(handled, isTrue);
    expect(container.read(activityControllerProvider).valueOrNull, isEmpty);
    expect(presenter.cancelled, isNotEmpty);
  });
}

ProviderContainer _container({
  _FakePresenter? presenter,
  List<DappItem> dapps = MockActivityEventSource.mockDapps,
}) {
  return ProviderContainer(
    overrides: [
      dappsProvider.overrideWith((ref) async => dapps),
      activityNotificationPresenterProvider.overrideWithValue(
        presenter ?? _FakePresenter(),
      ),
      productionSetupFactReaderProvider.overrideWithValue(
        const _HealthyProductionSetupReader(),
      ),
      challengesProvider.overrideWith(_EmptyChallengesController.new),
      breakdownProvider.overrideWith(_EmptyBreakdownController.new),
    ],
  );
}

Set<String> _mockDappSlugs() {
  return {for (final dapp in MockActivityEventSource.mockDapps) dapp.slug};
}

String? _dappSlugFromTargetRoute(String? route) {
  final text = route?.trim();
  if (text == null) return null;
  return RegExp(r'^/dapps/([a-z0-9-]+)$').firstMatch(text)?.group(1);
}

ActivityRecord _record({
  required String id,
  required String title,
  required ActivityPriority priority,
  DateTime? readAt,
  DateTime? archivedAt,
}) {
  return ActivityRecord(
    id: id,
    source: ActivitySource.dapp,
    category: ActivityCategory.dappFeedback,
    eventType: 'test',
    title: title,
    body: 'Activity body',
    createdAt: DateTime(2026, 1, 1),
    readAt: readAt,
    archivedAt: archivedAt,
    priority: priority,
    pinned: false,
    targetRoute: '/dapps',
  );
}

class _FakePresenter implements ActivityNotificationPresenter {
  final presented = <ActivityRecord>[];
  final cancelled = <ActivityRecord>[];

  @override
  Future<void> show(ActivityRecord record) async {
    presented.add(record);
  }

  @override
  Future<void> cancel(ActivityRecord record) async {
    cancelled.add(record);
  }
}

class _HealthyProductionSetupReader implements ProductionSetupFactReader {
  const _HealthyProductionSetupReader();

  @override
  Future<ProductionSetupFacts> read() async {
    return const ProductionSetupFacts(
      notificationsEnabled: true,
      exactAlarmsEnabled: true,
      batteryOptimizationDisabled: true,
    );
  }
}

class _EmptyChallengesController extends ChallengesController {
  @override
  bool watchDeps() => true;

  @override
  Future<List<ChallengeDto>> fetch() async => const [];
}

class _EmptyBreakdownController extends BreakdownController {
  @override
  bool watchDeps() => false;

  @override
  Future<BreakdownResult> fetch() async => throw StateError('not fetched');
}
