import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/services/log_share_service.dart';

import '../../helpers/session_authority_test_helpers.dart';

const _base = 'https://test.example.com/api/v3/mobile';
final _credential = testCredentialLease(
  epoch: 7,
  token: 'sess-1',
  sessionId: 'session-a',
  credentialRef: 'credential-a',
  credentialGeneration: 3,
);

LogShareService _service(MockClient client) => LogShareService(
      baseUrl: _base,
      httpClient: client,
      retryBackoff: Duration.zero,
    );

Future<LogShareOutcome> _post(
  LogShareService service,
) =>
    service.postLogs(
      body: const {'events': []},
      credential: _credential,
    );

void main() {
  test('sends the captured bearer through the injected HTTP client', () async {
    late http.Request capturedRequest;
    final service = LogShareService(
      baseUrl: _base,
      httpClient: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'continue': true}), 200);
      }),
      retryBackoff: Duration.zero,
    );

    final outcome = await _post(service);

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/v3/mobile/logs');
    expect(capturedRequest.headers['authorization'], 'Bearer sess-1');
    expect(outcome, LogShareOutcome.keepGoing);
  });

  test('{continue:false} stops', () async {
    final service = _service(MockClient((req) async => http.Response(
        jsonEncode({'continue': false}), 200,
        headers: {'content-type': 'application/json'})));
    expect(await _post(service), LogShareOutcome.stop);
  });

  test('401 stops', () async {
    final service =
        _service(MockClient((req) async => http.Response('{}', 401)));
    expect(await _post(service), LogShareOutcome.stop);
  });

  test('retry reuses the original immutable bearer', () async {
    final submittedRequests = <http.Request>[];
    final service = LogShareService(
      baseUrl: _base,
      httpClient: MockClient((request) async {
        submittedRequests.add(request);
        if (submittedRequests.length == 1) {
          return http.Response('{}', 500);
        }
        return http.Response('{}', 401);
      }),
      retryBackoff: Duration.zero,
    );

    expect(await _post(service), LogShareOutcome.stop);
    expect(submittedRequests, hasLength(2));
    expect(
      submittedRequests.map((request) => request.headers['authorization']),
      everyElement('Bearer sess-1'),
    );
  });
}
