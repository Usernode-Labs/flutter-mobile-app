import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
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
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
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
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('testnet:accounts:activeId'), 'acc_1_b');

    // The bucket now follows B's account, and B's staged participant id
    // was moved into it (and out of the guest bucket).
    expect(NetworkPrefs.activeBucket, isNot(NetworkPrefs.guestBucket));
    final bucketKey =
        'testnet:acct:${NetworkPrefs.activeBucket}:leaderboard:participant_id';
    expect(prefs.getInt(bucketKey), 99);
    expect(prefs.getInt(guestPidKey), isNull);
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
    final container = ProviderContainer(overrides: [
      leaderboardApiServiceProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
    ]);
    addTearDown(container.dispose);

    final changed =
        await container.read(nodeAccountReconcilerProvider).reconcile();

    expect(changed, isFalse);
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
