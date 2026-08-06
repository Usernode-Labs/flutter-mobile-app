import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/explorer_service.dart';

/// Provider used only to obtain a `Ref` for constructing the service. The cache
/// methods under test never read from `ref`, so no other overrides are needed.
final _serviceProvider = Provider((ref) => ExplorerService(ref));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ExplorerService service;

  ExplorerService build() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(_serviceProvider);
  }

  String balanceCache(double balance, DateTime cachedAt) => jsonEncode({
        'response': ExplorerBalanceResponse(
          balance: balance,
          tokenSymbol: 'TKN',
          dataSource: DataSource.explorerPrimary,
          fetchedAt: cachedAt,
        ).toJson(),
        'cached_at': cachedAt.millisecondsSinceEpoch,
      });

  group('getCachedBalance', () {
    test('returns null when nothing is cached', () async {
      SharedPreferences.setMockInitialValues({});
      service = build();
      expect(await service.getCachedBalance('acct'), isNull);
    });

    test('returns a fresh cached balance tagged as cached', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.explorer_balance_acct': balanceCache(42, DateTime.now()),
      });
      service = build();
      final res = await service.getCachedBalance('acct');
      expect(res, isNotNull);
      expect(res!.balance, 42);
      expect(res.dataSource, DataSource.cached);
    });

    test('returns null when the cache entry is expired', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.explorer_balance_acct':
            balanceCache(42, DateTime.now().subtract(const Duration(days: 3))),
      });
      service = build();
      expect(await service.getCachedBalance('acct'), isNull);
    });

    test('returns null on corrupt cache data', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.explorer_balance_acct': 'not-json',
      });
      service = build();
      expect(await service.getCachedBalance('acct'), isNull);
    });
  });

}
