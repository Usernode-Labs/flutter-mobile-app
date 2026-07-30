import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/services/log_share_service.dart';

const _base = 'https://test.example.com/api/v3/mobile';

LogShareService _service(
  MockClient client, {
  Future<String?> Function()? tokenProvider,
}) =>
    LogShareService(
      baseUrl: _base,
      httpClient: client,
      tokenProvider: tokenProvider ?? () async => 'sess-1',
    );

void main() {
  test('POSTs to /logs (no participant segment) with Bearer token', () async {
    Uri? url;
    String? auth;
    final service = _service(MockClient((req) async {
      url = req.url;
      auth = req.headers['authorization'];
      return http.Response(jsonEncode({'continue': true}), 200,
          headers: {'content-type': 'application/json'});
    }));

    final outcome = await service.postLogs(body: {'events': []});

    expect(url!.path, '/api/v3/mobile/logs');
    expect(auth, 'Bearer sess-1');
    expect(outcome, LogShareOutcome.keepGoing);
  });

  test('{continue:false} stops', () async {
    final service = _service(MockClient((req) async => http.Response(
        jsonEncode({'continue': false}), 200,
        headers: {'content-type': 'application/json'})));
    expect(await service.postLogs(body: const {}), LogShareOutcome.stop);
  });

  test('401 stops', () async {
    final service =
        _service(MockClient((req) async => http.Response('{}', 401)));
    expect(await service.postLogs(body: const {}), LogShareOutcome.stop);
  });

  test('no token skips the request', () async {
    var sent = false;
    final service = _service(
      MockClient((req) async {
        sent = true;
        return http.Response('{}', 200);
      }),
      tokenProvider: () async => null,
    );
    expect(await service.postLogs(body: const {}), LogShareOutcome.stop);
    expect(sent, isFalse);
  });
}
