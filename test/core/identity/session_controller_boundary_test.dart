import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_cleanup.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/session_authority_test_helpers.dart';

class _NoopLogoutRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

class _SessionAuthorityRepository extends _NoopLogoutRepository {
  _SessionAuthorityRepository(this._resolve);

  final Future<AuthSession> Function(String token) _resolve;
  final resolvedTokens = <String>[];
  final confirmedCredentials = <AuthCredentialLease>[];

  @override
  Future<AuthSession> resolveBearerSession(
    String token, {
    int? legacyParticipantId,
  }) {
    resolvedTokens.add(token);
    return _resolve(token);
  }

  @override
  Future<AuthSession> confirmBearerSession(
    AuthCredentialLease credential,
  ) {
    confirmedCredentials.add(credential);
    return _resolve(credential.token);
  }
}

class _BlockingLogoutRepository extends AuthRepository {
  final revokedTokens = <String>[];
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> logout(String sessionToken) async {
    revokedTokens.add(sessionToken);
    if (!started.isCompleted) started.complete();
    await release.future;
  }
}

class _TerminalResetProbe {
  _TerminalResetProbe(this.tokenStore);

  final AuthTokenStore tokenStore;
  final reasons = <String>[];
  final phasesAtEntry = <IdentityPhase>[];
  final tokensBeforeWipe = <String?>[];
  final hadNextLaunchWriter = <bool>[];

  Future<void> call({
    required String reason,
    Future<void> Function()? prepareNextLaunch,
  }) async {
    reasons.add(reason);
    phasesAtEntry.add(IdentitySnapshots.current.phase);
    tokensBeforeWipe.add(await tokenStore.read());
    hadNextLaunchWriter.add(prepareNextLaunch != null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await tokenStore.clear();
    expect(await tokenStore.read(), isNull);
    await prepareNextLaunch?.call();
  }
}

/// A 16-hex namespace shaped like the server's `identity_hash`, distinct per
/// participant.
String _namespaceFor(int participantId) =>
    participantId.toString().padLeft(16, 'a');

AuthSession _session(String token, int participantId) => AuthSession(
      token: token,
      participant: Participant(
        id: participantId,
        email: '$participantId@example.com',
        emailConfirmed: true,
        identityHash: _namespaceFor(participantId),
      ),
    );

/// Counts the side effects a sign-out must perform on the live runtime.
class _RuntimeProbe {
  _RuntimeProbe({
    this.webSessionClear = _clearedOk,
    this.suspendNodeBehaviour,
    this.rotateNativeGenerationResult = true,
    this.sessionNotificationsResult = true,
  });

  static Future<bool> _clearedOk() async => true;

  /// The native reply a WebView session clear should produce. Reachable
  /// production values are `true`, `false`, a throw, and a timeout.
  final Future<bool> Function() webSessionClear;
  final Future<void> Function()? suspendNodeBehaviour;
  final bool rotateNativeGenerationResult;
  final bool sessionNotificationsResult;

  var suspendedNodes = 0;
  var clearedWebSessions = 0;
  var rotatedNativeGenerations = 0;
  var clearedNotifications = 0;
  var resetProcessState = 0;
  var signOutCompletions = 0;

  Future<void> suspendNode() async {
    suspendedNodes += 1;
    final behaviour = suspendNodeBehaviour;
    if (behaviour != null) await behaviour();
  }

  Future<bool> clearWebSessionData() async {
    clearedWebSessions += 1;
    return webSessionClear();
  }

  Future<bool> rotateNativeGeneration() async {
    rotatedNativeGenerations += 1;
    return rotateNativeGenerationResult;
  }

  Future<bool> clearSessionNotifications() async {
    clearedNotifications += 1;
    return sessionNotificationsResult;
  }

  Future<void> resetSessionScopedProcessState() async => resetProcessState += 1;

  void onSignOutCompleted() => signOutCompletions += 1;
}

SessionController _controller(
  AuthTokenStore tokenStore,
  _TerminalResetProbe reset, {
  AuthRepository? repository,
  _RuntimeProbe? runtime,
  SignOutFence? signOutFence,
}) =>
    SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: repository ?? _NoopLogoutRepository(),
      suspendNode: runtime == null ? () async {} : runtime.suspendNode,
      clearWebSessionData:
          runtime == null ? () async => true : runtime.clearWebSessionData,
      rotateNativeGeneration:
          runtime == null ? () async => true : runtime.rotateNativeGeneration,
      clearSessionNotifications: runtime == null
          ? () async => true
          : runtime.clearSessionNotifications,
      resetSessionScopedProcessState: runtime?.resetSessionScopedProcessState,
      onSignOutCompleted: runtime?.onSignOutCompleted,
      // The real fence is file-backed; these tests own no app directory.
      signOutFence: signOutFence ?? InMemorySignOutFence(),
      terminalReset: reset.call,
    );

