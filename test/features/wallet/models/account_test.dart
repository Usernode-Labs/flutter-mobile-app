import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/wallet/models/account.dart';

void main() {
  AccountMeta meta() => AccountMeta(
        id: 'id1',
        name: 'Main',
        createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
        derivationPath: "m/44'/0'/0'",
        hdIndex: 0,
        address: 'addr',
        publicKey: 'pub',
        backupConfirmed: false,
      );

  test('copyWith overrides only provided fields, keeps identity fields', () {
    final a = meta();
    final b = a.copyWith(name: 'Renamed', backupConfirmed: true, isDemo: true);
    expect(b.name, 'Renamed');
    expect(b.backupConfirmed, isTrue);
    expect(b.isDemo, isTrue);
    expect(b.id, a.id);
    expect(b.address, a.address);
    expect(a.copyWith().name, a.name);
  });

  test('toJson/fromJson round-trip', () {
    final a = meta().copyWith(isDemo: true);
    final json = a.toJson();
    final b = AccountMeta.fromJson(json);
    expect(b.id, a.id);
    expect(b.name, a.name);
    expect(b.createdAt, a.createdAt);
    expect(b.hdIndex, a.hdIndex);
    expect(b.isDemo, isTrue);
  });

  test('fromJson defaults backupConfirmed/isDemo when absent', () {
    final b = AccountMeta.fromJson({
      'id': 'x',
      'name': 'n',
      'createdAt': DateTime.utc(2024).toIso8601String(),
      'derivationPath': 'm',
      'hdIndex': 2,
      'address': 'a',
      'publicKey': 'p',
    });
    expect(b.backupConfirmed, isFalse);
    expect(b.isDemo, isFalse);
    expect(b.hdIndex, 2);
  });

  test('toString is JSON-encoded', () {
    expect(meta().toString(), contains('"id":"id1"'));
  });
}
