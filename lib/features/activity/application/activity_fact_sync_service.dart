import 'dart:io';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/activity/application/activity_ingest_service.dart';
import 'package:crypto_mobile_app/features/activity/data/activity_record_store.dart';
import 'package:crypto_mobile_app/features/activity/models/activity_models.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

const productionSetupDedupeKey = 'production_setup:required_settings';
const _nodeRoute = '/main/node';
const _profileSettingsRoute = '/profile/settings';

class ProductionSetupFacts {
  const ProductionSetupFacts({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
    required this.batteryOptimizationDisabled,
    this.foregroundServiceRunning,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;
  final bool batteryOptimizationDisabled;
  final bool? foregroundServiceRunning;

  bool get healthy =>
      notificationsEnabled && exactAlarmsEnabled && batteryOptimizationDisabled;

  List<String> get missingFacts => [
    if (!notificationsEnabled) 'notifications',
    if (!exactAlarmsEnabled) 'exact_alarms',
    if (!batteryOptimizationDisabled) 'battery_optimization',
  ];
}

abstract class ProductionSetupFactReader {
  Future<ProductionSetupFacts> read();
}

class PlatformProductionSetupFactReader implements ProductionSetupFactReader {
  const PlatformProductionSetupFactReader();

  @override
  Future<ProductionSetupFacts> read() async {
    if (!Platform.isAndroid) {
      return const ProductionSetupFacts(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
        batteryOptimizationDisabled: true,
      );
    }

    final service = PlatformAlarmService.instance;
    await service.initialize();
    return ProductionSetupFacts(
      notificationsEnabled: await service.hasPostNotificationsPermission(),
      exactAlarmsEnabled: await service.hasExactAlarmPermission(),
      batteryOptimizationDisabled: await service
          .isBatteryOptimizationDisabled(),
      foregroundServiceRunning: await service.isPersistentForegroundRunning(),
    );
  }
}

class ActivityFactSyncService {
  ActivityFactSyncService({
    required ActivityRecordStore store,
    required ActivityIngestService ingestService,
    required ActivityNotificationPresenter presenter,
    required ProductionSetupFactReader productionSetupReader,
    DateTime Function()? now,
  }) : _store = store,
       _ingestService = ingestService,
       _presenter = presenter,
       _productionSetupReader = productionSetupReader,
       _now = now ?? DateTime.now;

  final ActivityRecordStore _store;
  final ActivityIngestService _ingestService;
  final ActivityNotificationPresenter _presenter;
  final ProductionSetupFactReader _productionSetupReader;
  final DateTime Function() _now;

  Future<List<ActivityRecord>> syncAvailableFacts({
    List<ChallengeDto>? challenges,
    BreakdownResult? breakdown,
  }) async {
    await syncProductionSetupFacts();
    await syncChallengeRewardFacts(
      challenges: challenges,
      breakdown: breakdown,
    );
    return _store.loadRecords();
  }

  Future<List<ActivityRecord>> syncProductionSetupFacts() async {
    final facts = await _productionSetupReader.read();
    if (facts.healthy) {
      return _archiveProductionSetupRecord();
    }

    return _ingestService.ingest(
      ActivityEvent(
        source: ActivitySource.system,
        category: ActivityCategory.productionSetup,
        eventType: 'production_setup_incomplete',
        title: 'Block production setup needs attention',
        body: _productionSetupBody(facts),
        priority: ActivityPriority.persistent,
        pinned: true,
        dedupeKey: productionSetupDedupeKey,
        targetRoute: _profileSettingsRoute,
        payload: {
          'sourceFact': 'production_setup',
          'factStatus': 'incomplete',
          'missingFacts': facts.missingFacts,
          if (facts.foregroundServiceRunning != null)
            'foregroundServiceRunning': facts.foregroundServiceRunning,
        },
      ),
    );
  }

  Future<List<ActivityRecord>> _archiveProductionSetupRecord() async {
    final records = await _store.loadRecords();
    var changed = false;
    final now = _now();
    final next = <ActivityRecord>[];
    for (final record in records) {
      if (record.dedupeKey == productionSetupDedupeKey && !record.archived) {
        changed = true;
        await _presenter.cancel(record);
        next.add(record.copyWith(archivedAt: now));
      } else {
        next.add(record);
      }
    }
    return changed ? _store.replaceAll(next) : records;
  }

  Future<List<ActivityRecord>> syncChallengeRewardFacts({
    List<ChallengeDto>? challenges,
    BreakdownResult? breakdown,
  }) async {
    if (challenges == null || challenges.isEmpty) return _store.loadRecords();

    final progressByChallenge = {
      for (final progress in breakdown?.challengeProgress ?? const [])
        progress.challengeId: progress,
    };

    final events = <ActivityEvent>[];
    final now = _now();
    for (final challenge in challenges) {
      if (!challenge.enabled) continue;
      events.addAll(
        _challengeEvents(challenge, progressByChallenge[challenge.id], now),
      );
    }

    if (events.isEmpty) return _store.loadRecords();
    return _ingestService.ingestAll(events);
  }

  Iterable<ActivityEvent> _challengeEvents(
    ChallengeDto challenge,
    ChallengeProgress? progress,
    DateTime now,
  ) sync* {
    final title = _challengeTitle(challenge);
    final startsAt = _parseDate(challenge.scheduleStart);
    final endsAt = _parseDate(challenge.scheduleEnd);

    if (!challenge.completed &&
        startsAt != null &&
        !startsAt.isAfter(now) &&
        now.difference(startsAt) <= const Duration(hours: 24)) {
      yield ActivityEvent(
        source: ActivitySource.challenge,
        category: ActivityCategory.challengePromotion,
        eventType: 'challenge_visible',
        title: '$title is live',
        body: 'A challenge is now available in Usernode.',
        dedupeKey: 'challenge:${challenge.id}:visible',
        targetRoute: _challengeRoute(challenge.id),
        payload: _challengePayload(challenge, 'visible'),
      );
    }

    if (!challenge.completed &&
        endsAt != null &&
        endsAt.isAfter(now) &&
        endsAt.difference(now) <= const Duration(hours: 24)) {
      yield ActivityEvent(
        source: ActivitySource.challenge,
        category: ActivityCategory.challengeDeadline,
        eventType: 'challenge_ending_soon',
        title: '$title ends soon',
        body: 'Open Challenges to review the remaining time.',
        priority: ActivityPriority.attention,
        dedupeKey: 'challenge:${challenge.id}:deadline:${_dayWindow(endsAt)}',
        expiresAt: endsAt,
        targetRoute: _challengeRoute(challenge.id),
        payload: _challengePayload(challenge, 'deadline'),
      );
    }

    if (challenge.completed) {
      yield ActivityEvent(
        source: ActivitySource.challenge,
        category: ActivityCategory.rewardActivity,
        eventType: 'challenge_completed',
        title: '$title completed',
        body: 'Your completed challenge is recorded in your earned history.',
        dedupeKey: 'challenge:${challenge.id}:completed',
        targetRoute: _challengeRoute(challenge.id),
        payload: _challengePayload(challenge, 'completed'),
      );
    }

    if (progress == null) return;

    if (progress.pendingPoints > 0) {
      yield ActivityEvent(
        source: ActivitySource.reward,
        category: ActivityCategory.rewardActivity,
        eventType: 'reward_pending',
        title: 'Reward pending review',
        body:
            '${_formatPoints(progress.pendingPoints)} pts pending for $title.',
        dedupeKey: 'reward:${challenge.id}:pending',
        targetRoute: _challengeRoute(challenge.id),
        payload: {
          ..._challengePayload(challenge, 'reward_pending'),
          'pendingPoints': progress.pendingPoints,
        },
      );
    }

    if (progress.earnedPoints > 0 ||
        progress.state == ChallengeProgressState.earned) {
      yield ActivityEvent(
        source: ActivitySource.reward,
        category: ActivityCategory.rewardActivity,
        eventType: 'reward_awarded',
        title: 'Reward awarded',
        body: '${_formatPoints(progress.earnedPoints)} pts awarded for $title.',
        dedupeKey: 'reward:${challenge.id}:awarded',
        targetRoute: _challengeRoute(challenge.id),
        payload: {
          ..._challengePayload(challenge, 'reward_awarded'),
          'earnedPoints': progress.earnedPoints,
        },
      );
    }
  }

  static String _productionSetupBody(ProductionSetupFacts facts) {
    final missing = facts.missingFacts;
    if (missing.contains('battery_optimization')) {
      return 'Set Usernode battery usage to Unrestricted so scheduled block production can wake the phone reliably.';
    }
    if (missing.contains('exact_alarms')) {
      return 'Enable exact alarms so Usernode can wake up for scheduled block production.';
    }
    return 'Enable notifications so Usernode can keep block production status visible.';
  }

  static String productionResultTargetRoute(List<ChallengeDto>? challenges) {
    final challenge = _currentProduceBlocksChallenge(challenges);
    return challenge == null ? _nodeRoute : _challengeRoute(challenge.id);
  }

  static ChallengeDto? _currentProduceBlocksChallenge(
    List<ChallengeDto>? challenges,
  ) {
    if (challenges == null || challenges.isEmpty) return null;

    for (final challenge in challenges) {
      if (challenge.enabled &&
          !challenge.completed &&
          isProduceBlocksChallenge(challenge)) {
        return challenge;
      }
    }

    for (final challenge in challenges) {
      if (isProduceBlocksChallenge(challenge)) return challenge;
    }

    return null;
  }

  static Map<String, Object?> _challengePayload(
    ChallengeDto challenge,
    String fact,
  ) {
    return {
      'sourceFact': 'challenge',
      'factStatus': fact,
      'challengeId': challenge.id,
      if (challenge.eventId != null) 'eventId': challenge.eventId,
    };
  }

  static String _challengeRoute(int challengeId) => '/challenges/$challengeId';

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String _challengeTitle(ChallengeDto challenge) {
    final goal = challenge.goal.trim();
    return goal.isNotEmpty ? goal : 'Challenge';
  }

  static String _dayWindow(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _formatPoints(int points) {
    final text = points.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return points < 0 ? '-$buffer' : buffer.toString();
  }
}
