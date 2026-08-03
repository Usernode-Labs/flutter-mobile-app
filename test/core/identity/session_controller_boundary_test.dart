import 'dart:async';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/services/session_runtime_boundary.dart';
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
  _BlockingLogoutRepository(this.tokenStore);

  final AuthTokenStore tokenStore;
  final revokedTokens = <String>[];
  final tokensObservedAtRevoke = <String?>[];
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> logout(String sessionToken) async {
    revokedTokens.add(sessionToken);
    tokensObservedAtRevoke.add(await tokenStore.read());
    if (!started.isCompleted) started.complete();
    await release.future;
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
  AuthTokenStore tokenStore, {
  AuthRepository? repository,
}) =>
    SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: repository ?? _NoopLogoutRepository(),
      suspendNode: () async {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = SessionRuntimeBoundary.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
    boundary.resetForTesting();
  });

  tearDown(boundary.resetForTesting);

  test('initial login stays in place and same participant rotates its token',
      () async {
    var replacements = 0;
    boundary.register((_, persistSession) async {
      replacements += 1;
      await persistSession();
    });

    final tokenStore = AuthTokenStore();
    final controller = _controller(tokenStore);
    addTearDown(controller.dispose);
    await controller.restore();

    expect(await controller.completeLogin(_session('token-a', 1)), isTrue);
    await controller.reconcileSucceeded(
      epoch: controller.state.epoch,
      accountId: 'account-a',
      address: 'address-a',
      participantId: 1,
    );
    final ready = controller.state;

    expect(
      await controller.completeLogin(
        _session('token-a-renewed', 1),
        expectedIdentity: ready,
      ),
      isTrue,
    );
    expect(replacements, 0);
    expect(controller.state.sameScopeAs(ready), isTrue);
    expect(await tokenStore.read(), 'token-a-renewed');
  });

  test('same-participant rotation stores the new token before revoking old',
      () async {
    final tokenStore = AuthTokenStore();
    final repository = _BlockingLogoutRepository(tokenStore);
    final controller = _controller(tokenStore, repository: repository);
    addTearDown(controller.dispose);
    await controller.restore();
    await controller.completeLogin(_session('token-a', 1));
    await controller.reconcileSucceeded(
      epoch: controller.state.epoch,
      accountId: 'account-a',
      address: 'address-a',
      participantId: 1,
    );

    final rotation = controller.completeLogin(
      _session('token-a-renewed', 1),
      expectedIdentity: controller.state,
    );
    await repository.started.future;

    expect(repository.revokedTokens, ['token-a']);
    expect(repository.tokensObservedAtRevoke, ['token-a-renewed']);
    repository.release.complete();
    expect(await rotation, isTrue);
  });

  test('participant replacement writes the new token only after cleanup',
      () async {
    final tokenStore = AuthTokenStore();
    final controller = _controller(tokenStore);
    addTearDown(controller.dispose);
    await controller.restore();
    await controller.completeLogin(_session('token-a', 1));
    await controller.reconcileSucceeded(
      epoch: controller.state.epoch,
      accountId: 'account-a',
      address: 'address-a',
      participantId: 1,
    );

    final cleanupStarted = Completer<void>();
    final releaseCleanup = Completer<void>();
    boundary.register((change, persistSession) async {
      expect(change, SessionRuntimeChange.participantReplacement);
      controller.retireForRuntimeRestart();
      cleanupStarted.complete();
      await releaseCleanup.future;
      await persistSession();
    });

    final replacement = controller.completeLogin(
      _session('token-b', 2),
      expectedIdentity: controller.state,
    );
    await cleanupStarted.future;

    expect(await tokenStore.read(), isNull);
    expect(await controller.completeLogin(_session('token-c', 3)), isFalse);

    releaseCleanup.complete();
    expect(await replacement, isTrue);
    expect(await tokenStore.read(), 'token-b');
  });

  test('logout is durable before cleanup and waits for replacement', () async {
    final tokenStore = AuthTokenStore();
    final controller = _controller(tokenStore);
    addTearDown(controller.dispose);
    await controller.restore();
    await controller.completeLogin(_session('token-a', 1));

    final cleanupStarted = Completer<void>();
    final releaseCleanup = Completer<void>();
    boundary.register((change, persistSession) async {
      expect(change, SessionRuntimeChange.logout);
      controller.retireForRuntimeRestart();
      cleanupStarted.complete();
      await releaseCleanup.future;
      await persistSession();
    });

    final logout = controller.logout(expectedIdentity: controller.state);
    await cleanupStarted.future;
    expect(await tokenStore.read(), isNull);

    releaseCleanup.complete();
    expect(await logout, isTrue);
  });

  test('headless logout uses the hard-stop hook', () async {
    var ordinarySuspends = 0;
    var hardStops = 0;
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopLogoutRepository(),
      suspendNode: () async => ordinarySuspends += 1,
      hardStopRuntime: () async => hardStops += 1,
    );
    addTearDown(controller.dispose);

    await controller.restore();
    await controller.completeLogin(_session('token-a', 1));
    expect(await controller.logout(), isTrue);

    expect(ordinarySuspends, 1);
    expect(hardStops, 1);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
  });
}
