import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_repository.dart';
import 'package:crypto_mobile_app/features/activity/domain/activity_assertion_provider.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_feed_provider.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';

import '../activity_test_fixtures.dart';

void main() {
  test('is inert when Activity is not configured', () {
    final container = _container(repository: null);

    expect(
      container.read(activityFeedProvider).phase,
      ActivityFeedPhase.inactive,
    );
    expect(container.read(activityFeedProvider).entries, isEmpty);
  });

  test('treats a missing consumer session as an empty feed', () async {
    final repository = _FakeActivityRepository(
      feedError: const ActivitySessionRequiredException(),
    );
    final container = _container(repository: repository);

    final state = await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    expect(state.entries, isEmpty);
  });

  test('loads a validated page and the optional unread count', () async {
    final repository = _FakeActivityRepository(
      pages: [validFeedPageJson()],
      unreadCount: 4,
    );
    final container = _container(repository: repository);

    final state = await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    expect(state.entries, hasLength(1));
    expect(state.entries.single.isUnread, isTrue);
    expect(await container.read(activityUnreadCountProvider.future), 4);
  });

  test('badge authorization revocation clears visible feed state', () async {
    final repository = _FakeActivityRepository(
      pages: [validFeedPageJson()],
      revokeOnUnread: true,
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );
    expect(container.read(activityFeedProvider).entries, isNotEmpty);

    expect(await container.read(activityUnreadCountProvider.future), 0);
    final state = await _waitFor(
      container,
      (value) =>
          value.phase == ActivityFeedPhase.ready && value.entries.isEmpty,
    );

    expect(state.entries, isEmpty);
  });

  test('loads known and generic contracts in the same page', () async {
    final repository = _FakeActivityRepository(
      pages: [
        validFeedPageJson(
          items: [
            validActivityItemJson(),
            validGenericActivityItemJson(),
          ],
        ),
      ],
    );
    final container = _container(repository: repository);

    final state = await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    expect(state.entries, hasLength(2));
    expect(state.entries.first.isGeneric, isFalse);
    expect(state.entries.last.isGeneric, isTrue);
  });

  test('fails the page closed when the known contract is invalid', () async {
    final invalid = validActivityItemJson();
    final event = invalid['activityEvent']! as Map<String, dynamic>;
    final sourceEvent = event['sourceEvent']! as Map<String, dynamic>;
    sourceEvent['facts'] = {'privatePreview': 'not a dev-run fact'};
    final repository = _FakeActivityRepository(
      pages: [
        validFeedPageJson(items: [invalid]),
      ],
    );
    final container = _container(repository: repository);

    final state = await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.error,
    );

    expect(state.entries, isEmpty);
  });

  test('marks read once and refreshes server-authoritative state', () async {
    final repository = _FakeActivityRepository(
      pages: [
        validFeedPageJson(),
        validFeedPageJson(
          items: [
            validActivityItemJson(readAt: '2026-07-20T12:00:00Z'),
          ],
        ),
      ],
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    final entry = container.read(activityFeedProvider).entries.single;
    await container.read(activityFeedProvider.notifier).markRead(entry);

    expect(repository.markedRead, ['1']);
    expect(repository.feedCalls, 2);
    expect(container.read(activityFeedProvider).entries.single.isUnread, false);
  });

  test('keeps a confirmed mark read when immediate refresh fails', () async {
    final repository = _FakeActivityRepository(pages: [validFeedPageJson()]);
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    final entry = container.read(activityFeedProvider).entries.single;
    await container.read(activityFeedProvider.notifier).markRead(entry);

    final state = container.read(activityFeedProvider);
    expect(repository.markedRead, ['1']);
    expect(state.entries.single.isUnread, isFalse);
  });

  test('keeps an unread row unchanged when mark-read fails', () async {
    final repository = _FakeActivityRepository(
      pages: [validFeedPageJson()],
      markReadError: StateError('offline'),
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );
    final entry = container.read(activityFeedProvider).entries.single;

    await expectLater(
      container.read(activityFeedProvider.notifier).markRead(entry),
      throwsStateError,
    );

    final state = container.read(activityFeedProvider);
    expect(state.entries.single.isUnread, isTrue);
    expect(state.markingReadSequences, isEmpty);
  });

  test('clears in-memory feed after consumer authorization is revoked',
      () async {
    final repository = _FakeActivityRepository(
      pages: [validFeedPageJson()],
      markReadError: const ActivityApiException(
        statusCode: 401,
        code: ActivityApiErrorCode.unauthorizedConsumer,
      ),
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );
    final entry = container.read(activityFeedProvider).entries.single;

    await expectLater(
      container.read(activityFeedProvider.notifier).markRead(entry),
      throwsA(isA<ActivityApiException>()),
    );

    expect(container.read(activityFeedProvider).entries, isEmpty);
  });

  test('VIEW_ONLY never sends a mark-read mutation', () async {
    final repository = _FakeActivityRepository(pages: [validFeedPageJson()]);
    final container = _container(
      repository: repository,
      writesEnabled: false,
    );
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    await container.read(activityFeedProvider.notifier).markRead(
          container.read(activityFeedProvider).entries.single,
        );

    expect(repository.markedRead, isEmpty);
  });

  test('loads and deduplicates an older cursor page', () async {
    final repository = _FakeActivityRepository(
      pagesByCursor: {
        null: validFeedPageJson(
          nextCursor: 'older-page',
          hasMore: true,
        ),
        'older-page': validFeedPageJson(
          items: [
            validActivityItemJson(),
            validActivityItemJson(inboxSequence: '2', version: 3),
          ],
        ),
      },
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    await container.read(activityFeedProvider.notifier).loadMore();

    final state = container.read(activityFeedProvider);
    expect(
      state.entries.map((entry) => entry.inboxSequence),
      ['1', '2'],
    );
    expect(state.hasMore, isFalse);
  });

  test('loads a generic contract from an older cursor page', () async {
    final repository = _FakeActivityRepository(
      pagesByCursor: {
        null: validFeedPageJson(
          nextCursor: 'older-page',
          hasMore: true,
        ),
        'older-page': validFeedPageJson(
          items: [validGenericActivityItemJson()],
        ),
      },
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );

    await container.read(activityFeedProvider.notifier).loadMore();

    final entries = container.read(activityFeedProvider).entries;
    expect(entries, hasLength(2));
    expect(entries.last.isGeneric, isTrue);
  });

  test('marking an older item preserves loaded pagination', () async {
    final repository = _FakeActivityRepository(
      pagesByCursor: {
        null: validFeedPageJson(
          nextCursor: 'older-page',
          hasMore: true,
        ),
        'older-page': validFeedPageJson(
          items: [validActivityItemJson(inboxSequence: '2', version: 3)],
        ),
      },
    );
    final container = _container(repository: repository);
    await _waitFor(
      container,
      (value) => value.phase == ActivityFeedPhase.ready,
    );
    await container.read(activityFeedProvider.notifier).loadMore();
    final older = container.read(activityFeedProvider).entries.last;

    await container.read(activityFeedProvider.notifier).markRead(older);

    final entries = container.read(activityFeedProvider).entries;
    expect(entries.map((entry) => entry.inboxSequence), ['1', '2']);
    expect(entries.last.isUnread, isFalse);
  });
}

ProviderContainer _container({
  required ActivityRepository? repository,
  bool writesEnabled = true,
}) {
  final container = ProviderContainer(
    overrides: [
      activityRepositoryProvider.overrideWithValue(repository),
      activityWritesEnabledProvider.overrideWithValue(writesEnabled),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ActivityFeedState> _waitFor(
  ProviderContainer container,
  bool Function(ActivityFeedState value) predicate,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final value = container.read(activityFeedProvider);
    if (predicate(value)) return value;
    await Future<void>.delayed(Duration.zero);
  }
  throw TestFailure('Activity provider did not reach the expected state');
}

class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository({
    this.pages = const [],
    this.pagesByCursor,
    this.feedError,
    this.markReadError,
    this.unreadCount = 0,
    this.revokeOnUnread = false,
  });

  final List<Map<String, dynamic>> pages;
  final Map<String?, Map<String, dynamic>>? pagesByCursor;
  final Object? feedError;
  final Object? markReadError;
  final int unreadCount;
  final bool revokeOnUnread;

  int feedCalls = 0;
  bool _revoked = false;
  final List<String> markedRead = [];

  @override
  Future<ActivityFeedPage> getFeed({String? before, int limit = 100}) async {
    feedCalls++;
    if (_revoked) throw const ActivitySessionRequiredException();
    final error = feedError;
    if (error != null) throw error;
    final page = pagesByCursor?[before] ?? pages[feedCalls - 1];
    return ActivityFeedPage.fromJson(page);
  }

  @override
  Future<void> markRead(String inboxSequence) async {
    final error = markReadError;
    if (error != null) throw error;
    markedRead.add(inboxSequence);
  }

  @override
  Future<ActivityUnreadCount> getUnreadCount() async {
    if (revokeOnUnread) {
      _revoked = true;
      throw const ActivityApiException(
        statusCode: 401,
        code: ActivityApiErrorCode.unauthorizedConsumer,
      );
    }
    return ActivityUnreadCount(unreadCount);
  }

  @override
  Future<void> clearSession() async {}

  @override
  Future<ActivitySession> establishSession(
    ActivityAssertionProvider assertionProvider,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<bool> restoreSession() async => true;

  @override
  Future<ActivitySyncPage> sync({String? after, int limit = 100}) {
    throw UnimplementedError();
  }
}
