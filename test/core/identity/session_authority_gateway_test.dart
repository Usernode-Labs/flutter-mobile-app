import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/session_authority_test_helpers.dart';

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

  test('account capability issuance fixes the complete Ready owner', () {
    final gateway = SessionAuthorityGateway();
    const identity = Identity(
      epoch: 9,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 3,
    );

    final capability = gateway.captureAccountCapability(
      identity: identity,
      userNamespace: 'aaaaaaaaaaaaaaaa',
      network: 'testnet',
    );

    expect(capability.sessionId, 'session-a');
    expect(capability.userNamespace, 'aaaaaaaaaaaaaaaa');
    expect(capability.network, 'testnet');
    expect(capability.accountId, 'account-a');
    expect(capability.address, 'address-a');
    expect(capability.secretKeyRef, 'testnet:account:account-a:secretKey');

    for (final invalid in <Identity>[
      identity.copyWith(phase: IdentityPhase.reconciling),
      identity.copyWith(clearAccount: true),
      identity.copyWith(clearSessionAuthority: true),
    ]) {
      expect(
        () => gateway.captureAccountCapability(
          identity: invalid,
          userNamespace: 'aaaaaaaaaaaaaaaa',
          network: 'testnet',
        ),
        throwsA(isA<StaleAuthCredentialException>()),
      );
    }
  });

  test('WebView realm capture pins the original session and document', () {
    final gateway = SessionAuthorityGateway();
    final lease = gateway.captureWebViewRealmLease(
      identity: const Identity(
        epoch: 9,
        phase: IdentityPhase.ready,
        sessionId: 'session-a',
      ),
      realmId: 'realm-a',
    );
    expect(lease.sessionId, 'session-a');
    expect(lease.realmId, 'realm-a');

    expect(
      () => gateway.captureWebViewRealmLease(
        identity: const Identity.unknown(),
        realmId: 'realm-a',
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

  test('credential request keeps its captured bearer and may finish late',
      () async {
    final responseGate = Completer<http.StreamedResponse>();
    final dispatched = Completer<void>();
    late http.BaseRequest capturedRequest;
    final gateway = SessionAuthorityGateway(
      requestSender: (request) {
        capturedRequest = request;
        dispatched.complete();
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
    );
    var responseSettled = false;
    unawaited(responseFuture.then<void>(
      (_) => responseSettled = true,
      onError: (_) => responseSettled = true,
    ));
    await dispatched.future;

    expect(capturedRequest, same(request));
    expect(capturedRequest.headers['authorization'], 'Bearer token-a');
    expect(responseSettled, isFalse);

    responseGate.complete(http.StreamedResponse(const Stream.empty(), 200));
    expect((await responseFuture).statusCode, 200);
  });

  test('workflow transport requires the row and credential to share an owner',
      () async {
    var sends = 0;
    final gateway = SessionAuthorityGateway(
      requestSender: (request) async {
        sends++;
        return http.StreamedResponse(const Stream.empty(), 200);
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

    final response = await gateway.sendWorkflowCredentialRequest(
      appSessionId: 'session-a',
      credential: credential,
      request: request,
    );
    expect(response.statusCode, 200);
    expect(sends, 1);
    expect(
      () => gateway.sendWorkflowCredentialRequest(
        appSessionId: 'session-b',
        credential: credential,
        request: request,
      ),
      throwsA(isA<StaleAuthCredentialException>()),
    );
    expect(sends, 1);
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
