import 'fixture_harness.dart';

const _source = '''
void send(dynamic wallet) {
  wallet.txSend(fromPkHash: from, amount: amount, toPkHash: to, memo: memo);
  wallet.txSendResult(
    fromPkHash: from,
    amount: amount,
    toPkHash: to,
    memo: memo,
  );
}
''';

void main() {
  final outside = lintRulesFor(
    _source,
    filePath: 'lib/features/wallet/send.dart',
  );
  final violations =
      outside.where((rule) => rule == 'wallet_effect_gateway_only').length;
  if (violations != 2) {
    throw StateError(
        'Expected both raw wallet sends to be caught; got $outside');
  }

  final facade = lintRulesFor(
    _source,
    filePath: 'lib/features/node/node_service.dart',
  );
  if (facade.contains('wallet_effect_gateway_only')) {
    throw StateError('node_service.dart should be exempt.');
  }

  final similarlyNamed = lintRulesFor('''
void inspect(dynamic wallet) {
  wallet.txSendStatus();
}
''', filePath: 'lib/features/wallet/send.dart');
  if (similarlyNamed.contains('wallet_effect_gateway_only')) {
    throw StateError('Only exact raw effect names should be caught.');
  }

  final unrelatedTarget = lintRulesFor('''
void send(dynamic queue) {
  queue.txSend();
  queue.txSendResult();
}
''', filePath: 'lib/features/wallet/send.dart');
  if (unrelatedTarget.contains('wallet_effect_gateway_only')) {
    throw StateError('Only the raw wallet target should be caught.');
  }

  final cascade = lintRulesFor('''
void send(dynamic wallet) {
  wallet..txSendResult();
}
''', filePath: 'lib/features/wallet/send.dart');
  if (!cascade.contains('wallet_effect_gateway_only')) {
    throw StateError('Cascaded raw wallet effects must be caught.');
  }

  print('wallet_effect_gateway_only fixture passed');
}
