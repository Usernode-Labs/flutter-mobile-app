import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/api_version_gate.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedSession() async {
    await AuthTokenStore().write('sess-1');
    await UserTypeStore().write(UserLevel.operator);
  }

  test('absent version clears the session (new install)', () async {
    await seedSession();
    final result = await reconcileApiVersion();

    expect(result.stored, isNull);
    expect(result.cleared, true);
    expect(result.isCurrent, false);
    expect(await AuthTokenStore().read(), isNull);
    expect(await UserTypeStore().read(), isNull);
  });

  test('older version clears the session (incompatible upgrade)', () async {
    SharedPreferences.setMockInitialValues({'app:api_version': 2});
    await seedSession();
    final result = await reconcileApiVersion();

    expect(result.stored, 2);
    expect(result.cleared, true);
    expect(await AuthTokenStore().read(), isNull);
    expect(await UserTypeStore().read(), isNull);
  });

  test('current version leaves the session untouched', () async {
    SharedPreferences.setMockInitialValues(
        {'app:api_version': kCurrentApiVersion});
    await seedSession();
    final result = await reconcileApiVersion();

    expect(result.cleared, false);
    expect(result.isCurrent, true);
    expect(await AuthTokenStore().read(), 'sess-1');
    expect(await UserTypeStore().read(), UserLevel.operator);
  });

  // The gate must be idempotent: it runs on every launch, and a second run
  // before the version is written must not do anything different.
  test('re-running before the version is written stays cleared', () async {
    await seedSession();
    await reconcileApiVersion();
    final second = await reconcileApiVersion();

    expect(second.cleared, true);
    expect(await AuthTokenStore().read(), isNull);
  });

  test('markApiVersionCurrent makes the next check a no-op', () async {
    await seedSession();
    await reconcileApiVersion();
    await markApiVersionCurrent();

    await AuthTokenStore().write('sess-2');
    final after = await reconcileApiVersion();

    expect(after.isCurrent, true);
    expect(after.cleared, false);
    expect(await AuthTokenStore().read(), 'sess-2');
  });

  // On-chain accounts live in secure storage under different keys and must
  // survive: an operator who logs back in is an operator again.
  test('does not touch non-session secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({
      'testnet:account:acc_0:secretKey': 'utsk-secret',
    });
    await seedSession();
    await reconcileApiVersion();

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'testnet:account:acc_0:secretKey'),
        'utsk-secret');
  });
}
