import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

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

  test('guest flag set/read/clear', () async {
    final flag = AuthGuestFlag();
    expect(await flag.isGuest(), false);
    await flag.setGuest();
    expect(await flag.isGuest(), true);
    await flag.clear();
    expect(await flag.isGuest(), false);
  });
}
