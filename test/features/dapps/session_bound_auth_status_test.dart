import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/dapps/session_bound_auth_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ready = Identity(
    epoch: 7,
    phase: IdentityPhase.ready,
    participantId: 42,
    accountId: 'account-42',
    address: 'address-42',
  );

  test('session handoff gate starts open for anonymous wallet sign-in', () {
    final gate = SessionHandoffGate();

    expect(gate.isBlocked, isFalse);
    expect(gate.blocks('getNodeAddress'), isFalse);
    expect(gate.blocks('signMessage'), isFalse);
  });

  test('session handoff blocks the exact session-scoped dispatch set', () {
    final gate = SessionHandoffGate()..begin();

    expect(SessionHandoffGate.sessionScopedMethods, {
      'getNodeAddress',
      'sendTransaction',
      'signMessage',
      'txObserved',
      'getWalletState',
      'getTransactionRecords',
    });
    for (final method in SessionHandoffGate.sessionScopedMethods) {
      expect(gate.blocks(method), isTrue, reason: method);
    }
    expect(gate.blocks('completeLogin'), isFalse);
    expect(gate.blocks('getAuthStatus'), isFalse);
  });

  test('confirmed authenticated or anonymous admission reopens dispatch', () {
    final gate = SessionHandoffGate()..begin();

    gate.admit();

    expect(gate.isBlocked, isFalse);
    expect(gate.blocks('getWalletState'), isFalse);
  });

  test('status carries the participant and identity epoch', () {
    expect(sessionBoundAuthStatus(ready, reconciliationStatus: 'settled'), {
      'phase': 'ready',
      'address': 'address-42',
      'participantId': 42,
      'epoch': 7,
      'reconciliationStatus': 'settled',
    });
  });

  test('node start scope must match participant, epoch, and address', () {
    expect(
      sessionScopeMatchesReadyIdentity(
        ready,
        participantId: 42,
        epoch: 7,
        address: 'address-42',
      ),
      isTrue,
    );
    expect(
      sessionScopeMatchesReadyIdentity(
        ready,
        participantId: 43,
        epoch: 7,
        address: 'address-42',
      ),
      isFalse,
    );
    expect(
      sessionScopeMatchesReadyIdentity(
        ready,
        participantId: 42,
        epoch: 6,
        address: 'address-42',
      ),
      isFalse,
    );
    expect(
      sessionScopeMatchesReadyIdentity(
        ready,
        participantId: 42,
        epoch: 7,
        address: 'address-other',
      ),
      isFalse,
    );
  });

  test('unsettled identities never match a start scope', () {
    expect(
      sessionScopeMatchesReadyIdentity(
        ready.copyWith(phase: IdentityPhase.reconciling),
        participantId: 42,
        epoch: 7,
        address: 'address-42',
      ),
      isFalse,
    );
  });
}
