import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';

const _scope = AccountStorageScope(
  network: 'testnet',
  bucket: 'bucket-a',
  accountId: 'account-a',
  address: 'acct/A',
);

const _otherNetworkScope = AccountStorageScope(
  network: 'internal',
  bucket: 'bucket-a',
  accountId: 'account-a',
  address: 'acct/A',
);

const _otherBucketScope = AccountStorageScope(
  network: 'testnet',
  bucket: 'bucket-b',
  accountId: 'account-a',
  address: 'acct/A',
);

const _otherAccountScope = AccountStorageScope(
  network: 'testnet',
  bucket: 'bucket-a',
  accountId: 'account-b',
  address: 'acct/A',
);

const _otherAddressScope = AccountStorageScope(
  network: 'testnet',
  bucket: 'bucket-a',
  accountId: 'account-a',
  address: 'acct/B',
);

const _chainId = 'chain-a';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ExplorerService buildService([http.Client? client]) {
    final service = ExplorerService(
      httpClient:
          client ?? MockClient((_) async => http.Response('unreachable', 500)),
    );
    addTearDown(service.dispose);
    return service;
  }

  group('scoped cache', () {
    test('returns null when nothing is cached', () async {
      final service = buildService();

      expect(
        await service.getCachedBalance(scope: _scope, chainId: _chainId),
        isNull,
      );
      expect(
        await service.getCachedTransactions(
          scope: _scope,
          chainId: _chainId,
        ),
        isNull,
      );
    });

    test('returns fresh balance and transaction entries as cached', () async {
      final cachedAt = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'flutter.${_cacheKey(_scope, _chainId, 'balance')}':
            _balanceCache(42, cachedAt),
        'flutter.${_cacheKey(_scope, _chainId, 'transactions')}':
            _transactionsCache(cachedAt),
      });
      final service = buildService();

      final balance = await service.getCachedBalance(
        scope: _scope,
        chainId: _chainId,
      );
      final transactions = await service.getCachedTransactions(
        scope: _scope,
        chainId: _chainId,
      );

      expect(balance?.balance, 42);
      expect(balance?.dataSource, DataSource.cached);
      expect(transactions?.transactions, hasLength(1));
      expect(transactions?.transactions.single.id, 'tx-a');
      expect(transactions?.dataSource, DataSource.cached);
    });

    test('isolates every account scope dimension and the chain ID', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.${_cacheKey(_scope, _chainId, 'balance')}':
            _balanceCache(42, DateTime.now()),
      });
      final service = buildService();

      expect(
        (await service.getCachedBalance(
          scope: _scope,
          chainId: _chainId,
        ))
            ?.balance,
        42,
      );

      for (final target in [
        (scope: _otherNetworkScope, chainId: _chainId),
        (scope: _otherBucketScope, chainId: _chainId),
        (scope: _otherAccountScope, chainId: _chainId),
        (scope: _otherAddressScope, chainId: _chainId),
        (scope: _scope, chainId: 'chain-b'),
      ]) {
        expect(
          await service.getCachedBalance(
            scope: target.scope,
            chainId: target.chainId,
          ),
          isNull,
        );
      }
    });

    test('successful live balance is cached only in its captured scope',
        () async {
      late Uri requestedUrl;
      final service = buildService(MockClient((request) async {
        requestedUrl = request.url;
        return http.Response(
          jsonEncode({'balance': 17, 'token_symbol': 'TKN'}),
          200,
        );
      }));
      const chainId = 'chain / one';

      final live = await service.getAccountBalance(
        scope: _scope,
        chainId: chainId,
      );
      final cached = await service.getCachedBalance(
        scope: _scope,
        chainId: chainId,
      );

      expect(live?.balance, 17);
      expect(live?.dataSource, DataSource.explorerPrimary);
      expect(cached?.balance, 17);
      expect(cached?.dataSource, DataSource.cached);
      expect(
        requestedUrl.toString(),
        contains(Uri.encodeComponent(chainId)),
      );
      expect(
        requestedUrl.toString(),
        contains(Uri.encodeComponent(_scope.address)),
      );
      expect(
        await service.getCachedBalance(
          scope: _otherAccountScope,
          chainId: chainId,
        ),
        isNull,
      );
      // Cache rows retain their chain provenance without changing the
      // separately observed current-chain pointer.
      expect(await service.resolveChainId(scope: _scope), isNull);
      expect(
        await service.resolveChainId(scope: _otherAccountScope),
        isNull,
      );
    });

    test('remembers observed chain provenance for offline cache reads',
        () async {
      final service = buildService();

      expect(
        await service.resolveChainId(
          scope: _scope,
          observedChainId: ' chain-a ',
        ),
        _chainId,
      );
      expect(await service.resolveChainId(scope: _scope), _chainId);
      expect(
        await service.resolveChainId(scope: _otherNetworkScope),
        isNull,
      );
    });

    test('a late cache write cannot replace newer observed chain provenance',
        () async {
      final service = buildService(MockClient((_) async {
        return http.Response(
          jsonEncode({'balance': 17, 'token_symbol': 'TKN'}),
          200,
        );
      }));
      await service.resolveChainId(
        scope: _scope,
        observedChainId: 'chain-b',
      );

      await service.getAccountBalance(scope: _scope, chainId: _chainId);

      expect(await service.resolveChainId(scope: _scope), 'chain-b');
      expect(
        await service.getCachedBalance(scope: _scope, chainId: _chainId),
        isNotNull,
      );
    });

    test('successful live transactions round-trip through the scoped cache',
        () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final service = buildService(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'tx_id': 'tx-live',
                'tx_type': 'transfer',
                'direction': 'in',
                'amount': 3,
                'timestamp_ms': timestamp,
                'status': 'confirmed',
              },
            ],
          }),
          200,
        );
      }));

      final live = await service.getAccountTransactions(
        scope: _scope,
        chainId: _chainId,
      );
      final cached = await service.getCachedTransactions(
        scope: _scope,
        chainId: _chainId,
      );

      expect(live?.transactions.single.id, 'tx-live');
      expect(cached?.transactions.single.id, 'tx-live');
      expect(cached?.dataSource, DataSource.cached);
    });

    test('discards legacy entries with unknowable provenance', () async {
      final cachedAt = DateTime.now();
      final legacyBalanceKey = 'explorer_balance_${_scope.address}';
      final legacyTransactionsKey = 'explorer_transactions_${_scope.address}';
      SharedPreferences.setMockInitialValues({
        'flutter.$legacyBalanceKey': _balanceCache(42, cachedAt),
        'flutter.$legacyTransactionsKey': _transactionsCache(cachedAt),
      });
      final service = buildService();

      expect(
        await service.getCachedBalance(scope: _scope, chainId: _chainId),
        isNull,
      );
      expect(
        await service.getCachedTransactions(
          scope: _scope,
          chainId: _chainId,
        ),
        isNull,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(legacyBalanceKey), isFalse);
      expect(prefs.containsKey(legacyTransactionsKey), isFalse);
    });

    test('removes expired and corrupt scoped entries', () async {
      final balanceKey = _cacheKey(_scope, _chainId, 'balance');
      final transactionsKey = _cacheKey(_scope, _chainId, 'transactions');
      SharedPreferences.setMockInitialValues({
        'flutter.$balanceKey': _balanceCache(
          42,
          DateTime.now().subtract(const Duration(days: 3)),
        ),
        'flutter.$transactionsKey': 'not-json',
      });
      final service = buildService();

      expect(
        await service.getCachedBalance(scope: _scope, chainId: _chainId),
        isNull,
      );
      expect(
        await service.getCachedTransactions(
          scope: _scope,
          chainId: _chainId,
        ),
        isNull,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(balanceKey), isFalse);
      expect(prefs.containsKey(transactionsKey), isFalse);
    });

    test('rejects an empty chain ID', () {
      final service = buildService();

      expect(
        () => service.getCachedBalance(scope: _scope, chainId: '  '),
        throwsArgumentError,
      );
    });
  });

  test('circuit breakers are isolated by account scope and chain', () async {
    var requestCount = 0;
    final service = buildService(MockClient((_) async {
      requestCount++;
      return http.Response('failure', 500);
    }));

    for (var i = 0; i < 4; i++) {
      await service.getAccountBalance(scope: _scope, chainId: _chainId);
    }
    final blockedCount = requestCount;

    await service.getAccountBalance(scope: _scope, chainId: _chainId);
    expect(requestCount, blockedCount);

    await service.getAccountBalance(
      scope: _otherAccountScope,
      chainId: _chainId,
    );
    expect(requestCount, greaterThan(blockedCount));
    final otherAccountCount = requestCount;

    await service.getAccountBalance(scope: _scope, chainId: 'chain-b');
    expect(requestCount, greaterThan(otherAccountCount));
  });
}

