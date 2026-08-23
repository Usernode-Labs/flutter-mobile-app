import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account authorities are private and raw bridge signing is forbidden',
      () {
    final gateway = File(
      'lib/core/identity/session_authority_gateway.dart',
    ).readAsStringSync();
    final accounts = File(
      'lib/core/providers/accounts_provider.dart',
    ).readAsStringSync();
    final bridge = File(
      'lib/features/dapps/bridge/dapp_bridge_wallet.dart',
    ).readAsStringSync();

    expect(gateway, contains('AccountCapability._('));
    expect(gateway, contains('AccountReconciliationLease._('));
    expect(
      accounts,
      isNot(contains('getSecretKey(String accountId)')),
    );
    expect(bridge, isNot(contains('frb_account.signMessage(')));
    expect(bridge, isNot(contains('.getSecretKey(')));
  });

  test('bootstrap restores authority before touching retained accounts', () {
    final source = File(
      'lib/core/bootstrap/app_bootstrap.dart',
    ).readAsStringSync();
    final run = source.substring(
      source.indexOf('static Future<AppBootstrapResult> initNonUi'),
      source.indexOf('static Future<SessionAuthorityGateway>'),
    );

    final restore = run.indexOf(
      'await container.read(identityProvider.notifier).restore()',
    );
    final repository = run.indexOf('await AccountsRepository.create(');
    final bootstrapIdentity = run.indexOf('await _applyBootstrapIdentity(');
    expect(restore, greaterThanOrEqualTo(0));
    expect(repository, greaterThan(restore));
    expect(bootstrapIdentity, greaterThan(restore));
  });
}
