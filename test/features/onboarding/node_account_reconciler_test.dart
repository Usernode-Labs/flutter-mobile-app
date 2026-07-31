import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';

const _addressA = 'ut1useraaaaaaaa';
const _addressB = 'ut1userbbbbbbbb';

Map<String, dynamic> _accountJson(String id, String address) => {
      'id': id,
      'name': 'Node Account',
      'createdAt': '2026-01-01T00:00:00.000',
      'derivationPath': 'imported',
      'hdIndex': 0,
      'address': address,
      'publicKey': 'utpk1$address',
      'backupConfirmed': true,
      'isDemo': false,
    };

/// A service whose `/wallet/provision` returns [address]. [provisionCalls]
/// counts round-trips so tests can assert coalescing.
LeaderboardApiService _provisionService(
  String address,
  List<int> provisionCalls,
) {
  final client = MockClient((request) async {
    expect(request.url.path, endsWith('/wallet/provision'));
    provisionCalls.add(1);
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'address': address,
          'public_key': 'utpk1$address',
          'secret_key': 'utsk1secret',
          'newly_allocated': false,
          'season_id': 7,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return LeaderboardApiService(
    baseUrl: 'https://test.example.com/api/v4/mobile',
    httpClient: client,
    tokenProvider: AuthTokenStore().read,
  );
}

AuthSession _session(String token, {int participantId = 99}) => AuthSession(
      token: token,
      participant: Participant(
        id: participantId,
        email: 'a@b.com',
        emailConfirmed: true,
      ),
    );

/// Signs in through the real [SessionController], leaving the identity in the
/// reconciling phase exactly as the app would (marker set, participant id
/// staged in the guest bucket, epoch bumped).
Future<void> _login(ProviderContainer c, {String token = 'sess-1'}) async {
  c.read(identityProvider);
  await c.read(identityProvider.notifier).completeLogin(_session(token));
}

/// Overrides the reconciler with a no-op node binding (the default touches
/// the Rust backend).
Override _reconcilerOverride({
  Future<void> Function()? ensureNodeIdentity,
}) =>
    nodeAccountReconcilerProvider.overrideWith(
      (ref) => NodeAccountReconciler(
        ref,
        ensureNodeIdentity: ensureNodeIdentity ?? () async {},
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestPidKey = 'testnet:acct:guest:leaderboard:participant_id';
  const markerKey = 'testnet:account:reconcile_pending';

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
    IdentitySnapshots.reset();
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
    IdentitySnapshots.reset();
  });

  test('does nothing when the identity is not reconciling', () async {
    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    // Boot as unauthenticated (no token, no guest flag).
    container.read(identityProvider);
    await container.read(identityProvider.notifier).restore();

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isFalse);
    expect(provisionCalls, isEmpty);
  });

  test(
      'activates the existing local account matching the provisioned address '
      'and settles the identity to ready', () async {
    // Device state after user A logged out and user B signs in: BOTH
    // accounts exist locally, A's is still active. hasAny() alone would
    // keep running under A's identity.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    var nodeBinds = 0;
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(ensureNodeIdentity: () async => nodeBinds++),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');

    // The node runtime was re-bound to the reconciled account before commit.
    expect(nodeBinds, 1);

    // The identity settled to ready under B's account and season.
    final identity = container.read(identityProvider);
    expect(identity.phase, IdentityPhase.ready);
    expect(identity.address, _addressB);
    expect(identity.participantId, 99);
    expect(identity.provisionedSeasonId, 7);

    // The bucket now follows B's account, and B's staged participant id
    // was installed there (and removed from the guest bucket).
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    expect(NetworkPrefs.activeBucket, bucketB);
    expect(
        prefs.getInt('testnet:acct:$bucketB:leaderboard:participant_id'), 99);
    expect(prefs.getInt(guestPidKey), isNull);

    // The provisioned season is persisted for rollover detection.
    expect(
        prefs.getInt('testnet:acct:$bucketB:identity:provisioned_season'), 7);

    // Reconcile completed — boot restores no longer need to re-run it.
    expect(prefs.getBool(markerKey), isNull);
  });

  test('legacy ownership migration provisions once, then restores ready',
      () async {
    final bucketA = NetworkPrefs.bucketForAddress(_addressA);
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
      // Pre-lifecycle state: an active account has an owner id, but there is
      // no reconcile marker or ownership proof tying it to the stored token.
      'testnet:acct:$bucketA:leaderboard:participant_id': 7,
      // Residue without a pending marker is not authenticated recovery state;
      // `/me` below must win over it.
      'testnet:acct:guest:leaderboard:participant_id': 123,
    });
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-b'});
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final provisionService = _provisionService(_addressB, provisionCalls);
    final accountService = AccountApiService(
      baseUrl: 'https://test.example.com/api/v4/mobile',
      tokenProvider: AuthTokenStore().read,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/me'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 99,
              'email': 'b@example.com',
              'email_confirmed': true,
              'level': 'operator',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(provisionService.dispose);
    addTearDown(accountService.dispose);

    List<Override> overrides() => [
          leaderboardApiServiceProvider.overrideWithValue(provisionService),
          accountApiServiceProvider.overrideWithValue(accountService),
          _reconcilerOverride(),
        ];

    final firstBoot = ProviderContainer(overrides: overrides());
    try {
      await firstBoot.read(identityProvider.notifier).restore();
      expect(
        firstBoot.read(identityProvider).phase,
        IdentityPhase.reconciling,
      );

      expect(
        await firstBoot.read(nodeAccountReconcilerProvider).reconcile(),
        isTrue,
      );
      expect(firstBoot.read(identityProvider).phase, IdentityPhase.ready);
      expect(firstBoot.read(identityProvider).address, _addressB);
      expect(provisionCalls, hasLength(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');
      expect(
        prefs.getInt('testnet:acct:$bucketB:leaderboard:participant_id'),
        99,
      );
      expect(
        prefs.getBool(
            'testnet:acct:$bucketB:identity:lifecycle_ownership_confirmed'),
        isTrue,
      );
      expect(prefs.getBool(markerKey), isNull);
    } finally {
      firstBoot.dispose();
    }

    // Simulate a new process/controller with the same durable stores. The
    // completed lifecycle proof must allow a network-free ready restore.
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
    final secondBoot = ProviderContainer(overrides: overrides());
    addTearDown(secondBoot.dispose);

    await secondBoot.read(identityProvider.notifier).restore();

    expect(secondBoot.read(identityProvider).phase, IdentityPhase.ready);
    expect(secondBoot.read(identityProvider).participantId, 99);
    expect(
      await secondBoot.read(nodeAccountReconcilerProvider).reconcile(),
      isFalse,
    );
    expect(provisionCalls, hasLength(1));
  });

  test('same-account reconcile refreshes onboarding from the confirmed bucket',
      () async {
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
      'testnet:acct:$bucketB:onboarding:completed': true,
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);
    // Reconciliation has not confirmed an account yet, so this first read is
    // cached from the guest bucket.
    expect(await container.read(hasCompletedOnboardingProvider.future), false);

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isTrue);
    // The registry account did not change, but the active identity bucket did
    // (guest -> B), so the provider must have been invalidated regardless.
    expect(await container.read(hasCompletedOnboardingProvider.future), true);
  });

  test(
      'missing participant id keeps reconcile pending when /me cannot recover '
      'it', () async {
    SharedPreferences.setMockInitialValues({
      markerKey: true,
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    var nodeBinds = 0;
    final accountService = AccountApiService(
      baseUrl: 'https://test.example.com/api/v4/mobile',
      tokenProvider: AuthTokenStore().read,
      httpClient: MockClient(
        (_) async => http.Response('{"success":false}', 503),
      ),
    );
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      accountApiServiceProvider.overrideWithValue(accountService),
      _reconcilerOverride(ensureNodeIdentity: () async => nodeBinds++),
    ]);
    addTearDown(() {
      container.dispose();
      accountService.dispose();
    });

    container.read(identityProvider);
    await container.read(identityProvider.notifier).restore();
    expect(container.read(identityProvider).participantId, isNull);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<AccountApiException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
    expect(prefs.getBool(markerKey), isTrue);
    expect(nodeBinds, 0);
    expect(provisionCalls, hasLength(1));
    expect(
      jsonDecode(prefs.getString('testnet:accounts:index')!) as List,
      hasLength(1),
    );
  });

  test('concurrent reconcile calls coalesce onto one provision round-trip',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final reconciler = container.read(nodeAccountReconcilerProvider);
    // Identity driver and onboarding tap racing must not double-import.
    final results =
        await Future.wait([reconciler.reconcile(), reconciler.reconcile()]);

    expect(provisionCalls.length, 1);
    expect(results, [true, true]);
  });

  test(
      'an identity change while provisioning is in flight discards the '
      'response and keeps the reconcile-pending marker', () async {
    // B's provisioning is slow; C signs in while it's in flight. B's
    // response must not activate B's wallet or clear C's recovery marker.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    late ProviderContainer container;
    final client = MockClient((request) async {
      // The identity changes while the provision round-trip is in flight.
      await container
          .read(identityProvider.notifier)
          .completeLogin(_session('sess-c', participantId: 100));
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'address': _addressB,
            'public_key': 'utpk1$_addressB',
            'secret_key': 'utsk1secret',
            'newly_allocated': false,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider.overrideWithValue(LeaderboardApiService(
        baseUrl: 'https://test.example.com/api/v4/mobile',
        httpClient: client,
        tokenProvider: AuthTokenStore().read,
      )),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final committed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(committed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    // No mutation: A's account is still active, marker still set so the new
    // identity's own reconcile repairs state.
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_0_a');
    expect(prefs.getBool(markerKey), isTrue);
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
    // C's staged participant id was not consumed by B's stale run.
    expect(prefs.getInt(guestPidKey), 100);
  });

  test('a caller under a newer epoch does not join a stale in-flight run',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    final reconciler = container.read(nodeAccountReconcilerProvider);
    final first = reconciler.reconcile();
    // A new sign-in bumps the epoch while the first run is in flight: the
    // next caller must get its own provision round-trip, not the stale
    // run's result.
    await container
        .read(identityProvider.notifier)
        .completeLogin(_session('sess-2'));
    final second = reconciler.reconcile();
    final results = await Future.wait([first, second]);

    expect(provisionCalls.length, 2);
    // The stale run was discarded; the fresh run committed.
    expect(results, [false, true]);
  });

  test(
      'a failed node re-bind keeps the identity reconciling and the marker '
      'set so the next boot repairs the runtime identity', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      _reconcilerOverride(
        ensureNodeIdentity: () async =>
            throw StateError('node failed to start'),
      ),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<StateError>()),
    );

    final prefs = await SharedPreferences.getInstance();
    // The registry switch itself happened, but the identity never became
    // ready and the marker survives — the next boot restore re-runs the
    // reconcile (which is idempotent) and re-binds the node.
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');
    expect(prefs.getBool(markerKey), isTrue);
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
  });

  test('propagates provisioning failure so onboarding can surface it',
      () async {
    final client = MockClient((request) async => http.Response(
          jsonEncode({'success': false, 'error': 'No accounts available'}),
          409,
          headers: {'content-type': 'application/json'},
        ));
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider.overrideWithValue(
        LeaderboardApiService(
          baseUrl: 'https://test.example.com/api/v4/mobile',
          httpClient: client,
          tokenProvider: AuthTokenStore().read,
        ),
      ),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<LeaderboardApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
    // The identity stays reconciling for the retry path.
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
  });
}
