import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopLogoutRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
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

AuthSession _session(String token, int participantId) => AuthSession(
      token: token,
      participant: Participant(
        id: participantId,
        email: '$participantId@example.com',
        emailConfirmed: true,
      ),
    );

SessionController _controller(
  AuthTokenStore tokenStore,
  _TerminalResetProbe reset, {
  AuthRepository? repository,
}) =>
    SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: repository ?? _NoopLogoutRepository(),
      suspendNode: () async {},
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
    'testnet:accounts:index': jsonEncode([
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
    'testnet:accounts:activeId': 'account-a',
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

  test('logout reset does not wait for remote revocation or publish successor',
      () async {
    _seedReadyIdentity();
    final tokenStore = AuthTokenStore();
    final reset = _TerminalResetProbe(tokenStore);
    final repository = _BlockingLogoutRepository();
    final controller = _controller(
      tokenStore,
      reset,
      repository: repository,
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.logout(expectedIdentity: controller.state), isTrue);

    expect(reset.reasons, ['logout']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(await tokenStore.read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
    await repository.started.future;
    expect(repository.revokedTokens, ['token-a']);

    final coldReset = _TerminalResetProbe(tokenStore);
    final coldController = _controller(tokenStore, coldReset);
    addTearDown(coldController.dispose);
    await coldController.restore();
    expect(coldController.state.phase, IdentityPhase.unauthenticated);
    expect(coldReset.reasons, isEmpty);
    final coldPrefs = await SharedPreferences.getInstance();
    expect(coldPrefs.getString('testnet:accounts:index'), isNull);
    expect(coldPrefs.getString('testnet:accounts:activeId'), isNull);

    repository.release.complete();
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
    final controller = _controller(tokenStore, reset);
    addTearDown(controller.dispose);
    await controller.restore();
    final credential = AuthCredentialLease(
      epoch: controller.state.epoch,
      token: 'token-a',
    );

    await controller.onUnauthorized(credential: credential);

    expect(reset.reasons, ['session_expired']);
    expect(reset.phasesAtEntry, [IdentityPhase.transitioning]);
    expect(await tokenStore.read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
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
