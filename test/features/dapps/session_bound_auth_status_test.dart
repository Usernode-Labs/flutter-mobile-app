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

    expect(gate.isAuthenticatedBlocked, isFalse);
    expect(gate.isWalletBlocked, isFalse);
    expect(gate.blocks('getNodeAddress'), isFalse);
    expect(gate.blocks('signMessage'), isFalse);
  });

  test('session handoff gate can start blocked for the chromeless shell', () {
    final gate = SessionHandoffGate(initiallyBlocked: true);

    expect(gate.isAuthenticatedBlocked, isTrue);
    expect(gate.isWalletBlocked, isTrue);
    expect(gate.blocks('getNodeAddress'), isTrue);
    expect(gate.blocks('signMessage'), isTrue);
  });

  test('session handoff blocks authenticated and wallet dispatch sets', () {
    final gate = SessionHandoffGate()..begin();

    expect(SessionHandoffGate.walletScopedMethods, {
      'getNodeAddress',
      'sendTransaction',
      'signMessage',
      'txObserved',
      'getWalletState',
      'getTransactionRecords',
    });
    expect(SessionHandoffGate.authenticatedScopedMethods, {
      'getSocialPushState',
      'setSocialPushEnabled',
      'claimPendingSocialNotification',
      'ackPendingSocialNotification',
    });
    for (final method in {
      ...SessionHandoffGate.walletScopedMethods,
      ...SessionHandoffGate.authenticatedScopedMethods,
    }) {
      expect(gate.blocks(method), isTrue, reason: method);
    }
    expect(gate.blocks('completeLogin'), isFalse);
    expect(gate.blocks('getAuthStatus'), isFalse);
  });

  test('authenticated admission opens push while wallet stays closed', () {
    final gate = SessionHandoffGate()..begin();
    final reconciling = ready.copyWith(
      phase: IdentityPhase.reconciling,
      clearAccount: true,
    );

    expect(gate.admitAuthenticated(reconciling), isTrue);

    expect(gate.isAuthenticatedBlocked, isFalse);
    expect(gate.isWalletBlocked, isTrue);
    expect(gate.authenticates(reconciling), isTrue);
    expect(gate.blocks('getSocialPushState'), isFalse);
    expect(gate.blocks('getWalletState'), isTrue);
    expect(gate.admitWallet(reconciling), isFalse);
  });

  test('wallet admission waits for the same participant and epoch to settle',
      () {
    final gate = SessionHandoffGate()..begin();
    final reconciling = ready.copyWith(
      phase: IdentityPhase.reconciling,
      clearAccount: true,
    );
    gate.admitAuthenticated(reconciling);

    expect(gate.admitWallet(ready), isTrue);
    expect(gate.blocks('getWalletState'), isFalse);

    gate.restrictWallet(reconciling);
    expect(gate.blocks('getWalletState'), isTrue);
    expect(
      gate.admitWallet(ready.copyWith(epoch: ready.epoch + 1)),
      isFalse,
    );
  });

  test('anonymous admission reopens local dispatch without an auth binding',
      () {
    final gate = SessionHandoffGate()..begin();

    gate.admitAnonymous();

    expect(gate.isAuthenticatedBlocked, isFalse);
    expect(gate.isWalletBlocked, isFalse);
    expect(gate.authenticates(ready), isFalse);
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
