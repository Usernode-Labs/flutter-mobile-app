import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart' as rust;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/session_authority_test_helpers.dart';

final class _FakeSessionEffectPermit implements rust.SessionEffectPermit {
  var _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;
}

void main() {
  test('credential issuance requires complete authenticated authority', () {
    const identity = Identity(
      epoch: 7,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 3,
    );

    final credential = SessionAuthorityGateway.captureCredential(
      identity: identity,
      token: 'token-a',
    );

    expect(credential.epoch, 7);
    expect(credential.token, 'token-a');
    expect(credential.sessionId, 'session-a');
    expect(credential.credentialRef, 'credential-a');
    expect(credential.credentialGeneration, 3);

    for (final invalid in <Identity>[
      identity.copyWith(phase: IdentityPhase.unauthenticated),
      identity.copyWith(clearSessionAuthority: true),
      identity.copyWith(sessionId: ' '),
      identity.copyWith(credentialRef: ' '),
      identity.copyWith(credentialGeneration: 0),
    ]) {
      expect(
        () => SessionAuthorityGateway.captureCredential(
          identity: invalid,
          token: 'token-a',
        ),
        throwsA(isA<StaleAuthCredentialException>()),
      );
    }
    expect(
      () => SessionAuthorityGateway.captureCredential(
        identity: identity,
        token: ' ',
      ),
      throwsA(isA<StaleAuthCredentialException>()),
    );
  });

  const revision = <String, dynamic>{
    'sequence': 7,
    'session_id': 'session-a',
    'state': 'ready',
    'transition_id': null,
  };
  final record = <String, dynamic>{
    'schema_version': 1,
    'sequence': 7,
    'network': 'testnet',
    'state': <String, dynamic>{
      'kind': 'ready',
      'session_id': 'session-a',
      'user_namespace': 'user-a',
      'credential_ref': 'credential-a',
      'credential_generation': 1,
      'account_binding': <String, dynamic>{
        'account_id': 'account-a',
        'address': 'address-a',
      },
      'runtime_generation': null,
      'production_desired': false,
    },
  };

  test('commands leave Dart asynchronously with the complete expected owner',
      () async {
    final requests = <Map<String, dynamic>>[];
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) =>
          jsonEncode({'status': 'logged_out'}),
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          jsonEncode({'status': 'logged_out'}),
      commandJson: ({required directory, required request}) async {
        requests.add(jsonDecode(request) as Map<String, dynamic>);
        await Future<void>.delayed(Duration.zero);
        return jsonEncode({
          'status': 'ok',
          'outcome': {'kind': 'record_read'},
          'revision': revision,
          'record': record,
        });
      },
    );

    final reply = await gateway.command({
      'command': 'renew_credential',
      'expected': revision,
      'session_id': 'session-a',
      'expected_credential_ref': 'credential-a',
      'expected_credential_generation': 1,
      'next_credential_ref': 'credential-b',
    });

    expect(gateway.directory, '/application-support/session-authority');
    expect(requests.single['expected'], revision);
    expect((reply['outcome'] as Map<String, dynamic>)['kind'], 'record_read');
    expect(reply['revision'], revision);
    expect(reply['record'], record);
  });

  test('a rejected command preserves the Rust reason and durable record',
      () async {
    final gateway = _gatewayReturning({
      'status': 'rejected',
      'reason': 'stale compare-and-swap owner',
      'record': record,
    });

    await expectLater(
      gateway.command({'command': 'read_record'}),
      throwsA(
        isA<SessionAuthorityRejected>()
            .having((error) => error.reason, 'reason', contains('stale'))
            .having((error) => error.record, 'record', record),
      ),
    );
  });

  test('terminal drain metadata reaches production telemetry dimensions',
      () async {
    final reports = <Map<String, Object?>>[];
    final terminalRecord = {
      ...record,
      'sequence': 8,
      'state': {
        'kind': 'terminal_reset_required',
        'reason': 'effect_drain_timeout',
        'previous_state': record['state'],
      },
    };
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async =>
          jsonEncode({
        'status': 'ok',
        'outcome': {
          'kind': 'retirement_drain_terminal',
          'reason': 'effect_drain_timeout',
          'oldest': {
            'sink': 'zk_outbox',
            'operation_id': 'flush-a',
            'engine_id': 'ui-a',
            'handed_off': false,
            'held_for_ms': 10004,
          },
        },
        'telemetry': {
          'reason': 'effect_drain_timeout',
          'phase': 'retirement_entry',
          'sink': 'zk_outbox',
          'platform': Platform.operatingSystem,
          'operation_id': 'flush-a',
          'engine_id': 'ui-a',
          'handed_off': false,
          'held_for_ms': 10004,
        },
        'revision': {...revision, 'sequence': 8},
        'record': terminalRecord,
      }),
      terminalReporter: reports.add,
    );

    await gateway.command({'command': 'enter_retirement'});

    expect(reports.single, {
      'reason': 'effect_drain_timeout',
      'phase': 'retirement_entry',
      'sink': 'zk_outbox',
      'platform': Platform.operatingSystem,
      'operation_id': 'flush-a',
      'engine_id': 'ui-a',
      'handed_off': false,
      'held_for_ms': 10004,
    });
  });

  test('invalid JSON and unknown statuses fail closed', () async {
    for (final response in [
      {'status': 'unexpected'},
      <String, dynamic>{},
    ]) {
      await expectLater(
        _gatewayReturning(response).command({'command': 'read_record'}),
        throwsA(isA<SessionAuthorityProtocolException>()),
      );
    }

    final invalidJson = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => 'not-json',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          'not-json',
      commandJson: ({required directory, required request}) async => 'not-json',
    );
    await expectLater(
      invalidJson.command({'command': 'read_record'}),
      throwsA(isA<SessionAuthorityProtocolException>()),
    );
  });

  test('bootstrap uses the stable installation directory and exact owner',
      () async {
    final calls = <Map<String, String>>[];
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) =>
          jsonEncode({'status': 'missing_journal'}),
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) {
        calls.add({
          'directory': directory,
          'network': network,
          'session_id': sessionId,
        });
        return jsonEncode({
          'status': 'logged_out',
          'session_id': sessionId,
          'network': network,
          'mode': 'signed_out',
        });
      },
      commandJson: ({required directory, required request}) async => '{}',
    );

    expect((await gateway.admission())['status'], 'missing_journal');
    final created = await gateway.bootstrapLoggedOut(
      network: 'testnet',
      sessionId: 'logged-out-a',
    );

    expect(created['session_id'], 'logged-out-a');
    expect(calls.single, {
      'directory': '/application-support/session-authority',
      'network': 'testnet',
      'session_id': 'logged-out-a',
    });
  });

  test('credential HTTP permit releases before a withheld response', () async {
    final events = <Object>[];
    final responseGate = Completer<http.StreamedResponse>();
    final requestWritten = Completer<void>();
    late http.BaseRequest capturedRequest;
    final permit = _FakeSessionEffectPermit();
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async => '{}',
      acquireHttpEffect: ({
        required directory,
        required sessionId,
        required credentialRef,
        required credentialGeneration,
        required operationId,
        required engineId,
      }) {
        events.add({
          'kind': 'acquire',
          'directory': directory,
          'session_id': sessionId,
          'credential_ref': credentialRef,
          'credential_generation': credentialGeneration,
          'operation_id': operationId,
        });
        return permit;
      },
      markEffectHandoff: ({required permit}) {
        events.add('handoff');
      },
      releaseEffectPermit: ({required permit}) {
        events.add('release');
      },
      requestWriter: (request, {required onRequestWritten}) async {
        capturedRequest = request;
        await Future<void>.sync(onRequestWritten);
        requestWritten.complete();
        return responseGate.future;
      },
    );
    final credential = testCredentialLease(
      epoch: 7,
      token: 'token-a',
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 3,
    );
    final request = http.Request(
      'GET',
      Uri.parse('https://example.test/api/v3/mobile/me'),
    )..headers['authorization'] = 'Bearer token-a';

    final responseFuture = gateway.sendCredentialRequest(
      credential: credential,
      request: request,
      operationId: 'confirm-a',
    );
    var responseSettled = false;
    unawaited(responseFuture.then<void>(
      (_) => responseSettled = true,
      onError: (_) => responseSettled = true,
    ));
    await requestWritten.future;

    expect(capturedRequest, same(request));
    expect(events, [
      {
        'kind': 'acquire',
        'directory': '/application-support/session-authority',
        'session_id': 'session-a',
        'credential_ref': 'credential-a',
        'credential_generation': BigInt.from(3),
        'operation_id': 'confirm-a',
      },
      'handoff',
      'release',
    ]);
    expect(responseSettled, isFalse);

    responseGate.complete(http.StreamedResponse(const Stream.empty(), 200));
    expect((await responseFuture).statusCode, 200);
  });

  test('workflow HTTP permit releases before a withheld response', () async {
    final events = <Object>[];
    final responseGate = Completer<http.StreamedResponse>();
    final requestWritten = Completer<void>();
    final permit = _FakeSessionEffectPermit();
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async => '{}',
      acquireWorkflowHttpEffect: ({
        required directory,
        required sessionId,
        required credentialRef,
        required credentialGeneration,
        required operationId,
        required engineId,
      }) {
        events.add({
          'kind': 'acquire',
          'session_id': sessionId,
          'credential_ref': credentialRef,
          'credential_generation': credentialGeneration,
          'operation_id': operationId,
        });
        return permit;
      },
      markEffectHandoff: ({required permit}) => events.add('handoff'),
      releaseEffectPermit: ({required permit}) => events.add('release'),
      requestWriter: (request, {required onRequestWritten}) async {
        await Future<void>.sync(onRequestWritten);
        requestWritten.complete();
        return responseGate.future;
      },
    );
    final credential = testCredentialLease(
      epoch: 7,
      token: 'token-a',
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 3,
    );
    final request = http.Request(
      'POST',
      Uri.parse('https://example.test/api/v3/mobile/zkpassport/complete'),
    )..headers['authorization'] = 'Bearer token-a';

    final responseFuture = gateway.sendWorkflowCredentialRequest(
      appSessionId: 'session-a',
      credential: credential,
      request: request,
      operationId: 'zk-delivery:request-a',
    );
    var responseSettled = false;
    unawaited(responseFuture.then<void>(
      (_) => responseSettled = true,
      onError: (_) => responseSettled = true,
    ));
    await requestWritten.future;

    expect(events, [
      {
        'kind': 'acquire',
        'session_id': 'session-a',
        'credential_ref': 'credential-a',
        'credential_generation': BigInt.from(3),
        'operation_id': 'zk-delivery:request-a',
      },
      'handoff',
      'release',
    ]);
    expect(responseSettled, isFalse);

    responseGate.complete(http.StreamedResponse(const Stream.empty(), 200));
    expect((await responseFuture).statusCode, 200);
  });

  test('push permit releases at native submission before a withheld result',
      () async {
    final events = <Object>[];
    final nativeHandoff = Completer<String>();
    final permit = _FakeSessionEffectPermit();
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async => '{}',
      acquirePushEffect: ({
        required directory,
        required sessionId,
        required operationId,
        required engineId,
      }) {
        events.add({
          'kind': 'acquire',
          'directory': directory,
          'session_id': sessionId,
          'operation_id': operationId,
        });
        return permit;
      },
      markEffectHandoff: ({required permit}) => events.add('handoff'),
      releaseEffectPermit: ({required permit}) => events.add('release'),
    );

    final result = gateway.runPushEffect(
      sessionId: 'session-a',
      operationId: 'social-push:provider-token-read',
      effect: () async {
        events.add('native-effect');
        return nativeHandoff.future;
      },
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, [
      {
        'kind': 'acquire',
        'directory': '/application-support/session-authority',
        'session_id': 'session-a',
        'operation_id': 'social-push:provider-token-read',
      },
      'native-effect',
      'handoff',
      'release',
    ]);

    nativeHandoff.complete('provider-token-a');
    expect(await result, 'provider-token-a');
    expect(events, hasLength(4));
  });

  test('rejected push admission cannot invoke the native effect', () async {
    var invoked = false;
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async => '{}',
      acquirePushEffect: ({
        required directory,
        required sessionId,
        required operationId,
        required engineId,
      }) =>
          throw const StaleAuthCredentialException(),
    );

    await expectLater(
      gateway.runPushEffect(
        sessionId: 'session-a',
        operationId: 'social-push:auto-init-enable',
        effect: () async {
          invoked = true;
        },
      ),
      throwsA(isA<StaleAuthCredentialException>()),
    );
    expect(invoked, isFalse);
  });

  test('Rust HTTP admission rejection stays distinct from transport failure',
      () async {
    final gateway = SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async => '{}',
      acquireHttpEffect: ({
        required directory,
        required sessionId,
        required credentialRef,
        required credentialGeneration,
        required operationId,
        required engineId,
      }) =>
          throw StateError('Rust rejected the stale credential'),
    );
    final credential = testCredentialLease(
      epoch: 7,
      token: 'token-a',
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 3,
    );
    final request = http.Request(
      'GET',
      Uri.parse('https://example.test/api/v3/mobile/me'),
    )..headers['authorization'] = 'Bearer token-a';

    await expectLater(
      gateway.sendCredentialRequest(
        credential: credential,
        request: request,
        operationId: 'confirm-a',
      ),
      throwsA(isA<StaleAuthCredentialException>()),
    );
  });
}

SessionAuthorityGateway _gatewayReturning(Map<String, dynamic> response) =>
    SessionAuthorityGateway(
      supportDirectory: () async => Directory('/application-support'),
      admissionJson: ({required directory}) => '{}',
      bootstrapJson: ({
        required directory,
        required network,
        required sessionId,
      }) =>
          '{}',
      commandJson: ({required directory, required request}) async =>
          jsonEncode(response),
    );
