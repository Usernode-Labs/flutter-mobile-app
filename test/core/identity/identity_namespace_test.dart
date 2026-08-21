// The per-user storage namespace (`identity_hash`) and the account registry
// that hangs off it.
//
// The point of the namespace is segregation: local accounts now outlive a
// sign-out, so a second user on the same device must never resolve the first
// user's registry — and the FIRST user signing back in must resolve theirs, or
// their wallet is unreachable.

import 'dart:convert';

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
      expect(
        (await (await AccountsRepository.create()).list()).single.id,
        'acct-alice',
      );

      // Alice signs out (her rows stay) and Bob signs in.
      await saveIdentityNamespace(_bob);
      final bobRepo = await AccountsRepository.create();

      expect(await bobRepo.list(), isEmpty, reason: 'Bob starts clean');
      expect(bobRepo.getActiveId(), isNull);

      // Alice signs back in and finds her wallet exactly where she left it.
      await saveIdentityNamespace(_alice);
      final aliceAgain = await AccountsRepository.create();
      expect((await aliceAgain.list()).single.id, 'acct-alice');
      expect(aliceAgain.getActiveId(), 'acct-alice');
    });

    test('an install with no session keeps using the unnamespaced keys',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-legacy', 'ut1legacy'),
      );

      final repo = await AccountsRepository.create();

      expect((await repo.list()).single.id, 'acct-legacy');
    });

    test('the first signed-in user adopts a pre-namespace registry', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-legacy', 'ut1legacy'),
      );
      await prefs.setString('testnet:accounts:activeId', 'acct-legacy');
      await saveIdentityNamespace(_alice);

      final repo = await AccountsRepository.create();

      expect((await repo.list()).single.id, 'acct-legacy');
      expect(repo.getActiveId(), 'acct-legacy');
      // The legacy copy is gone, so the NEXT user to sign in cannot inherit
      // the same accounts.
      expect(prefs.getString('testnet:accounts:index'), isNull);
      expect(prefs.getString('testnet:accounts:activeId'), isNull);
      expect(
        prefs.getString('testnet:user:$_alice:accounts:index'),
        isNotNull,
      );
    });

    test('adoption cannot hand one registry to a second user', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-legacy', 'ut1legacy'),
      );

      await saveIdentityNamespace(_alice);
      expect((await (await AccountsRepository.create()).list()).single.id,
          'acct-legacy');

      await saveIdentityNamespace(_bob);
      expect(await (await AccountsRepository.create()).list(), isEmpty);
    });

    test('adoption never overwrites a namespace that already has accounts',
        () async {
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

      expect((await repo.list()).single.id, 'acct-owned');
      expect(prefs.getString('testnet:accounts:index'), isNotNull,
          reason: 'someone else may still own the legacy rows');
    });

    test('an adoption interrupted before its source was removed is finished',
        () async {
      final prefs = await SharedPreferences.getInstance();
      // The state a crash between "destination written" and "source removed"
      // leaves: BOTH copies, plus the marker naming who was adopting.
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-mine', 'ut1mine'),
      );
      await prefs.setString('testnet:accounts:activeId', 'acct-mine');
      await prefs.setString(
        'testnet:user:$_alice:accounts:index',
        _indexJson('acct-mine', 'ut1mine'),
      );
      await prefs.setString('testnet:accounts:adopting', _alice);
      await saveIdentityNamespace(_alice);

      final repo = await AccountsRepository.create();

      expect((await repo.list()).single.id, 'acct-mine');
      // The marker is what tells this duplicate apart from bare rows that
      // were never this user's — without it the leftover copy stays
      // resolvable by the next identity that has no namespace at all.
      expect(prefs.getString('testnet:accounts:index'), isNull);
      expect(prefs.getString('testnet:accounts:activeId'), isNull);
      expect(prefs.getString('testnet:accounts:adopting'), isNull);
    });

    test('a sign-out retires bare rows even when the namespace is valid',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:user:$_alice:accounts:index',
        _indexJson('acct-owned', 'ut1owned'),
      );
      // Reachable two ways: a same-participant renewal that only just
      // acquired an `identity_hash`, and an adoption that was interrupted
      // without leaving a marker.
      await prefs.setString(
        'testnet:accounts:index',
        _indexJson('acct-bare', 'ut1bare'),
      );
      await prefs.setString('testnet:accounts:activeId', 'acct-bare');
      await saveIdentityNamespace(_alice);

      expect(await AccountsRepository.retireUnnamespacedRegistry(), isTrue);

      // A non-null namespace does NOT prove the bare keys are absent, so the
      // retirement is unconditional; the namespaced registry is untouched.
      expect(prefs.getString('testnet:accounts:index'), isNull);
      expect(prefs.getString('testnet:accounts:activeId'), isNull);
      expect(
        prefs.getString('testnet:user:$_alice:accounts:index'),
        isNotNull,
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
