import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/onboarding/data/wallet_provisioning_api.dart';

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

/// A narrow provisioning capability that returns [address].
/// [provisionCalls] counts calls so tests can assert coalescing.
WalletProvisioningApi _provisionService(
  String address,
  List<int> provisionCalls, {
  Completer<void>? firstCallStarted,
  Future<void>? releaseFirstCall,
  Object? error,
}) {
  return _FakeWalletProvisioningApi(
    result: WalletProvisioningResult(
      address: address,
      publicKey: 'utpk1$address',
      secretKey: 'utsk1secret',
      newlyAllocated: false,
      bpReleased: false,
    ),
    provisionCalls: provisionCalls,
    firstCallStarted: firstCallStarted,
    releaseFirstCall: releaseFirstCall,
    error: error,
  );
}

class _FakeWalletProvisioningApi implements WalletProvisioningApi {
  _FakeWalletProvisioningApi({
    required this.result,
    required this.provisionCalls,
    this.firstCallStarted,
    this.releaseFirstCall,
    this.error,
  });

  final WalletProvisioningResult result;
  final List<int> provisionCalls;
  final Completer<void>? firstCallStarted;
  final Future<void>? releaseFirstCall;
  final Object? error;

  @override
  Future<WalletProvisioningResult> provision() async {
    provisionCalls.add(1);
    if (provisionCalls.length == 1) {
      final started = firstCallStarted;
      if (started != null && !started.isCompleted) started.complete();
      final release = releaseFirstCall;
      if (release != null) await release;
    }
    final failure = error;
    if (failure != null) throw failure;
    return result;
  }
}

