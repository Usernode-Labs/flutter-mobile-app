import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
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

http.StreamedResponse _streamedResponse(int statusCode, Object body) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

SessionAuthorityCredentialRequestSender _throughClient(http.Client client) => ({
      required credential,
      required request,
      required operationId,
    }) =>
        client.send(request);

void _publishAuthenticatedIdentity({
  IdentityPhase phase = IdentityPhase.ready,
}) {
  IdentitySnapshots.publish(Identity(
    epoch: 7,
    phase: phase,
    participantId: 1,
    accountId: 'account-1',
    address: 'address-1',
    sessionId: 'session-a',
    credentialRef: 'credential-a',
    credentialGeneration: 3,
  ));
}

void main() {
  setUp(IdentitySnapshots.reset);
  tearDown(IdentitySnapshots.reset);

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
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final result = await service.provisionWallet();

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
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.provisionWallet(),
        throwsA(isA<LeaderboardApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });

  // -------------------------------------------------------------------------
  // completeZkPassport
  // -------------------------------------------------------------------------

  group('completeZkPassport', () {
    test('returns true on 200', () async {
      final client = _mockClient(200, _envelope({'status': 'completed'}));
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      final ok = await service.completeZkPassport(
        challengeId: 7,
        walletAddress: 'ut1abc',
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
      final service =
          LeaderboardApiService(baseUrl: _baseUrl, httpClient: client);

      expect(
        () => service.completeZkPassport(
          challengeId: 7,
          walletAddress: 'ut1abc',
          sessionId: 'sess-1',
          nullifierHex: '0xdead',
        ),
        throwsA(isA<LeaderboardApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
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
        () => service.getBreakdown(),
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
        () => service.getBreakdown(),
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
        () => service.getBreakdown(),
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
        () => service.provisionWallet(),
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
  // Delegation
  // -------------------------------------------------------------------------

  group('delegation', () {
    test('reads delegation state for the requested wallet', () async {
      Uri? capturedUri;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(
          200,
          _envelope({
            'delegated': true,
            'delegated_since': '2026-08-10T12:00:00Z',
          }),
          onRequest: (request) => capturedUri = request.url,
        ),
      );

      final result = await service.getDelegation(walletAddress: 'ut1-wallet');

      expect(result?.delegated, isTrue);
      expect(result?.delegatedSince, '2026-08-10T12:00:00Z');
      expect(capturedUri?.path, '/api/v3/mobile/delegation');
      expect(capturedUri?.queryParameters['wallet_address'], 'ut1-wallet');
    });

    test('returns null when the wallet is unknown', () async {
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(404, {'error': 'Unknown account address.'}),
        maxGetRetries: 0,
      );

      expect(
        await service.getDelegation(walletAddress: 'ut1-missing'),
        isNull,
      );
    });

    test('sets delegation using session ownership rather than participant id',
        () async {
      http.Request? capturedRequest;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(
          200,
          _envelope({'delegated': true}),
          onRequest: (request) => capturedRequest = request,
        ),
        writesEnabled: true,
      );

      final result = await service.setDelegation(
        walletAddress: 'ut1-wallet',
        delegated: true,
      );

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(result.delegated, isTrue);
      expect(capturedRequest?.method, 'POST');
      expect(body, {'wallet_address': 'ut1-wallet', 'delegated': true});
      expect(body, isNot(contains('participant_id')));
    });

    test('view-only mode rejects delegation writes before transport', () async {
      var requests = 0;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((request) async {
          requests++;
          return http.Response('{}', 200);
        }),
        writesEnabled: false,
      );

      await expectLater(
        () => service.setDelegation(
          walletAddress: 'ut1-wallet',
          delegated: true,
        ),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(requests, 0);
    });
  });

  // -------------------------------------------------------------------------
  // Auth (session token) behavior
  // -------------------------------------------------------------------------

  group('auth', () {
    test('Ready GET submits its exact lease only to the authority sender',
        () async {
      _publishAuthenticatedIdentity();
      late AuthCredentialLease capturedCredential;
      late http.BaseRequest capturedRequest;
      late String capturedOperationId;
      var ordinaryClientUsed = false;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((request) async {
          ordinaryClientUsed = true;
          return http.Response('{}', 500);
        }),
        credentialRequestSender: ({
          required credential,
          required request,
          required operationId,
        }) async {
          capturedCredential = credential;
          capturedRequest = request;
          capturedOperationId = operationId;
          return _streamedResponse(
            200,
            _envelope({
              'scope': 'global',
              'display_name': 'X',
              'total_points': 0,
              'offchain_points': 0,
            }),
          );
        },
        tokenProvider: () async => 'sess-xyz',
      );

      await service.getBreakdown(seasonId: 1);

      expect(capturedCredential.epoch, 7);
      expect(capturedCredential.token, 'sess-xyz');
      expect(capturedCredential.sessionId, 'session-a');
      expect(capturedCredential.credentialRef, 'credential-a');
      expect(capturedCredential.credentialGeneration, 3);
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.path, '/api/v3/mobile/me/breakdown');
      expect(capturedRequest.headers['authorization'], 'Bearer sess-xyz');
      expect(capturedOperationId, 'leaderboard:get:/me/breakdown');
      expect(ordinaryClientUsed, isFalse);
    });

    test('reconciling wallet provision submits its exact activation lease',
        () async {
      _publishAuthenticatedIdentity(phase: IdentityPhase.reconciling);
      late AuthCredentialLease capturedCredential;
      late http.BaseRequest capturedRequest;
      late String capturedOperationId;
      var ordinaryClientUsed = false;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        writesEnabled: true,
        httpClient: MockClient((request) async {
          ordinaryClientUsed = true;
          return http.Response('{}', 500);
        }),
        credentialRequestSender: ({
          required credential,
          required request,
          required operationId,
        }) async {
          capturedCredential = credential;
          capturedRequest = request;
          capturedOperationId = operationId;
          return _streamedResponse(
            200,
            _envelope({
              'address': 'ut1pool0',
              'public_key': 'utpk1pool0',
              'secret_key': 'utsk1pool0',
              'season_id': 10,
              'newly_allocated': true,
            }),
          );
        },
        tokenProvider: () async => 'sess-xyz',
      );

      await service.provisionWallet();

      expect(capturedCredential.sessionId, 'session-a');
      expect(capturedCredential.credentialRef, 'credential-a');
      expect(capturedCredential.credentialGeneration, 3);
      expect(capturedCredential.token, 'sess-xyz');
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v3/mobile/wallet/provision');
      expect(capturedRequest.headers['authorization'], 'Bearer sess-xyz');
      expect(jsonDecode((capturedRequest as http.Request).body),
          <String, dynamic>{});
      expect(capturedOperationId, 'leaderboard:post:/wallet/provision');
      expect(ordinaryClientUsed, isFalse);
    });

    test(
        'authenticated request without a sender cannot use the ordinary client',
        () async {
      _publishAuthenticatedIdentity();
      var ordinaryClientUsed = false;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((request) async {
          ordinaryClientUsed = true;
          return http.Response(
            jsonEncode(_envelope({
              'scope': 'global',
              'display_name': 'X',
              'total_points': 0,
              'offchain_points': 0,
            })),
            200,
          );
        }),
        tokenProvider: () async => 'sess-xyz',
      );

      await expectLater(
        () => service.getBreakdown(seasonId: 1),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(ordinaryClientUsed, isFalse);
    });

    test('omits Authorization header when no token', () async {
      String? auth = 'unset';
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: _mockClient(
          200,
          _envelope({
            'scope': 'global',
            'display_name': 'X',
            'total_points': 0,
            'offchain_points': 0,
          }),
          onRequest: (r) => auth = r.headers['authorization'],
        ),
        tokenProvider: () async => null,
      );
      await service.getBreakdown(seasonId: 1);
      expect(auth, isNull);
    });

    test('401 invokes onUnauthorized then throws', () async {
      _publishAuthenticatedIdentity();
      AuthCredentialLease? rejectedCredential;
      final client = _mockClient(401, {'error': 'unauth'});
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: client,
        credentialRequestSender: _throughClient(client),
        tokenProvider: () async => 'sess-xyz',
        onUnauthorized: (credential) async {
          rejectedCredential = credential;
        },
        maxGetRetries: 0,
      );
      await expectLater(
        () => service.getBreakdown(seasonId: 1),
        throwsA(isA<LeaderboardApiException>()),
      );
      expect(rejectedCredential?.token, 'sess-xyz');
      expect(rejectedCredential?.sessionId, 'session-a');
      expect(rejectedCredential?.credentialRef, 'credential-a');
      expect(rejectedCredential?.credentialGeneration, 3);
    });

    test('retry re-admits the original immutable lease at the authority sink',
        () async {
      _publishAuthenticatedIdentity();
      var tokenReads = 0;
      final submittedCredentials = <AuthCredentialLease>[];
      final submittedRequests = <http.BaseRequest>[];
      var ordinaryClientUsed = false;
      final service = LeaderboardApiService(
        baseUrl: _baseUrl,
        httpClient: MockClient((request) async {
          ordinaryClientUsed = true;
          return http.Response('{}', 500);
        }),
        credentialRequestSender: ({
          required credential,
          required request,
          required operationId,
        }) async {
          submittedCredentials.add(credential);
          submittedRequests.add(request);
          if (submittedCredentials.length == 1) {
            return _streamedResponse(500, {'error': 'retry'});
          }
          throw const StaleAuthCredentialException();
        },
        tokenProvider: () async => tokenReads++ == 0 ? 'sess-old' : 'sess-new',
        maxGetRetries: 1,
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        () => service.getBreakdown(seasonId: 1),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(tokenReads, 1);
      expect(submittedCredentials, hasLength(2));
      expect(
        submittedCredentials.map((credential) => credential.token),
        everyElement('sess-old'),
      );
      expect(
        submittedRequests.map((request) => request.headers['authorization']),
        everyElement('Bearer sess-old'),
      );
      expect(ordinaryClientUsed, isFalse);
    });
  });
}
