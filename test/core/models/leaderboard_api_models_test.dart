import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';

void main() {
  // -------------------------------------------------------------------------
  // LeaderboardApiException
  // -------------------------------------------------------------------------

  group('LeaderboardApiException', () {
    test('toString includes status code and message', () {
      final e = LeaderboardApiException(404, 'Not found', body: '{}');
      expect(e.toString(), 'LeaderboardApiException(404, Not found)');
      expect(e.statusCode, 404);
      expect(e.message, 'Not found');
      expect(e.body, '{}');
    });
  });

  // -------------------------------------------------------------------------
  // RegistrationEventInfo
  // -------------------------------------------------------------------------

  group('RegistrationEventInfo', () {
    test('fromJson parses all fields with event_id key', () {
      final info = RegistrationEventInfo.fromJson({
        'event_id': 3,
        'name': 'Event 3',
        'ends_at': '2025-03-01T00:00:00Z',
      });
      expect(info.id, 3);
      expect(info.name, 'Event 3');
      expect(info.endsAt, '2025-03-01T00:00:00Z');
    });

    test('fromJson falls back to id key (cache compat)', () {
      final info = RegistrationEventInfo.fromJson({
        'id': 3,
        'name': 'Event 3',
      });
      expect(info.id, 3);
    });

    test('fromJson handles null endsAt', () {
      final info =
          RegistrationEventInfo.fromJson({'event_id': 1, 'name': 'E1'});
      expect(info.endsAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // RegistrationV2Result
  // -------------------------------------------------------------------------

  group('RegistrationV2Result', () {
    test('fromJson parses re-registration response (with season)', () {
      final result = RegistrationV2Result.fromJson({
        'participant_id': 42,
        'identity_uid': 'uid-abc',
        'public_key': 'pk-123',
        'secret_key': 'sk-456',
        'address': 'addr-789',
        'tier': 'gold',
        'season_id': 1,
        'season_name': 'Season 1',
        'event': {
          'event_id': 2,
          'name': 'Event 2',
          'ends_at': '2025-06-01',
        },
      });
      expect(result.participantId, 42);
      expect(result.identityUid, 'uid-abc');
      expect(result.publicKey, 'pk-123');
      expect(result.secretKey, 'sk-456');
      expect(result.address, 'addr-789');
      expect(result.tier, 'gold');
      expect(result.seasonId, 1);
      expect(result.seasonName, 'Season 1');
      expect(result.event, isNotNull);
      expect(result.event!.id, 2);
    });

    test('fromJson parses first registration (no season/event)', () {
      final result = RegistrationV2Result.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid',
        'public_key': 'pk',
        'secret_key': 'sk',
        'address': 'addr',
        'tier': 'silver',
      });
      expect(result.seasonId, isNull);
      expect(result.seasonName, isNull);
      expect(result.event, isNull);
    });

    test('fromJson falls back to phase key (cache compat)', () {
      final result = RegistrationV2Result.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid',
        'public_key': 'pk',
        'secret_key': 'sk',
        'address': 'addr',
        'tier': 'silver',
        'season_id': 1,
        'season_name': 'S1',
        'phase': {'id': 2, 'name': 'Phase 2'},
      });
      expect(result.event, isNotNull);
      expect(result.event!.id, 2);
    });
  });

  // -------------------------------------------------------------------------
  // RankingResult
  // -------------------------------------------------------------------------

  group('RankingResult', () {
    test('fromJson parses event scope', () {
      final r = RankingResult.fromJson({
        'scope': 'event',
        'rank': 5,
        'total_points': 1200,
        'offchain_points': 300,
        'total_participants': 500,
        'event_id': 10,
        'event_name': 'Event Alpha',
      });
      expect(r.scope, 'event');
      expect(r.rank, 5);
      expect(r.totalPoints, 1200);
      expect(r.offchainPoints, 300);
      expect(r.totalParticipants, 500);
      expect(r.eventId, 10);
      expect(r.eventName, 'Event Alpha');
      expect(r.seasonId, isNull);
    });

    test('fromJson parses season scope with events_participated', () {
      final r = RankingResult.fromJson({
        'scope': 'season',
        'rank': 3,
        'total_points': 5000,
        'offchain_points': 1000,
        'total_participants': 2000,
        'season_id': 1,
        'season_name': 'Season 1',
        'events_participated': 4,
        'total_produced_blocks': 25,
      });
      expect(r.scope, 'season');
      expect(r.seasonId, 1);
      expect(r.seasonName, 'Season 1');
      expect(r.eventsParticipated, 4);
      expect(r.totalProducedBlocks, 25);
      expect(r.eventId, isNull);
    });

    test('fromJson falls back to phases_participated (cache compat)', () {
      final r = RankingResult.fromJson({
        'scope': 'season',
        'rank': 3,
        'total_points': 5000,
        'offchain_points': 1000,
        'total_participants': 2000,
        'phases_participated': 4,
      });
      expect(r.eventsParticipated, 4);
    });

    test('fromJson parses global scope with minimal fields', () {
      final r = RankingResult.fromJson({
        'scope': 'global',
        'rank': 1,
        'total_points': 99999,
        'offchain_points': 0,
        'total_participants': 10000,
      });
      expect(r.scope, 'global');
      expect(r.eventId, isNull);
      expect(r.seasonId, isNull);
      expect(r.eventsParticipated, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ChallengeDto
  // -------------------------------------------------------------------------

  group('ChallengeDto', () {
    test('fromJson parses all fields', () {
      final c = ChallengeDto.fromJson({
        'id': 7,
        'event_id': 2,
        'event_name': 'Event 2',
        'event_type': 'season',
        'category': 'block_production',
        'sub_category': 'PRODUCE_BLOCKS_CHALLENGE',
        'goal': 'Produce 10 blocks',
        'task': 'Block Production',
        'reward': 500,
        'description': 'Produce blocks to earn points',
        'requirements': 'Node must be running',
        'reward_logic': 'Fixed per completion',
        'cta_label': 'Start',
        'cta_link': 'https://example.com',
        'schedule_start': '2025-01-01',
        'schedule_end': '2025-02-01',
        'enabled': true,
        'completed': false,
      });
      expect(c.id, 7);
      expect(c.eventId, 2);
      expect(c.eventName, 'Event 2');
      expect(c.eventType, 'season');
      expect(c.category, 'block_production');
      expect(c.subCategory, 'PRODUCE_BLOCKS_CHALLENGE');
      expect(c.goal, 'Produce 10 blocks');
      expect(c.task, 'Block Production');
      expect(c.reward, '500');
      expect(c.description, 'Produce blocks to earn points');
      expect(c.ctaLabel, 'Start');
      expect(c.enabled, true);
      expect(c.completed, false);
    });

    test('fromJson handles nullable fields', () {
      final c = ChallengeDto.fromJson({
        'id': 1,
        'category': 'social',
        'goal': 'Share',
        'task': 'Social',
        'reward': 100,
        'enabled': true,
        'completed': true,
      });
      expect(c.eventId, isNull);
      expect(c.eventName, isNull);
      expect(c.eventType, isNull);
      expect(c.subCategory, isNull);
      expect(c.description, isNull);
      expect(c.requirements, isNull);
      expect(c.rewardLogic, isNull);
      expect(c.ctaLabel, isNull);
      expect(c.ctaLink, isNull);
      expect(c.scheduleStart, isNull);
      expect(c.scheduleEnd, isNull);
      expect(c.completed, true);
    });
  });

  // -------------------------------------------------------------------------
  // Leaderboard types
  // -------------------------------------------------------------------------

  group('LeaderboardSeason', () {
    test('fromJson parses correctly', () {
      final s = LeaderboardSeason.fromJson({'id': 1, 'name': 'Season 1'});
      expect(s.id, 1);
      expect(s.name, 'Season 1');
    });
  });

  group('LeaderboardEvent', () {
    test('fromJson parses all fields including type', () {
      final e = LeaderboardEvent.fromJson({
        'id': 5,
        'name': 'Event 5',
        'type': 'regular',
        'starts_at': '2025-01-01',
        'ends_at': '2025-01-07',
        'is_active': true,
      });
      expect(e.id, 5);
      expect(e.name, 'Event 5');
      expect(e.type, 'regular');
      expect(e.startsAt, '2025-01-01');
      expect(e.endsAt, '2025-01-07');
      expect(e.isActive, true);
    });

    test('fromJson parses season type', () {
      final e = LeaderboardEvent.fromJson({
        'id': 10,
        'name': 'Season 1 Global Challenges',
        'type': 'season',
        'is_active': true,
      });
      expect(e.type, 'season');
    });

    test('fromJson handles null dates and type', () {
      final e = LeaderboardEvent.fromJson({
        'id': 1,
        'name': 'E1',
        'is_active': false,
      });
      expect(e.type, isNull);
      expect(e.startsAt, isNull);
      expect(e.endsAt, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // SeasonEventDto
  // -------------------------------------------------------------------------

  group('SeasonEventDto', () {
    test('fromJson parses event_id key with type', () {
      final e = SeasonEventDto.fromJson({
        'event_id': 5,
        'name': 'Event 5',
        'type': 'regular',
        'description': 'The fifth event',
        'starts_at': '2025-01-01',
        'ends_at': '2025-01-07',
        'is_active': true,
      });
      expect(e.id, 5);
      expect(e.name, 'Event 5');
      expect(e.type, 'regular');
      expect(e.description, 'The fifth event');
      expect(e.startsAt, '2025-01-01');
      expect(e.endsAt, '2025-01-07');
      expect(e.isActive, true);
    });

    test('fromJson parses season type', () {
      final e = SeasonEventDto.fromJson({
        'event_id': 10,
        'name': 'Season 1 Global Challenges',
        'type': 'season',
        'is_active': true,
      });
      expect(e.type, 'season');
    });

    test('fromJson falls back to id key (cache compat)', () {
      final e = SeasonEventDto.fromJson({
        'id': 5,
        'name': 'Event 5',
        'is_active': true,
      });
      expect(e.id, 5);
    });

    test('fromJson handles nullable fields', () {
      final e = SeasonEventDto.fromJson({
        'event_id': 1,
        'name': 'E1',
        'is_active': false,
      });
      expect(e.type, isNull);
      expect(e.description, isNull);
      expect(e.startsAt, isNull);
      expect(e.endsAt, isNull);
    });

    test('toJson round-trip preserves type', () {
      final json = {
        'event_id': 5,
        'name': 'Event 5',
        'type': 'season',
        'description': 'Desc',
        'starts_at': '2025-01-01',
        'ends_at': '2025-01-07',
        'is_active': true,
      };
      final e = SeasonEventDto.fromJson(json);
      final e2 = SeasonEventDto.fromJson(e.toJson());
      expect(e2.id, e.id);
      expect(e2.name, e.name);
      expect(e2.type, e.type);
      expect(e2.description, e.description);
      expect(e2.startsAt, e.startsAt);
      expect(e2.endsAt, e.endsAt);
      expect(e2.isActive, e.isActive);
    });
  });

  // -------------------------------------------------------------------------
  // SeasonDto
  // -------------------------------------------------------------------------

  group('SeasonDto', () {
    test('fromJson parses season_id key with nested events', () {
      final s = SeasonDto.fromJson({
        'season_id': 1,
        'name': 'Season 1',
        'description': 'First season',
        'starts_at': '2025-01-01',
        'ends_at': '2025-06-01',
        'is_active': true,
        'events': [
          {
            'event_id': 10,
            'name': 'Event 10',
            'is_active': true,
          },
          {
            'event_id': 11,
            'name': 'Event 11',
            'is_active': false,
          },
        ],
      });
      expect(s.id, 1);
      expect(s.name, 'Season 1');
      expect(s.description, 'First season');
      expect(s.startsAt, '2025-01-01');
      expect(s.endsAt, '2025-06-01');
      expect(s.isActive, true);
      expect(s.events, hasLength(2));
      expect(s.events.first.id, 10);
      expect(s.events.last.isActive, false);
    });

    test('fromJson falls back to id key (cache compat)', () {
      final s = SeasonDto.fromJson({
        'id': 2,
        'name': 'Season 2',
        'is_active': true,
      });
      expect(s.id, 2);
    });

    test('fromJson handles missing events and season_challenges', () {
      final s = SeasonDto.fromJson({
        'season_id': 2,
        'name': 'Season 2',
        'is_active': false,
      });
      expect(s.events, isEmpty);
      expect(s.seasonChallenges, isNull);
      expect(s.description, isNull);
      expect(s.startsAt, isNull);
    });

    test('fromJson parses season_challenges', () {
      final s = SeasonDto.fromJson({
        'season_id': 1,
        'name': 'Season 1',
        'is_active': true,
        'events': [],
        'season_challenges': [
          {
            'challenge_id': 42,
            'id': 42,
            'category': 'TECHNICAL',
            'goal': 'Produce Every Block',
            'task': 'Block Production',
            'reward': 6500,
            'enabled': true,
            'completed': false,
          },
        ],
      });
      expect(s.seasonChallenges, hasLength(1));
      expect(s.seasonChallenges!.first.id, 42);
      expect(s.seasonChallenges!.first.goal, 'Produce Every Block');
    });

    test('toJson round-trip', () {
      final json = {
        'season_id': 1,
        'name': 'Season 1',
        'description': 'Desc',
        'starts_at': '2025-01-01',
        'ends_at': '2025-06-01',
        'is_active': true,
        'events': [
          {
            'event_id': 10,
            'name': 'Event 10',
            'is_active': true,
          },
        ],
      };
      final s = SeasonDto.fromJson(json);
      final s2 = SeasonDto.fromJson(s.toJson());
      expect(s2.id, s.id);
      expect(s2.name, s.name);
      expect(s2.description, s.description);
      expect(s2.startsAt, s.startsAt);
      expect(s2.endsAt, s.endsAt);
      expect(s2.isActive, s.isActive);
      expect(s2.events.length, s.events.length);
      expect(s2.events.first.id, s.events.first.id);
    });
  });

  group('LeaderboardEntry', () {
    test('fromJson parses all fields with events_participated', () {
      final e = LeaderboardEntry.fromJson({
        'rank': 1,
        'participant_id': 42,
        'display_name': 'Alice',
        'total_points': 9999,
        'offchain_points': 500,
        'total_produced_blocks': 100,
        'vrf_total_won_slots': 50,
        'success_rate': 0.95,
        'events_participated': 3,
      });
      expect(e.rank, 1);
      expect(e.participantId, 42);
      expect(e.displayName, 'Alice');
      expect(e.totalPoints, 9999);
      expect(e.successRate, 0.95);
      expect(e.eventsParticipated, 3);
    });

    test('fromJson falls back to phases_participated (cache compat)', () {
      final e = LeaderboardEntry.fromJson({
        'rank': 1,
        'participant_id': 42,
        'total_points': 100,
        'offchain_points': 0,
        'total_produced_blocks': 0,
        'vrf_total_won_slots': 0,
        'success_rate': 0.0,
        'phases_participated': 3,
      });
      expect(e.eventsParticipated, 3);
    });

    test('fromJson handles null displayName', () {
      final e = LeaderboardEntry.fromJson({
        'rank': 2,
        'participant_id': 99,
        'total_points': 100,
        'offchain_points': 0,
        'total_produced_blocks': 0,
        'vrf_total_won_slots': 0,
        'success_rate': 0.0,
        'events_participated': 1,
      });
      expect(e.displayName, isNull);
    });
  });

  group('PaginationInfo', () {
    test('fromJson parses correctly', () {
      final p = PaginationInfo.fromJson({
        'page': 2,
        'per_page': 50,
        'total': 250,
        'total_pages': 5,
      });
      expect(p.page, 2);
      expect(p.perPage, 50);
      expect(p.total, 250);
      expect(p.totalPages, 5);
    });
  });

  group('LeaderboardResult', () {
    test('fromJson parses leaderboard key', () {
      final r = LeaderboardResult.fromJson({
        'season': {'id': 1, 'name': 'Season 1'},
        'events': [
          {
            'id': 1,
            'name': 'Event 1',
            'starts_at': '2025-01-01',
            'ends_at': '2025-01-07',
            'is_active': true,
          },
        ],
        'leaderboard': [
          {
            'rank': 1,
            'participant_id': 42,
            'display_name': 'Bob',
            'total_points': 5000,
            'offchain_points': 200,
            'total_produced_blocks': 50,
            'vrf_total_won_slots': 30,
            'success_rate': 0.9,
            'events_participated': 2,
          },
        ],
        'pagination': {
          'page': 1,
          'per_page': 50,
          'total': 1,
          'total_pages': 1,
        },
      });
      expect(r.season.id, 1);
      expect(r.events, hasLength(1));
      expect(r.entries, hasLength(1));
      expect(r.entries.first.displayName, 'Bob');
      expect(r.pagination.page, 1);
    });

    test('fromJson falls back to entries key (cache compat)', () {
      final r = LeaderboardResult.fromJson({
        'season': {'id': 1, 'name': 'S1'},
        'events': <dynamic>[],
        'entries': [
          {
            'rank': 1,
            'participant_id': 1,
            'total_points': 100,
            'offchain_points': 0,
            'total_produced_blocks': 0,
            'vrf_total_won_slots': 0,
            'success_rate': 0.0,
            'events_participated': 1,
          },
        ],
        'pagination': {
          'page': 1,
          'per_page': 50,
          'total': 1,
          'total_pages': 1,
        },
      });
      expect(r.entries, hasLength(1));
    });

    test('fromJson handles empty events and leaderboard', () {
      final r = LeaderboardResult.fromJson({
        'season': {'id': 1, 'name': 'S1'},
        'events': <dynamic>[],
        'leaderboard': <dynamic>[],
        'pagination': {
          'page': 1,
          'per_page': 50,
          'total': 0,
          'total_pages': 0,
        },
      });
      expect(r.events, isEmpty);
      expect(r.entries, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Breakdown types
  // -------------------------------------------------------------------------

  group('BreakdownActivity', () {
    test('fromJson parses activity_id key', () {
      final a = BreakdownActivity.fromJson({
        'activity_id': 1,
        'activity_type': 'block_produced',
        'points': 50,
        'description': 'Produced block #123',
        'activity_at': '2025-01-15T10:00:00Z',
        'challenge_id': 7,
      });
      expect(a.id, '1');
      expect(a.activityType, 'block_produced');
      expect(a.points, 50);
      expect(a.description, 'Produced block #123');
      expect(a.activityAt, '2025-01-15T10:00:00Z');
      expect(a.challengeId, 7);
    });

    test('fromJson falls back to id key (cache compat)', () {
      final a = BreakdownActivity.fromJson({
        'id': 2,
        'activity_type': 'bonus',
        'points': 10,
      });
      expect(a.id, '2');
    });

    test('fromJson parses string activity_id (extra points)', () {
      final a = BreakdownActivity.fromJson({
        'activity_id': 'extra-point-42',
        'activity_type': 'technical',
        'points': 125,
        'description': 'Manual recovery bonus',
        'activity_at': '2026-03-27T14:00:00Z',
        'challenge_id': 7,
        'activity_sub_category': 'PRODUCE_BLOCKS_CHALLENGE',
      });
      expect(a.id, 'extra-point-42');
      expect(a.activityType, 'technical');
      expect(a.points, 125);
      expect(a.challengeId, 7);
      expect(a.activitySubCategory, 'PRODUCE_BLOCKS_CHALLENGE');
    });

    test('fromJson handles nullable fields', () {
      final a = BreakdownActivity.fromJson({
        'activity_id': 2,
        'activity_type': 'bonus',
        'points': 10,
      });
      expect(a.description, isNull);
      expect(a.activityAt, isNull);
      expect(a.challengeId, isNull);
      expect(a.activitySubCategory, isNull);
    });
  });

  group('EventBreakdown', () {
    test('fromJson parses nested event object', () {
      final eb = EventBreakdown.fromJson({
        'event': {'id': 5, 'name': 'Event 5'},
        'total_points': 800,
        'offchain_points': 200,
        'rank': 3,
        'first_block_points': 100,
        'top_3_points': 50,
        'success_50_percent_points': 75,
        'produced_blocks': 20,
        'vrf_won_slots': 15,
        'success_rate': 0.85,
        'activities': [
          {
            'activity_id': 1,
            'activity_type': 'block_produced',
            'points': 50,
          },
        ],
      });
      expect(eb.eventId, 5);
      expect(eb.eventName, 'Event 5');
      expect(eb.totalPoints, 800);
      expect(eb.rank, 3);
      expect(eb.firstBlockPoints, 100);
      expect(eb.top3Points, 50);
      expect(eb.success50PercentPoints, 75);
      expect(eb.successRate, 0.85);
      expect(eb.activities, hasLength(1));
    });

    test('fromJson falls back to flat event_id/event_name (cache compat)', () {
      final eb = EventBreakdown.fromJson({
        'event_id': 5,
        'event_name': 'Event 5',
        'total_points': 800,
        'offchain_points': 200,
        'top3_points': 50,
      });
      expect(eb.eventId, 5);
      expect(eb.eventName, 'Event 5');
      expect(eb.top3Points, 50);
    });

    test('fromJson handles missing optional fields', () {
      final eb = EventBreakdown.fromJson({
        'event': {'id': 1, 'name': 'E1'},
        'total_points': 0,
        'offchain_points': 0,
      });
      expect(eb.rank, isNull);
      expect(eb.firstBlockPoints, isNull);
      expect(eb.activities, isEmpty);
    });
  });

  group('SeasonBreakdown', () {
    test('fromJson parses nested season object', () {
      final sb = SeasonBreakdown.fromJson({
        'season': {'id': 1, 'name': 'Season 1'},
        'total_points': 3000,
        'offchain_points': 500,
        'events': [
          {
            'event': {'id': 1, 'name': 'E1'},
            'total_points': 1500,
            'offchain_points': 250,
          },
          {
            'event': {'id': 2, 'name': 'E2'},
            'total_points': 1500,
            'offchain_points': 250,
          },
        ],
      });
      expect(sb.seasonId, 1);
      expect(sb.seasonName, 'Season 1');
      expect(sb.totalPoints, 3000);
      expect(sb.events, hasLength(2));
    });

    test('fromJson falls back to flat season_id/season_name (cache compat)',
        () {
      final sb = SeasonBreakdown.fromJson({
        'season_id': 1,
        'season_name': 'Season 1',
        'total_points': 3000,
        'offchain_points': 500,
      });
      expect(sb.seasonId, 1);
      expect(sb.seasonName, 'Season 1');
    });

    test('fromJson handles missing events', () {
      final sb = SeasonBreakdown.fromJson({
        'season': {'id': 1, 'name': 'S1'},
        'total_points': 0,
        'offchain_points': 0,
      });
      expect(sb.events, isEmpty);
    });
  });

  group('BreakdownResult', () {
    test('fromJson parses event scope with nested event object', () {
      final br = BreakdownResult.fromJson({
        'scope': 'event',
        'display_name': 'Alice',
        'total_points': 1000,
        'offchain_points': 200,
        'event': {'id': 5, 'name': 'Event 5'},
        'rank': 2,
        'first_block_points': 100,
        'top_3_points': 50,
        'success_50_percent_points': 75,
        'produced_blocks': 20,
        'vrf_won_slots': 15,
        'success_rate': 0.9,
        'activities': <dynamic>[],
      });
      expect(br.scope, 'event');
      expect(br.displayName, 'Alice');
      expect(br.totalPoints, 1000);
      expect(br.eventBreakdown, isNotNull);
      expect(br.eventBreakdown!.eventId, 5);
      expect(br.eventBreakdown!.eventName, 'Event 5');
      expect(br.eventBreakdown!.rank, 2);
      expect(br.eventBreakdown!.top3Points, 50);
      expect(br.seasonBreakdown, isNull);
    });

    test('fromJson parses season scope with nested season object', () {
      final br = BreakdownResult.fromJson({
        'scope': 'season',
        'display_name': 'Bob',
        'total_points': 5000,
        'offchain_points': 1000,
        'season': {'id': 1, 'name': 'Season 1'},
        'events': [
          {
            'event': {'id': 1, 'name': 'E1'},
            'total_points': 2500,
            'offchain_points': 500,
          },
        ],
      });
      expect(br.scope, 'season');
      expect(br.displayName, 'Bob');
      expect(br.seasonBreakdown, isNotNull);
      expect(br.seasonBreakdown!.seasonId, 1);
      expect(br.seasonBreakdown!.seasonName, 'Season 1');
      expect(br.seasonBreakdown!.events, hasLength(1));
      expect(br.eventBreakdown, isNull);
    });

    test('fromJson parses global scope with neither breakdown', () {
      final br = BreakdownResult.fromJson({
        'scope': 'global',
        'display_name': 'Charlie',
        'total_points': 99999,
        'offchain_points': 5000,
      });
      expect(br.scope, 'global');
      expect(br.eventBreakdown, isNull);
      expect(br.seasonBreakdown, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // toJson round-trip tests
  // -------------------------------------------------------------------------

  group('toJson round-trip', () {
    test('RankingResult (event scope)', () {
      final json = {
        'scope': 'event',
        'rank': 5,
        'total_points': 1200,
        'offchain_points': 300,
        'total_participants': 500,
        'event_id': 10,
        'event_name': 'Event Alpha',
      };
      final r = RankingResult.fromJson(json);
      final r2 = RankingResult.fromJson(r.toJson());
      expect(r2.scope, r.scope);
      expect(r2.rank, r.rank);
      expect(r2.totalPoints, r.totalPoints);
      expect(r2.offchainPoints, r.offchainPoints);
      expect(r2.totalParticipants, r.totalParticipants);
      expect(r2.eventId, r.eventId);
      expect(r2.eventName, r.eventName);
      expect(r2.seasonId, isNull);
    });

    test('RankingResult (season scope)', () {
      final json = {
        'scope': 'season',
        'rank': 3,
        'total_points': 5000,
        'offchain_points': 1000,
        'total_participants': 2000,
        'season_id': 1,
        'season_name': 'Season 1',
        'events_participated': 4,
        'total_produced_blocks': 25,
      };
      final r = RankingResult.fromJson(json);
      final r2 = RankingResult.fromJson(r.toJson());
      expect(r2.seasonId, r.seasonId);
      expect(r2.seasonName, r.seasonName);
      expect(r2.eventsParticipated, r.eventsParticipated);
      expect(r2.totalProducedBlocks, r.totalProducedBlocks);
    });

    test('ChallengeDto (all fields)', () {
      final json = {
        'id': 7,
        'event_id': 2,
        'event_name': 'Event 2',
        'event_type': 'season',
        'category': 'block_production',
        'sub_category': 'PRODUCE_BLOCKS_CHALLENGE',
        'goal': 'Produce 10 blocks',
        'task': 'Block Production',
        'reward': 500,
        'description': 'Produce blocks to earn points',
        'requirements': 'Node must be running',
        'reward_logic': 'Fixed per completion',
        'cta_label': 'Start',
        'cta_link': 'https://example.com',
        'schedule_start': '2025-01-01',
        'schedule_end': '2025-02-01',
        'enabled': true,
        'completed': false,
      };
      final c = ChallengeDto.fromJson(json);
      final c2 = ChallengeDto.fromJson(c.toJson());
      expect(c2.id, c.id);
      expect(c2.eventId, c.eventId);
      expect(c2.eventName, c.eventName);
      expect(c2.eventType, c.eventType);
      expect(c2.category, c.category);
      expect(c2.subCategory, c.subCategory);
      expect(c2.goal, c.goal);
      expect(c2.task, c.task);
      expect(c2.reward, c.reward);
      expect(c2.description, c.description);
      expect(c2.requirements, c.requirements);
      expect(c2.rewardLogic, c.rewardLogic);
      expect(c2.ctaLabel, c.ctaLabel);
      expect(c2.ctaLink, c.ctaLink);
      expect(c2.scheduleStart, c.scheduleStart);
      expect(c2.scheduleEnd, c.scheduleEnd);
      expect(c2.enabled, c.enabled);
      expect(c2.completed, c.completed);
    });

    test('ChallengeDto (nullable fields)', () {
      final json = {
        'id': 1,
        'category': 'social',
        'goal': 'Share',
        'task': 'Social',
        'reward': 100,
        'enabled': true,
        'completed': true,
      };
      final c = ChallengeDto.fromJson(json);
      final c2 = ChallengeDto.fromJson(c.toJson());
      expect(c2.eventId, isNull);
      expect(c2.subCategory, isNull);
      expect(c2.description, isNull);
      expect(c2.ctaLabel, isNull);
    });

    test('LeaderboardSeason', () {
      final s = LeaderboardSeason.fromJson({'id': 1, 'name': 'Season 1'});
      final s2 = LeaderboardSeason.fromJson(s.toJson());
      expect(s2.id, s.id);
      expect(s2.name, s.name);
    });

    test('LeaderboardEvent', () {
      final json = {
        'id': 5,
        'name': 'Event 5',
        'starts_at': '2025-01-01',
        'ends_at': '2025-01-07',
        'is_active': true,
      };
      final e = LeaderboardEvent.fromJson(json);
      final e2 = LeaderboardEvent.fromJson(e.toJson());
      expect(e2.id, e.id);
      expect(e2.name, e.name);
      expect(e2.startsAt, e.startsAt);
      expect(e2.endsAt, e.endsAt);
      expect(e2.isActive, e.isActive);
    });

    test('LeaderboardEntry', () {
      final json = {
        'rank': 1,
        'participant_id': 42,
        'display_name': 'Alice',
        'total_points': 9999,
        'offchain_points': 500,
        'total_produced_blocks': 100,
        'vrf_total_won_slots': 50,
        'success_rate': 0.95,
        'events_participated': 3,
      };
      final e = LeaderboardEntry.fromJson(json);
      final e2 = LeaderboardEntry.fromJson(e.toJson());
      expect(e2.rank, e.rank);
      expect(e2.participantId, e.participantId);
      expect(e2.displayName, e.displayName);
      expect(e2.totalPoints, e.totalPoints);
      expect(e2.successRate, e.successRate);
      expect(e2.eventsParticipated, e.eventsParticipated);
    });

    test('PaginationInfo', () {
      final json = {
        'page': 2,
        'per_page': 50,
        'total': 250,
        'total_pages': 5,
      };
      final p = PaginationInfo.fromJson(json);
      final p2 = PaginationInfo.fromJson(p.toJson());
      expect(p2.page, p.page);
      expect(p2.perPage, p.perPage);
      expect(p2.total, p.total);
      expect(p2.totalPages, p.totalPages);
    });

    test('LeaderboardResult', () {
      final json = {
        'season': {'id': 1, 'name': 'Season 1'},
        'events': [
          {
            'id': 1,
            'name': 'Event 1',
            'starts_at': '2025-01-01',
            'ends_at': '2025-01-07',
            'is_active': true,
          },
        ],
        'leaderboard': [
          {
            'rank': 1,
            'participant_id': 42,
            'display_name': 'Bob',
            'total_points': 5000,
            'offchain_points': 200,
            'total_produced_blocks': 50,
            'vrf_total_won_slots': 30,
            'success_rate': 0.9,
            'events_participated': 2,
          },
        ],
        'pagination': {
          'page': 1,
          'per_page': 50,
          'total': 1,
          'total_pages': 1,
        },
      };
      final r = LeaderboardResult.fromJson(json);
      final r2 = LeaderboardResult.fromJson(r.toJson());
      expect(r2.season.id, r.season.id);
      expect(r2.season.name, r.season.name);
      expect(r2.events.length, r.events.length);
      expect(r2.events.first.id, r.events.first.id);
      expect(r2.entries.length, r.entries.length);
      expect(r2.entries.first.displayName, r.entries.first.displayName);
      expect(r2.pagination.page, r.pagination.page);
    });

    test('BreakdownActivity', () {
      final json = {
        'activity_id': 1,
        'activity_type': 'block_produced',
        'points': 50,
        'description': 'Produced block #123',
        'activity_at': '2025-01-15T10:00:00Z',
        'challenge_id': 7,
        'activity_sub_category': 'PRODUCE_BLOCKS_CHALLENGE',
      };
      final a = BreakdownActivity.fromJson(json);
      final a2 = BreakdownActivity.fromJson(a.toJson());
      expect(a2.id, a.id);
      expect(a2.activityType, a.activityType);
      expect(a2.points, a.points);
      expect(a2.description, a.description);
      expect(a2.activityAt, a.activityAt);
      expect(a2.challengeId, a.challengeId);
      expect(a2.activitySubCategory, a.activitySubCategory);
    });

    test('BreakdownActivity round-trip with string id (extra points)', () {
      final json = {
        'activity_id': 'extra-point-42',
        'activity_type': 'technical',
        'points': 125,
        'description': 'Manual recovery bonus',
        'challenge_id': 7,
        'activity_sub_category': 'PRODUCE_BLOCKS_CHALLENGE',
      };
      final a = BreakdownActivity.fromJson(json);
      final a2 = BreakdownActivity.fromJson(a.toJson());
      expect(a2.id, 'extra-point-42');
      expect(a2.points, 125);
      expect(a2.challengeId, 7);
    });

    test('EventBreakdown', () {
      final json = {
        'event': {'id': 5, 'name': 'Event 5'},
        'total_points': 800,
        'offchain_points': 200,
        'rank': 3,
        'first_block_points': 100,
        'top_3_points': 50,
        'success_50_percent_points': 75,
        'produced_blocks': 20,
        'vrf_won_slots': 15,
        'success_rate': 0.85,
        'activities': [
          {
            'activity_id': 1,
            'activity_type': 'block_produced',
            'points': 50,
          },
        ],
      };
      final eb = EventBreakdown.fromJson(json);
      final eb2 = EventBreakdown.fromJson(eb.toJson());
      expect(eb2.eventId, eb.eventId);
      expect(eb2.eventName, eb.eventName);
      expect(eb2.totalPoints, eb.totalPoints);
      expect(eb2.rank, eb.rank);
      expect(eb2.firstBlockPoints, eb.firstBlockPoints);
      expect(eb2.top3Points, eb.top3Points);
      expect(eb2.success50PercentPoints, eb.success50PercentPoints);
      expect(eb2.successRate, eb.successRate);
      expect(eb2.activities.length, eb.activities.length);
      expect(eb2.activities.first.id, eb.activities.first.id);
    });

    test('SeasonBreakdown', () {
      final json = {
        'season': {'id': 1, 'name': 'Season 1'},
        'total_points': 3000,
        'offchain_points': 500,
        'events': [
          {
            'event': {'id': 1, 'name': 'E1'},
            'total_points': 1500,
            'offchain_points': 250,
          },
        ],
      };
      final sb = SeasonBreakdown.fromJson(json);
      final sb2 = SeasonBreakdown.fromJson(sb.toJson());
      expect(sb2.seasonId, sb.seasonId);
      expect(sb2.seasonName, sb.seasonName);
      expect(sb2.totalPoints, sb.totalPoints);
      expect(sb2.events.length, sb.events.length);
      expect(sb2.events.first.eventId, sb.events.first.eventId);
    });

    test('BreakdownResult (event scope)', () {
      final json = {
        'scope': 'event',
        'display_name': 'Alice',
        'total_points': 1000,
        'offchain_points': 200,
        'event': {'id': 5, 'name': 'Event 5'},
        'rank': 2,
        'first_block_points': 100,
        'top_3_points': 50,
        'success_50_percent_points': 75,
        'produced_blocks': 20,
        'vrf_won_slots': 15,
        'success_rate': 0.9,
        'activities': <dynamic>[],
      };
      final br = BreakdownResult.fromJson(json);
      final br2 = BreakdownResult.fromJson(br.toJson());
      expect(br2.scope, br.scope);
      expect(br2.displayName, br.displayName);
      expect(br2.totalPoints, br.totalPoints);
      expect(br2.eventBreakdown, isNotNull);
      expect(br2.eventBreakdown!.eventId, br.eventBreakdown!.eventId);
      expect(br2.eventBreakdown!.rank, br.eventBreakdown!.rank);
      expect(br2.seasonBreakdown, isNull);
    });

    test('BreakdownResult (season scope)', () {
      final json = {
        'scope': 'season',
        'display_name': 'Bob',
        'total_points': 5000,
        'offchain_points': 1000,
        'season': {'id': 1, 'name': 'Season 1'},
        'events': [
          {
            'event': {'id': 1, 'name': 'E1'},
            'total_points': 2500,
            'offchain_points': 500,
          },
        ],
      };
      final br = BreakdownResult.fromJson(json);
      final br2 = BreakdownResult.fromJson(br.toJson());
      expect(br2.scope, br.scope);
      expect(br2.displayName, br.displayName);
      expect(br2.seasonBreakdown, isNotNull);
      expect(br2.seasonBreakdown!.seasonId, br.seasonBreakdown!.seasonId);
      expect(br2.seasonBreakdown!.events.length,
          br.seasonBreakdown!.events.length);
      expect(br2.eventBreakdown, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // SeasonEventContext
  // -------------------------------------------------------------------------

  group('SeasonEventContext', () {
    test('defaults to all null', () {
      const ctx = SeasonEventContext();
      expect(ctx.seasonId, isNull);
      expect(ctx.seasonName, isNull);
      expect(ctx.eventId, isNull);
      expect(ctx.eventName, isNull);
    });

    test('copyWith replaces specified fields', () {
      const ctx = SeasonEventContext(seasonId: 1, seasonName: 'S1');
      final updated = ctx.copyWith(eventId: 5, eventName: 'E5');
      expect(updated.seasonId, 1);
      expect(updated.seasonName, 'S1');
      expect(updated.eventId, 5);
      expect(updated.eventName, 'E5');
    });
  });
}
