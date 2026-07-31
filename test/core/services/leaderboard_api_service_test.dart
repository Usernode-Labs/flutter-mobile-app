import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

const _baseUrl = 'https://test.example.com/api/v3/mobile';

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

void _publishAuthenticatedIdentity() {
  IdentitySnapshots.publish(const Identity(
    epoch: 7,
    phase: IdentityPhase.ready,
    participantId: 1,
    accountId: 'account-1',
    address: 'address-1',
  ));
}

void main() {
  setUp(IdentitySnapshots.reset);
  tearDown(IdentitySnapshots.reset);

  // -------------------------------------------------------------------------
  // register
  // -------------------------------------------------------------------------

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
            'total_tokens': 1250,
            'offchain_points': 300,
            'total_participants': 500,
            'event_id': 10,
            'event_name': 'Event Alpha',
          }));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.getRanking();

      expect(result.scope, 'event');
      expect(result.rank, 5);
      expect(result.totalTokens, 1250);
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

      await service.getRanking(seasonId: 1, eventId: 5);

      expect(capturedUri, isNotNull);
      expect(capturedUri!.path, '/api/v3/mobile/me/ranking');
      expect(capturedUri!.queryParameters.containsKey('participant_id'), false);
      expect(capturedUri!.queryParameters.containsKey('season_id'), false);
      expect(capturedUri!.queryParameters['event_id'], '5');
    });

    test('throws on 404', () async {
      final client = _mockClient(404, {'error': 'Participant not found'});
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.getRanking(),
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

      expect(capturedUri!.path, '/api/v3/mobile/challenges');
      expect(capturedUri!.queryParameters.containsKey('season_id'), false);
      expect(capturedUri!.queryParameters['event_id'], '3');
      expect(capturedUri!.queryParameters['active_only'], '1');
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

      expect(capturedUri!.path, '/api/v3/mobile/leaderboard');
      expect(capturedUri!.queryParameters['season_id'], '1');
      expect(capturedUri!.queryParameters['event_id'], '2');
      expect(capturedUri!.queryParameters['page'], '3');
      expect(capturedUri!.queryParameters['per_page'], '25');
    });
  });

  group('getEventPoints pagination', () {
    Map<String, dynamic> pageEnvelope({
      required int page,
      required int totalPages,
      required List<Map<String, dynamic>> points,
      int totalParticipants = 3,
    }) =>
        {
          'success': true,
          'data': {
            'season_event_id': 5,
            'event_name': 'Event 5',
            'event_total_points': 1200,
            'user_total_points': 700,
            'total_points_per_user': points,
            'total_participants': totalParticipants,
          },
          'meta': {
            'current_page': page,
            'per_page': 100,
            'total': totalParticipants,
            'total_pages': totalPages,
          },
        };

    setUp(_publishAuthenticatedIdentity);

    test('fetches every page under one credential and merges participants',
        () async {
      final requestedPages = <String?>[];
      final client = MockClient((request) async {
        requestedPages.add(request.url.queryParameters['page']);
        expect(request.url.queryParameters['per_page'], '100');
        expect(request.headers['authorization'], 'Bearer token-1');
        final page = int.parse(request.url.queryParameters['page']!);
        return http.Response(
          jsonEncode(pageEnvelope(
            page: page,
            totalPages: 2,
            points: page == 1
                ? [
                    {'user_id': 1, 'total_points': 700},
                    {'user_id': 2, 'total_points': 300},
                  ]
                : [
                    {'user_id': 3, 'total_points': 200},
                  ],
          )),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      final result = await service.getEventPoints(eventId: 5);

      expect(requestedPages, ['1', '2']);
      expect(
        result.totalPointsPerUser.map((points) => points.participantId),
        [1, 2, 3],
      );
    });

    test('accepts an empty result with zero total pages', () async {
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: _mockClient(
          200,
          pageEnvelope(
            page: 1,
            totalPages: 0,
            points: const [],
            totalParticipants: 0,
          ),
        ),
      );

      final result = await service.getEventPoints(eventId: 5);

      expect(result.totalPointsPerUser, isEmpty);
    });

    test('fails the logical read when a later page fails', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            jsonEncode(pageEnvelope(
              page: 1,
              totalPages: 2,
              points: const [],
            )),
            200,
          );
        }
        return http.Response(jsonEncode({'error': 'failed'}), 500);
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
        maxGetRetries: 0,
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(requests, 2);
    });

    test('rejects malformed pagination metadata', () async {
      final envelope = pageEnvelope(page: 1, totalPages: 1, points: const []);
      envelope['meta'] = {'current_page': 2, 'total_pages': 'invalid'};
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: _mockClient(200, envelope),
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<LeaderboardApiException>()),
      );
    });

    test('rejects pagination metadata without the requested page size',
        () async {
      final envelope = pageEnvelope(page: 1, totalPages: 1, points: const []);
      (envelope['meta'] as Map<String, dynamic>).remove('per_page');
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: _mockClient(200, envelope),
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<LeaderboardApiException>()),
      );
    });

    test('restarts the whole read once when pagination drifts', () async {
      var requests = 0;
      final requestedPages = <String?>[];
      final client = MockClient((request) async {
        requests++;
        requestedPages.add(request.url.queryParameters['page']);
        final page = int.parse(request.url.queryParameters['page']!);
        final firstAttempt = requests <= 2;
        return http.Response(
          jsonEncode(pageEnvelope(
            page: page,
            totalPages: firstAttempt && page == 2 ? 3 : 2,
            totalParticipants: 2,
            points: [
              {'user_id': page, 'total_points': 10},
            ],
          )),
          200,
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: client,
        maxGetRetries: 0,
      );

      final result = await service.getEventPoints(eventId: 5);

      expect(requestedPages, ['1', '2', '1', '2']);
      expect(
        result.totalPointsPerUser.map((points) => points.participantId),
        [1, 2],
      );
    });

    test('retries when rank movement duplicates a page-boundary participant',
        () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final page = int.parse(request.url.queryParameters['page']!);
        final firstAttempt = requests <= 2;
        final ids = switch ((firstAttempt, page)) {
          (true, 1) => [for (var id = 1; id <= 100; id++) id],
          (true, 2) => [100],
          (false, 1) => [101, for (var id = 1; id < 100; id++) id],
          _ => [100],
        };
        return http.Response(
          jsonEncode(pageEnvelope(
            page: page,
            totalPages: 2,
            totalParticipants: 101,
            points: [
              for (final id in ids) {'user_id': id, 'total_points': 1000 - id},
            ],
          )),
          200,
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: client,
        maxGetRetries: 0,
      );

      final result = await service.getEventPoints(eventId: 5);

      expect(requests, 4);
      expect(result.totalPointsPerUser, hasLength(101));
      expect(
        result.totalPointsPerUser.map((points) => points.participantId),
        containsAll([100, 101]),
      );
    });

    test('bounds retries when page-boundary drift does not settle', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final page = int.parse(request.url.queryParameters['page']!);
        final ids = page == 1 ? [for (var id = 1; id <= 100; id++) id] : [100];
        return http.Response(
          jsonEncode(pageEnvelope(
            page: page,
            totalPages: 2,
            totalParticipants: 101,
            points: [
              for (final id in ids) {'user_id': id, 'total_points': 1000 - id},
            ],
          )),
          200,
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'token-1',
        httpClient: client,
        maxGetRetries: 0,
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(requests, 4);
    });

    test('does not request page two after identity replacement', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        IdentitySnapshots.publish(const Identity(
          epoch: 8,
          phase: IdentityPhase.ready,
          participantId: 2,
          accountId: 'account-2',
          address: 'address-2',
        ));
        return http.Response(
          jsonEncode(pageEnvelope(
            page: 1,
            totalPages: 2,
            points: const [],
          )),
          200,
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(requests, 1);
    });

    test('does not request page two with a replacement token', () async {
      var token = 'token-1';
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        token = 'token-2';
        return http.Response(
          jsonEncode(pageEnvelope(
            page: 1,
            totalPages: 2,
            points: const [],
          )),
          200,
        );
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => token,
      );

      await expectLater(
        service.getEventPoints(eventId: 5),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(requests, 1);
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

      final result = await service.getBreakdown();

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

      await service.getBreakdown(seasonId: 1, eventId: 3);

      expect(capturedUri!.path, '/api/v3/mobile/me/breakdown');
      expect(capturedUri!.queryParameters.containsKey('participant_id'), false);
      expect(capturedUri!.queryParameters.containsKey('season_id'), false);
      expect(capturedUri!.queryParameters['event_id'], '3');
    });
  });

  // -------------------------------------------------------------------------
  // provisionWallet
  // -------------------------------------------------------------------------

  group('provisionWallet', () {
    setUp(_publishAuthenticatedIdentity);

    test('returns WalletProvisionResult on 200', () async {
      http.Request? captured;
      final client = _mockClient(
        200,
        _envelope({
          'address': 'ut1pool0',
          'public_key': 'utpk1pool0',
          'secret_key': 'utsk1pool0',
          'season_id': 10,
          'season_event_id': null,
          'newly_allocated': true,
        }),
        onRequest: (r) => captured = r,
      );
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      final result = await service.provisionWallet(
        authority: IdentityLease.capture(IdentitySnapshots.current),
      );

      expect(captured!.url.path, endsWith('/wallet/provision'));
      expect(result.address, 'ut1pool0');
      expect(result.publicKey, 'utpk1pool0');
      expect(result.secretKey, 'utsk1pool0');
      expect(result.seasonId, 10);
      expect(result.seasonEventId, isNull);
      expect(result.newlyAllocated, true);
    });

    test('throws on 409 (season account pool exhausted)', () async {
      final client = _mockClient(409, {
        'success': false,
        'error': 'No on-chain accounts are available for the current season.',
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      expect(
        () => service.provisionWallet(
          authority: IdentityLease.capture(IdentitySnapshots.current),
        ),
        throwsA(isA<LeaderboardApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('does not provision with a replacement identity credential', () async {
      final token = Completer<String?>();
      var requests = 0;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        writesEnabled: true,
        tokenProvider: () => token.future,
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final authority = IdentityLease.capture(IdentitySnapshots.current);

      final provision = service.provisionWallet(authority: authority);
      await pumpEventQueue();
      IdentitySnapshots.publish(const Identity(
        epoch: 8,
        phase: IdentityPhase.ready,
        participantId: 2,
        accountId: 'account-2',
        address: 'address-2',
      ));
      token.complete('replacement-token');

      await expectLater(
        provision,
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(requests, 0);
    });
  });

  // -------------------------------------------------------------------------
  // completeZkPassport
  // -------------------------------------------------------------------------

  group('completeZkPassport', () {
    setUp(_publishAuthenticatedIdentity);

    test('returns true on 200', () async {
      final client = _mockClient(200, _envelope({'status': 'completed'}));
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      final ok = await service.completeZkPassport(
        authority: AuthenticatedUserLease.capture(
          IdentitySnapshots.current,
        )!,
        challengeId: 7,
        walletAddress: 'address-1',
        sessionId: 'sess-1',
        nullifierHex: '0xdead',
      );

      expect(ok, true);
    });

    test('throws on 409 (v4 real rejection, not duplicate-success)', () async {
      final client = _mockClient(409, {
        'success': false,
        'error': 'Challenge is not accepting completions.',
      });
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        tokenProvider: () async => 'token-1',
      );

      expect(
        () => service.completeZkPassport(
          authority: AuthenticatedUserLease.capture(
            IdentitySnapshots.current,
          )!,
          challengeId: 7,
          walletAddress: 'address-1',
          sessionId: 'sess-1',
          nullifierHex: '0xdead',
        ),
        throwsA(isA<LeaderboardApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('does not POST with a superseded authenticated authority', () async {
      var requests = 0;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        tokenProvider: () async => 'replacement-token',
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final authority = AuthenticatedUserLease.capture(
        IdentitySnapshots.current,
      )!;
      IdentitySnapshots.publish(const Identity(
        epoch: 8,
        phase: IdentityPhase.ready,
        participantId: 2,
        accountId: 'account-2',
        address: 'address-2',
      ));

      await expectLater(
        service.completeZkPassport(
          authority: authority,
          challengeId: 7,
          walletAddress: 'address-1',
          sessionId: 'sess-1',
          nullifierHex: '0xdead',
        ),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(requests, 0);
    });

    test('does not POST a wallet outside the authenticated account scope',
        () async {
      var requests = 0;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        service.completeZkPassport(
          authority: AuthenticatedUserLease.capture(
            IdentitySnapshots.current,
          )!,
          challengeId: 7,
          walletAddress: 'address-from-another-account',
          sessionId: 'sess-1',
          nullifierHex: '0xdead',
        ),
        throwsArgumentError,
      );
      expect(requests, 0);
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
        () => service.getRanking(),
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
        () => service.getRanking(),
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
        () => service.getRanking(),
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

      final result = await service.getBreakdown();

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

      final result = await service.getBreakdown();

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
        () => service.getBreakdown(),
        throwsA(
          isA<LeaderboardApiException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('does NOT retry a POST (write) on a transient 503', () async {
      _publishAuthenticatedIdentity();
      final authority = AuthenticatedUserLease.capture(
        IdentitySnapshots.current,
      )!;
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
        tokenProvider: () async => 'token-1',
      );

      await expectLater(
        () => service.postTermsConsent(
          termsVersionId: 1,
          appVersion: '1.0.0',
          authority: authority,
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
        () => service.getBreakdown(),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(attempts, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Auth (session token) behavior
  // -------------------------------------------------------------------------

  group('auth', () {
    test('attaches Bearer token from tokenProvider on GET', () async {
      _publishAuthenticatedIdentity();
      String? auth;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(
          200,
          _envelope({
            'scope': 'global',
            'rank': 1,
            'total_points': 0,
            'offchain_points': 0,
            'total_participants': 0,
          }),
          onRequest: (r) => auth = r.headers['authorization'],
        ),
        tokenProvider: () async => 'sess-xyz',
      );
      await service.getRanking(seasonId: 1);
      expect(auth, 'Bearer sess-xyz');
    });

    test('omits Authorization header when no token', () async {
      String? auth = 'unset';
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(
          200,
          _envelope({
            'scope': 'global',
            'rank': 1,
            'total_points': 0,
            'offchain_points': 0,
            'total_participants': 0,
          }),
          onRequest: (r) => auth = r.headers['authorization'],
        ),
        tokenProvider: () async => null,
      );
      await service.getRanking(seasonId: 1);
      expect(auth, isNull);
    });

    test('401 invokes onUnauthorized then throws', () async {
      _publishAuthenticatedIdentity();
      AuthCredentialLease? rejectedCredential;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(401, {'error': 'unauth'}),
        tokenProvider: () async => 'sess-xyz',
        onUnauthorized: (credential) async {
          rejectedCredential = credential;
        },
        maxGetRetries: 0,
      );
      await expectLater(
        () => service.getRanking(seasonId: 1),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(rejectedCredential?.token, 'sess-xyz');
    });

    test('token replacement during retry backoff cancels the retry', () async {
      _publishAuthenticatedIdentity();
      var token = 'sess-old';
      var requests = 0;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((request) async {
          requests++;
          token = 'sess-new';
          return http.Response(jsonEncode({'error': 'retry'}), 500);
        }),
        tokenProvider: () async => token,
        maxGetRetries: 1,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        () => service.getRanking(seasonId: 1),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(requests, 1);
    });
  });
}
