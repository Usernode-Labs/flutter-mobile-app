import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

/// Records whether the login recovery payload (reconcile-pending marker +
/// participant id staged in the guest bucket) was already persisted when the
/// token write made the session boot-restorable. A crash after the token
/// write must find the payload in place, or the boot reconcile "succeeds"
/// with nothing to migrate and the participant id is lost.
///
/// Also records the published identity phase at write time: the gate must
/// close (`transitioning` published) BEFORE any persistence, so
/// concurrent signing/node-start checks can't pass under the old identity.
class _OrderProbeTokenStore extends AuthTokenStore {
  bool payloadPersistedBeforeTokenWrite = false;
  IdentityPhase? phaseAtTokenWrite;

  @override
  Future<void> write(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final stagedId = prefs.getInt(NetworkPrefs.prefixAccountKeyFor(
        'leaderboard:participant_id', NetworkPrefs.guestBucket));
    final markerSet =
        prefs.getBool(NetworkPrefs.prefixKey('account:reconcile_pending')) ??
            false;
    payloadPersistedBeforeTokenWrite = stagedId != null && markerSet;
    phaseAtTokenWrite = IdentitySnapshots.current.phase;
    await super.write(token);
  }
}

class _BlockingLogoutRepository extends AuthRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  String? token;

  @override
  Future<void> logout(String sessionToken) async {
    token = sessionToken;
    started.complete();
    await release.future;
  }
}

AuthSession _session(String token) => AuthSession(
      token: token,
      participant:
          const Participant(id: 1, email: 'a@b.com', emailConfirmed: true),
    );

