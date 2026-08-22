import 'dart:convert';
import 'dart:io';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopAuthRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

class _RejectedAuthRepository extends AuthRepository {
  @override
  Future<AuthSession> resolveBearerSession(
    String token, {
    int? legacyParticipantId,
  }) async =>
      throw AuthException(
        AuthErrorKind.invalidCredentials,
        'Unauthenticated.',
      );

  @override
  Future<void> logout(String sessionToken) async {}
}

class _ScriptedAuthority extends SessionAuthorityGateway {
  _ScriptedAuthority(this.responses)
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

AuthSession _session(String token) => AuthSession(
      token: token,
      participant: const Participant(
        id: 7,
        email: '7@example.com',
        emailConfirmed: true,
        identityHash: 'aaaaaaaaaaaaaaaa',
      ),
    );

Map<String, dynamic> _response({
  required int sequence,
  required Map<String, dynamic> state,
  required String outcome,
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
        'network': 'testnet',
        'state': state,
      },
    };

Map<String, dynamic> _loggedOut() => {
      'kind': 'logged_out',
      'session_id': 'logged-out-a',
      'mode': 'signed_out',
    };

Map<String, dynamic> _activating({
  required String phase,
  String? credentialRef,
  int? credentialGeneration,
  String? userNamespace,
  Map<String, dynamic>? accountBinding,
  String? rollbackLoggedOutSessionId,
}) =>
    {
      'kind': 'activating',
      'predecessor_session_id': 'logged-out-a',
      'session_id': 'session-a',
      'transition_id': 'login-a',
      'phase': phase,
      'rollback_logged_out_session_id': rollbackLoggedOutSessionId,
      'credential_ref': credentialRef,
      'credential_generation': credentialGeneration,
      'user_namespace': userNamespace,
      'account_binding': accountBinding,
    };

Map<String, dynamic> _ready({
  String credentialRef = 'credential-a',
  int credentialGeneration = 1,
}) =>
    {
      'kind': 'ready',
      'session_id': 'session-a',
      'user_namespace': 'aaaaaaaaaaaaaaaa',
      'credential_ref': credentialRef,
      'credential_generation': credentialGeneration,
      'account_binding': {
        'account_id': 'account-a',
        'address': 'address-a',
      },
      'runtime_generation': null,
      'production_desired': false,
    };

Map<String, dynamic> _retiring(String phase, {int attempts = 0}) => {
      'kind': 'retiring',
      'session_id': 'session-a',
      'successor_logged_out_session_id': 'logged-out-b',
      'successor_network': null,
      'transition_id': 'retire-a',
      'phase': phase,
      'phase_attempts': attempts,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  test('login reaches Ready only through exact durable activation evidence',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 0, state: _loggedOut(), outcome: 'record_read'),
      _response(
        sequence: 1,
        state: _activating(phase: 'persist_credential'),
        outcome: 'activation_started',
      ),
      _response(
        sequence: 2,
        state: _activating(
          phase: 'bind_namespace',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 3,
        state: _activating(
          phase: 'reconcile_account',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: 'aaaaaaaaaaaaaaaa',
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 4,
        state: _activating(
          phase: 'commit_ready',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: 'aaaaaaaaaaaaaaaa',
          accountBinding: {
            'account_id': 'account-a',
            'address': 'address-a',
          },
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 5,
        state: _ready(),
        outcome: 'activation_ready',
      ),
      _response(
        sequence: 6,
        state: _ready(
          credentialRef: 'credential-b',
          credentialGeneration: 2,
        ),
        outcome: 'credential_renewed',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    final ids = <String, String>{
      'session': 'session-a',
      'transition': 'login-a',
      'credential': 'credential-a',
      'renewal': 'credential-b',
    };
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => ids[kind]!,
      suspendNode: () async {},
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);

    await controller.restore();
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-a');

    expect(await controller.completeLogin(_session('token-a')), isTrue);
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.sessionId, 'session-a');
    expect(controller.state.credentialRef, 'credential-a');
    expect(controller.state.credentialGeneration, 1);
    expect(
      (await tokenStore.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ))
          ?.token,
      'token-a',
    );

    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 7,
      ),
      isTrue,
    );
    expect(controller.state.phase, IdentityPhase.ready);
    expect(controller.state.sessionId, 'session-a');

