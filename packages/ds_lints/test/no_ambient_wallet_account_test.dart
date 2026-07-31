import 'fixture_harness.dart';

void _expectViolation(String source, String filePath) {
  final rules = lintRulesFor(source, filePath: filePath);
  if (!rules.contains('no_ambient_wallet_account')) {
    throw StateError(
        'Expected no_ambient_wallet_account in $filePath; got $rules');
  }
}

void main() {
  _expectViolation(
    'Future<void> load(dynamic repository) async => repository.getActive();',
    'lib/features/wallet/data/wallet_store.dart',
  );
  _expectViolation(
    "String key() => NetworkPrefs.prefixAccountKey('recent');",
    'lib/features/dapps/data/dapp_cache.dart',
  );
  _expectViolation(
    'String bucket() => NetworkPrefs.activeBucket;',
    'lib/core/providers/mempool_provider.dart',
  );
  _expectViolation(
    'String bucket() => prefs.NetworkPrefs.activeBucket;',
    'lib/core/providers/recipient_history_provider.dart',
  );
  _expectViolation(
    'Future<void> load(dynamic repo) async => repo.getActive();',
    'lib/core/providers/wallet_provider.dart',
  );
  _expectViolation(
    'Future<void> load(dynamic accountRepo) async { accountRepo..getActive(); }',
    'lib/features/wallet/data/wallet_store.dart',
  );
  _expectViolation(
    'Future<void> load(dynamic accounts) async => accounts.getActive();',
    'lib/features/dapps/data/dapp_cache.dart',
  );
  _expectViolation(
    "String key() => NetworkPrefs.prefixAccountKey('balance');",
    'lib/core/services/explorer_service.dart',
  );

  final outside = lintRulesFor(
    'Future<void> load(dynamic repository) async => repository.getActive();',
    filePath: 'lib/core/providers/accounts_provider.dart',
  );
  if (outside.contains('no_ambient_wallet_account')) {
    throw StateError('Unrelated repository code should not be in scope.');
  }

  final unrelatedMethod = lintRulesFor(
    'Future<void> load(dynamic featureFlags) async => '
    'featureFlags.getActive();',
    filePath: 'lib/core/providers/wallet_provider.dart',
  );
  if (unrelatedMethod.contains('no_ambient_wallet_account')) {
    throw StateError('An unrelated getActive method must remain allowed.');
  }

  final explicitScope = lintRulesFor(
    "String key(AccountStorageScope scope) => scope.preferenceKey('recent');",
    filePath: 'lib/core/providers/recipient_history_provider.dart',
  );
  if (explicitScope.contains('no_ambient_wallet_account')) {
    throw StateError('Explicit account scopes must remain allowed.');
  }

  print('no_ambient_wallet_account fixture passed');
}
