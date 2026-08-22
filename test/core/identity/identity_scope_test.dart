import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';

void main() {
  test('only a signed-in ready identity may currently start a node', () {
    for (final phase in IdentityPhase.values) {
      final identity = Identity(epoch: 1, phase: phase);
      expect(
        identity.allowsNodeStart,
        phase == IdentityPhase.ready,
        reason: phase.name,
      );
    }
  });

  test('sameScopeAs matches only the complete captured identity snapshot', () {
    const identity = Identity(
      epoch: 7,
      phase: IdentityPhase.ready,
      participantId: 11,
      accountId: 'account-a',
      address: 'address-a',
      provisionedSeasonId: 3,
      sessionId: 'session-a',
      credentialRef: 'credential-a',
      credentialGeneration: 1,
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
    expect(
      identity.sameScopeAs(identity.copyWith(sessionId: 'session-b')),
      isFalse,
    );
    expect(
      identity.sameScopeAs(identity.copyWith(credentialGeneration: 2)),
      isFalse,
    );
  });

  test('credential leases never print their token', () {
    const lease = AuthCredentialLease(epoch: 7, token: 'secret-token');
    expect(lease.toString(), isNot(contains('secret-token')));
  });
}
