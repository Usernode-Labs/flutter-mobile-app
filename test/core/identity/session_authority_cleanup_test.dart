import 'dart:io';

import 'package:crypto_mobile_app/core/identity/session_authority_cleanup.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
  });

  test('compatibility cleanup removes routing but retains every registry',
      () async {
    const namespace = 'aaaaaaaaaaaaaaaa';
    const bareRegistry = '[{"id":"legacy-account"}]';
    const namespacedRegistry = '[{"id":"namespaced-account"}]';
    SharedPreferences.setMockInitialValues({
      'auth:v3:guest': true,
      'testnet:account:reconcile_pending': true,
      'testnet:acct:guest:leaderboard:participant_id': 7,
      'testnet:identity:namespace': namespace,
      'testnet:accounts:index': bareRegistry,
      'testnet:accounts:activeId': 'legacy-account',
      'testnet:accounts:adopting': namespace,
      'testnet:user:$namespace:accounts:index': namespacedRegistry,
      'testnet:user:$namespace:accounts:activeId': 'namespaced-account',
    });

    expect(
      await clearCompatibilitySessionAuthority(AuthGuestFlag()),
      isTrue,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('auth:v3:guest'), isNull);
    expect(prefs.getBool('testnet:account:reconcile_pending'), isNull);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      isNull,
    );
    expect(prefs.getString('testnet:identity:namespace'), isNull);
    expect(prefs.getString('testnet:accounts:index'), bareRegistry);
    expect(prefs.getString('testnet:accounts:activeId'), 'legacy-account');
    expect(prefs.getString('testnet:accounts:adopting'), namespace);
    expect(
      prefs.getString('testnet:user:$namespace:accounts:index'),
      namespacedRegistry,
    );
    expect(
      prefs.getString('testnet:user:$namespace:accounts:activeId'),
      'namespaced-account',
    );
  });

  test('legacy sign-out fence cleanup deletes only the obsolete authority file',
      () async {
    final root = await Directory.systemTemp.createTemp('legacy-fence-cleanup-');
    addTearDown(() => root.delete(recursive: true));
    final fence = File('${root.path}/testnet.signout_pending');
    final retained = File('${root.path}/wallet.data');
    await fence.writeAsString('1');
    await retained.writeAsString('wallet');

    expect(
      await clearLegacySignOutMarker(directory: () async => root),
      isTrue,
    );

    expect(await fence.exists(), isFalse);
    expect(await retained.readAsString(), 'wallet');
  });
}