    final epoch = controller.state.epoch;
    expect(await controller.completeLogin(_session('token-b')), isTrue);
    expect(controller.state.epoch, epoch);
    expect(controller.state.credentialRef, 'credential-b');
    expect(controller.state.credentialGeneration, 2);
    expect(
      (await tokenStore.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-b',
        credentialGeneration: 2,
      ))
          ?.token,
      'token-b',
    );

    expect(
      authority.commands.map((command) => command['command']),
      [
        'read_record',
        'begin_activation',
        'recover_activation',
        'recover_activation',
        'recover_activation',
        'recover_activation',
        'renew_credential',
      ],
    );
    expect(
      authority.commands[2]['evidence'],
      {
        'kind': 'credential_verified',
        'credential_ref': 'credential-a',
        'credential_generation': 1,
      },
    );
    expect(
      authority.commands[4]['evidence'],
      {
        'kind': 'account_verified',
        'account_binding': {
          'account_id': 'account-a',
          'address': 'address-a',
        },
      },
    );
  });

  test('cold activation adopts only its exact persisted credential', () async {
    final authority = _ScriptedAuthority([
      _response(
        sequence: 1,
        state: _activating(phase: 'persist_credential'),
        outcome: 'record_read',
      ),
      _response(
        sequence: 2,
        state: _activating(
          phase: 'bind_namespace',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 3,
        state: _activating(
          phase: 'reconcile_account',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: 'aaaaaaaaaaaaaaaa',
        ),
        outcome: 'activation_advanced',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    await tokenStore.writeSessionCredential(
      const SessionCredential(
        sessionId: 'session-a',
        transitionId: 'login-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        token: 'token-a',
        userNamespace: 'aaaaaaaaaaaaaaaa',
      ),
    );
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (_) => 'unused',
      suspendNode: () async {},
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.sessionId, 'session-a');
    expect(controller.state.credentialRef, 'credential-a');
    expect(controller.state.credentialGeneration, 1);
    expect(
      authority.commands.map((command) => command['command']),
      ['read_record', 'recover_activation', 'recover_activation'],
    );
    expect(authority.commands[1]['evidence'], {
      'kind': 'credential_verified',
      'credential_ref': 'credential-a',
      'credential_generation': 1,
    });
  });

  test('cold activation without credential clears only the transition',
      () async {
    final authority = _ScriptedAuthority([
      _response(
        sequence: 1,
        state: _activating(phase: 'persist_credential'),
        outcome: 'record_read',
      ),
      _response(
        sequence: 2,
        state: _activating(
          phase: 'rollback_clear',
          rollbackLoggedOutSessionId: 'logged-out-b',
        ),
        outcome: 'activation_rolling_back',
      ),
      _response(
        sequence: 3,
        state: _activating(
          phase: 'rollback_commit',
          rollbackLoggedOutSessionId: 'logged-out-b',
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 4,
        state: {
          'kind': 'logged_out',
          'session_id': 'logged-out-b',
          'mode': 'signed_out',
        },
        outcome: 'activation_logged_out',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => kind == 'rollback' ? 'logged-out-b' : 'unused',
      suspendNode: () async {},
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(authority.commands[1]['evidence'], {'kind': 'missing'});
    expect(
      authority.commands[1]['rollback_logged_out_session_id'],
      'logged-out-b',
    );
    expect(
      authority.commands.map((command) => command['command']),
      [
        'read_record',
        'recover_activation',
        'recover_activation',
        'recover_activation',
      ],
    );
  });

  test('logout enters durable retirement before platform cleanup and repair',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_entered',
        outcomeFields: {'effect_epoch': 2},
      ),
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_tombstone_status',
        outcomeFields: {'verified': false},
      ),
      _response(
        sequence: 7,
        state: _retiring('tombstone_work', attempts: 1),
        outcome: 'retirement_invoke',
        outcomeFields: {
          'phase': 'tombstone_work',
          'durable_attempt': 1,
          'timeout_ms': 10000,
        },
      ),
      _response(
        sequence: 7,
        state: _retiring('tombstone_work', attempts: 1),
        outcome: 'retirement_tombstone_status',
        outcomeFields: {'verified': true},
      ),
      _response(
        sequence: 8,
        state: _retiring('revoke_native_admission'),
        outcome: 'retirement_advanced',
        outcomeFields: {'phase': 'revoke_native_admission'},
      ),
      ..._phaseResponses(
        instructionSequence: 9,
        advanceSequence: 10,
        phase: 'revoke_native_admission',
        nextPhase: 'revoke_runtime',
      ),
      ..._phaseResponses(
        instructionSequence: 11,
        advanceSequence: 12,
        phase: 'revoke_runtime',
        nextPhase: 'clear_credential',
      ),
      ..._phaseResponses(
        instructionSequence: 13,
        advanceSequence: 14,
        phase: 'clear_credential',
        nextPhase: 'clear_webview',
      ),
      ..._phaseResponses(
        instructionSequence: 15,
        advanceSequence: 16,
        phase: 'clear_webview',
        nextPhase: 'commit_logged_out',
      ),
      _response(
        sequence: 17,
        state: {
          'kind': 'logged_out',
          'session_id': 'logged-out-b',
          'mode': 'signed_out',
        },
        outcome: 'retirement_logged_out',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    await tokenStore.writeSessionCredential(
      const SessionCredential(
        sessionId: 'session-a',
        transitionId: 'login-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        token: 'token-a',
        userNamespace: 'aaaaaaaaaaaaaaaa',
      ),
    );
    final bucket = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
      'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
    });
    final effects = <String>[];
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      suspendNode: () async {},
      retireRuntimeAuthority: ({
        required directory,
        required sessionId,
        required transitionId,
      }) async {
        effects.add('runtime');
        return true;
      },
      clearWebSessionData: () async {
        effects.add('webview');
        return true;
      },
      rotateNativeGeneration: () async {
        effects.add('native');
        return true;
      },
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);

    await controller.restore();
    expect(controller.state.phase, IdentityPhase.ready);
    expect(await controller.logout(), isTrue);

    expect(effects, ['native', 'runtime', 'webview']);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(
      await tokenStore.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ),
      isNull,
    );
    expect(authority.commands[1]['command'], 'enter_retirement');
    expect(
      authority.commands[1]['expected'],
      {
        'sequence': 5,
        'session_id': 'session-a',
        'state': 'ready',
        'transition_id': null,
      },
    );
    final firstPlatformEffectCommand = authority.commands.indexWhere(
      (command) =>
          command['command'] == 'recover_retirement' &&
          (command['evidence'] as Map)['kind'] == 'needs_invocation',
    );
    expect(firstPlatformEffectCommand, greaterThan(1));
  });

  test('cold Ready with no exact credential retires through the journal',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(),
    ]);
    final bucket = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
    });
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: ({
        required directory,
        required sessionId,
        required transitionId,
      }) async =>
          true,
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(authority.commands[1]['command'], 'enter_retirement');
    expect(authority.commands[1]['session_id'], 'session-a');
  });

  test('a missing current credential uses ordinary durable retirement',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(),
    ]);
    final tokenStore = AuthTokenStore();
    const credential = SessionCredential(
      sessionId: 'session-a',
      transitionId: 'login-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
      token: 'token-a',
      userNamespace: 'aaaaaaaaaaaaaaaa',
    );
    await tokenStore.writeSessionCredential(credential);
    final bucket = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
    });
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: ({
        required directory,
        required sessionId,
        required transitionId,
      }) async =>
          true,
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final epoch = controller.state.epoch;
    expect(await tokenStore.clearSessionCredential(credential), isTrue);

    await controller.onCredentialMissing(epoch: epoch);

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(authority.commands[1]['command'], 'enter_retirement');
    expect(authority.commands[1]['session_id'], 'session-a');
  });

  test('definitive rejection retires only the exact current credential',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_entered',
        outcomeFields: {'effect_epoch': 2},
      ),
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_tombstone_status',
        outcomeFields: {'verified': true},
      ),
      _response(
        sequence: 7,
        state: _retiring('revoke_native_admission'),
        outcome: 'retirement_advanced',
        outcomeFields: {'phase': 'revoke_native_admission'},
      ),
      ..._phaseResponses(
        instructionSequence: 8,
        advanceSequence: 9,
        phase: 'revoke_native_admission',
        nextPhase: 'revoke_runtime',
      ),
      ..._phaseResponses(
        instructionSequence: 10,
        advanceSequence: 11,
        phase: 'revoke_runtime',
        nextPhase: 'clear_credential',
      ),
      ..._phaseResponses(
        instructionSequence: 12,
        advanceSequence: 13,
        phase: 'clear_credential',
        nextPhase: 'clear_webview',
      ),
      ..._phaseResponses(
        instructionSequence: 14,
        advanceSequence: 15,
        phase: 'clear_webview',
        nextPhase: 'commit_logged_out',
      ),
      _response(
        sequence: 16,
        state: {
          'kind': 'logged_out',
          'session_id': 'logged-out-b',
          'mode': 'signed_out',
        },
        outcome: 'retirement_logged_out',
      ),
    ]);
    final tokenStore = AuthTokenStore();
    await tokenStore.writeSessionCredential(
      const SessionCredential(
        sessionId: 'session-a',
        transitionId: 'login-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
        token: 'token-a',
        userNamespace: 'aaaaaaaaaaaaaaaa',
      ),
    );
    final bucket = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
      'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
    });
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _RejectedAuthRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      suspendNode: () async {},
      retireRuntimeAuthority: ({
        required directory,
        required sessionId,
        required transitionId,
      }) async =>
          true,
      clearWebSessionData: () async => true,
      rotateNativeGeneration: () async => true,
      clearSessionNotifications: () async => true,
      signOutFence: InMemorySignOutFence(),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Unexpected terminal reset: $reason');
      },
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final identity = controller.state;

    await controller.onUnauthorized(
      credential: AuthCredentialLease(
        epoch: identity.epoch,
        token: 'token-a',
        sessionId: identity.sessionId,
        credentialRef: identity.credentialRef,
        credentialGeneration: identity.credentialGeneration,
      ),
    );

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(authority.commands[1], {
      'command': 'confirm_credential',
      'expected': {
        'sequence': 5,
        'session_id': 'session-a',
        'state': 'ready',
        'transition_id': null,
      },
      'session_id': 'session-a',
      'credential_ref': 'credential-a',
      'credential_generation': 1,
      'evidence': 'definitive_rejection',
      'successor_logged_out_session_id': 'logged-out-b',
      'transition_id': 'retire-a',
    });
  });
}

