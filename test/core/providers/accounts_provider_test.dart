import 'dart:convert';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('recovers account index from secure storage when prefs index is missing',
      () async {
    FlutterSecureStorage.setMockInitialValues({
      'testnet:account:acc_0_deadbeef:secretKey': 'secret-key',
      'testnet:account:acc_0_deadbeef:publicKey': 'public-key',
      'testnet:account:acc_0_deadbeef:address': '0xdeadbeef',
      'testnet:account:acc_0_deadbeef:hdIndex': '0',
    });

    final repo = await AccountsRepository.create();
    final accounts = await repo.list();

    expect(accounts, hasLength(1));
    expect(accounts.first.id, 'acc_0_deadbeef');
    expect(accounts.first.name, 'Recovered Account 1');
    expect(accounts.first.address, '0xdeadbeef');
    expect(accounts.first.publicKey, 'public-key');
    expect(repo.getActiveId(), 'acc_0_deadbeef');

    final prefs = await SharedPreferences.getInstance();
    final rawIndex = prefs.getString(
      NetworkPrefs.prefixKeyWith('accounts:index', 'testnet'),
    );
    expect(rawIndex, isNotNull);

    final decoded = jsonDecode(rawIndex!) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect(
      (decoded.single as Map<String, dynamic>)['id'],
      'acc_0_deadbeef',
    );
  });
}
