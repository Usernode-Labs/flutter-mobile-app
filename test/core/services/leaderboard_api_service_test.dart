import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

const _baseUrl = 'https://test.example.com/api/v2/mobile';

/// Creates a [MockClient] that returns a fixed status code and JSON body.
MockClient _mockClient(
  int statusCode,
  Object body, {
  void Function(http.Request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request);
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Wraps [data] in the standard `{ success: true, data: ... }` envelope.
Map<String, dynamic> _envelope(Object data) => {
      'success': true,
      'data': data,
    };

void main() {
  // -------------------------------------------------------------------------
  // register
  // -------------------------------------------------------------------------

  group('register', () {
    test('returns RegistrationV2Result on 200 success', () async {
      final client = _mockClient(
          200,
          _envelope({
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
          }));
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: true,
      );

      final result = await service.register(
        registrationCode: 'code-123',
        identifier: 'test-id',
      );

      expect(result.participantId, 42);
      expect(result.identityUid, 'uid-abc');
      expect(result.tier, 'gold');
      expect(result.event?.id, 2);
    });

    test('sends POST with correct body', () async {
      http.Request? captured;
      final client = _mockClient(
        200,
        _envelope({
          'participant_id': 1,
          'identity_uid': 'u',
          'public_key': 'p',
          'secret_key': 's',
          'address': 'a',
          'tier': 't',
        }),
        onRequest: (r) => captured = r,
      );
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: true,
      );

      await service.register(
        registrationCode: 'my-code',
        identifier: 'my-id',
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v2/mobile/register');

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['registration_code'], 'my-code');
      expect(body['identifier'], 'my-id');
    });

    test('throws LeaderboardApiException on 400', () async {
      final client = _mockClient(400, {'error': 'Bad request'});
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: true,
      );

      expect(
        () => service.register(
          registrationCode: 'bad',
          identifier: 'test',
        ),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Bad request'),
        ),
      );
    });

    test('throws LeaderboardApiException on 409 conflict', () async {
      final client = _mockClient(409, {'error': 'Already registered'});
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: true,
      );

      expect(
        () => service.register(
          registrationCode: 'dup',
          identifier: 'test',
        ),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', 'Already registered'),
        ),
      );
    });

    test('fails fast in view-only mode before sending request', () async {
      var requestSent = false;
      final client = MockClient((request) async {
        requestSent = true;
        return http.Response('{}', 200);
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: false,
      );

      expect(
        () => service.register(
          registrationCode: 'code-123',
          identifier: 'test-id',
        ),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
      expect(requestSent, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // getRanking
  // -------------------------------------------------------------------------

  group('getRanking', () {
    test('returns RankingResult on 200', () async {
      final client = _mockClient(
          200,
          _envelope({
            'scope': 'event',
            'rank': 5,
            'total_points': 1200,
            'offchain_points': 300,
            'total_participants': 500,
            'event_id': 10,
            'event_name': 'Event Alpha',
          }));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getRanking(participantId: 42);

      expect(result.scope, 'event');
      expect(result.rank, 5);
      expect(result.eventId, 10);
    });

    test('sends correct URL and query params', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope({
          'scope': 'event',
          'rank': 1,
          'total_points': 0,
          'offchain_points': 0,
          'total_participants': 0,
        }),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getRanking(
        participantId: 42,
        seasonId: 1,
        eventId: 5,
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/api/v2/mobile/me/ranking');
      expect(capturedUri!.queryParameters['participant_id'], '42');
      expect(capturedUri!.queryParameters['season_id'], '1');
      expect(capturedUri!.queryParameters['event_id'], '5');
    });

    test('throws on 404', () async {
      final client = _mockClient(404, {'error': 'Participant not found'});
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getRanking(participantId: 999),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getChallenges
  // -------------------------------------------------------------------------

  group('getChallenges', () {
    test('returns list of ChallengeDto on 200', () async {
      final client = _mockClient(
          200,
          _envelope([
            {
              'id': 1,
              'category': 'social',
              'goal': 'Share',
              'task': 'Social',
              'reward': 100,
              'enabled': true,
              'completed': false,
            },
            {
              'id': 2,
              'category': 'block_production',
              'goal': 'Produce 5 blocks',
              'task': 'Blocks',
              'reward': 500,
              'enabled': true,
              'completed': true,
            },
          ]));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getChallenges();

      expect(result, hasLength(2));
      expect(result[0].id, 1);
      expect(result[0].category, 'social');
      expect(result[1].completed, true);
    });

    test('sends correct query params', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope(<dynamic>[]),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getChallenges(
        seasonId: 1,
        eventId: 3,
        activeOnly: true,
      );

      expect(capturedUri!.path, '/api/v2/mobile/challenges');
      expect(capturedUri!.queryParameters['season_id'], '1');
      expect(capturedUri!.queryParameters['event_id'], '3');
      expect(capturedUri!.queryParameters['active_only'], 'true');
    });

    test('sends only_scheduled query param when true', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope(<dynamic>[]),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getChallenges(
        seasonId: 1,
        onlyScheduled: true,
      );

      expect(capturedUri!.queryParameters['only_scheduled'], '1');
    });

    test('omits only_scheduled when false or null', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope(<dynamic>[]),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getChallenges(seasonId: 1);
      expect(capturedUri!.queryParameters.containsKey('only_scheduled'), false);
    });

    test('returns empty list for empty data', () async {
      final client = _mockClient(200, _envelope(<dynamic>[]));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getChallenges();
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // getLeaderboard
  // -------------------------------------------------------------------------

  group('getLeaderboard', () {
    test('returns LeaderboardResult on 200', () async {
      final client = _mockClient(
          200,
          _envelope({
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
                'display_name': 'Alice',
                'total_points': 9999,
                'offchain_points': 500,
                'total_produced_blocks': 100,
                'vrf_total_won_slots': 50,
                'success_rate': 0.95,
                'events_participated': 3,
              },
            ],
            'pagination': {
              'page': 1,
              'per_page': 50,
              'total': 1,
              'total_pages': 1,
            },
          }));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getLeaderboard(seasonId: 1);

      expect(result.season.name, 'Season 1');
      expect(result.events, hasLength(1));
      expect(result.entries, hasLength(1));
      expect(result.entries.first.displayName, 'Alice');
      expect(result.pagination.totalPages, 1);
    });

    test('sends correct query params with pagination', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope({
          'season': {'id': 1, 'name': 'S1'},
          'events': <dynamic>[],
          'leaderboard': <dynamic>[],
          'pagination': {
            'page': 3,
            'per_page': 25,
            'total': 100,
            'total_pages': 4,
          },
        }),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getLeaderboard(
        seasonId: 1,
        eventId: 2,
        page: 3,
        perPage: 25,
      );

      expect(capturedUri!.path, '/api/v2/mobile/leaderboard');
      expect(capturedUri!.queryParameters['season_id'], '1');
      expect(capturedUri!.queryParameters['event_id'], '2');
      expect(capturedUri!.queryParameters['page'], '3');
      expect(capturedUri!.queryParameters['per_page'], '25');
    });
  });

  // -------------------------------------------------------------------------
  // getBreakdown
  // -------------------------------------------------------------------------

  group('getBreakdown', () {
    test('returns BreakdownResult for event scope on 200', () async {
      final client = _mockClient(
          200,
          _envelope({
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
            'activities': [
              {
                'activity_id': 1,
                'activity_type': 'block_produced',
                'points': 50,
                'description': 'Block #123',
                'activity_at': '2025-01-15T10:00:00Z',
              },
            ],
          }));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getBreakdown(participantId: 42);

      expect(result.scope, 'event');
      expect(result.displayName, 'Alice');
      expect(result.eventBreakdown, isNotNull);
      expect(result.eventBreakdown!.eventId, 5);
      expect(result.eventBreakdown!.activities, hasLength(1));
      expect(result.seasonBreakdown, isNull);
    });

    test('sends correct query params', () async {
      Uri? capturedUri;
      final client = _mockClient(
        200,
        _envelope({
          'scope': 'global',
          'display_name': 'X',
          'total_points': 0,
          'offchain_points': 0,
        }),
        onRequest: (r) => capturedUri = r.url,
      );
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      await service.getBreakdown(
        participantId: 42,
        seasonId: 1,
        eventId: 3,
      );

      expect(capturedUri!.path, '/api/v2/mobile/me/breakdown');
      expect(capturedUri!.queryParameters['participant_id'], '42');
      expect(capturedUri!.queryParameters['season_id'], '1');
      expect(capturedUri!.queryParameters['event_id'], '3');
    });
  });

  // -------------------------------------------------------------------------
  // Error handling
  // -------------------------------------------------------------------------

  group('error handling', () {
    test('throws on 500 with fallback message', () async {
      final client = _mockClient(500, 'Internal server error');
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getRanking(participantId: 1),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Request failed (HTTP 500)')),
        ),
      );
    });

    test('throws on 200 with success:false', () async {
      final client = _mockClient(200, {
        'success': false,
        'error': 'Something went wrong',
      });
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getRanking(participantId: 1),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.message, 'message', 'Something went wrong'),
        ),
      );
    });

    test('propagates timeout errors', () async {
      final client = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getRanking(participantId: 1),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('uses error field from JSON response body', () async {
      final client = _mockClient(403, {'error': 'Season inactive'});
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getChallenges(),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.message, 'message', 'Season inactive'),
        ),
      );
    });

    test('falls back to default message when body is not JSON', () async {
      final client = MockClient((request) async {
        return http.Response('not json', 404);
      });
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getChallenges(),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.message, 'message', 'Resource not found.'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Retry (GET-only)
  // -------------------------------------------------------------------------

  group('retry', () {
    Map<String, dynamic> breakdownEnvelope() => _envelope({
          'scope': 'global',
          'display_name': 'Alice',
          'total_points': 1000,
          'offchain_points': 200,
        });

    test('retries a GET after a transient 503 and then succeeds', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            jsonEncode({'error': 'Service unavailable'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode(breakdownEnvelope()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        retryBaseDelay: Duration.zero,
      );

      final result = await service.getBreakdown(participantId: 42);

      expect(attempts, 2);
      expect(result.totalPoints, 1000);
    });

    test('retries a GET after a transient connection error', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          throw TimeoutException('Request timed out');
        }
        return http.Response(
          jsonEncode(breakdownEnvelope()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        retryBaseDelay: Duration.zero,
      );

      final result = await service.getBreakdown(participantId: 42);

      expect(attempts, 2);
      expect(result.totalPoints, 1000);
    });

    test('gives up after exhausting retries on persistent 500', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        return http.Response('Internal server error', 500);
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        maxGetRetries: 2,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        () => service.getBreakdown(participantId: 42),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('does NOT retry a POST (write) on a transient 503', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode({'error': 'Service unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        writesEnabled: true,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        () => service.register(
          registrationCode: 'code',
          identifier: 'id',
        ),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(attempts, 1);
    });

    test('does NOT retry a non-transient 4xx', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode({'error': 'Participant not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        () => service.getBreakdown(participantId: 999),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(attempts, 1);
    });
  });
}
