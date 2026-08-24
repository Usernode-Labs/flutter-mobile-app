import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/session_host.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/session_authority_test_helpers.dart';

class _NoopAuthRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

class _RejectedAuthRepository extends AuthRepository {
  final confirmedCredentials = <AuthCredentialLease>[];

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
  Future<AuthSession> confirmBearerSession(
    AuthCredentialLease credential,
  ) async {
    confirmedCredentials.add(credential);
    throw AuthException(
      AuthErrorKind.invalidCredentials,
      'Unauthenticated.',
    );
  }

  @override
  Future<void> logout(String sessionToken) async {}
}

class _AcceptedAuthRepository extends _NoopAuthRepository {
  @override
  Future<AuthSession> confirmBearerSession(
    AuthCredentialLease credential,
  ) async =>
      _session(credential.token);
}

class _UnavailableAuthRepository extends _NoopAuthRepository {
  @override
  Future<AuthSession> confirmBearerSession(
    AuthCredentialLease credential,
  ) async =>
      throw AuthException(AuthErrorKind.network, 'temporarily unavailable');
}

typedef _ScriptedAuthority = ScriptedSessionAuthority;

AuthSession _session(String token) => AuthSession(
      token: token,
      participant: const Participant(
        id: 7,
        email: '7@example.com',
        emailConfirmed: true,
        identityHash: 'aaaaaaaaaaaaaaaa',
      ),
    );

const _response = sessionAuthorityResponse;
const _loggedOut = loggedOutAuthorityState;
const _activating = activatingAuthorityState;
const _ready = readyAuthorityState;
const _successfulRetirementResponses = successfulRetirementResponses;

