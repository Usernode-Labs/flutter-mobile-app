import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/node_runtime_binding.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    IdentitySnapshots.reset();
  });

  tearDown(IdentitySnapshots.reset);

  test('durable fingerprint is stable across isolate-local identity epochs',
      () async {
    const firstIdentity = Identity(
      epoch: 2,
      phase: IdentityPhase.ready,
      participantId: 10,
      accountId: 'account-a',
      address: 'address-a',
      provisionedSeasonId: 7,
    );
    const restoredIdentity = Identity(
      epoch: 1,
      phase: IdentityPhase.ready,
      participantId: 10,
      accountId: 'account-a',
      address: 'address-a',
      provisionedSeasonId: 7,
    );
    IdentitySnapshots.publish(firstIdentity);
    final first = await resolveNodeRuntimeBinding(firstIdentity);

    IdentitySnapshots.reset();
    IdentitySnapshots.publish(restoredIdentity);
    final restored = await resolveNodeRuntimeBinding(restoredIdentity);

    expect(restored, first);
    expect(restored!.recoveryFingerprint, first!.recoveryFingerprint);
  });

  test('guest identity resolves to a keyless non-recoverable binding',
      () async {
    const identity = Identity(
      epoch: 3,
      phase: IdentityPhase.guest,
    );
    IdentitySnapshots.publish(identity);

    final binding = await resolveNodeRuntimeBinding(identity);

    expect(binding, isNotNull);
    expect(binding!.identityPhase, IdentityPhase.guest);
    expect(binding.accountId, isNull);
    expect(binding.address, isNull);
    expect(binding.productionEligible, isFalse);
  });

  test('local-only account resolves without an authenticated participant',
      () async {
    const identity = Identity(
      epoch: 4,
      phase: IdentityPhase.unauthenticated,
      accountId: 'local-account',
      address: 'local-address',
    );
    final bucket = NetworkPrefs.bucketForAddress('local-address');
    SharedPreferences.setMockInitialValues({
      NetworkPrefs.prefixAccountKeyFor('bp:released', bucket): true,
    });
    await NetworkPrefs.init();
    IdentitySnapshots.publish(identity);

    final binding = await resolveNodeRuntimeBinding(identity);

    expect(binding, isNotNull);
    expect(binding!.identityPhase, IdentityPhase.unauthenticated);
    expect(binding.participantId, isNull);
    expect(binding.accountId, 'local-account');
    expect(binding.blockProductionReleased, isTrue);
    expect(binding.productionEligible, isFalse);
  });
}
