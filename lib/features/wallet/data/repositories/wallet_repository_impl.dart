import 'package:crypto_mobile_app/features/wallet/data/repositories/wallet_service.dart';
import 'package:crypto_mobile_app/features/wallet/data/mappers/wallet_mappers.dart';
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart'
    as domain;
import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';
import 'package:crypto_mobile_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl._();
  static WalletRepositoryImpl? _instance;
  static WalletRepositoryImpl get instance =>
      _instance ??= WalletRepositoryImpl._();

  @override
  Future<WalletBalanceEntity> getBalance() async {
    try {
      final b = WalletService.instance.getBalance();
      return b.toDomain();
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'wallet_getBalance');
      throw BackendError('Failed to load wallet balance',
          cause: e, stackTrace: st);
    }
  }

  @override
  Future<List<domain.Transaction>> getRecentTransactions(
      {int limit = 10}) async {
    try {
      final txs = WalletService.instance.getRecentTransactions(limit: limit);
      return txs.map((t) => t.toDomain()).toList(growable: false);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'wallet_getRecentTransactions');
      throw BackendError('Failed to load transactions',
          cause: e, stackTrace: st);
    }
  }

  @override
  Future<void> refresh() async {
    try {
      await WalletService.instance.refreshWalletData();
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'wallet_refresh');
      throw BackendError('Failed to refresh wallet data',
          cause: e, stackTrace: st);
    }
  }
}
