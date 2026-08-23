import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _namespace = 'aaaaaaaaaaaaaaaa';

Map<String, dynamic> _account(String id, String address) => {
      'id': id,
      'name': 'Node Account',
      'createdAt': '2026-01-01T00:00:00.000',
      'derivationPath': 'imported',
      'hdIndex': 0,
      'address': address,
      'publicKey': 'utpk1$address',
      'backupConfirmed': true,
      'isDemo': false,
    };

const _ready = Identity(
  epoch: 7,
  phase: IdentityPhase.ready,
  participantId: 11,
  accountId: 'account-a',
  address: 'address-a',
  sessionId: 'session-a',
  credentialRef: 'credential-a',
  credentialGeneration: 3,
);

const _reconciling = Identity(
  epoch: 7,
  phase: IdentityPhase.reconciling,
  participantId: 11,
  sessionId: 'session-a',
  credentialRef: 'credential-a',
  credentialGeneration: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    NetworkPrefs.setActiveBucket(null, guest: true);
    await NetworkPrefs.init();
    await saveIdentityNamespace(_namespace);
  });

  test('exact capability pins metadata, key disclosure, and signing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'testnet:user:$_namespace:accounts:index',
      jsonEncode([_account('account-a', 'address-a')]),
    );
    await prefs.setString(
      'testnet:user:$_namespace:accounts:activeId',
      'account-a',
    );
    FlutterSecureStorage.setMockInitialValues({
      'testnet:account:account-a:address': 'address-a',
      'testnet:account:account-a:secretKey': 'secret-a',
    });

    final repository = await AccountsRepository.create(
      signer: ({required secretKey, required message}) {
        expect(secretKey, 'secret-a');
        return 'signed:$message';
      },
    );
    final capability = repository.capabilityFor(_ready);

    expect(
        (await repository.getAuthorizedAccount(capability))?.id, 'account-a');
    expect(await repository.getSecretKey(capability), 'secret-a');
    expect(
      await repository.signMessage(capability, 'hello'),
      'signed:hello',
    );
  });

  test('activation reuses only the retained account at the provisioned address',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final original = jsonEncode([
      _account('account-a', 'address-a'),
      _account('account-b', 'address-b'),
    ]);
    await prefs.setString(
      'testnet:user:$_namespace:accounts:index',
      original,
    );
    await prefs.setString(
      'testnet:user:$_namespace:accounts:activeId',
      'account-a',
    );
    FlutterSecureStorage.setMockInitialValues({
      'testnet:account:account-b:address': 'address-b',
      'testnet:account:account-b:secretKey': 'retained-secret-b',
    });

    final derivedSecrets = <String>[];
    final repository = await AccountsRepository.create(
      accountDeriver: ({required secretKey}) {
        derivedSecrets.add(secretKey);
        return AccountExport(
          secretKey: secretKey,
          publicKey: 'public-b',
          address: 'address-b',
        );
      },
    );

    final result = await repository.reconcileProvisionedAccount(
      identity: _reconciling,
      address: 'address-b',
      secretKey: 'response-secret-must-not-replace-retained',
      name: 'Node Account',
    );

    expect(result.account.id, 'account-b');
    expect(result.changed, isTrue);
    expect(
      prefs.getString('testnet:user:$_namespace:accounts:index'),
      original,
      reason: 'reuse must not rewrite or delete retained metadata',
    );
    expect(
      const FlutterSecureStorage().read(
        key: 'testnet:account:account-b:secretKey',
      ),
      completion('retained-secret-b'),
    );
    expect(
      derivedSecrets,
      containsAll(<String>[
        'response-secret-must-not-replace-retained',
        'retained-secret-b',
      ]),
      reason: 'both backend and retained keys must prove the address',
    );
  });

  test('reconcile associates only an exact legacy account with the namespace',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = jsonEncode([
      _account('legacy-a', 'address-a'),
      _account('legacy-b', 'address-b'),
    ]);
    await prefs.setString('testnet:accounts:index', legacy);
    await prefs.setString('testnet:accounts:activeId', 'legacy-a');
    FlutterSecureStorage.setMockInitialValues({
      'testnet:account:legacy-a:address': 'address-a',
      'testnet:account:legacy-a:secretKey': 'secret-a',
      'testnet:account:legacy-b:address': 'address-b',
      'testnet:account:legacy-b:secretKey': 'secret-b',
    });
    final derivedSecrets = <String>[];
    final repository = await AccountsRepository.create(
      accountDeriver: ({required secretKey}) {
        derivedSecrets.add(secretKey);
        return AccountExport(
          secretKey: secretKey,
          publicKey: 'public-b',
          address: secretKey == 'secret-b' ? 'address-b' : 'unexpected',
        );
      },
    );

    expect(await repository.list(), isEmpty,
        reason: 'legacy metadata is not visible before reconciliation');

    final result = await repository.reconcileProvisionedAccount(
      identity: _reconciling,
      address: 'address-b',
      secretKey: 'secret-b',
      name: 'Node Account',
    );

    expect(result.account.id, 'legacy-b');
    expect(result.changed, isTrue);
    expect(
        (await repository.list()).map((account) => account.id), ['legacy-b']);
    expect(repository.getActiveId(), 'legacy-b');
    expect(prefs.getString('testnet:accounts:index'), legacy,
        reason: 'reconciliation must not rewrite or delete legacy metadata');
    expect(prefs.getString('testnet:accounts:activeId'), 'legacy-a');
    expect(
      const FlutterSecureStorage().read(
        key: 'testnet:account:legacy-b:secretKey',
      ),
      completion('secret-b'),
    );
    expect(derivedSecrets, ['secret-b', 'secret-b']);
  });

  test('a provisioned secret/address mismatch writes nothing', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = await AccountsRepository.create(
      accountDeriver: ({required secretKey}) => const AccountExport(
        secretKey: 'derived-secret',
        publicKey: 'derived-public',
        address: 'different-address',
      ),
    );

    await expectLater(
      repository.reconcileProvisionedAccount(
        identity: _reconciling,
        address: 'address-b',
        secretKey: 'response-secret',
        name: 'Node Account',
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      prefs.getString('testnet:user:$_namespace:accounts:index'),
      isNull,
    );
    expect(
      const FlutterSecureStorage().read(
        key: 'testnet:account:acc_0_address-b:secretKey',
      ),
      completion(isNull),
    );
  });
}
