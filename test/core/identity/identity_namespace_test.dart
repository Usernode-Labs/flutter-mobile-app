// The per-user storage namespace (`identity_hash`) and the account registry
// that hangs off it.
//
// The point of the namespace is segregation: local accounts now outlive a
// sign-out, so a second user on the same device must never resolve the first
// user's registry — and the FIRST user signing back in must resolve theirs, or
// their wallet is unreachable.

import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _alice = 'a145a65507b14025';
const _bob = 'd1eb5fd4504344f1';

Identity _ready({
  required String accountId,
  required String address,
  required String sessionId,
}) =>
    Identity(
      epoch: 1,
      phase: IdentityPhase.ready,
      participantId: 7,
      accountId: accountId,
      address: address,
      sessionId: sessionId,
    );

String _indexJson(String id, String address) => jsonEncode([
      {
        'id': id,
        'name': 'Node Account',
        'createdAt': '2026-01-01T00:00:00.000',
        'derivationPath': 'imported',
        'hdIndex': 0,
        'address': address,
        'publicKey': 'utpk1$address',
        'backupConfirmed': true,
        'isDemo': false,
      }
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    NetworkPrefs.setActiveBucket(null, guest: true);
    await NetworkPrefs.init();
  });

  group('parsing', () {
    test('a well-formed hash is accepted from both user payloads', () {
      final participant = Participant.fromJson({
        'id': 1,
        'email': 'alice@example.com',
        'email_confirmed': true,
        'identity_hash': _alice,
      });
      expect(participant.identityHash, _alice);

      final me = Me.fromJson({
        'id': 1,
        'email': 'alice@example.com',
        'email_confirmed': true,
        'identity_hash': _alice,
      });
      expect(me.identityHash, _alice);
    });

    test('a server that does not issue the field yields null, not a crash', () {
      final participant = Participant.fromJson({
        'id': 1,
        'email': 'alice@example.com',
        'email_confirmed': true,
      });
      expect(participant.identityHash, isNull);
    });

    test('anything that is not a 16-hex namespace is rejected', () {
      // A storage key is being built from this. Nothing that could widen it
      // into another user's namespace — or into a path — may pass.
      for (final rejected in <Object?>[
        '',
        'not-hex-at-all!!',
        'a145a65507b1402', // 15 chars
        'a145a65507b140255', // 17 chars
        'a145a65507b14025:../accounts:index',
        42,
        true,
        null,
      ]) {
        expect(
          normalizeIdentityHash(rejected),
          isNull,
          reason: 'must reject ${jsonEncode(rejected)}',
        );
      }
    });

    test('a hash is normalized to lower case', () {
      expect(normalizeIdentityHash(_alice.toUpperCase()), _alice);
      expect(normalizeIdentityHash('  $_alice '), _alice);
    });
  });

  group('registry namespacing', () {
    test('two users on one device never see each other\'s accounts', () async {
      // Seeded directly: account creation derives keys through the Rust
      // bridge, which unit tests do not load. What is under test is which
      // rows each session resolves, not how they were written.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:user:$_alice:accounts:index',
        _indexJson('acct-alice', 'ut1alice'),
      );
      await prefs.setString(
        'testnet:user:$_alice:accounts:activeId',
        'acct-alice',
      );

      await saveIdentityNamespace(_alice);
      final aliceRepo = await AccountsRepository.create();
      final aliceCapability = aliceRepo.capabilityFor(_ready(
        accountId: 'acct-alice',
        address: 'ut1alice',
        sessionId: 'session-alice-a',
      ));
      expect(
        (await aliceRepo.list(aliceCapability)).single.id,
        'acct-alice',
      );

      // Alice signs out (her rows stay) and Bob signs in.
      await saveIdentityNamespace(_bob);
      final bobRepo = await AccountsRepository.create();
      final bobCapability = bobRepo.capabilityFor(_ready(
        accountId: 'acct-bob',
        address: 'ut1bob',
        sessionId: 'session-bob',
      ));

      expect(await bobRepo.list(bobCapability), isEmpty,
          reason: 'Bob starts clean');
      expect(bobRepo.getActiveId(bobCapability), isNull);

      // Alice signs back in and finds her wallet exactly where she left it.
      await saveIdentityNamespace(_alice);
      final aliceAgain = await AccountsRepository.create();
      final aliceAgainCapability = aliceAgain.capabilityFor(_ready(
        accountId: 'acct-alice',
        address: 'ut1alice',
        sessionId: 'session-alice-b',
      ));
      expect(
        (await aliceAgain.list(aliceAgainCapability)).single.id,
        'acct-alice',
      );
      expect(aliceAgain.getActiveId(aliceAgainCapability), 'acct-alice');
    });

    test('an install with no session cannot enumerate legacy accounts',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final legacy = _indexJson('acct-legacy', 'ut1legacy');
      await prefs.setString(
        'testnet:accounts:index',
        legacy,
      );

      final repo = await AccountsRepository.create();

      expect(
        () => repo.capabilityFor(_ready(
          accountId: 'acct-legacy',
          address: 'ut1legacy',
          sessionId: 'session-none',
        )),
        throwsA(isA<StaleAuthCredentialException>()),
      );
      expect(prefs.getString('testnet:accounts:index'), legacy);
    });

    test('sign-in does not automatically claim a legacy registry', () async {
      final prefs = await SharedPreferences.getInstance();
      final legacy = _indexJson('acct-legacy', 'ut1legacy');
      await prefs.setString(
        'testnet:accounts:index',
        legacy,
      );
      await prefs.setString('testnet:accounts:activeId', 'acct-legacy');
      await saveIdentityNamespace(_alice);

      final repo = await AccountsRepository.create();
      final capability = repo.capabilityFor(_ready(
        accountId: 'acct-legacy',
        address: 'ut1legacy',
        sessionId: 'session-alice',
      ));

      expect(await repo.list(capability), isEmpty);
      expect(repo.getActiveId(capability), isNull);
      expect(prefs.getString('testnet:accounts:index'), legacy);
      expect(prefs.getString('testnet:accounts:activeId'), 'acct-legacy');
      expect(
        prefs.getString('testnet:user:$_alice:accounts:index'),
        isNull,
      );
    });

    test('a bare registry is invisible to every namespace until reconcile',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-legacy', 'ut1legacy'),
      );

      await saveIdentityNamespace(_alice);
      final aliceRepo = await AccountsRepository.create();
      final aliceCapability = aliceRepo.capabilityFor(_ready(
        accountId: 'acct-legacy',
        address: 'ut1legacy',
        sessionId: 'session-alice',
      ));
      expect(await aliceRepo.list(aliceCapability), isEmpty);

      await saveIdentityNamespace(_bob);
      final bobRepo = await AccountsRepository.create();
      final bobCapability = bobRepo.capabilityFor(_ready(
        accountId: 'acct-legacy',
        address: 'ut1legacy',
        sessionId: 'session-bob',
      ));
      expect(await bobRepo.list(bobCapability), isEmpty);
    });

    test('a legacy registry never overwrites an existing namespace', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-legacy', 'ut1legacy'),
      );
      await prefs.setString(
        'testnet:user:$_alice:accounts:index',
        _indexJson('acct-owned', 'ut1owned'),
      );
      await saveIdentityNamespace(_alice);

      final repo = await AccountsRepository.create();
      final capability = repo.capabilityFor(_ready(
        accountId: 'acct-owned',
        address: 'ut1owned',
        sessionId: 'session-alice',
      ));

      expect((await repo.list(capability)).single.id, 'acct-owned');
      expect(prefs.getString('testnet:accounts:index'), isNotNull,
          reason: 'someone else may still own the legacy rows');
    });

    test('obsolete adoption residue is retained without changing either copy',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final bare = _indexJson('acct-mine', 'ut1mine');
      final namespaced = _indexJson('acct-mine', 'ut1mine');
      await prefs.setString(
        'testnet:accounts:index',
        bare,
      );
      await prefs.setString('testnet:accounts:activeId', 'acct-mine');
      await prefs.setString(
        'testnet:user:$_alice:accounts:index',
        namespaced,
      );
      await prefs.setString('testnet:accounts:adopting', _alice);
      await saveIdentityNamespace(_alice);

      final repo = await AccountsRepository.create();
      final capability = repo.capabilityFor(_ready(
        accountId: 'acct-mine',
        address: 'ut1mine',
        sessionId: 'session-alice',
      ));

      expect((await repo.list(capability)).single.id, 'acct-mine');
      expect(prefs.getString('testnet:accounts:index'), bare);
      expect(prefs.getString('testnet:accounts:activeId'), 'acct-mine');
      expect(prefs.getString('testnet:accounts:adopting'), _alice);
      expect(
        prefs.getString('testnet:user:$_alice:accounts:index'),
        namespaced,
      );
    });
  });

  group('namespace store', () {
    test('the namespace round-trips and clears', () async {
      expect(await loadIdentityNamespace(), isNull);
      await saveIdentityNamespace(_alice);
      expect(await loadIdentityNamespace(), _alice);
      await clearIdentityNamespace();
      expect(await loadIdentityNamespace(), isNull);
    });

    test('saving a malformed hash stores nothing rather than a bad key',
        () async {
      await saveIdentityNamespace(_alice);
      await saveIdentityNamespace('nonsense');
      expect(await loadIdentityNamespace(), isNull);
    });
  });
}
