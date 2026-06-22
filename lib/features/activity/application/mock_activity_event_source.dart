import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/dapps/models/dapp_item.dart';

class MockActivityEventSource {
  const MockActivityEventSource();

  static const allNotificationScenarioKey = 'all';
  static const clearNotificationScenarioKey = 'clear';
  static const priorityStackScenarioKey = 'priority-stack';
  static const resetNotificationScenarioKey = 'reset';
  static const fallbackDappSlug = 'opinion-market';

  static const giveKudosChallengeId = 104;
  static const produceEveryBlockChallengeId = 107;
  static const useDappsChallengeId = 108;

  static const mockDapps = [
    DappItem(
      name: 'Opinion Market',
      author: 'Usernode Labs',
      url: 'https://opinion-market-eb3f76.social-vibecoding.usernodelabs.org',
    ),
    DappItem(
      name: 'Falling Sands',
      author: 'Usernode Labs',
      url:
          'https://falling-sands-game-ad186d.social-vibecoding.usernodelabs.org',
    ),
    DappItem(
      name: 'Last One Wins',
      author: 'Usernode Labs',
      url: 'https://last-one-wins-7053f0.social-vibecoding.usernodelabs.org',
    ),
    DappItem(
      name: 'Echo Diagnostic',
      author: 'Usernode Labs',
      url:
          'https://usernode-echo-diagnostic-6f02bf.social-vibecoding.usernodelabs.org/',
    ),
    DappItem(
      name: 'Web3 Trivia Quiz',
      author: 'Usernode Labs',
      url:
          'https://usernode-dapp-homepage-87a553.social-vibecoding.usernodelabs.org/trivia',
    ),
  ];

  List<ActivityEvent> seedEvents({DateTime? now}) {
    return notificationScenarios(
      now: now,
    ).map((scenario) => scenario.event).toList();
  }

