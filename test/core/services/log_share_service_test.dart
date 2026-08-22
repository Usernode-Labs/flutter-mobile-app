import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/log_share_service.dart';

const _base = 'https://test.example.com/api/v3/mobile';
const _credential = AuthCredentialLease(
  epoch: 7,
  token: 'sess-1',
  sessionId: 'session-a',
  credentialRef: 'credential-a',
  credentialGeneration: 3,
);

LogShareService _service(MockClient client) => LogShareService(
      baseUrl: _base,
      credentialRequestSender: ({
        required credential,
        required request,
        required operationId,
      }) =>
          client.send(request),
      retryBackoff: Duration.zero,
    );

http.StreamedResponse _streamedResponse(int statusCode, String body) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

Future<LogShareOutcome> _post(
  LogShareService service,
) =>
    service.postLogs(
      body: const {'events': []},
      credential: _credential,
    );

void main() {
  test('submits its exact lease and request only to the authority sender',
      () async {
    late AuthCredentialLease capturedCredential;
    late http.BaseRequest capturedRequest;
    late String capturedOperationId;
    final service = LogShareService(
      baseUrl: _base,
      credentialRequestSender: ({
        required credential,
        required request,
        required operationId,
      }) async {
        capturedCredential = credential;
        capturedRequest = request;
        capturedOperationId = operationId;
        return _streamedResponse(200, jsonEncode({'continue': true}));
      },
      retryBackoff: Duration.zero,
    );

    final outcome = await _post(service);

    expect(capturedCredential.sessionId, 'session-a');
    expect(capturedCredential.credentialRef, 'credential-a');
    expect(capturedCredential.credentialGeneration, 3);
    expect(capturedCredential.token, 'sess-1');
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/v3/mobile/logs');
    expect(capturedRequest.headers['authorization'], 'Bearer sess-1');
    expect(capturedOperationId, 'log-share:post');
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

  test('missing authority sender fails closed as stale', () async {
    final service = LogShareService(
      baseUrl: _base,
      retryBackoff: Duration.zero,
    );

    expect(await _post(service), LogShareOutcome.stale);
  });

  test('retry re-admits the original lease and stops on sink rejection',
      () async {
    final submittedCredentials = <AuthCredentialLease>[];
    final submittedRequests = <http.BaseRequest>[];
    final service = LogShareService(
      baseUrl: _base,
      credentialRequestSender: ({
        required credential,
        required request,
        required operationId,
      }) async {
        submittedCredentials.add(credential);
        submittedRequests.add(request);
        if (submittedCredentials.length == 1) {
          return _streamedResponse(500, '{}');
        }
        throw const StaleAuthCredentialException();
      },
      retryBackoff: Duration.zero,
    );

    expect(await _post(service), LogShareOutcome.stale);
    expect(submittedCredentials, hasLength(2));
    expect(
      submittedCredentials.map((credential) => credential.token),
      everyElement('sess-1'),
    );
    expect(
      submittedRequests.map((request) => request.headers['authorization']),
      everyElement('Bearer sess-1'),
    );
  });
}
