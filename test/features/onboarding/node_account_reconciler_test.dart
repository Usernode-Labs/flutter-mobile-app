import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/identity_lifecycle.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
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
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return LeaderboardApiService(
    baseUrl: 'https://test.example.com/api/v4/mobile',
    httpClient: client,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestPidKey = 'testnet:acct:guest:leaderboard:participant_id';

  setUp(() async {
    // participantIdProvider (invalidated by the reconciler) watches
    // authStatusProvider, whose token store reads secure storage.
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
    NodeIdentitySuspension.clear();
    IdentityGenerations.reset();
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
    NodeIdentitySuspension.clear();
  });

  test(
      'activates the existing local account matching the provisioned address '
      'instead of trusting whichever account was active', () async {
    // Device state after user A logged out and user B signs in: BOTH
    // accounts exist locally, A's is still active. hasAny() alone would
    // keep running under A's identity.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
      // User B's login staged their participant id in the guest bucket.
      guestPidKey: 99,
      // ...and marked the reconcile as pending (cleared below on success).
      'testnet:account:reconcile_pending': true,
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    var nodeRestarts = 0;
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async =>
              nodeRestarts++,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');

    // A node that was running under A's identity must be restarted so it
    // re-reads the (now B's) active account key.
    expect(nodeRestarts, 1);

    // The bucket now follows B's account, and B's staged participant id
    // was moved into it (and out of the guest bucket).
    expect(NetworkPrefs.activeBucket, isNot(NetworkPrefs.guestBucket));
    final bucketKey =
        'testnet:acct:${NetworkPrefs.activeBucket}:leaderboard:participant_id';
    expect(prefs.getInt(bucketKey), 99);
    expect(prefs.getInt(guestPidKey), isNull);

    // Reconcile completed — boot restores no longer need to re-run it.
    expect(prefs.getBool('testnet:account:reconcile_pending'), isNull);
  });

  test(
      're-running when the provisioned account is already active reports '
      'no change but still repairs a missed id migration', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
      // Simulates an interruption after import but before the id move — a
      // hasAny() early-return would leave this stranded forever.
      guestPidKey: 99,
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    var nodeRestarts = 0;
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async =>
              nodeRestarts++,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isFalse);
    // No identity change — the running node must NOT be bounced.
    expect(nodeRestarts, 0);
    final prefs = await SharedPreferences.getInstance();
    final bucketKey =
        'testnet:acct:${NetworkPrefs.activeBucket}:leaderboard:participant_id';
    expect(prefs.getInt(bucketKey), 99);
    expect(prefs.getInt(guestPidKey), isNull);
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
    ]);
    addTearDown(container.dispose);

    final reconciler = container.read(nodeAccountReconcilerProvider);
    // Sign-in listener and onboarding tap racing must not double-import.
    await Future.wait([reconciler.reconcile(), reconciler.reconcile()]);

    expect(provisionCalls.length, 1);

    // A later reconcile is a fresh run again.
    await reconciler.reconcile();
    expect(provisionCalls.length, 2);
  });

  test(
      'a session change while provisioning is in flight discards the '
      'response and keeps the reconcile-pending marker', () async {
    // B's provisioning is slow; B logs out and C signs in while it's in
    // flight. B's response must not activate B's wallet or clear C's
    // recovery marker.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
      'testnet:account:reconcile_pending': true,
    });
    await NetworkPrefs.init();

    var generation = 1;
    final client = MockClient((request) async {
      // The session changes while the provision round-trip is in flight.
      generation = 2;
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
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider.overrideWithValue(LeaderboardApiService(
        baseUrl: 'https://test.example.com/api/v4/mobile',
        httpClient: client,
      )),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async {},
          currentGeneration: () => generation,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    // No mutation: A's account is still active, marker still set so the new
    // session's own reconcile repairs state.
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_0_a');
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
  });

  test('a caller from a newer session does not join a stale in-flight run',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    var generation = 1;
    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async {},
          currentGeneration: () => generation,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final reconciler = container.read(nodeAccountReconcilerProvider);
    final first = reconciler.reconcile();
    // A new session starts while the first run is in flight: its caller
    // must get its own provision round-trip, not the stale run's result.
    generation = 2;
    final second = reconciler.reconcile();
    await Future.wait([first, second]);

    expect(provisionCalls.length, 2);
  });

  test(
      'a login-suspended node is started again even when the account did '
      'not change', () async {
    // Legacy install: same user re-logs in but the bucket has no stored
    // participant id, so login can't prove ownership and suspends the node.
    // The reconcile confirms the account and must bring the node back.
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();
    NodeIdentitySuspension.markSuspended();

    final provisionCalls = <int>[];
    final ensureCalls = <bool>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async =>
              ensureCalls.add(startIfSuspended),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isFalse);
    expect(ensureCalls, [true]); // startIfSuspended: bring the node back up
    expect(NodeIdentitySuspension.isSuspended, isFalse);
  });

  test(
      'a failed node restart keeps the reconcile-pending marker so the next '
      'boot repairs the runtime identity', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_0_a', _addressA),
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_0_a',
      'testnet:account:reconcile_pending': true,
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      nodeAccountReconcilerProvider.overrideWith(
        (ref) => NodeAccountReconciler(
          ref,
          ensureNodeIdentity: ({required bool startIfSuspended}) async =>
              throw StateError('node failed to start'),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    // The registry/bucket switch itself succeeded...
    expect(changed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');
    // ...but the runtime identity is unconfirmed — the marker must survive.
    expect(prefs.getBool('testnet:account:reconcile_pending'), isTrue);
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
        ),
      ),
    ]);
    addTearDown(container.dispose);

    expect(
      () => container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<LeaderboardApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
  });
}