String _cacheKey(
  AccountStorageScope scope,
  String chainId,
  String kind,
) {
  final encodedChainId = Uri.encodeComponent(chainId);
  final encodedAccountId = Uri.encodeComponent(scope.accountId);
  final encodedAddress = Uri.encodeComponent(scope.address);
  return scope.preferenceKey(
    'explorer:v2:chain:$encodedChainId:account:$encodedAccountId:'
    'address:$encodedAddress:$kind',
  );
}

String _balanceCache(double balance, DateTime cachedAt) => jsonEncode({
      'response': ExplorerBalanceResponse(
        balance: balance,
        tokenSymbol: 'TKN',
        dataSource: DataSource.explorerPrimary,
        fetchedAt: cachedAt,
      ).toJson(),
      'cached_at': cachedAt.millisecondsSinceEpoch,
    });

String _transactionsCache(DateTime cachedAt) => jsonEncode({
      'response': ExplorerTransactionsResponse(
        transactions: [
          ExplorerTransaction(
            id: 'tx-a',
            txType: 'transfer',
            direction: 'in',
            amount: 1,
            tokenSymbol: 'TKN',
            timestamp: cachedAt,
            status: 'confirmed',
          ),
        ],
        dataSource: DataSource.explorerPrimary,
        fetchedAt: cachedAt,
      ).toJson(),
      'cached_at': cachedAt.millisecondsSinceEpoch,
    });
