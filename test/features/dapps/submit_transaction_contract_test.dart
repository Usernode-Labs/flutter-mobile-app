import 'package:crypto_mobile_app/features/dapps/submit_transaction_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the exact submitTransaction request', () {
    final request = SubmitTransactionRequest.fromBridgeArgs({
      'destinationPubkey': ' destination ',
      'amount': 42,
      'memo': ' memo is preserved ',
      'confirmation': {
        'title': ' Confirm ',
        'subtitle': ' Details ',
      },
    });

    expect(request.destinationPubkey, 'destination');
    expect(request.amount, BigInt.from(42));
    expect(request.memo, ' memo is preserved ');
    expect(request.confirmation?.title, 'Confirm');
    expect(request.confirmation?.subtitle, 'Details');
  });

  test('accepts the largest JavaScript-safe positive integer', () {
    final request = SubmitTransactionRequest.fromBridgeArgs({
      'destinationPubkey': 'destination',
      'amount': SubmitTransactionRequest.maxSafeInteger,
      'memo': '',
    });

    expect(
      request.amount,
      BigInt.from(SubmitTransactionRequest.maxSafeInteger),
    );
    expect(request.confirmation, isNull);
  });

  test('rejects legacy aliases, unknown fields, and unsafe amounts', () {
    Map<String, Object?> requestWith(Object? amount) => {
          'destinationPubkey': 'destination',
          'amount': amount,
          'memo': '',
        };

    for (final args in <Map<String, Object?>>[
      {
        'destination_pubkey': 'destination',
        'amount': 1,
        'memo': '',
      },
      {...requestWith(1), 'confirm_title': 'legacy'},
      requestWith(0),
      requestWith(-1),
      requestWith(1.5),
      requestWith('1'),
      requestWith(SubmitTransactionRequest.maxSafeInteger + 1),
    ]) {
      expect(
        () => SubmitTransactionRequest.fromBridgeArgs(args),
        throwsA(isA<FormatException>()),
        reason: args.toString(),
      );
    }
  });

  test('rejects malformed confirmation fields', () {
    expect(
      () => SubmitTransactionRequest.fromBridgeArgs({
        'destinationPubkey': 'destination',
        'amount': 1,
        'memo': '',
        'confirmation': {'title': 7},
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('successful result contains only a non-empty authoritative txId', () {
    final result = SubmitTransactionResult(txId: 'tx-123');

    expect(result.toBridgeJson(), {'txId': 'tx-123'});
    expect(
      () => SubmitTransactionResult(txId: '  '),
      throwsArgumentError,
    );
    expect(
      () => SubmitTransactionResult(txId: ' tx-123 '),
      throwsArgumentError,
    );
  });
}
