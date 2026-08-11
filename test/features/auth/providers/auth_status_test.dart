import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

void _seedReadyIdentity({int? provisionedSeasonId = 7}) {
  const address = 'addr-1';
  final bucket = NetworkPrefs.bucketForAddress(address);
  FlutterSecureStorage.setMockInitialValues({
    'auth:v3:session_token': 'sess-1',
  });
  SharedPreferences.setMockInitialValues({
    'testnet:accounts:index': jsonEncode([
      {
        'id': 'acc-1',
        'name': 'Node Account',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': address,
        'publicKey': 'utpk1$address',
        'backupConfirmed': true,
        'isDemo': false,
      },
    ]),
    'testnet:accounts:activeId': 'acc-1',
    'testnet:acct:$bucket:leaderboard:participant_id': 1,
    'testnet:acct:$bucket:identity:lifecycle_ownership_confirmed': true,
    if (provisionedSeasonId != null)
      'testnet:acct:$bucket:identity:provisioned_season': provisionedSeasonId,
  });
}

void _seedReconcilingIdentity() {
  FlutterSecureStorage.setMockInitialValues({
    'auth:v3:session_token': 'sess-1',
  });
  SharedPreferences.setMockInitialValues({
    'testnet:account:reconcile_pending': true,
    'testnet:acct:guest:leaderboard:participant_id': 1,
  });
}

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

  test('reconcileSucceeded settles a cold-launch recovery identity to ready',
      () async {
    _seedReconcilingIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
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
    _seedReadyIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final staleEpoch = c.read(identityProvider).epoch;
    await c
        .read(identityProvider.notifier)
        .beginSeasonRollover(activeSeasonId: 8);
    final committed =
        await c.read(identityProvider.notifier).reconcileSucceeded(
              epoch: staleEpoch,
              accountId: 'acc-stale',
              address: 'addr-stale',
              participantId: 1,
            );
    expect(committed, isFalse);
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(c.read(identityProvider).accountId, 'acc-1');
  });

  test('beginSeasonRollover re-enters reconciling on a season mismatch',
      () async {
    _seedReadyIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;

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

  test('onUnauthorized from a superseded epoch is ignored', () async {
    _seedReadyIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final staleEpoch = c.read(identityProvider).epoch;
    await c
        .read(identityProvider.notifier)
        .beginSeasonRollover(activeSeasonId: 8);
    await c.read(identityProvider.notifier).onUnauthorized(
          credential: AuthCredentialLease(epoch: staleEpoch, token: 'sess-1'),
        );
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-1');
  });

  test('401 for a replaced token in the same epoch is ignored', () async {
    _seedReadyIdentity();
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
    _seedReadyIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final epoch = c.read(identityProvider).epoch;
    await c.read(authTokenStoreProvider).write('sess-2');

    await c.read(identityProvider.notifier).onCredentialMissing(epoch: epoch);

    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('stale bridge logout cannot reset a newer season identity', () async {
    _seedReadyIdentity();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    final staleIdentity = c.read(identityProvider);
    await c
        .read(identityProvider.notifier)
        .beginSeasonRollover(activeSeasonId: 8);

    expect(
      await c
          .read(identityProvider.notifier)
          .logout(expectedIdentity: staleIdentity),
      isFalse,
    );
    expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-1');
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
      _seedReadyIdentity(provisionedSeasonId: provisionedSeasonId);
      await controller.restore();
      expect(controller.state.phase, IdentityPhase.ready);
    }

    test('season rollover suspends the existing node', () async {
      await settleReady(provisionedSeasonId: 7);
      expect(suspendCount, 0);

      await controller.beginSeasonRollover(activeSeasonId: 8);
      expect(controller.state.phase, IdentityPhase.reconciling);
      expect(suspendCount, 1);
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
