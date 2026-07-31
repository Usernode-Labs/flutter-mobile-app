import 'dart:async';

import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final store = HttpDebugLogStore.instance;

  setUp(() {
    store.clearForTesting();
    DebugModeStorage.isEnabled = false;
    IdentitySnapshots.reset();
  });
  tearDown(() {
    store.clearForTesting();
    DebugModeStorage.isEnabled = false;
    IdentitySnapshots.reset();
  });

  test(
      'does not capture when Debug Mode is off, but still returns the response',
      () async {
    final client = LoggingHttpClient(
      MockClient((_) async => http.Response('{"ok":true}', 200)),
    );

    final res = await client.get(Uri.parse('https://example.com/api'));

    expect(res.body, '{"ok":true}');
    expect(store.debugEntries, isEmpty);
  });

  test('captures a redacted entry when Debug Mode is on', () async {
    DebugModeStorage.isEnabled = true;
    final client = LoggingHttpClient(
      MockClient((req) async {
        // Body is preserved end-to-end.
        return http.Response('{"value":42}', 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final res = await client.post(
      Uri.parse('https://example.com/api'),
      headers: {'Authorization': 'Bearer super-secret'},
      body: 'request-payload',
    );

    // Caller still receives the untouched response.
    expect(res.statusCode, 200);
    expect(res.body, '{"value":42}');

    expect(store.debugEntries, hasLength(1));
    final entry = store.debugEntries.first;
    expect(entry.method, 'POST');
    expect(entry.statusCode, 200);
    expect(entry.requestBody, 'request-payload');
    expect(entry.responseBody, '{"value":42}');
    // The secret must be redacted.
    expect(entry.requestHeaders['Authorization'], '***');
    expect(entry.toLogText(), isNot(contains('super-secret')));
  });

  test('records an error entry and rethrows when the request throws', () async {
    DebugModeStorage.isEnabled = true;
    final client = LoggingHttpClient(
      MockClient((_) async => throw Exception('boom')),
    );

    await expectLater(
      client.get(Uri.parse('https://example.com/fail')),
      throwsA(isA<Exception>()),
    );

    expect(store.debugEntries, hasLength(1));
    final entry = store.debugEntries.first;
    expect(entry.isError, isTrue);
    expect(entry.error, contains('boom'));
    expect(entry.statusCode, isNull);
  });

  test('keeps the authenticated owner captured when the request began',
      () async {
    DebugModeStorage.isEnabled = true;
    IdentitySnapshots.publish(const Identity(
      epoch: 1,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
    ));
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final client = LoggingHttpClient(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );

    final request = client.get(Uri.parse('https://example.com/slow'));
    await started.future;
    IdentitySnapshots.publish(const Identity(
      epoch: 2,
      phase: IdentityPhase.ready,
      participantId: 22,
      accountId: 'account-b',
      address: 'address-b',
    ));
    response.complete(http.Response('{}', 200));
    await request;

    expect(
      store.debugEntries.single.owner,
      const AuthenticatedUserScope(participantId: 11),
    );
  });

  test('request begun anonymously stays anonymous after login', () async {
    DebugModeStorage.isEnabled = true;
    IdentitySnapshots.publish(
      const Identity(epoch: 1, phase: IdentityPhase.unauthenticated),
    );
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final client = LoggingHttpClient(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );

    final request = client.get(Uri.parse('https://example.com/pre-login'));
    await started.future;
    IdentitySnapshots.publish(const Identity(
      epoch: 2,
      phase: IdentityPhase.ready,
      participantId: 22,
      accountId: 'account-b',
      address: 'address-b',
    ));
    response.complete(http.Response('{}', 200));
    await request;

    expect(store.debugEntries.single.owner, isNull);
  });
}