void _seedReadyIdentity({
  String token = 'token-a',
  int participantId = 1,
}) {
  const address = 'ut1readyaccount';
  final bucket = NetworkPrefs.bucketForAddress(address);
  FlutterSecureStorage.setMockInitialValues({
    'auth:v3:session_token': token,
  });
  SharedPreferences.setMockInitialValues({
    'testnet:user:${_namespaceFor(participantId)}:accounts:index': jsonEncode([
      {
        'id': 'account-a',
        'name': 'Node Account',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': address,
        'publicKey': 'utpk1$address',
        'backupConfirmed': true,
        'isDemo': false,
      }
    ]),
    'testnet:user:${_namespaceFor(participantId)}:accounts:activeId':
        'account-a',
    'testnet:identity:namespace': _namespaceFor(participantId),
    'testnet:acct:$bucket:leaderboard:participant_id': participantId,
    'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  test('initial login stays in-process and enters account reconciliation',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth:v3:guest': true,
      'existing_preference': 'must remain',
    });
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.state.phase, IdentityPhase.guest);

    expect(await controller.completeLogin(_session('token-b', 2)), isTrue);

    expect(reset.reasons, isEmpty);
    expect(await tokenStore.read(), 'token-b');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('existing_preference'), 'must remain');
    expect(prefs.getBool('auth:v3:guest'), isNull);
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      2,
    );
    // The storage namespace is part of the crash-recovery payload: a
    // boot-restorable token must resolve THIS user's account registry, never
    // the previous one's.
    expect(prefs.getString('testnet:identity:namespace'), _namespaceFor(2));
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.participantId, 2);

    final reconciling = controller.state;
    expect(
      await controller.completeLogin(
        _session('token-c', 2),
        expectedIdentity: reconciling,
      ),
      isTrue,
    );
    expect(controller.state.sameScopeAs(reconciling), isTrue);
    expect(await tokenStore.read(), 'token-c');
    expect(reset.reasons, isEmpty);
  });

  test('same participant rotates its bearer without resetting', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();
    final ready = controller.state;

    expect(
      await controller.completeLogin(
        _session('token-a-renewed', 1),
        expectedIdentity: ready,
      ),
      isTrue,
    );

    expect(reset.reasons, isEmpty);
    expect(controller.state.sameScopeAs(ready), isTrue);
    expect(await tokenStore.read(), 'token-a-renewed');
  });

  test('different participant is discarded and forces current-user reset',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
      await controller.completeLogin(
        _session('token-b', 2),
        expectedIdentity: controller.state,
      ),
      isFalse,
    );

    expect(reset.reasons, ['different_participant_login']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(reset.tokensBeforeWipe, ['token-a']);
    expect(reset.hadNextLaunchWriter, [isFalse]);
    expect(await tokenStore.read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
  });

  test('signing out ends the session in-process, without a terminal reset',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe();
    final repository = _BlockingLogoutRepository();
    final controller = _controller(
      tokenStore,
      reset,
      repository: repository,
      runtime: runtime,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    // The whole point: no wipe, no inert surface, no dead process.
    expect(reset.reasons, isEmpty);
    expect(controller.state.phase, IdentityPhase.unauthenticated);

    // The session is gone locally whether or not the server ever answers —
    // the revocation below is still blocked at this point.
    expect(await tokenStore.read(), isNull);
    expect(runtime.suspendedNodes, 1,
        reason: 'the node was bound to the signed-out account');
    expect(runtime.clearedWebSessions, 1,
        reason: 'the shell would otherwise reload into an authenticated page');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:identity:namespace'), isNull);
    expect(prefs.getBool('testnet:account:reconcile_pending'), isNull);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      isNull,
    );

    // The wallet survives, addressable again by the same user's next login.
    expect(
      prefs.getString('testnet:user:${_namespaceFor(1)}:accounts:index'),
      isNotNull,
    );

    await repository.started.future;
    expect(repository.revokedTokens, ['token-a']);
    repository.release.complete();
  });

  test('a signed-out install boots to local-only mode, wallet still stored',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final controller = _controller(tokenStore, _TerminalResetProbe(tokenStore));
    addTearDown(controller.dispose);
    await controller.restore();
    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    final coldReset = _TerminalResetProbe(tokenStore);
    final coldController = _controller(tokenStore, coldReset);
    addTearDown(coldController.dispose);
    await coldController.restore();

    expect(coldController.state.phase, IdentityPhase.unauthenticated);
    expect(coldReset.reasons, isEmpty);
    // Signed out, the registry is not addressable — the namespace that
    // resolves it went with the session.
    expect(coldController.state.accountId, isNull);
    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.getString('testnet:accounts:index'), isNull);
    expect(
      coldPrefs.getString('testnet:user:${_namespaceFor(1)}:accounts:index'),
      isNotNull,
      reason: 'the accounts themselves are kept, just not resolvable',
    );
  });

  test('signing out twice cannot double-fire, and a guest sign-out is a no-op',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe();
    final controller = _controller(tokenStore, reset, runtime: runtime);
    addTearDown(controller.dispose);
    await controller.restore();
    final identity = controller.state;

    expect(await controller.logout(expectedIdentity: identity), isTrue);
    // The second call carries the now-superseded identity, exactly as a
    // duplicate bridge callback would.
    expect(await controller.logout(expectedIdentity: identity), isFalse);
    // And an unscoped call finds nothing left to sign out of.
    expect(await controller.logout(), isFalse);

    expect(runtime.clearedWebSessions, 1);
    expect(reset.reasons, isEmpty);
  });

  test('authenticated-to-guest is a terminal reset with no guest successor',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();

    await controller.continueAsGuest();

    expect(reset.reasons, ['authenticated_to_guest']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(reset.hadNextLaunchWriter, [isFalse]);
    expect(await tokenStore.read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
  });

  test('an exact authenticated 401 enters the terminal logout reset', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final repository = _SessionAuthorityRepository(
      (_) async => throw AuthException(
        AuthErrorKind.invalidCredentials,
        'Unauthenticated.',
      ),
    );
    final controller = _controller(
      tokenStore,
      reset,
      repository: repository,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final credential = testCredentialLease(
      epoch: controller.state.epoch,
      token: 'token-a',
    );

    await controller.onUnauthorized(credential: credential);

    expect(repository.resolvedTokens, isEmpty);
    expect(repository.confirmedCredentials.map((value) => value.token), [
      'token-a',
    ]);
    expect(reset.reasons, ['session_expired']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(await tokenStore.read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
  });

  test('an endpoint 401 is ignored when the session authority accepts it',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final repository = _SessionAuthorityRepository(
      (token) async => _session(token, 1),
    );
    final controller = _controller(
      tokenStore,
      reset,
      repository: repository,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final credential = testCredentialLease(
      epoch: controller.state.epoch,
      token: 'token-a',
    );

    await controller.onUnauthorized(credential: credential);

    expect(repository.resolvedTokens, isEmpty);
    expect(repository.confirmedCredentials.map((value) => value.token), [
      'token-a',
    ]);
    expect(reset.reasons, isEmpty);
    expect(await tokenStore.read(), 'token-a');
    expect(controller.state.phase, IdentityPhase.ready);
  });

  test('an endpoint 401 is ignored when session validation is unavailable',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final repository = _SessionAuthorityRepository(
      (_) async => throw AuthException(
        AuthErrorKind.network,
        'Session service unavailable.',
      ),
    );
    final controller = _controller(
      tokenStore,
      reset,
      repository: repository,
    );
    addTearDown(controller.dispose);
    await controller.restore();
    final credential = testCredentialLease(
      epoch: controller.state.epoch,
      token: 'token-a',
    );

    await controller.onUnauthorized(credential: credential);

    expect(repository.resolvedTokens, isEmpty);
    expect(repository.confirmedCredentials.map((value) => value.token), [
      'token-a',
    ]);
    expect(reset.reasons, isEmpty);
    expect(await tokenStore.read(), 'token-a');
    expect(controller.state.phase, IdentityPhase.ready);
  });

  test('a sign-out clears every session-scoped runtime fence', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe();
    final fence = InMemorySignOutFence();
    final controller = _controller(
      tokenStore,
      reset,
      runtime: runtime,
      signOutFence: fence,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    expect(reset.reasons, isEmpty);
    // The native generation is retired BEFORE the runtime teardown, so an
    // alarm or headless recovery event landing during it is already stale.
    expect(runtime.rotatedNativeGenerations, 1);
    expect(runtime.suspendedNodes, 1);
    expect(runtime.clearedNotifications, 1);
    expect(runtime.resetProcessState, 1);
    expect(runtime.signOutCompletions, 1,
        reason: 'the settled-sign-out signal drives document replacement');
    expect(fence.raiseCount, 1);
    expect(fence.raised, isFalse,
        reason: 'the crash fence is lowered once the boundary settles');
  });

  test('an undurable crash fence is not acknowledged as a sign-out', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe();
    final fence = InMemorySignOutFence(raiseSucceeds: false);
    final controller = _controller(
      tokenStore,
      reset,
      runtime: runtime,
      signOutFence: fence,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
        await controller.logout(expectedIdentity: controller.state), isFalse);

    // Without a durable fence, bearer and namespace retirement stop being
    // crash-atomic, so the bearer is not touched here at all — the boundary
    // escalates to the one that erases both.
    expect(reset.reasons, ['signout_cleanup_unconfirmed']);
    expect(runtime.rotatedNativeGenerations, 0);
    expect(runtime.suspendedNodes, 0);
    expect(runtime.signOutCompletions, 0);
  });

  test('a throwing mandatory step escalates in THIS process', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    // `RustBackendService.stopNode()` deliberately throws when process-global
    // shutdown cannot be confirmed; every prefs/native call can throw too.
    final runtime = _RuntimeProbe(
      suspendNodeBehaviour: () async => throw StateError('node stuck'),
    );
    final controller = _controller(tokenStore, reset, runtime: runtime);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
        await controller.logout(expectedIdentity: controller.state), isFalse);

    // Not left to a hypothetical next boot: an uncaught throw would strand the
    // identity in `transitioning` with no completion, no document replacement
    // and no reset.
    expect(reset.reasons, ['signout_cleanup_unconfirmed']);
    expect(runtime.signOutCompletions, 0);
  });

  test('a failed notification clear does not block the sign-out', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe(sessionNotificationsResult: false);
    final controller = _controller(tokenStore, reset, runtime: runtime);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    // Tray text leaks the retired session's content, not its authority, so it
    // is warned about rather than escalated into a device-wide wipe.
    expect(runtime.clearedNotifications, 1);
    expect(reset.reasons, isEmpty);
    expect(runtime.signOutCompletions, 1);
  });

  test('an unconfirmed native generation retirement is not acknowledged',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe(rotateNativeGenerationResult: false);
    final controller = _controller(tokenStore, reset, runtime: runtime);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
        await controller.logout(expectedIdentity: controller.state), isFalse);

    // Leaving the previous generation live is exactly the producer race the
    // terminal boundary existed to close, so this fails closed into it.
    expect(reset.reasons, ['signout_cleanup_unconfirmed']);
    expect(runtime.signOutCompletions, 0);
    expect(await tokenStore.read(), isNull);
  });

  group('a mandatory web-session purge cannot fail open', () {
    Future<void> expectTerminal(Future<bool> Function() webSessionClear) async {
      _seedReadyIdentity();
      final tokenStore = AuthTokenStore();
      final reset = _TerminalResetProbe(tokenStore);
      final runtime = _RuntimeProbe(webSessionClear: webSessionClear);
      final controller = _controller(tokenStore, reset, runtime: runtime);
      addTearDown(controller.dispose);
      await controller.restore();

      expect(
          await controller.logout(expectedIdentity: controller.state), isFalse);

      // A retained cookie/storage jar silently re-authenticates the next page
      // load, so an unconfirmed clear must not resolve `loggedOut` — it is
      // retried, then escalated to the boundary that does wipe the jar.
      expect(runtime.clearedWebSessions, 2, reason: 'retried once');
      expect(reset.reasons, ['signout_cleanup_unconfirmed']);
      expect(runtime.signOutCompletions, 0);
      expect(await tokenStore.read(), isNull);
    }

    test('a false reply escalates', () => expectTerminal(() async => false));

    test('a throw escalates',
        () => expectTerminal(() async => throw StateError('channel down')));

    test('a timeout escalates', () async {
      await expectTerminal(
        () => Future<bool>.delayed(const Duration(seconds: 5), () => true)
            .timeout(
          const Duration(milliseconds: 10),
        ),
      );
    });
  });

  test(
      'a sign-out interrupted before the namespace is retired repairs itself '
      'on the next boot', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final fence = InMemorySignOutFence();
    // The native generation rotation sits between the bearer clear and the
    // namespace retirement — the same window a process death would open.
    final runtime = _RuntimeProbe(rotateNativeGenerationResult: false);
    // Terminal reset is what a real unconfirmed boundary escalates to; this
    // probe stops short of wiping so the interrupted on-disk state stays
    // observable for the cold-boot half of the test.
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: _NoopLogoutRepository(),
      suspendNode: runtime.suspendNode,
      clearWebSessionData: runtime.clearWebSessionData,
      rotateNativeGeneration: runtime.rotateNativeGeneration,
      clearSessionNotifications: runtime.clearSessionNotifications,
      signOutFence: fence,
      terminalReset: ({required reason, prepareNextLaunch}) async {
        reset.reasons.add(reason);
      },
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
        await controller.logout(expectedIdentity: controller.state), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(reset.reasons, ['signout_cleanup_unconfirmed']);
    expect(await tokenStore.read(), isNull, reason: 'the bearer is gone');
    expect(prefs.getString('testnet:identity:namespace'), isNotNull,
        reason: 'the namespace retirement never ran');
    expect(fence.raised, isTrue, reason: 'the fence outlives the failure');

    // Without the fence this cold boot would resolve the interrupted user's
    // active account and publish it as a locally-signable identity.
    final coldReset = _TerminalResetProbe(tokenStore);
    final coldRuntime = _RuntimeProbe();
    final coldController = _controller(
      tokenStore,
      coldReset,
      runtime: coldRuntime,
      signOutFence: fence,
    );
    addTearDown(coldController.dispose);
    await coldController.restore();

    expect(coldReset.reasons, isEmpty);
    expect(coldController.state.phase, IdentityPhase.unauthenticated);
    expect(coldController.state.accountId, isNull);
    expect(coldController.state.address, isNull);
    expect(coldController.state.allowsSigning, isFalse);
    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.getString('testnet:identity:namespace'), isNull);
    expect(fence.raised, isFalse);
  });

  test('an interrupted sign-out is completed even when the bearer survived it',
      () async {
    // The fence is durable BEFORE the bearer clear, so a crash in that first
    // window leaves the token, the namespace AND the fence behind.
    FlutterSecureStorage.setMockInitialValues({
      'auth:v3:session_token': 'token-a',
    });
    SharedPreferences.setMockInitialValues({
      'testnet:identity:namespace': _namespaceFor(1),
    });
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final runtime = _RuntimeProbe();
    final fence = InMemorySignOutFence(raised: true);
    final controller = _controller(
      tokenStore,
      reset,
      runtime: runtime,
      signOutFence: fence,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(reset.reasons, isEmpty);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(await tokenStore.read(), isNull,
        reason: 'a fenced sign-out is completed, not resumed as a session');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:identity:namespace'), isNull);
    expect(fence.raised, isFalse);
  });

  test('session cleanup retains a registry with no identity namespace',
      () async {
    final index = jsonEncode([
      {
        'id': 'account-a',
        'name': 'Node Account',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': 'ut1readyaccount',
        'publicKey': 'utpk1ut1readyaccount',
        'backupConfirmed': true,
        'isDemo': false,
      }
    ]);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': index,
      'testnet:accounts:activeId': 'account-a',
      'testnet:accounts:adopting': _namespaceFor(1),
      'testnet:identity:namespace': _namespaceFor(1),
    });
    expect(
      await clearCompatibilitySessionAuthority(AuthGuestFlag()),
      isTrue,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:accounts:index'), index);
    expect(prefs.getString('testnet:accounts:activeId'), 'account-a');
    expect(prefs.getString('testnet:accounts:adopting'), _namespaceFor(1));
    expect(prefs.getString('testnet:identity:namespace'), isNull);
  });

  test('a namespaced registry is kept across a sign-out', () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('testnet:user:${_namespaceFor(1)}:accounts:index'),
      isNotNull,
      reason: 'segregation is proven, so the wallet survives',
    );
    expect(controller.state.allowsSigning, isFalse);
  });

  test('a missing current credential enters the terminal logout reset',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();
    final epoch = controller.state.epoch;
    await tokenStore.clear();

    await controller.onCredentialMissing(epoch: epoch);

    expect(reset.reasons, ['session_credential_missing']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(reset.tokensBeforeWipe, [null]);
    expect(controller.state.phase, IdentityPhase.transitioning);
  });
}
