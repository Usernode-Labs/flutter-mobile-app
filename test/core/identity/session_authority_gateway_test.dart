import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
