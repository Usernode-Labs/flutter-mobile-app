import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/session_scope_reset.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/log_share_provider.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hands the reset the same `Ref` the identity provider would give it.
final _refProvider = Provider<Ref>((ref) => ref);

const _namespaceA = 'aaaaaaaaaaaaaaa1';
const _namespaceB = 'aaaaaaaaaaaaaaa2';

String _registry(String id, String address) => jsonEncode([
      {
        'id': id,
        'name': 'Wallet',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': address,
        'publicKey': 'utpk1$address',
        'backupConfirmed': true,
        'isDemo': false,
      }
    ]);

HttpLogEntry _entry(String url) => HttpLogEntry(
      timestamp: DateTime(2026, 1, 1),
      method: 'GET',
      url: url,
      statusCode: 200,
      responseBody: '{"display_name":"user-a","balance":"1234"}',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
    FlutterSecureStorage.setMockInitialValues({});
    HttpDebugLogStore.instance.clear();
  });

  test('the retired session leaves no HTTP debug buffer for the next user',
      () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    HttpDebugLogStore.instance.add(_entry('https://api.example.com/me'));
    container.read(httpLogFilterProvider.notifier).state = 'me';
    expect(HttpDebugLogStore.instance.entries, hasLength(1));

    await resetSessionScopedProcessState(container.read(_refProvider));

    // The buffer is process-global and identity-agnostic: header/credential
    // redaction removes credentials, not the profile/wallet payloads the next
    // user would otherwise read in Debug Mode — or upload, since a fresh
    // sharing session rewinds its cursor to zero and flushes what is retained.
    expect(HttpDebugLogStore.instance.entries, isEmpty);
    expect(HttpDebugLogStore.instance.totalBytes, 0);
    // A fresh sharing session rewinds to cursor 0; there is nothing left for
    // it to flush under the successor's credential.
    expect(HttpDebugLogStore.instance.entriesAdded(0), isEmpty);
    expect(container.read(httpLogFilterProvider), '');
    expect(container.read(logShareControllerProvider).isSharing, isFalse);
  });

  test('the cached account registry is rebound to the successor identity',
      () async {
    SharedPreferences.setMockInitialValues({
      'testnet:identity:namespace': _namespaceA,
      'testnet:user:$_namespaceA:accounts:index':
          _registry('account-a', 'ut1useraaa'),
      'testnet:user:$_namespaceA:accounts:activeId': 'account-a',
      'testnet:user:$_namespaceB:accounts:index':
          _registry('account-b', 'ut1userbbb'),
      'testnet:user:$_namespaceB:accounts:activeId': 'account-b',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repositoryA = await container.read(accountsProvider.future);
    expect((await repositoryA.getActive())?.id, 'account-a');

    // Sign-out retires the namespace; the successor's login installs its own.
    await clearIdentityNamespace();
    await saveIdentityNamespace(_namespaceB);
    await resetSessionScopedProcessState(container.read(_refProvider));

    // Without the rebind this still answers with A's repository, whose
    // namespace was captured at construction — and a successor whose
    // reconcile finishes with `changed == false` never invalidates it either.
    final repositoryB = await container.read(accountsProvider.future);
    expect((await repositoryB.getActive())?.id, 'account-b');
  });

  test('the successor is not rendered as the retired identity in zkPassport',
      () async {
    const address = 'ut1useraaa';
    final bucketA = NetworkPrefs.bucketForAddress(address);
    SharedPreferences.setMockInitialValues({
      'testnet:acct:$bucketA:zkpassport:settings_v1':
          jsonEncode({'facematch_strict': false}),
    });
    NetworkPrefs.setActiveBucket(address, guest: false);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settingsA = await container.read(zkPassportSettingsProvider.future);
    expect(settingsA.facematchStrict, isFalse);

    // Sign-out returns the ambient bucket to guest; the cached value above
    // belongs to the account that just left.
    NetworkPrefs.setActiveBucket(null, guest: true);
    await resetSessionScopedProcessState(container.read(_refProvider));

    final settingsAfter =
        await container.read(zkPassportSettingsProvider.future);
    expect(
      settingsAfter.facematchStrict,
      ZkPassportSettings.defaults.facematchStrict,
      reason: 'the retired identity\'s zkPassport view must not be replayed',
    );
  });

  test('zkPassport presentation state does not outlive the session', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pipeline = container.read(zkPassportPipelineProvider.notifier);
    // A pipeline that already finished has no polling worker left to notice an
    // identity change, so its terminal state — result message, request id,
    // timings, public inputs — is rendered straight into the successor's flow
    // screen.
    await pipeline.reportImmediateFailure(message: 'user-a proof failed');
    container.read(zkIdentityChallengeActiveProvider.notifier).state = true;
    expect(container.read(zkPassportPipelineProvider).message,
        'user-a proof failed');

    await resetSessionScopedProcessState(container.read(_refProvider));

    expect(container.read(zkPassportPipelineProvider).message, isEmpty);
    expect(
      container.read(zkPassportPipelineProvider).status,
      ZkPassportPipelineStatus.idle,
    );
    expect(container.read(zkIdentityChallengeActiveProvider), isFalse);
  });

  test('telemetry stops attributing the successor to the retired account',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SentryUtil.bootstrap(
      () {},
      settings: const SentrySettings(
        dsn: 'https://public@example.com/1',
        environment: 'test',
        tracesSampleRate: 0,
        profilesSampleRate: 0,
        enableBreadcrumbs: false,
        enablePerformanceTracking: false,
      ),
    );
    addTearDown(Sentry.close);
    await SentryUtil.setUser(id: 'account-a');
    SentryUser? user;
    await Sentry.configureScope((scope) => user = scope.user);
    expect(user?.id, 'account-a');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await resetSessionScopedProcessState(container.read(_refProvider));

    await Sentry.configureScope((scope) => user = scope.user);
    expect(user, isNull);
  });
}