AccountApiService _meService({
  Completer<void>? requestStarted,
  Future<void>? releaseRequest,
  int statusCode = 200,
  String? email = 'fresh@example.com',
}) {
  return AccountApiService(
    baseUrl: 'https://test.example.com/api/v4/mobile',
    tokenProvider: AuthTokenStore().read,
    httpClient: MockClient((request) async {
      expect(request.url.path, endsWith('/me'));
      if (requestStarted != null && !requestStarted.isCompleted) {
        requestStarted.complete();
      }
      if (releaseRequest != null) await releaseRequest;
      if (statusCode != 200) {
        return http.Response(
          jsonEncode({'success': false, 'error': 'temporarily unavailable'}),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 99,
            'email': email,
            'email_confirmed': true,
            'display_name': 'Fresh Profile',
            'level': 'operator',
            'bp_released': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
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

/// Stages the only payload retained by a successful terminal login, then
/// rebuilds the identity provider to model the next cold launch.
Future<void> _login(ProviderContainer c, {String token = 'sess-1'}) async {
  await c.read(identityProvider.notifier).restore();
  final session = _session(token);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('testnet:account:reconcile_pending', true);
  await prefs.setInt(
    'testnet:acct:guest:leaderboard:participant_id',
    session.participant.id,
  );
  await prefs.remove('auth:v3:guest');
  await AuthTokenStore().write(session.token);
  c.invalidate(identityProvider);
  await c.read(identityProvider.notifier).restore();
  expect(c.read(identityProvider).phase, IdentityPhase.reconciling);
}

/// Overrides the reconciler with a no-op node binding (the default touches
/// the Rust backend).
Override _reconcilerOverride({
  Future<void> Function()? ensureNodeIdentity,
  Identity Function()? currentIdentity,
}) =>
    nodeAccountReconcilerProvider.overrideWith(
      (ref) => NodeAccountReconciler(
        ref,
        ensureNodeIdentity: ensureNodeIdentity ?? () async {},
        currentIdentity: currentIdentity,
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
      walletProvisioningApiProvider
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
    // Legacy/corrupt registry state contains two accounts and points at the
    // wrong one. Reconcile must select the backend-provisioned address;
    // account presence alone is not ownership proof.
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
      walletProvisioningApiProvider
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

    // The identity settled to ready under B's account.
    final identity = container.read(identityProvider);
    expect(identity.phase, IdentityPhase.ready);
    expect(identity.address, _addressB);
    expect(identity.participantId, 99);

    // The bucket now follows B's account, and B's staged participant id
    // was installed there (and removed from the guest bucket).
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    expect(NetworkPrefs.activeBucket, bucketB);
    expect(
        prefs.getInt('testnet:acct:$bucketB:leaderboard:participant_id'), 99);
    expect(prefs.getInt(guestPidKey), isNull);

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
    addTearDown(accountService.dispose);

    List<Override> overrides() => [
          walletProvisioningApiProvider.overrideWithValue(provisionService),
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
      walletProvisioningApiProvider
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
      walletProvisioningApiProvider
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
      walletProvisioningApiProvider
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
    final provisionCalls = <int>[];
    final container = ProviderContainer(overrides: [
      walletProvisioningApiProvider.overrideWithValue(
        _provisionService(
          _addressB,
          provisionCalls,
          error: WalletProvisioningException(
            409,
            'No accounts available',
          ),
        ),
      ),
      _reconcilerOverride(),
    ]);
    addTearDown(container.dispose);

    await _login(container);

    await expectLater(
      container.read(nodeAccountReconcilerProvider).reconcile(),
      throwsA(isA<WalletProvisioningException>()
          .having((e) => e.statusCode, 'statusCode', 409)),
    );
    // The identity stays reconciling for the retry path.
    expect(container.read(identityProvider).phase, IdentityPhase.reconciling);
  });

  test(
      'email-less authority refresh updates ready state and permits node start',
      () async {
    final bucketB = NetworkPrefs.bucketForAddress(_addressB);
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final me = _meService(email: null);
    final container = ProviderContainer(overrides: [
      walletProvisioningApiProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(),
    ]);
    addTearDown(() {
      container.dispose();
      me.dispose();
    });

    await _login(container);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);
    expect(await loadBlockProductionReleased(), isFalse);

    final driver = IdentityDriver(
      reconcileNodeAccount: () async {},
      retryPendingZkCompletion: () async {},
      refreshAccountAuthority: reconciler.refreshAccountAuthority,
    );
    addTearDown(driver.dispose);
    driver.onIdentityChanged(null, container.read(identityProvider));
    await driver.lastRun;
    expect(await driver.ensureFreshBeforeNodeStart(), isTrue);

    final profile = await container.read(meProvider.future);
    expect(profile?.displayName, 'Fresh Profile');
    expect(profile?.email, isEmpty);
    expect(await loadBlockProductionReleased(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('testnet:acct:$bucketB:bp:released'),
      isTrue,
    );
  });

  test('ready refresh preserves transient API errors for retry handling',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final provisionCalls = <int>[];
    final me = _meService(statusCode: 503);
    final container = ProviderContainer(overrides: [
      walletProvisioningApiProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(),
    ]);
    addTearDown(() {
      container.dispose();
      me.dispose();
    });

    await _login(container);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);

    await expectLater(
      reconciler.refreshAccountAuthority(),
      throwsA(
        isA<AccountApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('delayed ready refresh cannot write after its epoch', () async {
    SharedPreferences.setMockInitialValues({
      'testnet:accounts:index': jsonEncode([
        _accountJson('acc_1_b', _addressB),
      ]),
      'testnet:accounts:activeId': 'acc_1_b',
    });
    await NetworkPrefs.init();

    final requestStarted = Completer<void>();
    final releaseRequest = Completer<void>();
    addTearDown(() {
      if (!releaseRequest.isCompleted) releaseRequest.complete();
    });
    final provisionCalls = <int>[];
    final me = _meService(
      requestStarted: requestStarted,
      releaseRequest: releaseRequest.future,
    );
    late Identity currentIdentity;
    final container = ProviderContainer(overrides: [
      walletProvisioningApiProvider
          .overrideWithValue(_provisionService(_addressB, provisionCalls)),
      accountApiServiceProvider.overrideWithValue(me),
      _reconcilerOverride(currentIdentity: () => currentIdentity),
    ]);
    addTearDown(() {
      container.dispose();
      me.dispose();
    });

    await _login(container);
    currentIdentity = container.read(identityProvider);
    final reconciler = container.read(nodeAccountReconcilerProvider);
    expect(await reconciler.reconcile(), isTrue);
    currentIdentity = container.read(identityProvider);

    final refresh = reconciler.refreshAccountAuthority();
    await requestStarted.future;
    currentIdentity = currentIdentity.copyWith(
      epoch: currentIdentity.epoch + 1,
      phase: IdentityPhase.transitioning,
    );
    releaseRequest.complete();
    expect(await refresh, isFalse);
    expect(await loadBlockProductionReleased(), isFalse);
  });
}