Future<void> _retireRuntime({
  required String directory,
  required int expectedSequence,
  required String sessionId,
  required String successorLoggedOutSessionId,
  required String? successorNetwork,
  required String transitionId,
}) async {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
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
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => ids[kind]!,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
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

  test(
      'same-account season rollover retains Ready authority without '
      'reactivation', () async {
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
      _response(sequence: 5, state: _ready(), outcome: 'activation_ready'),
    ]);
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'session' => 'session-a',
        'transition' => 'login-a',
        'credential' => 'credential-a',
        _ => throw StateError('Unexpected authority id: $kind'),
      },
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    expect(await controller.completeLogin(_session('token-a')), isTrue);
    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 7,
        provisionedSeasonId: 7,
      ),
      isTrue,
    );
    final commandsBeforeRollover = authority.commands.length;

    await controller.beginSeasonRollover(activeSeasonId: 8);
    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 7,
        provisionedSeasonId: 8,
      ),
      isTrue,
    );

    expect(authority.commands, hasLength(commandsBeforeRollover));
    expect(controller.state.phase, IdentityPhase.ready);
    expect(controller.state.sessionId, 'session-a');
    expect(controller.state.credentialRef, 'credential-a');
    expect(controller.state.credentialGeneration, 1);
    expect(controller.state.provisionedSeasonId, 8);
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
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (_) => 'unused',
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
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
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => kind == 'rollback' ? 'logged-out-b' : 'unused',
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
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
      ..._successfulRetirementResponses(),
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
      'testnet:user:aaaaaaaaaaaaaaaa:accounts:index': 'retained-wallet',
    });
    final effects = <String>[];
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: ({
        required directory,
        required expectedSequence,
        required sessionId,
        required successorLoggedOutSessionId,
        required successorNetwork,
        required transitionId,
      }) async {
        effects.add('runtime');
      },
      clearWebSessionData: () async {
        effects.add('webview');
        return true;
      },
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    expect(controller.state.phase, IdentityPhase.ready);
    expect(await controller.logout(), isTrue);

    expect(effects, ['runtime', 'webview']);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('testnet:user:aaaaaaaaaaaaaaaa:accounts:index'),
      'retained-wallet',
    );
    expect(
      await tokenStore.readSessionCredential(
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 1,
      ),
      isNull,
    );
    expect(
      authority.commands.map((command) => command['command']),
      ['read_record', 'read_record', 'read_record', 'complete_retirement'],
    );
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
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(authority.commands[1]['command'], 'read_record');
    expect(authority.commands.last['command'], 'complete_retirement');
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
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final epoch = controller.state.epoch;
    expect(await tokenStore.clearSessionCredential(credential), isTrue);

    await controller.onCredentialMissing(epoch: epoch);

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(authority.commands[1]['command'], 'read_record');
    expect(authority.commands.last['command'], 'complete_retirement');
  });

  test('definitive rejection retires only the exact current credential',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      _response(
        sequence: 5,
        state: _ready(),
        outcome: 'credential_confirmation_rejected',
      ),
      ..._successfulRetirementResponses(),
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
    final repository = _RejectedAuthRepository();
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: repository,
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'credential-confirmation' => 'confirm-http-a',
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final identity = controller.state;

    await controller.onUnauthorized(
      credential: testCredentialLease(
        epoch: identity.epoch,
        token: 'token-a',
        sessionId: identity.sessionId,
        credentialRef: identity.credentialRef,
        credentialGeneration: identity.credentialGeneration,
      ),
    );

    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(repository.confirmedCredentials.single.token, 'token-a');
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
    });
  });

  for (final entry in <(String, AuthRepository Function())>[
    ('accepted', _AcceptedAuthRepository.new),
    ('unavailable', _UnavailableAuthRepository.new),
  ]) {
    test('credential confirmation ${entry.$1} preserves Ready authority',
        () async {
      final authority = _ScriptedAuthority([
        _response(sequence: 5, state: _ready(), outcome: 'record_read'),
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
      });
      final controller = SessionController(
        tokenStore: tokenStore,
        guestFlag: AuthGuestFlag(),
        repository: entry.$2(),
        sessionAuthority: authority,
        sessionHost: const InlineSessionHostLifecycle(),
        clearWebSessionData: () async => true,
        clearSessionNotifications: () async => true,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      final identity = controller.state;

      await controller.onUnauthorized(
        credential: testCredentialLease(
          epoch: identity.epoch,
          token: 'token-a',
          sessionId: identity.sessionId,
          credentialRef: identity.credentialRef,
          credentialGeneration: identity.credentialGeneration,
        ),
      );

      expect(controller.state.sameScopeAs(identity), isTrue);
      expect(
        authority.commands.map((command) => command['command']),
        ['read_record'],
      );
    });
  }

  test('duplicate logout commits one successor', () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(),
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
    });
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    final first = controller.logout();
    final duplicate = controller.logout();

    expect(await first, isTrue);
    expect(await duplicate, isFalse);
    expect(controller.state.sessionId, 'logged-out-b');
    expect(
      authority.commands
          .where((command) => command['command'] == 'complete_retirement'),
      hasLength(1),
    );
  });

  test('authenticated guest choice uses ordinary retirement in-process',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(),
      _response(
        sequence: 8,
        state: _loggedOut(sessionId: 'guest-c', mode: 'guest'),
        outcome: 'logged_out_updated',
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
    });
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        'guest' => 'guest-c',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    await controller.continueAsGuest();

    expect(controller.state.phase, IdentityPhase.guest);
    expect(controller.state.sessionId, 'guest-c');
    expect(
      authority.commands.map((command) => command['command']),
      [
        'read_record',
        'read_record',
        'read_record',
        'complete_retirement',
        'update_logged_out',
      ],
    );
  });

  test('different participant retires A then activates B in-process', () async {
    const namespaceB = 'bbbbbbbbbbbbbbbb';
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(),
      _response(
        sequence: 8,
        state: _activating(
          phase: 'persist_credential',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
        ),
        outcome: 'activation_started',
      ),
      _response(
        sequence: 9,
        state: _activating(
          phase: 'bind_namespace',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 10,
        state: _activating(
          phase: 'reconcile_account',
          predecessorSessionId: 'logged-out-b',
          sessionId: 'session-b',
          transitionId: 'login-b',
          credentialRef: 'credential-b',
          credentialGeneration: 1,
          userNamespace: namespaceB,
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
    final bucket = NetworkPrefs.bucketForAddress('address-a');
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
    });
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        'session' => 'session-b',
        'transition' => 'login-b',
        'credential' => 'credential-b',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    final accepted = await controller.completeLogin(
      const AuthSession(
        token: 'token-b',
        participant: Participant(
          id: 8,
          email: '8@example.com',
          emailConfirmed: true,
          identityHash: namespaceB,
        ),
      ),
    );

    expect(accepted, isTrue);
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.participantId, 8);
    expect(controller.state.sessionId, 'session-b');
    expect(
      (await tokenStore.readSessionCredential(
        sessionId: 'session-b',
        credentialRef: 'credential-b',
        credentialGeneration: 1,
      ))
          ?.token,
      'token-b',
    );
  });

  test('guest choice is committed as a fresh logged-out incarnation', () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 0, state: _loggedOut(), outcome: 'record_read'),
      _response(
        sequence: 1,
        state: _loggedOut(sessionId: 'guest-a', mode: 'guest'),
        outcome: 'logged_out_updated',
      ),
    ]);
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => kind == 'guest' ? 'guest-a' : 'unused',
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    await controller.continueAsGuest();

    expect(controller.state.phase, IdentityPhase.guest);
    expect(controller.state.sessionId, 'guest-a');
    expect(authority.commands[1], {
      'command': 'update_logged_out',
      'expected': {
        'sequence': 0,
        'session_id': 'logged-out-a',
        'state': 'logged_out',
        'transition_id': null,
      },
      'successor_logged_out_session_id': 'guest-a',
      'mode': 'guest',
      'network': null,
    });
  });

  test('logged-out network change commits before operational restart',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 0, state: _loggedOut(), outcome: 'record_read'),
      _response(sequence: 0, state: _loggedOut(), outcome: 'record_read'),
      _response(
        sequence: 1,
        state: _loggedOut(sessionId: 'logged-out-b'),
        outcome: 'logged_out_updated',
        network: 'internal',
      ),
    ]);
    var restarts = 0;
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => kind == 'successor'
          ? 'logged-out-b'
          : throw StateError('Unexpected id kind $kind'),
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
      restartAfterNetworkChange: () async => restarts++,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    await controller.changeNetwork('internal');

    expect(authority.commands[1]['command'], 'read_record');
    expect(authority.commands[2], {
      'command': 'update_logged_out',
      'expected': {
        'sequence': 0,
        'session_id': 'logged-out-a',
        'state': 'logged_out',
        'transition_id': null,
      },
      'successor_logged_out_session_id': 'logged-out-b',
      'mode': 'signed_out',
      'network': 'internal',
    });
    expect(NetworkPrefs.currentNetwork, 'internal');
    expect(
      (await SharedPreferences.getInstance())
          .getString(NetworkPrefs.networkKey),
      'internal',
    );
    expect(restarts, 1);
  });

  test('Ready network change adopts the network only in retirement commit',
      () async {
    final authority = _ScriptedAuthority([
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      _response(sequence: 5, state: _ready(), outcome: 'record_read'),
      ..._successfulRetirementResponses(successorNetwork: 'internal'),
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
    });
    var restarts = 0;
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => switch (kind) {
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected id kind $kind'),
      },
      retireRuntimeAuthority: _retireRuntime,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
      restartAfterNetworkChange: () async => restarts++,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    await controller.changeNetwork('internal');

    expect(authority.commands[2]['command'], 'read_record');
    expect(authority.commands.last['command'], 'complete_retirement');
    expect(NetworkPrefs.currentNetwork, 'internal');
    expect(restarts, 1);
  });

  test('network change explicitly rolls an in-flight activation back first',
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
        sequence: 3,
        state: _activating(
          phase: 'reconcile_account',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: 'aaaaaaaaaaaaaaaa',
        ),
        outcome: 'record_read',
      ),
      _response(
        sequence: 4,
        state: _activating(
          phase: 'rollback_clear',
          credentialRef: 'credential-a',
          credentialGeneration: 1,
          userNamespace: 'aaaaaaaaaaaaaaaa',
          rollbackLoggedOutSessionId: 'logged-out-b',
        ),
        outcome: 'activation_rolling_back',
      ),
      _response(
        sequence: 5,
        state: _activating(
          phase: 'rollback_commit',
          rollbackLoggedOutSessionId: 'logged-out-b',
        ),
        outcome: 'activation_advanced',
      ),
      _response(
        sequence: 6,
        state: _loggedOut(sessionId: 'logged-out-b'),
        outcome: 'activation_logged_out',
      ),
      _response(
        sequence: 6,
        state: _loggedOut(sessionId: 'logged-out-b'),
        outcome: 'record_read',
      ),
      _response(
        sequence: 7,
        state: _loggedOut(sessionId: 'logged-out-c'),
        outcome: 'logged_out_updated',
        network: 'internal',
      ),
    ]);
    final ids = <String, String>{
      'session': 'session-a',
      'transition': 'login-a',
      'credential': 'credential-a',
      'rollback': 'logged-out-b',
      'successor': 'logged-out-c',
    };
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopAuthRepository(),
      sessionAuthority: authority,
      sessionHost: const InlineSessionHostLifecycle(),
      newAuthorityId: (kind) => ids[kind]!,
      clearWebSessionData: () async => true,
      clearSessionNotifications: () async => true,
      restartAfterNetworkChange: () async {},
    );
    addTearDown(controller.dispose);

    await controller.restore();
    expect(await controller.completeLogin(_session('token-a')), isTrue);
    await controller.changeNetwork('internal');

    final cancellation = authority.commands.singleWhere(
      (command) =>
          command['command'] == 'recover_activation' &&
          (command['evidence'] as Map)['kind'] == 'explicit_cancellation',
    );
    expect(cancellation['rollback_logged_out_session_id'], 'logged-out-b');
    expect(authority.commands.last['command'], 'update_logged_out');
    expect(authority.commands.last['successor_logged_out_session_id'],
        'logged-out-c');
  });
}