List<Map<String, dynamic>> _phaseResponses({
  required int instructionSequence,
  required int advanceSequence,
  required String phase,
  required String nextPhase,
}) =>
    [
      _response(
        sequence: instructionSequence,
        state: _retiring(phase, attempts: 1),
        outcome: 'retirement_invoke',
        outcomeFields: {
          'phase': phase,
          'durable_attempt': 1,
          'timeout_ms': 10000,
        },
      ),
      _response(
        sequence: advanceSequence,
        state: _retiring(nextPhase),
        outcome: 'retirement_advanced',
        outcomeFields: {'phase': nextPhase},
      ),
    ];

List<Map<String, dynamic>> _successfulRetirementResponses() => [
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_entered',
        outcomeFields: {'effect_epoch': 2},
      ),
      _response(
        sequence: 6,
        state: _retiring('tombstone_work'),
        outcome: 'retirement_tombstone_status',
        outcomeFields: {'verified': true},
      ),
      _response(
        sequence: 7,
        state: _retiring('revoke_native_admission'),
        outcome: 'retirement_advanced',
        outcomeFields: {'phase': 'revoke_native_admission'},
      ),
      ..._phaseResponses(
        instructionSequence: 8,
        advanceSequence: 9,
        phase: 'revoke_native_admission',
        nextPhase: 'revoke_runtime',
      ),
      ..._phaseResponses(
        instructionSequence: 10,
        advanceSequence: 11,
        phase: 'revoke_runtime',
        nextPhase: 'clear_credential',
      ),
      ..._phaseResponses(
        instructionSequence: 12,
        advanceSequence: 13,
        phase: 'clear_credential',
        nextPhase: 'clear_webview',
      ),
      ..._phaseResponses(
        instructionSequence: 14,
        advanceSequence: 15,
        phase: 'clear_webview',
        nextPhase: 'commit_logged_out',
      ),
      _response(
        sequence: 16,
        state: {
          'kind': 'logged_out',
          'session_id': 'logged-out-b',
          'mode': 'signed_out',
        },
        outcome: 'retirement_logged_out',
      ),
    ];
