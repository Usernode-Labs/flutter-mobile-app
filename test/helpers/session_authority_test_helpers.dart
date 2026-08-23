import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';

export 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart'
    show AuthCredentialLease;

/// A transport script for controller tests. It deliberately has no lifecycle
/// model: each command consumes the next response locked by the test.
class ScriptedSessionAuthority extends SessionAuthorityGateway {
  ScriptedSessionAuthority(this.responses)
      : super(
          supportDirectory: () async => Directory('/application-support'),
          admissionJson: ({required directory}) => '{}',
          bootstrapJson: ({
            required directory,
            required network,
            required sessionId,
          }) =>
              '{}',
          commandJson: ({required directory, required request}) async => '{}',
        );

  final List<Map<String, dynamic>> responses;
  final commands = <Map<String, dynamic>>[];

  @override
  String get directory => '/application-support/session-authority';

  @override
  Future<Map<String, dynamic>> command(Map<String, dynamic> request) async {
    commands.add(jsonDecode(jsonEncode(request)) as Map<String, dynamic>);
    if (responses.isEmpty) throw StateError('Unexpected authority command');
    return responses.removeAt(0);
  }
}

Map<String, dynamic> sessionAuthorityResponse({
  required int sequence,
  required Map<String, dynamic> state,
  required String outcome,
  String network = 'testnet',
  Map<String, dynamic> outcomeFields = const {},
}) =>
    {
      'status': 'ok',
      'outcome': {'kind': outcome, ...outcomeFields},
      'revision': {
        'sequence': sequence,
        'session_id': state['session_id'],
        'state': state['kind'],
        'transition_id': state['transition_id'],
      },
      'record': {
        'schema_version': 1,
        'sequence': sequence,
        'network': network,
        'state': state,
      },
    };

Map<String, dynamic> loggedOutAuthorityState({
  String sessionId = 'logged-out-a',
  String mode = 'signed_out',
}) =>
    {
      'kind': 'logged_out',
      'session_id': sessionId,
      'mode': mode,
    };

Map<String, dynamic> activatingAuthorityState({
  required String phase,
  String predecessorSessionId = 'logged-out-a',
  String sessionId = 'session-a',
  String transitionId = 'login-a',
  String? credentialRef,
  int? credentialGeneration,
  String? userNamespace,
  Map<String, dynamic>? accountBinding,
  String? rollbackLoggedOutSessionId,
}) =>
    {
      'kind': 'activating',
      'predecessor_session_id': predecessorSessionId,
      'session_id': sessionId,
      'transition_id': transitionId,
      'phase': phase,
      'rollback_logged_out_session_id': rollbackLoggedOutSessionId,
      'credential_ref': credentialRef,
      'credential_generation': credentialGeneration,
      'user_namespace': userNamespace,
      'account_binding': accountBinding,
    };

Map<String, dynamic> readyAuthorityState({
  String accountId = 'account-a',
  String address = 'address-a',
  String credentialRef = 'credential-a',
  int credentialGeneration = 1,
  String userNamespace = 'aaaaaaaaaaaaaaaa',
}) =>
    {
      'kind': 'ready',
      'session_id': 'session-a',
      'user_namespace': userNamespace,
      'credential_ref': credentialRef,
      'credential_generation': credentialGeneration,
      'account_binding': {
        'account_id': accountId,
        'address': address,
      },
      'runtime_generation': null,
      'production_desired': false,
    };

Map<String, dynamic> retiringAuthorityState({
  String? successorNetwork,
}) =>
    {
      'kind': 'retiring',
      'session_id': 'session-a',
      'successor_logged_out_session_id': 'logged-out-b',
      'successor_network': successorNetwork,
      'transition_id': 'retire-a',
    };

/// The fixed happy-path transcript shared by tests whose subject begins after
/// login. Callers can append retirement replies when that is part of the
/// behavior under test.
ScriptedSessionAuthority activationSessionAuthority({
  required String accountId,
  required String address,
  String userNamespace = 'aaaaaaaaaaaaaaaa',
  String loggedOutMode = 'signed_out',
  List<Map<String, dynamic>> trailingResponses = const [],
}) {
  final binding = {'account_id': accountId, 'address': address};
  return ScriptedSessionAuthority([
    sessionAuthorityResponse(
      sequence: 0,
      state: loggedOutAuthorityState(mode: loggedOutMode),
      outcome: 'record_read',
    ),
    sessionAuthorityResponse(
      sequence: 1,
      state: activatingAuthorityState(phase: 'persist_credential'),
      outcome: 'activation_started',
    ),
    sessionAuthorityResponse(
      sequence: 2,
      state: activatingAuthorityState(
        phase: 'bind_namespace',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ),
      outcome: 'activation_advanced',
    ),
    sessionAuthorityResponse(
      sequence: 3,
      state: activatingAuthorityState(
        phase: 'reconcile_account',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        userNamespace: userNamespace,
      ),
      outcome: 'activation_advanced',
    ),
    sessionAuthorityResponse(
      sequence: 4,
      state: activatingAuthorityState(
        phase: 'commit_ready',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        userNamespace: userNamespace,
        accountBinding: binding,
      ),
      outcome: 'activation_advanced',
    ),
    sessionAuthorityResponse(
      sequence: 5,
      state: readyAuthorityState(
        accountId: accountId,
        address: address,
        userNamespace: userNamespace,
      ),
      outcome: 'activation_ready',
    ),
    ...trailingResponses,
  ]);
}

List<Map<String, dynamic>> successfulRetirementResponses({
  String? successorNetwork,
}) =>
    [
      sessionAuthorityResponse(
        sequence: 5,
        state: readyAuthorityState(),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 6,
        state: retiringAuthorityState(successorNetwork: successorNetwork),
        outcome: 'record_read',
      ),
      sessionAuthorityResponse(
        sequence: 7,
        state: loggedOutAuthorityState(sessionId: 'logged-out-b'),
        outcome: 'retirement_logged_out',
        network: successorNetwork ?? 'testnet',
      ),
    ];

AuthCredentialLease testCredentialLease({
  required int epoch,
  required String token,
  String? sessionId,
  String? credentialRef,
  int? credentialGeneration,
  IdentityPhase phase = IdentityPhase.ready,
}) =>
    SessionAuthorityGateway.captureCredential(
      identity: Identity(
        epoch: epoch,
        phase: phase,
        sessionId: sessionId ?? 'test-session-$epoch',
        credentialRef: credentialRef ?? 'test-credential-$epoch',
        credentialGeneration: credentialGeneration ?? 1,
      ),
      token: token,
    );
