import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('token store write/read/clear', () async {
    final store = AuthTokenStore();
    expect(await store.read(), isNull);
    await store.write('sess-1');
    expect(await store.read(), 'sess-1');
    await store.clear();
    expect(await store.read(), isNull);
  });

  group('UserTypeStore', () {
    test('write/read/clear round-trips every tier', () async {
      final store = UserTypeStore();
      expect(await store.read(), isNull);
      for (final level in UserLevel.values) {
        await store.write(level);
        expect(await store.read(), level);
      }
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('isGuest is true only for the guest tier', () async {
      final store = UserTypeStore();
      expect(await store.isGuest(), false, reason: 'absent');
      await store.write(UserLevel.guest);
      expect(await store.isGuest(), true);
      await store.write(UserLevel.member);
      expect(await store.isGuest(), false);
      await store.write(UserLevel.operator);
      expect(await store.isGuest(), false);
    });

    // An unknown string must not crash or be coerced into a real tier —
    // a downgrade that read garbage as `operator` would start block production.
    test('unrecognised stored value reads as null, not a tier', () async {
      SharedPreferences.setMockInitialValues({'app:user_type': 'archon'});
      expect(await UserTypeStore().read(), isNull);
      expect(await UserTypeStore().isGuest(), false);
    });
  });
}
