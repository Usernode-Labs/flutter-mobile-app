import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_repository.dart';
import 'package:crypto_mobile_app/features/activity/presentation/activity_presentation.dart';
import 'package:crypto_mobile_app/features/activity/providers/activity_providers.dart';

enum ActivityFeedPhase { inactive, loading, ready, error }

const _unchangedCursor = Object();

class ActivityFeedState {
  const ActivityFeedState({
    required this.phase,
    this.entries = const [],
    this.nextCursor,
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.markingReadSequences = const {},
  });

  const ActivityFeedState.inactive() : this(phase: ActivityFeedPhase.inactive);

  const ActivityFeedState.loading() : this(phase: ActivityFeedPhase.loading);

  final ActivityFeedPhase phase;
  final List<ActivityFeedEntry> entries;
  final String? nextCursor;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final Set<String> markingReadSequences;

  ActivityFeedState copyWith({
    ActivityFeedPhase? phase,
    List<ActivityFeedEntry>? entries,
    Object? nextCursor = _unchangedCursor,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    Set<String>? markingReadSequences,
  }) {
    return ActivityFeedState(
      phase: phase ?? this.phase,
      entries: entries == null ? this.entries : List.unmodifiable(entries),
      nextCursor: identical(nextCursor, _unchangedCursor)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      markingReadSequences: markingReadSequences == null
          ? this.markingReadSequences
          : Set.unmodifiable(markingReadSequences),
    );
  }
}

final activityFeedProvider =
    NotifierProvider<ActivityFeedController, ActivityFeedState>(
  ActivityFeedController.new,
);

final activityUnreadCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(activityRepositoryProvider);
  if (repository == null) return 0;

  try {
    return (await repository.getUnreadCount()).value;
  } catch (error) {
    if (_isSessionUnavailable(error)) {
      ref.invalidate(activityFeedProvider);
    }
    // The shell badge is optional chrome. A missing session or temporary
    // Activity outage must not make the rest of the app noisy.
    return 0;
  }
});

class ActivityFeedController extends Notifier<ActivityFeedState> {
  int _requestVersion = 0;

  ActivityRepository? get _repository => ref.read(activityRepositoryProvider);

  @override
  ActivityFeedState build() {
    final repository = ref.watch(activityRepositoryProvider);
    if (repository == null) {
      return const ActivityFeedState.inactive();
    }

    Future<void>(() => _replaceFirstPage(repository, initial: true));
    return const ActivityFeedState.loading();
  }

  Future<bool> refresh() async {
    final repository = _repository;
    if (repository == null) return true;

    final loaded = await _replaceFirstPage(repository, initial: false);
    ref.invalidate(activityUnreadCountProvider);
    return loaded;
  }

  Future<bool> loadMore() async {
    final repository = _repository;
    final cursor = state.nextCursor;
    if (repository == null ||
        !state.hasMore ||
        cursor == null ||
        state.isLoadingMore) {
      return true;
    }

    final requestVersion = _requestVersion;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await repository.getFeed(before: cursor);
      final older = page.items.map(ActivityFeedEntry.fromItem);
      if (!_isCurrent(repository, requestVersion)) return false;

      final incoming = {
        for (final entry in older) entry.inboxSequence: entry,
      };
      state = state.copyWith(
        phase: ActivityFeedPhase.ready,
        entries: [
          for (final current in state.entries)
            incoming.remove(current.inboxSequence) ?? current,
          ...incoming.values,
        ],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(repository, requestVersion)) return false;
      if (_isSessionUnavailable(error)) {
        state = const ActivityFeedState(phase: ActivityFeedPhase.ready);
      } else {
        state = state.copyWith(isLoadingMore: false);
      }
      return false;
    }
  }

  Future<void> markRead(ActivityFeedEntry entry) async {
    final repository = _repository;
    if (repository == null ||
        !entry.isUnread ||
        !ref.read(activityWritesEnabledProvider) ||
        state.markingReadSequences.contains(entry.inboxSequence)) {
      return;
    }

    state = state.copyWith(
      markingReadSequences: {
        ...state.markingReadSequences,
        entry.inboxSequence,
      },
    );

    try {
      await repository.markRead(entry.inboxSequence);
      state = state.copyWith(
        entries: [
          for (final current in state.entries)
            if (current.inboxSequence == entry.inboxSequence)
              current.markedRead()
            else
              current,
        ],
      );
      await _replaceFirstPage(repository, initial: false);
      ref.invalidate(activityUnreadCountProvider);
    } catch (error) {
      if (_isSessionUnavailable(error)) {
        state = const ActivityFeedState(phase: ActivityFeedPhase.ready);
        ref.invalidate(activityUnreadCountProvider);
      }
      rethrow;
    } finally {
      if (identical(_repository, repository)) {
        state = state.copyWith(
          markingReadSequences: {
            for (final sequence in state.markingReadSequences)
              if (sequence != entry.inboxSequence) sequence,
          },
        );
      }
    }
  }

  Future<bool> _replaceFirstPage(
    ActivityRepository repository, {
    required bool initial,
  }) async {
    final requestVersion = ++_requestVersion;
    final previousEntries = state.entries;
    if (!initial) {
      state = state.copyWith(isRefreshing: true);
    }

    try {
      final page = await repository.getFeed();
      final refreshed = page.items.map(ActivityFeedEntry.fromItem).toList();
      if (!_isCurrent(repository, requestVersion)) return false;

      final refreshedSequences =
          refreshed.map((entry) => entry.inboxSequence).toSet();
      final entries = [
        ...refreshed,
        for (final previous in previousEntries)
          if (!refreshedSequences.contains(previous.inboxSequence)) previous,
      ];

      state = state.copyWith(
        phase: ActivityFeedPhase.ready,
        entries: entries,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isRefreshing: false,
        isLoadingMore: false,
      );
      return true;
    } catch (error) {
      if (!_isCurrent(repository, requestVersion)) return false;
      if (_isSessionUnavailable(error)) {
        state = const ActivityFeedState(phase: ActivityFeedPhase.ready);
        return true;
      }

      if (previousEntries.isEmpty) {
        state = const ActivityFeedState(phase: ActivityFeedPhase.error);
      } else {
        state = state.copyWith(
          phase: ActivityFeedPhase.ready,
          isRefreshing: false,
          isLoadingMore: false,
        );
      }
      return false;
    }
  }

  bool _isCurrent(ActivityRepository repository, int requestVersion) {
    return identical(_repository, repository) &&
        requestVersion == _requestVersion;
  }
}

bool _isSessionUnavailable(Object error) {
  return error is ActivitySessionRequiredException ||
      error is ActivityApiException &&
          error.statusCode == 401 &&
          error.code == ActivityApiErrorCode.unauthorizedConsumer;
}
