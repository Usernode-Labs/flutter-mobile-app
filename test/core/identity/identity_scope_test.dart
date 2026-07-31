import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/identity/wallet_identity_lease.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  setUp(() {
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  test('identity lease matches the complete snapshot and network', () {
    const identity = Identity(
      epoch: 7,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
      provisionedSeasonId: 3,
    );
    final lease = IdentityLease.capture(identity, network: 'testnet');

    expect(
      lease.matches(identity, currentNetwork: 'testnet'),
      isTrue,
    );
    expect(
      lease.matches(
        identity.copyWith(participantId: 12),
        currentNetwork: 'testnet',
      ),
      isFalse,
    );
    expect(
      lease.matches(identity, currentNetwork: 'internal'),
      isFalse,
    );
  });

  test('sameScopeAs matches only the complete captured identity snapshot', () {
    const identity = Identity(
      epoch: 7,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
      provisionedSeasonId: 3,
    );

    expect(identity.sameScopeAs(identity), isTrue);
    expect(identity.sameScopeAs(identity.copyWith(participantId: 12)), isFalse);
    expect(
      identity.sameScopeAs(
        identity.copyWith(phase: IdentityPhase.reconciling),
      ),
      isFalse,
    );
    expect(identity.sameScopeAs(identity.copyWith(epoch: 8)), isFalse);
  });

  test('credential leases never print their token', () {
    const lease = AuthCredentialLease(epoch: 7, token: 'secret-token');
    expect(lease.toString(), isNot(contains('secret-token')));
  });

  test('stable scopes build keys without ambient bucket or network', () {
    const scope = AccountStorageScope(
      network: 'internal',
      bucket: 'bucket-a',
      accountId: 'account-a',
      address: 'address-a',
    );

    expect(
      scope.preferenceKey('recent'),
      'internal:acct:bucket-a:recent',
    );
  });

  test('only an account-owning identity can mint wallet authority', () {
    const ready = Identity(
      epoch: 3,
      phase: IdentityPhase.ready,
      participantId: 1,
      accountId: 'account-a',
      address: 'address-a',
    );

    final lease = WalletIdentityLease.capture(ready, network: 'testnet');
    expect(lease, isNotNull);
    expect(lease!.address, 'address-a');
    expect(
      WalletIdentityLease.capture(
        ready.copyWith(phase: IdentityPhase.reconciling),
      ),
      isNull,
    );
    expect(
      WalletIdentityLease.capture(
        const Identity(epoch: 4, phase: IdentityPhase.guest),
      ),
      isNull,
    );
    expect(
      WalletIdentityLease.capture(
        const Identity(
          epoch: 5,
          phase: IdentityPhase.ready,
          participantId: 1,
        ),
      ),
      isNull,
    );
  });

  test('wallet data ownership is stable across runtime generations', () {
    const account = AccountStorageScope(
      network: 'testnet',
      bucket: 'bucket-a',
      accountId: 'account-a',
      address: 'address-a',
    );
    const first = WalletDataScope(
      accountScope: account,
      chainId: 'chain-a',
    );

    expect(
      first,
      const WalletDataScope(
        accountScope: account,
        chainId: 'chain-a',
      ),
    );
    expect(
      const WalletRuntimeLease(dataScope: first, runtimeGeneration: 4),
      isNot(
        const WalletRuntimeLease(
          dataScope: first,
          runtimeGeneration: 5,
        ),
      ),
    );
  });

  test('reconcile node authority names the account before identity commit', () {
    const reconciling = Identity(
      epoch: 9,
      phase: IdentityPhase.reconciling,
      participantId: 11,
    );
    final lease = IdentityLease.capture(reconciling, network: 'testnet');
    final account = AccountStorageScope(
      network: 'testnet',
      bucket: NetworkPrefs.bucketForAddress('address-a'),
      accountId: 'account-a',
      address: 'address-a',
    );

    final authority = NodeStartAuthority.forReconciliation(
      identityLease: lease,
      accountScope: account,
    );

    expect(authority, isNotNull);
    expect(authority!.isReconciliation, isTrue);
    expect(authority.accountScope, account);
    expect(
      NodeStartAuthority.forReconciliation(
        identityLease: lease,
        accountScope: AccountStorageScope(
          network: 'internal',
          bucket: account.bucket,
          accountId: account.accountId,
          address: account.address,
        ),
      ),
      isNull,
    );
  });

  test('runtime reuse requires the same network, mode, account and generation',
      () {
    const identity = Identity(
      epoch: 1,
      phase: IdentityPhase.ready,
      participantId: 1,
      accountId: 'account-a',
      address: 'address-a',
    );
    final start = NodeStartAuthority.capture(identity, network: 'testnet')!;
    final runtime = NodeRuntimeAuthority(
      network: 'testnet',
      accountScope: start.accountScope,
      generation: 4,
    );

    expect(
      runtime.matchesStart(
        start,
        keyless: false,
        currentGeneration: 4,
      ),
      isTrue,
    );
    expect(
      runtime.matchesStart(
        start,
        keyless: true,
        currentGeneration: 4,
      ),
      isFalse,
    );
    expect(
      runtime.matchesStart(
        start,
        keyless: false,
        currentGeneration: 5,
      ),
      isFalse,
    );
  });

  test('node start gate fails closed for unknown and accountless states', () {
    expect(const Identity.unknown().allowsNodeStart, isFalse);
    expect(
      const Identity(
        epoch: 1,
        phase: IdentityPhase.unauthenticated,
      ).allowsNodeStart,
      isFalse,
    );
    expect(
      const Identity(
        epoch: 2,
        phase: IdentityPhase.guest,
      ).allowsNodeStart,
      isTrue,
    );
  });
}