  List<MockActivityNotificationScenario> notificationScenarios({
    DateTime? now,
  }) {
    final base = now ?? DateTime.now();
    return [
      _scenario(
        key: 'dapp-transaction',
        label: 'Transaction',
        category: ActivityCategory.dappTransaction,
        eventType: 'transaction_settled',
        title: 'Echo transaction settled',
        body: 'Echo Diagnostic confirmed your latest dApp transaction.',
        dappName: 'Echo Diagnostic',
        webRoute: '#app/echo-diagnostic/transactions/latest',
        createdAt: base,
        dappSlug: 'echo-diagnostic',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
      _scenario(
        key: 'dapp-game',
        label: 'Game',
        category: ActivityCategory.dappGame,
        eventType: 'game_turn_ready',
        title: 'Your move is ready',
        body: 'Last One Wins is waiting for your next move.',
        dappName: 'Last One Wins',
        webRoute: '#app/last-one-wins/rounds/current',
        createdAt: base.subtract(const Duration(minutes: 2)),
        dappSlug: 'last-one-wins',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
      _scenario(
        key: 'dapp-market',
        label: 'Market',
        category: ActivityCategory.dappMarket,
        eventType: 'market_position_changed',
        title: 'Opinion moved against you',
        body: 'Opinion Market changed while your position is still open.',
        dappName: 'Opinion Market',
        webRoute: '#app/opinion-market/markets/latest',
        createdAt: base.subtract(const Duration(minutes: 4)),
        dappSlug: 'opinion-market',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
      _scenario(
        key: 'dapp-canvas',
        label: 'Canvas',
        category: ActivityCategory.dappCanvas,
        eventType: 'canvas_updated',
        title: 'Canvas changed nearby',
        body: 'Falling Sands updated an area close to your last edit.',
        dappName: 'Falling Sands',
        webRoute: '#app/falling-sands/canvas/latest',
        createdAt: base.subtract(const Duration(minutes: 6)),
        dappSlug: 'falling-sands',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
      _scenario(
        key: 'dapp-feedback',
        label: 'Feedback',
        category: ActivityCategory.dappFeedback,
        eventType: 'diagnostic_report_ready',
        title: 'Diagnostic report is ready',
        body: 'Echo Diagnostic prepared a report for your review.',
        dappName: 'Echo Diagnostic',
        webRoute: '#app/echo-diagnostic/reports/latest',
        createdAt: base.subtract(const Duration(minutes: 8)),
        dappSlug: 'echo-diagnostic',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
      _scenario(
        key: 'dapp-quiz',
        label: 'Quiz',
        category: ActivityCategory.dappGame,
        eventType: 'quiz_round_available',
        title: 'Trivia round is available',
        body: 'Web3 Trivia Quiz opened a new round for you.',
        dappName: 'Web3 Trivia Quiz',
        webRoute: '#app/web3-trivia-quiz/rounds/latest',
        createdAt: base.subtract(const Duration(minutes: 10)),
        dappSlug: 'web3-trivia-quiz',
        routingBucket: MockActivityRoutingBucket.sourceDetail,
      ),
    ];
  }

  List<ActivityEvent> priorityStackEvents({DateTime? now}) {
    final base = now ?? DateTime.now();
    return [
      ActivityEvent(
        source: ActivitySource.system,
        category: ActivityCategory.productionSetup,
        eventType: 'battery_optimization_setup_needed',
        title: 'Battery optimization is not set up',
        body:
            'Open Usernode settings and set battery usage to Unrestricted so scheduled block production can wake the phone reliably.',
        createdAt: base,
        priority: ActivityPriority.persistent,
        dedupeKey: 'priority-stack:production-setup:battery',
        targetRoute: '/profile/settings',
      ),
      ActivityEvent(
        source: ActivitySource.node,
        category: ActivityCategory.productionResult,
        eventType: 'production_window_needs_attention',
        title: 'Block production needs attention',
        body:
            'The last scheduled production window did not complete. Keep Usernode open and check node status before the next slot.',
        createdAt: base.subtract(const Duration(minutes: 3)),
        priority: ActivityPriority.persistent,
        dedupeKey: 'priority-stack:production-result:missed-window',
        targetRoute: '/challenges/$produceEveryBlockChallengeId',
      ),
      ActivityEvent(
        source: ActivitySource.dapp,
        category: ActivityCategory.dappFeedback,
        eventType: 'diagnostic_report_ready',
        title: 'Diagnostic report is ready',
        body: 'Review Echo Diagnostic findings before the next test run.',
        createdAt: base.subtract(const Duration(minutes: 7)),
        priority: ActivityPriority.attention,
        dedupeKey: 'priority-stack:dapp-feedback:diagnostic-report',
        targetRoute: '/dapps/echo-diagnostic',
        payload: const {
          'bridgeMethod': 'notify',
          'dappName': 'Echo Diagnostic',
          'webRoute': '#app/echo-diagnostic/reports/latest',
        },
      ),
      ActivityEvent(
        source: ActivitySource.challenge,
        category: ActivityCategory.challengeDeadline,
        eventType: 'challenge_ending_soon',
        title: 'Give Kudos ends soon',
        body:
            'You still have 1 kudos left to give before the challenge closes.',
        createdAt: base.subtract(const Duration(hours: 1)),
        priority: ActivityPriority.attention,
        dedupeKey: 'priority-stack:challenge-deadline:give-kudos',
        targetRoute: '/challenges/$giveKudosChallengeId',
      ),
      ActivityEvent(
        source: ActivitySource.dapp,
        category: ActivityCategory.dappCanvas,
        eventType: 'canvas_updated_nearby',
        title: 'Canvas changed nearby',
        body: 'A nearby area changed after your last edit.',
        createdAt: base.subtract(const Duration(minutes: 12)),
        priority: ActivityPriority.passive,
        dedupeKey: 'priority-stack:dapp-canvas:nearby-change',
        targetRoute: '/dapps/falling-sands',
        payload: const {
          'bridgeMethod': 'notify',
          'dappName': 'Falling Sands',
          'webRoute': '#app/falling-sands/canvas/latest',
        },
      ),
      ActivityEvent(
        source: ActivitySource.node,
        category: ActivityCategory.productionResult,
        eventType: 'block_produced',
        title: 'Block produced',
        body:
            'Slot 1284 confirmed. Reward calculation will update after the epoch checkpoint.',
        createdAt: base.subtract(const Duration(minutes: 27)),
        priority: ActivityPriority.standard,
        dedupeKey: 'priority-stack:production-result:block-produced',
        targetRoute: '/challenges/$produceEveryBlockChallengeId',
      ),
    ];
  }

  bool isPriorityStackReadReceipt(ActivityRecord record) {
    return record.dedupeKey == 'priority-stack:dapp-canvas:nearby-change' ||
        record.dedupeKey == 'priority-stack:production-result:block-produced';
  }

  MockActivityNotificationScenario? notificationScenarioByKey(String key) {
    for (final scenario in notificationScenarios()) {
      if (scenario.key == key) return scenario;
    }
    return null;
  }

  static MockActivityNotificationScenario _scenario({
    required String key,
    required String label,
    required ActivityCategory category,
    required String eventType,
    required String title,
    required String body,
    required String dappName,
    required String webRoute,
    required DateTime createdAt,
    required String dappSlug,
    String? targetRoute,
    MockActivityRoutingBucket routingBucket =
        MockActivityRoutingBucket.sourceRoot,
  }) {
    final slug = _routeSlug(dappSlug);
    return MockActivityNotificationScenario(
      key: key,
      label: label,
      routingBucket: routingBucket,
      event: ActivityEvent(
        source: ActivitySource.dapp,
        category: category,
        eventType: eventType,
        title: title,
        body: body,
        createdAt: createdAt,
        priority: ActivityPriority.attention,
        dedupeKey: 'dapp:$dappName:$webRoute',
        targetRoute: targetRoute ?? '/dapps/$slug',
        payload: {
          'bridgeMethod': 'notify',
          'dappName': dappName,
          'webRoute': webRoute,
          'requestedCategory': label.toLowerCase(),
        },
      ),
    );
  }

  static String _routeSlug(String raw) {
    final slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? fallbackDappSlug : slug;
  }
}

enum MockActivityRoutingBucket { sourceRoot, sourceDetail }

class MockActivityNotificationScenario {
  const MockActivityNotificationScenario({
    required this.key,
    required this.label,
    required this.routingBucket,
    required this.event,
  });

  final String key;
  final String label;
  final MockActivityRoutingBucket routingBucket;
  final ActivityEvent event;
}
