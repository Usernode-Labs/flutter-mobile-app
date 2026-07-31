import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/log_share_service.dart';

const _base = 'https://test.example.com/api/v3/mobile';
const _credential = AuthCredentialLease(epoch: 7, token: 'sess-1');

LogShareService _service(MockClient client) => LogShareService(
      baseUrl: _base,
      httpClient: client,
      retryBackoff: Duration.zero,
    );

Future<LogShareOutcome> _post(
  LogShareService service, {
  Future<bool> Function(AuthCredentialLease)? credentialIsCurrent,
}) =>
    service.postLogs(
      body: const {'events': []},
      credential: _credential,
      sendIfCredentialCurrent: (credential, send) async {
        final current = await (credentialIsCurrent?.call(credential) ??
            Future<bool>.value(true));
        return current ? send() : null;
      },
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

    final outcome = await _post(service);

    expect(url!.path, '/api/v3/mobile/logs');
    expect(auth, 'Bearer sess-1');
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

  test('stale credential skips the request', () async {
    var sent = false;
    final service = _service(MockClient((req) async {
      sent = true;
      return http.Response('{}', 200);
    }));
    expect(
      await _post(service, credentialIsCurrent: (_) async => false),
      LogShareOutcome.stale,
    );
    expect(sent, isFalse);
  });

  test('does not retry after the credential becomes stale', () async {
    var requests = 0;
    var current = true;
    final service = _service(MockClient((req) async {
      requests++;
      current = false;
      return http.Response('{}', 500);
    }));

    expect(
      await _post(service, credentialIsCurrent: (_) async => current),
      LogShareOutcome.stale,
    );
    expect(requests, 1);
  });
}
