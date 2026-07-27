import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/features/activity/data/repositories/activity_api_client.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';

import '../../activity_test_fixtures.dart';

const _privateHeaders = {'cache-control': 'private, no-store'};

void main() {
  group('ActivityApiClient', () {
    test('exchanges an assertion without an authorization header', () async {
      const assertion = 'header.payload.signature-that-is-long-enough-for-v1';
      final client = ActivityApiClient(
        baseUrl: 'https://activity.example/',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(),
              'https://activity.example/v1/auth/exchanges');
          expect(request.headers['authorization'], isNull);
          expect(
            jsonDecode(request.body),
            {'assertion': assertion},
          );
          return http.Response(
            jsonEncode(validActivitySessionJson()),
            200,
            headers: _privateHeaders,
          );
        }),
      );
      addTearDown(client.dispose);

      final session = await client.exchangeAssertion(assertion);
      expect(session.accessToken, validActivityToken);
      expect(session.expiresAt, DateTime.utc(2030, 7, 27, 12));
    });

    test('sends exact feed, sync, read, and unread requests', () async {
      final paths = <String>[];
      final client = ActivityApiClient(
        baseUrl: 'https://activity.example',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          expect(
              request.headers['authorization'], 'Bearer $validActivityToken');
          switch (request.url.path) {
            case '/v1/me/activity':
              expect(request.url.queryParameters, {
                'before': 'feed-cursor',
                'limit': '25',
              });
              return http.Response(
                jsonEncode(
                  validFeedPageJson(
                    nextCursor: 'next-feed',
                    hasMore: true,
                  ),
                ),
                200,
                headers: _privateHeaders,
              );
            case '/v1/me/activity/sync':
              expect(request.url.queryParameters, {
                'after': 'sync-cursor',
                'limit': '50',
              });
              return http.Response(
                jsonEncode(validSyncPageJson(nextCursor: 'next-sync')),
                200,
                headers: _privateHeaders,
              );
            case '/v1/me/activity/read':
              expect(request.method, 'POST');
              expect(jsonDecode(request.body), {'inboxSequence': '1'});
              return http.Response('', 204);
            case '/v1/me/unread-count':
              return http.Response(
                jsonEncode({'unreadCount': 3}),
                200,
                headers: _privateHeaders,
              );
          }
          fail('Unexpected request ${request.url}');
        }),
      );
      addTearDown(client.dispose);

      final feed = await client.getFeed(
        accessToken: validActivityToken,
        before: 'feed-cursor',
        limit: 25,
      );
      final sync = await client.sync(
        accessToken: validActivityToken,
        after: 'sync-cursor',
        limit: 50,
      );
      await client.markRead(
        accessToken: validActivityToken,
        inboxSequence: '1',
      );
      final unread = await client.getUnreadCount(
        accessToken: validActivityToken,
      );

      expect(feed.nextCursor, 'next-feed');
      expect(sync.nextCursor, 'next-sync');
      expect(unread.value, 3);
      expect(paths, [
        '/v1/me/activity',
        '/v1/me/activity/sync',
        '/v1/me/activity/read',
        '/v1/me/unread-count',
      ]);
    });

    test('maps a closed API error without exposing credentials', () async {
      final client = ActivityApiClient(
        baseUrl: 'https://activity.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'invalid_assertion'}),
            400,
          ),
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.exchangeAssertion('header.payload.sensitive-assertion-value'),
        throwsA(
          isA<ActivityApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.code,
                'code',
                ActivityApiErrorCode.invalidAssertion,
              )
              .having(
                (error) => error.toString(),
                'safe description',
                isNot(contains('sensitive-assertion-value')),
              ),
        ),
      );
    });

    test('rejects malformed success and cache responses', () async {
      final malformed = ActivityApiClient(
        baseUrl: 'https://activity.example',
        httpClient: MockClient(
          (_) async => http.Response('{}', 200, headers: _privateHeaders),
        ),
      );
      addTearDown(malformed.dispose);
      await expectLater(
        malformed.getUnreadCount(accessToken: validActivityToken),
        throwsA(isA<ActivityProtocolException>()),
      );

      final cacheable = ActivityApiClient(
        baseUrl: 'https://activity.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'unreadCount': 0}),
            200,
          ),
        ),
      );
      addTearDown(cacheable.dispose);
      await expectLater(
        cacheable.getUnreadCount(accessToken: validActivityToken),
        throwsA(isA<ActivityProtocolException>()),
      );
    });

    test('blocks writes in view-only mode before network access', () async {
      var calls = 0;
      final client = ActivityApiClient(
        baseUrl: 'https://activity.example',
        writesEnabled: false,
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.exchangeAssertion('header.payload.signature'),
        throwsA(isA<ActivityWriteDisabledException>()),
      );
      await expectLater(
        client.markRead(
          accessToken: validActivityToken,
          inboxSequence: '1',
        ),
        throwsA(isA<ActivityWriteDisabledException>()),
      );
      expect(calls, 0);
    });

    test('accepts only an origin URL as the service base', () {
      expect(
        ActivityApiClient.normalizeBaseUrl('https://activity.example/'),
        'https://activity.example',
      );
      expect(
        () => ActivityApiClient.normalizeBaseUrl('http://activity.example'),
        throwsArgumentError,
      );
      expect(
        ActivityApiClient.normalizeBaseUrl('http://10.0.2.2:3000'),
        'http://10.0.2.2:3000',
      );
      expect(
        () => ActivityApiClient.normalizeBaseUrl(
          'https://activity.example/prefix',
        ),
        throwsArgumentError,
      );
      expect(
        () => ActivityApiClient.normalizeBaseUrl(
          'https://user:pass@activity.example',
        ),
        throwsArgumentError,
      );
    });

    test('rejects unauthorized-consumer on a non-401 status', () async {
      final client = ActivityApiClient(
        baseUrl: 'https://activity.example',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'error': 'unauthorized_consumer'}),
            500,
          ),
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        client.getFeed(accessToken: validActivityToken),
        throwsA(isA<ActivityProtocolException>()),
      );
    });
  });
}
