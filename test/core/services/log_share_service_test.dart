import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/services/log_share_service.dart';

void main() {
  LogShareService service(MockClient client) =>
      LogShareService(baseUrl: 'https://api.example.com', httpClient: client);

  Future<LogShareOutcome> post(MockClient client) => service(client)
      .postLogs(participantId: 42, body: {'lines': []});

  test('hits /logs/{participant} and returns keepGoing on continue:true',
      () async {
    Uri? url;
    final outcome = await post(MockClient((req) async {
      url = req.url;
      return http.Response(jsonEncode({'continue': true}), 200);
    }));
    expect(url!.path, '/logs/42');
    expect(outcome, LogShareOutcome.keepGoing);
  });

  test('200 with continue:false stops', () async {
    expect(
      await post(MockClient(
          (_) async => http.Response(jsonEncode({'continue': false}), 200))),
      LogShareOutcome.stop,
    );
  });

  test('200 with an unparseable body stops (safe default)', () async {
    expect(
      await post(MockClient((_) async => http.Response('not-json', 200))),
      LogShareOutcome.stop,
    );
  });

  test('404 stops (bad participant id)', () async {
    expect(
      await post(MockClient((_) async => http.Response('', 404))),
      LogShareOutcome.stop,
    );
  });

  test('unexpected 4xx is a (non-retried) failure', () async {
    var calls = 0;
    final outcome = await post(MockClient((_) async {
      calls++;
      return http.Response('', 400);
    }));
    expect(outcome, LogShareOutcome.failed);
    expect(calls, 1); // not retried
  });

  test('5xx retries then succeeds', () async {
    var calls = 0;
    final outcome = await post(MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('', 503);
      return http.Response(jsonEncode({'continue': true}), 200);
    }));
    expect(outcome, LogShareOutcome.keepGoing);
    expect(calls, 2);
  });

  test('persistent 5xx exhausts retries and fails', () async {
    var calls = 0;
    final outcome = await post(MockClient((_) async {
      calls++;
      return http.Response('', 500);
    }));
    expect(outcome, LogShareOutcome.failed);
    expect(calls, 3);
  });

  test('network exception exhausts retries and fails', () async {
    var calls = 0;
    final outcome = await post(MockClient((_) async {
      calls++;
      throw Exception('offline');
    }));
    expect(outcome, LogShareOutcome.failed);
    expect(calls, 3);
    service(MockClient((_) async => http.Response('', 200))).dispose();
  });
}