Future<AuthStatus> _settle(ProviderContainer c) async {
  // The provider starts restore eagerly; awaiting the idempotent method joins
  // that exact run and avoids timing the number of persistence microtasks.
  await c.read(identityProvider.notifier).restore();
  return c.read(authStatusProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  test('boots to unauthenticated when nothing stored', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.unauthenticated);
    expect(c.read(identityProvider).phase, IdentityPhase.unauthenticated);
  });

  test(
      'boots into the reconciling phase when a token is stored but the '
      'account was never confirmed', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);
    // No account bucket carries a confirmed participant id, so the boot
    // routes through reconciling rather than trusting local state.
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
  });

  test(
      'boots directly to ready when the previous session settled '
      '(account bucket owner recorded, no marker)', () async {
    const address = 'ut1activeaccount';
    final bucket = NetworkPrefs.bucketForAddress(address);
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        {
          'id': 'acc_1',
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
      'testnet:accounts:activeId': 'acc_1',
      // A past reconcile recorded participant 7 as this bucket's owner and
      // cleared the marker. The lifecycle ownership proof distinguishes this
      // from a legacy token/account pair that still needs one provision call.
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
      'testnet:acct:$bucket:identity:provisioned_season': 4,
      'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);
    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.ready);
    expect(identity.participantId, 7);
    expect(identity.address, address);
    expect(identity.provisionedSeasonId, 4);
    expect(NetworkPrefs.activeBucket, bucket);
  });

  test(
      'legacy token and active account must reconcile before boot can trust '
      'their ownership', () async {
    const address = 'ut1legacyaccount';
    final bucket = NetworkPrefs.bucketForAddress(address);
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-legacy'});
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        {
          'id': 'acc_legacy',
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
      'testnet:accounts:activeId': 'acc_legacy',
      // Legacy state has an owner id and no pending marker, but predates the
      // lifecycle proof written by a confirmed provision/reconcile.
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
      'testnet:acct:guest:leaderboard:participant_id': 999,
    });

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);

    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.reconciling);
    expect(identity.participantId, isNull);
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      isNull,
    );
  });

  test('pending marker takes precedence over a persisted ownership proof',
      () async {
    const address = 'ut1crashafterproof';
    final bucket = NetworkPrefs.bucketForAddress(address);
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        {
          'id': 'acc_1',
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
      'testnet:accounts:activeId': 'acc_1',
      'testnet:acct:$bucket:leaderboard:participant_id': 7,
      'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
      // Crash state after the proof write but before marker removal.
      'testnet:account:reconcile_pending': true,
    });

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);

    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(c.read(identityProvider).participantId, isNull);
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
  });

  test(
      'boots into reconciling when a reconcile-pending marker survives a '
      'crash, restoring the staged participant id', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    SharedPreferences.setMockInitialValues({
      'testnet:account:reconcile_pending': true,
      'testnet:acct:guest:leaderboard:participant_id': 42,
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);
    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.reconciling);
    expect(identity.participantId, 42);
    // The previous user's bucket is not activated while ownership is
    // unsettled.
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
  });

  test('boots to guest when guest flag set', () async {
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.guest);
  });

  test('completeLogin persists token and enters reconciling', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(c.read(identityProvider).participantId, 1);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('completeLogin closes gates synchronously before replacing the token',
      () async {
    final stopStarted = Completer<void>();
    final stopRelease = Completer<void>();
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () {
        stopStarted.complete();
        return stopRelease.future;
      },
    );
    addTearDown(controller.dispose);

    final login = controller.completeLogin(_session('sess-2'));
    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.allowsNodeStart, isFalse);
    await stopStarted.future;
    // The crash-recovery payload and replacement credential are durable even
    // while shutdown is still pending; the identity remains fail-closed.
    expect(await AuthTokenStore().read(), 'sess-2');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
    expect(controller.state.phase, IdentityPhase.transitioning);

    stopRelease.complete();
    await login;
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(await AuthTokenStore().read(), 'sess-2');
  });

  test('completeLogin stages the session user id in the guest bucket',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    // Until the reconcile confirms an account bucket, the id lives in the
    // guest staging area and on the identity snapshot itself.
    expect(await loadParticipantIdInBucket(NetworkPrefs.guestBucket), 1);
    expect(await c.read(participantIdProvider.future), 1);
  });

  test(
      'completeLogin persists the recovery payload before the token becomes '
      'boot-restorable (crash-atomic login)', () async {
    final probe = _OrderProbeTokenStore();
    final c = ProviderContainer(overrides: [
      authTokenStoreProvider.overrideWithValue(probe),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    expect(probe.payloadPersistedBeforeTokenWrite, isTrue);
  });

  test('reconcileSucceeded settles the identity to ready', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    expect(c.read(isReadyAuthenticatedProvider), isFalse);
    final epoch = c.read(identityProvider).epoch;
    final committed =
        await c.read(identityProvider.notifier).reconcileSucceeded(
              epoch: epoch,
              accountId: 'acc-1',
              address: 'addr-1',
              participantId: 1,
              provisionedSeasonId: 7,
            );
    expect(committed, isTrue);
    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.ready);
    expect(c.read(isReadyAuthenticatedProvider), isTrue);
    expect(identity.epoch, epoch);
    expect(identity.address, 'addr-1');
    expect(identity.provisionedSeasonId, 7);
    expect(identity.allowsSigning, isTrue);
    expect(identity.allowsNodeStart, isTrue);
    final prefs = await SharedPreferences.getInstance();
    final bucket = NetworkPrefs.bucketForAddress('addr-1');
    expect(
      prefs.getBool(
          'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed'),
      isTrue,
    );
  });

  test('reconcileSucceeded from a superseded epoch is discarded', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    final staleEpoch = c.read(identityProvider).epoch;
    // A second login supersedes the first reconcile.
    await c.read(identityProvider.notifier).completeLogin(_session('sess-3'));
    final committed =
        await c.read(identityProvider.notifier).reconcileSucceeded(
              epoch: staleEpoch,
              accountId: 'acc-stale',
              address: 'addr-stale',
              participantId: 1,
            );
    expect(committed, isFalse);
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(c.read(identityProvider).accountId, isNull);
  });

  test('beginSeasonRollover re-enters reconciling on a season mismatch',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    final epoch = c.read(identityProvider).epoch;
    await c.read(identityProvider.notifier).reconcileSucceeded(
          epoch: epoch,
          accountId: 'acc-1',
          address: 'addr-1',
          participantId: 1,
          provisionedSeasonId: 7,
        );

    // Same season: no-op.
    await c
        .read(identityProvider.notifier)
        .beginSeasonRollover(activeSeasonId: 7);
    expect(c.read(identityProvider).phase, IdentityPhase.ready);

    // New season: reconcile again under a new epoch.
    await c
        .read(identityProvider.notifier)
        .beginSeasonRollover(activeSeasonId: 8);
    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.reconciling);
    expect(identity.epoch, greaterThan(epoch));
    expect(identity.allowsSigning, isFalse);
    expect(identity.allowsNodeStart, isFalse);
  });

  test('continueAsGuest sets guest', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).continueAsGuest();
    expect(c.read(authStatusProvider), AuthStatus.guest);
  });

  test(
      'continueAsGuest persists guest before shutdown and settles only after it',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final stopStarted = Completer<void>();
    final stopRelease = Completer<void>();
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () {
        stopStarted.complete();
        return stopRelease.future;
      },
    );
    addTearDown(controller.dispose);

    final transition = controller.continueAsGuest();
    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(controller.state.allowsNodeStart, isFalse);
    expect(controller.state.allowsSigning, isFalse);
    await stopStarted.future;
    expect(await AuthTokenStore().read(), isNull);
    expect(await AuthGuestFlag().isGuest(), isTrue);
    expect(controller.state.phase, IdentityPhase.transitioning);

    stopRelease.complete();
    await transition;
    expect(controller.state.phase, IdentityPhase.guest);
  });

  test('failed guest shutdown keeps the gate closed but revokes durably',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () async => throw StateError('shutdown timeout'),
    );
    addTearDown(controller.dispose);

    await expectLater(controller.continueAsGuest(), throwsStateError);

    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(await AuthTokenStore().read(), isNull);
    expect(await AuthGuestFlag().isGuest(), isTrue);
  });

  test('failed login shutdown preserves crash-safe replacement state',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-old'});
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () async => throw StateError('shutdown timeout'),
    );
    addTearDown(controller.dispose);

    await expectLater(
      controller.completeLogin(_session('sess-new')),
      throwsStateError,
    );

    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(await AuthTokenStore().read(), 'sess-new');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      1,
    );
  });

  test('logout clears locally before waiting for the remote request', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final repository = _BlockingLogoutRepository();
    final stopStarted = Completer<void>();
    final stopRelease = Completer<void>();
    final controller = SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: repository,
      suspendNode: () {
        stopStarted.complete();
        return stopRelease.future;
      },
    );
    addTearDown(controller.dispose);

    final logout = controller.logout();
    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(controller.state.allowsSigning, isFalse);
    await stopStarted.future;
    expect(await AuthTokenStore().read(), isNull);
    expect(controller.state.phase, IdentityPhase.transitioning);
    stopRelease.complete();
    await repository.started.future;

    expect(await AuthTokenStore().read(), isNull);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(repository.token, 'sess-1');

    repository.release.complete();
    expect(await logout, isTrue);
  });

  test('onUnauthorized clears token and unauthenticates', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;
    await c.read(identityProvider.notifier).onUnauthorized(
          credential: AuthCredentialLease(epoch: epoch, token: 'sess-1'),
        );
    expect(c.read(authStatusProvider), AuthStatus.unauthenticated);
    expect(await c.read(authTokenStoreProvider).read(), isNull);
  });

  test('onUnauthorized from a superseded epoch is ignored', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final staleEpoch = c.read(identityProvider).epoch;
    // A newer login writes a fresh token; the stale request's late 401 must
    // not clear it.
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    await c.read(identityProvider.notifier).onUnauthorized(
          credential: AuthCredentialLease(epoch: staleEpoch, token: 'sess-1'),
        );
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('401 for a replaced token in the same epoch is ignored', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;
    await c.read(authTokenStoreProvider).write('sess-2');

    await c.read(identityProvider.notifier).onUnauthorized(
          credential: AuthCredentialLease(epoch: epoch, token: 'sess-1'),
        );

    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('missing-token callback cannot clear a token written since its read',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;
    await c.read(authTokenStoreProvider).write('sess-2');

    await c.read(identityProvider.notifier).onCredentialMissing(epoch: epoch);

    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('credential loss stops the existing node before settling signed-out',
      () async {
    var nodeStops = 0;
    final tokenStore = AuthTokenStore();
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () async {
        nodeStops++;
      },
    );
    addTearDown(controller.dispose);
    await controller.completeLogin(_session('sess-1'));
    final epoch = controller.state.epoch;
    await tokenStore.clear();

    await controller.onCredentialMissing(epoch: epoch);

    expect(nodeStops, 2); // login replacement + credential loss
    expect(controller.state.phase, IdentityPhase.unauthenticated);
  });

  test('an exact 401 stops the existing node before settling signed-out',
      () async {
    var nodeStops = 0;
    final tokenStore = AuthTokenStore();
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () async {
        nodeStops++;
      },
    );
    addTearDown(controller.dispose);
    await controller.completeLogin(_session('sess-1'));
    final epoch = controller.state.epoch;

    await controller.onUnauthorized(
      credential: AuthCredentialLease(epoch: epoch, token: 'sess-1'),
    );

    expect(nodeStops, 2); // login replacement + rejected credential
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(await tokenStore.read(), isNull);
  });

  test('stale bridge logout cannot log out a replacement identity', () async {
    final tokenStore = AuthTokenStore();
    final controller = SessionController(
      tokenStore: tokenStore,
      guestFlag: AuthGuestFlag(),
      repository: AuthRepository(),
      suspendNode: () async {},
    );
    addTearDown(controller.dispose);
    await controller.completeLogin(_session('sess-1'));
    final staleIdentity = controller.state;
    await controller.completeLogin(_session('sess-2'));

    expect(
      await controller.logout(expectedIdentity: staleIdentity),
      isFalse,
    );
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(await tokenStore.read(), 'sess-2');
  });

  test(
      'completeLogin closes the identity gate before its persistence writes '
      '(concurrent signing/node checks see transitioning)', () async {
    final probe = _OrderProbeTokenStore();
    final c = ProviderContainer(overrides: [
      authTokenStoreProvider.overrideWithValue(probe),
    ]);
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).completeLogin(_session('sess-2'));
    // By the time the token write ran (mid-transition), the transitioning
    // identity was already published — the gate was closed first.
    expect(probe.phaseAtTokenWrite, IdentityPhase.transitioning);
  });

  test('guest sessions never allow signing or wallet exposure', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(identityProvider.notifier).continueAsGuest();
    final identity = c.read(identityProvider);
    expect(identity.phase, IdentityPhase.guest);
    // Guests are settled (their own bucket is trustworthy) but must never
    // operate the registry's active account or its keys.
    expect(identity.isSettled, isTrue);
    expect(identity.allowsSigning, isFalse);
  });

  test('local-only unauthenticated identity signs only with an account', () {
    const withAccount = Identity(
      epoch: 1,
      phase: IdentityPhase.unauthenticated,
      accountId: 'acc-1',
      address: 'addr-1',
    );
    const withoutAccount =
        Identity(epoch: 1, phase: IdentityPhase.unauthenticated);
    expect(withAccount.allowsSigning, isTrue);
    expect(withoutAccount.allowsSigning, isFalse);
    expect(
        const Identity(epoch: 1, phase: IdentityPhase.reconciling)
            .allowsSigning,
        isFalse);
  });

  group('node suspension and season baseline (injected suspendNode)', () {
    late int suspendCount;
    late SessionController controller;

    setUp(() {
      suspendCount = 0;
      controller = SessionController(
        tokenStore: AuthTokenStore(),
        guestFlag: AuthGuestFlag(),
        repository: AuthRepository(),
        suspendNode: () async => suspendCount++,
      );
    });

    tearDown(() => controller.dispose());

    Future<void> settleReady({int? provisionedSeasonId}) async {
      await controller.restore();
      await controller.completeLogin(_session('sess-2'));
      final committed = await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'acc-1',
        address: 'addr-1',
        participantId: 1,
        provisionedSeasonId: provisionedSeasonId,
      );
      expect(committed, isTrue);
    }

    test('completeLogin and season rollover both suspend the node', () async {
      await settleReady(provisionedSeasonId: 7);
      expect(suspendCount, 1); // login suspension

      await controller.beginSeasonRollover(activeSeasonId: 8);
      expect(controller.state.phase, IdentityPhase.reconciling);
      // The rollover suspended the node too: it was producing under the
      // previous season's account binding.
      expect(suspendCount, 2);
    });

    test(
        'runtime retirement drains accepted transitions and refuses later ones',
        () async {
      controller.dispose();
      final firstSuspendStarted = Completer<void>();
      final releaseFirstSuspend = Completer<void>();
      var localSuspendCount = 0;
      controller = SessionController(
        tokenStore: AuthTokenStore(),
        guestFlag: AuthGuestFlag(),
        repository: AuthRepository(),
        suspendNode: () {
          localSuspendCount += 1;
          if (localSuspendCount == 1) {
            firstSuspendStarted.complete();
            return releaseFirstSuspend.future;
          }
          return Future<void>.value();
        },
      );
      await controller.restore();

      final login = controller.completeLogin(_session('sess-retiring'));
      await firstSuspendStarted.future;
      final acceptedGuestTransition = controller.continueAsGuest();
      final finalBarrier = controller.retireForRuntimeCutover();
      var finalBarrierCompleted = false;
      unawaited(finalBarrier.whenComplete(() => finalBarrierCompleted = true));

      // This call arrived after retirement. It must neither join the queue nor
      // mutate the durable target the replacement runtime will restore.
      expect(await controller.logout(), isFalse);
      await pumpEventQueue();
      expect(finalBarrierCompleted, isFalse);

      releaseFirstSuspend.complete();
      await finalBarrier;
      await login;
      await acceptedGuestTransition;

      expect(localSuspendCount, 2);
      // The old runtime stays closed. The replacement restores the durable
      // guest target after the barrier instead of publishing it in place.
      expect(controller.state.phase, IdentityPhase.transitioning);
      expect(await AuthTokenStore().read(), isNull);
      expect(await AuthGuestFlag().isGuest(), isTrue);
    });

    test('a null reconcile result clears the previous season everywhere',
        () async {
      await settleReady(provisionedSeasonId: 7);
      final bucket = controller.state.bucket;
      final key = NetworkPrefs.prefixAccountKeyFor(
        'identity:provisioned_season',
        bucket,
      );
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(key), 7);

      await controller.beginSeasonRollover(activeSeasonId: 8);
      final committed = await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'acc-1',
        address: 'addr-1',
        participantId: 1,
        provisionedSeasonId: null,
      );

      expect(committed, isTrue);
      expect(controller.state.provisionedSeasonId, isNull);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(key), isFalse);
    });

    test(
        'a ready identity with no provisioned-season baseline reconciles '
        'once (pre-baseline install migration), and only once', () async {
      await settleReady(provisionedSeasonId: null);
      expect(controller.state.provisionedSeasonId, isNull);
      final readyEpoch = controller.state.epoch;

      // First authoritative season report: one-time migration reconcile.
      await controller.beginSeasonRollover(activeSeasonId: 5);
      expect(controller.state.phase, IdentityPhase.reconciling);
      expect(controller.state.epoch, greaterThan(readyEpoch));

      // The migration reconcile commits — but the backend again returned no
      // season id. The persisted flag must prevent an endless loop.
      final committed = await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'acc-1',
        address: 'addr-1',
        participantId: 1,
        provisionedSeasonId: null,
      );
      expect(committed, isTrue);
      await controller.beginSeasonRollover(activeSeasonId: 5);
      expect(controller.state.phase, IdentityPhase.ready);
    });
  });

  test('onUnauthorized keeps a remembered guest as guest', () async {
    // A stray 401 (auth-required endpoint reached while browsing as guest)
    // invalidates the token, not the user's explicit guest choice.
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;
    await c.read(authTokenStoreProvider).write('stray-token');
    await c.read(identityProvider.notifier).onUnauthorized(
          credential: AuthCredentialLease(epoch: epoch, token: 'stray-token'),
        );
    expect(c.read(authStatusProvider), AuthStatus.guest);
  });
}
