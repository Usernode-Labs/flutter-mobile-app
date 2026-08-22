import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/providers/log_share_provider.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:crypto_mobile_app/core/services/log_share_service.dart';

Identity _identity({required int epoch, required int participantId}) =>
    Identity(
      epoch: epoch,
      phase: IdentityPhase.ready,
      participantId: participantId,
      accountId: 'account-$participantId',
      address: 'address-$participantId',
      sessionId: 'session-$participantId',
      credentialRef: 'credential-$participantId',
      credentialGeneration: 1,
    );

SessionAuthorityCredentialRequestSender _throughClient(http.Client client) => ({
      required credential,
      required request,
      required operationId,
    }) =>
        client.send(request);

HttpLogEntry _entry(String suffix) => HttpLogEntry(
      timestamp: DateTime.utc(2026, 1, 1),
      method: 'GET',
      url: 'https://example.test/$suffix',
      statusCode: 200,
    );

Future<void> _waitForRequestCount(
    List<http.Request> requests, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (requests.length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $count requests; saw ${requests.length}');
    }
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = HttpDebugLogStore.instance;

  setUp(store.clear);
  tearDown(store.clear);

  test('identity replacement stops sharing without advancing the old cursor',
      () async {
    var identity = _identity(epoch: 1, participantId: 1);
    var token = 'token-a';
    final requests = <http.Request>[];
    final responses = <Completer<http.Response>>[];
    final client = MockClient((request) {
      requests.add(request);
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    });
    final service = LogShareService(
      baseUrl: 'https://test.example/api/v3/mobile',
      retryBackoff: Duration.zero,
      credentialRequestSender: _throughClient(client),
    );
    final controller = LogShareController(
      currentIdentity: () => identity,
      tokenProvider: () async => token,
      filterProvider: () => '',
      service: service,
      store: store,
    );
    addTearDown(controller.dispose);
    store.add(_entry('identity-a'));

    final sharingA = controller.start(1);
    await _waitForRequestCount(requests, 1);
    expect(requests.single.headers['authorization'], 'Bearer token-a');

    identity = _identity(epoch: 2, participantId: 2);
    token = 'token-b';
    controller.identityChanged(identity);
    expect(controller.state.isSharing, isFalse);

    responses.single.complete(http.Response(
      jsonEncode({'continue': true}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await sharingA;
    expect(controller.state.isSharing, isFalse);
    expect(requests, hasLength(1));

    // Starting the replacement identity must resend the buffered entry. If
    // the stale completion advanced the cursor, this request would not occur.
    store.add(_entry('identity-b'));
    final sharingB = controller.start(2);
    await _waitForRequestCount(requests, 2);
    expect(requests.last.headers['authorization'], 'Bearer token-b');
    expect(jsonDecode(requests.last.body)['events'], hasLength(2));
    responses.last.complete(http.Response(
      jsonEncode({'continue': false}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await sharingB;
  });

  test('replacement lease flushes while superseded transport is still pending',
      () async {
    var identity = _identity(epoch: 1, participantId: 1);
    var token = 'token-a';
    final requests = <http.Request>[];
    final responses = <Completer<http.Response>>[];
    final client = MockClient((request) {
      requests.add(request);
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    });
    final service = LogShareService(
      baseUrl: 'https://test.example/api/v3/mobile',
      retryBackoff: Duration.zero,
      credentialRequestSender: _throughClient(client),
    );
    final controller = LogShareController(
      currentIdentity: () => identity,
      tokenProvider: () async => token,
      filterProvider: () => '',
      service: service,
      store: store,
    );
    addTearDown(controller.dispose);
    store.add(_entry('identity-a'));

    final sharingA = controller.start(1);
    await _waitForRequestCount(requests, 1);

    identity = _identity(epoch: 2, participantId: 2);
    token = 'token-b';
    controller.identityChanged(identity);
    store.add(_entry('identity-b'));

    // Do not complete A. B must own an independent in-flight slot and send its
    // initial batch immediately instead of waiting for A plus the 30s timer.
    final sharingB = controller.start(2);
    await _waitForRequestCount(requests, 2);
    expect(responses.first.isCompleted, isFalse);
    expect(requests.last.headers['authorization'], 'Bearer token-b');

    responses[1].complete(http.Response(
      jsonEncode({'continue': false}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await sharingB;

    responses[0].complete(http.Response(
      jsonEncode({'continue': true}),
      200,
      headers: {'content-type': 'application/json'},
    ));
    await sharingA;
    expect(controller.state.stoppedByServer, isTrue);
  });
}
