import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction confirmation and submission hold the expected awake leases',
      () {
    final source = File(
      'lib/features/dapps/bridge/dapp_bridge_wallet.dart',
    ).readAsStringSync();
    final handler = source.substring(
      source.indexOf('Future<void> _handleSubmitTransaction('),
      source.indexOf('Future<void> _handleSignMessage('),
    );

    final surface = handler.indexOf(
      'SessionNodeAwakeReason.transactionSurface',
    );
    final confirmation = handler.indexOf(
      'await _requestTransactionConfirmation(',
    );
    final submission = handler.indexOf(
      'SessionNodeAwakeReason.transactionSubmission',
    );
    final nativeSubmit = handler.indexOf(
      'await operation.submitTransaction(',
    );

    expect(surface, greaterThanOrEqualTo(0));
    expect(confirmation, greaterThan(surface));
    expect(submission, greaterThan(confirmation));
    expect(nativeSubmit, greaterThan(submission));
    expect('await submissionLease.release()'.allMatches(handler), hasLength(1));
    expect('await surfaceLease.release()'.allMatches(handler), hasLength(1));
  });
}
