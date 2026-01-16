import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/wallet/models/transaction_item.dart';

void main() {
  group('selectMempoolOutputForDisplay', () {
    test('returns null when outputs empty', () {
      final selected = selectMempoolOutputForDisplay(
        outputs: const [],
        isSent: true,
        ownerAddress: 'ut_owner',
      );

      expect(selected, isNull);
    });

    test('sent tx with one output uses that output', () {
      final outputs = <ParsedMempoolOutput>[
        (
          recipientAddress: 'ut_recipient',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(5))],
        ),
      ];

      final selected = selectMempoolOutputForDisplay(
        outputs: outputs,
        isSent: true,
        ownerAddress: 'ut_owner',
      );

      expect(selected, isNotNull);
      expect(selected!.recipientAddress, equals('ut_recipient'));
      expect(selected.amounts.single.amount, equals(BigInt.from(5)));
    });

    test('sent tx with change filters out owner output', () {
      final outputs = <ParsedMempoolOutput>[
        (
          recipientAddress: 'ut_recipient',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(7))],
        ),
        (
          recipientAddress: 'ut_owner',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(3))],
        ),
      ];

      final selected = selectMempoolOutputForDisplay(
        outputs: outputs,
        isSent: true,
        ownerAddress: 'ut_owner',
      );

      expect(selected, isNotNull);
      expect(selected!.recipientAddress, equals('ut_recipient'));
      expect(selected.amounts.single.amount, equals(BigInt.from(7)));
    });

    test('self-send falls back to first output', () {
      final outputs = <ParsedMempoolOutput>[
        (
          recipientAddress: 'ut_owner',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(9))],
        ),
        (
          recipientAddress: 'ut_owner',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(1))],
        ),
      ];

      final selected = selectMempoolOutputForDisplay(
        outputs: outputs,
        isSent: true,
        ownerAddress: 'ut_owner',
      );

      expect(selected, isNotNull);
      expect(selected!.recipientAddress, equals('ut_owner'));
      expect(selected.amounts.single.amount, equals(BigInt.from(9)));
    });

    test('received tx prefers output to owner', () {
      final outputs = <ParsedMempoolOutput>[
        (
          recipientAddress: 'ut_other',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(2))],
        ),
        (
          recipientAddress: 'ut_owner',
          amounts: [AssetAmount(tokenId: 't', amount: BigInt.from(6))],
        ),
      ];

      final selected = selectMempoolOutputForDisplay(
        outputs: outputs,
        isSent: false,
        ownerAddress: 'ut_owner',
      );

      expect(selected, isNotNull);
      expect(selected!.recipientAddress, equals('ut_owner'));
      expect(selected.amounts.single.amount, equals(BigInt.from(6)));
    });
  });
}
