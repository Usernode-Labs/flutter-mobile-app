import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/staking_preference_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
  });

  test('defaults to self-staking', () async {
    const store = StakingPreferenceStore(bucket: 'account-a');

    expect(await store.loadDelegateAddress(), isNull);
    expect(await store.isDelegated(), isFalse);
  });

  test('persists and clears a normalized delegate address', () async {
    const store = StakingPreferenceStore(bucket: 'account-a');

    await store.setDelegateAddress('  B62server  ');
    expect(await store.loadDelegateAddress(), 'B62server');
    expect(await store.isDelegated(), isTrue);

    await store.setDelegateAddress(null);
    expect(await store.loadDelegateAddress(), isNull);
  });

  test('isolates delegation by identity bucket', () async {
    const first = StakingPreferenceStore(bucket: 'account-a');
    const second = StakingPreferenceStore(bucket: 'account-b');

    await first.setDelegateAddress('B62server');

    expect(await first.isDelegated(), isTrue);
    expect(await second.isDelegated(), isFalse);
  });

  test('headless routing uses the explicit journal network and bucket',
      () async {
    SharedPreferences.setMockInitialValues({
      'internal:acct:account-a:staking:delegate_address': 'B62server',
    });
    const store = StakingPreferenceStore.forOwner(
      network: 'internal',
      bucket: 'account-a',
    );

    expect(await store.loadDelegateAddress(), 'B62server');
  });
}
