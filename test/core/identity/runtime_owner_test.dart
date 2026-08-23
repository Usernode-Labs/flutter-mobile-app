import 'package:crypto_mobile_app/core/identity/runtime_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const owner = RuntimeOwner(
    sessionId: 'session-a',
    runtimeGeneration: 7,
    accountId: 'account-a',
    address: 'address-a',
  );

  test('complete runtime owner round-trips across the platform map', () {
    expect(owner.toMap(), {
      'session_id': 'session-a',
      'runtime_generation': 7,
      'account_id': 'account-a',
      'address': 'address-a',
    });
    expect(RuntimeOwner.fromMap(owner.toMap()), owner);
  });

  test('missing, malformed, and zero runtime owners fail closed', () {
    final valid = owner.toMap();
    for (final invalid in <Map<String, dynamic>>[
      <String, dynamic>{...valid}..remove('session_id'),
      <String, dynamic>{...valid}..remove('runtime_generation'),
      <String, dynamic>{...valid}..remove('account_id'),
      <String, dynamic>{...valid}..remove('address'),
      <String, dynamic>{...valid, 'session_id': ''},
      <String, dynamic>{...valid, 'runtime_generation': 0},
      <String, dynamic>{...valid, 'runtime_generation': '7'},
      <String, dynamic>{...valid, 'account_id': ''},
      <String, dynamic>{...valid, 'address': ''},
    ]) {
      expect(RuntimeOwner.fromMap(invalid), isNull);
    }
  });
}
