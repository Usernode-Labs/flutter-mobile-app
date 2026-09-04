import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ready identity accepts either a complete wallet or no wallet', () {
    final walletless = SessionIdentityProjection.ready(
      nativeRevision: '1',
      participantId: 6,
    );
    expect(walletless.status, SessionProjectionStatus.ready);
    expect(walletless.hasWallet, isFalse);
    expect(walletless.accountId, isNull);
    expect(walletless.address, isNull);
    expect(walletless.publicKey, isNull);

    final wallet = SessionIdentityProjection.ready(
      nativeRevision: '2',
      participantId: 6,
      accountId: '7',
      address: 'address',
      publicKey: 'public-key',
    );
    expect(wallet.hasWallet, isTrue);
    expect(wallet.accountId, '7');
    expect(wallet.address, 'address');
    expect(wallet.publicKey, 'public-key');
  });

  test('ready identity rejects partial wallet authority', () {
    expect(
      () => SessionIdentityProjection.ready(
        nativeRevision: '1',
        participantId: 6,
        accountId: '7',
      ),
      throwsArgumentError,
    );
  });
}
